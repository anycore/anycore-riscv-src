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

module PRF_RAM_PARTITIONED #(
	/* Parameters */
  parameter RPORT = (2*`ISSUE_WIDTH),
  parameter WPORT = `ISSUE_WIDTH,
	parameter DEPTH = `RAM_CONFIG_DEPTH, 
	parameter INDEX = `RAM_CONFIG_INDEX, 
	parameter WIDTH = `RAM_CONFIG_WIDTH 
) (

	input  [INDEX-1:0]            addr0_i,
	output [WIDTH-1:0]            data0_o,
	                              
	input  [INDEX-1:0]            addr1_i,
	output [WIDTH-1:0]            data1_o,

	input  [INDEX-1:0]            addr0wr_i,
	input  [WIDTH-1:0]            data0wr_i,
	input                         we0_i,
                                
	                              
`ifdef ISSUE_TWO_WIDE   
	input  [INDEX-1:0]            addr2_i,
	output [WIDTH-1:0]            data2_o,
	                              
	input  [INDEX-1:0]            addr3_i,
	output [WIDTH-1:0]            data3_o,

	input  [INDEX-1:0]            addr1wr_i,
	input  [WIDTH-1:0]            data1wr_i,
	input                         we1_i,
`endif                          
	                              
`ifdef ISSUE_THREE_WIDE   
	input  [INDEX-1:0]            addr4_i,
	output [WIDTH-1:0]            data4_o,

	input  [INDEX-1:0]            addr5_i,
	output [WIDTH-1:0]            data5_o,

	input  [INDEX-1:0]            addr2wr_i,
	input  [WIDTH-1:0]            data2wr_i,
	input                         we2_i,
`endif                          
	                              
`ifdef ISSUE_FOUR_WIDE   
	input  [INDEX-1:0]            addr6_i,
	output [WIDTH-1:0]            data6_o,

	input  [INDEX-1:0]            addr7_i,
	output [WIDTH-1:0]            data7_o,

	input  [INDEX-1:0]            addr3wr_i,
	input  [WIDTH-1:0]            data3wr_i,
	input                         we3_i,
`endif                          
	                              
`ifdef ISSUE_FIVE_WIDE   
	input  [INDEX-1:0]            addr8_i,
	output [WIDTH-1:0]            data8_o,

	input  [INDEX-1:0]            addr9_i,
	output [WIDTH-1:0]            data9_o,

	input  [INDEX-1:0]            addr4wr_i,
	input  [WIDTH-1:0]            data4wr_i,
	input                         we4_i,
`endif                          
	                              
`ifdef ISSUE_SIX_WIDE   
	input  [INDEX-1:0]            addr10_i,
	output [WIDTH-1:0]            data10_o,

	input  [INDEX-1:0]            addr11_i,
	output [WIDTH-1:0]            data11_o,

	input  [INDEX-1:0]            addr5wr_i,
	input  [WIDTH-1:0]            data5wr_i,
	input                         we5_i,
`endif                          
	                              
`ifdef ISSUE_SEVEN_WIDE   
	input  [INDEX-1:0]            addr12_i,
	output [WIDTH-1:0]            data12_o,

	input  [INDEX-1:0]            addr13_i,
	output [WIDTH-1:0]            data13_o,

	input  [INDEX-1:0]            addr6wr_i,
	input  [WIDTH-1:0]            data6wr_i,
	input                         we6_i,
`endif                          
	                              
`ifdef ISSUE_EIGHT_WIDE   
	input  [INDEX-1:0]            addr14_i,
	output [WIDTH-1:0]            data14_o,

	input  [INDEX-1:0]            addr15_i,
	output [WIDTH-1:0]            data15_o,

	input  [INDEX-1:0]            addr7wr_i,
	input  [WIDTH-1:0]            data7wr_i,
	input                         we7_i,
`endif                     
                           
  input [`ISSUE_WIDTH-1:0]      execLaneActive_i,
  input [`NUM_PARTS_RF-1:0]     rfPartitionActive_i,

	//input                    reset,
	input                         clk
);


  logic [`ISSUE_WIDTH-1:0]                we;
  logic [`ISSUE_WIDTH-1:0][INDEX-1:0]     addrWr;
  logic [`ISSUE_WIDTH-1:0][WIDTH-1:0]     dataWr;

  logic [2*`ISSUE_WIDTH-1:0][INDEX-1:0]   addr;
  logic [2*`ISSUE_WIDTH-1:0][WIDTH-1:0]   rdData;

  logic [`ISSUE_WIDTH-1:0]                writePortGated;
  logic [2*`ISSUE_WIDTH-1:0]              readPortGated;
  logic [`NUM_PARTS_RF-1:0]               partitionGated;

  assign writePortGated   = ~execLaneActive_i;
  always_comb
  begin
    int i;
    for(i = 0; i < 2*`ISSUE_WIDTH; i++)
    begin
      readPortGated[i*2+:2]    = {2{~execLaneActive_i[i]}};
    end
  end

  assign partitionGated   = ~rfPartitionActive_i;


    assign we[0] = we0_i;
    assign addrWr[0] = addr0wr_i;
    assign dataWr[0] = data0wr_i;

  `ifdef ISSUE_TWO_WIDE
    assign we[1] = we1_i;
    assign addrWr[1] = addr1wr_i;
    assign dataWr[1] = data1wr_i;
  `endif
  
  `ifdef ISSUE_THREE_WIDE
    assign we[2] = we2_i;
    assign addrWr[2] = addr2wr_i;
    assign dataWr[2] = data2wr_i;
  `endif
  
  `ifdef ISSUE_FOUR_WIDE
    assign we[3] = we3_i;
    assign addrWr[3] = addr3wr_i;
    assign dataWr[3] = data3wr_i;
  `endif

  `ifdef ISSUE_FIVE_WIDE
    assign we[4] = we4_i;
    assign addrWr[4] = addr4wr_i;
    assign dataWr[4] = data4wr_i;
  `endif

  `ifdef ISSUE_SIX_WIDE
    assign we[5] = we5_i;
    assign addrWr[5] = addr5wr_i;
    assign dataWr[5] = data5wr_i;
  `endif

  `ifdef ISSUE_SEVEN_WIDE
    assign we[6] = we6_i;
    assign addrWr[6] = addr6wr_i;
    assign dataWr[6] = data6wr_i;
  `endif

  `ifdef ISSUE_EIGHT_WIDE
    assign we[7] = we7_i;
    assign addrWr[7] = addr7wr_i;
    assign dataWr[7] = data7wr_i;
  `endif

  /* Read operation */
  assign addr[0]     = addr0_i;
  assign data0_o     = rdData[0];
  assign addr[1]     = addr1_i;
  assign data1_o     = rdData[1];
  
  `ifdef ISSUE_TWO_WIDE
  assign addr[2]     = addr2_i;
  assign data2_o     = rdData[2];
  assign addr[3]     = addr3_i;
  assign data3_o     = rdData[3];
  `endif
  
  `ifdef ISSUE_THREE_WIDE
  assign addr[4]     = addr4_i;
  assign data4_o     = rdData[4];
  assign addr[5]     = addr5_i;
  assign data5_o     = rdData[5];
  `endif
  
  `ifdef ISSUE_FOUR_WIDE
  assign addr[6]     = addr6_i;
  assign data6_o     = rdData[6];
  assign addr[7]     = addr7_i;
  assign data7_o     = rdData[7];
  `endif
  
  `ifdef ISSUE_FIVE_WIDE
  assign addr[8]     = addr8_i;
  assign data8_o     = rdData[8];
  assign addr[9]     = addr9_i;
  assign data9_o     = rdData[9];
  `endif
  
  `ifdef ISSUE_SIX_WIDE
  assign addr[10]    = addr10_i;
  assign data10_o    = rdData[10];
  assign addr[11]    = addr11_i;
  assign data11_o    = rdData[11];
  `endif
  
  `ifdef ISSUE_SEVEN_WIDE
  assign addr[12]    = addr12_i;
  assign data12_o    = rdData[12];
  assign addr[13]    = addr13_i;
  assign data13_o    = rdData[13];
  `endif
  
  `ifdef ISSUE_EIGHT_WIDE
  assign addr[14]    = addr14_i;
  assign data14_o    = rdData[14];
  assign addr[15]    = addr15_i;
  assign data15_o    = rdData[15];
  `endif
 
 

  localparam NUM_RD_PORTS = 2*`ISSUE_WIDTH;
  localparam NUM_WR_PORTS = `ISSUE_WIDTH; 
  localparam NUM_PARTS = `NUM_PARTS_RF;
  localparam NUM_PARTS_LOG = `NUM_PARTS_RF_LOG;



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

      PRF_RAM #(
        .RPORT      (RPORT),
        .WPORT      (WPORT),
      	.DEPTH      (DEPTH/NUM_PARTS),
      	.INDEX      (INDEX-NUM_PARTS_LOG),
      	.WIDTH      (WIDTH)
      	)
      
      	ram_inst   (
      	
      	.addr0_i       (addrPartition[0]),
      	.data0_o       (rdDataPartition[part][0]),
      
      	.addr1_i       (addrPartition[1]),
      	.data1_o       (rdDataPartition[part][1]),
      
      	.addr0wr_i     (addrWrPartition[0]), 
      	.data0wr_i     (dataWr[0]),
      	.we0_i         (writeEnPartition[0]),
      
      
      `ifdef ISSUE_TWO_WIDE
      	.addr2_i       (addrPartition[2]),
      	.data2_o       (rdDataPartition[part][2]),
      
      	.addr3_i       (addrPartition[3]),
      	.data3_o       (rdDataPartition[part][3]),
      
      	.addr1wr_i     (addrWrPartition[1]),
      	.data1wr_i     (dataWr[1]),
      	.we1_i         (writeEnPartition[1]),
      `endif
      
      
      `ifdef ISSUE_THREE_WIDE
      	.addr4_i       (addrPartition[4]),
      	.data4_o       (rdDataPartition[part][4]),
      
      	.addr5_i       (addrPartition[5]),
      	.data5_o       (rdDataPartition[part][5]),
      
      	.addr2wr_i     (addrWrPartition[2]),
      	.data2wr_i     (dataWr[2]),
      	.we2_i         (writeEnPartition[2]),
      `endif
      
      
      `ifdef ISSUE_FOUR_WIDE
      	.addr6_i       (addrPartition[6]),
      	.data6_o       (rdDataPartition[part][6]),
      
      	.addr7_i       (addrPartition[7]),
      	.data7_o       (rdDataPartition[part][7]),
      
      	.addr3wr_i     (addrWrPartition[3]),
      	.data3wr_i     (dataWr[3]),
      	.we3_i         (writeEnPartition[3]),
      `endif
      
      `ifdef ISSUE_FIVE_WIDE
      	.addr8_i       (addrPartition[8]),
      	.data8_o       (rdDataPartition[part][8]),
      
      	.addr9_i       (addrPartition[9]),
      	.data9_o       (rdDataPartition[part][9]),
      
      	.addr4wr_i     (addrWrPartition[4]),
      	.data4wr_i     (dataWr[4]),
      	.we4_i         (writeEnPartition[4]),
      `endif
      
      `ifdef ISSUE_SIX_WIDE
      	.addr10_i      (addrPartition[10]),
      	.data10_o      (rdDataPartition[part][10]),
      
      	.addr11_i      (addrPartition[11]),
      	.data11_o      (rdDataPartition[part][11]),
      
      	.addr5wr_i     (addrWrPartition[5]),
      	.data5wr_i     (dataWr[5]),
      	.we5_i         (writeEnPartition[5]),
      `endif
      
      `ifdef ISSUE_SEVEN_WIDE
      	.addr12_i      (addrPartition[12]),
      	.data12_o      (rdDataPartition[part][12]),
      
      	.addr13_i      (addrPartition[13]),
      	.data13_o      (rdDataPartition[part][13]),
      
      	.addr6wr_i     (addrWrPartition[6]),
      	.data6wr_i     (dataWr[6]),
      	.we6_i         (writeEnPartition[6]),
      `endif
      
      `ifdef ISSUE_EIGHT_WIDE
      	.addr14_i      (addrPartition[14]),
      	.data14_o      (rdDataPartition[part][14]),
      
      	.addr15_i      (addrPartition[15]),
      	.data15_o      (rdDataPartition[part][15]),
      
      	.addr7wr_i     (addrWrPartition[7]),
      	.data7wr_i     (dataWr[7]),
      	.we7_i         (writeEnPartition[7]),
      `endif
      
      //`ifdef DYNAMIC_CONFIG
      //  .execLaneActive_i   (execLaneActive_i),
      //  .rfPartitionActive_i(rfPartitionActive_i),
      //`endif
             
      `ifdef PRF_DEBUG_PORT
        .debugPRFRdAddr_i  (debugPRFAddr_shifted),
        .debugPRFRdData_o  (debugPRFRdData_byte5),
        .debugPRFWrData_i  (debugPRFWrData_i),
        .debugPRFWrEn_i    (debugPRFWrEn_byte5),
      `endif //PRF_DEBUG_PORT
      	
      	.clk               (clk)
      	//.reset             (reset && ~dbWe_i)
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

