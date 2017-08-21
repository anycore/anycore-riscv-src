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


module Mux (

	input  wbPkt                           input_1,
	input  wbPkt                           input_2,
	output wbPkt                           output_1
);


always_comb
begin

	if (input_1.valid) // IT IS A SIMPLE INSTRUCTION
	begin
		output_1 = input_1;
	end

	else if (input_2.valid) // IT IS A COMPLEX INSTRUCTION
	begin
		output_1 = input_2;
	end

	else
	begin
		output_1 = 0;
	end
end

endmodule


module Mux3 (

	input  wbPkt                           input_1,
	input  wbPkt                           input_2,
	input  wbPkt                           input_3,
	output wbPkt                           output_1
);


always_comb
begin

	if (input_1.valid) // IT IS A SIMPLE INSTRUCTION
	begin
		output_1 = input_1;
	end

	else if (input_2.valid) // IT IS A COMPLEX INSTRUCTION
	begin
		output_1 = input_2;
	end

	else if (input_3.valid) // IT IS A FP INSTRUCTION
	begin
		output_1 = input_3;
	end

	else
	begin
		output_1 = 0;
	end
end

endmodule
