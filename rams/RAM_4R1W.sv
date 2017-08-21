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

module RAM_4R1W(
	clk,
	reset,

	addr0_i,
	addr1_i,
	addr2_i,
	addr3_i,
	addr0wr_i,
	we0_i,
	data0wr_i,

	data0_o,
	data1_o,
	data2_o,
	data3_o
);

/* Parameters */
parameter DEPTH = 16;
parameter INDEX = 4;
parameter WIDTH = 8;

/* Input and output wires and regs */
input wire clk;
input wire reset;

input wire [INDEX-1:0] addr0_i;
input wire [INDEX-1:0] addr1_i;
input wire [INDEX-1:0] addr2_i;
input wire [INDEX-1:0] addr3_i;
input wire [INDEX-1:0] addr0wr_i;
input wire we0_i;
input wire [WIDTH-1:0] data0wr_i;

output wire [WIDTH-1:0] data0_o;
output wire [WIDTH-1:0] data1_o;
output wire [WIDTH-1:0] data2_o;
output wire [WIDTH-1:0] data3_o;

/* The ram reg */
reg [WIDTH-1:0] ram [DEPTH-1:0];

integer i;

/* Read operation */
assign data0_o = ram[addr0_i];
assign data1_o = ram[addr1_i];
assign data2_o = ram[addr2_i];
assign data3_o = ram[addr3_i];

/* Write operation */
always @(posedge clk)
begin

	if(reset == 1'b1)
	begin
		for(i=0; i<DEPTH; i=i+1)
		begin
			ram[i] <= 0;
		end
	end
	else
	begin
		if(we0_i == 1'b1)
		begin
			ram[addr0wr_i] <= data0wr_i;
		end

	end
end

endmodule

