`include "defines.svh"

module ll_bit_reg (
    input clk, rst,

    input bit_t flush, // for exception clear llbit
    input bit_t llbit_we,
    input bit_t llbit_wdata,
    output bit_t ll_bit
);

reg ll_bit_inner;

always_ff @(posedge clk) begin 
    if (rst || flush) begin
        ll_bit_inner <= 1'b0;
    end else if (llbit_we) begin
        ll_bit_inner <= llbit_wdata;
    end
end

always_comb begin: read_llbit
    if (flush) begin
        ll_bit = 1'b0;
    end else if (llbit_we) begin // wb -> mem data bypass
        ll_bit = llbit_wdata;
    end else begin
        ll_bit = ll_bit_inner;
    end  
end

endmodule
