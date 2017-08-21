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

module PriorityEncoder #(
	parameter ENCODER_WIDTH = 32
	)(

	input  [ENCODER_WIDTH-1:0]  vector_i,
	output [ENCODER_WIDTH-1:0]  vector_o
);

/* Mask to reset all other bits except the first */
reg  [ENCODER_WIDTH-1:0]  mask;

wire [ENCODER_WIDTH-1:0]  vector;

assign vector_o = vector;

/* Mask the input vector so that only the first 1'b1 is seen */
assign vector = vector_i & mask;


always_comb
begin: ENCODER_CONSTRUCT
	int i;
	mask[0] = 1'b1;

	for (i = 1; i < ENCODER_WIDTH; i++)
	begin
		if (vector_i[i-1])
		begin
			mask[i] = 0;
		end

		else
		begin
			mask[i] = mask[i-1];
		end
	end
end

endmodule
