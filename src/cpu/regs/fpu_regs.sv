`include "defines.svh"
// FPU data regs and FCSR impls.
module fpu_regs(
    input clk, rst,

    input fpuRegWriteReq_t wr,

    input regaddr_t raddr1,
    output fpuReg_t rdata1,

    input regaddr_t raddr2,
    output fpuReg_t rdata2,

    // FCSRs
    input bit_t fcsr_we,
    input fcsrReg_t fcsr_wdata,
    output fcsrReg_t fcsr,
    output word_t fccr // fccr is fixed and read-only in our impl!
);

fcsrReg_t fcsr_reg;

always_comb begin: fcsr_read
    if (fcsr_we) begin
        fcsr = fcsr_wdata;
    end else begin
        fcsr = fcsr_reg;
    end
    // if (except_req.flush && except_req.code == `EXCCODE_FPE) begin
    //     fcsr.cause = except_req.extra[$bits(fpuExcept_t) - 1:0];
    // end
end

// indicates that the single-precision floating point implemented
assign fccr = 32'h00010000;

always_ff @(posedge clk) begin
    if (rst) begin
        fcsr_reg <= '0;
    end else if (fcsr_we) begin
        fcsr_reg <= fcsr_wdata;
    end
end

reg [31:0] fpu_regs[0:`REG_NUM-1];
reg [$bits(fpuRegFormat_t)-1:0] fpu_reg_fmt[0:`REG_NUM-1];

// write port
genvar i;
generate
for (i = 0; i < `REG_NUM; i = i + 1) begin
    always_ff @(posedge clk) begin
        if (rst) begin
            fpu_regs[i] <= `ZERO_WORD;
            fpu_reg_fmt[i] <= `FPU_REG_UNKNOWN;
        end else if (wr.we && wr.waddr == i) begin
            fpu_regs[i] <= wr.wdata.val;
            fpu_reg_fmt[i] <= wr.wdata.fmt;
        end
    end
end
endgenerate

// read port 1
always_comb begin: read_port1
    if (wr.we && raddr1 == wr.waddr) begin
        rdata1 = wr.wdata;
    end else begin
        rdata1.val = fpu_regs[raddr1];
        rdata1.fmt = fpu_reg_fmt[raddr1];
    end
end

// read port 2
always_comb begin: read_port2
    if (wr.we && raddr2 == wr.waddr) begin
        rdata2 = wr.wdata;
    end else begin
        rdata2.val = fpu_regs[raddr2];
        rdata2.fmt = fpu_reg_fmt[raddr2];
    end
end

endmodule
