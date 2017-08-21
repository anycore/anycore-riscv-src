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


module Select #(
	parameter ISSUE_DEPTH          = 128,
	parameter SIZE_SELECT_BLOCK    = 16
	)(
  input                          clk,
  input                          reset,
	input  [`SIZE_ISSUEQ-1:0]      requestVector_i,

	output                         grantedValidA_o,

	/* Encoded form of grantedVector_o */
	output [`SIZE_ISSUEQ_LOG-1:0]  grantedEntryA_o
);

wire [`SIZE_ISSUEQ-1:0]     grantedVector;
wire [`SIZE_ISSUEQ_LOG-1:0] grantedEntry;

localparam NUM_SELECT_BLOCK = ISSUE_DEPTH/SIZE_SELECT_BLOCK;

/* reqOut signals propagating forwards from the back of the select tree to the front */
wire [NUM_SELECT_BLOCK-1:0] reqOut_u0;
wire reqOut_u1;

/* grantIn signals propagating backwards from the front of the select tree */
wire [NUM_SELECT_BLOCK-1:0] grantIn_u0;


/* Assign outputs */
assign grantedValidA_o  = reqOut_u1;
assign grantedEntryA_o  = grantedEntry;

integer i;

/******************************************
* Stage 0 (deals with 128 -> 8 conversion) *
******************************************/

genvar g;
generate
for (g = 0; g < NUM_SELECT_BLOCK; g = g + 1)
begin : SelectBlock_gen

	/* Stage 0 */
	SelectBlock #(
		.SIZE_SELECT_BLOCK (SIZE_SELECT_BLOCK)
		)
		U0 (

		.req_i     (requestVector_i[(g * SIZE_SELECT_BLOCK) +: SIZE_SELECT_BLOCK]),

		.grant_i   (grantIn_u0[g]),

		.grant_o   (grantedVector[(g * SIZE_SELECT_BLOCK) +: SIZE_SELECT_BLOCK]),

		.req_o     (reqOut_u0[g])
	);

end
endgenerate


/******************************************
* Stage 1 (deals with 8 -> 1 conversion) *
******************************************/

/* Stage 1, select block 0 */
SelectBetweenBlocks #(
	.SIZE_SELECT_BLOCK (NUM_SELECT_BLOCK)
	)
	U1 (
  
  .clk      (clk),

  .reset    (reset),

	.req_i    (reqOut_u0),

	.grant_i  (1'h1),

	.grant_o  (grantIn_u0),

	.req_o    (reqOut_u1)
);

/* Instantiate the encoder */
Encoder #(
	.ENCODER_WIDTH     (`SIZE_ISSUEQ),
	.ENCODER_WIDTH_LOG (`SIZE_ISSUEQ_LOG)
	)
	grantEncoder(

	.vector_i          (grantedVector),
	.encoded_o         (grantedEntry)
);

endmodule

