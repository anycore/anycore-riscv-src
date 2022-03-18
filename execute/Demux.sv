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


module Demux (

	input  fuPkt                           input_1,
	output fuPkt                           output_1,
	output fuPkt                           output_2
);


always_comb
begin

	output_1 = input_1;
	output_2 = input_1;

	if (input_1.isSimple) // IT IS A SIMPLE INSTRUCTION
	begin
		output_2.valid    = 1'b0;
	end

	else // IT IS A COMPLEX INSTRUCTION
	begin
		output_1.valid    = 1'b0;
	end
end

endmodule

module Demux3 (

	input  fuPkt                           input_1,
	output fuPkt                           output_1,
	output fuPkt                           output_2,
	output fuPkt                           output_3
);


always_comb
begin
	output_1 = input_1;
	output_2 = input_1;
	output_3 = input_1;

	if (input_1.isFP) // IT IS A FLOATING POINT INSTRUCTION , distinguish between FP and Simple insn here. FP insn has both Simple and FP marked
	begin	
		output_1.valid    = 1'b0;
		output_2.valid    = 1'b0;
	end

	else if (input_1.isSimple) // IT IS A SIMPLE INSTRUCTION
	begin
		output_2.valid    = 1'b0;
		output_3.valid    = 1'b0;
	end

	else // IT IS A COMPLEX INSTRUCTION
	begin
		output_1.valid    = 1'b0;
		output_3.valid    = 1'b0;
	end
end

endmodule


