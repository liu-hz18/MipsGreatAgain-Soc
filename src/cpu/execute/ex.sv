`include "defines.svh"

module execute (
    input clk, rst,
    input word_t pc,
    input bit_t flush,
    input bit_t stall_mm,
    input word_t inst,
    // control info from decode stage
    input doubleword_t hilo_i,
    input word_t cp0_rdata_i, // from CP0
    input word_t reg1,
    input word_t reg2,
    input word_t imm,
    input exOperation_t ex_op,
    input inst_type_t inst_type,
    input bit_t we1_i,
    input regaddr_t waddr1_i,
    input exceptType_t idex_except,
    input mmuResult_t data_mmu_result,
    input bit_t user_mode,

    output regaddr_t cp0_raddr, // to CP0
    output logic[2:0] cp0_rsel, // to CP0
    output regWritePort_t wp1_o,
    output bit_t we_hilo,
    output doubleword_t hilo_o,
    output memControl_t memory_o,
    output cp0WriteControl_t cp0_wp_o,
    output tlbControl_t tlb_ctrl_o,

    // exception
    output exceptType_t ex_except,

    `ifdef ENABLE_FPU
    // fpu ports
    input fpuOp_t fpu_op,
    input regaddr_t fpu_raddr1, // from id stage
    input regaddr_t fpu_raddr2,
    input bit_t fpu_we,
    input regaddr_t fpu_waddr,
    input word_t fpu_fccr, // from FCSR module
    input fpuReg_t fpu_reg1, // from fpu regs
    input fpuReg_t fpu_reg2,
    input fcsrReg_t fcsr,
    output fcsrReg_t fcsr_wdata, // to mem stage
    output bit_t fcsr_we,
    output fpuRegWriteReq_t fpu_wr,
    output fpuExcept_t fpu_except,
    `endif

    output bit_t ex_stall_req
);

word_t wdata; // execute result
// just copy to forward
assign wp1_o.we = we1_i;
assign wp1_o.waddr = waddr1_i;
assign wp1_o.wdata = wdata;

assign tlb_ctrl_o.tlbp = inst_type.tlbp_inst;
assign tlb_ctrl_o.tlbr = inst_type.tlbr_inst;
assign tlb_ctrl_o.tlbwi = inst_type.tlbwi_inst;
assign tlb_ctrl_o.tlbwr = inst_type.tlbwr_inst;

// add(u) and sub(u)
word_t add_u, sub_u;
assign add_u = reg1 + reg2; // for ADDI, ADDIU(and alike), reg2 = imm
assign sub_u = reg1 - reg2;
bit_t overflow_add, overflow_sub; // only signed add/sub will use this
assign overflow_add = (reg1[31] == reg2[31]) & (reg1[31] ^ add_u[31]);
assign overflow_sub = (reg1[31] ^ reg2[31]) & (reg1[31] ^ sub_u[31]);
bit_t overflow_expt;
assign overflow_expt = ((ex_op == OP_ADD) & overflow_add) | ((ex_op == OP_SUB) & overflow_sub);

// (un)signed compare
bit_t signed_lt, unsigned_lt;
assign signed_lt = (reg1[31] != reg2[31]) ? reg1[31] : sub_u[31];
assign unsigned_lt = (reg1 < reg2);

// for mem stage
bit_t is_load, is_save;
bit_t is_serial_write;
assign is_serial_write = (memory_o.addr == 32'hbfaf_fff0) & (ex_op == OP_SB);
assign is_load = inst_type.load_inst;
assign is_save = inst_type.store_inst;
`ifdef DISABLE_SERIAL_PORT
assign memory_o.ce = (is_load | is_save) & ~is_serial_write;
assign memory_o.we = is_save & ~is_serial_write;
`else
assign memory_o.ce = is_load | is_save;
assign memory_o.we = is_save;
`endif
assign memory_o.addr = reg1 + imm;
always_comb begin
    memory_o.invalidate_icache = 1'b0;
    memory_o.invalidate_dcache = 1'b0;
    if (ex_op == OP_CACHE) begin
        unique case(inst[20:16])
        5'b00000, 5'b10000:
            memory_o.invalidate_icache = 1'b1;
        5'b00001, 5'b10101:
            memory_o.invalidate_dcache = 1'b1;
        default: memory_o.invalidate_dcache = 1'b0;
        endcase
    end
end
always_comb begin: memory_write_data
    unique case(ex_op)
    OP_LW, OP_SW, OP_LL, OP_SC: begin
        memory_o.sel = 4'b1111;
        memory_o.wdata = reg2;
    end
    OP_LH, OP_LHU, OP_SH: begin
        memory_o.sel = memory_o.addr[1] ? 4'b1100 : 4'b0011;
        memory_o.wdata = memory_o.addr[1] ? (reg2 << 16) : reg2;
    end
    OP_LB, OP_LBU, OP_SB: begin
        memory_o.sel = 4'b0001 << memory_o.addr[1:0];
        memory_o.wdata = reg2 << (memory_o.addr[1:0] * 8);
    end
    OP_LWL: begin
        unique case(memory_o.addr[1:0])
        2'b00:   memory_o.sel = 4'b1000;
        2'b01:   memory_o.sel = 4'b1100;
        2'b10:   memory_o.sel = 4'b1110;
        default: memory_o.sel = 4'b1111; // 2'b11
        endcase
        memory_o.wdata = reg2;
    end
    OP_LWR: begin
        unique case(memory_o.addr[1:0])
        2'b00:   memory_o.sel = 4'b1111;
        2'b01:   memory_o.sel = 4'b0111;
        2'b10:   memory_o.sel = 4'b0011;
        default: memory_o.sel = 4'b0001; // 2'b11
        endcase
        memory_o.wdata = reg2;
    end
    OP_SWL: begin
        unique case(memory_o.addr[1:0])
        2'b00:   memory_o.sel = 4'b0001;
        2'b01:   memory_o.sel = 4'b0011;
        2'b10:   memory_o.sel = 4'b0111;
        default: memory_o.sel = 4'b1111; // 2'b11
        endcase
        memory_o.wdata = reg2 >> ((3 - memory_o.addr[1:0]) * 8);
    end
    OP_SWR: begin
        unique case(memory_o.addr[1:0])
        2'b00:   memory_o.sel = 4'b1111;
        2'b01:   memory_o.sel = 4'b1110;
        2'b10:   memory_o.sel = 4'b1100;
        default: memory_o.sel = 4'b1000; // 2'b11
        endcase
        memory_o.wdata = reg2 << (memory_o.addr[1:0] * 8);
    end
    `ifdef ENABLE_FPU
    OP_SWC1, OP_LWC1: begin
        memory_o.sel = 4'b1111;
		memory_o.wdata = fpu_reg1;
    end
    `endif
    default: begin
        memory_o.sel = 4'b0000;
        memory_o.wdata = `ZERO_WORD;
    end
    endcase
end

// safe HI/LO
doubleword_t hilo_safe;
assign hilo_safe = hilo_i;
// hi,lo
word_t hi, lo;
assign {hi, lo} = hilo_safe;
assign we_hilo = inst_type.write_hilo_inst;

// clz(count leading zero), clo(count leading ones)
word_t clz_cnt, clo_cnt;
ex_bitcount clz_instance(
    .bit_val(1'b0),
	.val(reg1),
	.count(clz_cnt)
);
ex_bitcount clo_instance(
    .bit_val(1'b1),
	.val(reg1),
	.count(clo_cnt)
);
`ifdef ENABLE_EXT_INS
word_t ext_res, ins_res;
ex_ext_ins ext_ins_instance(
    .inst(inst),
    .in1(reg1),
    .in2(reg2),
    .ext(ext_res),
    .ins(ins_res)
);
`endif
// multi cycle mult/div
doubleword_t hilo_ret;
word_t reg_ret;
bit_t multi_cyc_busy;
ex_mult_div ex_mult_div_instance(
    .clk(clk),
    .rst(rst),
    .flush(flush),
    .stall(stall_mm),
    .op(ex_op),
    .reg1(reg1),
    .reg2(reg2),
    .hilo(hilo_safe),
    .inst_type(inst_type),

    .hilo_ret(hilo_ret),
    .reg_ret(reg_ret),
    .is_busy(multi_cyc_busy)
);
assign hilo_o = hilo_ret;

bit_t fpu_busy;
`ifdef ENABLE_FPU
word_t fpu_gpr_ret;
assign fpu_wr.we = fpu_we;
assign fpu_wr.waddr = fpu_waddr;
assign fpu_wr.wdata.fmt = `FPU_REG_UNINTERPRET;
// fpu ops
fpu_ex fpu_ex_instance(
    .clk(clk),
    .rst(rst),
    .flush(flush),
    .stall(stall_mm), // WARN: do fpu need to stall when mem stage have stall request ?
    .op(fpu_op),
    .inst(inst),
    .fcsr(fcsr),
    .fccr(fpu_fccr),
    .gpr1(reg1),
    .gpr2(reg2),
    .fpu_reg1(fpu_reg1),
    .fpu_reg2(fpu_reg2),
    .fcsr_we(fcsr_we),
    .fcsr_wdata(fcsr_wdata),
    .fpu_reg_ret(fpu_wr.wdata.val),
    .gpr_ret(fpu_gpr_ret),
    .fpu_except(fpu_except),
    .fpu_busy(fpu_busy)
);
`else
assign fpu_busy = 1'b0;
`endif
assign ex_stall_req = multi_cyc_busy | fpu_busy;

// CP0 data bypass
assign cp0_raddr = inst[15:11];
assign cp0_rsel = inst[2:0];
assign cp0_wp_o.we = (ex_op == OP_MTC0);
assign cp0_wp_o.wdata = reg2;
assign cp0_wp_o.waddr = inst[15:11];
assign cp0_wp_o.wsel = inst[2:0];

word_t cp0_rdata_safe;
assign cp0_rdata_safe = cp0_rdata_i;

// ALU ops distrubution
always_comb begin: alu_case
    wdata = `ZERO_WORD;
    unique case(ex_op)
    // shift
    OP_SLL, OP_SLLV: wdata = reg2 << reg1[4:0];
    OP_SRL, OP_SRLV: wdata = reg2 >> reg1[4:0];
    OP_SRA, OP_SRAV: wdata = $signed(reg2) >>> reg1[4:0];
    OP_ROR, OP_RORV: wdata = (reg2 >> reg1[4:0]) | (reg2 << (32 - reg1[4:0]));
    // bits ops
    `ifdef ENABLE_EXT_INS
    OP_EXT: wdata = ext_res;
    OP_INS: wdata = ins_res;
    `endif
    OP_SEB: wdata = { {24{reg2[7]}}, reg2[7:0] };
    OP_SEH: wdata = { {16{reg2[15]}}, reg2[15:0] };
    OP_WSBH: wdata = { reg2[23:16], reg2[31:24], reg2[7:0], reg2[15:8] };
    // OP_JR:
    // OP_SYSCALL:
    // OP_BREAK:
    OP_MFHI: wdata = hi;
    OP_MFLO: wdata = lo;
    OP_MUL: wdata = reg_ret;
    // add/sub
    OP_ADD, OP_ADDU: wdata = add_u;
    OP_SUB, OP_SUBU: wdata = sub_u;
    // logical
    OP_AND: wdata = reg1 & reg2;
    OP_OR: wdata = reg1 | reg2;
    OP_XOR: wdata = reg1 ^ reg2;
    OP_NOR: wdata = ~(reg1 | reg2);
    OP_SLT: wdata = signed_lt; // zero extend by verilog
    OP_SLTU: wdata = unsigned_lt; // zero extend by verilog
    OP_LUI: wdata = {imm[15:0], 16'b0};
    // bitcount
    OP_CLZ: wdata = clz_cnt;
    OP_CLO: wdata = clo_cnt;
    
    OP_MFC0: wdata = cp0_rdata_safe; // cp0 data will be write into `wdata` in mem stage, because CP0 data bypass is to complicated !
    // OP_MTC0:
    `ifdef ENABLE_FPU
    OP_MFC1, OP_CFC1: wdata = fpu_gpr_ret;
    `endif
    // OP_ERET:
    // OP_BEQ:
    // OP_BNE:
    // OP_BLEZ:
    // OP_BGTZ:
    // OP_J:
    // OP_BLTZ:
    // OP_BGEZ:
    OP_MOVCI, OP_MOVZ, OP_MOVN: wdata = reg1; // `we` was set in ID stage
    OP_JAL, OP_JALR, OP_BLTZAL, OP_BGEZAL: wdata = pc + 32'd8; // not delay slot(pc+4)
    default: wdata = `ZERO_WORD; // LOAD / STORE ops won't handle in here
    endcase
end

// except
always_comb begin: except_assign
    if (ex_op == OP_NOP) begin
        ex_except = '0;
    end else begin
        ex_except = idex_except;
        ex_except.eret = inst_type.eret_inst;
        ex_except.break_ = inst_type.break_inst;
        ex_except.syscall = inst_type.syscall_inst;
        ex_except.overflow = overflow_expt;
        ex_except.invalid_inst = inst_type.invalid_inst;
        ex_except.priv_inst = inst_type.priv_inst & user_mode;

        unique case(ex_op)
        OP_TEQ: ex_except.trap = (reg1 == reg2);
        OP_TNE: ex_except.trap = (reg1 != reg2);
        OP_TGE: ex_except.trap = ~signed_lt;
        OP_TLT: ex_except.trap = signed_lt;
        OP_TGEU: ex_except.trap = ~unsigned_lt;
        OP_TLTU: ex_except.trap = unsigned_lt;
        default: ex_except.trap = 1'b0;
        endcase

        unique case(ex_op)
        OP_LW, OP_SW, OP_LL, OP_SC, OP_LWC1, OP_SWC1:
            ex_except.daddr_unaligned = memory_o.addr[0] | memory_o.addr[1];
        OP_LH, OP_LHU, OP_SH:
            ex_except.daddr_unaligned = memory_o.addr[0];
        default: ex_except.daddr_unaligned = 1'b0;
        endcase

        ex_except.daddr_miss     = memory_o.ce & data_mmu_result.miss;
        ex_except.daddr_invalid  = memory_o.ce & data_mmu_result.invalid;
        ex_except.daddr_illegal  = memory_o.ce & data_mmu_result.illegal;
        ex_except.daddr_readonly = memory_o.ce & memory_o.we & ~data_mmu_result.dirty;
    end
end

endmodule
