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

module RAM_PG_2R1W( pwrGate_i,addr0_i,addr1_i,addrWr_i,we_i,data_i,
		  clk,reset,data0_o,data1_o);


parameter DEPTH  =  64;
parameter INDEX  =  6;
parameter WIDTH  =  32;
parameter RESET_VAL  =  `RAM_RESET_ZERO;
parameter SEQ_START  =  0;

input [INDEX-1:0] addr0_i;
input [INDEX-1:0] addr1_i;
input [INDEX-1:0] addrWr_i;
input  we_i;
input  clk;
input  reset;
input  pwrGate_i;
input  [WIDTH-1:0] data_i;
output [WIDTH-1:0] data0_o;
output [WIDTH-1:0] data1_o;

/* Defining register file for ram */
reg [WIDTH-1:0] ram [DEPTH-1:0];

integer i;

// Emulate Power gating for simulation by reading Xs
assign data0_o = pwrGate_i ? {WIDTH{1'bx}} : ram[addr0_i];
assign data1_o = pwrGate_i ? {WIDTH{1'bx}} : ram[addr1_i];


always @(posedge clk or posedge pwrGate_i)
begin
  // Emulating effect of power gate by making all RAM locations X
  // at the negedge of pwrGate_i signal i.e when powering back up
  if(pwrGate_i)
  begin
   for(i=0;i<DEPTH;i=i+1)
       ram[i] <= {WIDTH{1'bx}};
  end
  else 
  begin
    if(reset)
    begin
      if(RESET_VAL == `RAM_RESET_SEQ)
      begin
        for(i=0;i<DEPTH;i=i+1)
          ram[i] <= SEQ_START+i;
      end
      else if(RESET_VAL == `RAM_RESET_ZERO)
      begin
        for(i=0;i<DEPTH;i=i+1)
          ram[i] <= 0;
      end
    end

    else
    begin
     if(we_i & ~pwrGate_i)
        ram[addrWr_i] <= data_i;
    end
  end
end

endmodule

