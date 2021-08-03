`include "defines.svh"

module tlb_lookup (
    input tlbEntry_t [`TLB_ENTRIES_NUM-1:0] entries,
    input word_t vaddr,
    input logic [7:0] asid,
    output tlbResult_t result
);

logic [`TLB_ENTRIES_NUM_LOG2-1:0] which_matched;
logic [`TLB_ENTRIES_NUM-1:0] matched;
tlbEntry_t matched_entry;
assign matched_entry = entries[which_matched];

assign result.miss = (matched == {`TLB_ENTRIES_NUM{1'b0}});
assign result.which = which_matched;
assign result.phy_addr[11:0] = vaddr[11:0];

always_comb begin
    if (vaddr[12]) begin
        result.dirty = matched_entry.d1;
        result.valid = matched_entry.v1;
        result.cache_flag = matched_entry.c1;
        result.phy_addr[31:12] = matched_entry.pfn1[19:0];
    end else begin
        result.dirty = matched_entry.d0;
        result.valid = matched_entry.v0;
        result.cache_flag = matched_entry.c0;
        result.phy_addr[31:12] = matched_entry.pfn0[19:0];
    end
end

// all 4KB pages, so pagemask must be all zero, so we do not use pagemask in matching for simplification.
for(genvar i = 0; i < `TLB_ENTRIES_NUM; ++i) begin
    assign matched[i] = (
        entries[i].vpn2 == vaddr[31:13] &&
        (entries[i].asid == asid || entries[i].G)
    );
end

always_comb begin
    which_matched = '0;
    for(int i = 0; i < `TLB_ENTRIES_NUM; ++i)
        if(matched[i]) which_matched = i;
end

endmodule
