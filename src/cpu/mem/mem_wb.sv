`include "defines.svh"

module mem_wb (
    input clk, rst,

    input stall_t stall,
    input bit_t flush,

    input word_t mem_pc,
    input regWritePort_t mem_wp1,
    input bit_t mem_we_hilo,
    input doubleword_t mem_hilo,
    input bit_t mem_llbit_we,
    input bit_t mem_llbit_wdata,
    `ifdef ENABLE_FPU
    input fcsrReg_t mem_fcsr_wdata,
    input bit_t mem_fcsr_we,
    input fpuRegWriteReq_t mem_fpu_wr,
    `endif

    output word_t wb_pc,
    output regWritePort_t wb_wp1, // execute result
    output bit_t wb_we_hilo,
    output doubleword_t wb_hilo,
    `ifdef ENABLE_FPU
    output fcsrReg_t wb_fcsr_wdata,
    output bit_t wb_fcsr_we,
    output fpuRegWriteReq_t wb_fpu_wr,
    `endif
    output bit_t wb_llbit_we,
    output bit_t wb_llbit_wdata
);

// control flow to copy forward
always_ff @(posedge clk) begin
    if (rst || (stall.stall_mem && ~stall.stall_wb)) begin
        wb_pc <= `ZERO_WORD;
        wb_wp1.we <= 1'b0;
        wb_wp1.waddr <= `ZERO_REG_ADDR;
        wb_wp1.wdata <= `ZERO_WORD;
        wb_we_hilo <= 1'b0;
        wb_hilo <= `ZERO_DWORD;
        wb_llbit_we <= 1'b0;
        wb_llbit_wdata <= 1'b0;
        `ifdef ENABLE_FPU
        wb_fcsr_wdata <= {$bits(fcsrReg_t){1'b0}};
        wb_fcsr_we <= 1'b0;
        wb_fpu_wr.we <= 1'b0;
        wb_fpu_wr.waddr <= `ZERO_REG_ADDR;
        wb_fpu_wr.wdata <= {$bits(fpuReg_t){1'b0}};
        `endif
    end else if (~stall.stall_mem) begin
        wb_pc <= mem_pc;
        wb_wp1 <= mem_wp1;
        wb_we_hilo <= mem_we_hilo;
        wb_hilo <= mem_hilo;
        wb_llbit_we <= mem_llbit_we;
        wb_llbit_wdata <= mem_llbit_wdata;
        `ifdef ENABLE_FPU
        wb_fcsr_wdata <= mem_fcsr_wdata;
        wb_fcsr_we <= mem_fcsr_we;
        wb_fpu_wr <= mem_fpu_wr;
        `endif
    end
end

endmodule
