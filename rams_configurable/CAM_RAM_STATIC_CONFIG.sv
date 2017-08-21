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

module CAM_RAM_STATIC_CONFIG #(
	/* Parameters */
	parameter DEPTH = `RAM_CONFIG_DEPTH,
	parameter INDEX = `RAM_CONFIG_INDEX,
	parameter WIDTH = `RAM_CONFIG_WIDTH,
  parameter FUNCTION = 0,  // 0 = EQUAL_TO, 1 = GREATER_THAN
  parameter NUM_WR_PORTS = `RAM_CONFIG_WP,
  parameter NUM_CAM_RD_PORTS = `RAM_CONFIG_RP,
  parameter NUM_RAM_RD_PORTS = `RAM_CONFIG_RP,
  parameter WR_PORTS_LOG = `RAM_CONFIG_WP_LOG,
  parameter RESET_VAL = `RAM_RESET_ZERO, //RAM_RESET_SEQ or RAM_RESET_ZERO
  parameter SEQ_START = 0,       // valid only when RESET_VAL = "SEQ"
  parameter PARENT_MODULE = "NO_PARENT", // This gives the module name in which this is instantiated
  parameter GATING_ENABLED = 0,
  parameter LATCH_BASED_RAM = 0
) (

  input       [NUM_WR_PORTS-1:0]       writePortGated_i,
  input       [NUM_CAM_RD_PORTS-1:0]   readPortGated_i,
  input                                ramGated_i,

	input       [NUM_CAM_RD_PORTS-1:0][WIDTH-1:0]       tag_i,
	output reg  [NUM_CAM_RD_PORTS-1:0][DEPTH-1:0]       vect_o,

	input       [NUM_RAM_RD_PORTS-1:0][INDEX-1:0]       addr_i,
	output reg  [NUM_RAM_RD_PORTS-1:0][WIDTH-1:0]       data_o,

	input       [NUM_WR_PORTS-1:0][INDEX-1:0]       addrWr_i,
	input       [NUM_WR_PORTS-1:0][WIDTH-1:0]       dataWr_i,

	input       [NUM_WR_PORTS-1:0]       wrEn_i,

	input                    clk,
	input                    reset,
  output                   ramReady_o //Used to signal that the RAM is ready for operation
);


localparam GATING_OVERRIDE = 1'b0;

//`ifdef SIM  
//  always @*
//  begin
//    $display("%s: WritePortGated: %X readPortGated %X",PARENT_MODULE, writePortGated_i, readPortGated_i);
//  end
//`endif

  wire  [WIDTH-1:0]  tagGated     [NUM_CAM_RD_PORTS-1:0];
  wire  [INDEX-1:0]  addrGated    [NUM_RAM_RD_PORTS-1:0];
  wire  [INDEX-1:0]  addrWrGated  [NUM_WR_PORTS-1:0];
  wire  [NUM_WR_PORTS-1:0]  wrEnGated;
  wire  clkGated;

  // Input Gating to save dynamic power for deconfigured lanes
  genvar wrp;
  genvar crprt;
  genvar rrprt;
  generate
    if (GATING_ENABLED & GATING_OVERRIDE)
    begin: GATED_SIGNALS
      for(wrp = 0; wrp < NUM_WR_PORTS; wrp++)//For every dispatch lane write port
      begin:WP_ADDR_GATE
        PGIsolationCell #(
          .WIDTH(INDEX)
        ) wrAddrClamp
        (
          .clampEn(writePortGated_i[wrp]),
          .signalIn(addrWr_i[wrp]),
          .signalOut(addrWrGated[wrp]),
          .clampValue({INDEX{1'b0}})
        );
        //assign wrEnGated[wrp]     =  writePortGated_i[wrp] ? 1'b0 : wrEn_i[wrp];
        //assign addrWrGated[wrp]   =  writePortGated_i[wrp] ? {INDEX{1'b0}} : addrWr_i[wrp];
      end

      for(crprt = 0; crprt < NUM_CAM_RD_PORTS; crprt++)//For every dispatch lane write port
      begin:RP_CAM_ADDR_GATE
        PGIsolationCell #(
          .WIDTH(WIDTH)
        ) rdAddrClamp
        (
          .clampEn(readPortGated_i[crprt]),
          .signalIn(tag_i[crprt]),
          .signalOut(tagGated[crprt]),
          .clampValue({WIDTH{1'b0}})
        );
        //assign tagGated[crprt]  = readPortGated_i[crprt] ? {WIDTH{1'b0}} : tag_i[crprt];
      end

      for(rrprt = 0; rrprt < NUM_RAM_RD_PORTS; rrprt++)//For every dispatch lane write port
      begin:RP_RAM_ADDR_GATE
        PGIsolationCell #(
          .WIDTH(INDEX)
        ) rdAddrClamp
        (
          .clampEn(readPortGated_i[rrprt]),
          .signalIn(addr_i[rrprt]),
          .signalOut(addrGated[rrprt]),
          .clampValue({INDEX{1'b0}})
        );
        //assign addrGated[rrprt]  = readPortGated_i[rrprt] ? {INDEX{1'b0}} : addr_i[rrprt];
      end

      `ifdef GATE_CLK
        // Instantiating clk gate cell
        clk_gater_ul clkGate(.clk_i(clk), .clkGated_o(clkGated), .clkEn_i(~ramGated_i));
      `else
        assign clkGated = clk;
      `endif
    end
    else
    begin: NON_GATED_SIGNALS
      for(wrp = 0; wrp < NUM_WR_PORTS; wrp++)//For every dispatch lane write port
      begin:WP_ADDR_GATE
        //assign wrEnGated[wrp]      = wrEn_i[wrp];
        assign addrWrGated[wrp]    = addrWr_i[wrp];
      end

      for(crprt = 0; crprt < NUM_CAM_RD_PORTS; crprt++)//For every dispatch lane write port
      begin:RP_CAM_ADDR_GATE
        assign tagGated[crprt]  = tag_i[crprt];
      end

      for(rrprt = 0; rrprt < NUM_RAM_RD_PORTS; rrprt++)//For every dispatch lane write port
      begin:RP_RAM_ADDR_GATE
        assign addrGated[rrprt]  = addr_i[rrprt];
      end

      assign clkGated       = clk;
    end
  endgenerate




  wire  [NUM_WR_PORTS-1:0]  writeEn;
  wire  [INDEX-1:0]  writeAddr [NUM_WR_PORTS-1:0];
  wire  [WIDTH-1:0]  writeData [NUM_WR_PORTS-1:0];

  reg  [WIDTH-1:0]  ram_reg [DEPTH-1:0];
  genvar wp;
  generate
    for(wp = 0; wp < NUM_WR_PORTS; wp++)//For every dispatch lane write port
    begin:LOOP_WP
      //assign writeEn[wp]    = wrEnGated[wp] & ~writePortGated_i[wp];
      assign writeEn[wp]    = wrEn_i[wp] & ~writePortGated_i[wp];
      assign writeData[wp]  = dataWr_i[wp];
      assign writeAddr[wp]  = addrWrGated[wp];
  end
  endgenerate
  assign ramReady_o = ~reset;

  int k;
  always_ff @(posedge clkGated)
  begin
    if(reset)
    begin
      if(RESET_VAL == `RAM_RESET_SEQ)
      begin
        for(k = 0; k < DEPTH; k++)
          ram_reg[k]  <=  SEQ_START + k;
      end
      else
      begin
        for(k = 0; k < DEPTH; k++)
          ram_reg[k]  <=  0;
      end
    end
    else
    begin
      for(k = 0;k < NUM_WR_PORTS; k++)
      begin
        if(writeEn[k])
          ram_reg[writeAddr[k]] <= writeData[k];
      end
    end
  end

  // CAM lookup operation
  int rp;
  int l;
  always_comb
  begin
    for(rp = 0; rp < NUM_CAM_RD_PORTS; rp++)//For every dispatch lane read port pair
    begin:LOOP_CAM_RP      
      if(readPortGated_i[rp])
        vect_o[rp] = {DEPTH{1'bx}};
      else
      begin
        vect_o[rp] = {DEPTH{1'b0}};

        for(l = 0; l < DEPTH; l++)
          if(FUNCTION == 0)
          begin
            if(tagGated[rp] == ram_reg[l])
              vect_o[rp][l] =  1'b1;
          end
          else if(FUNCTION == 1)
          begin
            if(tagGated[rp] > ram_reg[l])
              vect_o[rp][l] =  1'b1;
          end
      end
    end

    for(rp = 0; rp < NUM_RAM_RD_PORTS; rp++)//For every dispatch lane read port pair
    begin:LOOP_RAM_RP      
      if(readPortGated_i[rp])
        data_o[rp] = {WIDTH{1'bx}};
      else
        data_o[rp] = ram_reg[addr_i[rp]];
    end
  end

endmodule


