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


module PhyRegFile (

	input                                 clk,
	input                                 reset,

`ifdef DYNAMIC_CONFIG  
  input [`ISSUE_WIDTH-1:0]              execLaneActive_i,
  input [`NUM_PARTS_RF-1:0]             rfPartitionActive_i,
`endif  

	/* INPUTS COMING FROM THE R-R STAGE */
	input [`SIZE_PHYSICAL_LOG-1:0]        phySrc1_i [0:`ISSUE_WIDTH-1],
	input [`SIZE_PHYSICAL_LOG-1:0]        phySrc2_i [0:`ISSUE_WIDTH-1],

	/* INPUTS COMING FROM THE WRITEBACK STAGE */
	input  bypassPkt                      bypassPacket_i [0:`ISSUE_WIDTH-1],

	/* OUTPUTS GOING TO THE R-R STAGE */
	output reg [`SIZE_DATA-1:0]           src1Data_o [0:`ISSUE_WIDTH-1],
	output reg [`SIZE_DATA-1:0]           src2Data_o [0:`ISSUE_WIDTH-1],
	
	input  [`SIZE_PHYSICAL_LOG+`SIZE_DATA_BYTE_OFFSET-1:0]       debugPRFAddr_i,
	input  [`SRAM_DATA_WIDTH-1:0]         debugPRFWrData_i,
	input                                 debugPRFWrEn_i,
	output [`SRAM_DATA_WIDTH-1:0]         debugPRFRdData_o
	);


reg  [`SIZE_PHYSICAL_LOG-1:0]         destAddr   [0:`ISSUE_WIDTH-1];
reg  [`SIZE_DATA-1:0]                 destData   [0:`ISSUE_WIDTH-1];
reg                                   destWe     [0:`ISSUE_WIDTH-1];

// TODO: Might be worthwhile to gate the per lane decoders
// This should be decided based upon the power numbers obtained
// from Prime Time. Dynamic power will be saved as the addresses
// are gated. 
always_comb
begin
	int i;
	for (i = 0; i < `ISSUE_WIDTH; i++)
	begin
		destAddr[i]         = bypassPacket_i[i].tag;
		destWe[i]           = bypassPacket_i[i].valid;
		destData[i]         = bypassPacket_i[i].data;
  end

end

// This is a debug port to read write PRF through the off chip debug interface
`ifdef PRF_DEBUG_PORT

  wire [`SRAM_DATA_WIDTH-1:0] debugPRFRdDataWord;
  reg  [`SRAM_DATA_WIDTH-1:0] debugPRFWrDataWord;
  wire [`SRAM_DATA_WIDTH-1:0] debugPRFWordAddr;
  wire [`SRAM_DATA_WIDTH-1:0] debugPRFWrEn;

  always_ff @(posedge clk)
  begin
    case(debugPRFAddr_i[`SIZE_DATA_BYTE_OFFSET+`SIZE_PHYSICAL_LOG-1-:3])
      3'b000: debugPRFWrDataWord[7:0]   <=  debugPRFWrData_i;
      3'b001: debugPRFWrDataWord[15:7]  <=  debugPRFWrData_i;
      3'b010: debugPRFWrDataWord[23:16] <=  debugPRFWrData_i;
      3'b011: debugPRFWrDataWord[31:24] <=  debugPRFWrData_i;
      3'b100: debugPRFWrDataWord[39:32] <=  debugPRFWrData_i;
      3'b101: debugPRFWrDataWord[47:40] <=  debugPRFWrData_i;
      3'b110: debugPRFWrDataWord[55:48] <=  debugPRFWrData_i;
      3'b111: debugPRFWrDataWord[63:56] <=  debugPRFWrData_i;
    endcase
  end

  always_comb
  begin
    case(debugPRFAddr_i[`SIZE_DATA_BYTE_OFFSET+`SIZE_PHYSICAL_LOG-1-:3])
      3'b000: debugPRFRdData_o          =  debugPRFRdDataWord[7:0]  ;
      3'b001: debugPRFRdData_o          =  debugPRFRdDataWord[15:7] ;
      3'b010: debugPRFRdData_o          =  debugPRFRdDataWord[23:16];
      3'b011: debugPRFRdData_o          =  debugPRFRdDataWord[31:24];
      3'b100: debugPRFRdData_o          =  debugPRFRdDataWord[39:32];
      3'b101: debugPRFRdData_o          =  debugPRFRdDataWord[47:40];
      3'b110: debugPRFRdData_o          =  debugPRFRdDataWord[55:48];
      3'b111: debugPRFRdData_o          =  debugPRFRdDataWord[63:56];
    endcase
  end

  assign debugPRFWordAddr =  debugPRFAddr_i[`SIZE_PHYSICAL_LOG-1:0] ;
  assign debugPRFWrEn     =  (debugPRFAddr_i[`SIZE_DATA_BYTE_OFFSET+`SIZE_PHYSICAL_LOG-1-:3] == 3'b111) & debugPRFWrEn_i;

`endif //PRF_DEBUG_PORT

`ifdef DYNAMIC_CONFIG
PRF_RAM_PARTITIONED #(
`else
PRF_RAM #(
`endif
  .RPORT             (2*`ISSUE_WIDTH),
  .WPORT             (`ISSUE_WIDTH),
	.DEPTH             (`SIZE_PHYSICAL_TABLE),
	.INDEX             (`SIZE_PHYSICAL_LOG),
	.WIDTH             (`SIZE_DATA)
	)

	PhyRegFile   (
	
	.addr0_i       (phySrc1_i[0]),
	.data0_o       (src1Data_o[0]),

	.addr1_i       (phySrc2_i[0]),
	.data1_o       (src2Data_o[0]),

	.addr0wr_i     (destAddr[0]), 
	.data0wr_i     (destData[0]),
	.we0_i         (destWe[0]),


`ifdef ISSUE_TWO_WIDE
	.addr2_i       (phySrc1_i[1]),
	.data2_o       (src1Data_o[1]),

	.addr3_i       (phySrc2_i[1]),
	.data3_o       (src2Data_o[1]),

	.addr1wr_i     (destAddr[1]),
	.data1wr_i     (destData[1]),
	.we1_i         (destWe[1]),
`endif


`ifdef ISSUE_THREE_WIDE
	.addr4_i       (phySrc1_i[2]),
	.data4_o       (src1Data_o[2]),

	.addr5_i       (phySrc2_i[2]),
	.data5_o       (src2Data_o[2]),

	.addr2wr_i     (destAddr[2]),
	.data2wr_i     (destData[2]),
	.we2_i         (destWe[2]),
`endif


`ifdef ISSUE_FOUR_WIDE
	.addr6_i       (phySrc1_i[3]),
	.data6_o       (src1Data_o[3]),

	.addr7_i       (phySrc2_i[3]),
	.data7_o       (src2Data_o[3]),

	.addr3wr_i     (destAddr[3]),
	.data3wr_i     (destData[3]),
	.we3_i         (destWe[3]),
`endif

`ifdef ISSUE_FIVE_WIDE
	.addr8_i       (phySrc1_i[4]),
	.data8_o       (src1Data_o[4]),

	.addr9_i       (phySrc2_i[4]),
	.data9_o       (src2Data_o[4]),

	.addr4wr_i     (destAddr[4]),
	.data4wr_i     (destData[4]),
	.we4_i         (destWe[4]),
`endif

`ifdef ISSUE_SIX_WIDE
	.addr10_i      (phySrc1_i[5]),
	.data10_o      (src1Data_o[5]),

	.addr11_i      (phySrc2_i[5]),
	.data11_o      (src2Data_o[5]),

	.addr5wr_i     (destAddr[5]),
	.data5wr_i     (destData[5]),
	.we5_i         (destWe[5]),
`endif

`ifdef ISSUE_SEVEN_WIDE
	.addr12_i      (phySrc1_i[6]),
	.data12_o      (src1Data_o[6]),

	.addr13_i      (phySrc2_i[6]),
	.data13_o      (src2Data_o[6]),

	.addr6wr_i     (destAddr[6]),
	.data6wr_i     (destData[6]),
	.we6_i         (destWe[6]),
`endif

`ifdef ISSUE_EIGHT_WIDE
	.addr14_i      (phySrc1_i[7]),
	.data14_o      (src1Data_o[7]),

	.addr15_i      (phySrc2_i[7]),
	.data15_o      (src2Data_o[7]),

	.addr7wr_i     (destAddr[7]),
	.data7wr_i     (destData[7]),
	.we7_i         (destWe[7]),
`endif

`ifdef DYNAMIC_CONFIG
  .execLaneActive_i   (execLaneActive_i),
  .rfPartitionActive_i(rfPartitionActive_i),
`endif
       
`ifdef PRF_DEBUG_PORT
  .debugPRFRdAddr_i  (debugPRFWordAddr),
  .debugPRFRdData_o  (debugPRFRdDataWord),
  .debugPRFWrData_i  (debugPRFWrDataWord),
  .debugPRFWrEn_i    (debugPRFWrEn),
`endif //PRF_DEBUG_PORT
	
	.clk               (clk)
	//.reset             (reset && ~dbWe_i)
	);

endmodule

