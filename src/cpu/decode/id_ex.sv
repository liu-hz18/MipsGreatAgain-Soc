`include "defines.svh"

module id_ex (
    input clk, rst,
    // stall and flush
    input stall_t stall,
    input bit_t flush,
    input bit_t in_delayslot_hold,

    // control flow from decode stage
    input bit_t id_branch_flag,
    input word_t id_inst,
    input word_t id_pc,
    input bit_t id_delayslot,
    input word_t id_reg1,
    input word_t id_reg2,
    input word_t id_imm,
    input exOperation_t id_exop,
    input bit_t id_we1,
    input regaddr_t id_waddr1,
    input bit_t id_next_inst_in_delayslot, // from id
    input exceptType_t id_except,
    input doubleword_t id_hilo,
    input inst_type_t id_inst_type,
    `ifdef ENABLE_FPU
    // FPU ctrls
    input fpuOp_t id_fpu_op,
    input regaddr_t id_fpu_raddr1,
    input regaddr_t id_fpu_raddr2,
    input bit_t id_fpu_we,
    input regaddr_t id_fpu_waddr,
    input fcsrReg_t id_fpu_fcsr,
    input fpuReg_t id_fpu_reg1,
    input fpuReg_t id_fpu_reg2,
    `endif

    output bit_t ex_branch_flag,
    output word_t ex_inst,
    output word_t ex_pc,
    output bit_t ex_delayslot,
    output word_t ex_reg1,
    output word_t ex_reg2,
    output word_t ex_imm,
    output exOperation_t ex_exop,
    output bit_t ex_we1,
    output regaddr_t ex_waddr1,
    output doubleword_t ex_hilo,
    output inst_type_t ex_inst_type,
    `ifdef ENABLE_FPU
    output fpuOp_t ex_fpu_op,
    output regaddr_t ex_fpu_raddr1,
    output regaddr_t ex_fpu_raddr2,
    output bit_t ex_fpu_we,
    output regaddr_t ex_fpu_waddr,
    output fcsrReg_t ex_fpu_fcsr,
    output fpuReg_t ex_fpu_reg1,
    output fpuReg_t ex_fpu_reg2,
    `endif
    // to id stage (ring-back)
    output bit_t id_in_delayslot, 
    output exceptType_t idex_except
);

always_ff @(posedge clk) begin
    if (rst || flush || (stall.stall_id && ~stall.stall_ex)) begin
        ex_inst <= `ZERO_WORD;
        ex_pc <= `ZERO_WORD;
        ex_delayslot <= 1'b0;
        ex_reg1 <= `ZERO_WORD;
        ex_reg2 <= `ZERO_WORD;
        ex_imm <= `ZERO_WORD;
        ex_exop <= OP_NOP;
        ex_we1 <= 1'b0;
        ex_waddr1 <= `ZERO_REG_ADDR;
        id_in_delayslot <= 1'b0;
        idex_except <= {$bits(exceptType_t){1'b0}};
        ex_branch_flag <= 1'b0;
        ex_hilo <= '0;
        ex_inst_type <= '0;
        `ifdef ENABLE_FPU
        ex_fpu_op <= FPU_OP_NOP;
        ex_fpu_raddr1 <= `ZERO_REG_ADDR;
        ex_fpu_raddr2 <= `ZERO_REG_ADDR;
        ex_fpu_we <= 1'b0;
        ex_fpu_waddr <= `ZERO_REG_ADDR;
        ex_fpu_fcsr <= {$bits(fcsrReg_t){1'b0}};
        ex_fpu_reg1 <= '0;
        ex_fpu_reg2 <= '0;
        `endif
    end else if (~stall.stall_id) begin
        ex_inst <= id_inst;
        ex_pc <= id_pc;
        ex_delayslot <= id_delayslot;
        ex_reg1 <= id_reg1;
        ex_reg2 <= id_reg2;
        ex_imm <= id_imm;
        ex_exop <= id_exop;
        ex_we1 <= id_we1;
        ex_waddr1 <= id_waddr1;
        ex_hilo <= id_hilo;
        ex_inst_type <= id_inst_type;
        `ifdef ENABLE_FPU
        ex_fpu_op <= id_fpu_op;
        ex_fpu_raddr1 <= id_fpu_raddr1;
        ex_fpu_raddr2 <= id_fpu_raddr2;
        ex_fpu_we <= id_fpu_we;
        ex_fpu_waddr <= id_fpu_waddr;
        ex_fpu_fcsr <= id_fpu_fcsr;
        ex_fpu_reg1 <= id_fpu_reg1;
        ex_fpu_reg2 <= id_fpu_reg2;
        `endif
        if (in_delayslot_hold && id_in_delayslot) begin
            id_in_delayslot <= id_in_delayslot;
        end else begin
            id_in_delayslot <= id_next_inst_in_delayslot;
        end
        idex_except <= id_except;
        ex_branch_flag <= id_branch_flag;
    end
end

endmodule
