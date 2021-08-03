`include "defines.svh"

module fpu_ex (
    input clk, rst,

    input bit_t flush,
    input bit_t stall,
    input fpuOp_t op,
    input word_t inst,
    input fcsrReg_t fcsr,
    input word_t fccr,
    input word_t gpr1, // general purpose register
    input word_t gpr2,
    input fpuReg_t fpu_reg1,
    input fpuReg_t fpu_reg2,
    
    output bit_t fcsr_we,
    output fcsrReg_t fcsr_wdata,
    output word_t fpu_reg_ret,
    output word_t gpr_ret,
    output fpuExcept_t fpu_except,
    output bit_t fpu_busy
);

// cycle control
logic[5:0] cyc_number;
logic[63:0] cyc_stage;
assign fpu_busy = (cyc_number != 1 && ~cyc_stage[0]);

always_ff @(posedge clk) begin
    if (rst || flush) begin
        cyc_stage <= 0;
    end else if (cyc_stage != 0 && ~stall) begin
        cyc_stage <= cyc_stage >> 1;
    end else begin
        cyc_stage <= ((1 << cyc_number) >> 2);
    end
end

always_comb begin
    if (rst || flush) begin
        cyc_number = 1;
    end else begin
        unique case(op)
        FPU_OP_ADD: cyc_number = 3;
        FPU_OP_SUB: cyc_number = 3;
        FPU_OP_MUL: cyc_number = 3;
        FPU_OP_DIV: cyc_number = 9;
        FPU_OP_SQRT: cyc_number = 9;
        FPU_OP_COND: cyc_number = 2;
        FPU_OP_MFC: cyc_number = 2;
        default: cyc_number = 1;
        endcase
    end
end

function is_nan(input word_t x);
    is_nan = (x == 32'h7fff_ffff || x == 32'h7fbf_ffff);
endfunction

// float-point exceptions
logic exp_sqrt;
// divide: divide_by_zero, invalid, overflow, underflow
logic [3:0] exp_div;
// add/sub/mul: invalid, overflow, underflow
logic [2:0] exp_add, exp_sub, exp_mul;

// results
logic fpu_reg1_nan;
word_t result_add, result_sub, result_mul, result_div, result_sqrt, result_neg, result_abs;
assign fpu_reg1_nan = is_nan(fpu_reg1.val);
assign result_abs = fpu_reg1_nan ? fpu_reg1.val : {1'b0, fpu_reg1.val[30:0]};
assign result_neg = fpu_reg1_nan ? fpu_reg1.val : {~fpu_reg1.val[31], fpu_reg1.val[30:0]};
logic [7:0] result_fcc;
logic [3:0] expected_cond_code;
logic [7:0] compare_cond_code;
word_t result_ceil, result_floor, result_trunc, result_round;
bit_t invalid_ceil, invalid_floor, invalid_trunc, invalid_round;
word_t result_int2float;

always_comb begin: fcc_mask
	unique case(inst[2:0])
	3'd0: expected_cond_code = 4'b0000;  // always false, sf(56)
	3'd1: expected_cond_code = 4'b1000;  // unordered, ngle(57)
	3'd2: expected_cond_code = 4'b0001;  // equal, eq(50), seq(58)
	3'd3: expected_cond_code = 4'b1001;  // unordered or equal, ueq(51), ngl(59)
	3'd4: expected_cond_code = 4'b0010;  // ordered or less than, olt(52), lt(60)
	3'd5: expected_cond_code = 4'b1010;  // unordered or less than, ult(53), nge(61)
	3'd6: expected_cond_code = 4'b0011;  // ordered or less than or equal, ole(54), le(62)
	3'd7: expected_cond_code = 4'b1011;  // unordered or less than or equal, ule(55), ngt(63)
	default: expected_cond_code = 4'b0000;
	endcase
end

always_comb begin: fcc_assign
    result_fcc = fcsr.fcc;
    result_fcc[inst[10:8]] = |(compare_cond_code[3:0] & expected_cond_code);
end

floating_point_add fpu_add(
    .s_axis_a_tdata(fpu_reg1.val),
    .s_axis_a_tvalid(1'b1),
    .s_axis_b_tdata(fpu_reg2.val),
    .s_axis_b_tvalid(1'b1),
    .aclk(clk),
    .m_axis_result_tdata(result_add),
    .m_axis_result_tuser(exp_add),
    .m_axis_result_tvalid()
);

floating_point_sub fpu_sub(
    .s_axis_a_tdata(fpu_reg1.val),
    .s_axis_a_tvalid(1'b1),
    .s_axis_b_tdata(fpu_reg2.val),
    .s_axis_b_tvalid(1'b1),
    .aclk(clk),
    .m_axis_result_tdata(result_sub),
    .m_axis_result_tuser(exp_sub),
    .m_axis_result_tvalid()
);

floating_point_mul fpu_mul(
    .s_axis_a_tdata(fpu_reg1.val),
    .s_axis_a_tvalid(1'b1),
    .s_axis_b_tdata(fpu_reg2.val),
    .s_axis_b_tvalid(1'b1),
    .aclk(clk),
    .m_axis_result_tdata(result_mul),
    .m_axis_result_tuser(exp_mul),
    .m_axis_result_tvalid()
);

floating_point_div fpu_div(
    .s_axis_a_tdata(fpu_reg1.val),
    .s_axis_a_tvalid(1'b1),
    .s_axis_b_tdata(fpu_reg2.val),
    .s_axis_b_tvalid(1'b1),
    .aclk(clk),
    .m_axis_result_tdata(result_div),
    .m_axis_result_tuser(exp_div),
    .m_axis_result_tvalid()
);

floating_point_sqrt fpu_sqrt(
    .s_axis_a_tdata(fpu_reg1.val),
    .s_axis_a_tvalid(1'b1),
    .aclk(clk),
    .m_axis_result_tdata(result_sqrt),
    .m_axis_result_tuser(exp_sqrt),
    .m_axis_result_tvalid()
);

floating_point_cmp fpu_cmp(
    .s_axis_a_tdata(fpu_reg1.val),
	.s_axis_a_tvalid(1'b1),
	.s_axis_b_tdata(fpu_reg2.val),
	.s_axis_b_tvalid(1'b1),
    .aclk(clk),
	.m_axis_result_tdata(compare_cond_code),
	.m_axis_result_tvalid()
);

fpu_float2int fpu_f2i(
    .float_word(fpu_reg1.val),
    .invalid_ceil(invalid_ceil),
    .invalid_floor(invalid_floor),
    .invalid_trunc(invalid_trunc),
    .invalid_round(invalid_round),
    .ceil(result_ceil),
    .floor(result_floor),
    .trunc(result_trunc),
    .round(result_round)
);

floating_point_int2float fpu_i2f(
    .s_axis_a_tdata(fpu_reg1.val),
    .s_axis_a_tvalid(1'b1),
    .aclk(clk),
    .m_axis_result_tdata(result_int2float),
    .m_axis_result_tvalid()
);

always_comb begin: fpu_except_assign
    fpu_except = '0;

    unique case(op)
    FPU_OP_ADD: { fpu_except.invalid, fpu_except.overflow, fpu_except.underflow } = exp_add;
    FPU_OP_SUB: { fpu_except.invalid, fpu_except.overflow, fpu_except.underflow } = exp_sub;
    FPU_OP_MUL: { fpu_except.invalid, fpu_except.overflow, fpu_except.underflow } = exp_mul;
    FPU_OP_DIV: { fpu_except.divided_by_zero, fpu_except.invalid, fpu_except.overflow, fpu_except.underflow } = exp_mul;
    FPU_OP_NEG, FPU_OP_ABS: fpu_except.invalid = fpu_reg1_nan;
    FPU_OP_SQRT: fpu_except.invalid = exp_sqrt;
    FPU_OP_CEIL: fpu_except.invalid = invalid_ceil;
    FPU_OP_TRUNC: fpu_except.invalid = invalid_trunc;
    FPU_OP_ROUND: fpu_except.invalid = invalid_round;
    FPU_OP_FLOOR: fpu_except.invalid = invalid_floor;
    FPU_OP_CVTW: begin
        unique casez(fcsr.rm)
        2'd0: fpu_except.invalid = invalid_round;
        2'd1: fpu_except.invalid = invalid_trunc;
        2'd2: fpu_except.invalid = invalid_ceil;
        default: fpu_except.invalid = invalid_floor; // 2'd3
        endcase
    end
    // FPU_OP_INVALID: fpu_except.unimpl = 1'b1; // FPU exception prio is higher than invalid-inst, so we make unimpl 1'b0 to trigger invalid-inst instead of COP1 exception.
    default: begin end
    endcase
end

// FCSR regs result
always_comb begin: fcsr_assign
    fcsr_we    = 1'b1;
	fcsr_wdata = fcsr;
    unique case(op)
    FPU_OP_COND: fcsr_wdata.fcc = result_fcc;
    FPU_OP_ADD, FPU_OP_SUB, FPU_OP_MUL, FPU_OP_DIV, FPU_OP_SQRT,
    FPU_OP_CEIL, FPU_OP_TRUNC, FPU_OP_FLOOR, FPU_OP_ROUND,
    FPU_OP_CVTS, FPU_OP_CVTW, FPU_OP_NEG, FPU_OP_ABS: begin
        fcsr_wdata.cause = fpu_except;
        fcsr_wdata.flags[4:0] = fcsr.flags[4:0] | fpu_except[4:0];
    end
    FPU_OP_CTC: begin
        unique case(inst[15:11])
        5'd25: begin
            fcsr_wdata.fcc = gpr2[7:0];
        end
        5'd26: begin
            fcsr_wdata.cause      = gpr2[17:12];
			fcsr_wdata.flags[4:0] = gpr2[6:2];
        end
        5'd28: begin
            fcsr_wdata.fs           = gpr2[2];
			fcsr_wdata.rm           = gpr2[1:0];
			fcsr_wdata.enables[4:0] = gpr2[11:7];
        end
        5'd31: begin
            fcsr_wdata.fcc          = { gpr2[31:25], gpr2[23] };
			fcsr_wdata.fs           = gpr2[24];
			fcsr_wdata.cause        = gpr2[17:12];
			fcsr_wdata.enables[4:0] = gpr2[11:7];
			fcsr_wdata.flags[4:0]   = gpr2[6:2];
			fcsr_wdata.rm           = gpr2[1:0];
        end
        default: fcsr_we = 1'b0;
        endcase
    end
    default: fcsr_we = 1'b0;
    endcase
end

// fpu regs assign
always_comb begin: fpu_regs_assign
    unique case(op)
    FPU_OP_MTC: fpu_reg_ret = gpr2;
    FPU_OP_MOV, FPU_OP_CMOV: fpu_reg_ret = fpu_reg1.val;
    FPU_OP_NEG: fpu_reg_ret = result_neg;
    FPU_OP_ABS: fpu_reg_ret = result_abs;
    FPU_OP_ADD: fpu_reg_ret = result_add;
    FPU_OP_SUB: fpu_reg_ret = result_sub;
    FPU_OP_MUL: fpu_reg_ret = result_mul;
    FPU_OP_DIV: fpu_reg_ret = result_div;
    FPU_OP_SQRT: fpu_reg_ret = result_sqrt;
    FPU_OP_CEIL: fpu_reg_ret = result_ceil;
    FPU_OP_TRUNC: fpu_reg_ret = result_trunc;
    FPU_OP_ROUND: fpu_reg_ret = result_round;
    FPU_OP_FLOOR: fpu_reg_ret = result_floor;
    FPU_OP_CVTS: fpu_reg_ret = result_int2float;
    FPU_OP_CVTW: begin
        unique casez(fcsr.rm)
        2'd0: fpu_reg_ret = result_round;
        2'd1: fpu_reg_ret = result_trunc;
        2'd2: fpu_reg_ret = result_ceil;
        default: fpu_reg_ret = result_floor; // 2'd3
        endcase
    end
    default: fpu_reg_ret = `ZERO_WORD;
    endcase
end

// cpu regs assign
always_comb begin: cpu_regs_assign
    unique case(op)
    FPU_OP_MFC: gpr_ret = fpu_reg2.val;
    FPU_OP_CFC: begin
        unique case(inst[15:11])
        5'd0: gpr_ret = fccr;
        5'd25: gpr_ret = { 24'b0, fcsr.fcc };
        5'd26: gpr_ret = { 14'b0, fcsr.cause, 5'b0, fcsr.flags[4:0], 2'b0 };
        5'd28: gpr_ret = { 20'b0, fcsr.enables[4:0], 4'b0, fcsr.fs, fcsr.rm };
        5'd31: gpr_ret = { fcsr.fcc[7:1], fcsr.fs, fcsr.fcc[0], 5'b0, fcsr.cause, fcsr.enables[4:0], fcsr.flags[4:0], fcsr.rm };
        default: gpr_ret = `ZERO_WORD;
        endcase
    end
    default: gpr_ret = `ZERO_WORD;
    endcase
end

endmodule
