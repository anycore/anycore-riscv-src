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

module DEBUG_INST_RAM #(

    /* Parameters */
    parameter DEPTH = 256,
    parameter INDEX = 8,
    parameter WIDTH = 64
    ) (

`ifdef SCRATCH_PAD

      input  [INDEX-1:0]                addr0_i,
      output [WIDTH-1:0]                data0_o,
  
  `ifdef FETCH_TWO_WIDE
      input  [INDEX-1:0]                addr1_i,
      output [WIDTH-1:0]                data1_o,
  `endif
  
  `ifdef FETCH_THREE_WIDE
      input  [INDEX-1:0]                addr2_i,
      output [WIDTH-1:0]                data2_o,
  `endif
  
  `ifdef FETCH_FOUR_WIDE
      input  [INDEX-1:0]                addr3_i,
      output [WIDTH-1:0]                data3_o,
  `endif
  
  `ifdef FETCH_FIVE_WIDE
      input  [INDEX-1:0]                addr4_i,
      output [WIDTH-1:0]                data4_o,
  `endif
  
  `ifdef FETCH_SIX_WIDE
      input  [INDEX-1:0]                addr5_i,
      output [WIDTH-1:0]                data5_o,
  `endif
  
  `ifdef FETCH_SEVEN_WIDE
      input  [INDEX-1:0]                addr6_i,
      output [WIDTH-1:0]                data6_o,
  `endif
  
  `ifdef FETCH_EIGHT_WIDE
      input  [INDEX-1:0]                addr7_i,
      output [WIDTH-1:0]                data7_o,
  `endif
  
  
      input [`DEBUG_INST_RAM_LOG+`DEBUG_INST_RAM_WIDTH_LOG-1:0]   instScratchAddr_i   ,
      input [7:0]   instScratchWrData_i ,
      input         instScratchWrEn_i   ,
      output [7:0]  instScratchRdData_o ,

`endif //`ifdef SCRATCH_PAD

    input                             clk,
    input                             reset
);


`ifdef SCRATCH_PAD

  reg  [WIDTH-1:0]                    ram [DEPTH-1:0];
  
  
  /* Read operation */
    assign data0_o                    = ram[addr0_i];
  
  `ifdef FETCH_TWO_WIDE
    assign data1_o                    = ram[addr1_i];
  `endif
  
  `ifdef FETCH_THREE_WIDE
    assign data2_o                    = ram[addr2_i];
  `endif
  
  `ifdef FETCH_FOUR_WIDE
    assign data3_o                    = ram[addr3_i];
  `endif
  
  `ifdef FETCH_FIVE_WIDE
    assign data4_o                    = ram[addr4_i];
  `endif
  
  `ifdef FETCH_SIX_WIDE
    assign data5_o                    = ram[addr5_i];
  `endif
  
  `ifdef FETCH_SEVEN_WIDE
    assign data6_o                    = ram[addr6_i];
  `endif
  
  `ifdef FETCH_EIGHT_WIDE
    assign data7_o                    = ram[addr7_i];
  `endif
    assign instScratchRdData_o = ram[instScratchAddr_i[`DEBUG_INST_RAM_LOG-1:0]][(8*(instScratchAddr_i[`DEBUG_INST_RAM_LOG+`DEBUG_INST_RAM_WIDTH_LOG-1:`DEBUG_INST_RAM_LOG]+1)-1)-:8] ;
  
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
          if (instScratchWrEn_i)
          begin
            ram[instScratchAddr_i[`DEBUG_INST_RAM_LOG-1:0]][(8*(instScratchAddr_i[`DEBUG_INST_RAM_LOG+`DEBUG_INST_RAM_WIDTH_LOG-1:`DEBUG_INST_RAM_LOG]+1)-1)-:8] <= instScratchWrData_i ;
          end
      end
  end

`endif

endmodule

