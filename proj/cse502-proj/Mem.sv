`include "inst.svh"

//`define MEM_DEBUG 1

module Mem (input clk,
	input enable,
	output mem_blocked,
	output mem_wb,
 /* verilator lint_off UNUSED */
	input micro_op_t uop,
 /* verilator lint_on UNUSED */
	input[63:0] alu_result,

	output[63:0] mem_result,

	output dcache_en,
	output dcache_wren,
	output dcache_flush,
	output[63:0] dcache_addr,
	input[31:0] dcache_rdata,
	output[31:0] dcache_wdata,
	input dcache_done
);

	enum { op_none, op_read, op_write, op_flush } mem_op;
	enum { mem_idle, mem_waiting, mem_active } mem_state;

	//logic[63:0] rip;
	//assign rip = uop.next_rip;

	logic[63:0] tmp_mem_result;

	logic[63:0] addr = 0;
	logic[31:0] value = 0;

	always_ff @ (posedge clk) begin
		if (dcache_en)
			dcache_en <= 0;
		if (dcache_wren)
			dcache_wren <= 0;
		if (dcache_flush)
			dcache_flush <= 0;
		if (mem_state == mem_idle) begin
			if (enable) begin
				if (mem_op == op_read) begin
`ifdef MEM_DEBUG
					$display("[MEM] reading from %x", addr);
`endif
					mem_state <= mem_waiting;
					dcache_en <= 1;
					dcache_wren <= 0;
					dcache_addr <= addr;
					mem_wb <= 0;
				end else if (mem_op == op_write) begin
`ifdef MEM_DEBUG
					$display("[MEM] writing %x into %x", value, addr);
`endif
					mem_state <= mem_waiting;
					dcache_en <= 1;
					dcache_wren <= 1;
					dcache_addr <= addr;
					dcache_wdata <= value;
					mem_wb <= 0;
				end else if (mem_op == op_flush) begin
`ifdef MEM_DEBUG
					$display("[MEM] flushing %x", addr);
`endif
					mem_state <= mem_waiting;
					dcache_en <= 1;
					dcache_flush <= 1;
					dcache_addr <= addr;
					mem_wb <= 0;
				end else begin
					/* No need to do memory ops */
					mem_result <= tmp_mem_result;
					mem_wb <= 1;
				end
			end else begin	/* !enable */
					mem_wb <= 0;
			end
		end else begin	/* !idle */
			if (dcache_done) begin
				dcache_en <= 0;
				dcache_wren <= 0;
				mem_state <= mem_idle;
				mem_result[31:0] <= dcache_rdata;
`ifdef MEM_DEBUG
				$display("[MEM] reading value %x", dcache_rdata);
`endif
				mem_wb <= 1;
			end else begin
				mem_wb <= 0;
			end
		end
	end

	always_comb begin
		mem_op = op_none;
		if (enable && mem_state == mem_idle) begin
			if (uop.op == 2'h11) begin
				/* LEA */
				tmp_mem_result[31:0] = uop.oprd2.value;
				mem_op = op_none;
				mem_blocked = 0;
			end else begin
				/* No mem operation, unblock previous stages */
				tmp_mem_result = alu_result;
				mem_op = op_none;
				mem_blocked = 0;
			end
		end else if (mem_state == mem_waiting && dcache_done) begin
			mem_blocked = 0;
		end
	end

endmodule

