`ifndef DEFINES_SVH
`define DEFINES_SVH

`default_nettype wire
`timescale 1ns / 1ps

`include "options.svh"

// data formats
typedef logic bit_t;
typedef logic[7:0] byte_t;
typedef logic[15:0] halfword_t;
typedef logic[31:0] word_t;
typedef logic[63:0] doubleword_t;

`define ZERO_BIT 1'b0
`define ZERO_BYTE 8'h0
`define ZERO_HWORD 16'h0
`define ZERO_WORD 32'h0
`define ZERO_DWORD 64'h0

// pc init
`define PC_RESET_VECTOR 32'hbfc0_0000 // in kseg1
`define PC_TRAP_VECTOR  32'hbfc0_0380 // in kseg1

// opcode for ex stage(not opcode in instruction!)
// operation
typedef enum {
	/* instruction control instructions */
	OP_NOP, OP_SSNOP,
		
	/* Release 2 instructions */
	OP_EXT, OP_INS, OP_SEB, OP_SEH, OP_WSBH,
	OP_ROR, OP_RORV,

	/* arithmetic instructions */
	OP_ADD, OP_ADDU, OP_SUB, OP_SUBU,
	OP_CLO, OP_CLZ,
	OP_DIV, OP_DIVU,
	OP_MADD, OP_MADDU, OP_MSUB, OP_MSUBU,
	OP_MUL, OP_MULT, OP_MULTU,
	OP_SLT, OP_SLTU,

	/* logical instructions */
	OP_AND, OP_LUI, OP_NOR, OP_OR, OP_XOR, 

	/* branch and jump instructions */
	OP_BEQ, OP_BGEZ, OP_BGEZAL,
	OP_BGTZ, OP_BLEZ, OP_BLTZ, OP_BLTZAL, OP_BNE,
	OP_J, OP_JAL, OP_JALR, OP_JR, OP_BC1,
	// OP_B,   the same as OP_BEQ with rs = rt = 0
	// OP_BAL, the same as OP_BGEZAL with rs = 0

	/* load, store, and memory control instructions */
	OP_LB, OP_LBU, OP_LH, OP_LHU,
	OP_LW, OP_LWL, OP_LWR, OP_SB,
	OP_SH, OP_SW, OP_SWL, OP_SWR,
	OP_LL, OP_SC, OP_LWC1, OP_SWC1,
	OP_LDC1A, OP_SDC1A, OP_LDC1B, OP_SDC1B,
	// OP_PERF, OP_SYNC, regarded as OP_NOP

	/* move instructions */
	OP_MFHI, OP_MFLO, OP_MTHI, OP_MTLO,
	OP_MOVN, OP_MOVZ, OP_MOVCI,

	/* shift instructions */
	OP_SLL, OP_SLLV, OP_SRA, OP_SRAV, OP_SRL, OP_SRLV, 

	/* trap instructions */
	OP_BREAK, OP_SYSCALL, OP_TEQ, OP_TNE,
	OP_TGEU, OP_TGE, OP_TLTU, OP_TLT, 

	/* privileged instructions */
	OP_CACHE, OP_ERET, OP_MFC0, OP_MTC0,
	OP_TLBP, OP_TLBR, OP_TLBWI, OP_TLBWR, OP_WAIT,

	/* FPU/CPU data transfer */
	OP_CFC1, OP_CTC1, OP_MFC1, OP_MTC1,

	/* FPU inner instructions */
	OP_FPU,

	/* invalid */
	OP_INVALID
} exOperation_t;

// op class info in pipeline
typedef struct packed {
	bit_t invalid_inst;

	bit_t branch_inst; // high bit
	bit_t jump_inst; 
	bit_t tlbp_inst;
	bit_t tlbr_inst;
	bit_t tlbwi_inst;
	bit_t tlbwr_inst;
	bit_t load_inst;
	bit_t store_inst;
	bit_t write_hilo_inst;
	bit_t priv_inst;
	bit_t eret_inst;
	bit_t break_inst;
	bit_t syscall_inst;
	bit_t multi_cyc_inst;
	bit_t signed_multi_cyc_inst;
	bit_t ll_inst;
	bit_t sc_inst;
	bit_t unaligned_inst; // mem
} inst_type_t;

// Registers
`define REG_NUM 32
`define REG_DATA_WIDTH 32
`define REG_ADDR_WIDTH 5
`define ZERO_REG_ADDR 5'b00000
typedef logic [`REG_ADDR_WIDTH-1:0] regaddr_t;
typedef struct packed {
	bit_t we;
	regaddr_t waddr;
	word_t wdata;
} regWritePort_t;

// stall control (6bit)
typedef struct packed {
	bit_t hold_pc; // high bit
	bit_t stall_if; 
	bit_t stall_id;
	bit_t stall_ex;
	bit_t stall_mem;
	bit_t stall_wb;  // not used
} stall_t;

// memory or fetch
`define INST_WIDTH 32
`define ADDR_WIDTH 32
typedef logic [`ADDR_WIDTH-1:0] addr_t;
typedef struct packed {
	bit_t ce;
	bit_t we; // read: we=0, write: we=1
	logic[3:0] sel;
	word_t wdata;
	word_t addr;
	logic invalidate_icache, invalidate_dcache;
} memControl_t;

// CP0
`define CP0_REG_NUM 32
`define CP0_REG_ADDR_WIDTH 5
`define CP0_DATA_WIDTH 32

// Status 32bit (only use im[7:0] and exl)
typedef struct packed {
	logic cu3, cu2, cu1, cu0;
	logic rp, fr, re, mx;
	logic px, bev, ts, sr;
	logic nmi, zero;
	logic [1:0] impl;
	logic [7:0] im;
	logic kx, sx, ux, um;
	logic r0, erl, exl, ie;
} CP0StatusReg_t;

// Cause 32bit (only use bd, ti, ip[7:0] and exc_code regions)
typedef struct packed {
	logic bd, ti;
	logic [1:0] ce;
	logic [3:0] zero27_24;
	logic iv, wp;
	logic [5:0] zero21_16;
	logic [7:0] ip;
	logic zero7;
	logic [4:0] exc_code;
	logic [1:0] zero1_0;
} CP0CauseReg_t;


// CP0 regs data format
// N * 32 bits reg, only one dimension
typedef struct packed {
	word_t ebase, config1;
	/* The order of the following registers is important.
	 * DO NOT change them. New registers must be added 
	 * BEFORE this comment */
	/* primary 32 registers (sel = 0) */
	word_t 
	 desave,    error_epc,  tag_hi,     tag_lo,    
	 cache_err, err_ctl,    perf_cnt,   depc,      
	 debug,     impl_lfsr32,  reserved21, reserved20,
	 watch_hi,  watch_lo,   ll_addr,    config0,   
	 prid,      epc; // 14
	CP0CauseReg_t  cause; // 13
	CP0StatusReg_t status; // 12
	word_t
	 compare,   entry_hi,   count,      bad_vaddr, 
	 reserved7, wired,      page_mask,  context_,  
	 entry_lo1, entry_lo0,  random,     index;
} CP0Regs_t;

typedef struct packed {
	bit_t     we;
	regaddr_t waddr;
	word_t    wdata;
	logic[2:0] wsel;
} cp0WriteControl_t;

// exception (interrupt is not included here.)
typedef struct packed {
	bit_t iaddr_miss, iaddr_illegal, iaddr_invalid;
	bit_t daddr_miss, daddr_illegal, daddr_invalid;
	bit_t syscall, break_, priv_inst, overflow;
	bit_t invalid_inst, trap, eret;
	bit_t daddr_unaligned, daddr_readonly;
} exceptType_t;

typedef struct packed {
	bit_t flush, delayslot, eret;
	logic[4:0] code;
	word_t cur_pc, jump_pc;
	word_t extra;
} exceptControl_t;

/* cause register exc_code field */
`define EXCCODE_INT   5'h00  // interrupt
`define EXCCODE_MOD   5'h01  // TLB modification exception
`define EXCCODE_TLBL  5'h02  // TLB exception (load or instruction fetch)
`define EXCCODE_TLBS  5'h03  // TLB exception (store)
`define EXCCODE_ADEL  5'h04  // address exception (load or instruction fetch)
`define EXCCODE_ADES  5'h05  // address exception (store)
`define EXCCODE_SYS   5'h08  // syscall
`define EXCCODE_BP    5'h09  // breakpoint
`define EXCCODE_RI    5'h0a  // reserved instruction exception
`define EXCCODE_CpU   5'h0b  // coprocesser unusable exception
`define EXCCODE_OV    5'h0c  // overflow
`define EXCCODE_TR    5'h0d  // trap
`define EXCCODE_FPE   5'h0f  // floating point exception

// TLB & MMU
`define TLB_ENTRIES_NUM_LOG2 $clog2(`TLB_ENTRIES_NUM)
typedef struct packed {
	word_t vaddr, paddr;
	bit_t uncached, invalid, miss, dirty, illegal;
} mmuResult_t;

// TLB defines
// TLB entries
typedef struct packed {
    logic [18:0] vpn2;
    logic [7:0] asid;
    logic [15:0] page_mask;
    logic [23:0] pfn0, pfn1;
    logic [2:0] c0, c1;
    logic d1, v1, d0, v0;
    logic G;
} tlbEntry_t;
typedef logic [`TLB_ENTRIES_NUM_LOG2-1:0] tlbIndex_t;
typedef logic [`TLB_ENTRIES_NUM * $bits(tlbEntry_t) - 1:0] tlbFlatEntries_t;
typedef struct packed {
	word_t phy_addr;
	logic [`TLB_ENTRIES_NUM_LOG2-1:0] which;
	logic miss, dirty, valid;
	logic [2:0] cache_flag;
} tlbResult_t;
typedef struct packed {
	logic tlbp, tlbr, tlbwr, tlbwi;
} tlbControl_t;

// AXI buses
interface cpu_ibus_if();
	logic read;
	word_t address;
	word_t rdata;
	logic branch_flag;
	word_t cpu_pc;
	exceptType_t cpu_if_except;
	logic valid;

	logic ready;
	logic stall;
	logic flush;
	logic stall_req;
	word_t bus_pc;
	exceptType_t bus_if_except;
	
	modport master (
		input stall, rdata, bus_pc, ready, bus_if_except, valid,
		output read, address, flush, stall_req, branch_flag, cpu_pc, cpu_if_except
	);

	modport slave (
		input read, address, flush, stall_req, branch_flag, cpu_pc, cpu_if_except,
		output stall, rdata, bus_pc, ready, bus_if_except, valid
	);

endinterface // cpu_ibus_if


interface cpu_dbus_if();
	logic read;
	logic write;
	logic[3:0] byte_en; // byteenable[i] corresponds to wdata[(i+1)*8-1 : i*8]
	word_t address;
	word_t rdata;
	word_t wdata;

	logic stall;

	logic invalidate_icache, invalidate_dcache;

	modport master (
		input stall, rdata,
		output read, write, wdata, address, byte_en, invalidate_icache, invalidate_dcache
	);

	modport slave (
		input read, write, wdata, address, byte_en, invalidate_icache, invalidate_dcache,
		output stall, rdata
	);

endinterface // cpu_dbus_if

typedef struct packed {
	// Read address(control) channel signals
    logic [31:0] araddr;
    logic [3 :0] arlen;
    logic [2 :0] arsize;
    logic [1 :0] arburst;
    logic [1 :0] arlock;
    logic [3 :0] arcache;
    logic [2 :0] arprot;
    logic        arvalid;
	// Read data channel signals
    logic        rready;
	// Write address(control) channel signals
    logic [31:0] awaddr;
    logic [3 :0] awlen;
    logic [2 :0] awsize;
    logic [1 :0] awburst;
    logic [1 :0] awlock;
    logic [3 :0] awcache;
    logic [2 :0] awprot;
    logic        awvalid;
	// Write data channel signals
    logic [31:0] wdata;
    logic [3 :0] wstrb;
    logic        wlast;
    logic        wvalid;
	// Write response channel
    logic        bready;
} axi_req_t;

typedef struct packed {
	// Read address(control) channel signals
	logic        arready;
	// Read data channel signals
	logic [31:0] rdata;
	logic [1 :0] rresp;
	logic        rlast;
	logic        rvalid;
	// Write address(control) channel signals
	logic        awready;
	// Write data channel signals
	logic        wready;
	// Write response channel
	logic [1 :0] bresp;
	logic        bvalid;
} axi_resp_t;


// FPU configs
typedef enum {
	FPU_OP_NOP,
	/* load and store */
	FPU_OP_LW, FPU_OP_SW,
	/* FPU/CPU data transfer */
	FPU_OP_CFC, FPU_OP_CTC, FPU_OP_MFC, FPU_OP_MTC,
	/* FPU arithematic */
	FPU_OP_ADD, FPU_OP_SUB, FPU_OP_COND, FPU_OP_NEG,
	FPU_OP_MUL, FPU_OP_DIV, FPU_OP_SQRT, FPU_OP_ABS,
	/* FPU conversion */
	FPU_OP_CVTW, FPU_OP_CVTS,
	FPU_OP_TRUNC, FPU_OP_ROUND,
	FPU_OP_CEIL, FPU_OP_FLOOR,
	/* FPU move */
	FPU_OP_MOV, FPU_OP_CMOV,
	/* invalid */
	FPU_OP_INVALID
} fpuOp_t;

typedef struct packed {
	logic unimpl;  // only used by 'cause'
	logic invalid;
	logic divided_by_zero;
	logic overflow;
	logic underflow;
	logic inexact;
} fpuExcept_t;

typedef struct packed {
	logic [7:0] fcc;
	logic fs;
	fpuExcept_t cause, enables, flags;
	logic [1:0] rm;
} fcsrReg_t;

`define FPU_REG_UNKNOWN      2'b00
`define FPU_REG_UNINTERPRET  2'b01
`define FPU_REG_S            2'b10  // single floating point
`define	FPU_REG_W            2'b11  // word fixed point
typedef logic [1:0] fpuRegFormat_t;

typedef struct packed {
	fpuRegFormat_t fmt;
	word_t val;
} fpuReg_t;

typedef struct packed {
	bit_t     we;
	regaddr_t waddr;
	fpuReg_t  wdata;
} fpuRegWriteReq_t;

`endif
