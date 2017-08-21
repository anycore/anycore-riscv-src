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

module WAKEUP_CAM_PARTITIONED #(
	/* Parameters */
  parameter RPORT = `ISSUE_WIDTH,
  parameter WPORT = `DISPATCH_WIDTH,
	parameter DEPTH = 16,
	parameter INDEX = 4,
	parameter WIDTH = 8
	) (

	input      [WIDTH-1:0]                tag0_i,
	output reg [DEPTH-1:0]                vect0_o,
	
`ifdef ISSUE_TWO_WIDE
	input      [WIDTH-1:0]                tag1_i,
	output reg [DEPTH-1:0]                vect1_o,
`endif

`ifdef ISSUE_THREE_WIDE
	input      [WIDTH-1:0]                tag2_i,
	output reg [DEPTH-1:0]                vect2_o,
`endif

`ifdef ISSUE_FOUR_WIDE
	input      [WIDTH-1:0]                tag3_i,
	output reg [DEPTH-1:0]                vect3_o,
`endif

`ifdef ISSUE_FIVE_WIDE
	input      [WIDTH-1:0]                tag4_i,
	output reg [DEPTH-1:0]                vect4_o,
`endif

`ifdef ISSUE_SIX_WIDE
	input      [WIDTH-1:0]                tag5_i,
	output reg [DEPTH-1:0]                vect5_o,
`endif

`ifdef ISSUE_SEVEN_WIDE
	input      [WIDTH-1:0]                tag6_i,
	output reg [DEPTH-1:0]                vect6_o,
`endif

`ifdef ISSUE_EIGHT_WIDE
	input      [WIDTH-1:0]                tag7_i,
	output reg [DEPTH-1:0]                vect7_o,
`endif


	input      [INDEX-1:0]                addr0wr_i,
	input      [WIDTH-1:0]                data0wr_i,
	input                                 we0_i,

`ifdef DISPATCH_TWO_WIDE
	input      [INDEX-1:0]                addr1wr_i,
	input      [WIDTH-1:0]                data1wr_i,
	input                                 we1_i,
`endif

`ifdef DISPATCH_THREE_WIDE
	input      [INDEX-1:0]                addr2wr_i,
	input      [WIDTH-1:0]                data2wr_i,
	input                                 we2_i,
`endif

`ifdef DISPATCH_FOUR_WIDE
	input      [INDEX-1:0]                addr3wr_i,
	input      [WIDTH-1:0]                data3wr_i,
	input                                 we3_i,
`endif

`ifdef DISPATCH_FIVE_WIDE
	input      [INDEX-1:0]                addr4wr_i,
	input      [WIDTH-1:0]                data4wr_i,
	input                                 we4_i,
`endif

`ifdef DISPATCH_SIX_WIDE
	input      [INDEX-1:0]                addr5wr_i,
	input      [WIDTH-1:0]                data5wr_i,
	input                                 we5_i,
`endif

`ifdef DISPATCH_SEVEN_WIDE
	input      [INDEX-1:0]                addr6wr_i,
	input      [WIDTH-1:0]                data6wr_i,
	input                                 we6_i,
`endif

`ifdef DISPATCH_EIGHT_WIDE
	input      [INDEX-1:0]                addr7wr_i,
	input      [WIDTH-1:0]                data7wr_i,
	input                                 we7_i,
`endif

  input [`DISPATCH_WIDTH-1:0]           dispatchLaneActive_i,
  input [`ISSUE_WIDTH-1:0]              issueLaneActive_i,
  input [`NUM_PARTS_IQ-1:0]             iqPartitionActive_i,
  output                                iqCamReady_o,

	//input                                 reset,
	input                                 clk
);



  logic [`DISPATCH_WIDTH-1:0]              we;
  logic [`DISPATCH_WIDTH-1:0][INDEX-1:0]   addrWr;
  logic [`DISPATCH_WIDTH-1:0][WIDTH-1:0]   dataWr;

  logic [`ISSUE_WIDTH-1:0][WIDTH-1:0]      tag;
  logic [`ISSUE_WIDTH-1:0][DEPTH-1:0]      vect;

  logic [`DISPATCH_WIDTH-1:0]              writePortGated;
  logic [`ISSUE_WIDTH-1:0]                 readPortGated;
  logic [`NUM_PARTS_IQ-1:0]                partitionGated; 

  assign writePortGated   = ~dispatchLaneActive_i;
  assign readPortGated    = ~issueLaneActive_i;
  assign partitionGated   = ~iqPartitionActive_i;


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
    assign tag[0]       = tag0_i;
    assign vect0_o      = vect[0];
  
  `ifdef ISSUE_TWO_WIDE
    assign tag[1]       = tag1_i;
    assign vect1_o      = vect[1];
  `endif

  `ifdef ISSUE_THREE_WIDE
    assign tag[2]       = tag2_i;
    assign vect2_o      = vect[2];
  `endif

  `ifdef ISSUE_FOUR_WIDE
    assign tag[3]       = tag3_i;
    assign vect3_o      = vect[3];
  `endif

  `ifdef ISSUE_FIVE_WIDE
    assign tag[4]       = tag4_i;
    assign vect4_o      = vect[4];
  `endif

  `ifdef ISSUE_SIX_WIDE
    assign tag[5]       = tag5_i;
    assign vect5_o      = vect[5];
  `endif

  `ifdef ISSUE_SEVEN_WIDE
    assign tag[6]       = tag6_i;
    assign vect6_o      = vect[6];
  `endif

  `ifdef ISSUE_EIGHT_WIDE
    assign tag[7]       = tag7_i;
    assign vect7_o      = vect[7];
  `endif



  localparam NUM_RD_PORTS = `ISSUE_WIDTH;
  localparam NUM_WR_PORTS = `DISPATCH_WIDTH; 
  localparam NUM_PARTS = `NUM_PARTS_IQ;
  localparam NUM_PARTS_LOG = `NUM_PARTS_IQ_LOG;


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


      WAKEUP_CAM #(
        .RPORT      (RPORT),
        .WPORT      (WPORT),
        .DEPTH      (DEPTH/NUM_PARTS),
        .INDEX      (INDEX-NUM_PARTS_LOG),
        .WIDTH      (WIDTH)
      )
      
      cam_inst (
      
          .tag0_i      (tag[0]),
          .vect0_o     (vectPartition[part][0]),
      
        `ifdef ISSUE_TWO_WIDE
          .tag1_i      (tag[1]),
          .vect1_o     (vectPartition[part][1]),
        `endif

        `ifdef ISSUE_THREE_WIDE
          .tag2_i      (tag[2]),
          .vect2_o     (vectPartition[part][2]),
        `endif

        `ifdef ISSUE_FOUR_WIDE
          .tag3_i      (tag[3]),
          .vect3_o     (vectPartition[part][3]),
        `endif

        `ifdef ISSUE_FIVE_WIDE
          .tag4_i      (tag[4]),
          .vect4_o     (vectPartition[part][4]),
        `endif

        `ifdef ISSUE_SIX_WIDE
          .tag5_i      (tag[5]),
          .vect5_o     (vectPartition[part][5]),
        `endif

        `ifdef ISSUE_SEVEN_WIDE
          .tag6_i      (tag[6]),
          .vect6_o     (vectPartition[part][6]),
        `endif

        `ifdef ISSUE_EIGHT_WIDE
          .tag7_i      (tag[7]),
          .vect7_o     (vectPartition[part][7]),
        `endif

          .addr0wr_i   (addrWrPartition[0]),
          .data0wr_i   (dataWr[0]),
          .we0_i       (writeEnPartition[0]),
      
        `ifdef DISPATCH_TWO_WIDE
          .addr1wr_i   (addrWrPartition[1]),
          .data1wr_i   (dataWr[1]),
          .we1_i       (writeEnPartition[1]),
        `endif
      
        `ifdef DISPATCH_THREE_WIDE
          .addr2wr_i   (addrWrPartition[2]),
          .data2wr_i   (dataWr[2]),
          .we2_i       (writeEnPartition[2]),
        `endif
      
        `ifdef DISPATCH_FOUR_WIDE
          .addr3wr_i   (addrWrPartition[3]),
          .data3wr_i   (dataWr[3]),
          .we3_i       (writeEnPartition[3]),
        `endif
      
        `ifdef DISPATCH_FIVE_WIDE
          .addr4wr_i   (addrWrPartition[4]),
          .data4wr_i   (dataWr[4]),
          .we4_i       (writeEnPartition[4]),
        `endif
      
        `ifdef DISPATCH_SIX_WIDE
          .addr5wr_i   (addrWrPartition[5]),
          .data5wr_i   (dataWr[5]),
          .we5_i       (writeEnPartition[5]),
        `endif
      
        `ifdef DISPATCH_SEVEN_WIDE
          .addr6wr_i   (addrWrPartition[6]),
          .data6wr_i   (dataWr[6]),
          .we6_i       (writeEnPartition[6]),
        `endif
      
        `ifdef DISPATCH_EIGHT_WIDE
          .addr7wr_i   (addrWrPartition[7]),
          .data7wr_i   (dataWr[7]),
          .we7_i       (writeEnPartition[7]),
        `endif
      
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


