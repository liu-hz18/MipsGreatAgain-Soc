`include "defines.svh"

// 处理和分发各阶段的stall请求和flush请求
module stall_ctrl (
    input rst,
    input bit_t if_stall_req,
    input bit_t id_stall_req,
    input bit_t ex_stall_req,
    input bit_t mem_stall_req,
    input bit_t wb_stall_req,
    input exceptControl_t except_req,

    output stall_t stall,
    output bit_t flush
);

always_comb begin: stall_control
    flush = except_req.flush;

    stall = 6'b000000;
    if (wb_stall_req) begin
        stall = 6'b111111;
    end else if (mem_stall_req) begin
        stall = 6'b111110;
    end else if (ex_stall_req) begin
        stall = 6'b111100;
    end else if (id_stall_req) begin
        stall = 6'b111000;
    end else if (if_stall_req) begin
        stall = 6'b110000;
    end
end

endmodule
