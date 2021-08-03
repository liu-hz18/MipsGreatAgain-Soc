`include "defines.svh"

module fetch (
    input rst,
    input word_t pc,
    input bit_t pc_ce,
    input mmuResult_t inst_mmu_result,
    input bit_t stall_req,
    input bit_t flush,
    input bit_t branch_flag,

    output bit_t if_stall_req,
    cpu_ibus_if.master inst_bus
);

exceptType_t if_except;
assign if_stall_req = inst_bus.stall;
assign inst_bus.address = inst_mmu_result.paddr;
assign inst_bus.cpu_if_except = if_except;
assign inst_bus.cpu_pc = pc;
assign inst_bus.branch_flag = branch_flag;
assign inst_bus.flush = flush;
assign inst_bus.stall_req = stall_req;

always_comb begin: except_if
    if_except = '0;
    if_except.iaddr_miss = inst_mmu_result.miss;
    if_except.iaddr_invalid = inst_mmu_result.invalid;
    if_except.iaddr_illegal = inst_mmu_result.illegal || (|pc[1:0]);

    if (rst || ~pc_ce) begin
        inst_bus.read = 1'b0;
    end else begin
        inst_bus.read = 1'b1;
    end
end

endmodule
