`include "inst.svh"
`include "gpr.svh"

//`define ALU_DEBUG 1

module ALU (
	input clk,
	input enable,
	input[1:0] opcode,
	/* verilator lint_off UNUSED */
	input[2:0] op2,
	/* verilator lint_on UNUSED */
	input[5:0] op3,
	/* verilator lint_off UNUSED */
	input[31:0] oprd1,
	/* verilator lint_on UNUSED */
	input[31:0] oprd2,
	input[31:0] oprd3,

	/* verilator lint_off UNUSED */
	input[3:0] cond_code,
	input annul,
	/* verilator lint_on UNUSED */

	input[63:0] next_rip,
	output[63:0] result,
	output[31:0] rflags,
	output exe_mem,
	input mem_blocked,

	/* For branch */
	output branch,
	output[63:0] branch_rip
);
	logic[63:0] tmp_result;
	logic[31:0] tmp_rflags;
	logic[4:0] tmp_cwp;

	logic delayed_executed;


	initial begin
		rflags = 32'h7;
		$display("[ALU] rflags: %x", rflags);
	end


	/* verilator lint_off WIDTH */

	/* op3[5:4] == 0 */
	function logic[63:0] binary_op();
		casez (op3[3:0])
		4'h0: binary_op = oprd2 + oprd3;
		4'h1: binary_op = oprd2 & oprd3;
		4'h2: binary_op = oprd2 | oprd3;
		4'h3: binary_op = oprd2 ^ oprd3;
		4'h4: binary_op = oprd2 - oprd3;
		4'h5: binary_op = oprd2 & (~oprd3);
		4'h6: binary_op = oprd2 | (~oprd3);
		4'h7: binary_op = oprd2 ^ (~oprd3);
		4'h8: binary_op = oprd2 + oprd3 + rflags[`RF_C]; /* ADDX */
		4'ha: binary_op = oprd2 * oprd3; /* UMUL */
		4'hb: binary_op = oprd2 * oprd3; /* SMUL */
		4'hc: binary_op = oprd2 - oprd3 - rflags[`RF_C]; /* SUBX */
		4'he: binary_op = oprd2 / oprd3; /* UDIV */
		4'hf: binary_op = oprd2 / oprd3; /* SDIV */
		default:
			$display("[ALU] Unsupported OP");
		endcase
	endfunction

	function logic[31:0] binary_op_flag();
		casez (op3[3:0])
		4'h0: binary_op_flag = rflags;
		4'h1: binary_op_flag = rflags;
		4'h2: binary_op_flag = rflags;
		4'h3: binary_op_flag = rflags;
		4'h4: binary_op_flag = rflags;
		4'h5: binary_op_flag = rflags;
		4'h6: binary_op_flag = rflags;
		4'h7: binary_op_flag = rflags;
		4'h8: binary_op_flag = rflags;
		4'ha: binary_op_flag = rflags;
		4'hb: binary_op_flag = rflags;
		4'hc: binary_op_flag = rflags;
		4'he: binary_op_flag = rflags;
		4'hf: binary_op_flag = rflags;
		default:
			$display("[ALU] Unsupported OP");
		endcase
	endfunction


	/* verilator lint_off WIDTH */

	/* op3[5:4] == 1 */
	function logic[63:0] binary_op_cc();
		casez (op3[3:0])
		4'h0: binary_op_cc = oprd2 + oprd3;
		4'h1: binary_op_cc = oprd2 & oprd3;
		4'h2: binary_op_cc = oprd2 | oprd3;
		4'h3: binary_op_cc = oprd2 ^ oprd3;
		4'h4: binary_op_cc = oprd2 - oprd3;
		4'h5: binary_op_cc = oprd2 & (~oprd3);
		4'h6: binary_op_cc = oprd2 | (~oprd3);
		4'h7: binary_op_cc = oprd2 ^ (~oprd3);
		4'h8: binary_op_cc = oprd2 + oprd3 + rflags[`RF_C];
		4'ha: binary_op_cc = oprd2 * oprd3;
		4'hb: binary_op_cc = oprd2 * oprd3;
		4'hc: binary_op_cc = oprd2 - oprd3 - rflags[`RF_C];
		4'he: binary_op_cc = oprd2 / oprd3;
		4'hf: binary_op_cc = oprd2 / oprd3;
		default:
			$display("[ALU] Unsupported OP");
		endcase
	endfunction

	function logic rf_v_flag_add();
		rf_v_flag_add = (oprd1[31] & oprd2[31] & (!tmp_result[31]))
					| ((!oprd1[31]) & (!oprd2[31]) & tmp_result[31]); 	
	endfunction

	function logic rf_c_flag_add();
		rf_c_flag_add =	(oprd1[31] & oprd2[31]) 
					| (!(tmp_result[31]) & (oprd1[31] | oprd2[31]));
	endfunction


	function logic rf_v_flag_sub();
		rf_v_flag_sub = (oprd1[31] & (!oprd2[31]) & (!tmp_result[31]))
					| ((!oprd1[31]) & (oprd2[31]) & tmp_result[31]);
	endfunction

	function logic rf_c_flag_sub();
		rf_c_flag_sub =	((!oprd1[31]) & oprd2[31]) 
					| ((tmp_result[31]) & (!oprd1[31] | oprd2[31]));
	endfunction

	function logic rf_v_flag_mul();
		rf_v_flag_mul = (oprd1[31] & oprd2[31] & (!tmp_result[31]))
					| ((!oprd1[31]) & (!oprd2[31]) & tmp_result[31]);
	endfunction

	function logic rf_c_flag_mul();
		rf_c_flag_mul =	((oprd1[31]) & oprd2[31]) 
					| ((!tmp_result[31]) & (oprd1[31] | oprd2[31]));
	endfunction

	function logic rf_v_flag_div();
		rf_v_flag_div = (oprd1[31] & (!oprd2[31]) & (!tmp_result[31]))
					| ((!oprd1[31]) & (oprd2[31]) & tmp_result[31]);
	endfunction

	function logic rf_c_flag_div();
		rf_c_flag_div =	0;
	endfunction

	/* Check the V8 manual Page 173 for details*/
	function logic rf_v_flag_logic();
		rf_v_flag_logic = 0;
	endfunction

	function logic rf_c_flag_logic();
		rf_c_flag_logic = 0;
	endfunction

	function logic[31:0] assign_flag_logic();
		logic[31:0] cc_flag;
		cc_flag = rflags;
		cc_flag[`RF_N] = tmp_result[31];
		cc_flag[`RF_Z] = (tmp_result == 0) ? 1:0;
		cc_flag[`RF_C] = rf_c_flag_logic();
		cc_flag[`RF_V] = rf_v_flag_logic();
		return cc_flag;
	endfunction

	function logic[31:0] assign_flag_add();
		logic[31:0] cc_flag;
		cc_flag = rflags;
		cc_flag[`RF_N] = tmp_result[31];
		cc_flag[`RF_Z] = (tmp_result == 0) ? 1:0;
		cc_flag[`RF_C] = rf_c_flag_add();
		cc_flag[`RF_V] = rf_v_flag_add();
		return cc_flag;
	endfunction

	function logic[31:0] assign_flag_sub();
		logic[31:0] cc_flag;
		cc_flag = rflags;
		cc_flag[`RF_N] = tmp_result[31];
		cc_flag[`RF_Z] = (tmp_result == 0) ? 1:0;
		cc_flag[`RF_C] = rf_c_flag_sub();
		cc_flag[`RF_V] = rf_v_flag_sub();
		return cc_flag;
	endfunction

	function logic[31:0] assign_flag_mul();
		logic[31:0] cc_flag;
		cc_flag = rflags;
		cc_flag[`RF_N] = tmp_result[31];
		cc_flag[`RF_Z] = (tmp_result == 0) ? 1:0;
		cc_flag[`RF_C] = rf_c_flag_mul();
		cc_flag[`RF_V] = rf_v_flag_mul();
		return cc_flag;
	endfunction

	function logic[31:0] assign_flag_div();
		logic[31:0] cc_flag;
		cc_flag = rflags;
		cc_flag[`RF_N] = tmp_result[31];
		cc_flag[`RF_Z] = (tmp_result == 0) ? 1:0;
		cc_flag[`RF_C] = rf_c_flag_div();
		cc_flag[`RF_V] = rf_v_flag_div();
		return cc_flag;
	endfunction

	/* For op3[5:4] == 1 */
	function logic[31:0] binary_op_cc_flag();
		logic[31:0] f;
		casez (op3[3:0])
			4'h0: f = assign_flag_add(); /* ADDcc */
			4'h1: f = assign_flag_logic();
			4'h2: f = assign_flag_logic();
			4'h3: f = assign_flag_logic();
			4'h4: f = assign_flag_sub(); /* SUBcc */
			4'h5: f = assign_flag_logic();
			4'h6: f = assign_flag_logic();
			4'h7: f = assign_flag_logic();
			4'h8: f = assign_flag_add(); /* ADDXcc */
			4'ha: f = assign_flag_mul(); /*	UMULcc */
			4'hb: f = assign_flag_mul(); /* SMULcc */
			4'hc: f = assign_flag_sub(); /* SUBXcc */
			4'he: f = assign_flag_div(); /* UDIVcc */
			4'hf: f = assign_flag_div(); /* SDIVcc */
			default:
			$display("[ALU] Unsupported OP");
		endcase
		return f;
	endfunction

	/* verilator lint_off WIDTH */
	/* TRAP and Step multiply and shift */

	/* For op3[5:4] == 2 */
	function logic[63:0] binary_op_other();
		casez (op3[3:0])
		default:
			$display("[ALU] Unsupported OP Maybe TRAP");
		endcase
		return 0;
	endfunction

	function logic[31:0] binary_op_other_flag();
		casez (op3[3:0])
		default:
			$display("[ALU] Unsupported OP Maybe TRAP");
		endcase
		return rflags;
	endfunction

	always_comb begin
		if (enable && !(branch == 1 && delayed_executed ==0)) begin
			$display("[ALU] op: %x op2: %x op3: %x", opcode, op2, op3);
			$display("[ALU] oprd: %x %x %x", oprd1, oprd2, oprd3);

			if (opcode == 3) begin
				$display("[ALU] memory instruction");
			end else if (opcode == 2) begin
				casez (op3[5:4]) 
				2'b00: begin
					tmp_result = binary_op();
					tmp_rflags = binary_op_flag();
				end
				2'b01: begin
					tmp_result = binary_op_cc();
					tmp_rflags = binary_op_cc_flag();
				end
				2'b10: begin
					tmp_result = binary_op_other();
					tmp_rflags = binary_op_other_flag();
				end
				2'b11: begin
					if (op3[3:0] == 4'hC) begin /* SAVE */
						$display("[ALU] Save instruction");
						tmp_result = oprd2 + oprd3;
						tmp_cwp = rflags[4:0] - 1;
						tmp_rflags = rflags;
						tmp_rflags = tmp_cwp;
						$display("[ALU] Save oprd2: %x, oprd3: %x, result: %x", oprd2, oprd3, oprd2 + oprd3);
					end else if (op3[3:0] == 4'h8) begin /* JMPL */
						tmp_result = oprd2 + oprd3;
						tmp_rflags = rflags;
					end else if (op3[3:0] == 4'hd) begin /* RESTORE */
						$display("[ALU] Restore instruction");
						tmp_result = oprd2 + oprd3;
						tmp_cwp = rflags[4:0] + 1;
						tmp_rflags = rflags;
						tmp_rflags = tmp_cwp;
						$display("[ALU] Restore oprd2: %x, oprd3: %x, result: %x", oprd2, oprd3, oprd2 + oprd3);
					end else if (op3[3:0] == 4'ha) begin /* Ticc */
						if (cond_code == 4'h8) begin  /* ta 0x10 */
							tmp_rflags = rflags;
							$display("[ALU] for trap 0x10");
						end

					end else begin

					end

				end
				endcase
			end else if (opcode == 1) begin
				/* Call instruction */
				tmp_rflags = rflags;
				tmp_result[31:0] = oprd1;
			end else begin 
				/* opcode == 0 */
				if (op2 == 4) begin
					$display("[ALU] sethi value: %x", oprd2);
					tmp_result = oprd2; 
				end else if (op2 == 2) begin
					


				end else begin


				end


			end
		end
	end

	always @ (posedge clk) begin
		if (enable == 1 && !mem_blocked) begin
			result <= tmp_result;
			rflags <= tmp_rflags;
			exe_mem <= 1;
			$display("[ALU] tmp_rflags: %x", tmp_rflags);
			$display("[ALU] tmp_result: %x", tmp_result);
		end else if (mem_blocked) begin
			/* Keep the previous value */
		end else begin
			exe_mem <= 0;
		end
	end

	function logic condition_true(logic[3:0] cond);
		case (cond)
			4'b1000: return 1;	/* Always */
			4'b0000: return 0;	/* Never */
			4'b1001: return !rflags[`RF_Z];
			4'b0001: return rflags[`RF_Z];
			4'b1010: return !((rflags[`RF_N] ^ rflags[`RF_V]) | rflags[`RF_Z]);
			4'b0010: return (rflags[`RF_N] ^ rflags[`RF_V]) | rflags[`RF_Z];
			4'b1011: return !(rflags[`RF_N] ^ rflags[`RF_V]);
			4'b0011: return (rflags[`RF_N] ^ rflags[`RF_V]);
			4'b1100: return !(rflags[`RF_Z] | rflags[`RF_C]);
			4'b0100: return (rflags[`RF_Z] | rflags[`RF_C]);
			4'b1101: return !rflags[`RF_C];
			4'b0101: return rflags[`RF_C];
			4'b1110: return !rflags[`RF_N];
			4'b0110: return rflags[`RF_N];
			4'b1111: return !rflags[`RF_V];
			4'b0111: return rflags[`RF_V];
			default: $display("[ALU] ERR unknown condition [%x]", cond);
		endcase
	endfunction


	function logic set_delayed_executed();
		if (cond_code == 4'b1000 && annul ==0) begin
			delayed_executed <= 1;
		end if (cond_code == 4'b0000 && annul ==0) begin
			delayed_executed <= 1;
		end else if (condition_true(cond_code) && annul == 0) begin
			delayed_executed <= 1;
		end else if (!condition_true(cond_code) && annul == 0) begin
			delayed_executed <= 1;
		end else if (condition_true(cond_code) && annul == 1) begin
			delayed_executed <= 1;
		end else begin
			delayed_executed <= 0;
		end

		return 0;
	endfunction


	/* Branched, we don't deal with call/retl/JMPL here */
	always @ (posedge clk) begin
		if (enable == 1) begin
			casez (opcode)
				2'b00: begin
					if (op2 == 2 && condition_true(cond_code)) begin
						$display("[ALU] cond_code: %x", cond_code);
						$display("[ALU] branch_rip: %x", oprd1 + next_rip -4);
						branch <= 1;
						branch_rip <= oprd1 + next_rip - 4; /* Be careful */
						set_delayed_executed();
					end else if (op2 == 2 && !condition_true(cond_code)) begin
						branch <= 1;
						branch_rip <= next_rip + 4; /* Be careful */
						set_delayed_executed();
					end else begin
						branch <= 0;
					end
				end
				default: begin
					branch <= 0;
				end
			endcase
		end else begin
			branch <= 0;
			branch_rip <= 0;
			delayed_executed <= 0; 
		end
	end

endmodule


/* vim: set ts=4 sw=0 tw=0 noet : */
