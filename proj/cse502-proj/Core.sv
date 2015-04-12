`include "global.svh"
`include "gpr.svh"
`include "inst.svh"

module Core (
	input[63:0] entry,	
	/* verilator lint_off UNDRIVEN */ /* verilator lint_off UNUSED */ 
	Sysbus bus 
	/* verilator lint_on UNUSED */ /* verilator lint_on UNDRIVEN */
);
	import "DPI-C" function int
	syscall_cse502(input int g1, input int o0, input int o1, input int o2, input int o3, input int o4, input int o5);

	logic clk;
	assign clk = bus.clk;

	logic[31:0] reg_occupies;
	logic[31:0] psr;

	/* verilator lint_off UNDRIVEN */ /* verilator lint_off UNUSED */ 
	logic[31:0] wim;
	/* verilator lint_off UNDRIVEN */ /* verilator lint_off UNUSED */ 

	logic[31:0] regs[`REG_WIN_NUM-1:0];

	/* ++++++++++++++++ Data initialization ++++++++++++++++++++ */
	always_ff @ (posedge bus.clk) begin
		if (bus.reset) begin
			/* work around a bug */
			for (int j=0; j<`REG_WIN_NUM; j += 12)
				for (int i = j; i<j+12; i += 1)
					regs[i] <= 32'h0;

			reg_occupies <= 0;
			psr <= 32'h7;
			wim <= 32'h0;
			/* stack pointer */
			regs[reg_index(14)] <= 32'h40000000 - 32'h400000;
		end
	end


	/* ++++++++++++++ For register Window +++++++++++++++++++++ */
	logic[31:0] cwp;
	logic[31:0] out_reg_start;
	assign cwp = {27'b0, psr[4:0]};
	assign out_reg_start = cwp*16+8;


	/* +++++++++++++++++++++++++++++++++++++++++++++++++++++++++ */
	/* Memory arbiter and cache */
	logic irequest;
	logic ireqack;
	logic[63:0] iaddr;
	logic[64*8-1:0] idata;
	logic idone;
	logic drequest;
	logic dreqack;
	logic dclflush;
	logic dwrenable;
	logic[63:0] daddr;
	logic[64*8-1:0] drdata;
	logic[64*8-1:0] dwdata;
	logic ddone;

	Arbiter arbiter(bus,
		irequest, ireqack, iaddr, idata, idone,
		drequest, dreqack, dwrenable, daddr, drdata, dwdata, ddone);

	logic icache_enable;
	logic[63:0] icache_addr;
	logic[511:0] icache_rdata;
	logic icache_done;
	ICache icache(clk, icache_enable, icache_addr, icache_rdata, icache_done,
		irequest, ireqack, iaddr, idata, idone);

	logic dcache_enable;
	logic dcache_wenable;
	logic[63:0] dcache_addr;

	logic dcache_done;
	logic[31:0] dcache_rdata;
	logic[31:0] dcache_wdata;


	DCache dcache(clk,
		dcache_enable, dcache_wenable, dclflush, dcache_addr, dcache_rdata, dcache_wdata, dcache_done,
		drequest, dreqack, dwrenable, daddr, drdata, dwdata, ddone);

	/* --------------------------------------------------------- */
	/* Instruction-Fetch stage */
	logic if_dc;
	logic[0:15*8-1] decode_bytes;
	logic[63:0] decode_rip;

	logic[7:0] bytes_decoded;
	logic if_set_rip;
	logic[63:0] if_new_rip;

	Ifetch inf(clk, if_set_rip, if_new_rip, icache_enable, icache_addr, icache_rdata, icache_done,
		decode_bytes, decode_rip, bytes_decoded, if_dc);

	/* --------------------------------------------------------- */
	/* Decode stage */
	logic dc_taken = 0;
	logic dc_df = 0;
	logic dc_resume = 0;
	micro_op_t dc_uop;
	Decoder decoder(clk, if_dc, dc_resume, decode_rip, decode_bytes, dc_taken,
		bytes_decoded, dc_uop, dc_df);

	always_comb begin
		if (bus.reset) begin
			if_set_rip = 1;
			if_new_rip = entry;
		end else begin
			if_set_rip = 0;
			if_new_rip = 0;
		end
	end

	always_ff @ (posedge bus.clk) begin
		if (wb_branch) begin
			dc_resume <= 1;
		end else if (exe_branch) begin
			dc_resume <= 1;
		end else 
			dc_resume <= 0;
	end

	/* --------------------------------------------------------- */
	/* Data Fetch & Schedule stage */
	logic df_taken;
	assign dc_taken = df_taken;
	micro_op_t df_uop;
	micro_op_t df_uop_tmp;
	logic df_exe;
	logic mem_blocked;

	/* check register conflict */
	function logic df_reg_conflict(/* verilator lint_off UNUSED */ micro_op_t uop /* verilator lint_off UNUSED */);
		if (uop.oprd1.t == `OPRD_T_RD || uop.oprd1.t == `OPRD_T_RS)
			if (reg_occupies[uop.oprd1.r] != 0)
				return 1;

		if (uop.oprd2.t == `OPRD_T_RD || uop.oprd2.t == `OPRD_T_RS)
			if (reg_occupies[uop.oprd2.r] != 0)
				return 1;

		if (uop.oprd3.t == `OPRD_T_RD || uop.oprd3.t == `OPRD_T_RS)
			if (reg_occupies[uop.oprd3.r] != 0)
				return 1;
		return 0;
	endfunction

	/* This can only be called from alwasy_ff */
	function logic df_set_reg_conflict(oprd_t oprd);
		/* FIXME: here we assume oprd1 is the target, need to handle multi-target condition */
		if (oprd.t == `OPRD_T_RD || oprd.t == `OPRD_T_RS) begin
			reg_occupies[oprd.r] <= 1;
		end

		return 0;
	endfunction



	function logic [31:0] reg_index(logic[4:0] index);
		if (index < 8)
			return {27'b0 , index};
		else
			return out_reg_start + {27'b0, index} - 8;	
	endfunction


	always_comb begin
		df_taken = 0;
		if (dc_df == 1 && !df_reg_conflict(dc_uop) && !mem_blocked) begin
			df_taken = 1;
			df_uop_tmp = dc_uop;

			$display("[pre_ALU] I am assigning values");


			/* Retrieve register values
			/* TODO: might need special treatment for special registers */
			if (df_uop_tmp.oprd1.t == `OPRD_T_RS) begin
				df_uop_tmp.oprd1.value = regs[reg_index(df_uop_tmp.oprd1.r)];
				$display("[pre_ALU] oprd1-value: %x", df_uop_tmp.oprd1.value);
				$display("[pre_ALU] oprd1-source: %x", regs[reg_index(df_uop_tmp.oprd1.r)]);
				$display("[pre_ALU] oprd1-index: %x", df_uop_tmp.oprd1.r);
			end

			if (df_uop_tmp.oprd2.t == `OPRD_T_RS) begin
				df_uop_tmp.oprd2.value = regs[reg_index(df_uop_tmp.oprd2.r)];
				$display("[pre_ALU] oprd2-value: %x", df_uop_tmp.oprd2.value);
				$display("[pre_ALU] oprd2-source: %x", regs[reg_index(df_uop_tmp.oprd2.r)]);
				$display("[pre_ALU] oprd2-index: %x", df_uop_tmp.oprd2.r);
			end

			if (df_uop_tmp.oprd3.t == `OPRD_T_RS) begin
				df_uop_tmp.oprd3.value = regs[reg_index(df_uop_tmp.oprd3.r)];
				$display("[pre_ALU] oprd3-value: %x", df_uop_tmp.oprd3.value);
				$display("[pre_ALU] oprd3-source: %x", regs[reg_index(df_uop_tmp.oprd3.r)]);
				$display("[pre_ALU] oprd3-index: %x", df_uop_tmp.oprd3.r);
			end


			if (1) begin
			$display("PSR = %x", psr);
			$display("reg_occupies = %x", reg_occupies);
			$display("g00 = %x", regs[reg_index(0)]);
			$display("g01 = %x", regs[reg_index(1)]);
			$display("g02 = %x", regs[reg_index(2)]);
			$display("g03 = %x", regs[reg_index(3)]);
			$display("g04 = %x", regs[reg_index(4)]);
			$display("g05 = %x", regs[reg_index(5)]);
			$display("g06 = %x", regs[reg_index(6)]);
			$display("g07 = %x", regs[reg_index(7)]);

			$display("out0 = %x", regs[reg_index(8)]);
			$display("out1 = %x", regs[reg_index(9)]);
			$display("out2 = %x", regs[reg_index(10)]);
			$display("out3 = %x", regs[reg_index(11)]);
			$display("out4 = %x", regs[reg_index(12)]);
			$display("out5 = %x", regs[reg_index(13)]);
			$display("out6 = %x", regs[reg_index(14)]);
			$display("out7 = %x", regs[reg_index(15)]);

			$display("loc0 = %x", regs[reg_index(16)]);
			$display("loc1 = %x", regs[reg_index(17)]);
			$display("loc2 = %x", regs[reg_index(18)]);
			$display("loc3 = %x", regs[reg_index(19)]);
			$display("loc4 = %x", regs[reg_index(20)]);
			$display("loc5 = %x", regs[reg_index(21)]);
			$display("loc6 = %x", regs[reg_index(22)]);
			$display("loc7 = %x", regs[reg_index(23)]);

			$display("in0 = %x", regs[reg_index(24)]);
			$display("in1 = %x", regs[reg_index(25)]);
			$display("in2 = %x", regs[reg_index(26)]);
			$display("in3 = %x", regs[reg_index(27)]);
			$display("in4 = %x", regs[reg_index(28)]);
			$display("in5 = %x", regs[reg_index(29)]);
			$display("in6 = %x", regs[reg_index(30)]);
			$display("in7 = %x", regs[reg_index(31)]);
			end

		end

	end

	always_ff @ (posedge bus.clk) begin
		if (dc_df == 1 && df_taken == 1 && !mem_blocked) begin
			/* we need to set occupation table in always_ff */
			df_set_reg_conflict(df_uop_tmp.oprd1);

			df_uop <= df_uop_tmp;
			df_exe <= 1;


		end else if (mem_blocked) begin
			/* Keep the previous value */
		end else begin
			df_uop <= 0;
			df_exe <= 0;
		end
	end


	/* --------------------------------------------------------- */
	/* EXE stage */
	logic exe_mem;
	logic[63:0] exe_result;
	logic[31:0] exe_rflags;
	micro_op_t exe_uop;

	logic exe_branch;
	logic[63:0] exe_rip;

	ALU alu(clk, df_exe,
		df_uop.op, df_uop.op2, df_uop.op3, df_uop.oprd1.value, df_uop.oprd2.value, df_uop.oprd3.value, 
		df_uop.cond, df_uop.next_rip, exe_result, exe_rflags, exe_mem, mem_blocked, exe_branch, exe_rip);

	always_ff @ (posedge bus.clk) begin
		if (df_exe && !mem_blocked) begin
			exe_uop <= df_uop;
		end else if (mem_blocked) begin
			/* Keep the previous value */
		end else begin
			exe_uop <= 0;
		end
	end

	/* --------------------------------------------------------- */
	/* MEM stage */
	logic mem_wb;
	logic[31:0] mem_result;
	logic[31:0] mem_rflags;
	micro_op_t mem_uop;

	Mem mem(clk, exe_mem, mem_blocked, mem_wb,
		exe_uop, exe_result, mem_result,
		dcache_enable, dcache_wenable, dclflush, dcache_addr, dcache_rdata, dcache_wdata, dcache_done);

	always_ff @ (posedge bus.clk) begin
		if (exe_mem && !mem_blocked) begin
			mem_uop <= exe_uop;
			mem_rflags <= exe_rflags;
			$display("[post-MEM] exe_rflags: %x", exe_rflags);
			$display("[post-MEM] exe_uop: %x", exe_uop);
		end else if (mem_blocked) begin
			/* Keep the previous value */
		end else begin
			mem_uop <= 0;
			mem_rflags <= 0;
		end
	end

	/* --------------------------------------------------------- */
	/* WB stage */
	logic wb_branch;
	logic[63:0] wb_rip;

	always_ff @ (posedge bus.clk) begin
		if (mem_wb == 1) begin
			$display("[WB] mem_uop.op: %x", mem_uop.op);

			if (mem_uop.op == 2'b00) begin
				psr <= mem_rflags;
				if (mem_uop.op2 == 4) begin
					regs[reg_index(mem_uop.oprd1.r)] <= mem_result[31:0];
					reg_occupies[mem_uop.oprd1.r] <= 0;
				end
			end else if (mem_uop.op == 2'b01) begin
				psr <= mem_rflags;
				wb_branch <= 1;
				wb_rip <= {32'b0, mem_uop.oprd1.value} + mem_uop.next_rip - 4;
				regs[reg_index(15)] <= mem_uop.next_rip[31:0] - 4;
				$display("[WB] next_rip: %x", mem_uop.next_rip[31:0]);
			end else if (mem_uop.op == 2'b10) begin
				$display("[WB] mem_uop.op.oprd1.r: %x", mem_uop.oprd1.r);
				$display("[WB] mem_uop.op.oprd1.t: %x", mem_uop.oprd1.t);
				$display("[WB] mem_result: %x", mem_result[31:0]);
				$display("[WB] mem_rflags: %x", mem_rflags);
				regs[reg_index(mem_uop.oprd1.r)] <= mem_result[31:0];
				reg_occupies[mem_uop.oprd1.r] <= 0;
				psr <= mem_rflags;
			end else begin
				regs[reg_index(mem_uop.oprd1.r)] <= mem_result[31:0];
				reg_occupies[mem_uop.oprd1.r] <= 0;
				psr <= mem_rflags;
			end

		end else begin
			wb_branch <= 0;
			wb_rip <= 0;
		end
	end


	final begin
		$display("Bye!");
	end
endmodule



/* vim: set ts=4 sw=0 tw=0 noet : */
