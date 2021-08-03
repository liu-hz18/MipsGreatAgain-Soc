`include "defines.svh"

module mem #(
    parameter DATA_WIDTH = 32, // bits
    parameter LINE_WIDTH = 256, // bits
    parameter SET_ASSOC = 4,
    parameter CACHE_SIZE = 16*1024*8 // bits
) (
    input clk, rst,
    input flush,

    input exOperation_t op,
    input bit_t ll_bit_unsafe,
    input mmuResult_t data_mmu_result_i,
    input inst_type_t inst_type,
    input bit_t except_already_occur,

    output bit_t mem_stall_req,

    // inputs and outputs that need to pipe to wb stage
    input memControl_t cache_memory,
    input word_t cache_pc,
    input regWritePort_t cache_wp,
    input bit_t cache_we_hilo,
    input doubleword_t cache_hilo,
    `ifdef ENABLE_FPU
    input fcsrReg_t cache_fcsr_wdata,
    input bit_t cache_fcsr_we,
    input fpuRegWriteReq_t cache_fpu_wr,
    `endif

    // cache 2 stage data bypass to id stage
    output regWritePort_t cache_2_wp,
    output bit_t cache_2_we_hilo,
    output doubleword_t cache_2_hilo,
    output memControl_t cache_2_memory,
    `ifdef ENABLE_FPU
    output fcsrReg_t cache_2_fcsr_wdata,
    output bit_t cache_2_fcsr_we,
    output fpuRegWriteReq_t cache_2_fpu_wr,
    `endif

    // mem stage data bypass and pipe to wb stage
    output word_t mem_pc,
    output regWritePort_t mem_wp1, // execute result
    output bit_t mem_we_hilo,
    output doubleword_t mem_hilo,
    output memControl_t mem_memory,
    `ifdef ENABLE_FPU
    output fcsrReg_t mem_fcsr_wdata,
    output bit_t mem_fcsr_we,
    output fpuRegWriteReq_t mem_fpu_wr,
    `endif
    output bit_t mem_llbit_we,
    output bit_t mem_llbit_wdata,

    output bit_t ready, // dcache need to init when booting
    // control signals to icache and axi dbus
    output bit_t invalidate_icache,
    output word_t invalidate_addr,
    output axi_req_t dcache_axi_req,
    input axi_resp_t dcache_axi_resp,
    output axi_req_t uncached_axi_req,
    input axi_resp_t uncached_axi_resp
);

// D-Cache，扩充为3级流水(MEM-1给tag和data信号，MEM-2得到命中信息和数据和替换位置，MEM-3处理AXI通信和写回)
// load  hit : give tag/data index -> get hit info and data, update lru -> pipe data to wb stage
// load  miss: give tag/data index -> get hit info and data, get replacement policy, update lru -> start axi load a block to cache, clear dirty, write to cache, return to wb stage
// store hit : give tag/data index -> get hit info and data, update lru, set dirty to data -> write dirty data to cache
// store miss: give tag/data index -> get hit info and data, get replacement policy, update lru -> start axi load a block to cache, set dirty to data, write back to cache
localparam int LINE_NUM = CACHE_SIZE / LINE_WIDTH;
localparam int GROUP_NUM = LINE_NUM / SET_ASSOC;

localparam int DATA_PER_LINE = LINE_WIDTH / DATA_WIDTH;
localparam int DATA_BYTE_OFFSET = $clog2(DATA_WIDTH / 8);
localparam int LINE_BYTE_OFFSET = $clog2(LINE_WIDTH / 8);
localparam int INDEX_WIDTH = $clog2(GROUP_NUM);
localparam int TAG_WIDTH = 32 - INDEX_WIDTH - LINE_BYTE_OFFSET;

localparam int BURST_LIMIT = (LINE_WIDTH / 32) - 1;

typedef struct packed {
    logic valid;
    logic dirty;
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

// ll_bit bypass in cache_1 stage from cache_2 stage and mem stage
bit_t cache_2_llbit_we;
bit_t cache_2_llbit_wdata;
bit_t ll_bit;
always_comb begin: ll_bit_assign
    ll_bit = ll_bit_unsafe;
    if (cache_2_llbit_we) begin
        ll_bit = cache_2_llbit_wdata;
    end else if (mem_llbit_we) begin
        ll_bit = mem_llbit_wdata;
    end
end
bit_t is_sc, is_ll;
assign is_sc = inst_type.sc_inst;
assign is_ll = inst_type.ll_inst;
bit_t ce_mem;
assign ce_mem = cache_memory.ce & (~except_already_occur);
// cached axi control signals
bit_t cache_dbus_read, cache_dbus_write;
word_t cache_dbus_addr, cache_dbus_wdata;
logic[3:0] cache_dbus_byteen;
bit_t cache_uncached;
assign cache_dbus_read = ce_mem & (~cache_memory.we);
assign cache_dbus_write = ce_mem & cache_memory.we & (~is_sc | ll_bit); // ce & we
assign cache_dbus_addr = inst_type.unaligned_inst ? { data_mmu_result_i.paddr[31:2], 2'b00 } : data_mmu_result_i.paddr; // force addr to be aligned.
assign cache_dbus_wdata = cache_memory.wdata;
assign cache_dbus_byteen = cache_memory.sel;
assign cache_uncached = data_mmu_result_i.uncached;

// LL / SC in cache-1 stage
bit_t llbit_we;
bit_t llbit_wdata;
assign llbit_we = is_ll | is_sc | except_already_occur;
always_comb begin: llbit_assign
    if (is_ll & ~except_already_occur) begin
        llbit_wdata = 1'b1;
    end else begin // include op == OP_SC, clear llbit
        llbit_wdata = 1'b0;
    end
end

// CACHE-1 stage: get tag and data index and send to BRAM
index_t tag_ram_raddr, data_ram_raddr;
assign tag_ram_raddr = get_index(cache_dbus_addr);
assign data_ram_raddr = get_index(cache_dbus_addr);


// Cache-2 stage: get hit info and data in cache, get replacement way
word_t cache_2_pc;
bit_t cache_2_dbus_read, cache_2_dbus_write;
word_t cache_2_dbus_addr, cache_2_dbus_wdata;
logic[3:0] cache_2_dbus_byteen;
bit_t cache_2_uncached;
exOperation_t cache_2_op;
// cache-1 -> cache-2 pipeline
always_ff @(posedge clk) begin
    if (rst || flush) begin
        cache_2_pc <= '0;
        cache_2_wp <= '0;
        cache_2_we_hilo <= '0;
        cache_2_hilo <= '0;
        cache_2_memory <= '0;
        cache_2_llbit_we <= '0;
        cache_2_llbit_wdata <= '0;
        `ifdef ENABLE_FPU
        cache_2_fcsr_wdata <= '0;
        cache_2_fcsr_we <= '0;
        cache_2_fpu_wr <= '0;
        `endif
        cache_2_dbus_read <= '0;
        cache_2_dbus_write <= '0;
        cache_2_dbus_addr <= '0;
        cache_2_dbus_wdata <= '0;
        cache_2_dbus_byteen <= '0;
        cache_2_uncached <= '0;
        cache_2_op <= OP_NOP;
    end else if (~mem_stall_req) begin
        cache_2_pc <= cache_pc;
        cache_2_wp <= cache_wp;
        cache_2_we_hilo <= cache_we_hilo & ~except_already_occur;
        cache_2_hilo <= cache_hilo;
        cache_2_memory <= cache_memory;
        cache_2_llbit_we <= llbit_we;
        cache_2_llbit_wdata <= llbit_wdata;
        `ifdef ENABLE_FPU
        cache_2_fcsr_wdata <= cache_fcsr_wdata;
        cache_2_fcsr_we <= cache_fcsr_we;
        cache_2_fpu_wr <= cache_fpu_wr;
        `endif
        cache_2_dbus_read <= cache_dbus_read;
        cache_2_dbus_write <= cache_dbus_write;
        cache_2_dbus_addr <= cache_dbus_addr;
        cache_2_dbus_wdata <= cache_dbus_wdata;
        cache_2_dbus_byteen <= cache_dbus_byteen;
        cache_2_uncached <= cache_uncached;
        cache_2_op <= op;
    end
end
logic [SET_ASSOC-1:0] tag_we;
logic [SET_ASSOC-1:0] data_we;
tag_t tag_wdata;
line_t data_wdata;
word_t mem_dbus_addr;
// bram tag and data query result
tag_t [SET_ASSOC-1:0] tag_rdata_unsafe, tag_rdata;
line_t [SET_ASSOC-1:0] data_rdata_unsafe, data_rdata;
// data bypass to tag_rdata and data_rdata.
always_comb begin
    data_rdata = data_rdata_unsafe;
    for (int i = 0; i < SET_ASSOC; ++i) begin
        if (data_we[i] && (get_index(cache_2_dbus_addr) == get_index(mem_dbus_addr))) begin
            data_rdata[i] = data_wdata;
        end
    end

    tag_rdata = tag_rdata_unsafe;
    for (int i = 0; i < SET_ASSOC; ++i) begin
        if (tag_we[i] && (get_index(cache_2_dbus_addr) == get_index(mem_dbus_addr))) begin
            tag_rdata[i] = tag_wdata;
        end
    end
end
// get hit info
logic [SET_ASSOC-1:0] hit;
logic cache_miss_stage2;
for(genvar i = 0; i < SET_ASSOC; ++i) begin: gen_icache_hit_tag
    assign hit[i] = tag_rdata[i].valid & (get_tag(cache_2_dbus_addr) == tag_rdata[i].tag);
end
assign cache_miss_stage2 = ~(|hit);
// get line hit data and return a word
line_t hit_line;
logic [$clog2(SET_ASSOC)-1:0] hit_way_addr;
always_comb begin: gen_icache_hit_data
    hit_line = '0;
    hit_way_addr = '0;
    for(int i = 0; i < SET_ASSOC; ++i) begin
        if (hit[i]) begin
            hit_line = data_rdata[i];
            hit_way_addr = i;
        end
    end
end
// get replacement control info
logic [GROUP_NUM-1:0][$clog2(SET_ASSOC)-1:0] lru;
logic [GROUP_NUM-1:0] lru_update;
logic [$clog2(SET_ASSOC)-1:0] cache_2_replace_assoc_addr;
bit_t cache_2_need_write_back;
word_t cache_2_wb_addr;
assign cache_2_wb_addr = { tag_rdata[cache_2_replace_assoc_addr].tag, get_index(cache_2_dbus_addr), {LINE_BYTE_OFFSET{1'b0}} };
always_comb begin
    cache_2_replace_assoc_addr = lru[get_index(cache_2_dbus_addr)];
    for (int i = 0; i < SET_ASSOC; ++i) begin
        if (~tag_rdata[i].valid) cache_2_replace_assoc_addr = i;
    end
end
always_comb begin
    cache_2_need_write_back = tag_rdata[cache_2_replace_assoc_addr].dirty;
    for (int i = 0; i < SET_ASSOC; ++i) begin
        cache_2_need_write_back &= tag_rdata[i].valid;
    end
end
// get write back data line
line_t write_back_line;
assign write_back_line = data_rdata[cache_2_replace_assoc_addr];
// cache-2 stage read and update lru state
for(genvar i = 0; i < GROUP_NUM; ++i) begin: gen_lru_update
    assign lru_update[i] = (i[INDEX_WIDTH-1:0] == get_index(cache_2_dbus_addr)) & cache_2_uncached;
end

// mem stage
logic [$clog2(SET_ASSOC)-1:0] mem_replace_assoc_addr;
bit_t mem_cache_miss;
line_t mem_hit_line;
bit_t mem_need_write_back;
line_t mem_write_back_line;
word_t mem_wb_addr;
logic [$clog2(SET_ASSOC)-1:0] mem_hit_way_addr;

bit_t mem_dbus_read, mem_dbus_write;
word_t mem_dbus_wdata;
logic[3:0] mem_dbus_byteen;
bit_t mem_uncached;
exOperation_t mem_op;
fpuRegWriteReq_t mem_fpu_wr_temp;
regWritePort_t mem_wp_temp;
// cache-2 -> mem pipeline
always_ff @(posedge clk) begin
    if (rst) begin
        mem_pc <= '0;
        mem_wp_temp <= '0;
        mem_we_hilo <= '0;
        mem_hilo <= '0;
        mem_memory <= '0;
        mem_llbit_we <= '0;
        mem_llbit_wdata <= '0;
        `ifdef ENABLE_FPU
        mem_fcsr_wdata <= '0;
        mem_fcsr_we <= '0;
        mem_fpu_wr_temp <= '0;
        `endif
        mem_dbus_read <= '0;
        mem_dbus_write <= '0;
        mem_dbus_addr <= '0;
        mem_dbus_wdata <= '0;
        mem_dbus_byteen <= '0;
        mem_uncached <= '0;
        mem_op <= OP_NOP;
        mem_replace_assoc_addr <= '0;
        mem_cache_miss <= '0;
        mem_hit_line <= '0;
        mem_need_write_back <= '0;
        mem_write_back_line <= '0;
        mem_wb_addr <= '0;
        mem_hit_way_addr <= '0;
    end else if (~mem_stall_req) begin
        mem_pc <= cache_2_pc;
        mem_wp_temp <= cache_2_wp;
        mem_we_hilo <= cache_2_we_hilo;
        mem_hilo <= cache_2_hilo;
        mem_memory <= cache_2_memory;
        mem_llbit_we <= cache_2_llbit_we;
        mem_llbit_wdata <= cache_2_llbit_wdata;
        `ifdef ENABLE_FPU
        mem_fcsr_wdata <= cache_2_fcsr_wdata;
        mem_fcsr_we <= cache_2_fcsr_we;
        mem_fpu_wr_temp <= cache_2_fpu_wr;
        `endif
        mem_dbus_read <= cache_2_dbus_read;
        mem_dbus_write <= cache_2_dbus_write;
        mem_dbus_addr <= cache_2_dbus_addr;
        mem_dbus_wdata <= cache_2_dbus_wdata;
        mem_dbus_byteen <= cache_2_dbus_byteen;
        mem_uncached <= cache_2_uncached;
        mem_op <= cache_2_op;
        mem_replace_assoc_addr <= cache_2_replace_assoc_addr;
        mem_cache_miss <= cache_miss_stage2;
        mem_hit_line <= hit_line;
        mem_need_write_back <= cache_2_need_write_back;
        mem_write_back_line <= write_back_line;
        mem_wb_addr <= cache_2_wb_addr;
        mem_hit_way_addr <= hit_way_addr;
    end
end

// dbus FSM
typedef enum logic[3:0] {  
    IDLE,
    // load states
    READ_WAIT_AXI_READY,
    READING,
    // cache replacement write back
    WB_WRITE_WAIT_AXI_READY,
    WB_WRITING,
    WB_WAIT_BVALID,
    // write cache states
    WRITE_CACHE,
    INVALIDATING,
    RST,
    // uncached store states
    UNCACHE_READ_WAIT_AXI_READY,
    UNCACHE_READING,
    UNCACHE_READ_FINISH,
    UNCACHE_WRITE_WAIT_AXI_READY,
    UNCACHE_WRITING,
    UNCACHE_WAIT_BVALID
} state_t;

state_t state, state_d;
index_t invalidate_cnt, invalidate_cnt_d;
logic [LINE_BYTE_OFFSET-1-2:0] burst_cnt, burst_cnt_d;
logic [LINE_BYTE_OFFSET-1-2:0] wb_burst_cnt, wb_burst_cnt_d;
logic [LINE_WIDTH/32-1:0][31:0] cache_line_recv; // 8 words
word_t uncache_data_recv;
index_t tag_ram_waddr, data_ram_waddr;

// cached req
// load hit: IDLE
// load miss: IDLE -> WB_WRITE_WAIT_AXI_READY -> WB_WRITING -> WB_WAIT_BVALID -> READ_WAIT_AXI_READY -> READING -> REFILL -> IDLE
// store hit: IDLE
// store miss: IDLE -> WB_WRITE_WAIT_AXI_READY -> WB_WRITING -> WB_WAIT_BVALID -> READ_WAIT_AXI_READY -> READING -> REFILL -> IDLE
// uncached req
// load: IDLE -> READ_WAIT_AXI_READY -> READING -> IDLE
// store: IDLE -> WRITE_WAIT_AXI_READY -> WRITING -> WAIT_BVALID -> IDLE
always_comb begin: dbus_state_fsm
    state_d = state;
    unique case (state)
    IDLE: begin
        if (mem_uncached) begin
            if (mem_dbus_read) state_d = UNCACHE_READ_WAIT_AXI_READY;
            if (mem_dbus_write) state_d = UNCACHE_WRITE_WAIT_AXI_READY;
        end else begin
            if (mem_dbus_read & mem_cache_miss) begin
                if (mem_need_write_back) state_d = WB_WRITE_WAIT_AXI_READY;
                else state_d = READ_WAIT_AXI_READY;
            end
            if (mem_dbus_write & mem_cache_miss) begin
                if (mem_need_write_back) state_d = WB_WRITE_WAIT_AXI_READY;
                else state_d = READ_WAIT_AXI_READY;
            end
        end
        if (mem_memory.invalidate_dcache) begin
            state_d = INVALIDATING;
        end
    end
    // cache states
    // write back from cache to mem
    WB_WRITE_WAIT_AXI_READY: if (dcache_axi_resp.awready) state_d = WB_WRITING;
    WB_WRITING: if (dcache_axi_resp.wready && dcache_axi_req.wlast) state_d = WB_WAIT_BVALID;
    WB_WAIT_BVALID: if (dcache_axi_resp.bvalid) state_d = READ_WAIT_AXI_READY;
    // read from mem to cache
    READ_WAIT_AXI_READY: if (dcache_axi_resp.arready) state_d = READING;
    READING: if (dcache_axi_resp.rvalid & dcache_axi_resp.rlast) state_d = WRITE_CACHE;
    WRITE_CACHE: state_d = IDLE;
    INVALIDATING: state_d = IDLE;
    RST: if (&invalidate_cnt) state_d = IDLE;

    // uncached axi write
    UNCACHE_READ_WAIT_AXI_READY: if (uncached_axi_resp.arready) state_d = UNCACHE_READING;
    UNCACHE_READING: if (uncached_axi_resp.rvalid & uncached_axi_resp.rlast) state_d = UNCACHE_READ_FINISH;
    UNCACHE_READ_FINISH: state_d = IDLE;
    UNCACHE_WRITE_WAIT_AXI_READY: if (uncached_axi_resp.awready) state_d = UNCACHE_WRITING;
    UNCACHE_WRITING: if (uncached_axi_resp.wready) state_d = UNCACHE_WAIT_BVALID;
    UNCACHE_WAIT_BVALID: if (uncached_axi_resp.bvalid) state_d = IDLE;
    default: state_d = IDLE;
    endcase
end

always_ff @(posedge clk) begin
    if (rst) begin
        state <= RST;
        invalidate_cnt <= '0;
        burst_cnt <= '0;
        wb_burst_cnt <= '0;
    end else begin
        state <= state_d;
        invalidate_cnt <= invalidate_cnt_d;
        burst_cnt <= burst_cnt_d;
        wb_burst_cnt <= wb_burst_cnt_d;
    end
end

// axi and cache signals control
always_comb begin
    // read / write is 4 bytes per transfer
    tag_we = '0;
    data_we = '0;
    invalidate_cnt_d = '0;
    burst_cnt_d = '0;
    wb_burst_cnt_d = '0;

    tag_ram_waddr = get_index(mem_dbus_addr);
    data_ram_waddr = get_index(mem_dbus_addr);

    // cached axi requests
    dcache_axi_req = '0;
    dcache_axi_req.arburst = 2'b01;
    dcache_axi_req.awburst = 2'b01;
    dcache_axi_req.arlen = BURST_LIMIT;
    dcache_axi_req.awlen = BURST_LIMIT;
    dcache_axi_req.arsize = 3'b010;
    dcache_axi_req.awsize = 3'b010;
    dcache_axi_req.araddr = { mem_dbus_addr[31:LINE_BYTE_OFFSET], {LINE_BYTE_OFFSET{1'b0}} };
    dcache_axi_req.awaddr = mem_wb_addr;
    dcache_axi_req.wdata = mem_write_back_line[wb_burst_cnt];
    dcache_axi_req.wlast = (wb_burst_cnt == BURST_LIMIT[LINE_BYTE_OFFSET-1:0]);
    dcache_axi_req.wstrb = 4'b1111;
    dcache_axi_req.bready = 1'b1; // ignore bresp
    // uncached axi requests
    uncached_axi_req = '0;
    uncached_axi_req.arburst = 2'b01;
    uncached_axi_req.awburst = 2'b01;
    uncached_axi_req.arlen = 3'b000;
    uncached_axi_req.awlen = 3'b000;
    uncached_axi_req.arsize = 2'b10; // 4 bytes
    uncached_axi_req.awsize = 2'b10;
    uncached_axi_req.araddr = mem_dbus_addr;
    uncached_axi_req.awaddr = mem_dbus_addr;
    uncached_axi_req.wdata = mem_dbus_wdata;
    uncached_axi_req.wstrb = mem_dbus_byteen;
    uncached_axi_req.bready = 1'b1; // CPU一直准备好接收写响应信号
    unique case(state)
    IDLE: begin
        if (mem_dbus_write & ~mem_cache_miss) begin
            tag_we[mem_hit_way_addr] = 1'b1;
            data_we[mem_hit_way_addr] = 1'b1;
        end
    end
    // cached axi requests
    WB_WRITE_WAIT_AXI_READY: begin
        dcache_axi_req.awvalid = 1'b1;
        wb_burst_cnt_d = '0;
    end
    WB_WRITING: begin
        dcache_axi_req.wvalid = 1'b1;
        if (dcache_axi_resp.wready) begin
            wb_burst_cnt_d = wb_burst_cnt + 1;
        end else begin
            wb_burst_cnt_d = wb_burst_cnt;
        end
    end
    READ_WAIT_AXI_READY: begin
        burst_cnt_d = '0;
        dcache_axi_req.arvalid = 1'b1;
    end
    READING: begin
        if (dcache_axi_resp.rvalid) begin
            dcache_axi_req.rready = 1'b1;
            burst_cnt_d = burst_cnt + 1;
        end else begin
            burst_cnt_d = burst_cnt;
        end
    end
    WRITE_CACHE: begin
        tag_we[mem_replace_assoc_addr] = 1'b1;
        data_we[mem_replace_assoc_addr] = 1'b1;
    end
    INVALIDATING: begin
        tag_we = 4'b1111;
    end
    RST: begin
        tag_we = 4'b1111;
        invalidate_cnt_d = invalidate_cnt + 1;
    end

    // uncached axi requests
    UNCACHE_READ_WAIT_AXI_READY: uncached_axi_req.arvalid = 1'b1;
    UNCACHE_READING: begin
        if (uncached_axi_resp.rvalid) begin
            uncached_axi_req.rready = 1'b1;
        end
    end
    UNCACHE_WRITE_WAIT_AXI_READY: uncached_axi_req.awvalid = 1'b1;
    UNCACHE_WRITING: begin
        uncached_axi_req.wvalid = 1'b1; // Write a single transfer
        uncached_axi_req.wlast = 1'b1; // The burst length is 1
    end
    default: begin end // do nothing
    endcase
end

assign invalidate_icache = mem_memory.invalidate_icache;
assign invalidate_addr = mem_memory.addr;

word_t word_mask;
assign word_mask = {
    {8{mem_memory.sel[3]}},
	{8{mem_memory.sel[2]}},
	{8{mem_memory.sel[1]}},
	{8{mem_memory.sel[0]}}
};

// save cacheline received
always_ff @(posedge clk) begin
    if (rst) begin
        cache_line_recv <= '0;
    end else if (state == READING && dcache_axi_resp.rvalid) begin
        cache_line_recv[burst_cnt] <= dcache_axi_resp.rdata;
    end
end
// save uncached data received
always_ff @(posedge clk) begin
    if (rst) begin
        uncache_data_recv <= '0;
    end else if (state == UNCACHE_READING && uncached_axi_resp.rvalid) begin
        uncache_data_recv <= uncached_axi_resp.rdata;
    end
end

// save received data to cache
assign tag_wdata.valid = (state != RST && state != INVALIDATING);
assign tag_wdata.dirty = mem_dbus_write;
assign tag_wdata.tag = get_tag(mem_dbus_addr);
always_comb begin
    if (mem_cache_miss) begin
        data_wdata = cache_line_recv;
        if (mem_dbus_write) begin
            data_wdata[get_offset(mem_dbus_addr)] = (word_mask & mem_dbus_wdata) | (~word_mask & cache_line_recv[get_offset(mem_dbus_addr)]);
        end
    end else begin
        data_wdata = mem_hit_line;
        data_wdata[get_offset(mem_dbus_addr)] = (word_mask & mem_dbus_wdata) | (~word_mask & mem_hit_line[get_offset(mem_dbus_addr)]);
    end   
end

// MEM stage control
assign mem_stall_req = (state_d != IDLE);
assign ready = (state != RST);

// dbus MUX in
word_t data_received;
always_comb begin
    if (mem_uncached) begin
        data_received = uncache_data_recv;
    end else begin
        if (mem_cache_miss) begin
            data_received = cache_line_recv[mem_dbus_addr[LINE_BYTE_OFFSET-1:2]];
        end else begin
            data_received = mem_hit_line[get_offset(mem_dbus_addr)];
        end
    end
end

word_t aligned_rdata;
word_t signed_ext_byte, signed_ext_halfword;
word_t unsigned_ext_byte, unsigned_ext_halfword;
assign aligned_rdata = data_received >> (mem_memory.addr[1:0] * 8);
assign signed_ext_byte = { {24{aligned_rdata[7]}}, aligned_rdata[7:0] };
assign signed_ext_halfword = { {16{aligned_rdata[15]}}, aligned_rdata[15:0] };
assign unsigned_ext_byte = { 24'b0, aligned_rdata[7:0] };
assign unsigned_ext_halfword = { 16'b0, aligned_rdata[15:0] };

// lwl/lwr
word_t unaligned_word_temp, unaligned_word;
always_comb begin: unaligned_load
    if (op == OP_LWL)  begin // lwl
        unaligned_word_temp = data_received << ((3 - mem_memory.addr[1:0]) * 8);
    end else begin // lwr
        unaligned_word_temp = data_received >> (mem_memory.addr[1:0] * 8);
    end
end
// for LWL/LWR, memory_req.wdata = reg2
assign unaligned_word = (unaligned_word_temp & word_mask) | (mem_memory.wdata & ~word_mask);

// assign wdata to wb
always_comb begin: wdata_to_reg
    mem_wp1 = mem_wp_temp;
    `ifdef ENABLE_FPU
    mem_fpu_wr = mem_fpu_wr_temp;
    `endif
    if (mem_memory.ce) begin
        if (mem_memory.we) begin // write memory, save
            if (mem_op == OP_SC) begin
                mem_wp1.we = mem_wp_temp.we;
                mem_wp1.waddr = mem_wp_temp.waddr;
                mem_wp1.wdata = {31'b0, ll_bit_unsafe}; // mem stage dont need llbit data bypass
            end else begin
                mem_wp1.we = 1'b0;
                mem_wp1.waddr = `ZERO_REG_ADDR;
                mem_wp1.wdata = `ZERO_WORD;
            end
            `ifdef ENABLE_FPU
            mem_fpu_wr.we = 1'b0;
            mem_fpu_wr.wdata = '0;
            mem_fpu_wr.waddr = '0;
            `endif
        end else begin // read memory, load
            mem_wp1.we = (mem_op != OP_LWC1);
            mem_wp1.waddr = mem_wp_temp.waddr;
            `ifdef ENABLE_FPU
            mem_fpu_wr.we = (mem_op == OP_LWC1); // load to fpu regs
            mem_fpu_wr.waddr = mem_fpu_wr_temp.waddr;
            mem_fpu_wr.wdata.val = aligned_rdata;
            mem_fpu_wr.wdata.fmt = `FPU_REG_UNINTERPRET;
            `endif
            unique case(mem_op)
            OP_LB: mem_wp1.wdata = signed_ext_byte;
            OP_LBU: mem_wp1.wdata = unsigned_ext_byte;
            OP_LH: mem_wp1.wdata = signed_ext_halfword;
            OP_LHU: mem_wp1.wdata = unsigned_ext_halfword;
            OP_LWL, OP_LWR: mem_wp1.wdata = unaligned_word;
            default: mem_wp1.wdata = aligned_rdata; // LW, LL
            endcase
        end
    end
end

// generate BRAM tag and data cache
for (genvar i = 0; i < SET_ASSOC; ++i) begin: gen_dcache
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
        .enb(~mem_stall_req), // Memory enable signal for port B. Must be high on clock cycles when read or write operations are initiated. Pipelined internally.
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
        .enb(~mem_stall_req), // Memory enable signal for port B. Must be high on clock cycles when read or write operations are initiated. Pipelined internally.
        .addrb(data_ram_raddr), // $clog2(SIZE)-bit input: Address for port B write and read operations.
        .doutb(data_rdata_unsafe[i])  // DATA_WIDTH-bit output: Data output for port B read operations.
    );
end

// generate PLRU replacement policy
for(genvar i = 0; i < GROUP_NUM; ++i) begin: gen_dcache_plru
    plru #(
        .SET_ASSOC (SET_ASSOC)
    ) plru_inst (
        .clk(clk),
        .rst(rst),
        .access(hit),
        .update(lru_update[i] & ~mem_stall_req),

        .lru(lru[i])
    );
end

endmodule
