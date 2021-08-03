`include "defines.svh"

module forward_bypass (
    // id read signal
    input regaddr_t raddr1,
    input regaddr_t raddr2,
    `ifdef ENABLE_FPU
    input regaddr_t fpu_raddr1,
    input regaddr_t fpu_raddr2,
    `endif

    // unsafe data from regfile
    input word_t rdata1,
    input word_t rdata2,
    input doubleword_t hilo,
    `ifdef ENABLE_FPU
    input fpuReg_t fpu_rdata1,
    input fpuReg_t fpu_rdata2,
    input fcsrReg_t fpu_fcsr,
    `endif

    // safe data to id module
    output bit_t id_stall_req, // load-relation handler
    output word_t rdata1_safe,
    output word_t rdata2_safe,
    output doubleword_t hilo_safe,
    `ifdef ENABLE_FPU
    output fpuReg_t fpu_rdata1_safe,
    output fpuReg_t fpu_rdata2_safe,
    output fcsrReg_t fpu_fcsr_safe,
    `endif

    // data bypass from ex stage
    input regWritePort_t ex_wr_bypass,
    input bit_t ex_hilo_we_bypass,
    input doubleword_t ex_hilo_wdata_bypass,
    input memControl_t ex_memory_bypass,
    `ifdef ENABLE_FPU
    input bit_t ex_fcsr_we_bypass,
    input fcsrReg_t ex_fcsr_bypass,
    input fpuRegWriteReq_t ex_fpu_wr_bypass,
    `endif

    // bypass from cache-1 stage
    input regWritePort_t cache_wr_bypass,
    input bit_t cache_hilo_we_bypass,
    input doubleword_t cache_hilo_wdata_bypass,
    input memControl_t cache_memory_bypass,
    `ifdef ENABLE_FPU
    input bit_t cache_fcsr_we_bypass,
    input fcsrReg_t cache_fcsr_bypass,
    input fpuRegWriteReq_t cache_fpu_wr_bypass,
    `endif

    // bypass from cache-2 stage
    input regWritePort_t cache_2_wr_bypass,
    input bit_t cache_2_hilo_we_bypass,
    input doubleword_t cache_2_hilo_wdata_bypass,
    input memControl_t cache_2_memory_bypass,
    `ifdef ENABLE_FPU
    input bit_t cache_2_fcsr_we_bypass,
    input fcsrReg_t cache_2_fcsr_bypass,
    input fpuRegWriteReq_t cache_2_fpu_wr_bypass,
    `endif

    // bypass from mem stage
    input regWritePort_t mem_wr_bypass,
    input bit_t mem_hilo_we_bypass,
    input doubleword_t mem_hilo_wdata_bypass,
    `ifdef ENABLE_FPU
    input bit_t mem_fcsr_we_bypass,
    input fcsrReg_t mem_fcsr_bypass,
    input fpuRegWriteReq_t mem_fpu_wr_bypass,
    `endif
    input memControl_t mem_memory_bypass
);

always_comb begin: bypass_forward_mux
    // reg1
    rdata1_safe = rdata1;
    if (ex_wr_bypass.we && ex_wr_bypass.waddr == raddr1) begin
        rdata1_safe = ex_wr_bypass.wdata;
    end else if (cache_wr_bypass.we && cache_wr_bypass.waddr == raddr1) begin
        rdata1_safe = cache_wr_bypass.wdata;
    end else if (cache_2_wr_bypass.we && cache_2_wr_bypass.waddr == raddr1) begin
        rdata1_safe = cache_2_wr_bypass.wdata;
    end else if (mem_wr_bypass.we && mem_wr_bypass.waddr == raddr1) begin
        rdata1_safe = mem_wr_bypass.wdata;
    end

    // reg2
    rdata2_safe = rdata2;
    if (ex_wr_bypass.we && ex_wr_bypass.waddr == raddr2) begin
        rdata2_safe = ex_wr_bypass.wdata;
    end else if (cache_wr_bypass.we && cache_wr_bypass.waddr == raddr2) begin
        rdata2_safe = cache_wr_bypass.wdata;
    end else if (cache_2_wr_bypass.we && cache_2_wr_bypass.waddr == raddr2) begin
        rdata2_safe = cache_2_wr_bypass.wdata;
    end else if (mem_wr_bypass.we && mem_wr_bypass.waddr == raddr2) begin
        rdata2_safe = mem_wr_bypass.wdata;
    end

    // hilo
    hilo_safe = hilo;
    if (ex_hilo_we_bypass) begin
        hilo_safe = ex_hilo_wdata_bypass;
    end else if (cache_hilo_we_bypass) begin
        hilo_safe = cache_hilo_wdata_bypass;
    end else if (cache_2_hilo_we_bypass) begin
        hilo_safe = cache_2_hilo_wdata_bypass;
    end else if (mem_hilo_we_bypass) begin
        hilo_safe = mem_hilo_wdata_bypass;
    end

    `ifdef ENABLE_FPU
    // fpu_reg1
    fpu_rdata1_safe = fpu_rdata1;
    if (ex_fpu_wr_bypass.we && fpu_raddr1 == ex_fpu_wr_bypass.waddr) begin
        fpu_rdata1_safe = ex_fpu_wr_bypass.wdata;
    end else if (cache_fpu_wr_bypass.we && fpu_raddr1 == cache_fpu_wr_bypass.waddr) begin
        fpu_rdata1_safe = cache_fpu_wr_bypass.wdata;
    end else if (cache_2_fpu_wr_bypass.we && fpu_raddr1 == cache_2_fpu_wr_bypass.waddr) begin
        fpu_rdata1_safe = cache_2_fpu_wr_bypass.wdata;
    end else if (mem_fpu_wr_bypass.we && fpu_raddr1 == mem_fpu_wr_bypass.waddr) begin
        fpu_rdata1_safe = mem_fpu_wr_bypass.wdata;
    end

    // fpu reg2
    fpu_rdata2_safe = fpu_rdata2;
    if (ex_fpu_wr_bypass.we && fpu_raddr2 == ex_fpu_wr_bypass.waddr) begin
        fpu_rdata2_safe = ex_fpu_wr_bypass.wdata;
    end else if (cache_fpu_wr_bypass.we && fpu_raddr1 == cache_fpu_wr_bypass.waddr) begin
        fpu_rdata2_safe = cache_fpu_wr_bypass.wdata;
    end else if (cache_2_fpu_wr_bypass.we && fpu_raddr1 == cache_2_fpu_wr_bypass.waddr) begin
        fpu_rdata2_safe = cache_2_fpu_wr_bypass.wdata;
    end else if (mem_fpu_wr_bypass.we && fpu_raddr2 == mem_fpu_wr_bypass.waddr) begin
        fpu_rdata2_safe = mem_fpu_wr_bypass.wdata;
    end

    // fscr
    fpu_fcsr_safe = fpu_fcsr;
    if (ex_fcsr_we_bypass) begin
        fpu_fcsr_safe = ex_fcsr_bypass;
    end else if (cache_fcsr_we_bypass) begin
        fpu_fcsr_safe = cache_fcsr_bypass;
    end else if (cache_2_fcsr_we_bypass) begin
        fpu_fcsr_safe = cache_2_fcsr_bypass;
    end else if (mem_fcsr_we_bypass) begin
        fpu_fcsr_safe = mem_fcsr_bypass;
    end
    `endif
end

// load-relation, stall 4 cycles
bit_t ex_load_relation, mem_load_relation, cache_load_relation, cache_2_load_relation;
assign ex_load_relation = (ex_memory_bypass.ce && ~ex_memory_bypass.we) && (
    ex_wr_bypass.waddr == raddr1 && raddr1 != 5'b0 ||
    ex_wr_bypass.waddr == raddr2 && raddr2 != 5'b0
);
assign cache_load_relation = (cache_memory_bypass.ce && ~cache_memory_bypass.we) && (
    cache_wr_bypass.waddr == raddr1 && raddr1 != 5'b0 ||
    cache_wr_bypass.waddr == raddr2 && raddr2 != 5'b0
);
assign cache_2_load_relation = (cache_2_memory_bypass.ce && ~cache_2_memory_bypass.we) && (
    cache_2_wr_bypass.waddr == raddr1 && raddr1 != 5'b0 ||
    cache_2_wr_bypass.waddr == raddr2 && raddr2 != 5'b0
);
assign mem_load_relation = (mem_memory_bypass.ce && ~mem_memory_bypass.we) && (
    mem_wr_bypass.waddr == raddr1 && raddr1 != 5'b0 ||
    mem_wr_bypass.waddr == raddr2 && raddr2 != 5'b0
);
bit_t ex_load_relation_fpu, mem_load_relation_fpu, cache_load_relation_fpu, cache_2_load_relation_fpu;
`ifdef ENABLE_FPU
assign ex_load_relation_fpu = (ex_memory_bypass.ce && ~ex_memory_bypass.we) && (
    ex_fpu_wr_bypass.waddr == fpu_raddr1 ||
    ex_fpu_wr_bypass.waddr == fpu_raddr2
);
assign cache_load_relation_fpu = (cache_memory_bypass.ce && ~cache_memory_bypass.we) && (
    cache_fpu_wr_bypass.waddr == fpu_raddr1 ||
    cache_fpu_wr_bypass.waddr == fpu_raddr2
);
assign cache_2_load_relation_fpu = (cache_2_memory_bypass.ce && ~cache_2_memory_bypass.we) && (
    cache_2_fpu_wr_bypass.waddr == fpu_raddr1 ||
    cache_2_fpu_wr_bypass.waddr == fpu_raddr2
);
assign mem_load_relation_fpu = (mem_memory_bypass.ce && ~mem_memory_bypass.we) && (
    mem_fpu_wr_bypass.waddr == fpu_raddr1 ||
    mem_fpu_wr_bypass.waddr == fpu_raddr2
);
`else
assign ex_load_relation_fpu = 1'b0;
assign cache_load_relation_fpu = 1'b0;
assign cache_2_load_relation_fpu = 1'b0;
assign mem_load_relation_fpu = 1'b0;
`endif
assign id_stall_req = (
    ex_load_relation | mem_load_relation | cache_load_relation | cache_2_load_relation |
    ex_load_relation_fpu | mem_load_relation_fpu | cache_load_relation_fpu | cache_2_load_relation_fpu
);

endmodule

