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

`ifdef LADDER_MUX
module MUX2_CUSTOM #(
  parameter WIDTH = `RAM_CONFIG_WIDTH
) (
  input [WIDTH-1:0] data0,
  input [WIDTH-1:0] data1,
  output [WIDTH-1:0]  dataOut,
  input select
);

  assign dataOut =   select ? data1 : data0;

endmodule
`endif

module RAM_PARTITIONED #(
	/* Parameters */
	parameter DEPTH = `RAM_CONFIG_DEPTH,
	parameter INDEX = `RAM_CONFIG_INDEX,
	parameter WIDTH = `RAM_CONFIG_WIDTH,
  parameter NUM_WR_PORTS = `RAM_CONFIG_WP,
  parameter NUM_RD_PORTS = `RAM_CONFIG_RP,
  parameter WR_PORTS_LOG = `RAM_CONFIG_WP_LOG,
  parameter NUM_PARTS    = `RAM_PARTS,
  parameter NUM_PARTS_LOG= `RAM_PARTS_LOG,
  parameter LATCH_BASED_RAM= `LATCH_BASED_RAM,
  parameter GATING_ENABLED = 1,
  parameter RESET_VAL = `RAM_RESET_ZERO, //RAM_RESET_SEQ or RAM_RESET_ZERO
  parameter SEQ_START = 0,       // valid only when RESET_VAL = "SEQ"
  parameter PARENT_MODULE = "NO_PARENT" // This gives the module name in which this is instantiated
) (

  input       [NUM_WR_PORTS-1:0]       writePortGated_i,
  input       [NUM_RD_PORTS-1:0]       readPortGated_i,
  input       [NUM_PARTS-1:0]          partitionGated_i,

	input       [NUM_RD_PORTS-1:0][INDEX-1:0]       addr_i,
	output reg  [NUM_RD_PORTS-1:0][WIDTH-1:0]       data_o,

	input       [NUM_WR_PORTS-1:0][INDEX-1:0]       addrWr_i,
	input       [NUM_WR_PORTS-1:0][WIDTH-1:0]       dataWr_i,

	input       [NUM_WR_PORTS-1:0]       wrEn_i,

	input                    clk,
	input                    reset,
  output                   ramReady_o //Used to signal that the RAM is ready for operation
);

  //function ceileven;
  //  input rd_ports;
  //  begin
  //    ceileven = rd_ports%2 ? (rd_ports+1) : rd_ports;
  //  end
  //endfunction

//`ifdef SIM  
//  always @*
//  begin
//    $display("%s: WritePortGated: %X readPortGated %X",PARENT_MODULE, writePortGated_i, readPortGated_i);
//  end
//`endif

  wire [NUM_RD_PORTS-1:0][WIDTH-1:0] rdData[NUM_PARTS-1:0];
  wire [NUM_RD_PORTS-1:0][INDEX-NUM_PARTS_LOG-1:0]  addrPartition;
  wire [NUM_WR_PORTS-1:0][INDEX-NUM_PARTS_LOG-1:0]  addrWrPartition;
  wire [NUM_RD_PORTS-1:0][NUM_PARTS_LOG-1:0]  addrPartSelect;
  wire [NUM_WR_PORTS-1:0][NUM_PARTS_LOG-1:0]  addrWrPartSelect;
  wire [NUM_PARTS-1:0]  ramReady;


  genvar rp;
  genvar wp;
  genvar wp1;
  genvar part;
  generate
    for(rp = 0; rp < NUM_RD_PORTS; rp++)
    begin
      assign addrPartition[rp]   = addr_i[rp][INDEX-NUM_PARTS_LOG-1:0];
      assign addrPartSelect[rp]  = addr_i[rp][INDEX-1:INDEX-NUM_PARTS_LOG];
    end

    for(wp = 0; wp < NUM_WR_PORTS; wp++)
    begin
      assign addrWrPartition[wp]   = addrWr_i[wp][INDEX-NUM_PARTS_LOG-1:0];
      assign addrWrPartSelect[wp]  = addrWr_i[wp][INDEX-1:INDEX-NUM_PARTS_LOG];
    end

    for(part = 0; part < NUM_PARTS; part++)//For every dispatch lane read port pair
    begin:INST_LOOP
      wire [NUM_WR_PORTS-1:0] writeEnPartition;
      for(wp1 = 0; wp1 < NUM_WR_PORTS; wp1++)//For every dispatch lane write port
      begin
        assign writeEnPartition[wp1]  = (~writePortGated_i[wp1]) & wrEn_i[wp1] & |(addrWrPartSelect[wp1] == part);
//        assign writeEnPartition[wp1]  = wrEn_i[wp1] & |(addrWrPartSelect[wp1] == part);
      end

      RAM_STATIC_CONFIG 
      #(
        .DEPTH(DEPTH/NUM_PARTS),
        .INDEX(INDEX-NUM_PARTS_LOG),
        .WIDTH(WIDTH),
        .NUM_WR_PORTS(NUM_WR_PORTS),
        .NUM_RD_PORTS(NUM_RD_PORTS),
        .WR_PORTS_LOG(WR_PORTS_LOG),
        .RESET_VAL(RESET_VAL),
        .SEQ_START(SEQ_START+(part*DEPTH/NUM_PARTS)),
        .GATING_ENABLED(GATING_ENABLED),
        .LATCH_BASED_RAM(LATCH_BASED_RAM),
        .PARENT_MODULE({PARENT_MODULE,"_RAM_STATIC"})
      ) ram_instance
      ( 
        .writePortGated_i   (writePortGated_i), 
        .readPortGated_i    (readPortGated_i), 
        .ramGated_i         (partitionGated_i[part]),
        .addr_i             (addrPartition),
        .addrWr_i           (addrWrPartition), //Write to the same address in RAM for each read port
        .wrEn_i             (writeEnPartition),
        .dataWr_i           (dataWr_i),  // Write the same data in each RAM for each read port
        .clk                (clk),
        .reset              (reset),
        .data_o             (rdData[part]),
        .ramReady_o         (ramReady[part])
      );

    end //for INSTANCE_LOOP
  endgenerate

  /* RAM reset state machine */
  //TODO: To be used in future if requred
  assign ramReady_o = &ramReady;

`ifdef LADDER_MUX
// In this case, a ladder structure of final MUXes
// are created instead of a tree structure
  initial begin
    $display("\n\nUsing Ladded MUX structure\n\n");
  end
  
  reg [NUM_RD_PORTS-1:0] selectPartition3_2;
  reg [NUM_RD_PORTS-1:0] selectPartition32_1;
  reg [NUM_RD_PORTS-1:0] selectPartition321_0;
  wire [NUM_RD_PORTS-1:0][WIDTH-1:0] rdDataPartition3_2;
  wire [NUM_RD_PORTS-1:0][WIDTH-1:0] rdDataPartition32_1;
  wire [NUM_RD_PORTS-1:0][WIDTH-1:0] rdDataPartition321_0;
  always_comb 
  begin
    int rp;
    for(rp = 0; rp< NUM_RD_PORTS; rp++)
    begin
      selectPartition3_2[rp]      = addrPartSelect[rp][1] & addrPartSelect[rp][0];
      selectPartition32_1[rp]     = addrPartSelect[rp][1];
      selectPartition321_0[rp]    = addrPartSelect[rp][1] | addrPartSelect[rp][0];
      data_o[rp] = rdDataPartition321_0[rp];
    end
  end

  genvar rprt;
  generate
    for(rprt = 0; rprt< NUM_RD_PORTS; rprt++)
    begin:LADDER_MUX
      MUX2_CUSTOM mux3_2(rdData[2][rprt],rdData[3][rprt],rdDataPartition3_2[rprt],selectPartition3_2[rprt]);
      MUX2_CUSTOM mux32_1(rdData[1][rprt],rdDataPartition3_2[rprt],rdDataPartition32_1[rprt],selectPartition32_1[rprt]);
      MUX2_CUSTOM mux321_0(rdData[0][rprt],rdDataPartition32_1[rprt],rdDataPartition321_0[rprt],selectPartition321_0[rprt]);
    end
  endgenerate

`else
  /* Read operation */
  always_comb 
  begin
    int rp;
    for(rp = 0; rp< NUM_RD_PORTS; rp++)
    begin
      data_o[rp] = rdData[addrPartSelect[rp]][rp];
    end
  end
`endif

endmodule


