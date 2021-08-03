`include "defines.svh"

module cpu_core (
    input clk,
    input rst,

    input wire[5:0] ext_int,

    cpu_ibus_if.master ibus,

    output bit_t invalidate_icache,
    output word_t invalidate_addr,
    output axi_req_t dcache_axi_req,
    input axi_resp_t dcache_axi_resp,
    output axi_req_t uncached_axi_req,
    input axi_resp_t uncached_axi_resp,

    // debug
    output wire[31:0] debug_wb_pc,
    output wire[3 :0] debug_wb_rf_wen,
    output wire[4 :0] debug_wb_rf_wnum,
    output wire[31:0] debug_wb_rf_wdata
);

bit_t dcache_ready;
bit_t bpu_ready;
bit_t branch_predict_if2, branch_predict_if3;
word_t branch_predict_target, branch_predict_target_if3;
logic [1:0] predict_state;

bit_t if_stall_req, id_stall_req, ex_stall_req, mem_stall_req, wb_stall_req;
stall_t stall;
bit_t flush;
bit_t ibus_stall_req;
assign wb_stall_req = 1'b0;
assign ibus_stall_req = wb_stall_req | mem_stall_req | ex_stall_req | id_stall_req | ~bpu_ready | ~dcache_ready;

// if <-> id & ram & pc
word_t branch_target_addr;
bit_t branch_flag;
bit_t pc_ce;
word_t pc;

// if_id <-> id
word_t id_pc_i;
word_t id_inst_i;
bit_t id_valid_i;
bit_t id_delayslot_i; 
bit_t in_delayslot_hold;

// id <-> regfile
word_t id_rdata1_i;
word_t id_rdata2_i;
regaddr_t id_raddr1_o;
regaddr_t id_raddr2_o;

// id <-> hilo
doubleword_t id_hilo_i;

// id <-> fpu_regs
fcsrReg_t fcsr_unsafe;

// id <-> id_ex
word_t id_pc_o;
word_t id_inst_o;
bit_t id_delayslot_o;
word_t id_rdata1_o;
word_t id_rdata2_o;
word_t id_imm_o;
exOperation_t id_ex_op_o;
bit_t id_we1_o;
regaddr_t id_waddr1_o;
bit_t next_inst_in_delayslot;
exceptType_t id_except;
doubleword_t id_hilo_safe;
fpuOp_t id_fpu_op;
regaddr_t id_fpu_raddr1;
regaddr_t id_fpu_raddr2;
bit_t id_fpu_we;
regaddr_t id_fpu_waddr;
fcsrReg_t id_fpu_fcsr;
fpuReg_t id_fpu_reg1, id_fpu_reg2; 
inst_type_t id_inst_type;

// id_ex <-> ex
bit_t ex_branch_flag_i;
word_t ex_inst_i;
word_t ex_pc_i;
bit_t ex_delayslot_i;
word_t ex_rdata1_i;
word_t ex_rdata2_i;
word_t ex_imm_i;
exOperation_t ex_ex_op_i;
bit_t ex_we1_i;
regaddr_t ex_waddr1_i;
doubleword_t ex_hilo_safe;
exceptType_t idex_except;
fpuOp_t ex_fpu_op;
regaddr_t ex_fpu_raddr1;
regaddr_t ex_fpu_raddr2;
bit_t ex_fpu_we;
regaddr_t ex_fpu_waddr;
fcsrReg_t ex_fpu_fcsr;
fpuReg_t ex_fpu_reg1, ex_fpu_reg2; 
inst_type_t ex_inst_type;

// ex <-> fpu_regs
word_t fpu_fccr; // constant
fpuReg_t fpu_reg1;
fpuReg_t fpu_reg2;

// ex <-> cp0
word_t ex_cp0_rdata;
regaddr_t ex_cp0_raddr;
logic[2:0] ex_cp0_rsel;

// ex <-> ex_mem
regWritePort_t ex_wp1_o;
bit_t ex_we_hilo_o;
doubleword_t ex_hilo_o;
memControl_t ex_memory_o;
cp0WriteControl_t ex_cp0_wp_o;
exceptType_t ex_except_o;
fcsrReg_t ex_fcsr_wdata;
bit_t ex_fcsr_we;
fpuRegWriteReq_t ex_fpu_wr;
fpuExcept_t ex_fpu_except;
tlbControl_t ex_tlb_ctrl;

// ex_mem <-> mem
bit_t mem_delayslot;
exOperation_t mem_op;
word_t mem_pc_i;
regWritePort_t mem_wp1_i;
bit_t mem_we_hilo_i;
doubleword_t mem_hilo_i;
memControl_t mem_memory_i;
cp0WriteControl_t mem_cp0_wp_i;
exceptType_t mem_except_i;
fcsrReg_t mem_fcsr_wdata_i;
bit_t mem_fcsr_we_i;
fpuRegWriteReq_t mem_fpu_wr_i;
fpuExcept_t mem_fpu_except;
mmuResult_t mem_data_mmu_result;
inst_type_t mem_inst_type;

// mem <-> mem_wb
tlbControl_t mem_tlb_ctrl;

// except <-> cp0 & ctrl
exceptControl_t except_req_o;

// mem_wb <-> wb
word_t wb_pc_i;
regWritePort_t wb_wp1_i;
bit_t wb_we_hilo_i;
doubleword_t wb_hilo_i;

// wb <-> llbit
bit_t wb_llbit_we;
bit_t wb_llbit_wdata;
// wb <-> fpu_regs
bit_t wb_fcsr_we;
fcsrReg_t wb_fcsr_wdata;
fpuRegWriteReq_t wb_fpu_wr;

// llbit
bit_t ll_bit_o;

// CP0 infos
CP0Regs_t cp0_regs_ex, cp0_regs_mem;
bit_t user_mode_o;
wire timer_int_o;
wire[7:0] asid_o;
bit_t kseg0_uncached_o;

// except
wire[7:0] interrupt_flag; // to CP0
assign interrupt_flag = {timer_int_o | ext_int[5], ext_int[4:0], cp0_regs_mem.cause.ip[1:0]};
wire[7:0] interrupt_exc_req; // to except, check at mem stage, so CP0 need to provide data bypass.
assign interrupt_exc_req = interrupt_flag & cp0_regs_mem.status.im;

// wb stage debug info
assign debug_wb_pc = wb_pc_i;
assign debug_wb_rf_wen = {4{wb_wp1_i.we}}; // word
assign debug_wb_rf_wnum = wb_wp1_i.waddr;
assign debug_wb_rf_wdata = wb_wp1_i.wdata;

// mmu
mmuResult_t inst_mmu_result, data_mmu_result;
// TLB ctrl
word_t tlbp_index;
tlbIndex_t tlbrw_index, ex_tlbrw_index;
bit_t tlbrw_we;
tlbEntry_t tlbrw_wdata;
tlbEntry_t tlbrw_rdata;


regfile regfile_instance(
    .clk(clk),
    .rst(rst),
    .wp1(wb_wp1_i),
    .raddr1(id_raddr1_o),
    .rdata1(id_rdata1_i),
    .raddr2(id_raddr2_o),
    .rdata2(id_rdata2_i)
);

hilo hilo_instance(
    .clk(clk),
    .rst(rst),
    .we(wb_we_hilo_i),
    .whilodata(wb_hilo_i),
    .rhilodata(id_hilo_i)
);

ll_bit_reg ll_bit_instance(
    .clk(clk),
    .rst(rst),
    .flush(flush),
    .llbit_we(wb_llbit_we),
    .llbit_wdata(wb_llbit_wdata),
    .ll_bit(ll_bit_o)
);

`ifdef ENABLE_FPU
fpu_regs fpu_regs_instance(
    .clk(clk),
    .rst(rst),
    
    .raddr1(id_fpu_raddr1), // from id stage
    .rdata1(fpu_reg1),
    .raddr2(id_fpu_raddr2),    
    .rdata2(fpu_reg2),

    .wr(wb_fpu_wr),

    .fcsr_we(wb_fcsr_we),
    .fcsr_wdata(wb_fcsr_wdata),
    .fcsr(fcsr_unsafe),
    .fccr(fpu_fccr)
);
`endif

stall_ctrl stall_ctrl_instance(
    .rst(rst),
    .if_stall_req(if_stall_req),
    .id_stall_req(id_stall_req),
    .ex_stall_req(ex_stall_req),
    .mem_stall_req(mem_stall_req),
    .wb_stall_req(wb_stall_req),
    .except_req(except_req_o),

    .stall(stall), // 6bit
    .flush(flush)
);

pc_reg pc_reg_instance(
    .clk(clk),
    .rst(rst),
    .ready(ibus.ready & bpu_ready & dcache_ready),
    .hold_pc(ibus_stall_req),
    .stall(stall),
    .flush(flush),

    .jump_pc(except_req_o.jump_pc), // flush info
    // branch
    .branch_flag(branch_flag),
    .branch_target_addr(branch_target_addr),
    // branch predict
    .branch_predict(branch_predict_if2),
    .branch_predict_target(branch_predict_target),

    .pc(pc),
    .ce(pc_ce)
);

fetch if_instance(
    .rst(rst),
    .pc(pc),
    .pc_ce(pc_ce),
    .inst_mmu_result(inst_mmu_result),
    .stall_req(ibus_stall_req),
    .flush(flush),
    .branch_flag(branch_flag),

    .if_stall_req(if_stall_req),
    .inst_bus(ibus)
);

bit_t bpu_we;
word_t bpu_branch_target;
bit_t bpu_is_jump;
bit_t bpu_branch_flag;
logic [1:0] id_branch_predict_state;
bit_t id_branch_predict;
word_t id_branch_predict_target;

// branch prediction unit
branch_predictor #(
    .SIZE(`BTB_SIZE)
) bp_instance (
    .clk(clk), 
    .rst(rst),
    .pc(pc), // in IF-1 stage
    .stall(stall.stall_if),
    .flush(flush),

    // update info from id stage
    .id_we(bpu_we),
    .id_pc(id_pc_i),
    .id_branch_target(bpu_branch_target),
    .id_jump(bpu_is_jump), // is J-type, must branch, so can change 2-bit to 2'b11 immediately.
    .id_state(id_branch_predict_state),
    .id_branch_flag(bpu_branch_flag),
    .id_mispredict(branch_flag),

    .ready(bpu_ready),
    .target(branch_predict_target), // return in next cycle (IF-2 stage) (send to IF-1)
    .predict_branch_if2(branch_predict_if2), // send to IF-1
    .predict_branch_if3(predict_branch_if3), // send to ID (return at IF-3)
    .predict_state(predict_state), // send to ID (return at IF-3)
    .predict_target_if3(branch_predict_target_if3)
);

if_id if_id_instance(
    .clk(clk),
    .rst(rst),
    .stall(stall),
    .flush(flush),
    .pc_ce(pc_ce),
    .branch_flag(ex_branch_flag_i),

    .if_except(ibus.bus_if_except),
    .if_pc(ibus.bus_pc),
    .if_inst(ibus.rdata),
    .if_valid(ibus.valid),
    .if_branch_predict(predict_branch_if3),
    .if_branch_predict_state(predict_state),
    .if_branch_predict_target(branch_predict_target_if3),
   
    .id_pc(id_pc_i),
    .id_inst(id_inst_i),
    .id_valid(id_valid_i),
    .id_branch_predict(id_branch_predict),
    .id_branch_predict_state(id_branch_predict_state),
    .id_branch_predict_target(id_branch_predict_target),
    .id_except(id_except),
    .in_delayslot_hold(in_delayslot_hold)
);

regWritePort_t cache_2_wp;
bit_t cache_2_we_hilo;
doubleword_t cache_2_hilo;
fcsrReg_t cache_2_fcsr_wdata;
bit_t cache_2_fcsr_we;
fpuRegWriteReq_t cache_2_fpu_wr;
memControl_t cache_2_memory;

word_t mem_pc;
regWritePort_t mem_wp1;
bit_t mem_we_hilo;
doubleword_t mem_hilo;
fcsrReg_t mem_fcsr_wdata;
bit_t mem_fcsr_we;
fpuRegWriteReq_t mem_fpu_wr;
bit_t mem_llbit_we;
bit_t mem_llbit_wdata;
memControl_t mem_memory;

word_t rdata1_safe;
word_t rdata2_safe;
fcsrReg_t fcsr_safe;
forward_bypass forward_bypass_instance (
    .raddr1(id_raddr1_o),
    .raddr2(id_raddr2_o),
    `ifdef ENABLE_FPU
    .fpu_raddr1(id_fpu_raddr1),
    .fpu_raddr2(id_fpu_raddr2),
    `endif

    .rdata1(id_rdata1_i),
    .rdata2(id_rdata2_i),
    .hilo(id_hilo_i),
    `ifdef ENABLE_FPU
    .fpu_rdata1(fpu_reg1),
    .fpu_rdata2(fpu_reg2),
    .fpu_fcsr(fcsr_unsafe),
    `endif

    .id_stall_req(id_stall_req),
    .rdata1_safe(rdata1_safe), // use in id
    .rdata2_safe(rdata2_safe), // use in id
    .hilo_safe(id_hilo_safe),
    `ifdef ENABLE_FPU
    .fpu_rdata1_safe(id_fpu_reg1),
    .fpu_rdata2_safe(id_fpu_reg2),
    .fpu_fcsr_safe(fcsr_safe), // use in id
    `endif

    .ex_wr_bypass(ex_wp1_o),
    .ex_hilo_we_bypass(ex_we_hilo_o),
    .ex_hilo_wdata_bypass(ex_hilo_o),
    .ex_memory_bypass(ex_memory_o),
    `ifdef ENABLE_FPU
    .ex_fcsr_we_bypass(ex_fcsr_we),
    .ex_fcsr_bypass(ex_fcsr_wdata),
    .ex_fpu_wr_bypass(ex_fpu_wr),
    `endif

    .cache_wr_bypass(mem_wp1_i),
    .cache_hilo_we_bypass(mem_we_hilo_i),
    .cache_hilo_wdata_bypass(mem_hilo_i),
    .cache_memory_bypass(mem_memory_i),
    `ifdef ENABLE_FPU
    .cache_fcsr_we_bypass(mem_fcsr_we_i),
    .cache_fcsr_bypass(mem_fcsr_wdata_i),
    .cache_fpu_wr_bypass(mem_fpu_wr_i),
    `endif

    .cache_2_wr_bypass(cache_2_wp),
    .cache_2_hilo_we_bypass(cache_2_we_hilo),
    .cache_2_hilo_wdata_bypass(cache_2_hilo),
    .cache_2_memory_bypass(cache_2_memory),
    `ifdef ENABLE_FPU
    .cache_2_fcsr_we_bypass(cache_2_fcsr_we),
    .cache_2_fcsr_bypass(cache_2_fcsr_wdata),
    .cache_2_fpu_wr_bypass(cache_2_fpu_wr),
    `endif

    .mem_wr_bypass(mem_wp1),
    .mem_hilo_we_bypass(mem_we_hilo),
    .mem_hilo_wdata_bypass(mem_hilo),
    `ifdef ENABLE_FPU
    .mem_fcsr_we_bypass(mem_fcsr_we),
    .mem_fcsr_bypass(mem_fcsr_wdata),
    .mem_fpu_wr_bypass(mem_fpu_wr),
    `endif
    .mem_memory_bypass(mem_memory)
);

decode decode_instance(
    .rst(rst),

    .pc(id_pc_i),
    .inst(id_inst_i),
    .valid(id_valid_i),
    .delayslot_i(id_delayslot_i),
    .id_branch_predict(id_branch_predict),
    .id_branch_predict_target(id_branch_predict_target),

    .rdata1(rdata1_safe),
    .rdata2(rdata2_safe),
    .raddr1(id_raddr1_o),
    .raddr2(id_raddr2_o),

    .delayslot_o(id_delayslot_o),
    .pc_o(id_pc_o),
    .inst_o(id_inst_o),
    .reg1(id_rdata1_o),
    .reg2(id_rdata2_o),
    .imm(id_imm_o),
    .ex_op(id_ex_op_o),
    .we1(id_we1_o),
    .waddr1(id_waddr1_o),
    .inst_type(id_inst_type),

    `ifdef ENABLE_FPU
    .fpu_fcsr_safe(fcsr_safe),
    // fpu reg read req
    .fpu_raddr1(id_fpu_raddr1),
    .fpu_raddr2(id_fpu_raddr2),
    // fpu ctrls
    .fpu_op(id_fpu_op),
    .fpu_we(id_fpu_we),
    .fpu_waddr(id_fpu_waddr),
    `endif

    // branch
    .branch_flag(branch_flag),
    .branch_target_addr(branch_target_addr),
    .next_inst_in_delayslot(next_inst_in_delayslot),
    .bpu_we(bpu_we),
    .bpu_branch_target(bpu_branch_target),
    .bpu_is_jump(bpu_is_jump),
    .bpu_branch_flag(bpu_branch_flag)
);

id_ex id_ex_instance(
    .clk(clk),
    .rst(rst),
    .stall(stall),
    .flush(flush),
    .in_delayslot_hold(in_delayslot_hold),

    .id_branch_flag(branch_flag),
    .id_inst(id_inst_o),
    .id_pc(id_pc_o), // from if/id stage
    .id_delayslot(id_delayslot_o),
    .id_reg1(id_rdata1_o),
    .id_reg2(id_rdata2_o),
    .id_imm(id_imm_o),
    .id_exop(id_ex_op_o),
    .id_we1(id_we1_o),
    .id_waddr1(id_waddr1_o),
    .id_next_inst_in_delayslot(next_inst_in_delayslot),
    .id_except(id_except),
    .id_hilo(id_hilo_safe),
    .id_inst_type(id_inst_type),
    `ifdef ENABLE_FPU
    .id_fpu_op(id_fpu_op),
    .id_fpu_raddr1(id_fpu_raddr1),
    .id_fpu_raddr2(id_fpu_raddr2),
    .id_fpu_we(id_fpu_we),
    .id_fpu_waddr(id_fpu_waddr),
    .id_fpu_fcsr(fcsr_safe),
    .id_fpu_reg1(id_fpu_reg1),
    .id_fpu_reg2(id_fpu_reg2),
    `endif

    .ex_branch_flag(ex_branch_flag_i),
    .ex_inst(ex_inst_i),
    .ex_pc(ex_pc_i),
    .ex_delayslot(ex_delayslot_i),
    .ex_reg1(ex_rdata1_i),
    .ex_reg2(ex_rdata2_i),
    .ex_imm(ex_imm_i),
    .ex_exop(ex_ex_op_i),
    .ex_we1(ex_we1_i),
    .ex_waddr1(ex_waddr1_i),
    .ex_hilo(ex_hilo_safe),
    .ex_inst_type(ex_inst_type),
    `ifdef ENABLE_FPU
    .ex_fpu_op(ex_fpu_op),
    .ex_fpu_raddr1(ex_fpu_raddr1),
    .ex_fpu_raddr2(ex_fpu_raddr2),
    .ex_fpu_we(ex_fpu_we),
    .ex_fpu_waddr(ex_fpu_waddr),
    .ex_fpu_fcsr(ex_fpu_fcsr),
    .ex_fpu_reg1(ex_fpu_reg1),
    .ex_fpu_reg2(ex_fpu_reg2),
    `endif
    .id_in_delayslot(id_delayslot_i),
    .idex_except(idex_except)
);

execute execute_instance(
    .clk(clk),
    .rst(rst),

    .flush(flush), // flush mult/div pipeline
    .pc(ex_pc_i),
    .inst(ex_inst_i),
    .stall_mm(stall.stall_mem),

    .hilo_i(ex_hilo_safe),
    .cp0_rdata_i(ex_cp0_rdata),
    .reg1(ex_rdata1_i),
    .reg2(ex_rdata2_i),
    .imm(ex_imm_i),
    .ex_op(ex_ex_op_i),
    .inst_type(ex_inst_type),
    .we1_i(ex_we1_i),
    .waddr1_i(ex_waddr1_i),
    .idex_except(idex_except),
    .data_mmu_result(data_mmu_result),
    .user_mode(user_mode_o),

    .cp0_raddr(ex_cp0_raddr),
    .cp0_rsel(ex_cp0_rsel),
    .wp1_o(ex_wp1_o),
    .we_hilo(ex_we_hilo_o),
    .hilo_o(ex_hilo_o),
    .memory_o(ex_memory_o),
    .cp0_wp_o(ex_cp0_wp_o),
    .tlb_ctrl_o(ex_tlb_ctrl),
    // exception output
    .ex_except(ex_except_o),

    `ifdef ENABLE_FPU
    // fpu
    .fpu_op(ex_fpu_op),
    .fpu_raddr1(ex_fpu_raddr1),
    .fpu_raddr2(ex_fpu_raddr2),
    .fpu_we(ex_fpu_we),
    .fpu_waddr(ex_fpu_waddr),
    .fpu_fccr(fpu_fccr),
    .fpu_reg1(ex_fpu_reg1),
    .fpu_reg2(ex_fpu_reg2),
    .fcsr(ex_fpu_fcsr),
    .fcsr_wdata(ex_fcsr_wdata),
    .fcsr_we(ex_fcsr_we),
    .fpu_wr(ex_fpu_wr),
    .fpu_except(ex_fpu_except),
    `endif

    .ex_stall_req(ex_stall_req)
);

// wb stage write control
assign tlbrw_we = mem_tlb_ctrl.tlbwi | mem_tlb_ctrl.tlbwr;
assign tlbrw_index = (mem_tlb_ctrl.tlbwi) ? cp0_regs_mem.index : cp0_regs_mem.random;
assign ex_tlbrw_index = cp0_regs_ex.index;
mmu mmu_instance(
    .clk(clk),
    .rst(rst),
    .asid(asid_o),
    .user_mode(user_mode_o),
    .kseg0_uncached(kseg0_uncached_o),
    .inst_vaddr(pc),
    .data_vaddr(ex_memory_o.addr), // ex stage

    .inst_mmu_result(inst_mmu_result),
    .data_mmu_result(data_mmu_result), // out at ex stage
    
    .tlbp_entry_hi(cp0_regs_ex.entry_hi), // ex stage
    .tlbp_index(tlbp_index), // ex stage

    .ex_tlbrw_index(ex_tlbrw_index), // ex stage
    .mem_tlbrw_index(tlbrw_index), // mem stage
    .mem_tlbrw_we(tlbrw_we), // mem stage
    .mem_tlbrw_wdata(tlbrw_wdata), // mem stage
    .ex_tlbrw_rdata(tlbrw_rdata) // ex stage
);

word_t mem_tlbp_index;
tlbEntry_t mem_tlbrw_rdata;

ex_mem ex_mem_instance(
    .clk(clk),
    .rst(rst),
    .stall(stall),
    .flush(flush),

    .ex_delayslot(ex_delayslot_i),
    .ex_op(ex_ex_op_i),
    .ex_pc(ex_pc_i), // from id/ex stage
    .ex_wp1(ex_wp1_o),
    .ex_we_hilo(ex_we_hilo_o),
    .ex_whilo(ex_hilo_o),
    .ex_memory(ex_memory_o),
    .ex_cp0_wp(ex_cp0_wp_o),
    .ex_except(ex_except_o),
    .ex_data_mmu_result(data_mmu_result),
    .ex_tlb_ctrl(ex_tlb_ctrl),
    .ex_tlbp_index(tlbp_index),
    .ex_tlbrw_rdata(tlbrw_rdata),
    .ex_inst_type(ex_inst_type),
    `ifdef ENABLE_FPU
    .ex_fcsr_wdata(ex_fcsr_wdata),
    .ex_fcsr_we(ex_fcsr_we),
    .ex_fpu_wr(ex_fpu_wr),
    .ex_fpu_except(ex_fpu_except),
    `endif
    
    .mem_delayslot(mem_delayslot),
    .mem_op(mem_op),
    .mem_pc(mem_pc_i),
    .mem_wp1(mem_wp1_i),
    .mem_we_hilo(mem_we_hilo_i),
    .mem_whilo(mem_hilo_i),
    .mem_memory(mem_memory_i),
    .mem_cp0_wp(mem_cp0_wp_i),
    .mem_except(mem_except_i),
    .mem_data_mmu_result(mem_data_mmu_result),
    .mem_tlbp_index(mem_tlbp_index),
    .mem_tlbrw_rdata(mem_tlbrw_rdata),
    .mem_inst_type(mem_inst_type),
    `ifdef ENABLE_FPU
    .mem_fcsr_wdata(mem_fcsr_wdata_i),
    .mem_fcsr_we(mem_fcsr_we_i),
    .mem_fpu_wr(mem_fpu_wr_i),
    .mem_fpu_except(mem_fpu_except),
    `endif
    .mem_tlb_ctrl(mem_tlb_ctrl)
);

bit_t except_already_occur;
assign except_already_occur = (|mem_except_i);

except except_instance(
    .rst(rst),

    .pc(mem_pc_i),
    .valid(mem_op != OP_NOP),
    .memory_req(mem_memory_i),
    .in_delayslot(mem_delayslot),
    .except_types(mem_except_i),

    .cp0_regs(cp0_regs_mem),
    .interrupt_flag(interrupt_exc_req),
    `ifdef ENABLE_FPU
    .fpu_except(mem_fpu_except), // from mem stage
    `endif
    .except_req(except_req_o)
);

cp0_regs cp0_regs_instance(
    .clk(clk),
    .rst(rst),

    .raddr(ex_cp0_raddr),
    .rsel(ex_cp0_rsel),
    .rdata(ex_cp0_rdata),

    .wp(mem_cp0_wp_i), // mem stage
    .except_occur(except_already_occur),
    .except_req(except_req_o),
    .interrupt_flag(interrupt_flag),

    .tlbp_en(mem_tlb_ctrl.tlbp), // mem stage
    .tlbp_index(mem_tlbp_index),
    .tlbr_en(mem_tlb_ctrl.tlbr),
    .tlbrw_rdata(mem_tlbrw_rdata),
    .tlbwr_en(mem_tlb_ctrl.tlbwr),
    .tlbrw_wdata(tlbrw_wdata), // to ex stage

    .regs_ex(cp0_regs_ex),
    .regs_mem(cp0_regs_mem),
    .user_mode(user_mode_o),
    .timer_int(timer_int_o),
    .asid(asid_o),
    .kseg0_uncached(kseg0_uncached_o)
);

mem #(
    .DATA_WIDTH(32),
    .LINE_WIDTH(`DCACHE_LINE_WIDTH),
    .SET_ASSOC(`DCACHE_SET_ASSOC),
    .CACHE_SIZE(`DCACHE_CACHE_SIZE)
) mem_instance(
    .clk(clk),
    .rst(rst),
    .flush(flush),

    .op(mem_op),
    .ll_bit_unsafe(ll_bit_o),
    .data_mmu_result_i(mem_data_mmu_result),
    .inst_type(mem_inst_type),
    .except_already_occur(except_already_occur),
    
    // inputs that need to pipe to wb stage
    .cache_memory(mem_memory_i),
    .cache_pc(mem_pc_i),
    .cache_wp(mem_wp1_i),
    .cache_we_hilo(mem_we_hilo_i),
    .cache_hilo(mem_hilo_i),
    `ifdef ENABLE_FPU
    .cache_fcsr_wdata(mem_fcsr_wdata_i),
    .cache_fcsr_we(mem_fcsr_we_i),
    .cache_fpu_wr(mem_fpu_wr_i),
    `endif

    // cache 2 stage data bypass to id stage
    .cache_2_wp(cache_2_wp),
    .cache_2_we_hilo(cache_2_we_hilo),
    .cache_2_hilo(cache_2_hilo),
    .cache_2_memory(cache_2_memory),
    `ifdef ENABLE_FPU
    .cache_2_fcsr_wdata(cache_2_fcsr_wdata),
    .cache_2_fcsr_we(cache_2_fcsr_we),
    .cache_2_fpu_wr(cache_2_fpu_wr),
    `endif

    // mem stage data bypass and pipe to wb stage
    .mem_pc(mem_pc),
    .mem_wp1(mem_wp1),
    .mem_we_hilo(mem_we_hilo),
    .mem_hilo(mem_hilo),
    .mem_memory(mem_memory),
    `ifdef ENABLE_FPU
    .mem_fcsr_wdata(mem_fcsr_wdata),
    .mem_fcsr_we(mem_fcsr_we),
    .mem_fpu_wr(mem_fpu_wr),
    `endif
    .mem_llbit_we(mem_llbit_we),
    .mem_llbit_wdata(mem_llbit_wdata),
    
    // control signals to icache and axi dbus
    .mem_stall_req(mem_stall_req),
    .ready(dcache_ready),

    .invalidate_icache(invalidate_icache),
    .invalidate_addr(invalidate_addr),
    .dcache_axi_req(dcache_axi_req),
    .dcache_axi_resp(dcache_axi_resp),
    .uncached_axi_req(uncached_axi_req),
    .uncached_axi_resp(uncached_axi_resp)
);


mem_wb mem_wb_instance(
    .clk(clk),
    .rst(rst),

    .stall(stall),
    .flush(flush),

    .mem_pc(mem_pc), // from ex/mem stage
    .mem_wp1(mem_wp1),
    .mem_we_hilo(mem_we_hilo),
    .mem_hilo(mem_hilo),
    .mem_llbit_we(mem_llbit_we),
    .mem_llbit_wdata(mem_llbit_wdata),
    `ifdef ENABLE_FPU
    .mem_fcsr_wdata(mem_fcsr_wdata),
    .mem_fcsr_we(mem_fcsr_we),
    .mem_fpu_wr(mem_fpu_wr),
    `endif

    .wb_pc(wb_pc_i),
    .wb_wp1(wb_wp1_i),
    .wb_we_hilo(wb_we_hilo_i),
    .wb_hilo(wb_hilo_i),
    `ifdef ENABLE_FPU
    .wb_fcsr_wdata(wb_fcsr_wdata),
    .wb_fcsr_we(wb_fcsr_we),
    .wb_fpu_wr(wb_fpu_wr),
    `endif
    .wb_llbit_we(wb_llbit_we),
    .wb_llbit_wdata(wb_llbit_wdata)
);

endmodule
