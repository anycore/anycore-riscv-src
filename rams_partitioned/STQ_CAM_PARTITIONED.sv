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

module STQ_CAM_PARTITIONED #(
	/* Parameters */
  parameter RPORT = 1,
  parameter WPORT = 1,
	parameter DEPTH = 16,
	parameter INDEX = 4,
	parameter WIDTH = 8,
  parameter FUNCTION    = 0  // 0 = EQUAL_TO,  1 = GREATER_THAN
	) (

	input      [WIDTH-1:0]                tag0_i,
	output reg [DEPTH-1:0]                vect0_o,
	
	input      [INDEX-1:0]                addr0wr_i,
	input      [WIDTH-1:0]                data0wr_i,
	input                                 we0_i,

	//input      [INDEX-1:0]                wrAddr1_i,
	//input      [WIDTH-1:0]                wrData1_i,
	//input                                 we1_i,

  input [`STRUCT_PARTS_LSQ-1:0]         lsqPartitionActive_i,

	//input                                 reset,
	input                                 clk
);



// TODO: Need to optimize in order to reduce power consumption
  /* Read operation */
/*
  reg [DEPTH-1:0]  vect0;
  assign vect0_o = issueLaneActive_i[0] ? vect0 : {DEPTH{1'b0}};
*/

  //wire [1:0]              we;
  //wire [1:0][INDEX-1:0]   addrWr;
  //wire [1:0][WIDTH-1:0]   dataWr;
  logic [0:0]              we;
  logic [0:0][INDEX-1:0]   addrWr;
  logic [0:0][WIDTH-1:0]   dataWr;

  logic [0:0][WIDTH-1:0]   tag;
  logic [0:0][DEPTH-1:0]   vect;

  //wire [1:0]                writePortGated;
  logic [0:0]                writePortGated;
  logic [0:0]                readPortGated;
  logic [`STRUCT_PARTS_LSQ-1:0]  partitionGated; 

  assign writePortGated   = 2'b00;
  assign readPortGated    = 1'b0;
  assign partitionGated   = ~lsqPartitionActive_i;

  assign we[0] = we0_i;
  assign addrWr[0] = addr0wr_i;
  assign dataWr[0] = data0wr_i;

  //assign we[1] = we1_i;
  //assign addrWr[1] = wrAddr1_i;
  //assign dataWr[1] = wrData1_i;
  

  /* Read operation */
  assign tag[0]       = tag0_i;
  assign vect0_o      = vect[0];
  

  localparam NUM_RD_PORTS = 1;
  localparam NUM_WR_PORTS = 1; 
  localparam NUM_PARTS = `STRUCT_PARTS_LSQ;
  localparam NUM_PARTS_LOG = `STRUCT_PARTS_LSQ_LOG;
  

  // Each partition matches ony 1/4th the number of entries
  wire [NUM_RD_PORTS-1:0][(DEPTH/NUM_PARTS)-1:0]  vectPartition[NUM_PARTS-1:0];
  wire [NUM_WR_PORTS-1:0][INDEX-NUM_PARTS_LOG-1:0]  addrWrPartition;
  wire [NUM_WR_PORTS-1:0][INDEX-NUM_PARTS_LOG-1:0]  addrWrPartSelect;
  wire [NUM_PARTS-1:0]  ramReady;


  genvar wp;
  genvar wp1;
  genvar part;
  generate
    for(wp = 0; wp < NUM_WR_PORTS; wp++)
    begin
      assign addrWrPartition[wp]   = addrWr[wp][INDEX-NUM_PARTS_LOG-1:0];
      assign addrWrPartSelect[wp]  = addrWr[wp][INDEX-1:INDEX-NUM_PARTS_LOG];
    end

    for(part = 0; part < NUM_PARTS; part++)//For every dispatch lane read port pair
    begin:INST_LOOP
      wire [NUM_WR_PORTS-1:0] writeEnPartition;
      for(wp1 = 0; wp1 < NUM_WR_PORTS; wp1++)//For every dispatch lane write port
      begin
        assign writeEnPartition[wp1]  = we[wp1] & (addrWrPartSelect[wp1] == part);
      end


      STQ_CAM #(
        .RPORT      (RPORT),
        .WPORT      (WPORT),
        .DEPTH      (DEPTH/NUM_PARTS),
        .INDEX      (INDEX-NUM_PARTS_LOG),
        .WIDTH      (WIDTH)
      )
      
      cam_inst (
      
          .tag0_i      (tag[0]),
          .vect0_o     (vectPartition[part][0]),
      
          .addr0wr_i   (addrWrPartition[0]),
          .data0wr_i   (dataWr[0]),
          .we0_i       (writeEnPartition[0]),
      
          //`ifdef DYNAMIC_CONFIG    
          //    .lsqPartitionActive_i  (lsqPartitionActive_i),
          //`endif    
      
          .clk         (clk)
          //.reset       (reset | recoverFlag_i)
      );
      

    end //for INSTANCE_LOOP
  endgenerate

  /* RAM reset state machine */
  //TODO: To be used in future if requred
  //assign ramReady_o = &ramReady;


  /* Read operation */
  always_comb 
  begin
    int rp;
    int prt;
    for(rp = 0; rp< NUM_RD_PORTS; rp++)
    begin
      for(prt = 0; prt<NUM_PARTS;prt++)
      begin
        vect[rp][prt*(DEPTH/NUM_PARTS)+:(DEPTH/NUM_PARTS)] = vectPartition[prt][rp];
      end
    end
  end


endmodule


