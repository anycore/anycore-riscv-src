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

module RAM_STATIC_CONFIG #(
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

  input       [NUM_WR_PORTS-1:0]       writePortGated_i,
  input       [NUM_RD_PORTS-1:0]       readPortGated_i,
  input                                ramGated_i,

	input       [NUM_RD_PORTS-1:0][INDEX-1:0]       addr_i,
	output reg  [NUM_RD_PORTS-1:0][WIDTH-1:0]       data_o,

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

  wire  [INDEX-1:0]  addrGated    [NUM_RD_PORTS-1:0];
  wire  [INDEX-1:0]  addrWrGated  [NUM_WR_PORTS-1:0];
  wire  [NUM_WR_PORTS-1:0]  wrEnGated;
  wire  clkGated;

  // Input Gating to save dynamic power for deconfigured lanes
  genvar wrp;
  genvar rprt;
  generate
    if (GATING_ENABLED & GATING_OVERRIDE)
    begin: GATED_SIGNALS
      for(wrp = 0; wrp < NUM_WR_PORTS; wrp++)//For every dispatch lane write port
      begin:WP_ADDR_GATE
        PGIsolationCell #(
          .WIDTH(INDEX+1)
        ) wrAddrClamp
        (
          .clampEn(writePortGated_i[wrp]),
          .signalIn({addrWr_i[wrp],wrEn_i[wrp]}),
          .signalOut({addrWrGated[wrp],wrEnGated[wrp]}),
          .clampValue({(INDEX+1){1'b0}})
        );
        //assign wrEnGated[wrp]     =  writePortGated_i[wrp] ? 1'b0 : wrEn_i[wrp];
        //assign addrWrGated[wrp]   =  writePortGated_i[wrp] ? {INDEX{1'b0}} : addrWr_i[wrp];
      end

      for(rprt = 0; rprt < NUM_RD_PORTS; rprt++)//For every dispatch lane write port
      begin:RP_ADDR_GATE
        PGIsolationCell #(
          .WIDTH(INDEX)
        ) rdAddrClamp
        (
          .clampEn(readPortGated_i[rprt]),
          .signalIn(addr_i[rprt]),
          .signalOut(addrGated[rprt]),
          .clampValue({INDEX{1'b0}})
        );
        //assign addrGated[rprt]  = readPortGated_i[rprt] ? {INDEX{1'b0}} : addr_i[rprt];
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
        assign wrEnGated[wrp]      = writePortGated_i[wrp] ? 1'b0 : wrEn_i[wrp];
        assign addrWrGated[wrp]    = addrWr_i[wrp];
      end
      for(rprt = 0; rprt < NUM_RD_PORTS; rprt++)//For every dispatch lane write port
      begin:RP_ADDR_GATE
        assign addrGated[rprt]      = addr_i[rprt];
      end
      assign clkGated       = clk;
    end
  endgenerate




  wire  [NUM_WR_PORTS-1:0]  writeEn;
  wire  [INDEX-1:0]  writeAddr [NUM_WR_PORTS-1:0];
  wire  [WIDTH-1:0]  writeData [NUM_WR_PORTS-1:0];
  reg  [INDEX-1:0]  resetAddr;
  reg  [WIDTH-1:0]  resetData;
  reg  [NUM_WR_PORTS-1:0]  writeEnLat;
  reg  [NUM_WR_PORTS-1:0][INDEX-1:0]  writeAddrLat;
  reg  [NUM_WR_PORTS-1:0][WIDTH-1:0]  writeDataLat;

  reg  [WIDTH-1:0]  ram_reg [DEPTH-1:0];

/*  
  reg  beginReset;

  // Sequential reset
  always_ff @(posedge clk)
  begin
    if(reset)
    begin
      beginReset <= 1'b1; // Start Reset
      resetAddr  <= {INDEX{1'b0}};
      resetData  <= RESET_VAL == `RAM_RESET_SEQ ? SEQ_START : {WIDTH{1'b0}};
    end
    else if(beginReset == 1'b1)
    begin
      resetData <= RESET_VAL == `RAM_RESET_SEQ ? resetData + 1 : {WIDTH{1'b0}}; 
      resetAddr <= resetAddr + 1;
      if(resetAddr == DEPTH-1)
      begin
        beginReset <= 1'b0;  //Reset Done
      end
    end
  end

  // RAM reset state machine 
  //TODO: To be used in future if requred
  assign ramReady_o = ~beginReset;


  genvar wp;
  generate
    for(wp = 0; wp < NUM_WR_PORTS; wp++)//For every dispatch lane write port
    begin:LOOP_WP
      // Mask the write_enables for inactive write lanes to avoid writes from
      // stray write enables

      assign writeEn[wp]    = beginReset ? (wp == 0) : wrEnGated[wp] & ~writePortGated_i[wp];
      assign writeData[wp]  = beginReset ? resetData : dataWr_i[wp];
      assign writeAddr[wp]  = beginReset ? resetAddr : addrWrGated[wp];
  end
  endgenerate
*/
  genvar wp;
  generate
    for(wp = 0; wp < NUM_WR_PORTS; wp++)//For every dispatch lane write port
    begin:LOOP_WP
      // Mask the write_enables for inactive write lanes to avoid writes from
      // stray write enables

      assign writeEn[wp]    = wrEnGated[wp] & ~writePortGated_i[wp];
      assign writeData[wp]  = dataWr_i[wp];
      assign writeAddr[wp]  = addrWrGated[wp];
  end
  endgenerate
  assign ramReady_o = ~reset;

  genvar j;
  generate   
  if(LATCH_BASED_RAM)
  begin: LATCH_ARRAY
    for(j = 0;j < NUM_WR_PORTS; j++)
    begin
      // The master latch - ensures signal capture at posedge
      // Stable signal through the entire positive clk phase
      always @(clk,writeEn[j])
      begin
        if(~clk)
          writeEnLat[j] <= writeEn[j];
      end
      always @(clk,writeData[j])
      begin
        if(~clk)
          writeDataLat[j] <= writeData[j];
      end
      always @(clk,writeAddr[j])
      begin
        if(~clk)
          writeAddrLat[j] <= writeAddr[j];
      end
    end

    int k;
    // Emulates the SRAM array - slave latch
    //always @(clk,writeEnLat,writeDataLat[NUM_WR_PORTS-1:0],writeAddrLat[NUM_WR_PORTS-1:0])
    always @(clk,writeEnLat,writeDataLat,writeAddrLat,reset)
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
        if(clk & writeEnLat[k])
          ram_reg[writeAddrLat[k]] <= writeDataLat[k];
      end
      end
  end
  else
  begin: FF_ARRAY
    int k;
    always_ff @(posedge clkGated)
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

      // Force X on all cells to emulate Power gating
//`ifdef SIM
//      if(ramGated_i)
//        for(k = 0; k < DEPTH; k++)
//          ram_reg[k]  <=  {WIDTH{1'bx}};
//`endif
  end
  endgenerate

  int rp;
  always_comb
  begin
    for(rp = 0; rp < NUM_RD_PORTS; rp++)//For every dispatch lane read port pair
    begin:LOOP_RP      
      //if(readPortGated_i[rp])
      //  data_o[rp] = {WIDTH{1'bx}};
      //else
        data_o[rp] = ram_reg[addr_i[rp]];
    end
  end

endmodule


