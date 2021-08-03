`include "defines.svh"

// 暂时保存取指阶段取得的指令和指令地址，并在下一时钟传递到译码阶段
module if_id (
    input clk, rst,
    input bit_t pc_ce,
    input bit_t branch_flag,
    input stall_t stall,
    input bit_t flush,
    
    input exceptType_t if_except,
    input word_t if_pc,
    input word_t if_inst,
    input bit_t if_valid,
    input bit_t if_branch_predict,
    input logic [1:0] if_branch_predict_state,
    input word_t if_branch_predict_target,

    output word_t id_pc,
    output word_t id_inst,
    output bit_t id_valid,
    output bit_t id_branch_predict,
    output logic [1:0] id_branch_predict_state,
    output word_t id_branch_predict_target,
    output exceptType_t id_except,
    output bit_t in_delayslot_hold
);

bit_t last_stall;
assign in_delayslot_hold = last_stall;

logic if_except_occur;
assign if_except_occur = (|if_except);

always_ff @(posedge clk) begin
    if (rst || flush || ~pc_ce) begin
        id_pc <= `ZERO_WORD;
        id_inst <= `ZERO_WORD;
        id_except <= {$bits(exceptType_t){1'b0}};
        id_valid <= '0;
        id_branch_predict <= '0;
        id_branch_predict_state <= '0;
        id_branch_predict_target <= '0;
    end else if (stall.stall_if && ~stall.stall_id) begin
        // 取指阶段暂停，译码阶段继续的时候，PC不变
        id_pc <= id_pc;
        id_inst <= `ZERO_WORD;
        id_except <= {$bits(exceptType_t){1'b0}};
        id_valid <= '0;
        id_branch_predict <= '0;
        id_branch_predict_state <= '0;
        id_branch_predict_target <= '0;
    end else if (~stall.stall_if) begin
        id_pc <= if_pc;
        id_inst <= if_except_occur ? `ZERO_WORD : if_inst;
        id_except <= if_except;
        id_valid <= if_valid;
        id_branch_predict <= if_branch_predict;
        id_branch_predict_state <= if_branch_predict_state;
        id_branch_predict_target <= if_branch_predict_target;
    end
end

always_ff @(posedge clk) begin
    if (rst) begin
        last_stall <= 1'b0;
    end else begin
        last_stall <= stall.stall_if;
    end
end

endmodule
