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
			$display("Unsupported OP");
		endcase
	endfunction

	function logic[31:0] binary_op_flag();
		casez (op3[3:0])
		4'h0: binary_op_flag = rflags;
		default:
			$display("Unsupported OP");
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
			$display("Unsupported OP");
		endcase
	endfunction

	function logic[31:0] binary_op_cc_flag();
		casez (op3[3:0])
		4'h0: binary_op_cc_flag = rflags;
		default:
			$display("Unsupported OP");
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
			$display("Unsupported OP");
		endcase
	endfunction

	function logic[31:0] binary_op_other_flag();
		casez (op3[3:0])
		4'h0: binary_op_other_flag = rflags;
		default:
			$display("Unsupported OP");
		endcase
	endfunction


	always_comb begin
		if (enable) begin
			if (opcode == 3) begin
				
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
					$display("Umimplemented OP");
				end
				endcase
			end else if (opcode == 1) begin

			end else begin
			
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

	function logic condition_true(logic[7:0] cond);
		case (cond)
			8'h02: return rflags[`RF_C];
			default: $display("[ALU] ERR unknown condition [%x]", cond);
		endcase
	endfunction


	/* Branched, we don't deal with call/retq here */
	always @ (posedge clk) begin
		if (enable == 1) begin
			casez (opcode)
				10'b00: begin
					if (condition_true({4'b0,4'b0})) begin
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
