`include "defines.svh"

module ex_ext_ins (
    input word_t inst,
    input word_t in1,
    input word_t in2,
    output word_t ext,
    output word_t ins
);

logic [4:0] lsb;
assign lsb = inst[10:6];
logic [4:0] size;
assign size = inst[15:11] - lsb;

always_comb begin: bit_ext
    ext = 32'b0;
    unique case(inst[15:11])
        5'd0: ext = in1[lsb +: 1];
        5'd1: ext = in1[lsb +: 2];
        5'd2: ext = in1[lsb +: 3];
        5'd3: ext = in1[lsb +: 4];
        5'd4: ext = in1[lsb +: 5];
        5'd5: ext = in1[lsb +: 6];
        5'd6: ext = in1[lsb +: 7];
        5'd7: ext = in1[lsb +: 8];
        5'd8: ext = in1[lsb +: 9];
        5'd9: ext = in1[lsb +: 10];
        5'd10: ext = in1[lsb +: 11];
        5'd11: ext = in1[lsb +: 12];
        5'd12: ext = in1[lsb +: 13];
        5'd13: ext = in1[lsb +: 14];
        5'd14: ext = in1[lsb +: 15];
        5'd15: ext = in1[lsb +: 16];
        5'd16: ext = in1[lsb +: 17];
        5'd17: ext = in1[lsb +: 18];
        5'd18: ext = in1[lsb +: 19];
        5'd19: ext = in1[lsb +: 20];
        5'd20: ext = in1[lsb +: 21];
        5'd21: ext = in1[lsb +: 22];
        5'd22: ext = in1[lsb +: 23];
        5'd23: ext = in1[lsb +: 24];
        5'd24: ext = in1[lsb +: 25];
        5'd25: ext = in1[lsb +: 26];
        5'd26: ext = in1[lsb +: 27];
        5'd27: ext = in1[lsb +: 28];
        5'd28: ext = in1[lsb +: 29];
        5'd29: ext = in1[lsb +: 30];
        5'd30: ext = in1[lsb +: 31];
        default: ext = 32'b0;
    endcase
end


always_comb begin: bit_ins
    ins = in2;
    unique case(size)
        5'd0: ins[lsb] = in1[0];
        5'd1: ins[lsb +: 2] = in1[1:0];
        5'd2: ins[lsb +: 3] = in1[2:0];
        5'd3: ins[lsb +: 4] = in1[3:0];
        5'd4: ins[lsb +: 5] = in1[4:0];
        5'd5: ins[lsb +: 6] = in1[5:0];
        5'd6: ins[lsb +: 7] = in1[6:0];
        5'd7: ins[lsb +: 8] = in1[7:0];
        5'd8: ins[lsb +: 9] = in1[8:0];
        5'd9: ins[lsb +: 10] = in1[9:0];
        5'd10: ins[lsb +: 11] = in1[10:0];
        5'd11: ins[lsb +: 12] = in1[11:0];
        5'd12: ins[lsb +: 13] = in1[12:0];
        5'd13: ins[lsb +: 14] = in1[13:0];
        5'd14: ins[lsb +: 15] = in1[14:0];
        5'd15: ins[lsb +: 16] = in1[15:0];
        5'd16: ins[lsb +: 17] = in1[16:0];
        5'd17: ins[lsb +: 18] = in1[17:0];
        5'd18: ins[lsb +: 19] = in1[18:0];
        5'd19: ins[lsb +: 20] = in1[19:0];
        5'd20: ins[lsb +: 21] = in1[20:0];
        5'd21: ins[lsb +: 22] = in1[21:0];
        5'd22: ins[lsb +: 23] = in1[22:0];
        5'd23: ins[lsb +: 24] = in1[23:0];
        5'd24: ins[lsb +: 25] = in1[24:0];
        5'd25: ins[lsb +: 26] = in1[25:0];
        5'd26: ins[lsb +: 27] = in1[26:0];
        5'd27: ins[lsb +: 28] = in1[27:0];
        5'd28: ins[lsb +: 29] = in1[28:0];
        5'd29: ins[lsb +: 30] = in1[29:0];
        5'd30: ins[lsb +: 31] = in1[30:0];
        default: ins = in1;
    endcase
end


endmodule

