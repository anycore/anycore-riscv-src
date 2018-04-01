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

module RAM_STATIC_CONFIG_NO_DECODE #(
	/* Parameters */
	parameter DEPTH = `RAM_CONFIG_DEPTH,
	parameter INDEX = `RAM_CONFIG_INDEX,
	parameter WIDTH = `RAM_CONFIG_WIDTH,
  parameter NUM_WR_PORTS = `RAM_CONFIG_WP,
  parameter NUM_RD_PORTS = `RAM_CONFIG_RP,
  parameter WR_PORTS_LOG = `RAM_CONFIG_WP_LOG,
  parameter RESET_VAL = `RAM_RESET_ZERO, //RAM_RESET_SEQ or RAM_RESET_ZERO
  parameter SEQ_START = 0,       // valid only when RESET_VAL = "SEQ"
  parameter PARENT_MODULE = "NO_PARENT", // This gives the module name in which this is instantiated
  parameter GATING_ENABLED = 0,
  parameter LATCH_BASED_RAM = 0
) (

  input                                ramGated_i,

	input       [NUM_RD_PORTS-1:0][DEPTH-1:0]       addr_i,
	output reg  [NUM_RD_PORTS-1:0][WIDTH-1:0]       data_o,

	input       [NUM_WR_PORTS-1:0][DEPTH-1:0]       addrWr_i,
	input       [NUM_WR_PORTS-1:0][WIDTH-1:0]       dataWr_i,

	input       [NUM_WR_PORTS-1:0]       wrEn_i,

	input                    clk,
	input                    reset,
  output                   ramReady_o //Used to signal that the RAM is ready for operation
);

  wire clkGated;

  `ifdef GATE_CLK
    // Instantiating clk gate cell
    clk_gater_ul clkGate(.clk_i(clk), .clkGated_o(clkGated), .clkEn_i(~ramGated_i));
  `else
    assign clkGated = clk;
  `endif

  assign ramReady_o = ~reset;

  /* The RAM reg */
  reg  [WIDTH-1:0]                        ram [DEPTH-1:0];
  
  //initial
  //begin
  //    int i;
  //    for (i = 0; i < DEPTH; i++)
  //    begin
  //        ram[i]                      = 0;
  //    end
  //end
  
  /* Read operation */
  always_comb
  begin
    int i;
    int j;
    for(i = 0; i < NUM_RD_PORTS ; i++)
    begin
        data_o[i]                  = ram[0];
      for(j = 0; j < DEPTH ; j++)
      begin
        if(addr_i[i][j])
          data_o[i]                = ram[j];
      end
    end
  end
  
  
  /* Write operation */
  always_ff @(posedge clkGated)
  begin
    int i;
    int j;
  
    if (reset)
    begin
        /* TODO: Load PRF from inputs instead of accessing from the testbench */
        for(i = 0; i < DEPTH; i++)
        begin
            ram[i]              <= (RESET_VAL == `RAM_RESET_SEQ) ? (SEQ_START+i) : 0;
        end
    end
  
    else
    begin
      for (i = 0; i < NUM_WR_PORTS; i++)
      begin
        for (j = 0; j < DEPTH; j++)
        begin
          if(wrEn_i[i] & addrWr_i[i][j])
            ram[j]            <= dataWr_i[i];  
        end
      end
    end
  end

endmodule


