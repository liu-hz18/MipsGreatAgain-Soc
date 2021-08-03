`ifndef ISA_CODES_SVH
`define ISA_CODES_SVH

// Decode(Instruction formats)
// opcodes inst[31:26] 6bits
// opcode 0 ~ 16
`define OPCODE_R     6'b000000 // R-type ops: add, addu, sub, subu, slt, sltu, div, divu, mult, multu, and, nor, or, sll, sllv, sra, srav, srl, srlv, jr, jalr, mfhi, mflo, mthi, mtlo, break, syscall
`define OPCODE_B     6'b000001 // B ops: bgez, bltz, bltzal, bgezal (I-type)
`define OPCODE_J     6'b000010 // j (J-type)
`define OPCODE_JAL   6'b000011 // jal (J-type)
`define OPCODE_BEQ   6'b000100 // beq (I-type)
`define OPCODE_BNE   6'b000101 // bne (I-type)
`define OPCODE_BLEZ  6'b000110 // blez (I-type)
`define OPCODE_BGTZ  6'b000111 // bgtz (I-type)
`define OPCODE_ADDI  6'b001000 // I-type ops
`define OPCODE_ADDIU 6'b001001
`define OPCODE_SLTI  6'b001010
`define OPCODE_SLTIU 6'b001011
`define OPCODE_ANDI  6'b001100
`define OPCODE_ORI   6'b001101
`define OPCODE_XORI  6'b001110
`define OPCODE_LUI   6'b001111 // I-type end
`define OPCODE_PRIO  6'b010000 // priority ops: eret, mfc0, mtc0, wait (R-type)
`define OPCODE_COP1  6'b010001 // co-processor 1: fpu
`define OPCODE_COUNT 6'b011100 // clz, clo, madd, maddu, msub, msubu, mul
`define OPCODE_BITS  6'b011111 // seb, seh, wsbh, ins, ext
// opcodes about mem ops
`define OPCODE_LB    6'b100000 // I-type ops
`define OPCODE_LH    6'b100001
`define OPCODE_LWL   6'b100010
`define OPCODE_LW    6'b100011
`define OPCODE_LBU   6'b100100
`define OPCODE_LHU   6'b100101
`define OPCODE_LWR   6'b100110
`define OPCODE_SB    6'b101000
`define OPCODE_SH    6'b101001
`define OPCODE_SWL   6'b101010
`define OPCODE_SW    6'b101011 // I-type end
`define OPCODE_SWR   6'b101110
`define OPCODE_CACHE 6'b101111
`define OPCODE_LL    6'b110000
`define OPCODE_LWC1  6'b110001
`define OPCODE_SC    6'b111000
`define OPCODE_SWC1  6'b111001
`define OPCODE_PREF  6'b110011

// function inst[5:0] 6bits
`define FUNC_SLL     6'b000000
`define FUNC_MOVCI   6'b000001
`define FUNC_SRL     6'b000010
`define FUNC_SRA     6'b000011
`define FUNC_SLLV    6'b000100
`define FUNC_SRLV    6'b000110
`define FUNC_SRAV    6'b000111
`define FUNC_JR      6'b001000
`define FUNC_JALR    6'b001001
`define FUNC_MOVZ    6'b001010
`define FUNC_MOVN    6'b001011
`define FUNC_SYSCALL 6'b001100
`define FUNC_BREAK   6'b001101
`define FUNC_SYNC    6'b001111
`define FUNC_MFHI    6'b010000
`define FUNC_MTHI    6'b010001
`define FUNC_MFLO    6'b010010
`define FUNC_MTLO    6'b010011
`define FUNC_MULT    6'b011000
`define FUNC_MULTU   6'b011001
`define FUNC_DIV     6'b011010
`define FUNC_DIVU    6'b011011
`define FUNC_ADD     6'b100000
`define FUNC_CLZ     6'b100000
`define FUNC_ADDU    6'b100001
`define FUNC_CLO	 6'b100001
`define FUNC_SUB     6'b100010
`define FUNC_SUBU    6'b100011
`define FUNC_AND     6'b100100
`define FUNC_OR      6'b100101
`define FUNC_XOR     6'b100110
`define FUNC_NOR     6'b100111
`define FUNC_SLT     6'b101010
`define FUNC_SLTU    6'b101011
`define FUNC_WAIT    6'b100000
`define FUNC_MADD    6'b000000
`define FUNC_MADDU   6'b000001
`define FUNC_MSUB    6'b000100
`define FUNC_MSUBU   6'b000101
`define FUNC_MUL     6'b000010
`define FUNC_EXT     6'b000000
`define FUNC_INS     6'b000100
`define FUNC_BITS    6'b100000
`define FUNC_TGE     6'b110000 // R-type trap ops
`define FUNC_TGEU    6'b110001
`define FUNC_TLT     6'b110010
`define FUNC_TLTU    6'b110011
`define FUNC_TEQ	 6'b110100
`define FUNC_TNE     6'b110101
// tlbs ops
`define FUNC_ERET    6'b011000
`define FUNC_TLBR    6'b000001
`define FUNC_TLBWI   6'b000010
`define FUNC_TLBWR   6'b000110
`define FUNC_TLBP    6'b001000
// fpu func
`define FUNC_FPU_ADD 6'b000000
`define FUNC_FPU_SUB 6'b000001
`define FUNC_FPU_MUL 6'b000010
`define FUNC_FPU_DIV 6'b000011
`define FUNC_FPU_SQRT 6'b000100
`define FUNC_FPU_ABS 6'b000101
`define FUNC_FPU_MOV 6'b000110
`define FUNC_FPU_NEG 6'b000111
`define FUNC_FPU_ROUND 6'b001100
`define FUNC_FPU_TRUNC 6'b001101
`define FUNC_FPU_CEIL 6'b001110
`define FUNC_FPU_FLOOR 6'b001111
`define FUNC_FPU_CMOV 6'b010001
`define FUNC_FPU_MOVZ 6'b010010
`define FUNC_FPU_MOVN 6'b010011
`define FUNC_FPU_CVTW 6'b100100
`define FUNC_FPU_COND 6'b11???? // eq(50), ueq(51), olt(52), ult(53), ole(54), ule(55), sf(56), ngle(57), seq(58), ngl(59), lt(60), nge(61), le(62), ngt(63) 
`define FUNC_FPU_CVTS 6'b100000

// `sa` region for bits ops. wsbh, seb, seh
`define SAFUNC_WSBH  5'b00010
`define SAFUNC_SEB   5'b10000
`define SAFUNC_SEH   5'b11000

// `rt` region for I-types, especially BEQ, BNE... inst[20:16] 5bits
// bgez, bltz, bltzal, bgezal
`define BFUNC_BLTZ   5'b00000
`define BFUNC_BGEZ   5'b00001
`define BFUNC_BLTZAL 5'b10000
`define BFUNC_BGEZAL 5'b10001
`define BFUNC_TGEI   5'b01000
`define BFUNC_TGEIU  5'b01001
`define BFUNC_TLTI   5'b01010
`define BFUNC_TLTIU  5'b01011
`define BFUNC_TEQI   5'b01100
`define BFUNC_TNEI   5'b01110

// `rs` region for priotity ops, e.g. eret, mfc0, mtc0. inst[25:21] 5bits
`define PRIO_MFC0    5'b00000
`define PRIO_MTC0    5'b00100
`define PRIO_ERET    5'b10000
// co-processor 1, `rs` region
`define COP1_MFC1 5'b00000
`define COP1_CFC1 5'b00010
`define COP1_MTC1 5'b00100
`define COP1_CTC1 5'b00110
`define COP1_BC1  5'b01000
`define COP1_ALUS 5'b10000
`define COP1_ALUW 5'b10100


`endif
