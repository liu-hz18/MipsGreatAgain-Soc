`include "defines.svh"
`include "isa_codes.svh"

`define INST(op, r1, r2, we, w1) \
begin \
    ex_op = op; \
    raddr1 = r1; \
    raddr2 = r2; \
    waddr1 = w1; \
    we1 = we; \
end
`define INST_W(op, r1, r2, w) `INST(op, r1, r2, 1'b1, w)
`define INST_R(op, r1, r2) `INST(op, r1, r2, 1'b0, 5'b0)
`define JUMP_TO(addr) \
    branch_flag_inner = 1'b1; \
    branch_target_addr_inner = addr;
`define FPU_INST(op, fr1, fr2, we, fw) \
begin \
    fpu_op = op; \
    fpu_raddr1 = fr1; \
    fpu_raddr2 = fr2; \
    fpu_we = we; \
    fpu_waddr = fw; \
end
`define FPU_INST_R(op, fr1, fr2) `FPU_INST(op, fr1, fr2, 1'b0, 5'b0)
`define FPU_INST_W(op, fr1, fr2, fw) `FPU_INST(op, fr1, fr2, 1'b1, fw)

// decode stage, comb
module decode (
    input rst,
    
    input word_t pc,
    input word_t inst,
    input bit_t valid,
    input bit_t delayslot_i,
    input bit_t id_branch_predict,
    input word_t id_branch_predict_target,
    
    // read data from forward unit
    input word_t rdata1,
    input word_t rdata2,

    // read/write control to regfile
    output regaddr_t raddr1,
    output regaddr_t raddr2,

    // pipeline informations
    output bit_t delayslot_o,
    // execute control to ex stage
    output word_t pc_o,
    output word_t inst_o,
    output word_t reg1,
    output word_t reg2,
    output word_t imm,
    output exOperation_t ex_op,
    output inst_type_t inst_type,
    // write back control to wb stage
    output bit_t we1,
    output regaddr_t waddr1,

    `ifdef ENABLE_FPU
    // fpu ports
    input fcsrReg_t fpu_fcsr_safe,
    // to ex stage
    output regaddr_t fpu_raddr1,
    output regaddr_t fpu_raddr2,
    output fpuOp_t fpu_op, 
    output bit_t fpu_we,
    output regaddr_t fpu_waddr,
    `endif

    // to IF-1 (PC REG)
    output bit_t branch_flag,
    output word_t branch_target_addr,
    output bit_t next_inst_in_delayslot,
    // to BPU
    output bit_t bpu_we,
    output word_t bpu_branch_target,
    output bit_t bpu_is_jump,
    output bit_t bpu_branch_flag
);

assign pc_o = pc;
assign inst_o = inst;

logic[5:0] opcode;
regaddr_t rs, rd, rt;
halfword_t immediate;
logic[4:0] sa;
logic[5:0] func;
logic[25:0] inst_index;

bit_t branch_flag_inner;
word_t branch_target_addr_inner;
// bpu write control
bit_t is_branch_inst;
assign is_branch_inst = (
    ex_op == OP_BLTZ || ex_op == OP_BGEZ || ex_op == OP_BLTZAL ||
    ex_op == OP_BGEZAL || ex_op == OP_BEQ || ex_op == OP_BNE ||
    ex_op == OP_BLEZ || ex_op == OP_BGTZ || ex_op == OP_BC1
);
bit_t is_jump_inst;
assign is_jump_inst = (
    ex_op == OP_J || ex_op == OP_JR || ex_op == OP_JAL || ex_op == OP_JALR
);
assign bpu_is_jump = is_jump_inst;
assign bpu_we = (is_branch_inst | is_jump_inst) & branch_flag_inner;
assign bpu_branch_target = branch_target_addr_inner;
assign bpu_branch_flag = branch_flag_inner;
bit_t target_diff;
assign target_diff = (branch_target_addr_inner != id_branch_predict_target);
bit_t predict_diff;
assign predict_diff = (branch_flag_inner ^ id_branch_predict);

// inst type assign
`ifdef ENABLE_FPU
assign inst_type.invalid_inst = (ex_op != OP_FPU) ? (ex_op == OP_INVALID) : (fpu_op == FPU_OP_INVALID);
`else
assign inst_type.invalid_inst = (ex_op == OP_INVALID);
`endif
assign inst_type.branch_inst = is_branch_inst;
assign inst_type.jump_inst = is_jump_inst;
assign inst_type.tlbp_inst = (ex_op == OP_TLBP);
assign inst_type.tlbr_inst = (ex_op == OP_TLBR);
assign inst_type.tlbwi_inst = (ex_op == OP_TLBWI);
assign inst_type.tlbwr_inst = (ex_op == OP_TLBWR);
assign inst_type.load_inst = (
	ex_op == OP_LB  || ex_op == OP_LBU || ex_op == OP_LH  || ex_op == OP_LL ||
	ex_op == OP_LHU || ex_op == OP_LW  || ex_op == OP_LWL || ex_op == OP_LWR ||
	ex_op == OP_LWC1
);
assign inst_type.store_inst = (
	ex_op == OP_SB  || ex_op == OP_SH  || ex_op == OP_SW ||
	ex_op == OP_SWL || ex_op == OP_SWR || ex_op == OP_SC ||
	ex_op == OP_SWC1
);
assign inst_type.write_hilo_inst = (
	ex_op == OP_MTHI  || ex_op == OP_MTLO  ||
	ex_op == OP_MADDU || ex_op == OP_MSUBU ||
	ex_op == OP_MADD  || ex_op == OP_MSUB  ||
	ex_op == OP_MULT  || ex_op == OP_MULTU ||
	ex_op == OP_DIV   || ex_op == OP_DIVU
);
assign inst_type.priv_inst = (
    ex_op == OP_CACHE || ex_op == OP_ERET || ex_op == OP_MFC0 ||
    ex_op == OP_MTC0  || ex_op == OP_TLBP || ex_op == OP_TLBR ||
    ex_op == OP_TLBWI || ex_op == OP_TLBWR || ex_op == OP_WAIT
);
assign inst_type.eret_inst = (ex_op == OP_ERET);
assign inst_type.break_inst = (ex_op == OP_BREAK);
assign inst_type.syscall_inst = (ex_op == OP_SYSCALL);
assign inst_type.multi_cyc_inst = (
	ex_op == OP_MADD || ex_op == OP_MADDU || ex_op == OP_MSUB || ex_op == OP_MSUBU ||
	ex_op == OP_MUL || ex_op == OP_MULT || ex_op == OP_MULTU || ex_op == OP_DIV || ex_op == OP_DIVU ||
	ex_op == OP_MFC0 || ex_op == OP_MTHI || ex_op == OP_MTLO
);
assign inst_type.signed_multi_cyc_inst = (
	ex_op == OP_MADD || ex_op == OP_MSUB || ex_op == OP_MUL  ||
	ex_op == OP_MULT || ex_op == OP_DIV
);
assign inst_type.ll_inst = (ex_op == OP_LL);
assign inst_type.sc_inst = (ex_op == OP_SC);
assign inst_type.unaligned_inst = (
    ex_op == OP_LWL | ex_op == OP_LWR | ex_op == OP_SWL | ex_op == OP_SWR
);

// solve j-type insts bug.
always_comb begin
    if (is_branch_inst) begin
        branch_flag = predict_diff;
    end else if (is_jump_inst) begin
        branch_flag = target_diff;
    end else begin
        branch_flag = '0;
    end
end
assign branch_target_addr = branch_flag_inner ? branch_target_addr_inner : pc + 32'h8;

// I-type:
// opcode | rs | rt | imm
// J-type:
// opcode | inst_index
// R-type:
// opcode | rs | rt | rd | sa | func
assign opcode = inst[31:26];
assign rs = inst[25:21];
assign rt = inst[20:16];
assign rd = inst[15:11];
assign sa = inst[10:6];
assign func = inst[5:0];
assign immediate = inst[15:0];
assign inst_index = inst[25:0];

// generate imm
word_t imm_zero_ext, imm_sign_ext;
assign imm_zero_ext = { 16'h0, immediate };
assign imm_sign_ext = { {16{immediate[15]}}, immediate };
bit_t unsigned_imm;
assign unsigned_imm = (
    opcode == `OPCODE_ANDI || // andi
    opcode == `OPCODE_ORI  || // ori
    opcode == `OPCODE_XORI || // xori
    opcode == `OPCODE_LUI     // lui
);
assign imm = unsigned_imm ? imm_zero_ext : imm_sign_ext;

// shift number `sa`
bit_t shift_const;
assign shift_const = ( opcode == `OPCODE_R && (
    func == `FUNC_SLL || func == `FUNC_SRL || func == `FUNC_SRA
));

// movz and movn set
bit_t fcc_match;
`ifdef ENABLE_FPU
assign fcc_match = fpu_fcsr_safe.fcc[inst[20:18]] == inst[16]; // include movt and movf.
`else
assign fcc_match = 1'b0;
`endif
bit_t rt_zero;
assign rt_zero = (reg2 == `ZERO_WORD);
bit_t movz_we, movn_we, movci_we;
assign movz_we = (ex_op == OP_MOVZ) && rt_zero;
assign movn_we = (ex_op == OP_MOVN) && (~rt_zero);
assign movci_we = (ex_op == OP_MOVCI) && (~fcc_match);

// branch
word_t pc_plus4;
assign pc_plus4 = { pc[31:2] + 30'b1, 2'b0 };
assign delayslot_o = delayslot_i;

always_comb begin: decode_case
    `INST(OP_NOP, `ZERO_REG_ADDR, `ZERO_REG_ADDR, 1'b0, `ZERO_REG_ADDR)
    branch_flag_inner = 1'b0;
    branch_target_addr_inner = `ZERO_WORD;
    next_inst_in_delayslot = 1'b0;
    if (valid) begin
        unique case(opcode)
        // R-type
        `OPCODE_R: begin
            unique case(func)
            // shift
            `FUNC_SLL: `INST_W(OP_SLL, 5'b0, rt, rd) // rs is not used, but can be read.
            `FUNC_SRL: begin
                if (rs[0]) begin
                    `INST_W(OP_ROR, 5'b0, rt, rd) // rs is not used, but can be read.
                end else begin
                    `INST_W(OP_SRL, 5'b0, rt, rd) // rs is not used, but can be read.
                end
            end
            `FUNC_SRA: `INST_W(OP_SRA, 5'b0, rt, rd)
            `FUNC_SLLV: `INST_W(OP_SLLV, rs, rt, rd)
            `FUNC_SRLV: begin
                if (inst[6]) begin
                    `INST_W(OP_RORV, rs, rt, rd)
                end else begin
                    `INST_W(OP_SRLV, rs, rt, rd)
                end
            end
            `FUNC_SRAV: `INST_W(OP_SRAV, rs, rt, rd)
            // jump from reg
            `FUNC_JR: begin
                `INST_R(OP_JR, rs, 5'b0) // pc <- rs
                next_inst_in_delayslot = 1'b1;
                `JUMP_TO(reg1);
            end
            `FUNC_JALR: begin
                `INST_W(OP_JALR, rs, 5'b0, rd) // rd <- ra, pc <- rs
                next_inst_in_delayslot = 1'b1;
                `JUMP_TO(reg1);
            end
            // move
            `FUNC_MOVCI: `INST(OP_MOVCI, rs, 5'b0, movci_we, rd)
            `FUNC_MOVZ: `INST(OP_MOVZ, rs, rt, movz_we, rd)
            `FUNC_MOVN: `INST(OP_MOVN, rs, rt, movn_we, rd)
            // breakpoint and syscall
            `FUNC_SYSCALL: `INST_R(OP_SYSCALL, 5'b0, 5'b0)
            `FUNC_BREAK: `INST_R(OP_BREAK, 5'b0, 5'b0)
            // move f/t hilo
            `FUNC_MFHI: `INST_W(OP_MFHI, 5'b0, 5'b0, rd)
            `FUNC_MTHI: `INST_R(OP_MTHI, rs, 5'b0)
            `FUNC_MFLO: `INST_W(OP_MFLO, 5'b0, 5'b0, rd)
            `FUNC_MTLO: `INST_R(OP_MTLO, rs, 5'b0)
            // mult and div
            `FUNC_MULT: `INST_R(OP_MULT, rs, rt)
            `FUNC_MULTU: `INST_R(OP_MULTU, rs, rt)
            `FUNC_DIV: `INST_R(OP_DIV, rs, rt)
            `FUNC_DIVU: `INST_R(OP_DIVU, rs, rt)
            // add and sub
            `FUNC_ADD: `INST_W(OP_ADD, rs, rt, rd)
            `FUNC_ADDU: `INST_W(OP_ADDU, rs, rt, rd)
            `FUNC_SUB: `INST_W(OP_SUB, rs, rt, rd)
            `FUNC_SUBU: `INST_W(OP_SUBU, rs, rt, rd)
            // logics
            `FUNC_AND: `INST_W(OP_AND, rs, rt, rd)
            `FUNC_OR: `INST_W(OP_OR, rs, rt, rd)
            `FUNC_XOR: `INST_W(OP_XOR, rs, rt, rd)
            `FUNC_NOR: `INST_W(OP_NOR, rs, rt, rd)
            `FUNC_SLT: `INST_W(OP_SLT, rs, rt, rd)
            `FUNC_SLTU: `INST_W(OP_SLTU, rs, rt, rd)
            // nops
            `FUNC_SYNC: `INST_R(OP_NOP, 5'b0, 5'b0)
            // traps
            `FUNC_TGE: `INST_R(OP_TGE, rs, rt)
            `FUNC_TGEU: `INST_R(OP_TGEU, rs, rt)
            `FUNC_TLT: `INST_R(OP_TLT, rs, rt)
            `FUNC_TLTU: `INST_R(OP_TLTU, rs, rt)
            `FUNC_TEQ: `INST_R(OP_TEQ, rs, rt)
            `FUNC_TNE: `INST_R(OP_TNE, rs, rt)
            default: ex_op = OP_INVALID;
            endcase
        end
        // (I-type) bgez, bltz, bltzal, bgezal
        `OPCODE_B: begin
            unique case(rt)
            `BFUNC_BLTZ: begin
                `INST_R(OP_BLTZ, rs, 5'b0)
                next_inst_in_delayslot = 1'b1;
                if (reg1[31] == 1'b1) begin
                    `JUMP_TO(pc_plus4 + { imm_sign_ext[29:0], 2'b00 });
                end
            end
            `BFUNC_BGEZ: begin
                `INST_R(OP_BGEZ, rs, 5'b0)
                next_inst_in_delayslot = 1'b1;
                if (reg1[31] == 1'b0) begin
                    `JUMP_TO(pc_plus4 + { imm_sign_ext[29:0], 2'b00 });
                end
            end
            `BFUNC_BLTZAL: begin
                `INST_W(OP_BLTZAL, rs, 5'b0, 5'd31)
                next_inst_in_delayslot = 1'b1;
                if (reg1[31] == 1'b1) begin
                    `JUMP_TO(pc_plus4 + { imm_sign_ext[29:0], 2'b00 });
                end
            end
            `BFUNC_BGEZAL: begin
                `INST_W(OP_BGEZAL, rs, 5'b0, 5'd31)
                next_inst_in_delayslot = 1'b1;
                if (reg1[31] == 1'b0) begin
                    `JUMP_TO(pc_plus4 + { imm_sign_ext[29:0], 2'b00 });
                end
            end
            // traps
            `BFUNC_TGEI: `INST_R(OP_TGE, rs, 5'b0)
            `BFUNC_TGEIU: `INST_R(OP_TGEU, rs, 5'b0)
            `BFUNC_TLTI: `INST_R(OP_TLT, rs, 5'b0)
            `BFUNC_TLTIU: `INST_R(OP_TLTU, rs, 5'b0)
            `BFUNC_TEQI: `INST_R(OP_TEQ, rs, 5'b0)
            `BFUNC_TNEI: `INST_R(OP_TNE, rs, 5'b0)
            default: ex_op = OP_INVALID;
            endcase
        end
        // J-type
        `OPCODE_J: begin
            ex_op = OP_J;
            next_inst_in_delayslot = 1'b1;
            `JUMP_TO({ pc_plus4[31:28], inst_index, 2'b00 });
        end
        `OPCODE_JAL: begin
            `INST_W(OP_JAL, 5'd0, 5'b0, 5'd31) // write pc+8 to $31
            next_inst_in_delayslot = 1'b1;
            `JUMP_TO({ pc_plus4[31:28], inst_index, 2'b00 });
        end
        // branch (I-type)
        `OPCODE_BEQ: begin
            `INST_R(OP_BEQ, rs, rt)
            next_inst_in_delayslot = 1'b1;
            if (reg1 == reg2) begin
                `JUMP_TO(pc_plus4 + { imm_sign_ext[29:0], 2'b00 });
            end
        end
        `OPCODE_BNE: begin
            `INST_R(OP_BNE, rs, rt)
            next_inst_in_delayslot = 1'b1;
            if (reg1 != reg2) begin
                `JUMP_TO(pc_plus4 + { imm_sign_ext[29:0], 2'b00 });
            end
        end
        `OPCODE_BLEZ: begin
            `INST_R(OP_BLEZ, rs, 5'b0)  // rt = 0
            next_inst_in_delayslot = 1'b1;
            if (reg1[31] == 1'b1 || (reg1 == `ZERO_WORD)) begin
                `JUMP_TO(pc_plus4 + { imm_sign_ext[29:0], 2'b00 });
            end
        end
        `OPCODE_BGTZ: begin
            `INST_R(OP_BGTZ, rs, 5'b0)  // rt = 0
            next_inst_in_delayslot = 1'b1;
            if (reg1[31] == 1'b0 && (reg1 != `ZERO_WORD)) begin
                `JUMP_TO(pc_plus4 + { imm_sign_ext[29:0], 2'b00 });
            end
        end
        // I-types
        `OPCODE_ADDI: `INST_W(OP_ADD, rs, 5'b0, rt)
        `OPCODE_ADDIU: `INST_W(OP_ADDU, rs, 5'b0, rt)
        `OPCODE_SLTI: `INST_W(OP_SLT, rs, 5'b0, rt)
        `OPCODE_SLTIU: `INST_W(OP_SLTU, rs, 5'b0, rt)
        `OPCODE_ANDI: `INST_W(OP_AND, rs, 5'b0, rt)
        `OPCODE_ORI: `INST_W(OP_OR, rs, 5'b0, rt)
        `OPCODE_XORI: `INST_W(OP_XOR, rs, 5'b0, rt)
        `OPCODE_LUI: `INST_W(OP_LUI, 5'b0, 5'b0, rt)
        // priotity insts, I-type
        `OPCODE_PRIO: begin
            unique case(rs)
            `PRIO_MFC0: `INST_W(OP_MFC0, 5'b0, 5'b0, rt)
            `PRIO_MTC0: `INST_R(OP_MTC0, 5'b0, rt)
            `PRIO_ERET: begin 
                unique case(func)
                `FUNC_ERET: `INST_R(OP_ERET, 5'b0, 5'b0)
                `FUNC_TLBR: `INST_R(OP_TLBR, 5'b0, 5'b0)
                `FUNC_TLBWI: `INST_R(OP_TLBWI, 5'b0, 5'b0)
                `FUNC_TLBWR: `INST_R(OP_TLBWR, 5'b0, 5'b0)
                `FUNC_TLBP: `INST_R(OP_TLBP, 5'b0, 5'b0)
                `FUNC_WAIT: `INST_R(OP_NOP, 5'b0, 5'b0) // wait -> nop
                default: ex_op = OP_INVALID;
                endcase
            end
            default: ex_op = OP_INVALID;
            endcase
        end
        `ifdef ENABLE_FPU
        `OPCODE_COP1: begin
            unique case(rs)
            `COP1_MFC1: `INST_W(OP_MFC1, 5'b0, 5'b0, rt)
            `COP1_CFC1: `INST_W(OP_CFC1, 5'b0, 5'b0, rt)
            `COP1_MTC1: `INST_R(OP_MTC1, 5'b0, rt)
            `COP1_CTC1: `INST_R(OP_CTC1, 5'b0, rt)
            `COP1_BC1: begin
                if (~inst[17]) begin // for bc1t and bc1f
                    `INST_R(OP_BC1, 5'b0, 5'b0)
                    next_inst_in_delayslot = 1'b1;
                    if (fcc_match) begin
                        `JUMP_TO(pc_plus4 + { imm_sign_ext[29:0], 2'b00 });
                    end
                end else begin // for bc1fl and bc1tl, not implemented.
                    ex_op = OP_INVALID;
                end
            end
            `COP1_ALUS: begin
                `INST_R(OP_FPU, 5'b0, 5'b0)
                if (inst[5:1] == 5'b01001) raddr2 = rt; // movz, movn
            end
            default: `INST_R(OP_FPU, 5'b0, 5'b0)
            endcase
        end
        `endif
        `OPCODE_COUNT: begin
            unique case(func)
            // add/sub after mul
            `FUNC_MADD: `INST_R(OP_MADD, rs, rt)  // rd = 0
            `FUNC_MADDU: `INST_R(OP_MADDU, rs, rt)  // rd = 0
            `FUNC_MSUB: `INST_R(OP_MSUB, rs, rt)  // rd = 0
            `FUNC_MSUBU: `INST_R(OP_MSUBU, rs, rt)  // rd = 0
            `FUNC_MUL: `INST_W(OP_MUL, rs, rt, rd)
            // bit count
            `FUNC_CLZ: `INST_W(OP_CLZ, rs, 5'b0, rd)
            `FUNC_CLO: `INST_W(OP_CLO, rs, 5'b0, rd)
            default: ex_op = OP_INVALID;
            endcase
        end
        `OPCODE_BITS: begin
            unique case(func)
            `ifdef ENABLE_EXT_INS
            `FUNC_EXT: `INST_W(OP_EXT, rs, 5'b0, rt)
            `FUNC_INS: `INST_W(OP_INS, rs, rt, rt)
            `endif
            `FUNC_BITS: begin
                unique case(sa)
                `SAFUNC_WSBH: `INST_W(OP_WSBH, 5'b0, rt, rd)
                `SAFUNC_SEB: `INST_W(OP_SEB, 5'b0, rt, rd)
                `SAFUNC_SEH: `INST_W(OP_SEH, 5'b0, rt, rd)
                default: ex_op = OP_INVALID;
                endcase
            end
            default: ex_op = OP_INVALID;
            endcase // case func
        end
        // load (I-type)
        `OPCODE_LB: `INST_W(OP_LB, rs, 5'b0, rt) // rt <- mem[rs + signed(offset)]
        `OPCODE_LH: `INST_W(OP_LH, rs, 5'b0, rt)
        `OPCODE_LWL: `INST_W(OP_LWL, rs, rt, rt)
        `OPCODE_LW: `INST_W(OP_LW, rs, 5'b0, rt)
        `OPCODE_LBU: `INST_W(OP_LBU, rs, 5'b0, rt)
        `OPCODE_LHU: `INST_W(OP_LHU, rs, 5'b0, rt)
        `OPCODE_LWR: `INST_W(OP_LWR, rs, rt, rt)
        // store (I-type)
        `OPCODE_SB: `INST_R(OP_SB, rs, rt)
        `OPCODE_SH: `INST_R(OP_SH, rs, rt)
        `OPCODE_SWL: `INST_R(OP_SWL, rs, rt)
        `OPCODE_SW: `INST_R(OP_SW, rs, rt)
        `OPCODE_SWR: `INST_R(OP_SWR, rs, rt)
        // cache op
        `OPCODE_CACHE: `INST_R(OP_CACHE, 5'b0, 5'b0)
        // load and links
        `OPCODE_LL: `INST_W(OP_LL, rs, 5'b0, rt)
        `OPCODE_SC: `INST_W(OP_SC, rs, rt, rt)
        `ifdef ENABLE_FPU
        `OPCODE_LWC1: `INST_R(OP_LWC1, rs, 5'b0)
        `OPCODE_SWC1: `INST_R(OP_SWC1, rs, 5'b0)
        `endif
        // nops
        `OPCODE_PREF: `INST_R(OP_NOP, 5'b0, 5'b0)
        default: ex_op = OP_INVALID;
        endcase
    end else begin
        ex_op = OP_NOP;
    end
end

`ifdef ENABLE_FPU
// fpu decode case
regaddr_t ft, fs, fd;
assign ft = inst[20:16];
assign fs = inst[15:11];
assign fd = inst[10:6];
always_comb begin: fpu_op_assign
    `FPU_INST(FPU_OP_NOP, `ZERO_REG_ADDR, `ZERO_REG_ADDR, 1'b0, `ZERO_REG_ADDR)
    unique case(opcode)
    `OPCODE_LWC1: `FPU_INST_W(FPU_OP_LW, 5'b0, 5'b0, ft)
    `OPCODE_SWC1: `FPU_INST_R(FPU_OP_SW, ft, 5'b0)
    `OPCODE_COP1: begin
        unique case(rs)
        `COP1_MFC1: `FPU_INST_R(FPU_OP_MFC, 5'b0, fs)
        `COP1_CFC1: `FPU_INST_R(FPU_OP_CFC, 5'b0, fs)
        `COP1_MTC1: `FPU_INST_W(FPU_OP_MTC, 5'b0, 5'b0, fs)
        `COP1_CTC1: `FPU_INST_W(FPU_OP_CTC, 5'b0, 5'b0, fs)
        `COP1_BC1:  `FPU_INST_R(FPU_OP_NOP, 5'b0, 5'b0)
        `COP1_ALUS: begin
            unique casez(func)
            `FUNC_FPU_ADD: `FPU_INST_W(FPU_OP_ADD, fs, ft, fd)
            `FUNC_FPU_SUB: `FPU_INST_W(FPU_OP_SUB, fs, ft, fd)
            `FUNC_FPU_MUL: `FPU_INST_W(FPU_OP_MUL, fs, ft, fd)
            `FUNC_FPU_DIV: `FPU_INST_W(FPU_OP_DIV, fs, ft, fd)
            `FUNC_FPU_SQRT: `FPU_INST_W(FPU_OP_SQRT, fs, ft, fd)
            `FUNC_FPU_ABS: `FPU_INST_W(FPU_OP_ABS, fs, ft, fd)
            `FUNC_FPU_MOV: `FPU_INST_W(FPU_OP_MOV, fs, ft, fd)
            `FUNC_FPU_NEG: `FPU_INST_W(FPU_OP_NEG, fs, ft, fd)
            `FUNC_FPU_ROUND: `FPU_INST_W(FPU_OP_ROUND, fs, ft, fd)
            `FUNC_FPU_TRUNC: `FPU_INST_W(FPU_OP_TRUNC, fs, ft, fd)
            `FUNC_FPU_CEIL: `FPU_INST_W(FPU_OP_CEIL, fs, ft, fd)
            `FUNC_FPU_FLOOR: `FPU_INST_W(FPU_OP_FLOOR, fs, ft, fd)
            `FUNC_FPU_CMOV: `FPU_INST(FPU_OP_CMOV, fs, 5'b0, fcc_match, fd) // movt and movf
            `FUNC_FPU_MOVZ: `FPU_INST(FPU_OP_CMOV, fs, 5'b0,  rt_zero, fd)
            `FUNC_FPU_MOVN: `FPU_INST(FPU_OP_CMOV, fs, 5'b0, ~rt_zero, fd)
            `FUNC_FPU_CVTW: `FPU_INST_W(FPU_OP_CVTW, fs, ft, fd)
            `FUNC_FPU_COND: begin
                if (inst[7:6] == 2'b0) begin
                    `FPU_INST_R(FPU_OP_COND, fs, ft) // c.cond.s
                end else begin // cabs.cond.s is not supported. (MIPS-3D)
                    fpu_op = FPU_OP_INVALID;
                end
            end
            default: fpu_op = FPU_OP_INVALID;
            endcase
        end
        `COP1_ALUW: begin
            unique case(func)
            `FUNC_FPU_CVTS: `FPU_INST_W(FPU_OP_CVTS, fs, ft, fd)
            default: fpu_op = FPU_OP_INVALID;
            endcase
        end
        default: fpu_op = FPU_OP_INVALID;
        endcase
    end
    default: fpu_op = FPU_OP_NOP;
    endcase
end
`endif

always_comb begin: reg_imm_mux
    reg1 = rdata1;
    if (shift_const) begin
        reg1 = {27'b0, sa};
    end

    reg2 = rdata2;
    if (opcode[5:3] == 3'b001 || opcode == 6'b000001) begin
        // attention: load/store ops is I-type but use `rt` field as destination(not `rd`!), 
        // so we won't assign `reg2` as imm, because `reg2` represent for `rt`.
        reg2 = imm;
    end
end

endmodule
