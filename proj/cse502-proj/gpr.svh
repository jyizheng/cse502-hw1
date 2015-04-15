
`ifndef _GPR_SVH_
`define _GPR_SVH_ 1


/* RFLAGS fields */

`define RF_IMPL_MSB	31
`define RF_IMPL_LSB	28
`define RF_VER_MSB	27
`define RF_VER_LSB	24
`define RF_ICC_MSB	23
`define RF_ICC_LSB	20
`define RF_N	23
`define RF_Z	22
`define RF_V	21
`define RF_C	20
`define RF_RESV_MSB	19
`define RF_RESV_LSB	14
`define RF_EC	13
`define RF_EF	12
`define RF_PIL_MSB	11
`define RF_PIL_LSB	8
`define RF_S	7
`define RF_PS	6
`define RF_ET	5
`define RF_CWP_MSB	4
`define RF_CWP_LSB	0

`define REG_G0	0
`define REG_G1	1
`define REG_G2	2
`define REG_G3	3
`define REG_G4	4
`define REG_G5	5
`define REG_G6	6
`define REG_G7	7

`define REG_O0	8
`define REG_O1	9
`define REG_O2	10
`define REG_O3	11
`define REG_O4	12
`define REG_O5	13
`define REG_O6	14
`define REG_O7	15

`define REG_L0	16
`define REG_L1	17
`define REG_L2	18
`define REG_L3	19
`define REG_L4	20
`define REG_L5	21
`define REG_L6	22
`define REG_L7	23

`define REG_I0	24
`define REG_I1	25
`define REG_I2	26
`define REG_I3	27
`define REG_I4	28
`define REG_I5	29
`define REG_I6	30
`define REG_I7	31

`endif

/* vim: set ts=4 sw=0 tw=0 noet : */
