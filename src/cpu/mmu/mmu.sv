`include "defines.svh"

module mmu (
    input clk, rst,

    input wire[7:0] asid,
    input bit_t user_mode,
    input bit_t kseg0_uncached,
    input word_t inst_vaddr,
    input word_t data_vaddr, // give at ex stage

    output mmuResult_t inst_mmu_result,
    output mmuResult_t data_mmu_result, // return at ex stage

    // send and return in ex stage
    // tlbp
    input word_t  tlbp_entry_hi,
    output word_t tlbp_index,
    // tlbr, tlbwi, tlbwr
    input tlbIndex_t ex_tlbrw_index,
    input tlbIndex_t mem_tlbrw_index,
    input bit_t      mem_tlbrw_we,
    input tlbEntry_t mem_tlbrw_wdata,
    output tlbEntry_t ex_tlbrw_rdata
);

bit_t inst_mapped, data_mapped;
assign inst_mapped = (~inst_vaddr[31] || inst_vaddr[31:30] == 2'b11); // bfcxxx is not mapped.
assign data_mapped = (~data_vaddr[31] || data_vaddr[31:30] == 2'b11);
bit_t inst_uncached, data_uncached;
assign inst_uncached = (inst_vaddr[31:29] == 3'b101 || (kseg0_uncached && inst_vaddr[31:29] == 3'b100));
assign data_uncached = (data_vaddr[31:29] == 3'b101 || (kseg0_uncached && data_vaddr[31:29] == 3'b100));

`ifdef ENABLE_TLB
    tlbResult_t inst_tlb_result, data_tlb_result;

    assign inst_mmu_result.dirty = 1'b0;
    assign inst_mmu_result.miss = (inst_mapped & inst_tlb_result.miss);
    assign inst_mmu_result.illegal = (user_mode & inst_vaddr[31]);
    assign inst_mmu_result.invalid = (inst_mapped & ~inst_tlb_result.valid);
    assign inst_mmu_result.uncached = inst_uncached;
    assign inst_mmu_result.vaddr = inst_vaddr;
    assign inst_mmu_result.paddr = inst_mapped ? inst_tlb_result.phy_addr : { 3'b0, inst_vaddr[28:0] };

    assign data_mmu_result.dirty = (~data_mapped | data_tlb_result.dirty); // dirty is 1 when writable
    assign data_mmu_result.miss = (data_mapped & data_tlb_result.miss);
    assign data_mmu_result.illegal = (user_mode & data_vaddr[31]);
    assign data_mmu_result.invalid = (data_mapped & ~data_tlb_result.valid);
    assign data_mmu_result.uncached = data_uncached | (data_mapped && data_tlb_result.cache_flag == 3'd2);
    assign data_mmu_result.vaddr = data_vaddr;
    assign data_mmu_result.paddr = data_mapped ? data_tlb_result.phy_addr : { 3'b0, data_vaddr[28:0] };

    tlb tlb_instance(
        .clk(clk),
        .rst(rst),

        .asid(asid),
        .inst_vaddr(inst_vaddr),
        .data_vaddr(data_vaddr),
        .inst_tlb_result(inst_tlb_result),
        .data_tlb_result(data_tlb_result),

        .tlbp_entry_hi(tlbp_entry_hi),
        .tlbp_index(tlbp_index),

        .ex_tlbrw_index(ex_tlbrw_index),
        .mem_tlbrw_index(mem_tlbrw_index),
        .mem_tlbrw_we(mem_tlbrw_we),
        .mem_tlbrw_wdata(mem_tlbrw_wdata),
        .ex_tlbrw_rdata(ex_tlbrw_rdata)
    );

`else
    // simple for func test
    // memory layout:
    // kseg3(512M, mapped): [0xe000_0000, 0xffff_ffff] -> [0xe000_0000, 0xffff_ffff]
    // kseg2(512M, mapped): [0xc000_0000, 0xdfff_ffff] -> [0xc000_0000, 0xdfff_ffff]
    // kseg1(512M, unmapped, uncached): [0xa000_0000, 0xbfff_ffff] -> [0x0000_0000, 0x1fff_ffff]
    // kseg0(512M, unmapped, cached): [0x8000_0000, 0x9fff_ffff] -> [0x0000_0000, 0x1fff_ffff]
    // kuseg(2G, mapped): [0x0000_0000, 0x7fff_ffff] -> [0x0000_0000, 0x7fff_ffff]
    
    assign inst_mmu_result.dirty = 1'b0;
    assign inst_mmu_result.miss = (inst_mapped & 1'b0);
    assign inst_mmu_result.illegal = (user_mode & inst_vaddr[31]);
    assign inst_mmu_result.invalid = (inst_mapped & 1'b0);
    assign inst_mmu_result.uncached = 1'b0;
    assign inst_mmu_result.vaddr = inst_vaddr;

    assign data_mmu_result.dirty = (~data_mapped | 1'b1); // dirty is 1 when writable
    assign data_mmu_result.miss = (data_mapped & 1'b0);
    assign data_mmu_result.illegal = (user_mode & data_vaddr[31]);
    assign data_mmu_result.invalid = (data_mapped & 1'b0);
    assign data_mmu_result.uncached = data_uncached;
    assign data_mmu_result.vaddr = data_vaddr;

    simple_segment_mapping inst_mapping(
        .rst(rst),
        .vaddr(inst_vaddr),
        .paddr(inst_mmu_result.paddr)
    );

    simple_segment_mapping data_mapping(
        .rst(rst),
        .vaddr(data_vaddr),
        .paddr(data_mmu_result.paddr)
    );

    assign tlbp_index = '0;
    assign ex_tlbrw_rdata = '0;

`endif

endmodule


// just for function test. not MIPS32 standard.
module simple_segment_mapping (
    input rst,
    input word_t vaddr,
    output word_t paddr
);

always_comb begin: assign_paddr
    if (vaddr[31:30] == 2'b10) begin // kseg1(3'b101), kseg0(3'b100)
        paddr = { 3'b0, vaddr[28:0] };
    end else begin // kuseg, kseg2 & kseg3
        paddr = vaddr;
    end
end

endmodule
