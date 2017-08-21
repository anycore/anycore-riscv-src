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

// NOTE: Too small to be converted into RAMs
module CTI_COMMIT_RAM #(
	/* Parameters */
  parameter RPORT = 1,
  parameter WPORT = (`COMMIT_WIDTH+1),
	parameter DEPTH = 16,
	parameter INDEX = 4,
	parameter WIDTH = 8
) (

	/* Read ports */
	input  [INDEX-1:0]      addr0_i,
	output [WIDTH-1:0]      data0_o,
                          
	/* Write ports */       
	input  [INDEX-1:0]      addr0wr_i,
	input  [WIDTH-1:0]      data0wr_i,
	input                   we0_i,

	input  [INDEX-1:0]      addr1wr_i,
	input  [WIDTH-1:0]      data1wr_i,
	input                   we1_i,

`ifdef COMMIT_TWO_WIDE
	input  [INDEX-1:0]      addr2wr_i,
	input  [WIDTH-1:0]      data2wr_i,
	input                   we2_i,
`endif

`ifdef COMMIT_THREE_WIDE
	input  [INDEX-1:0]      addr3wr_i,
	input  [WIDTH-1:0]      data3wr_i,
	input                   we3_i,
`endif

`ifdef COMMIT_FOUR_WIDE
	input  [INDEX-1:0]      addr4wr_i,
	input  [WIDTH-1:0]      data4wr_i,
	input                   we4_i,
`endif

	input                   reset,
	input                   clk
);

// NOTE: Too small to be converted into RAMs

/* The ram reg */
reg  [WIDTH-1:0] ram [DEPTH-1:0];


/* Read operation */
assign data0_o = ram[addr0_i];

/* Write operation */
always_ff @(posedge clk) 
begin
	int i;

	if (reset)
	begin
		for (i = 0; i < DEPTH; i++)
		begin
			ram[i] <= 0;
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

`ifdef COMMIT_TWO_WIDE
		if (we2_i)
		begin
			ram[addr2wr_i] <= data2wr_i;
		end
`endif

`ifdef COMMIT_THREE_WIDE
		if (we3_i)
		begin
			ram[addr3wr_i] <= data3wr_i;
		end
`endif

`ifdef COMMIT_FOUR_WIDE
		if (we4_i)
		begin
			ram[addr4wr_i] <= data4wr_i;
		end
`endif
	end
end

endmodule

