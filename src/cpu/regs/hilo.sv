`include "defines.svh"

module hilo(
    input clk, rst,
    input bit_t we,
    input doubleword_t whilodata,
    output doubleword_t rhilodata
);

doubleword_t reg_hilo;

always_ff @(posedge clk) begin
    if (rst) begin
        reg_hilo <= `ZERO_DWORD;
    end else if (we) begin
        reg_hilo <= whilodata;
    end
end

always_comb begin: read_hilo
    if (we == 1'b1) begin
        rhilodata = whilodata;
    end else begin
        rhilodata = reg_hilo;
    end
end

endmodule
