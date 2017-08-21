/***************************************************************************
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

module RAM_1R2W #(

	/* Parameters */
  parameter RPORT = 1,
  parameter WPORT = 1,
	parameter DEPTH = 16,
	parameter INDEX = 4,
	parameter WIDTH = 8
) (

	input  [INDEX-1:0]                addr0_i,
	output [WIDTH-1:0]                data0_o,


	input  [INDEX-1:0]                addr0wr_i,
	input  [WIDTH-1:0]                data0wr_i,
	input                             we0_i,

	input  [INDEX-1:0]                addr1wr_i,
	input  [WIDTH-1:0]                data1wr_i,
	input                             we1_i,

	input                             clk,
	input                             reset
);


reg  [WIDTH-1:0]                    ram [DEPTH-1:0];


/* Read operation */
assign data0_o                    = ram[addr0_i];


/* Write operation */
always_ff @(posedge clk)
begin
	int i;

	if (reset)
	begin
		for (i = 0; i < DEPTH; i++)
		begin
			ram[i]         <= 0;
		end
	end

	else
	begin
		if (we0_i)
		begin
			ram[addr0wr_i] <= data0wr_i;
		end

		if (we1_i)
		begin
			ram[addr1wr_i] <= data1wr_i;
		end
	end
end

endmodule


