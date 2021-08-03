`include "defines.svh"
// in mem stage
module except (
    input rst,

    input word_t pc,
    input bit_t valid,
    input memControl_t memory_req,
    input bit_t in_delayslot,
    input exceptType_t except_types,
    // input cp0WriteControl_t wb_cp0_wp, // for data bypass
    input CP0Regs_t cp0_regs,
    input wire[7:0] interrupt_flag, // [7:2] is hardware interrupt, [1:0] is software interrupt.
    `ifdef ENABLE_FPU
    // FPU excepts
    input fpuExcept_t fpu_except, // from mem stage (ex/mem output)
    `endif
    output exceptControl_t except_req
);

CP0Regs_t cp0_regs_safe;
// no need for data bypass.
// RAW conflict has been solved in `cp0_regs` module.
assign cp0_regs_safe = cp0_regs; 

exceptControl_t except_req_inner;
assign except_req = valid ? except_req_inner : '0;

bit_t interrupt_occur;
assign interrupt_occur = (
	cp0_regs_safe.status.ie &&
	(~cp0_regs_safe.status.exl) && (~cp0_regs_safe.status.erl) &&
	(|interrupt_flag)
);

bit_t fpu_except_occur;
`ifdef ENABLE_FPU
assign fpu_except_occur = (|fpu_except);
`else
assign fpu_except_occur = 1'b0;
`endif

logic[4:0] except_code;
bit_t except_interrupt_exist;
assign except_interrupt_exist = interrupt_occur | (|except_types) | fpu_except_occur;
logic tlb_refill;

// 异常控制信号分发
always_comb begin: except_control
    except_req_inner.extra = `ZERO_WORD;
    except_code = 5'b0;

    tlb_refill = 1'b0;
    except_req_inner.delayslot = in_delayslot;    

    if (interrupt_occur) begin
        except_code = `EXCCODE_INT;
        except_req_inner.extra = interrupt_flag;
    // except in if stage.
    end else if (except_types.iaddr_illegal) begin
        except_code = `EXCCODE_ADEL; // Address error exception(fetch)
        except_req_inner.extra = pc;
    end else if (except_types.iaddr_miss) begin
        except_code = `EXCCODE_TLBL;
        except_req_inner.extra = pc;
        tlb_refill = 1'b1;
    end else if (except_types.iaddr_invalid) begin
        except_code = `EXCCODE_TLBL;
        except_req_inner.extra = pc;
    // except in ex stage
    end else if (except_types.syscall) begin
        except_code = `EXCCODE_SYS;
    end else if (except_types.break_) begin
        except_code = `EXCCODE_BP;
    end else if (except_types.overflow) begin
        except_code = `EXCCODE_OV;
    end else if (except_types.trap) begin
        except_code = `EXCCODE_TR;
    end else if (fpu_except_occur) begin
        except_code = `EXCCODE_FPE;
        `ifdef ENABLE_FPU
        except_req_inner.extra = fpu_except;
        `else
        except_req_inner.extra = '0;
        `endif
    // except in decode stage
    end else if (except_types.eret) begin
        except_code = 5'b0; // not a exception actually.
    end else if (except_types.priv_inst) begin
        except_code = `EXCCODE_CpU;
        except_req_inner.extra = 32'd1;
    end else if (except_types.invalid_inst) begin
        except_code = `EXCCODE_RI;
    // except in mem stage
    end else if (except_types.daddr_unaligned || except_types.daddr_illegal) begin
        except_code = memory_req.we ? `EXCCODE_ADES : `EXCCODE_ADEL; // Address error exception(load/save)
        except_req_inner.extra = memory_req.addr;
    end else if (except_types.daddr_miss) begin
        except_code = memory_req.we ? `EXCCODE_TLBS : `EXCCODE_TLBL;
        except_req_inner.extra = memory_req.addr;
        tlb_refill = 1'b1;
    end else if (except_types.daddr_invalid) begin
        except_code = memory_req.we ? `EXCCODE_TLBS : `EXCCODE_TLBL;
        except_req_inner.extra = memory_req.addr;
    end else if (except_types.daddr_readonly) begin
        except_code = `EXCCODE_MOD;
        except_req_inner.extra = memory_req.addr;
    end
end


always_comb begin: assign_except_ctrl
    if (rst || ~except_interrupt_exist) begin
        except_req_inner.flush = 1'b0;
        except_req_inner.code = 5'b0;
        except_req_inner.eret = 1'b0;
        except_req_inner.cur_pc = `ZERO_WORD;
        except_req_inner.jump_pc = `ZERO_WORD;
    end else begin
        except_req_inner.flush = 1'b1;
        except_req_inner.code = except_code;
        except_req_inner.eret = except_types.eret;
        

        if ((except_types.iaddr_miss | except_types.iaddr_invalid) & in_delayslot) begin
            except_req_inner.cur_pc = pc + 4;
        end else begin
            except_req_inner.cur_pc = pc;
        end

        if (except_types.eret) begin // 从异常返回正常指令区
            if (cp0_regs_safe.status.erl) begin // ERL表示处于错误级
                // 特殊的异常处理阶段，其实暂时可以不考虑
                except_req_inner.jump_pc = cp0_regs_safe.error_epc; // 上一次系统错误时的程序计数器
            end else begin
                except_req_inner.jump_pc = cp0_regs_safe.epc; // 上一次异常发生时的程序计数器
            end
        end else begin // 发生中断或异常
            logic[11:0] offset;
            if (cp0_regs_safe.status.exl == 1'b0) begin
                if (tlb_refill && (except_code == `EXCCODE_TLBL || except_code == `EXCCODE_TLBS)) begin
                    offset = 12'h000;
                end else if (except_code == `EXCCODE_INT && cp0_regs_safe.cause.iv) begin
                    offset = 12'h200;
                end else begin
                    offset = 12'h180;
                end
            end else begin
                offset = 12'h180;
            end
            if (cp0_regs_safe.status.bev) begin
                except_req_inner.jump_pc = 32'hbfc00200 + offset; // 0xBFC0_0380 in kseg1
            end else begin
                except_req_inner.jump_pc = { cp0_regs_safe.ebase[31:12], offset };
            end
        end

    end
end

endmodule
