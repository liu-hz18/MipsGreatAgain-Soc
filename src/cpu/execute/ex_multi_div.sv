`include "defines.svh"

module ex_mult_div(
	input  clk, rst,
	input  bit_t          flush,
	input  bit_t          stall,
	input  exOperation_t  op,
	input  word_t         reg1,
	input  word_t         reg2,
	input  doubleword_t   hilo,
	input  inst_type_t    inst_type,

	output word_t         reg_ret,
	output doubleword_t   hilo_ret,
	output bit_t          is_busy
);

bit_t is_multicyc;
assign is_multicyc = inst_type.multi_cyc_inst;

word_t reg_inner;
doubleword_t hilo_inner;
bit_t data_ready;

localparam int DIV_CYC = 34;
localparam int MUL_CYC = 1;

enum logic [1:0] {
	IDLE,
	WAIT,
	FINISH
} state, state_d;

assign is_busy = (state_d != IDLE);

always_comb begin
	state_d = state;
	unique case (state)
	IDLE: if (is_multicyc) state_d = WAIT;
	WAIT: if (data_ready) state_d = FINISH;
	FINISH: if (~stall) state_d = IDLE;
	default: state_d = IDLE;
	endcase
end

always_ff @(posedge clk) begin
	if (rst || flush) begin
		state <= IDLE;
	end else begin
		state <= state_d;
	end
end

always_ff @(posedge clk) begin
	if (rst) begin
		reg_ret <= '0;
		hilo_ret <= '0;
	end else if (state == WAIT) begin
		reg_ret <= reg_inner;
		hilo_ret <= hilo_inner;
	end
end

/* signed setting */
bit_t is_signed, negative_result;
assign is_signed = inst_type.signed_multi_cyc_inst;
assign negative_result = is_signed && (reg1[31] ^ reg2[31]);
word_t abs_reg1, abs_reg2;
assign abs_reg1 = (is_signed && reg1[31]) ? -reg1 : reg1;
assign abs_reg2 = (is_signed && reg2[31]) ? -reg2 : reg2;
bit_t divide_by_zero;
assign divide_by_zero = (abs_reg2 == 32'b0);
bit_t divider_en;
assign divider_en = ((op == OP_DIV) || (op == OP_DIVU)) & ~divide_by_zero;

/* cycle control */
logic [DIV_CYC:0] cyc_stage, cyc_stage_d;
assign data_ready = cyc_stage[0];
always_comb begin
	unique case(state)
	IDLE: begin
		unique case(op)
		OP_MADD, OP_MADDU, OP_MSUB, OP_MSUBU,
		OP_MUL, OP_MULT, OP_MULTU:
			cyc_stage_d = 1 << 1;
		OP_DIV, OP_DIVU:
			if (divide_by_zero) cyc_stage_d = 1;
			else cyc_stage_d = 1 << DIV_CYC;
		OP_MTHI, OP_MTLO:
			cyc_stage_d = 1;
		OP_MFC0: // CP0 hazard
			cyc_stage_d = 1;
		default: cyc_stage_d = '0;
		endcase
	end
	WAIT: begin
		cyc_stage_d = cyc_stage >> 1;
	end
	default: cyc_stage_d = '0;
	endcase
end
always @(posedge clk) begin
	if(rst || flush) begin
		cyc_stage <= 0;
	end else begin
		cyc_stage <= cyc_stage_d;
	end
end

/* multiply */
doubleword_t pipe_mul_abs, mul_result;
assign mul_result = negative_result ? -pipe_mul_abs : pipe_mul_abs;

// split into 16 bit for faster clock freq.
always_ff @(posedge clk) begin
	if (rst) begin
		pipe_mul_abs <= '0;
	end else begin
		pipe_mul_abs <= abs_reg1 * abs_reg2;
	end
end

/* division */
word_t abs_quotient, abs_remainder;
word_t div_quotient, div_remainder;

// z / d = q ... s (z = dq + s)
/* Note that the document of MIPS32 says if the divisor is zero,
 * the result is UNDEFINED. */
divider divider_instance(
	.aclk(clk),

	.s_axis_dividend_tvalid(divider_en), // 被除数
	.s_axis_dividend_tdata(abs_reg1),
	.s_axis_divisor_tvalid(divider_en), // 除数
	.s_axis_divisor_tdata(abs_reg2),

	.m_axis_dout_tvalid(),
	.m_axis_dout_tdata({ abs_quotient, abs_remainder })
);

/* |b| = |aq| + |r|
 *   1) b > 0, a < 0 ---> b = (-a)(-q) + r
 *   2) b < 0, a > 0 ---> -b = a(-q) + (-r) */
assign div_quotient  = negative_result ? -abs_quotient : abs_quotient;
assign div_remainder = (is_signed && (reg1[31] ^ abs_remainder[31])) ? -abs_remainder : abs_remainder;

/* set result */
always_comb begin
	unique case(op)
		OP_MADDU, OP_MADD: hilo_inner = hilo + mul_result;
		OP_MSUBU, OP_MSUB: hilo_inner = hilo - mul_result;
		OP_DIV, OP_DIVU: hilo_inner = { div_remainder, div_quotient };
		OP_MULT, OP_MULTU: hilo_inner = mul_result;
		OP_MTLO: hilo_inner = { hilo[63:32], reg1 };
		OP_MTHI: hilo_inner = { reg1, hilo[31:0]  };
        default: hilo_inner = '0;
	endcase
end

always_comb begin
	unique case(op)
		OP_MUL:  reg_inner = mul_result[31:0];
		/* result of OP_MFC0 is computed in CP0 */
		default: reg_inner = '0;
	endcase
end

endmodule
