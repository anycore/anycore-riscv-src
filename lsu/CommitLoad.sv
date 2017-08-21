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

module CommitLoad ( 
	input  [`COMMIT_WIDTH-1:0]            commitLoad_i,

	input  [`SIZE_LSQ_LOG-1:0]            ldqHead_i,

	output [2:0]                          commitLdCount_o,

	output [`SIZE_LSQ_LOG-1:0]            commitLdIndex_o [0:`COMMIT_WIDTH-1]
);


reg [2:0]                 commitLdCount;
reg [`SIZE_LSQ_LOG-1:0]   commitLdIndex [0:`COMMIT_WIDTH-1];


assign commitLdCount_o   = commitLdCount;
assign commitLdIndex_o   = commitLdIndex;


/* Following combinational logic counts the number of LD commitructions in the
 * incoming retiring commitructions. */
always_comb
begin
	commitLdCount    = commitLoad_i[0] + commitLoad_i[1] + commitLoad_i[2] + commitLoad_i[3];
	commitLdIndex[0] = ldqHead_i;
	commitLdIndex[1] = ldqHead_i+1;
	commitLdIndex[2] = ldqHead_i+2;
	commitLdIndex[3] = ldqHead_i+3;
end

endmodule
