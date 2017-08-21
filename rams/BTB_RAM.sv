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

module BTB_RAM #(
  parameter RPORT  = 1,
  parameter WPORT  = 1,
	parameter DEPTH  =  64,
	parameter INDEX  =  6,
	parameter WIDTH  =  32
) (
	input                   clk,
	//input                   reset,

	input  [INDEX-1:0]      addr0_i,
	output [WIDTH-1:0]      data0_o,
                          
	input  [INDEX-1:0]      addr0wr_i,
	input  [WIDTH-1:0]      data0wr_i,
	input                   we0_i
);

`ifdef BTB_RAM_COMPILED
// synopsys translate_off
`endif

reg  [WIDTH-1:0]          ram [DEPTH-1:0];

assign data0_o          = ram[addr0_i];


always_ff @(posedge clk)
begin
	int i;
	//if (reset)
	//begin
	//	for (i = 0; i < DEPTH; i++)
	//	begin
	//		ram[i]           <= {WIDTH{1'b0}};
	//	end
	//end
  //
	//else
	//begin
		if (we0_i)
		begin
			ram[addr0wr_i]   <= data0wr_i;
		end
	//end
end

`ifdef BTB_RAM_COMPILED
// synopsys translate_on
`endif

endmodule

