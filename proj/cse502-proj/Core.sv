`include "global.svh"
`include "gpr.svh"
`include "inst.svh"

module Core (
	input[63:0] entry
,	/* verilator lint_off UNDRIVEN */ /* verilator lint_off UNUSED */ Sysbus bus /* verilator lint_on UNUSED */ /* verilator lint_on UNDRIVEN */
);
	import "DPI-C" function int
	syscall_cse502(input int g1, input int o0, input int o1, input int o2, input int o3, input int o4, input int o5);

	logic clk;
	assign clk = bus.clk;


	logic[31:0] reg_occupies;
	logic[31:0] rflags;
	logic[31:0] regs[`GLB_REG_NUM-1:0];
	

	/* Data initialization */
	always_ff @ (posedge bus.clk) begin
		if (bus.reset) begin
			for (int i = 0; i < `GLB_REG_NUM; i += 1)
				regs[i] <= 0;

			reg_occupies <= 0;
			regs[`GPR_RSP] <= 32'h0;
		end
	end

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

	/* verilator lint_off UNDRIVEN */ /* verilator lint_off UNUSED */ 
	logic dcache_done;
	logic[63:0] dcache_rdata;
	logic[63:0] dcache_wdata;
  	/* verilator lint_on UNUSED */ /* verilator lint_on UNDRIVEN */

	assign dcache_enable = 0;
	assign dcache_wenable = 0;
	assign dcache_addr = 0;
	assign dcache_wdata = 0;
	assign dclflush = 0;

	DCache dcache(clk,
		dcache_enable, dcache_wenable, dclflush, dcache_addr, dcache_rdata, dcache_wdata, dcache_done,
		drequest, dreqack, dwrenable, daddr, drdata, dwdata, ddone);

	/* --------------------------------------------------------- */
	/* Instruction-Fetch stage */
	/* verilator lint_off UNDRIVEN */ /* verilator lint_off UNUSED */ 
	logic if_dc;
	//logic dc_if;
	logic[0:15*8-1] decode_bytes;
	logic[63:0] decode_rip;
	/* verilator lint_off UNDRIVEN */ /* verilator lint_off UNUSED */ 

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
		/*
		if (wb_branch) begin
			dc_resume <= 1;
		end else if (exe_branch) begin
			dc_resume <= 1;
		end else 
		*/
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

	always_comb begin
		df_taken = 0;
		if (dc_df == 1 && !df_reg_conflict(dc_uop) && !mem_blocked) begin
			df_taken = 1;
			df_uop_tmp = dc_uop;

			/* Retrieve register values
			* TODO: might need special treatment for special registers */
			if (df_uop_tmp.oprd1.t == `OPRD_T_RD) begin
				df_uop_tmp.oprd1.value = regs[df_uop_tmp.oprd1.r];
			end

			if (df_uop_tmp.oprd2.t == `OPRD_T_RS) begin
				df_uop_tmp.oprd1.value = regs[df_uop_tmp.oprd2.r];
			end

			if (df_uop_tmp.oprd2.t == `OPRD_T_RS) begin
				df_uop_tmp.oprd1.value = regs[df_uop_tmp.oprd3.r];
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
		df_uop.next_rip, exe_result, exe_rflags, exe_mem, mem_blocked, exe_branch, exe_rip);

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
	logic[63:0] mem_result;
	logic[31:0] mem_rflags;
	micro_op_t mem_uop;

	Mem mem(clk, exe_mem, mem_blocked, mem_wb,
		exe_uop, exe_result, mem_result,
		dcache_enable, dcache_wenable, dclflush, dcache_addr, dcache_rdata[31:0], dcache_wdata[31:0], dcache_done);

	always_ff @ (posedge bus.clk) begin
		if (exe_mem && !mem_blocked) begin
			mem_uop <= exe_uop;
			mem_rflags <= exe_rflags;
		end else if (mem_blocked) begin
			/* Keep the previous value */
		end else begin
			mem_uop <= 0;
			mem_rflags <= 0;
		end
	end

	/* --------------------------------------------------------- */
	/* WB stage */
	//logic[63:0] wb_result;
	//logic[63:0] wb_rflags;
	//logic[4:0] reg_num;
	logic wb_branch;
	logic[63:0] wb_rip;

	always_ff @ (posedge bus.clk) begin
		if (mem_wb == 1) begin
			/* Special operations */
			if (mem_uop.op == 2'b01) begin
				/*  syscall */
				rflags <= mem_rflags;
			end

			/* Deal with call/ret */
			if (mem_uop.op== 2'b11) begin
				/* Call %reg */
				wb_branch <= 1;
				wb_rip <= {32'b0, mem_uop.oprd2.value};
			end
		end else begin
			wb_branch <= 0;
			wb_rip <= 0;
		end
	end


	// cse502 : Use the following as a guide to print the Register File contents.
	final begin
		$display("RFLAGS = %x", rflags);
		$display("g00  = %x", 0);
		$display("g01  = %x", 0);
		$display("g02  = %x", 0);
		$display("g03  = %x", 0);
		$display("g04  = %x", 0);
		$display("g05  = %x", 0);
		$display("g06  = %x", 0);
		$display("g07  = %x", 0);
		$display("w00  = %x", 0);
		$display("w01  = %x", 0);
		$display("w02  = %x", 0);
		$display("w03  = %x", 0);
		$display("w04  = %x", 0);
		$display("w05  = %x", 0);
		$display("w06  = %x", 0);
		$display("w07  = %x", 0);
		$display("w08  = %x", 0);
		$display("w09  = %x", 0);
		$display("w10  = %x", 0);
		$display("w11  = %x", 0);
		$display("w12  = %x", 0);
		$display("w13  = %x", 0);
		$display("w14  = %x", 0);
		$display("w15  = %x", 0);
		$display("w16  = %x", 0);
		$display("w17  = %x", 0);
		$display("w18  = %x", 0);
		$display("w19  = %x", 0);
		$display("w20  = %x", 0);
		$display("w21  = %x", 0);
		$display("w22  = %x", 0);
		$display("w23  = %x", 0);
	end
endmodule
