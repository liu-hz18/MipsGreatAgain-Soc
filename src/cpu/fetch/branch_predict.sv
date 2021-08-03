`include "defines.svh"

module branch_predictor #(
    parameter int SIZE = 1024
) (
    input logic clk, rst,
    input word_t pc, // in IF-1 stage
    input bit_t stall,
    input bit_t flush,

    // update info from id stage
    input bit_t id_we,
    input word_t id_pc,
    input word_t id_branch_target,
    input bit_t id_jump, // is J-type, must branch, so can change 2-bit to 2'b11 immediately.
    input logic[1:0] id_state,
    input bit_t id_branch_flag,
    input bit_t id_mispredict,

    output bit_t ready,
    output word_t target, // return in next cycle (IF-2 stage) (send to IF-1)
    output bit_t predict_branch_if2, // send to IF-1
    output bit_t predict_branch_if3, // send to ID (return at IF-3)
    output logic[1:0] predict_state, // send to ID (return at IF-3)
    output word_t predict_target_if3
);

localparam INDEX_WIDTH = $clog2(SIZE);
localparam TAG_WIDTH = 32 - INDEX_WIDTH - 2;
localparam LINE_WIDTH = TAG_WIDTH + 32 + 2;

typedef logic [INDEX_WIDTH-1:0] bp_index_t;
typedef logic [TAG_WIDTH-1:0] bp_tag_t;

function bp_index_t get_vaddr_index(input word_t vaddr);
    return vaddr[INDEX_WIDTH+2-1 : 2];
endfunction

function bp_tag_t get_vaddr_tag(input word_t vaddr);
    return vaddr[31 : INDEX_WIDTH+2];
endfunction

typedef logic [LINE_WIDTH-1:0] bp_line_t;
typedef logic [1:0] branch_state_t;

function bp_tag_t get_line_tag(input bp_line_t line);
    return line[LINE_WIDTH-1 : 2+32];
endfunction

function word_t get_line_target(input bp_line_t line);
    return line[2+32-1 : 2];
endfunction

function branch_state_t get_line_state(input bp_line_t line);
    return line[1 : 0];
endfunction


bit_t is_reseting;
bp_index_t reset_addr;
// reset stage (only once)
always_ff @(posedge clk) begin
    if (rst) begin
        is_reseting <= 1'b1;
        reset_addr <= '0;
    end else if (&reset_addr) begin
        is_reseting <= 1'b0;
        reset_addr <= reset_addr; // always stay `1`
    end else begin
        is_reseting <= 1'b1;
        reset_addr <= reset_addr + 1;
    end
end
assign ready = ~is_reseting;

// IF-1 stage
word_t pc_stage2;
bp_index_t vaddr_index;
assign vaddr_index = get_vaddr_index(pc);
bp_tag_t vaddr_tag, vaddr_tag_stage2;
assign vaddr_tag = get_vaddr_tag(pc);

always_ff @(posedge clk) begin
    if (rst || flush || id_mispredict) begin
        vaddr_tag_stage2 <= '0;
        pc_stage2 <= '0;
    end else if (~stall) begin
        vaddr_tag_stage2 <= vaddr_tag;
        pc_stage2 <= pc;
    end
end

// IF-2 stage
// state:
// 00: strongly not taken -> 
// 01: wakely not taken -> 
// 10: wakely taken -> 
// 11: strongly taken ->
bp_line_t linedata_stage2;
bp_tag_t line_tag_stage2;
word_t line_target;
branch_state_t line_state_stage2;
bit_t predict_branch_stage2;
assign line_state_stage2 = get_line_state(linedata_stage2);
assign line_tag_stage2 = get_line_tag(linedata_stage2);
assign line_target = get_line_target(linedata_stage2);
assign predict_branch_if2 = predict_branch_stage2;

always_comb begin
    if (rst || flush || id_mispredict) begin
        predict_branch_stage2 = '0;
        target = { pc_stage2[31:2] + 30'b1, 2'b0 };
    end else if (line_tag_stage2 == vaddr_tag_stage2 && (line_state_stage2 == 2'b10 || line_state_stage2 == 2'b11)) begin
        predict_branch_stage2 = 1'b1;
        target = line_target;
    end else begin
        predict_branch_stage2 = '0;
        target = { pc_stage2[31:2] + 30'b1, 2'b0 };
    end
end

// IF-3 stage
always_ff @(posedge clk) begin
    if (rst || flush || id_mispredict) begin
        predict_state <= '0;
        predict_branch_if3 <= '0;
        predict_target_if3 <= '0;
    end else if (~stall) begin
        predict_state <= line_state_stage2;
        predict_branch_if3 <= predict_branch_stage2;
        predict_target_if3 <= target;
    end
end

// ID stage (write back into BTB)
bit_t we;
bp_index_t id_waddr_index;
bp_tag_t id_wtag;
word_t id_wtarget;
branch_state_t id_wstate;
always_comb begin
    id_waddr_index = get_vaddr_index(id_pc);
    id_wtag = get_vaddr_tag(id_pc);
    id_wtarget = id_branch_target;
    we = id_we;
    if (is_reseting) begin
        id_wstate = 2'b00;
        id_waddr_index = reset_addr;
        id_wtag = '0;
        id_wtarget = '0;
        we = 1'b1;
    end else if (id_jump) begin
        id_wstate = 2'b11;
    end else if (id_branch_flag) begin
        unique case(id_state)
        2'b00: id_wstate = 2'b01;
        2'b01: id_wstate = 2'b10;
        2'b10: id_wstate = 2'b11;
        2'b11: id_wstate = 2'b11;
        default: id_wstate = 2'b00;
        endcase
    end else begin
        unique case(id_state)
        2'b00: id_wstate = 2'b00;
        2'b01: id_wstate = 2'b00;
        2'b10: id_wstate = 2'b01;
        2'b11: id_wstate = 2'b10;
        default: id_wstate = 2'b00;
        endcase
    end
end

bp_line_t id_wdata;
assign id_wdata = { id_wtag, id_wtarget, id_wstate };


// generate BTB of SIZE
simple_dual_port_bram #(
    .DATA_WIDTH(LINE_WIDTH),
    .SIZE(SIZE)
) btb_ram (
    .clk(clk),
    .rst(rst),
    // Port A for write
    .ena(1'b1), // Memory enable signal for port A. Must be high on clock cycles when read or write operations are initiated. Pipelined internally.
    .wea(we),     // 1 bit wide, Write enable vector for port A input data port `dina`
    .addra(id_waddr_index),   // $clog2(SIZE)-bit input: Address for port A write and read operations.
    .dina(id_wdata),    // DATA_WIDTH-bit input: Data input for port A write operations.
    // Port B for read (always)
    .enb(~stall), // Memory enable signal for port B. Must be high on clock cycles when read or write operations are initiated. Pipelined internally.
    .addrb(vaddr_index),   // $clog2(SIZE)-bit input: Address for port B write and read operations.
    .doutb(linedata_stage2)    // DATA_WIDTH-bit output: Data output for port B read operations.
);


endmodule
