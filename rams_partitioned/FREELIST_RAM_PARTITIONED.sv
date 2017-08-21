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

module FREELIST_RAM_PARTITIONED #(
	/* Parameters */
  parameter RPORT = `DISPATCH_WIDTH,
  parameter WPORT = `COMMIT_WIDTH,
	parameter DEPTH = `RAM_CONFIG_DEPTH, 
	parameter INDEX = `RAM_CONFIG_INDEX, 
	parameter WIDTH = `RAM_CONFIG_WIDTH 
) (

	input  [INDEX-1:0]            addr0_i,
	output [WIDTH-1:0]            data0_o,

`ifdef DISPATCH_TWO_WIDE
	input  [INDEX-1:0]            addr1_i,
	output [WIDTH-1:0]            data1_o,
`endif

`ifdef DISPATCH_THREE_WIDE
	input  [INDEX-1:0]            addr2_i,
	output [WIDTH-1:0]            data2_o,
`endif

`ifdef DISPATCH_FOUR_WIDE
	input  [INDEX-1:0]            addr3_i,
	output [WIDTH-1:0]            data3_o,
`endif

`ifdef DISPATCH_FIVE_WIDE
	input  [INDEX-1:0]            addr4_i,
	output [WIDTH-1:0]            data4_o,
`endif

`ifdef DISPATCH_SIX_WIDE
	input  [INDEX-1:0]            addr5_i,
	output [WIDTH-1:0]            data5_o,
`endif

`ifdef DISPATCH_SEVEN_WIDE
	input  [INDEX-1:0]            addr6_i,
	output [WIDTH-1:0]            data6_o,
`endif

`ifdef DISPATCH_EIGHT_WIDE
	input  [INDEX-1:0]            addr7_i,
	output [WIDTH-1:0]            data7_o,
`endif


	input  [INDEX-1:0]            addr0wr_i,
	input  [WIDTH-1:0]            data0wr_i,
	input                         we0_i,

`ifdef COMMIT_TWO_WIDE
	input  [INDEX-1:0]            addr1wr_i,
	input  [WIDTH-1:0]            data1wr_i,
	input                         we1_i,
`endif

`ifdef COMMIT_THREE_WIDE
	input  [INDEX-1:0]            addr2wr_i,
	input  [WIDTH-1:0]            data2wr_i,
	input                         we2_i,
`endif

`ifdef COMMIT_FOUR_WIDE
	input  [INDEX-1:0]            addr3wr_i,
	input  [WIDTH-1:0]            data3wr_i,
	input                         we3_i,
`endif

  input [`COMMIT_WIDTH-1:0]     commitLaneActive_i,
  input [`DISPATCH_WIDTH-1:0]   dispatchLaneActive_i,
  input [`NUM_PARTS_FL-1:0]     flPartitionActive_i,
//  output                        freeListReady_o,

	//input                         reset,
	input                         clk

);


  logic [`COMMIT_WIDTH-1:0]                we;
  logic [`COMMIT_WIDTH-1:0][INDEX-1:0]     addrWr;
  logic [`COMMIT_WIDTH-1:0][WIDTH-1:0]     dataWr;

  logic [`DISPATCH_WIDTH-1:0][INDEX-1:0]   addr;
  logic [`DISPATCH_WIDTH-1:0][WIDTH-1:0]   rdData;

  logic [`COMMIT_WIDTH-1:0]                writePortGated;
  logic [`DISPATCH_WIDTH-1:0]              readPortGated;
  logic [`NUM_PARTS_FL-1:0]          partitionGated;

  assign writePortGated   = ~commitLaneActive_i;
  assign readPortGated    = ~dispatchLaneActive_i;
  assign partitionGated   = ~flPartitionActive_i[`NUM_PARTS_FL-1:1]; // This depends on the number of RF partitions needed for architectural regs


    assign we[0] = we0_i;
    assign addrWr[0] = addr0wr_i;
    assign dataWr[0] = data0wr_i;

  `ifdef COMMIT_TWO_WIDE
    assign we[1] = we1_i;
    assign addrWr[1] = addr1wr_i;
    assign dataWr[1] = data1wr_i;
  `endif
  
  `ifdef COMMIT_THREE_WIDE
    assign we[2] = we2_i;
    assign addrWr[2] = addr2wr_i;
    assign dataWr[2] = data2wr_i;
  `endif
  
  `ifdef COMMIT_FOUR_WIDE
    assign we[3] = we3_i;
    assign addrWr[3] = addr3wr_i;
    assign dataWr[3] = data3wr_i;
  `endif
  

  /* Read operation */
  assign addr[0]     = addr0_i;
  assign data0_o     = rdData[0];
  
  `ifdef DISPATCH_TWO_WIDE
  assign addr[1]     = addr1_i;
  assign data1_o     = rdData[1];
  `endif
  
  `ifdef DISPATCH_THREE_WIDE
  assign addr[2]     = addr2_i;
  assign data2_o     = rdData[2];
  `endif
  
  `ifdef DISPATCH_FOUR_WIDE
  assign addr[3]     = addr3_i;
  assign data3_o     = rdData[3];
  `endif
  
  `ifdef DISPATCH_FIVE_WIDE
  assign addr[4]     = addr4_i;
  assign data4_o     = rdData[4];
  `endif
  
  `ifdef DISPATCH_SIX_WIDE
  assign addr[5]     = addr5_i;
  assign data5_o     = rdData[5];
  `endif
  
  `ifdef DISPATCH_SEVEN_WIDE
  assign addr[6]     = addr6_i;
  assign data6_o     = rdData[6];
  `endif
  
  `ifdef DISPATCH_EIGHT_WIDE
  assign addr[7]     = addr7_i;
  assign data7_o     = rdData[7];
  `endif

  localparam NUM_RD_PORTS = `DISPATCH_WIDTH;
  localparam NUM_WR_PORTS = `COMMIT_WIDTH; 
  localparam NUM_PARTS = `NUM_PARTS_FL;
  localparam NUM_PARTS_LOG = `NUM_PARTS_FL_LOG;

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

      FREELIST_RAM #(
        .RPORT      (RPORT),
        .WPORT      (WPORT),
      	.DEPTH      (DEPTH/NUM_PARTS),
      	.INDEX      (INDEX-NUM_PARTS_LOG),
      	.WIDTH      (WIDTH)
      	)
      
      	ram_inst (
      
      	.addr0_i    (addrPartition[0]),
      	.data0_o    (rdDataPartition[part][0]),
      
      `ifdef DISPATCH_TWO_WIDE
      	.addr1_i    (addrPartition[1]),
      	.data1_o    (rdDataPartition[part][1]),
      `endif
      
      `ifdef DISPATCH_THREE_WIDE
      	.addr2_i    (addrPartition[2]),
      	.data2_o    (rdDataPartition[part][2]),
      `endif
      
      `ifdef DISPATCH_FOUR_WIDE
      	.addr3_i    (addrPartition[3]),
      	.data3_o    (rdDataPartition[part][3]),
      `endif

      `ifdef DISPATCH_FIVE_WIDE
      	.addr4_i    (addrPartition[4]),
      	.data4_o    (rdDataPartition[part][4]),
      `endif
     
      `ifdef DISPATCH_SIX_WIDE
      	.addr5_i    (addrPartition[5]),
      	.data5_o    (rdDataPartition[part][5]),
      `endif
     
      `ifdef DISPATCH_SEVEN_WIDE
      	.addr6_i    (addrPartition[6]),
      	.data6_o    (rdDataPartition[part][6]),
      `endif
     
      `ifdef DISPATCH_EIGHT_WIDE
      	.addr7_i    (addrPartition[7]),
      	.data7_o    (rdDataPartition[part][7]),
      `endif
     
      
      	.addr0wr_i  (addrWrPartition[0]),
      	.we0_i      (writeEnPartition[0]),
      	.data0wr_i  (dataWr[0]),
      
      `ifdef COMMIT_TWO_WIDE
      	.addr1wr_i  (addrWrPartition[1]),
      	.we1_i      (writeEnPartition[1]),
      	.data1wr_i  (dataWr[1]),
      `endif
      
      `ifdef COMMIT_THREE_WIDE
      	.addr2wr_i  (addrWrPartition[2]),
      	.we2_i      (writeEnPartition[2]),
      	.data2wr_i  (dataWr[2]),
      `endif
      
      `ifdef COMMIT_FOUR_WIDE
      	.addr3wr_i  (addrWrPartition[3]),
      	.we3_i      (writeEnPartition[3]),
      	.data3wr_i  (dataWr[3]),
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

