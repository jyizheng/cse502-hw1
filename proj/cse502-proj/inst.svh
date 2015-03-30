`ifndef _MICRO_OP_SVH_
`define _MICRO_OP_SVH_

`define UOP_T_NONE	3'b00
`define UOP_T_NORM	3'b01
`define UOP_T_MEM	3'b10
`define UOP_T_BR	3'b11

`define OPRD_T_RD	3'b000
`define OPRD_T_IMM	3'b001
`define OPRD_T_DISP	3'b010
`define OPRD_T_RS	3'b011

typedef struct packed {
	logic[2:0] t;		/* Type */
	logic[4:0] r;		/* Register No. */
	logic[31:0] value;
} oprd_t;

typedef struct packed {
	logic[2:0] t;
	logic[1:0] op;
	logic[2:0] op2;
	logic[5:0] op3;
	logic[8:0] opf;
	logic annul_flag;
	logic[3:0] cond;

	oprd_t oprd1;
	oprd_t oprd2;
	oprd_t oprd3;
	logic[63:0] next_rip;
} micro_op_t;

`endif
