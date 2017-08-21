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

module STQ_FOLLOWINGLD_RAM_PARTITIONED #(
	/* Parameters */
  parameter RPORT = 1,
  parameter WPORT = `DISPATCH_WIDTH,
	parameter DEPTH = `RAM_CONFIG_DEPTH, 
	parameter INDEX = `RAM_CONFIG_INDEX, 
	parameter WIDTH = `RAM_CONFIG_WIDTH 
) (

	input  [INDEX-1:0]                addr0_i,
	output [WIDTH-1:0]                data0_o,

	input  [INDEX-1:0]                addr0wr_i,
	input  [WIDTH-1:0]                data0wr_i,
	input                             we0_i,

`ifdef DISPATCH_TWO_WIDE
	input  [INDEX-1:0]                addr1wr_i,
	input  [WIDTH-1:0]                data1wr_i,
	input                             we1_i,
`endif

`ifdef DISPATCH_THREE_WIDE
	input  [INDEX-1:0]                addr2wr_i,
	input  [WIDTH-1:0]                data2wr_i,
	input                             we2_i,
`endif

`ifdef DISPATCH_FOUR_WIDE
	input  [INDEX-1:0]                addr3wr_i,
	input  [WIDTH-1:0]                data3wr_i,
	input                             we3_i,
`endif

`ifdef DISPATCH_FIVE_WIDE
	input  [INDEX-1:0]                addr4wr_i,
	input  [WIDTH-1:0]                data4wr_i,
	input                             we4_i,
`endif

`ifdef DISPATCH_SIX_WIDE
	input  [INDEX-1:0]                addr5wr_i,
	input  [WIDTH-1:0]                data5wr_i,
	input                             we5_i,
`endif

`ifdef DISPATCH_SEVEN_WIDE
	input  [INDEX-1:0]                addr6wr_i,
	input  [WIDTH-1:0]                data6wr_i,
	input                             we6_i,
`endif

`ifdef DISPATCH_EIGHT_WIDE
	input  [INDEX-1:0]                addr7wr_i,
	input  [WIDTH-1:0]                data7wr_i,
	input                             we7_i,
`endif

  input  [`DISPATCH_WIDTH-1:0]      dispatchLaneActive_i,
  input  [`COMMIT_WIDTH-1:0]        commitLaneActive_i,
  input  [`STRUCT_PARTS_LSQ-1:0]    lsqPartitionActive_i,
  output                            ldqRamReady_o,

	//input                             reset,
	input                             clk
);


  logic [`DISPATCH_WIDTH-1:0]              we;
  logic [`DISPATCH_WIDTH-1:0][INDEX-1:0]   addrWr;
  logic [`DISPATCH_WIDTH-1:0][WIDTH-1:0]   dataWr;

  logic [0:0]                [INDEX-1:0]   addr;
  logic [0:0]                [WIDTH-1:0]   rdData;

  logic [`DISPATCH_WIDTH-1:0]              writePortGated;
  logic                                    readPortGated;
  logic [`STRUCT_PARTS_LSQ-1:0]            partitionGated; 

  assign writePortGated   = ~dispatchLaneActive_i;
  assign readPortGated    = 1'b0;
  assign partitionGated   = ~lsqPartitionActive_i;


    assign we[0] = we0_i;
    assign addrWr[0] = addr0wr_i;
    assign dataWr[0] = data0wr_i;

  `ifdef DISPATCH_TWO_WIDE
    assign we[1] = we1_i;
    assign addrWr[1] = addr1wr_i;
    assign dataWr[1] = data1wr_i;
  `endif
  
  `ifdef DISPATCH_THREE_WIDE
    assign we[2] = we2_i;
    assign addrWr[2] = addr2wr_i;
    assign dataWr[2] = data2wr_i;
  `endif
  
  `ifdef DISPATCH_FOUR_WIDE
    assign we[3] = we3_i;
    assign addrWr[3] = addr3wr_i;
    assign dataWr[3] = data3wr_i;
  `endif

  `ifdef DISPATCH_FIVE_WIDE
    assign we[4] = we4_i;
    assign addrWr[4] = addr4wr_i;
    assign dataWr[4] = data4wr_i;
  `endif

  `ifdef DISPATCH_SIX_WIDE
    assign we[5] = we5_i;
    assign addrWr[5] = addr5wr_i;
    assign dataWr[5] = data5wr_i;
  `endif

  `ifdef DISPATCH_SEVEN_WIDE
    assign we[6] = we6_i;
    assign addrWr[6] = addr6wr_i;
    assign dataWr[6] = data6wr_i;
  `endif

  `ifdef DISPATCH_EIGHT_WIDE
    assign we[7] = we7_i;
    assign addrWr[7] = addr7wr_i;
    assign dataWr[7] = data7wr_i;
  `endif

  /* Read operation */
  assign addr[0]     = addr0_i;
  assign data0_o     = rdData[0];


  localparam NUM_RD_PORTS = 1;
  localparam NUM_WR_PORTS = `DISPATCH_WIDTH; 
  localparam NUM_PARTS = `STRUCT_PARTS_LSQ;
  localparam NUM_PARTS_LOG = `STRUCT_PARTS_LSQ_LOG;



  wire [NUM_RD_PORTS-1:0][WIDTH-1:0] rdDataPartition[NUM_PARTS-1:0];
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
      if(NUM_PARTS == 1)
      begin
        assign addrPartition[rp]   = addr[rp];
        assign addrPartSelect[rp]  = 1'b0;
      end
      else
      begin
        assign addrPartition[rp]   = addr[rp][INDEX-NUM_PARTS_LOG-1:0];
        assign addrPartSelect[rp]  = addr[rp][INDEX-1:INDEX-NUM_PARTS_LOG];
      end
    end

    for(wp = 0; wp < NUM_WR_PORTS; wp++)
    begin
      if(NUM_PARTS == 1)
      begin
        assign addrWrPartition[wp]   = addrWr[wp];
        assign addrWrPartSelect[wp]  = 1'b0;
      end
      else
      begin
        assign addrWrPartition[wp]   = addrWr[wp][INDEX-NUM_PARTS_LOG-1:0];
        assign addrWrPartSelect[wp]  = addrWr[wp][INDEX-1:INDEX-NUM_PARTS_LOG];
      end
    end

    for(part = 0; part < NUM_PARTS; part++)//For every dispatch lane read port pair
    begin:INST_LOOP
      wire [NUM_WR_PORTS-1:0] writeEnPartition;
      for(wp1 = 0; wp1 < NUM_WR_PORTS; wp1++)//For every dispatch lane write port
      begin
        assign writeEnPartition[wp1]  = (~writePortGated[wp1]) & we[wp1] & |(addrWrPartSelect[wp1] == part);
//        assign writeEnPartition[wp1]  = we[wp1] & |(addrWrPartSelect[wp1] == part);
      end

      STQ_FOLLOWINGLD_RAM  #(
        .RPORT      (RPORT),
        .WPORT      (WPORT),
      	.DEPTH      (DEPTH/NUM_PARTS),
      	.INDEX      (INDEX-NUM_PARTS_LOG),
      	.WIDTH      (WIDTH)
       	)
      
      	ram_inst (
      
      	.addr0_i    (addrPartition[0]),
      	.data0_o    (rdDataPartition[part][0]),
      
      
      	.addr0wr_i  (addrWrPartition[0]),
      	.we0_i      (writeEnPartition[0]),
      	.data0wr_i  (dataWr[0]),
      
      `ifdef DISPATCH_TWO_WIDE
      	.addr1wr_i  (addrWrPartition[1]),
      	.we1_i      (writeEnPartition[1]),
      	.data1wr_i  (dataWr[1]),
      `endif
      
      `ifdef DISPATCH_THREE_WIDE
      	.addr2wr_i  (addrWrPartition[2]),
      	.we2_i      (writeEnPartition[2]),
      	.data2wr_i  (dataWr[2]),
      `endif
      
      `ifdef DISPATCH_FOUR_WIDE
      	.addr3wr_i  (addrWrPartition[3]),
      	.we3_i      (writeEnPartition[3]),
      	.data3wr_i  (dataWr[3]),
      `endif
      
      `ifdef DISPATCH_FIVE_WIDE
      	.addr4wr_i  (addrWrPartition[4]),
      	.we4_i      (writeEnPartition[4]),
      	.data4wr_i  (dataWr[4]),
      `endif
      
      `ifdef DISPATCH_SIX_WIDE
      	.addr5wr_i  (addrWrPartition[5]),
      	.we5_i      (writeEnPartition[5]),
      	.data5wr_i  (dataWr[5]),
      `endif
      
      `ifdef DISPATCH_SEVEN_WIDE
      	.addr6wr_i  (addrWrPartition[6]),
      	.we6_i      (writeEnPartition[6]),
      	.data6wr_i  (dataWr[6]),
      `endif
      
      `ifdef DISPATCH_EIGHT_WIDE
      	.addr7wr_i  (addrWrPartition[7]),
      	.we7_i      (writeEnPartition[7]),
      	.data7wr_i  (dataWr[7]),
      `endif
      
      //`ifdef DYNAMIC_CONFIG
      //  .issueLaneActive_i(issueLaneActive_i),
      //  .commitLaneActive_i(commitLaneActive_i),
      //  .alPartitionActive_i(alPartitionActive_i),
      //  .alCtrlReady_o(alCtrlReady),
      //`endif
      
      	//.reset      (reset),
      	.clk        (clk)
      
    	);

    end //for INSTANCE_LOOP
  endgenerate

  /* Read operation */
  always @(*) 
  begin
    int rp;
    for(rp = 0; rp< NUM_RD_PORTS; rp++)
    begin
      rdData[rp] = rdDataPartition[addrPartSelect[rp]][rp];
    end
  end

endmodule

