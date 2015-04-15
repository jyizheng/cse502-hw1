`include "inst.svh"

`define MEM_DEBUG 1

module Mem (input clk,
	input enable,
	output mem_blocked,
	output mem_wb,
 /* verilator lint_off UNUSED */
	input micro_op_t uop,
 /* verilator lint_on UNUSED */
	input[63:0] alu_result,

	output[31:0] mem_result,

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

	logic[63:0] addr;
	logic[31:0] value;

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
					mem_result <= tmp_mem_result[31:0];
					mem_wb <= 1;
					$display("[MEM] No need to do memory ops");
					$display("[MEM] tmp_mem_result: %x", tmp_mem_result);
				end
			end else begin	/* !enable */
					mem_wb <= 0;
			end
		end else begin	/* !idle */
			if (dcache_done) begin
				dcache_en <= 0;
				dcache_wren <= 0;
				mem_state <= mem_idle;
				mem_result <= dcache_rdata;
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

			$display("[MEM] op %x op2 %x op3 %x", uop.op, uop.op2, uop.op3);
			$display("[MEM]	oprd1.t %x, oprd1.r %x, oprd1.value %x" , uop.oprd1.t, uop.oprd1.r, uop.oprd1.value);
			$display("[MEM]	oprd2.t %x, oprd2.r %x, oprd2.value %x" , uop.oprd2.t, uop.oprd2.r, uop.oprd2.value);
			$display("[MEM]	oprd3.t %x, oprd3.r %x, oprd3.value %x" , uop.oprd3.t, uop.oprd3.r, uop.oprd3.value);
			
			if (uop.op == 2'b11) begin
				if (uop.op3 == 6'h00 | uop.op3 == 6'h09) begin
					mem_blocked = 1;
					mem_op = op_read;
					addr = {32'h0, uop.oprd2.value + uop.oprd3.value}; 
					$display("[MEM] Memory read, addr %x", addr);
				end else if (uop.op3 == 6'h01) begin


				end else if (uop.op3 == 6'h02) begin


				end else if (uop.op3 == 6'h03) begin

				end else if (uop.op3 == 6'h04) begin
					mem_blocked = 1;
					mem_op = op_write;
					addr = {32'h0, uop.oprd2.value + uop.oprd3.value}; 
					value = uop.oprd1.value;
					$display("[MEM] Memory write value: %x", uop.oprd1.value);
					$display("[MEM] Memory write addr: %x", addr);

				end else begin


				end

			end else if (uop.op == 2'b01) begin 
					/* call: no ALU result will be used */
			end else begin
				tmp_mem_result = alu_result;
				mem_op = op_none;
				mem_blocked = 0;
			end


		end else if (mem_state == mem_waiting && dcache_done) begin
			mem_blocked = 0;
			
		end
	end

endmodule

/* vim: set ts=4 sw=0 tw=0 noet : */
