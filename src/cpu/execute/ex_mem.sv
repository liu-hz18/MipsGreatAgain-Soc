`include "defines.svh"

module ex_mem (
    input clk, rst,

    input stall_t stall,
    input bit_t flush,

    input bit_t ex_delayslot,
    input exOperation_t ex_op,
    input word_t ex_pc,
    input regWritePort_t ex_wp1,
    input bit_t ex_we_hilo,
    input doubleword_t ex_whilo,
    input memControl_t ex_memory,
    input cp0WriteControl_t ex_cp0_wp,
    input exceptType_t ex_except,
    input mmuResult_t ex_data_mmu_result,
    input tlbControl_t ex_tlb_ctrl,
    input word_t ex_tlbp_index,
    input tlbEntry_t ex_tlbrw_rdata,
    input inst_type_t ex_inst_type,
    `ifdef ENABLE_FPU
    input fcsrReg_t ex_fcsr_wdata,
    input bit_t ex_fcsr_we,
    input fpuRegWriteReq_t ex_fpu_wr,
    input fpuExcept_t ex_fpu_except,
    `endif

    output bit_t mem_delayslot,
    output exOperation_t mem_op,
    output word_t mem_pc,
    output regWritePort_t mem_wp1,
    output bit_t mem_we_hilo,
    output doubleword_t mem_whilo,
    output memControl_t mem_memory,
    output cp0WriteControl_t mem_cp0_wp,
    output exceptType_t mem_except,
    output mmuResult_t mem_data_mmu_result,
    output word_t mem_tlbp_index,
    output tlbEntry_t mem_tlbrw_rdata,
    output inst_type_t mem_inst_type,
    `ifdef ENABLE_FPU
    output fcsrReg_t mem_fcsr_wdata,
    output bit_t mem_fcsr_we,
    output fpuRegWriteReq_t mem_fpu_wr,
    output fpuExcept_t mem_fpu_except,
    `endif
    output tlbControl_t mem_tlb_ctrl
);

always_ff @(posedge clk) begin
    if (rst || flush || (stall.stall_ex && ~stall.stall_mem)) begin
        mem_delayslot <= 1'b0;
        mem_wp1.we <= 1'b0;
        mem_wp1.waddr <= `ZERO_REG_ADDR;
        mem_wp1.wdata <= `ZERO_WORD;
        mem_we_hilo <= 1'b0;
        mem_whilo <= `ZERO_DWORD;
        mem_memory.ce <= 1'b0;
        mem_memory.we <= 1'b0;
        mem_memory.sel <= 1'b0;
        mem_memory.wdata <= `ZERO_WORD;
        mem_memory.addr <= `ZERO_WORD;
        mem_memory.invalidate_icache <= 1'b0;
        mem_memory.invalidate_dcache <= 1'b0;
        mem_op <= OP_NOP;
        mem_cp0_wp.we <= 1'b0;
        mem_cp0_wp.wdata <= `ZERO_WORD;
        mem_cp0_wp.waddr <= `ZERO_REG_ADDR;
        mem_cp0_wp.wsel <= 3'b0;
        mem_except <= {$bits(exceptType_t){1'b0}};
        mem_pc <= `ZERO_WORD;
        mem_tlbp_index <= '0;
        mem_tlbrw_rdata <= '0;
        mem_inst_type <= '0;
        `ifdef ENABLE_FPU
        mem_fcsr_wdata <= {$bits(fcsrReg_t){1'b0}};
        mem_fcsr_we <= 1'b0;
        mem_fpu_wr.we <= 1'b0;
        mem_fpu_wr.waddr <= `ZERO_REG_ADDR;
        mem_fpu_wr.wdata <= {$bits(fpuReg_t){1'b0}};
        mem_fpu_except <= {$bits(fpuExcept_t){1'b0}};
        `endif
        mem_data_mmu_result <= '0;
        mem_tlb_ctrl <= '0;
    end else if (~stall.stall_ex) begin
        mem_delayslot <= ex_delayslot;
        mem_wp1 <= ex_wp1;
        mem_we_hilo <= ex_we_hilo;
        mem_whilo <= ex_whilo;
        mem_memory <= ex_memory;
        mem_op <= ex_op;
        mem_cp0_wp <= ex_cp0_wp;
        mem_except <= ex_except;
        mem_pc <= ex_pc;
        mem_tlbp_index <= ex_tlbp_index;
        mem_tlbrw_rdata <= ex_tlbrw_rdata;
        mem_inst_type <= ex_inst_type;
        `ifdef ENABLE_FPU
        mem_fcsr_wdata <= ex_fcsr_wdata;
        mem_fcsr_we <= ex_fcsr_we;
        mem_fpu_wr <= ex_fpu_wr;
        mem_fpu_except <= ex_fpu_except;
        `endif
        mem_data_mmu_result <= ex_data_mmu_result;
        mem_tlb_ctrl <= ex_tlb_ctrl;
    end
end

endmodule
