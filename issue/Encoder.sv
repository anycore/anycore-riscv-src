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

module Encoder #(
	parameter ENCODER_WIDTH     = 32,
	parameter ENCODER_WIDTH_LOG = 5
	)(

	input  [ENCODER_WIDTH-1:0]     vector_i,
	output [ENCODER_WIDTH_LOG-1:0] encoded_o
);

/* Temporary regs and wires */
reg [ENCODER_WIDTH_LOG-1:0] s [ENCODER_WIDTH-1:0];     // Stores number itself.
reg [ENCODER_WIDTH_LOG-1:0] t [ENCODER_WIDTH-1:0];     // Stores (s[i] if vector[i]==1'b1 else stores 0)
reg [ENCODER_WIDTH-1:0]     u [ENCODER_WIDTH_LOG-1:0]; // Stores transpose of t (to use the | operator)

reg [ENCODER_WIDTH-1:0]     compareVector;

reg [ENCODER_WIDTH_LOG-1:0] encoded;

assign encoded_o = encoded;


always_comb
begin: ENCODER_CONSTRUCT
	int i, j;

	for (i = 0; i < ENCODER_WIDTH; i++)
	begin
		s[i] = i;
	end

	for (i = 0; i < ENCODER_WIDTH; i++)
	begin
		if (vector_i[i])
		begin
			t[i] = s[i];
		end

		else
		begin
			t[i] = 0;
		end
	end

	for (i = 0; i < ENCODER_WIDTH; i++)
	begin
		for (j = 0; j < ENCODER_WIDTH_LOG; j++)
		begin
			u[j][i] = t[i][j];
		end
	end

	for (j = 0; j < ENCODER_WIDTH_LOG; j++)
	begin
		encoded[j] = |u[j];
	end
end

endmodule
