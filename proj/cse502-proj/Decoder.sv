`include "inst.svh"

//`define DECODER_OUTPUT 1
`define DECODER_DEBUG 0
`define DC_BUF_SZ	16
`define DC_MAX_INSTR	4	// maximum number of instructions per cycle

module Decoder (
	input clk,
	input can_decode,
	input dc_resume,
	input[63:0] rip,
	input[0:15*8-1] decode_bytes,
	input taken,	// If pipeline has taken the sent instruction
	output[7:0] bytes_decoded,
	output micro_op_t out_dc_instr,
	output dc_df
);

	/* verilator lint_off WIDTH */
	enum { dc_norm, dc_stall } dc_state;

	initial begin
		dc_state = dc_norm;
	end

	logic[1:0] op;
	logic[2:0] op2;
	logic[5:0] op3;
	logic[8:0] opf;
	logic[3:0] cond;

	logic annul_flag;
	logic i_flag;
	
	oprd_t dc_oprd[3];

	enum { ec_none, ec_invalid_op, ec_rex } error_code;

	micro_op_t decoded_uops[3];
	logic[7:0] num_decoded_uops;

	/* Begin DC output buffer */
	micro_op_t dc_buf[`DC_BUF_SZ];
	logic[7:0] dc_buf_head;
	logic[7:0] dc_buf_tail;

	initial begin
		dc_buf_head = 0;
		dc_buf_tail = 0;
	end

	function logic dc_buf_full();
		logic[7:0] space;
		if (dc_buf_head >= dc_buf_tail)
			space = `DC_BUF_SZ - (dc_buf_head - dc_buf_tail) - 1;
		else
			space = (dc_buf_tail - dc_buf_head) - 1;

		if (space >= `DC_MAX_INSTR)
			dc_buf_full = 0;
		else
			dc_buf_full = 1;
	endfunction

	/* if one instruction has been taken, we need to move tail ahead in advance here */
	function logic dc_buf_empty(logic plus_one);
		logic[7:0] tmp_tail = (dc_buf_tail + plus_one) % `DC_BUF_SZ;
		dc_buf_empty = (dc_buf_head == tmp_tail) ? 1 : 0;
	endfunction


	/* verilator lint_on UNUSED */
	function logic fill_uop();
		if (can_decode && (bytes_decoded != 0) && (num_decoded_uops == 0)) begin
			decoded_uops[0] = 0;
			decoded_uops[0].op = op;
			decoded_uops[0].op2 = op2;
			decoded_uops[0].op3 = op3;
			decoded_uops[0].opf = opf;
			decoded_uops[0].annul_flag = annul_flag;
			decoded_uops[0].cond = cond;
			decoded_uops[0].oprd1 = dc_oprd[0];
			decoded_uops[0].oprd2 = dc_oprd[1];
			decoded_uops[0].oprd3 = dc_oprd[2];
			decoded_uops[0].next_rip = rip + bytes_decoded;
			num_decoded_uops = 1;
		end

		return 0;
	endfunction

	function logic set_dc_state_on_br();
		if (op == 2'b01) begin
			dc_state <= dc_stall;
		end else if (op == 2'b00) begin	
			casez (op2)
			/* Bicc */
			3'b010: dc_state <= dc_stall;
			/* FBfcc */
			3'b110: dc_state <= dc_stall;
			/* CBccc */
			3'b111: dc_state <= dc_stall;
			default: /* Do nothing */;
			endcase
		end else if (op == 2'b10) begin	
			casez (op3)
			/* JMPL */
			6'h38: dc_state <= dc_stall;
			/* RETT */
			6'h39: dc_state <= dc_stall;
			/* Ticc */
			6'h3a: dc_state <= dc_stall;
			default: /* Do nothing */;
			endcase
		end else begin 

		end

		return 0;
	endfunction

	/* Branch related stuff */
	always_ff @ (posedge clk) begin
		if (dc_resume) begin
			assert(dc_state == dc_stall) else $fatal("[DEC] resume at non-stall state?");
			dc_state <= dc_norm;
		end else begin
			/* Set decoder state for branch */
			if (can_decode) begin
				set_dc_state_on_br();
			end
		end
	end

	always @(posedge clk) begin
		/* Put decoded instruction into buffer */
		if (can_decode && !dc_buf_full() && dc_state == dc_norm) begin
			if (num_decoded_uops >= 1) begin
				dc_buf[dc_buf_head[3:0]] <= decoded_uops[0];
			end
			dc_buf_head <= (dc_buf_head + num_decoded_uops) % `DC_BUF_SZ;
		end

		/* previous uop taken by df stage */
		if (taken) begin
			if (dc_buf_empty(0))
				$write("[DEC] FATAL dc buffer empty (head %d, tail %d)", dc_buf_head, dc_buf_tail);
			dc_buf_tail <= (dc_buf_tail + 1) % `DC_BUF_SZ;
		end

		/* setup new output */
		if (!dc_buf_empty(taken)) begin
			out_dc_instr <= dc_buf[(dc_buf_tail[3:0]+taken)%`DC_BUF_SZ];
			dc_df <= 1;
		end else begin
			dc_df <= 0;
		end
	end

	/* verilator lint_on UNUSED */

	always_comb begin
		logic[31:0] next_inst;
		num_decoded_uops = 0;
		if (can_decode && !dc_buf_full() && dc_state == dc_norm) begin : decoder
			op2 = 3'b000;
			op3 = 6'b000000;
			i_flag = 1'b0;
			annul_flag = 1'b0;
			cond = 4'b0;

			//dc_oprd[0] = 0;
			//dc_oprd[1] = 0;
			//dc_oprd[2] = 0;

			bytes_decoded = 0;
			next_inst = decode_bytes[{3'b000, bytes_decoded} * 32 +: 32];
			error_code = ec_none;

			op = next_inst[31:30];
			$display("[DEC] op %x", op);
			if (op == 2'b00) begin
				op2 = next_inst[24:22];
				/* sethi */
				if (op2 == 3'b100) begin
					dc_oprd[0].t = `OPRD_T_RD;
					dc_oprd[0].r = next_inst[29:25];
					dc_oprd[1].t = `OPRD_T_IMM;
					dc_oprd[1].value = { next_inst[21:0], 10'b0000_0000_00 };
				/* branch */
				end else if (op2 == 3'b010) begin
					annul_flag = next_inst[29];
					cond = next_inst[28:25];
					if (annul_flag == 0) begin
						dc_oprd[0].t = `OPRD_T_DISP;
						dc_oprd[0].value = { {8{next_inst[21]}}, next_inst[21:0], 2'b00 };
					end else begin
						/* XXX: When Annul bit is 1 */
					end
				end else begin

				end
			end else if (op == 2'b01) begin  /* call */
				dc_oprd[0].t = `OPRD_T_DISP;
				dc_oprd[0].value = { next_inst[29:0], 2'b00 };

			end else if (op == 2'b10) begin
				op3 = next_inst[24:19];
				$display("[DEC] op3 %x", op3);

				if (op3 == 6'h34) begin
					opf = next_inst[13:5];
				end else if (op3 == 6'h35) begin
					opf = next_inst[13:5];
				end else if (op3 == 6'h3A) begin

				end else begin
					dc_oprd[0].t = `OPRD_T_RD;
					dc_oprd[0].r = next_inst[29:25];
					dc_oprd[1].t = `OPRD_T_RS;
					dc_oprd[1].r = next_inst[18:14];
					i_flag = next_inst[13];

					if (i_flag) begin
						dc_oprd[2].t = `OPRD_T_IMM;
						dc_oprd[2].value = { {19{next_inst[12]}}, next_inst[12:0] };
					end else begin
						dc_oprd[0].t = `OPRD_T_RD;
						dc_oprd[0].r = next_inst[29:25];
						dc_oprd[1].t = `OPRD_T_RS;
						dc_oprd[1].r = next_inst[18:14];
						dc_oprd[2].t = `OPRD_T_RS;
						dc_oprd[2].r = next_inst[4:0];
					end
				end
				
			end else if (op == 2'b11) begin /* load and store */
				op3 = next_inst[24:19];
				if (op3[3:0] == 4'h0 | op3[3:0] == 4'h1 | op3[3:0] == 4'h2 | op3[3:0] == 4'h3)
					dc_oprd[0].t = `OPRD_T_RS;

				if (op3[3:0] == 4'h4 | op3[3:0] == 4'h5 | op3[3:0] == 4'h6 | op3[3:0] == 4'h7)
					dc_oprd[0].t = `OPRD_T_RD;

				dc_oprd[0].r = next_inst[29:25];
				dc_oprd[1].t = `OPRD_T_RS;
				dc_oprd[1].r = next_inst[18:14];
				i_flag = next_inst[13];

				if (i_flag) begin
					dc_oprd[2].t = `OPRD_T_IMM;
					dc_oprd[2].value = { {19{next_inst[12]}}, next_inst[12:0] };
				end else begin
					dc_oprd[2].t = `OPRD_T_RS;
					dc_oprd[2].r = next_inst[4:0];
				end

			end else begin   
				/* Nothing else */
			end

			if (error_code != ec_none)
				$finish;

			bytes_decoded += 4;
			fill_uop();
`ifdef DECODER_DEBUG
		$display("[DEC] next_inst %x bytes_decoded %x", next_inst, bytes_decoded); 
		$display("[DEC] op %x op2 %x op3 %x", decoded_uops[0].op, decoded_uops[0].op2, decoded_uops[0].op3); 
		$display("[DEC] dc_oprd %x %x %x %x %x %x %x %x %x", dc_oprd[0].t, dc_oprd[0].r, dc_oprd[0].value, dc_oprd[1].t, dc_oprd[1].r, dc_oprd[1].value, dc_oprd[2].t, dc_oprd[2].r, dc_oprd[2].value);
`endif
		end else begin
			bytes_decoded = 0;
		end
	end

endmodule
