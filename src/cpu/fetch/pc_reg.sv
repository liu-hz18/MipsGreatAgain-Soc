`include "defines.svh"

module pc_reg (
    input clk, rst,
    input bit_t ready,
    input stall_t stall,
    input bit_t flush,
    input bit_t hold_pc,
    // jump to exception handler
    input word_t jump_pc,
    // branch
    input bit_t branch_flag,
    input word_t branch_target_addr,
    // branch predict
    input bit_t branch_predict,
    input word_t branch_predict_target,
    output word_t pc,
    output bit_t ce  // 指令存储器使能信号
);

assign ce = ready; // enable PC after invalidating I-CACHE.

always_ff @(posedge clk) begin
    if (rst || ~ce) begin
        pc <= `PC_RESET_VECTOR; // 存储器禁用时PC=0
    end else if (flush) begin
        pc <= jump_pc;
    end else if (branch_flag && ~hold_pc) begin // hold pc to avoid `branch_flag` give the wrong signal.
        pc <= branch_target_addr;
    end else if (branch_predict && ~hold_pc) begin
        pc <= branch_predict_target;
    end else if (~stall.hold_pc) begin
        pc <= {pc[31:2] + 30'b1, 2'b0}; // 存储器使能时PC计数
    end
end

endmodule
