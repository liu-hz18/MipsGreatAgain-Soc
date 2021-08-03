`include "defines.svh"

module lfsr_32bits(
	input  logic clk,
	input  logic rst,
	input  logic update,
	output word_t val
);

word_t mov_val;
// x^32 + x^30 + x^11 + x^5 + 1
assign mov_val = (val >> 0) ^ (val >> 2) ^ (val >> 21) ^ (val >> 27);

always_ff @(posedge clk)
begin
	if(rst) begin
		val <= 32'hdeadface;
	end else if(update) begin
		val[30:0] <= val[31:1];
		val[31]   <= mov_val[0];
	end
end

endmodule
