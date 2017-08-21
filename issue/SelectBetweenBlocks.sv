/*******************************************************************************
#                        NORTH CAROLINA STATE UNIVERSITY
#
#                              AnyCore Project
# 
# AnyCore written by NCSU authors Rangeen Basu Roy Chowdhury and Eric Rotenberg.
# 
# AnyCore is based on FabScalar which was written by NCSU authors Niket K. 
# Choudhary, Brandon H. Dwiel, and Eric Rotenberg.
# 
# AnyCore also includes contributions by NCSU authors Elliott Forbes, Jayneel 
# Gandhi, Anil Kumar Kannepalli, Sungkwan Ku, Hiran Mayukh, Hashem Hashemi 
# Najaf-abadi, Sandeep Navada, Tanmay Shah, Ashlesha Shastri, Vinesh Srinivasan, 
# and Salil Wadhavkar.
# 
# AnyCore is distributed under the BSD license.
*******************************************************************************/

`timescale 1ns/100ps

module SelectBetweenBlocks #(
	parameter SIZE_SELECT_BLOCK = 16
	)(
  input                           clk,
  input                           reset,

	input  [SIZE_SELECT_BLOCK-1:0]  req_i,

	/* The grant signal coming in from the next stage of the select tree */
	input                           grant_i,

	output [SIZE_SELECT_BLOCK-1:0]  grant_o,

	/* OR of the request signals, used as req_i for next stage of the select tree */
	output                          req_o
);

/* Wires and registers for combinatinal logic */
wire [SIZE_SELECT_BLOCK-1:0] grant;

/* Gate the current grant output with the grant_i from the next stage of the select tree */
assign grant_o = grant & {SIZE_SELECT_BLOCK{grant_i}};

/* Create the OR gate */
assign req_o = |req_i;

`ifndef RR_ISSUE_PARTITION
/* Create the priority logic */
PriorityEncoder #(
	.ENCODER_WIDTH     (SIZE_SELECT_BLOCK)
	)
	selectBlockPEncoder(

	.vector_i          (req_i),
	.vector_o          (grant)
);
`else
/* Create the priority logic */
PriorityEncoderRR #(
	.ENCODER_WIDTH     (SIZE_SELECT_BLOCK)
	)
	selectBlockPEncoderRR(

  .clk               (clk),
  .reset             (reset),
	.vector_i          (req_i),
	.vector_o          (grant)
);
`endif
endmodule
