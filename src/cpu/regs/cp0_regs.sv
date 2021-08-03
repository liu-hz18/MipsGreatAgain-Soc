`include "defines.svh"

module cp0_regs (
    input clk, rst,

    // read port 1, valid for mem stage
    input regaddr_t raddr,
    input wire[2:0] rsel,
    output word_t rdata,

    // write port 1
	input cp0WriteControl_t wp,
	input bit_t except_occur,

	// exception info
	input exceptControl_t except_req,
	input wire [7:0] interrupt_flag,

	// TLB RW infos
	input bit_t tlbp_en,
	input word_t tlbp_index,
	input bit_t tlbr_en,
	input tlbEntry_t tlbrw_rdata,
	input bit_t tlbwr_en,
	output tlbEntry_t tlbrw_wdata, // mem stage

    // CP0 infos
	output CP0Regs_t regs_ex,
	output CP0Regs_t regs_mem,
    output bit_t user_mode,
    output reg timer_int,
    output wire[7:0] asid,
	output bit_t kseg0_uncached
);

bit_t we;
regaddr_t waddr;
wire[2:0] wsel;
word_t wdata;
assign we = wp.we & ~except_occur;
assign waddr = wp.waddr;
assign wdata = wp.wdata;
assign wsel = wp.wsel;

// N * 32 bits reg, only one dimension
CP0Regs_t cp0_regs_new, cp0_regs_inner;
assign regs_mem = cp0_regs_inner;
// following signals are used in ex stage, so we provide data bypass.
assign regs_ex = cp0_regs_new;
assign asid = cp0_regs_new.entry_hi[7:0];
assign user_mode = (cp0_regs_new.status[4:1] == 4'b1000);
assign kseg0_uncached = (cp0_regs_new.config0[2:0] == 3'd2);

// TLB RW infos
assign tlbrw_wdata.vpn2 = cp0_regs_new.entry_hi[31:13];
assign tlbrw_wdata.asid = cp0_regs_new.entry_hi[7:0];
assign tlbrw_wdata.page_mask = {4'b0, cp0_regs_new.page_mask[24:13]};
// assign tlbrw_wdata.page_mask = cp0_regs_new.page_mask[28:13];
// assign tlbrw_wdata.pfn1 = cp0_regs_new.entry_lo1[29:6];
assign tlbrw_wdata.pfn1 = {4'b0, cp0_regs_new.entry_lo1[25:6]};
assign tlbrw_wdata.c1 = cp0_regs_new.entry_lo1[5:3];
assign tlbrw_wdata.d1 = cp0_regs_new.entry_lo1[2];
assign tlbrw_wdata.v1 = cp0_regs_new.entry_lo1[1];
// assign tlbrw_wdata.pfn0 = cp0_regs_new.entry_lo0[29:6];
assign tlbrw_wdata.pfn0 = {4'b0, cp0_regs_new.entry_lo0[25:6]};
assign tlbrw_wdata.c0 = cp0_regs_new.entry_lo0[5:3];
assign tlbrw_wdata.d0 = cp0_regs_new.entry_lo0[2];
assign tlbrw_wdata.v0 = cp0_regs_new.entry_lo0[1];
assign tlbrw_wdata.G = cp0_regs_new.entry_lo0[0] & cp0_regs_new.entry_lo1[0];

// read data from CP0s
always_comb begin: read_data
    if (rsel == 3'b0) begin
		unique case(raddr)
		// data bypass have been solved in cp0_regs_new assign.
		5'd0: rdata = cp0_regs_new.index;
		5'd1: rdata = cp0_regs_new.random;
		5'd2: rdata = cp0_regs_new.entry_lo0;
		5'd3: rdata = cp0_regs_new.entry_lo1;
		5'd4: rdata = cp0_regs_new.context_;
		5'd5: rdata = cp0_regs_new.page_mask;
		5'd6: rdata = cp0_regs_new.wired;
		5'd8: rdata = cp0_regs_new.bad_vaddr;
		5'd9: rdata = cp0_regs_new.count;
		5'd10: rdata = cp0_regs_new.entry_hi;
		5'd11: rdata = {cp0_regs_new.compare[31], cp0_regs_new.compare[30] | timer_int, cp0_regs_new.compare[29:0]};
		5'd12: rdata = cp0_regs_new.status;
		5'd13: rdata = cp0_regs_new.cause;
		5'd14: rdata = cp0_regs_new.epc;
		5'd15: rdata = cp0_regs_new.prid;
		5'd16: rdata = cp0_regs_new.config0;
		default: rdata = 32'b0;
		endcase
    end else begin
        rdata = 32'b0;
    end
end

localparam int TLB_ENTRY_NUM  = `TLB_ENTRIES_NUM - 1;
localparam int IC_SET_PER_WAY = $clog2(`ICACHE_CACHE_SIZE / `ICACHE_SET_ASSOC / `ICACHE_LINE_WIDTH / 64);
localparam int IC_LINE_SIZE   = $clog2(`ICACHE_LINE_WIDTH / 32) + 1;
localparam int IC_ASSOC       = `ICACHE_SET_ASSOC - 1;
localparam int DC_SET_PER_WAY = $clog2(`DCACHE_CACHE_SIZE / `DCACHE_SET_ASSOC / `DCACHE_LINE_WIDTH / 64);
localparam int DC_LINE_SIZE   = $clog2(`DCACHE_LINE_WIDTH / 32) + 1;
localparam int DC_ASSOC       = `DCACHE_SET_ASSOC - 1;

word_t config0_init, config1_init, prid_init;
assign config0_init = {
    1'b1,   // M, config1 is implemented
    15'b0,  // undefined
	1'b0,   // BE: Little endian
	2'b0,   // AT: MIPS32
	3'b0,   // AR: MIPS Release 1
    3'b1,   // MT: MMU Type ( Standard TLB )
    3'b0,
	1'b0,   // VI: Instruction Cache is not virtual
    3'd3    // K0: Kseg0 coherency algorithm
};
`ifdef ENABLE_FPU
localparam logic FPU_ENABLED  = 1'b1;
`else
localparam logic FPU_ENABLED  = 1'b0;
`endif
assign config1_init = {
	1'b0, // M, config2 not implemented
	TLB_ENTRY_NUM[5:0], // tlb entry num - 1
	IC_SET_PER_WAY[2:0],
	IC_LINE_SIZE[2:0],
	IC_ASSOC[2:0],
	DC_SET_PER_WAY[2:0],
	DC_LINE_SIZE[2:0],
	DC_ASSOC[2:0],
	6'd0,
	FPU_ENABLED
};
assign prid_init = {8'b0, 8'b1, 16'h8000};

// compare and generate timer interruption
// timer_int 接管 cause.ti 位，实现更简单的读写逻辑
always_ff @(posedge clk) begin
    if (rst) begin
        timer_int <= 1'b0;
    end else if (cp0_regs_inner.compare != 32'b0 && cp0_regs_inner.compare == cp0_regs_inner.count) begin
        timer_int <= 1'b1;
    end else if (we && wsel == 3'b0 && waddr == 5'd11) begin
        timer_int <= 1'b0;
    end
end

logic count_switch;
always_ff @(posedge clk) begin
	if (rst) count_switch <= 1'b0;
	else count_switch <= ~count_switch;
end

always_comb begin: write_data
    cp0_regs_new = cp0_regs_inner;
    cp0_regs_new.count = cp0_regs_inner.count + count_switch; // count 计数器自增

	`ifdef ENABLE_TLB
	cp0_regs_new.random[`TLB_ENTRIES_NUM_LOG2-1:0] = cp0_regs_inner.random[`TLB_ENTRIES_NUM_LOG2-1:0] + tlbwr_en;
	if ((&cp0_regs_inner.random[`TLB_ENTRIES_NUM_LOG2-1:0]) & tlbwr_en) begin
		cp0_regs_new.random = cp0_regs_inner.wired;
	end
	`endif

	cp0_regs_new.cause.ip[7:2] = interrupt_flag[7:2];

    // wb stage
    if (we) begin
        if (wsel == 3'b0) begin
			unique case(waddr)
			5'd0: cp0_regs_new.index[`TLB_ENTRIES_NUM_LOG2-1:0] = wdata[`TLB_ENTRIES_NUM_LOG2-1:0];
			5'd2: cp0_regs_new.entry_lo0[25:0] = wdata[25:0]; // in gs232
			5'd3: cp0_regs_new.entry_lo1[25:0] = wdata[25:0];
			// 5'd2: cp0_regs_new.entry_lo0 = wdata[29:0]; // in non-trival
			// 5'd3: cp0_regs_new.entry_lo1 = wdata[29:0];
			5'd4: cp0_regs_new.context_[31:23] = wdata[31:23];
			5'd5: cp0_regs_new.page_mask[24:13] = wdata[24:13]; // in gs232
			// 5'd5: cp0_regs_new.page_mask[28:13] = wdata[28:13]; // in non-trivial
			5'd6: begin
				cp0_regs_new.random[`TLB_ENTRIES_NUM_LOG2-1:0] = `TLB_ENTRIES_NUM - 1;
				cp0_regs_new.wired[`TLB_ENTRIES_NUM_LOG2-1:0] = wdata[`TLB_ENTRIES_NUM_LOG2-1:0];
			end
			5'd9: cp0_regs_new.count = wdata;
			5'd10: begin
				cp0_regs_new.entry_hi[31:13] = wdata[31:13];
				cp0_regs_new.entry_hi[7:0] = wdata[7:0];
			end
			5'd11: cp0_regs_new.compare = wdata;
			5'd12: begin
				cp0_regs_new.status.cu0 = wdata[28];
				`ifdef ENABLE_FPU
				cp0_regs_new.status.cu1 = wdata[29];
				`endif
				cp0_regs_new.status.bev = wdata[22];
				cp0_regs_new.status.im = wdata[15:8];
				cp0_regs_new.status.um = wdata[4];
				cp0_regs_new.status[2:0] = wdata[2:0]; // erl, exl, ie
			end
			5'd13: begin
				cp0_regs_new.cause.iv = wdata[23];
				cp0_regs_new.cause.ip[1:0] = wdata[9:8];
			end
			5'd14: cp0_regs_new.epc = wdata;
			5'd16: cp0_regs_new.config0[2:0] = wdata[2:0];
			default: begin end
			endcase
        end else if (wsel == 3'b1) begin
            if (waddr == 5'd15) begin
                cp0_regs_new.ebase[29:12] = wdata[29:12];
            end
        end
    end

	// TLBR / TLBP insts at WB stage
	if (tlbr_en) begin
		cp0_regs_new.entry_hi[31:13] = tlbrw_rdata.vpn2;
		cp0_regs_new.entry_hi[7:0] = tlbrw_rdata.asid;
		cp0_regs_new.entry_lo1 = { 6'b0, tlbrw_rdata.pfn1[19:0], tlbrw_rdata.c1, tlbrw_rdata.d1, tlbrw_rdata.v1, tlbrw_rdata.G };
		cp0_regs_new.entry_lo0 = { 6'b0, tlbrw_rdata.pfn0[19:0], tlbrw_rdata.c0, tlbrw_rdata.d0, tlbrw_rdata.v0, tlbrw_rdata.G };
		cp0_regs_new.page_mask[24:13] = tlbrw_rdata.page_mask[11:0]; // in gs232
		// cp0_regs_new.entry_lo1 = { 2'b0, tlbrw_rdata.pfn1, tlbrw_rdata.c1, tlbrw_rdata.d1, tlbrw_rdata.v1, tlbrw_rdata.G };
		// cp0_regs_new.entry_lo0 = { 2'b0, tlbrw_rdata.pfn0, tlbrw_rdata.c0, tlbrw_rdata.d0, tlbrw_rdata.v0, tlbrw_rdata.G };
		// cp0_regs_new.page_mask[28:13] = tlbrw_rdata.page_mask[15:0]; // in non-trivial
	end

	if (tlbp_en) begin
		cp0_regs_new.index = tlbp_index;
	end

    // exception record into CP0
	if (except_req.flush) begin
		if (except_req.eret) begin
			if (cp0_regs_new.status.erl) begin
				cp0_regs_new.status.erl = 1'b0; // ERL
			end else begin
				cp0_regs_new.status.exl = 1'b0; // EXL
			end
		end else begin
			if (~cp0_regs_new.status.exl) begin
				if (except_req.delayslot) begin
					cp0_regs_new.epc = except_req.cur_pc - 32'h4;
					cp0_regs_new.cause.bd = 1'b1;
				end else begin
					cp0_regs_new.epc = except_req.cur_pc;
					cp0_regs_new.cause.bd = 1'b0;
				end
			end

			cp0_regs_new.status.exl = 1'b1;
			cp0_regs_new.cause.exc_code = except_req.code;

			if (except_req.code == `EXCCODE_CpU) begin
				cp0_regs_new.cause.ce = except_req.extra[1:0]; // 协处理器错误
			end

			if (except_req.code == `EXCCODE_ADEL || except_req.code == `EXCCODE_ADES) begin
				cp0_regs_new.bad_vaddr = except_req.extra;
			end else if (except_req.code == `EXCCODE_TLBL || except_req.code == `EXCCODE_TLBS) begin
				cp0_regs_new.bad_vaddr = except_req.extra;
				cp0_regs_new.context_[22:4] = except_req.extra[31:13]; // context.bad_vpn2
				cp0_regs_new.entry_hi[31:13] = except_req.extra[31:13];  // entry_hi.vpn2
			end
		end
	end
end

always @(posedge clk) begin
	if (rst) begin
		// the initial value of registers
		cp0_regs_inner.index     <= `ZERO_WORD;
		cp0_regs_inner.random    <= `TLB_ENTRIES_NUM - 1;
		cp0_regs_inner.entry_lo0 <= `ZERO_WORD;
		cp0_regs_inner.entry_lo1 <= `ZERO_WORD;
		cp0_regs_inner.context_  <= `ZERO_WORD;
		cp0_regs_inner.page_mask <= `ZERO_WORD;
		cp0_regs_inner.wired     <= `ZERO_WORD;
		cp0_regs_inner.bad_vaddr <= `ZERO_WORD;
		cp0_regs_inner.count     <= `ZERO_WORD;
		cp0_regs_inner.entry_hi  <= `ZERO_WORD;
		cp0_regs_inner.compare   <= `ZERO_WORD;
		`ifdef ENABLE_FPU
		cp0_regs_inner.status    <= 32'b0011_0000_0100_0000_0000_0000_0000_0000;
		`else
		cp0_regs_inner.status    <= 32'b0001_0000_0100_0000_0000_0000_0000_0000;
		`endif
		cp0_regs_inner.cause     <= `ZERO_WORD;
		cp0_regs_inner.epc       <= `ZERO_WORD;
		cp0_regs_inner.prid      <= prid_init;
		cp0_regs_inner.config0   <= config0_init;
		cp0_regs_inner.error_epc <= `ZERO_WORD;
		cp0_regs_inner.ebase     <= 32'h80000000;
		cp0_regs_inner.config1 <= config1_init;
		// temporarily unused CP0 regs
		cp0_regs_inner.desave <= `ZERO_WORD;
		cp0_regs_inner.tag_hi <= `ZERO_WORD;
		cp0_regs_inner.tag_lo <= `ZERO_WORD;
		cp0_regs_inner.cache_err <= `ZERO_WORD;
		cp0_regs_inner.err_ctl <= `ZERO_WORD;
		cp0_regs_inner.perf_cnt <= `ZERO_WORD;
		cp0_regs_inner.depc <= `ZERO_WORD;
		cp0_regs_inner.debug <= `ZERO_WORD;
		cp0_regs_inner.impl_lfsr32 <= `ZERO_WORD;
		cp0_regs_inner.reserved21 <= `ZERO_WORD;
		cp0_regs_inner.reserved20 <= `ZERO_WORD;
		cp0_regs_inner.watch_hi <= `ZERO_WORD;
		cp0_regs_inner.watch_lo <= `ZERO_WORD;
		cp0_regs_inner.ll_addr <= `ZERO_WORD;
		cp0_regs_inner.reserved7 <= `ZERO_WORD;
	end else begin // clk 时写入
		cp0_regs_inner <= cp0_regs_new;
	end
end

endmodule


module cp0_write_mask(
	input rst,
	input [2:0] sel,
	input regaddr_t addr,
	output word_t mask
);

word_t tlb_index_mask;
assign tlb_index_mask = {
	1'b1,
	{(31 - `TLB_ENTRIES_NUM_LOG2){1'b0}},
	{`TLB_ENTRIES_NUM_LOG2{1'b1}}
};

always_comb
begin
	if(rst)
	begin
		mask = 32'b0;
	end else if(sel == 3'd0) begin
		unique case(addr)
		5'd0:  mask = tlb_index_mask; // index
		5'd1:  mask = 32'h00000000;  // random
		// 5'd2:  mask = 32'h7fffffff;  // entry_lo0 in non-trival
		// 5'd3:  mask = 32'h7fffffff;  // entry_lo1 in non-trival
		5'd2:  mask = 32'h03ffffff;  // entry_lo0 in gs232
		5'd3:  mask = 32'h03ffffff;  // entry_lo1 in gs232
		5'd4:  mask = 32'b1111_1111_1000_0000_0000_0000_0000_0000;  // context
		// 5'd5:  mask = 32'b0001_1111_1111_1111_1111_0000_0000_0000;  // page_mask in non-trival
		5'd5:  mask = 32'b0000_0001_1111_1111_1111_0000_0000_0000;  // page_mask in gs232
		5'd6:  mask = tlb_index_mask; // wired
		5'd8:  mask = 32'h00000000;  // bad_vaddr
		5'd9:  mask = 32'hffffffff;  // count, (软件可以设置count, 以实现计时器复位)
		// 5'd10: mask = 32'hfffff0ff;  // entry_hi in non-trival
		5'd10: mask = 32'hffffe0ff; // entry_hi in gs232
		5'd11: mask = 32'hffffffff;  // compare
		5'd12: mask = 32'b1111_1010_0111_1000_1111_1111_0001_0111;  // status
		5'd13: mask = 32'b0000_0000_1100_0000_0000_0011_0000_0000;  // cause
		5'd14: mask = 32'hffffffff;  // epc
		5'd15: mask = 32'h00000000;  // prid
		5'd16: mask = 32'b0000_0000_0000_0000_0000_0000_0000_0111;  // config
		5'd30: mask = 32'hffffffff;  // error_epc
		default: mask = 32'b0;
		endcase
	end else if(sel == 3'd1) begin
		unique case(addr)
		5'd15: mask = 32'h3ffff000;  // ebase
		default: mask = 32'b0;
		endcase
	end else begin
		mask = 32'b0;
	end
end

endmodule
