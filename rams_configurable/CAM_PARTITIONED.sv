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

module CAM_PARTITIONED #(
	/* Parameters */
	parameter DEPTH = `RAM_CONFIG_DEPTH,
	parameter INDEX = `RAM_CONFIG_INDEX,
	parameter WIDTH = `RAM_CONFIG_WIDTH,
  parameter NUM_WR_PORTS = `RAM_CONFIG_WP,
  parameter NUM_RD_PORTS = `RAM_CONFIG_RP,
  parameter WR_PORTS_LOG = `RAM_CONFIG_WP_LOG,
  parameter NUM_PARTS    = `STRUCT_PARTS,
  parameter NUM_PARTS_LOG= `STRUCT_PARTS_LOG,
  parameter RESET_VAL = `RAM_RESET_ZERO, //RAM_RESET_SEQ or RAM_RESET_ZERO
  parameter SEQ_START = 0,       // valid only when RESET_VAL = "SEQ"
  parameter PARENT_MODULE = "NO_PARENT" // This gives the module name in which this is instantiated
) (

  input       [NUM_WR_PORTS-1:0]       writePortGated_i,
  input       [NUM_RD_PORTS-1:0]       readPortGated_i,
  input       [NUM_PARTS-1:0]          partitionGated_i,

	input       [NUM_RD_PORTS-1:0][WIDTH-1:0]       tag_i,
	output reg  [NUM_RD_PORTS-1:0][DEPTH-1:0]       vect_o,

	input       [NUM_WR_PORTS-1:0][INDEX-1:0]       addrWr_i,
	input       [NUM_WR_PORTS-1:0][WIDTH-1:0]       dataWr_i,

	input       [NUM_WR_PORTS-1:0]       wrEn_i,

	input                    clk,
	input                    reset,
  output                   ramReady_o //Used to signal that the RAM is ready for operation
);

//`ifdef SIM  
//  always @*
//  begin
//    $display("%s: WritePortGated: %X readPortGated %X",PARENT_MODULE, writePortGated_i, readPortGated_i);
//  end
//`endif

  // Each partition matches ony 1/4th the number of entries
  wire [NUM_RD_PORTS-1:0][(DEPTH/NUM_PARTS)-1:0]  vect[NUM_PARTS-1:0];
  wire [NUM_WR_PORTS-1:0][INDEX-NUM_PARTS_LOG-1:0]  addrWrPartition;
  wire [NUM_WR_PORTS-1:0][INDEX-NUM_PARTS_LOG-1:0]  addrWrPartSelect;
  wire [NUM_PARTS-1:0]  ramReady;


  genvar wp;
  genvar wp1;
  genvar part;
  generate
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
        assign writeEnPartition[wp1]  = wrEn_i[wp1] & (addrWrPartSelect[wp1] == part);
      end

      CAM_STATIC_CONFIG 
      #(
        .DEPTH(DEPTH/NUM_PARTS),
        .INDEX(INDEX-NUM_PARTS_LOG),
        .WIDTH(WIDTH),
        .NUM_WR_PORTS(NUM_WR_PORTS),
        .NUM_RD_PORTS(NUM_RD_PORTS),
        .WR_PORTS_LOG(WR_PORTS_LOG),
        .RESET_VAL(RESET_VAL),
        .SEQ_START(SEQ_START+(part*DEPTH/NUM_PARTS)),
        .GATING_ENABLED(1),
        .PARENT_MODULE({PARENT_MODULE,"_CAM_STATIC"})
      ) cam_instance
      ( 
        .writePortGated_i   (writePortGated_i), 
        .readPortGated_i    (readPortGated_i), 
        .ramGated_i         (partitionGated_i[part]),
        // All the tags are sent to all the partitions
        .tag_i              (tag_i),
        .addrWr_i           (addrWrPartition), //Write to the same address in RAM for each read port
        .wrEn_i             (writeEnPartition),
        .dataWr_i           (dataWr_i),  // Write the same data in each RAM for each read port
        .clk                (clk),
        .reset              (reset),
        .vect_o             (vect[part]),
        .ramReady_o         (ramReady[part])
      );

    end //for INSTANCE_LOOP
  endgenerate

  /* RAM reset state machine */
  //TODO: To be used in future if requred
  assign ramReady_o = &ramReady;


  /* Read operation */
  always_comb 
  begin
    int rp;
    for(rp = 0; rp< NUM_RD_PORTS; rp++)
    begin
      vect_o[rp] = {vect[3][rp],vect[2][rp],vect[1][rp],vect[0][rp]};
    end
  end

endmodule


