`include "defines.svh"

// if you want to upgrade to multi-pipeline, you need to double the read/write port.
module regfile (
    input clk, rst,
    // write port 1
    input regWritePort_t wp1,

    // read port 1
    input regaddr_t raddr1,
    output word_t rdata1,
    // read port 2
    input regaddr_t raddr2,
    output word_t rdata2
);

reg[`REG_DATA_WIDTH-1:0] registers[0:`REG_NUM-1];

always_ff @(posedge clk) begin
    registers[0] <= `ZERO_WORD;
end

// write port 1, write at clk post edge.
genvar i;
generate // for reset use, seems a bit boring.
    for (i = 1; i < `REG_NUM; i = i+1) begin: gen_reg_assign
        always_ff @(posedge clk) begin
            if (rst) begin
                registers[i] <= `ZERO_WORD;
            end else begin
                if (wp1.we && wp1.waddr == i) begin
                    registers[i] <= wp1.wdata;
                end
            end
        end
    end
endgenerate

// read port 1
always_comb begin: read_port1
    if (wp1.we && raddr1 == wp1.waddr && raddr1 != 5'b0) begin
        rdata1 = wp1.wdata;
    end else begin
        rdata1 = registers[raddr1];
    end
end

// read port 2
always_comb begin: read_port2
    if (wp1.we && raddr2 == wp1.waddr && raddr2 != 5'b0) begin
        rdata2 = wp1.wdata;
    end else begin
        rdata2 = registers[raddr2];
    end
end

endmodule
