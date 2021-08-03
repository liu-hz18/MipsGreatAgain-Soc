`include "defines.svh"

module ibus_controller #(
    parameter DATA_WIDTH = 32, // bits
    parameter LINE_WIDTH = 256, // bits
    parameter SET_ASSOC = 4,
    parameter CACHE_SIZE = 16*1024*8 // bits
) (
    input clk,
    input rst,

    cpu_ibus_if.slave ibus,

    // invalidation requests from MEM stage
    input logic invalidate_icache,
    input word_t invalidate_addr,

    // cached
    output axi_req_t axi_req,
    input axi_resp_t axi_resp
);

localparam int LINE_NUM = CACHE_SIZE / LINE_WIDTH;
localparam int GROUP_NUM = LINE_NUM / SET_ASSOC;

localparam int DATA_PER_LINE = LINE_WIDTH / DATA_WIDTH;
localparam int DATA_BYTE_OFFSET = $clog2(DATA_WIDTH / 8);
localparam int LINE_BYTE_OFFSET = $clog2(LINE_WIDTH / 8);
localparam int INDEX_WIDTH = $clog2(GROUP_NUM);
localparam int TAG_WIDTH = 32 - INDEX_WIDTH - LINE_BYTE_OFFSET;

typedef enum logic[2:0] {  
    IDLE,
    WAIT_AXI_READY,
    RECEIVING,
    REFILL,
    INVALIDATING,
    WAIT_CPU_READY,
    FLUSH_WAIT_AXI_READY,
    FLUSH_RECEIVING
} state_t;

typedef struct packed {
    logic valid;
    logic [TAG_WIDTH-1:0] tag;
} tag_t;

typedef logic [DATA_PER_LINE-1:0][DATA_WIDTH-1:0] line_t;
typedef logic [INDEX_WIDTH-1:0] index_t;
typedef logic [LINE_BYTE_OFFSET-DATA_BYTE_OFFSET-1:0] offset_t;

function index_t get_index( input word_t addr );
    return addr[LINE_BYTE_OFFSET+INDEX_WIDTH-1:LINE_BYTE_OFFSET];
endfunction

function logic [TAG_WIDTH-1:0] get_tag( input word_t addr );
    return addr[31:LINE_BYTE_OFFSET+INDEX_WIDTH];
endfunction

function offset_t get_offset( input word_t addr );
    return addr[LINE_BYTE_OFFSET-1:DATA_BYTE_OFFSET];
endfunction

// stage 1(a.k.a IF stage): get tag index and data index and send to BRAM
// RAM read requests of tag
index_t tag_ram_raddr;
assign tag_ram_raddr = get_index(ibus.address);
// RAM read requests of data
index_t data_ram_raddr;
assign data_ram_raddr = get_index(ibus.address);

// stage 2
// pipe control info from IF-1 to IF-2
word_t address_stage2, pc_stage2;
exceptType_t if_except_stage2;
bit_t inst_valid_stage2;
always_ff @(posedge clk) begin
    if (rst || ibus.flush || (ibus.branch_flag & ~ibus.stall_req)) begin
        inst_valid_stage2 <= '0;
    end else if (~ibus.stall & ~ibus.stall_req) begin
        inst_valid_stage2 <= ~(|ibus.cpu_if_except);
    end

    if (rst || ibus.flush) begin
        address_stage2 <= '0;
        pc_stage2 <= '0;
        if_except_stage2 <= '0;
    end else if (~ibus.stall & ~ibus.stall_req) begin
        address_stage2 <= ibus.address;
        pc_stage2 <= ibus.cpu_pc;
        if_except_stage2 <= ibus.cpu_if_except;
    end
end
// bram tag and data query result
tag_t [SET_ASSOC-1:0] tag_rdata_unsafe, tag_rdata;
line_t [SET_ASSOC-1:0] data_rdata_unsafe, data_rdata;

// forward delaration
line_t data_wdata, pipe_data_wdata;
tag_t tag_wdata, pipe_tag_wdata;
logic [SET_ASSOC-1:0] tag_we;
logic [SET_ASSOC-1:0] pipe_tag_we;
logic [SET_ASSOC-1:0] data_we;
logic [SET_ASSOC-1:0] pipe_data_we;
word_t address_stage3;
always_ff @(posedge clk) begin
    if (rst) begin
        pipe_data_wdata <= '0;
        pipe_data_we <= '0;
        pipe_tag_wdata <= '0;
        pipe_tag_we <= '0;
    end else begin
        pipe_data_wdata <= data_wdata;
        pipe_data_we <= data_we;
        pipe_tag_wdata <= tag_wdata;
        pipe_tag_we <= tag_we;
    end
end
// data bypass to `tag_rdata` and `data_rdata`
always_comb begin
    data_rdata = data_rdata_unsafe;
    for (int i = 0; i < SET_ASSOC; ++i) begin
        if (pipe_data_we[i] && (get_index(address_stage2) == get_index(address_stage3))) begin
            data_rdata[i] = pipe_data_wdata;
        end
    end

    tag_rdata = tag_rdata_unsafe;
    for (int i = 0; i < SET_ASSOC; ++i) begin
        if (pipe_tag_we[i] && (get_index(address_stage2) == get_index(address_stage3))) begin
            tag_rdata[i] = pipe_tag_wdata;
        end
    end
end
// get hit info
logic [SET_ASSOC-1:0] hit;
logic cache_miss_stage2;
for(genvar i = 0; i < SET_ASSOC; ++i) begin: gen_icache_hit_tag
    assign hit[i] = tag_rdata[i].valid & (get_tag(address_stage2) == tag_rdata[i].tag);
end
assign cache_miss_stage2 = ~(|hit);
// get line data and return a word
word_t hit_data;
always_comb begin: gen_icache_hit_data
    hit_data = '0;
    for(int i = 0; i < SET_ASSOC; ++i) begin
        if (hit[i]) begin
            hit_data = data_rdata[i][get_offset(address_stage2)];
        end
    end
end
// get replace control info
logic [GROUP_NUM-1:0][$clog2(SET_ASSOC)-1:0] lru;
logic [GROUP_NUM-1:0] lru_update;
logic [$clog2(SET_ASSOC)-1:0] replace_assoc_addr_stage2;
always_comb begin
    replace_assoc_addr_stage2 = lru[get_index(address_stage2)];
    for (int i = 0; i < SET_ASSOC; ++i) begin
        if (~tag_rdata[i].valid) replace_assoc_addr_stage2 = i;
    end
end
for(genvar i = 0; i < GROUP_NUM; ++i) begin: gen_lru_update
    assign lru_update[i] = (i[INDEX_WIDTH-1:0] == get_index(address_stage2)) & inst_valid_stage2;
end

// stage 3, if miss we go to AXI FSM, if hit we simply pipe it to ID
word_t pc_stage3;
exceptType_t if_except_stage3;
word_t hit_data_stage3;
logic cache_miss_stage3;
logic [$clog2(SET_ASSOC)-1:0] replace_assoc_addr_stage3;
bit_t inst_valid_stage3;
// pipe control into from IF-2 to IF-3
always_ff @(posedge clk) begin
    if (rst || ibus.flush) begin
        inst_valid_stage3 <= '0;
    end else if (~ibus.stall & ~ibus.stall_req) begin
        if (ibus.branch_flag) begin
            inst_valid_stage3 <= '0;
        end else begin
            inst_valid_stage3 <= inst_valid_stage2;
        end
    end

    if (rst || ibus.flush) begin
        address_stage3 <= '0;
        pc_stage3 <= '0;
        if_except_stage3 <= '0;
        hit_data_stage3 <= '0;
        cache_miss_stage3 <= '0;
        replace_assoc_addr_stage3 <= '0;
    end else if (~ibus.stall & ~ibus.stall_req) begin
        address_stage3 <= address_stage2;
        pc_stage3 <= pc_stage2;
        if_except_stage3 <= if_except_stage2;
        hit_data_stage3 <= hit_data;
        cache_miss_stage3 <= cache_miss_stage2;
        replace_assoc_addr_stage3 <= replace_assoc_addr_stage2;
    end    
end

state_t state_d, state; // used in stage 3, but declare it here.
// invalidate is not used for basic tests. we will implement it later.
index_t invalidate_cnt, invalidate_cnt_d;
logic [LINE_BYTE_OFFSET-1-2:0] burst_cnt, burst_cnt_d;
logic [LINE_WIDTH/32-1:0][31:0] line_recv; // 8 words

// stage 3 ctrl FSM
always_comb begin: state_fsm
    state_d = state;
    unique case(state)
    IDLE:
        if (cache_miss_stage3 & inst_valid_stage3 & ~ibus.flush) state_d = WAIT_AXI_READY;
        else state_d = IDLE;
    WAIT_AXI_READY:
        if (axi_resp.arready) state_d = RECEIVING;
        else if (ibus.flush) state_d = FLUSH_WAIT_AXI_READY;
    FLUSH_WAIT_AXI_READY:
        if (axi_resp.arready) state_d = FLUSH_RECEIVING;
    RECEIVING:
        if(axi_resp.rvalid & axi_resp.rlast) begin
            state_d = REFILL;
        end else if (ibus.flush) begin
            state_d = FLUSH_RECEIVING;
        end
    FLUSH_RECEIVING:
        if(axi_resp.rvalid & axi_resp.rlast) begin
            if (~ibus.stall_req) begin
                state_d = IDLE;
            end else begin
                state_d = WAIT_CPU_READY;
            end
        end
    REFILL:
        if (~ibus.stall_req) begin
            state_d = IDLE;
        end else begin
            state_d = WAIT_CPU_READY;
        end
    WAIT_CPU_READY:
        if (~ibus.stall_req) begin // if mem have stalled IF stage due to a bus conflict, we can simply stall FSM in WAIT_CPU_READY stage.
            state_d = IDLE;
        end
    INVALIDATING:
        if (&invalidate_cnt) begin
            if (~ibus.stall_req) state_d = IDLE;
            else state_d = WAIT_CPU_READY;
        end 
    default: state_d = INVALIDATING; // for safe restart
    endcase
end

index_t tag_ram_waddr, data_ram_waddr;
always_comb begin
    tag_we = '0;
    data_we = '0;
    burst_cnt_d = '0;
    invalidate_cnt_d = '0;

    tag_ram_waddr = get_index(address_stage3);
    data_ram_waddr = get_index(address_stage3);

    // AXI signals assign
    axi_req = '0;
    axi_req.arlen   = LINE_WIDTH / 32 - 1; // LINE_WIDTH is 256 temply
    axi_req.arsize  = 3'b010; // 4 bytes per transmission
    axi_req.arburst = 2'b01;  // INCR
    axi_req.araddr  = { address_stage3[31:LINE_BYTE_OFFSET], {LINE_BYTE_OFFSET{1'b0}} };
    unique case (state)
    WAIT_AXI_READY, FLUSH_WAIT_AXI_READY: begin
        burst_cnt_d = '0;
        axi_req.arvalid = 1'b1;
    end
    RECEIVING: begin
        if (axi_resp.rvalid) begin
            axi_req.rready = 1'b1;
            burst_cnt_d = burst_cnt + 1;
        end else begin
            axi_req.rready = 1'b0;
            burst_cnt_d = burst_cnt; // hold `burst_cnt` when not rvalid
        end
        if (axi_resp.rvalid & axi_resp.rlast) begin
            tag_we[replace_assoc_addr_stage3] = 1'b1;
            data_we[replace_assoc_addr_stage3] = 1'b1;
        end
    end
    FLUSH_RECEIVING: begin
        axi_req.rready = 1'b1;
    end
    INVALIDATING: begin
        invalidate_cnt_d = invalidate_cnt + 1;
        tag_we = '1;
        data_we = '1; // set all data cache to zero, just for safety.
        tag_ram_waddr = invalidate_cnt;
    end
    default: begin end
    endcase
end

// write to RAM cache and return it to cpu
always_ff @(posedge clk) begin
    if (rst) begin
        line_recv <= '0;
    end else if (state == RECEIVING && axi_resp.rvalid) begin
        line_recv[burst_cnt] <= axi_resp.rdata;
    end
end
assign tag_wdata.valid = (state != INVALIDATING);
assign tag_wdata.tag = get_tag(address_stage3);
always_comb begin 
    data_wdata = line_recv;
    data_wdata[DATA_PER_LINE-1][DATA_WIDTH-1 -: 32] = axi_resp.rdata;
end

always_comb begin
    if (~inst_valid_stage3) begin
        ibus.rdata = '0; // issue NOP to ID for 2 cycles.
        ibus.valid = (|if_except_stage3);
    end else begin
        ibus.valid = '1;
        if (cache_miss_stage3) begin
            ibus.rdata = line_recv[address_stage3[LINE_BYTE_OFFSET-1:2]];
        end else begin
            ibus.rdata = hit_data_stage3;
        end
    end
end
assign ibus.bus_pc = pc_stage3;
assign ibus.bus_if_except = if_except_stage3;
assign ibus.stall = (state_d != IDLE); // bus signals assign
assign ibus.ready = (state != INVALIDATING);

always_ff @(posedge clk) begin
    if (rst) begin
        state <= INVALIDATING;
        invalidate_cnt <= '0;
        burst_cnt <= '0;
    end else begin
        state <= state_d;
        invalidate_cnt <= invalidate_cnt_d;
        burst_cnt <= burst_cnt_d;
    end
end

// generate block RAMs as I-CAHCE
for (genvar i = 0; i < SET_ASSOC; ++i) begin: gen_icache
    // DUAL port RAM enable us to read and write simultaneously !
    // DATA will return in the NEXT cycle after addr and enable vectors are set.
    simple_dual_port_bram #(
        .DATA_WIDTH($bits(tag_t)),
        .SIZE(GROUP_NUM)
    ) mem_tag (
        .clk(clk),
        .rst(rst),
        // Port A for write
        .ena(1'b1), // Memory enable signal for port A. Must be high on clock cycles when read or write operations are initiated. Pipelined internally.
        .wea(tag_we[i]),     // 1 bit wide, Write enable vector for port A input data port `dina`
        .addra(tag_ram_waddr),  // $clog2(SIZE)-bit input: Address for port A write and read operations.
        .dina(tag_wdata),   // DATA_WIDTH-bit input: Data input for port A write operations.
        // read Port B (is before IF-3)
        .enb(~ibus.stall_req && ~ibus.stall), // Memory enable signal for port B. Must be high on clock cycles when read or write operations are initiated. Pipelined internally.
        .addrb(tag_ram_raddr),  // $clog2(SIZE)-bit input: Address for port B write and read operations.
        .doutb(tag_rdata_unsafe[i])   // DATA_WIDTH-bit output: Data output for port B read operations.
    );

    simple_dual_port_bram #(
        .DATA_WIDTH($bits(line_t)),
        .SIZE(GROUP_NUM)
    ) mem_data (
        .clk(clk),
        .rst(rst),
        // Port A for write
        .ena(1'b1), // Memory enable signal for port A. Must be high on clock cycles when read or write operations are initiated. Pipelined internally.
        .wea(data_we[i]), // 1 bit wide, Write enable vector for port A input data port `dina`
        .addra(data_ram_waddr), // $clog2(SIZE)-bit input: Address for port A write and read operations.
        .dina(data_wdata),  // DATA_WIDTH-bit input: Data input for port A write operations.
        // Port B for read (always)
        .enb(~ibus.stall_req && ~ibus.stall), // Memory enable signal for port B. Must be high on clock cycles when read or write operations are initiated. Pipelined internally.
        .addrb(data_ram_raddr), // $clog2(SIZE)-bit input: Address for port B write and read operations.
        .doutb(data_rdata_unsafe[i])  // DATA_WIDTH-bit output: Data output for port B read operations.
    );
end

// generate PLRU replacement policy for each group
// PLRU records access in stage 2 and give lru vector in stage 2
for(genvar i = 0; i < GROUP_NUM; ++i) begin: gen_plru
    plru #(
        .SET_ASSOC (SET_ASSOC)
    ) plru_inst (
        .clk,
        .rst,
        .access (hit),
        .update (lru_update[i] & (~ibus.stall & ~ibus.stall_req)),

        .lru    (lru[i])
    );
end

endmodule
