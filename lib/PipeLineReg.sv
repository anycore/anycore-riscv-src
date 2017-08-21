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

module PipeLineReg 
  #(parameter WIDTH=1,CLKGATE=1)
  (clk,reset,stall_i,clkEn_i,pwrEn_i,data_i,data_o);

  input               clk;
  input               reset;
  input               stall_i;
  input               clkEn_i;  // Clk is on when high
  input               pwrEn_i;  // Power is on when high
  input   [WIDTH-1:0] data_i;
  output  [WIDTH-1:0] data_o;

  reg             clkGated;
  reg [WIDTH-1:0] data;

  assign data_o = data;

  generate
    if(CLKGATE)
    begin:GATED_CLK
      // Instantiating clk gate cell
      clk_gater_ul clkGate (.clk_i(clk),.clkGated_o(clkGated),.clkEn_i(clkEn_i));

      always_ff @(posedge clkGated)
      //always_ff @(posedge clk)
      begin
        if(reset)
          data <= {WIDTH{1'b0}};

      // Emulate Power Gating        
      `ifdef SIM
        else if(~pwrEn_i & clkEn_i)
          data <= {WIDTH{1'bx}};
      `endif

        else if(~stall_i & clkEn_i)
          data <= data_i;

      end
    end
    else
    begin:NON_GATED_CLK
      always_ff @(posedge clk)
      begin
        if(reset)
          data <= {WIDTH{1'b0}};

      // Emulate Power Gating        
      `ifdef SIM
        else if(~pwrEn_i)
          data <= {WIDTH{1'bx}};
      `endif

        else if(~stall_i)
          data <= data_i;

      end
    end
  endgenerate

endmodule  

