`include "defines.svh"

// TLB module
// 4KB page, so VPO == PPO == 12bit, and VPN = 20bit, PPN = 20bit
// classic TLBs usually have 16~64 entries, which need to perform comparation on each entry.
// in our implementation, TLB have 16 entries.
// our TLB use double memory, every TLB entry have 2 PPNs.
// input: (vpn2, asid) in entryhi, (pagemask, G) in cp0 pagemask.
// output: (ppn, V, D, C) in entrylo0, (ppn, V, D, C) in entrylo1

module tlb (
    input clk, rst,
    
    input logic[7:0] asid,
    input word_t inst_vaddr,
    input word_t data_vaddr,
    output tlbResult_t inst_tlb_result,
    output tlbResult_t data_tlb_result,

    // tlbp
    input word_t  tlbp_entry_hi, // ex stage
    output word_t tlbp_index, // ex stage
    // tlbr, tlbwi, tlbwr
    input tlbIndex_t ex_tlbrw_index, // ex stage
    input tlbIndex_t mem_tlbrw_index, // mem stage
    input bit_t      mem_tlbrw_we, // mem stage
    input tlbEntry_t mem_tlbrw_wdata, // mem stage
    output tlbEntry_t ex_tlbrw_rdata // ex stage
);

tlbEntry_t [`TLB_ENTRIES_NUM-1:0] entries;
always_comb begin
    if (mem_tlbrw_we && ex_tlbrw_index == mem_tlbrw_index) begin
        ex_tlbrw_rdata = mem_tlbrw_wdata;
    end else begin
        ex_tlbrw_rdata = entries[ex_tlbrw_index];
    end
end

// tlb write port (WB stage)
genvar i;
generate
    for (i = 0; i < `TLB_ENTRIES_NUM; ++i) begin: gen_write_tlb
        always_ff @(posedge clk) begin
            if (rst) begin
                entries[i] <= '0;
            end else if (mem_tlbrw_we && i == mem_tlbrw_index) begin
                entries[i] <= mem_tlbrw_wdata;
            end
        end
    end
endgenerate

tlb_lookup inst_lookup(
    .entries,
    .vaddr(inst_vaddr),
    .asid,
    .result(inst_tlb_result)
);

tlb_lookup data_lookup(
    .entries,
    .vaddr(data_vaddr),
    .asid,
    .result(data_tlb_result)
);

tlbResult_t tlbp_tlb_result;
tlb_lookup tlbp_lookup(
    .entries,
    .vaddr(tlbp_entry_hi),
    .asid(tlbp_entry_hi[7:0]),
    .result(tlbp_tlb_result)
);

assign tlbp_index = {
    tlbp_tlb_result.miss,
    {(32 - `TLB_ENTRIES_NUM_LOG2 - 1){1'b0}},
    tlbp_tlb_result.which
};

endmodule
