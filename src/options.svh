`ifndef OPTIONS_SVH
`define OPTIONS_SVH

// common options
// NOTE: if you want to disable it, you may `annotate it`
// `define ENABLE_TLB
// `define ENABLE_EXT_INS
// `define ENABLE_FPU
// `define DISABLE_SERIAL_PORT // trick: disable serial port write to improve score :)

// tlb entries
`define TLB_ENTRIES_NUM 32

// branch predict btb config
`define BTB_SIZE 512

// I-cache config
`define ICACHE_LINE_WIDTH 256 // bits
`define ICACHE_SET_ASSOC 4
`define ICACHE_CACHE_SIZE 16*1024*8 // bits

// D-cache config
`define DCACHE_LINE_WIDTH 256
`define DCACHE_SET_ASSOC 4
`define DCACHE_CACHE_SIZE 16*1024*8

`endif
