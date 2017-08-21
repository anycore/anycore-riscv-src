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

module RAM_1R1W( addr0_i,addr0wr_i,we0_i,data0wr_i,
		  clk,data0_o);


parameter RPORT  =  1;
parameter WPORT  =  1;
parameter DEPTH  =  64;
parameter INDEX  =  6;
parameter WIDTH  =  32;

input [INDEX-1:0] addr0_i;
input [INDEX-1:0] addr0wr_i;
input  we0_i;
input  clk;
//input  reset;
input  [WIDTH-1:0] data0wr_i;
output [WIDTH-1:0] data0_o;

`ifdef RAM_1R1W_COMPILED
//synopsys translate_off
`endif

/* Defining register file for ram */
reg [WIDTH-1:0] ram [DEPTH-1:0];

integer i;

assign data0_o = ram[addr0_i];


always @(posedge clk)
begin
// if(reset)
// begin
//  for(i=0;i<DEPTH;i=i+1)
//      ram[i] <= {WIDTH{1'b0}};
// end
// else
// begin
  if(we0_i)
     ram[addr0wr_i] <= data0wr_i;
// end
end

`ifdef RAM_1R1W_COMPILED
//synopsys translate_on
`endif

endmodule

