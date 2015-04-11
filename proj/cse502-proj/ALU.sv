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


	/* verilator lint_off WIDTH */
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
		4'h8: binary_op = oprd2 + oprd3 + rflags[`RF_C];
		4'ha: binary_op = oprd2 * oprd3;
		4'hb: binary_op = oprd2 * oprd3;
		4'hc: binary_op = oprd2 - oprd3 - rflags[`RF_C];
		4'he: binary_op = oprd2 / oprd3;
		4'hf: binary_op = oprd2 / oprd3;
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

	function logic[31:0] binary_op_cc_flag();
		casez (op3[3:0])
		4'h0: binary_op_cc_flag = rflags;
		default:
			$display("[ALU] Unsupported OP");
		endcase
	endfunction

	/* verilator lint_off WIDTH */
	function logic[63:0] binary_op_other();
		casez (op3[3:0])
		4'h0: binary_op_other = oprd2 + oprd3;
		4'h1: binary_op_other = oprd2 & oprd3;
		4'h2: binary_op_other = oprd2 | oprd3;
		4'h3: binary_op_other = oprd2 ^ oprd3;
		4'h4: binary_op_other = oprd2 - oprd3;
		4'h5: binary_op_other = oprd2 & (~oprd3);
		4'h6: binary_op_other = oprd2 | (~oprd3);
		4'h7: binary_op_other = oprd2 ^ (~oprd3);
		4'h8: binary_op_other = oprd2 + oprd3 + rflags[`RF_C];
		4'ha: binary_op_other = oprd2 * oprd3;
		4'hb: binary_op_other = oprd2 * oprd3;
		4'hc: binary_op_other = oprd2 - oprd3 - rflags[`RF_C];
		4'he: binary_op_other = oprd2 / oprd3;
		4'hf: binary_op_other = oprd2 / oprd3;
		default:
			$display("[ALU] Unsupported OP");
		endcase
	endfunction

	function logic[31:0] binary_op_other_flag();
		casez (op3[3:0])
		4'h0: binary_op_other_flag = rflags;
		default:
			$display("[ALU] Unsupported OP");
		endcase
	endfunction


	always_comb begin

		if (enable) begin

			$display("[ALU] op: %x op2: %x op3: %x", opcode, op2, op3);
			$display("[ALU] oprd: %x %x %x", oprd1, oprd2, oprd3);


			if (opcode == 3) begin

				$display("[ALU] memory inst");

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
					$display("[ALU] Umimplemented OP");
				end
				endcase
			end else if (opcode == 1) begin

			end else begin
				if (op2 == 4) begin
					$display("[ALU] sethi value: %x", oprd2);
					tmp_result = oprd2; 
				end
			end
		end
	end

	always @ (posedge clk) begin
		if (enable == 1 && !mem_blocked) begin
			result <= tmp_result;
			rflags <= tmp_rflags;
			exe_mem <= 1;
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


	/* Branched, we don't deal with call/ret here */
	always @ (posedge clk) begin
		if (enable == 1) begin
			casez (opcode)
				10'b00: begin
					if (op2 == 2 && condition_true(cond_code)) begin
						branch <= 1;
						branch_rip <= oprd2 + next_rip;
					end else begin
						branch <= 1;
						branch_rip <= next_rip;
					end
				end
				default: begin
					branch <= 0;
				end
			endcase
		end else begin
			branch <= 0;
			branch_rip <= 0;
		end
	end

endmodule
