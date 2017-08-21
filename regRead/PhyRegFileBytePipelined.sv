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


module PhyRegFileBytePipelined (

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
	output reg [`SRAM_DATA_WIDTH-1:0]     src1Data_byte0_o [0:`ISSUE_WIDTH-1],
	output reg [`SRAM_DATA_WIDTH-1:0]     src1Data_byte1_o [0:`ISSUE_WIDTH-1],
	output reg [`SRAM_DATA_WIDTH-1:0]     src1Data_byte2_o [0:`ISSUE_WIDTH-1],
	output reg [`SRAM_DATA_WIDTH-1:0]     src1Data_byte3_o [0:`ISSUE_WIDTH-1],
	output reg [`SRAM_DATA_WIDTH-1:0]     src1Data_byte4_o [0:`ISSUE_WIDTH-1],
	output reg [`SRAM_DATA_WIDTH-1:0]     src1Data_byte5_o [0:`ISSUE_WIDTH-1],
	output reg [`SRAM_DATA_WIDTH-1:0]     src1Data_byte6_o [0:`ISSUE_WIDTH-1],
	output reg [`SRAM_DATA_WIDTH-1:0]     src1Data_byte7_o [0:`ISSUE_WIDTH-1],

	output reg [`SRAM_DATA_WIDTH-1:0]     src2Data_byte0_o [0:`ISSUE_WIDTH-1],
	output reg [`SRAM_DATA_WIDTH-1:0]     src2Data_byte1_o [0:`ISSUE_WIDTH-1],
	output reg [`SRAM_DATA_WIDTH-1:0]     src2Data_byte2_o [0:`ISSUE_WIDTH-1],
	output reg [`SRAM_DATA_WIDTH-1:0]     src2Data_byte3_o [0:`ISSUE_WIDTH-1],
	output reg [`SRAM_DATA_WIDTH-1:0]     src2Data_byte4_o [0:`ISSUE_WIDTH-1],
	output reg [`SRAM_DATA_WIDTH-1:0]     src2Data_byte5_o [0:`ISSUE_WIDTH-1],
	output reg [`SRAM_DATA_WIDTH-1:0]     src2Data_byte6_o [0:`ISSUE_WIDTH-1],
	output reg [`SRAM_DATA_WIDTH-1:0]     src2Data_byte7_o [0:`ISSUE_WIDTH-1],

	input  [`SIZE_PHYSICAL_LOG-1:0]       dbAddr_i,
	input  [`SIZE_DATA-1:0]               dbData_i,
	input                                 dbWe_i,
	
	input  [`SIZE_PHYSICAL_LOG+`SIZE_DATA_BYTE_OFFSET-1:0]       debugPRFAddr_i,
	input  [`SRAM_DATA_WIDTH-1:0]         debugPRFWrData_i,
	input                                 debugPRFWrEn_i,
	output [`SRAM_DATA_WIDTH-1:0]         debugPRFRdData_o
	);


reg  [`SRAM_DATA_WIDTH-1:0]                   bypassData_byte2    [0:`ISSUE_WIDTH-1];
reg  [`SRAM_DATA_WIDTH-1:0]                   bypassData_byte3    [0:`ISSUE_WIDTH-1];
reg  [`SRAM_DATA_WIDTH-1:0]                   bypassData_byte3_t0 [0:`ISSUE_WIDTH-1];

reg  [`SRAM_DATA_WIDTH-1:0]                   bypassData_byte6    [0:`ISSUE_WIDTH-1];
reg  [`SRAM_DATA_WIDTH-1:0]                   bypassData_byte7    [0:`ISSUE_WIDTH-1];
reg  [`SRAM_DATA_WIDTH-1:0]                   bypassData_byte7_t0 [0:`ISSUE_WIDTH-1];


reg  [`SIZE_PHYSICAL_LOG-1:0]         src1Addr_byte0   [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]         src1Addr_byte1   [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]         src1Addr_byte2   [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]         src1Addr_byte3   [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]         src1Addr_byte4   [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]         src1Addr_byte5   [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]         src1Addr_byte6   [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]         src1Addr_byte7   [0:`ISSUE_WIDTH-1];

reg  [`SIZE_PHYSICAL_LOG-1:0]         src2Addr_byte0   [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]         src2Addr_byte1   [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]         src2Addr_byte2   [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]         src2Addr_byte3   [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]         src2Addr_byte4   [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]         src2Addr_byte5   [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]         src2Addr_byte6   [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]         src2Addr_byte7   [0:`ISSUE_WIDTH-1];

reg  [`SIZE_PHYSICAL_LOG-1:0]         destAddr_byte0   [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]         destAddr_byte1   [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]         destAddr_byte2   [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]         destAddr_byte3   [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]         destAddr_byte4   [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]         destAddr_byte5   [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]         destAddr_byte6   [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]         destAddr_byte7   [0:`ISSUE_WIDTH-1];

reg  [`SRAM_DATA_WIDTH-1:0]             destData_byte0   [0:`ISSUE_WIDTH-1];
reg  [`SRAM_DATA_WIDTH-1:0]             destData_byte1   [0:`ISSUE_WIDTH-1];
reg  [`SRAM_DATA_WIDTH-1:0]             destData_byte2   [0:`ISSUE_WIDTH-1];
reg  [`SRAM_DATA_WIDTH-1:0]             destData_byte3   [0:`ISSUE_WIDTH-1];
reg  [`SRAM_DATA_WIDTH-1:0]             destData_byte4   [0:`ISSUE_WIDTH-1];
reg  [`SRAM_DATA_WIDTH-1:0]             destData_byte5   [0:`ISSUE_WIDTH-1];
reg  [`SRAM_DATA_WIDTH-1:0]             destData_byte6   [0:`ISSUE_WIDTH-1];
reg  [`SRAM_DATA_WIDTH-1:0]             destData_byte7   [0:`ISSUE_WIDTH-1];

reg                                     destWe_byte0     [0:`ISSUE_WIDTH-1];
reg                                     destWe_byte1     [0:`ISSUE_WIDTH-1];
reg                                     destWe_byte2     [0:`ISSUE_WIDTH-1];
reg                                     destWe_byte3     [0:`ISSUE_WIDTH-1];
reg                                     destWe_byte4     [0:`ISSUE_WIDTH-1];
reg                                     destWe_byte5     [0:`ISSUE_WIDTH-1];
reg                                     destWe_byte6     [0:`ISSUE_WIDTH-1];
reg                                     destWe_byte7     [0:`ISSUE_WIDTH-1];


//`ifdef DYNAMIC_CONFIG
//  reg [`SIZE_PHYSICAL_LOG-1:0]        phySrc1Gated [0:`ISSUE_WIDTH-1];
//  reg [`SIZE_PHYSICAL_LOG-1:0]        phySrc2Gated [0:`ISSUE_WIDTH-1];
//  reg [`SIZE_PHYSICAL_LOG-1:0]        bypassTagGated [0:`ISSUE_WIDTH-1];
//  
//  reg [`ISSUE_WIDTH-1:0][`NUM_PARTS_RF_LOG-1:0] src1DataPartitionSelect_byte0;
//  reg [`ISSUE_WIDTH-1:0][`NUM_PARTS_RF_LOG-1:0] src1DataPartitionSelect_byte1;
//  reg [`ISSUE_WIDTH-1:0][`NUM_PARTS_RF_LOG-1:0] src1DataPartitionSelect_byte2;
//  reg [`ISSUE_WIDTH-1:0][`NUM_PARTS_RF_LOG-1:0] src1DataPartitionSelect_byte3;
//  reg [`ISSUE_WIDTH-1:0][`NUM_PARTS_RF_LOG-1:0] src1DataPartitionSelect_byte4;
//  reg [`ISSUE_WIDTH-1:0][`NUM_PARTS_RF_LOG-1:0] src1DataPartitionSelect_byte5;
//  reg [`ISSUE_WIDTH-1:0][`NUM_PARTS_RF_LOG-1:0] src1DataPartitionSelect_byte6;
//  reg [`ISSUE_WIDTH-1:0][`NUM_PARTS_RF_LOG-1:0] src1DataPartitionSelect_byte7;
//  
//                        
//  reg [`ISSUE_WIDTH-1:0][`NUM_PARTS_RF_LOG-1:0] src2DataPartitionSelect_byte0;
//  reg [`ISSUE_WIDTH-1:0][`NUM_PARTS_RF_LOG-1:0] src2DataPartitionSelect_byte1;
//  reg [`ISSUE_WIDTH-1:0][`NUM_PARTS_RF_LOG-1:0] src2DataPartitionSelect_byte2;
//  reg [`ISSUE_WIDTH-1:0][`NUM_PARTS_RF_LOG-1:0] src2DataPartitionSelect_byte3;
//  reg [`ISSUE_WIDTH-1:0][`NUM_PARTS_RF_LOG-1:0] src2DataPartitionSelect_byte4;
//  reg [`ISSUE_WIDTH-1:0][`NUM_PARTS_RF_LOG-1:0] src2DataPartitionSelect_byte5;
//  reg [`ISSUE_WIDTH-1:0][`NUM_PARTS_RF_LOG-1:0] src2DataPartitionSelect_byte6;
//  reg [`ISSUE_WIDTH-1:0][`NUM_PARTS_RF_LOG-1:0] src2DataPartitionSelect_byte7;
//  
//  always_comb
//  begin
//  	int i;
//  
//  	for (i = 0; i < `ISSUE_WIDTH; i++)
//  	begin
//      // Input Gating
//      // TODO: This gating should be done outside by the clamping logic surrounding the execution lanes
//      phySrc1Gated[i]           = execLaneActive_i[i] ?  phySrc1_i[i]          : {`SIZE_PHYSICAL_LOG{1'b0}};
//      phySrc2Gated[i]           = execLaneActive_i[i] ?  phySrc2_i[i]          : {`SIZE_PHYSICAL_LOG{1'b0}};
//      bypassTagGated[i]         = execLaneActive_i[i] ?  bypassPacket_i[i].tag : {`SIZE_PHYSICAL_LOG{1'b0}};
//  
//      src1DataPartitionSelect_byte0[i]   =   phySrc1Gated[i][`SIZE_PHYSICAL_LOG-1 :`SIZE_PHYSICAL_LOG-`NUM_PARTS_RF_LOG];
//      src2DataPartitionSelect_byte0[i]   =   phySrc2Gated[i][`SIZE_PHYSICAL_LOG-1 :`SIZE_PHYSICAL_LOG-`NUM_PARTS_RF_LOG];
//  
//      src1DataPartitionSelect_byte4[i]   =   phySrc1Gated[i][`SIZE_PHYSICAL_LOG-1 :`SIZE_PHYSICAL_LOG-`NUM_PARTS_RF_LOG];
//      src2DataPartitionSelect_byte4[i]   =   phySrc2Gated[i][`SIZE_PHYSICAL_LOG-1 :`SIZE_PHYSICAL_LOG-`NUM_PARTS_RF_LOG];
//  
//  `ifndef RR_THREE_DEEP
//      src1DataPartitionSelect_byte1[i]   =   src1DataPartitionSelect_byte0[i];
//      src2DataPartitionSelect_byte1[i]   =   src2DataPartitionSelect_byte0[i];
//  
//      src1DataPartitionSelect_byte5[i]   =   src1DataPartitionSelect_byte4[i];
//      src2DataPartitionSelect_byte5[i]   =   src2DataPartitionSelect_byte4[i];
//  `endif
//  
//  `ifndef RR_TWO_DEEP
//      src1DataPartitionSelect_byte2[i]   =   src1DataPartitionSelect_byte1[i];
//      src2DataPartitionSelect_byte2[i]   =   src2DataPartitionSelect_byte1[i];
//  
//      src1DataPartitionSelect_byte6[i]   =   src1DataPartitionSelect_byte5[i];
//      src2DataPartitionSelect_byte6[i]   =   src2DataPartitionSelect_byte5[i];
//  `endif
//  
//  `ifndef RR_FOUR_DEEP
//      src1DataPartitionSelect_byte3[i]   =   src1DataPartitionSelect_byte2[i];
//      src2DataPartitionSelect_byte3[i]   =   src2DataPartitionSelect_byte2[i];
//  
//      src1DataPartitionSelect_byte7[i]   =   src1DataPartitionSelect_byte6[i];
//      src2DataPartitionSelect_byte7[i]   =   src2DataPartitionSelect_byte6[i];
//  `endif
//    end
//  end
//  
//  always_ff @(posedge clk)
//  begin
//  	int i;
//  
//  	for (i = 0; i < `ISSUE_WIDTH; i++)
//  	begin
//  `ifdef RR_THREE_DEEP
//      src1DataPartitionSelect_byte1[i]   <=   src1DataPartitionSelect_byte0[i];
//      src2DataPartitionSelect_byte1[i]   <=   src2DataPartitionSelect_byte0[i];
//  
//      src1DataPartitionSelect_byte5[i]   <=   src1DataPartitionSelect_byte4[i];
//      src2DataPartitionSelect_byte5[i]   <=   src2DataPartitionSelect_byte4[i];
//  `endif
//  
//  `ifdef RR_TWO_DEEP
//      src1DataPartitionSelect_byte2[i]   <=   src1DataPartitionSelect_byte1[i];
//      src2DataPartitionSelect_byte2[i]   <=   src2DataPartitionSelect_byte1[i];
//  
//      src1DataPartitionSelect_byte6[i]   <=   src1DataPartitionSelect_byte5[i];
//      src2DataPartitionSelect_byte6[i]   <=   src2DataPartitionSelect_byte5[i];
//  `endif
//  
//  `ifdef RR_FOUR_DEEP
//      src1DataPartitionSelect_byte3[i]   <=   src1DataPartitionSelect_byte2[i];
//      src2DataPartitionSelect_byte3[i]   <=   src2DataPartitionSelect_byte2[i];
//  
//      src1DataPartitionSelect_byte7[i]   <=   src1DataPartitionSelect_byte6[i];
//      src2DataPartitionSelect_byte7[i]   <=   src2DataPartitionSelect_byte6[i];
//  `endif
//    end
//  
//  end
//
//`endif

/* The physical register file is split into bytes to accomodate different
 * depths. The bytes read/written in each cycle for different depths is as follows:
 *                Cycle-n  n+1  n+2  n+3
 * RR_ONE_DEEP    0,1,2,3
 * RR_TWO_DEEP    0,1      2,3
 * RR_THREE_DEEP  0        1    2,3
 * RR_FOUR_DEEP   0        1    2    3
 */

/* Reads and writes start at byte 0. The addresses/write enables get passed from
 * byte 0 to byte 1 to byte 2 to byte 3. Whether the signals get passed
 * immediately or in the next cycle depends on the register read depth.
 * The data being written comes from the bypass and gets delayed here for
 * depths > 1. */

// TODO: Might be worthwhile to gate the per lane decoders
// This should be decided based upon the power numbers obtained
// from Prime Time. Dynamic power will be saved as the addresses
// are gated. 
always_comb
begin
	int i;

	for (i = 0; i < `ISSUE_WIDTH; i++)
	begin
		/* Decode the addresses */
//`ifdef DYNAMIC_CONFIG    
//		src1Addr_byte0[i]         = phySrc1Gated[i];
//		src2Addr_byte0[i]         = phySrc2Gated[i];
//		destAddr_byte0[i]         = bypassTagGated[i];
//		src1Addr_byte4[i]         = phySrc1Gated[i];
//		src2Addr_byte4[i]         = phySrc2Gated[i];
//		destAddr_byte4[i]         = bypassTagGated[i];
//`else
		src1Addr_byte0[i]         = phySrc1_i[i];
		src2Addr_byte0[i]         = phySrc2_i[i];
		destAddr_byte0[i]         = bypassPacket_i[i].tag;
		src1Addr_byte4[i]         = phySrc1_i[i];
		src2Addr_byte4[i]         = phySrc2_i[i];
		destAddr_byte4[i]         = bypassPacket_i[i].tag;
//`endif    
		destWe_byte0[i]           = bypassPacket_i[i].valid;
		destData_byte0[i]         = bypassPacket_i[i].data[`SRAM_DATA_WIDTH-1:0];
		destWe_byte4[i]           = bypassPacket_i[i].valid;
		destData_byte4[i]         = bypassPacket_i[i].data[5*`SRAM_DATA_WIDTH-1:4*`SRAM_DATA_WIDTH];

`ifndef RR_THREE_DEEP
		src1Addr_byte1[i]         = src1Addr_byte0[i];
		src2Addr_byte1[i]         = src2Addr_byte0[i];
		destAddr_byte1[i]         = destAddr_byte0[i];
		destWe_byte1[i]           = destWe_byte0[i];
		destData_byte1[i]         = bypassPacket_i[i].data[2*`SRAM_DATA_WIDTH-1:`SRAM_DATA_WIDTH];
		bypassData_byte2[i]       = bypassPacket_i[i].data[3*`SRAM_DATA_WIDTH-1:2*`SRAM_DATA_WIDTH];
		bypassData_byte3_t0[i]    = bypassPacket_i[i].data[4*`SRAM_DATA_WIDTH-1:3*`SRAM_DATA_WIDTH];

		src1Addr_byte5[i]         = src1Addr_byte4[i];
		src2Addr_byte5[i]         = src2Addr_byte4[i];
		destAddr_byte5[i]         = destAddr_byte4[i];
		destWe_byte5[i]           = destWe_byte4[i];
		destData_byte5[i]         = bypassPacket_i[i].data[6*`SRAM_DATA_WIDTH-1:5*`SRAM_DATA_WIDTH];
		bypassData_byte6[i]       = bypassPacket_i[i].data[7*`SRAM_DATA_WIDTH-1:6*`SRAM_DATA_WIDTH];
		bypassData_byte7_t0[i]    = bypassPacket_i[i].data[8*`SRAM_DATA_WIDTH-1:7*`SRAM_DATA_WIDTH];
`endif

`ifndef RR_TWO_DEEP
		src1Addr_byte2[i]         = src1Addr_byte1[i];
		src2Addr_byte2[i]         = src2Addr_byte1[i];
		destAddr_byte2[i]         = destAddr_byte1[i];
		destWe_byte2[i]           = destWe_byte1[i];
		destData_byte2[i]         = bypassPacket_i[i].data[3*`SRAM_DATA_WIDTH-1:2*`SRAM_DATA_WIDTH];
		destData_byte3[i]         = bypassPacket_i[i].data[4*`SRAM_DATA_WIDTH-1:3*`SRAM_DATA_WIDTH];

		src1Addr_byte6[i]         = src1Addr_byte5[i];
		src2Addr_byte6[i]         = src2Addr_byte5[i];
		destAddr_byte6[i]         = destAddr_byte5[i];
		destWe_byte6[i]           = destWe_byte5[i];
		destData_byte6[i]         = bypassPacket_i[i].data[7*`SRAM_DATA_WIDTH-1:6*`SRAM_DATA_WIDTH];
		destData_byte7[i]         = bypassPacket_i[i].data[8*`SRAM_DATA_WIDTH-1:7*`SRAM_DATA_WIDTH];
`endif

`ifndef RR_FOUR_DEEP
		src1Addr_byte3[i]         = src1Addr_byte2[i];
		src2Addr_byte3[i]         = src2Addr_byte2[i];
		destAddr_byte3[i]         = destAddr_byte2[i];
		destWe_byte3[i]           = destWe_byte2[i];
		bypassData_byte3[i]       = bypassData_byte3_t0[i];

		src1Addr_byte7[i]         = src1Addr_byte6[i];
		src2Addr_byte7[i]         = src2Addr_byte6[i];
		destAddr_byte7[i]         = destAddr_byte6[i];
		destWe_byte7[i]           = destWe_byte6[i];
		bypassData_byte7[i]       = bypassData_byte7_t0[i];
`endif
	end

`ifdef ZERO
	/* Hijack a port to load from a checkpoint */
	/* Note: This is not implemented yet */
	if (dbWe_i)
	begin
		destAddr_byte0[0]   = dbAddr_i;
		destAddr_byte1[0]   = dbAddr_i;
		destAddr_byte3[0]   = dbAddr_i;

		destData_byte0[0]   = dbData_i[`SRAM_DATA_WIDTH-1:0];
		destData_byte1[0]   = dbData_i[2*`SRAM_DATA_WIDTH-1:`SRAM_DATA_WIDTH];
		destData_byte3[0]   = dbData_i[4*`SRAM_DATA_WIDTH-1:3*`SRAM_DATA_WIDTH];

		destWe_byte0[0]     = 1'h1;
		destWe_byte1[0]     = 1'h1;
		destWe_byte3[0]     = 1'h1;
	end
`endif
end


// LANE: Per lane logic

always_ff @(posedge clk)
begin
	int i;

`ifdef RR_THREE_DEEP
	for (i = 0; i < `ISSUE_WIDTH; i++)
	begin
		src1Addr_byte1[i]        <= src1Addr_byte0[i];
		src2Addr_byte1[i]        <= src2Addr_byte0[i];
		destAddr_byte1[i]        <= destAddr_byte0[i];
		destWe_byte1[i]          <= destWe_byte0[i];
		destData_byte1[i]        <= bypassPacket_i[i].data[2*`SRAM_DATA_WIDTH-1:`SRAM_DATA_WIDTH];
		bypassData_byte2[i]      <= bypassPacket_i[i].data[3*`SRAM_DATA_WIDTH-1:2*`SRAM_DATA_WIDTH];
		bypassData_byte3_t0[i]   <= bypassPacket_i[i].data[4*`SRAM_DATA_WIDTH-1:3*`SRAM_DATA_WIDTH];

		src1Addr_byte5[i]        <= src1Addr_byte4[i];
		src2Addr_byte5[i]        <= src2Addr_byte4[i];
		destAddr_byte5[i]        <= destAddr_byte4[i];
		destWe_byte5[i]          <= destWe_byte4[i];
		destData_byte5[i]        <= bypassPacket_i[i].data[6*`SRAM_DATA_WIDTH-1:5*`SRAM_DATA_WIDTH];
		bypassData_byte6[i]      <= bypassPacket_i[i].data[7*`SRAM_DATA_WIDTH-1:6*`SRAM_DATA_WIDTH];
		bypassData_byte7_t0[i]   <= bypassPacket_i[i].data[8*`SRAM_DATA_WIDTH-1:7*`SRAM_DATA_WIDTH];
	end
`endif

`ifdef RR_TWO_DEEP
	for (i = 0; i < `ISSUE_WIDTH; i++)
	begin
		src1Addr_byte2[i]        <= src1Addr_byte1[i];
		src2Addr_byte2[i]        <= src2Addr_byte1[i];
		destAddr_byte2[i]        <= destAddr_byte1[i];
		destWe_byte2[i]          <= destWe_byte1[i];
		destData_byte2[i]        <= bypassData_byte2[i];
		destData_byte3[i]        <= bypassData_byte3[i];

		src1Addr_byte6[i]        <= src1Addr_byte5[i];
		src2Addr_byte6[i]        <= src2Addr_byte5[i];
		destAddr_byte6[i]        <= destAddr_byte5[i];
		destWe_byte6[i]          <= destWe_byte5[i];
		destData_byte6[i]        <= bypassData_byte6[i];
		destData_byte7[i]        <= bypassData_byte7[i];
	end
`endif

`ifdef RR_FOUR_DEEP
	for (i = 0; i < `ISSUE_WIDTH; i++)
	begin
		src1Addr_byte3[i]        <= src1Addr_byte2[i];
		src2Addr_byte3[i]        <= src2Addr_byte2[i];
		destAddr_byte3[i]        <= destAddr_byte2[i];
		destWe_byte3[i]          <= destWe_byte2[i];
		bypassData_byte3[i]      <= bypassData_byte3_t0[i];

		src1Addr_byte7[i]        <= src1Addr_byte6[i];
		src2Addr_byte7[i]        <= src2Addr_byte6[i];
		destAddr_byte7[i]        <= destAddr_byte6[i];
		destWe_byte7[i]          <= destWe_byte6[i];
		bypassData_byte7[i]      <= bypassData_byte7_t0[i];
	end
`endif

`ifdef ZERO
	/* Hijack a port to load from a checkpoint */
	if (dbWe_i)
	begin
		destAddr_byte2[0]  <= 1 << dbAddr_i;
		destData_byte2[0]  <= dbData_i[3*`SRAM_DATA_WIDTH-1:2*`SRAM_DATA_WIDTH];
		destWe_byte2[0]    <= 1'h1;
	end
`endif
end


// This is a debug port to read write PRF through the off chip debug interface
`ifdef PRF_DEBUG_PORT

  wire debugPRFWrEn_byte0;
  wire debugPRFWrEn_byte1;
  wire debugPRFWrEn_byte2;
  wire debugPRFWrEn_byte3;
  wire debugPRFWrEn_byte4;
  wire debugPRFWrEn_byte5;
  wire debugPRFWrEn_byte6;
  wire debugPRFWrEn_byte7;
  
  wire [`SRAM_DATA_WIDTH-1:0] debugPRFRdData_byte0;
  wire [`SRAM_DATA_WIDTH-1:0] debugPRFRdData_byte1;
  wire [`SRAM_DATA_WIDTH-1:0] debugPRFRdData_byte2;
  wire [`SRAM_DATA_WIDTH-1:0] debugPRFRdData_byte4;
  wire [`SRAM_DATA_WIDTH-1:0] debugPRFRdData_byte5;
  wire [`SRAM_DATA_WIDTH-1:0] debugPRFRdData_byte6;
  wire [`SRAM_DATA_WIDTH-1:0] debugPRFRdData_byte7;

  wire [`SIZE_PHYSICAL_LOG-1:0]  debugPRFAddr_shifted;
  wire [`NUM_PARTS_RF_LOG-1:0] debugPRFPartitionSelect;
  
  assign debugPRFWrEn_byte0 = (debugPRFAddr_i[`SIZE_DATA_BYTE_OFFSET+`SIZE_PHYSICAL_LOG-1-:3] == 2'b000) ? debugPRFWrEn_i : 0;
  assign debugPRFWrEn_byte1 = (debugPRFAddr_i[`SIZE_DATA_BYTE_OFFSET+`SIZE_PHYSICAL_LOG-1-:3] == 2'b001) ? debugPRFWrEn_i : 0;
  assign debugPRFWrEn_byte2 = (debugPRFAddr_i[`SIZE_DATA_BYTE_OFFSET+`SIZE_PHYSICAL_LOG-1-:3] == 2'b010) ? debugPRFWrEn_i : 0;
  assign debugPRFWrEn_byte3 = (debugPRFAddr_i[`SIZE_DATA_BYTE_OFFSET+`SIZE_PHYSICAL_LOG-1-:3] == 2'b011) ? debugPRFWrEn_i : 0;
  assign debugPRFWrEn_byte4 = (debugPRFAddr_i[`SIZE_DATA_BYTE_OFFSET+`SIZE_PHYSICAL_LOG-1-:3] == 2'b100) ? debugPRFWrEn_i : 0;
  assign debugPRFWrEn_byte5 = (debugPRFAddr_i[`SIZE_DATA_BYTE_OFFSET+`SIZE_PHYSICAL_LOG-1-:3] == 2'b101) ? debugPRFWrEn_i : 0;
  assign debugPRFWrEn_byte6 = (debugPRFAddr_i[`SIZE_DATA_BYTE_OFFSET+`SIZE_PHYSICAL_LOG-1-:3] == 2'b110) ? debugPRFWrEn_i : 0;
  assign debugPRFWrEn_byte7 = (debugPRFAddr_i[`SIZE_DATA_BYTE_OFFSET+`SIZE_PHYSICAL_LOG-1-:3] == 2'b111) ? debugPRFWrEn_i : 0;
  
  assign debugPRFRdData_o =     (debugPRFAddr_i[`SIZE_DATA_BYTE_OFFSET+`SIZE_PHYSICAL_LOG-1-:3] == 2'b000) ? debugPRFRdData_byte0 
                              : (debugPRFAddr_i[`SIZE_DATA_BYTE_OFFSET+`SIZE_PHYSICAL_LOG-1-:3] == 2'b001) ? debugPRFRdData_byte1 
                              : (debugPRFAddr_i[`SIZE_DATA_BYTE_OFFSET+`SIZE_PHYSICAL_LOG-1-:3] == 2'b010) ? debugPRFRdData_byte2 
                              : (debugPRFAddr_i[`SIZE_DATA_BYTE_OFFSET+`SIZE_PHYSICAL_LOG-1-:3] == 2'b011) ? debugPRFRdData_byte3 
                              : (debugPRFAddr_i[`SIZE_DATA_BYTE_OFFSET+`SIZE_PHYSICAL_LOG-1-:3] == 2'b100) ? debugPRFRdData_byte4 
                              : (debugPRFAddr_i[`SIZE_DATA_BYTE_OFFSET+`SIZE_PHYSICAL_LOG-1-:3] == 2'b101) ? debugPRFRdData_byte5 
                              : (debugPRFAddr_i[`SIZE_DATA_BYTE_OFFSET+`SIZE_PHYSICAL_LOG-1-:3] == 2'b110) ? debugPRFRdData_byte6 
                              :                                                                              debugPRFRdData_byte7;
  


  assign debugPRFAddr_shifted       =  debugPRFAddr_i[`SIZE_PHYSICAL_LOG-1:0] ;
  assign debugPRFPartitionSelect    =  debugPRFAddr_i[`SIZE_PHYSICAL_LOG-1 :`SIZE_PHYSICAL_LOG-`NUM_PARTS_RF_LOG];

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
	.WIDTH             (8)
	)

	PhyRegFile_byte0   (
	
	.addr0_i       (src1Addr_byte0[0]),
	.data0_o       (src1Data_byte0_o[0]),

	.addr1_i       (src2Addr_byte0[0]),
	.data1_o       (src2Data_byte0_o[0]),

	.addr0wr_i     (destAddr_byte0[0]), 
	.data0wr_i     (destData_byte0[0]),
	.we0_i         (destWe_byte0[0]),


`ifdef ISSUE_TWO_WIDE
	.addr2_i       (src1Addr_byte0[1]),
	.data2_o       (src1Data_byte0_o[1]),

	.addr3_i       (src2Addr_byte0[1]),
	.data3_o       (src2Data_byte0_o[1]),

	.addr1wr_i     (destAddr_byte0[1]),
	.data1wr_i     (destData_byte0[1]),
	.we1_i         (destWe_byte0[1]),
`endif


`ifdef ISSUE_THREE_WIDE
	.addr4_i       (src1Addr_byte0[2]),
	.data4_o       (src1Data_byte0_o[2]),

	.addr5_i       (src2Addr_byte0[2]),
	.data5_o       (src2Data_byte0_o[2]),

	.addr2wr_i     (destAddr_byte0[2]),
	.data2wr_i     (destData_byte0[2]),
	.we2_i         (destWe_byte0[2]),
`endif


`ifdef ISSUE_FOUR_WIDE
	.addr6_i       (src1Addr_byte0[3]),
	.data6_o       (src1Data_byte0_o[3]),

	.addr7_i       (src2Addr_byte0[3]),
	.data7_o       (src2Data_byte0_o[3]),

	.addr3wr_i     (destAddr_byte0[3]),
	.data3wr_i     (destData_byte0[3]),
	.we3_i         (destWe_byte0[3]),
`endif

`ifdef ISSUE_FIVE_WIDE
	.addr8_i       (src1Addr_byte0[4]),
	.data8_o       (src1Data_byte0_o[4]),

	.addr9_i       (src2Addr_byte0[4]),
	.data9_o       (src2Data_byte0_o[4]),

	.addr4wr_i     (destAddr_byte0[4]),
	.data4wr_i     (destData_byte0[4]),
	.we4_i         (destWe_byte0[4]),
`endif

`ifdef ISSUE_SIX_WIDE
	.addr10_i      (src1Addr_byte0[5]),
	.data10_o      (src1Data_byte0_o[5]),

	.addr11_i      (src2Addr_byte0[5]),
	.data11_o      (src2Data_byte0_o[5]),

	.addr5wr_i     (destAddr_byte0[5]),
	.data5wr_i     (destData_byte0[5]),
	.we5_i         (destWe_byte0[5]),
`endif

`ifdef ISSUE_SEVEN_WIDE
	.addr12_i      (src1Addr_byte0[6]),
	.data12_o      (src1Data_byte0_o[6]),

	.addr13_i      (src2Addr_byte0[6]),
	.data13_o      (src2Data_byte0_o[6]),

	.addr6wr_i     (destAddr_byte0[6]),
	.data6wr_i     (destData_byte0[6]),
	.we6_i         (destWe_byte0[6]),
`endif

`ifdef ISSUE_EIGHT_WIDE
	.addr14_i      (src1Addr_byte0[7]),
	.data14_o      (src1Data_byte0_o[7]),

	.addr15_i      (src2Addr_byte0[7]),
	.data15_o      (src2Data_byte0_o[7]),

	.addr7wr_i     (destAddr_byte0[7]),
	.data7wr_i     (destData_byte0[7]),
	.we7_i         (destWe_byte0[7]),
`endif

`ifdef DYNAMIC_CONFIG
  .execLaneActive_i   (execLaneActive_i),
  .rfPartitionActive_i(rfPartitionActive_i),
`endif
       
`ifdef PRF_DEBUG_PORT
  .debugPRFRdAddr_i  (debugPRFAddr_shifted),
  .debugPRFRdData_o  (debugPRFRdData_byte0),
  .debugPRFWrData_i  (debugPRFWrData_i),
  .debugPRFWrEn_i    (debugPRFWrEn_byte0),
`endif //PRF_DEBUG_PORT
	
	.clk               (clk)
	//.reset             (reset && ~dbWe_i)
	);



`ifdef DYNAMIC_CONFIG
PRF_RAM_PARTITIONED #(
`else
PRF_RAM #(
`endif
  .RPORT             (2*`ISSUE_WIDTH),
  .WPORT             (`ISSUE_WIDTH),
	.DEPTH             (`SIZE_PHYSICAL_TABLE),
	.INDEX             (`SIZE_PHYSICAL_LOG),
	.WIDTH             (8)
	)

	PhyRegFile_byte1   (
	
	.addr0_i       (src1Addr_byte1[0]),
	.data0_o       (src1Data_byte1_o[0]),

	.addr1_i       (src2Addr_byte1[0]),
	.data1_o       (src2Data_byte1_o[0]),

	.addr0wr_i     (destAddr_byte1[0]), 
	.data0wr_i     (destData_byte1[0]),
	.we0_i         (destWe_byte1[0]),


`ifdef ISSUE_TWO_WIDE
	.addr2_i       (src1Addr_byte1[1]),
	.data2_o       (src1Data_byte1_o[1]),

	.addr3_i       (src2Addr_byte1[1]),
	.data3_o       (src2Data_byte1_o[1]),

	.addr1wr_i     (destAddr_byte1[1]),
	.data1wr_i     (destData_byte1[1]),
	.we1_i         (destWe_byte1[1]),
`endif


`ifdef ISSUE_THREE_WIDE
	.addr4_i       (src1Addr_byte1[2]),
	.data4_o       (src1Data_byte1_o[2]),

	.addr5_i       (src2Addr_byte1[2]),
	.data5_o       (src2Data_byte1_o[2]),

	.addr2wr_i     (destAddr_byte1[2]),
	.data2wr_i     (destData_byte1[2]),
	.we2_i         (destWe_byte1[2]),
`endif


`ifdef ISSUE_FOUR_WIDE
	.addr6_i       (src1Addr_byte1[3]),
	.data6_o       (src1Data_byte1_o[3]),

	.addr7_i       (src2Addr_byte1[3]),
	.data7_o       (src2Data_byte1_o[3]),

	.addr3wr_i     (destAddr_byte1[3]),
	.data3wr_i     (destData_byte1[3]),
	.we3_i         (destWe_byte1[3]),
`endif

`ifdef ISSUE_FIVE_WIDE
	.addr8_i       (src1Addr_byte1[4]),
	.data8_o       (src1Data_byte1_o[4]),

	.addr9_i       (src2Addr_byte1[4]),
	.data9_o       (src2Data_byte1_o[4]),

	.addr4wr_i     (destAddr_byte1[4]),
	.data4wr_i     (destData_byte1[4]),
	.we4_i         (destWe_byte1[4]),
`endif

`ifdef ISSUE_SIX_WIDE
	.addr10_i      (src1Addr_byte1[5]),
	.data10_o      (src1Data_byte1_o[5]),

	.addr11_i      (src2Addr_byte1[5]),
	.data11_o      (src2Data_byte1_o[5]),

	.addr5wr_i     (destAddr_byte1[5]),
	.data5wr_i     (destData_byte1[5]),
	.we5_i         (destWe_byte1[5]),
`endif

`ifdef ISSUE_SEVEN_WIDE
	.addr12_i      (src1Addr_byte1[6]),
	.data12_o      (src1Data_byte1_o[6]),

	.addr13_i      (src2Addr_byte1[6]),
	.data13_o      (src2Data_byte1_o[6]),

	.addr6wr_i     (destAddr_byte1[6]),
	.data6wr_i     (destData_byte1[6]),
	.we6_i         (destWe_byte1[6]),
`endif

`ifdef ISSUE_EIGHT_WIDE
	.addr14_i      (src1Addr_byte1[7]),
	.data14_o      (src1Data_byte1_o[7]),

	.addr15_i      (src2Addr_byte1[7]),
	.data15_o      (src2Data_byte1_o[7]),

	.addr7wr_i     (destAddr_byte1[7]),
	.data7wr_i     (destData_byte1[7]),
	.we7_i         (destWe_byte1[7]),
`endif

`ifdef DYNAMIC_CONFIG
  .execLaneActive_i   (execLaneActive_i),
  .rfPartitionActive_i(rfPartitionActive_i),
`endif
       
`ifdef PRF_DEBUG_PORT
  .debugPRFRdAddr_i  (debugPRFAddr_shifted),
  .debugPRFRdData_o  (debugPRFRdData_byte1),
  .debugPRFWrData_i  (debugPRFWrData_i),
  .debugPRFWrEn_i    (debugPRFWrEn_byte1),
`endif //PRF_DEBUG_PORT
	
	.clk               (clk)
	//.reset             (reset && ~dbWe_i)
	);




`ifdef DYNAMIC_CONFIG
PRF_RAM_PARTITIONED #(
`else
PRF_RAM #(
`endif
  .RPORT             (2*`ISSUE_WIDTH),
  .WPORT             (`ISSUE_WIDTH),
	.DEPTH             (`SIZE_PHYSICAL_TABLE),
	.INDEX             (`SIZE_PHYSICAL_LOG),
	.WIDTH             (8)
	)

	PhyRegFile_byte2   (
	
	.addr0_i       (src1Addr_byte2[0]),
	.data0_o       (src1Data_byte2_o[0]),

	.addr1_i       (src2Addr_byte2[0]),
	.data1_o       (src2Data_byte2_o[0]),

	.addr0wr_i     (destAddr_byte2[0]), 
	.data0wr_i     (destData_byte2[0]),
	.we0_i         (destWe_byte2[0]),


`ifdef ISSUE_TWO_WIDE
	.addr2_i       (src1Addr_byte2[1]),
	.data2_o       (src1Data_byte2_o[1]),

	.addr3_i       (src2Addr_byte2[1]),
	.data3_o       (src2Data_byte2_o[1]),

	.addr1wr_i     (destAddr_byte2[1]),
	.data1wr_i     (destData_byte2[1]),
	.we1_i         (destWe_byte2[1]),
`endif


`ifdef ISSUE_THREE_WIDE
	.addr4_i       (src1Addr_byte2[2]),
	.data4_o       (src1Data_byte2_o[2]),

	.addr5_i       (src2Addr_byte2[2]),
	.data5_o       (src2Data_byte2_o[2]),

	.addr2wr_i     (destAddr_byte2[2]),
	.data2wr_i     (destData_byte2[2]),
	.we2_i         (destWe_byte2[2]),
`endif


`ifdef ISSUE_FOUR_WIDE
	.addr6_i       (src1Addr_byte2[3]),
	.data6_o       (src1Data_byte2_o[3]),

	.addr7_i       (src2Addr_byte2[3]),
	.data7_o       (src2Data_byte2_o[3]),

	.addr3wr_i     (destAddr_byte2[3]),
	.data3wr_i     (destData_byte2[3]),
	.we3_i         (destWe_byte2[3]),
`endif

`ifdef ISSUE_FIVE_WIDE
	.addr8_i       (src1Addr_byte2[4]),
	.data8_o       (src1Data_byte2_o[4]),

	.addr9_i       (src2Addr_byte2[4]),
	.data9_o       (src2Data_byte2_o[4]),

	.addr4wr_i     (destAddr_byte2[4]),
	.data4wr_i     (destData_byte2[4]),
	.we4_i         (destWe_byte2[4]),
`endif

`ifdef ISSUE_SIX_WIDE
	.addr10_i      (src1Addr_byte2[5]),
	.data10_o      (src1Data_byte2_o[5]),

	.addr11_i      (src2Addr_byte2[5]),
	.data11_o      (src2Data_byte2_o[5]),

	.addr5wr_i     (destAddr_byte2[5]),
	.data5wr_i     (destData_byte2[5]),
	.we5_i         (destWe_byte2[5]),
`endif

`ifdef ISSUE_SEVEN_WIDE
	.addr12_i      (src1Addr_byte2[6]),
	.data12_o      (src1Data_byte2_o[6]),

	.addr13_i      (src2Addr_byte2[6]),
	.data13_o      (src2Data_byte2_o[6]),

	.addr6wr_i     (destAddr_byte2[6]),
	.data6wr_i     (destData_byte2[6]),
	.we6_i         (destWe_byte2[6]),
`endif

`ifdef ISSUE_EIGHT_WIDE
	.addr14_i      (src1Addr_byte2[7]),
	.data14_o      (src1Data_byte2_o[7]),

	.addr15_i      (src2Addr_byte2[7]),
	.data15_o      (src2Data_byte2_o[7]),

	.addr7wr_i     (destAddr_byte2[7]),
	.data7wr_i     (destData_byte2[7]),
	.we7_i         (destWe_byte2[7]),
`endif

`ifdef DYNAMIC_CONFIG
  .execLaneActive_i   (execLaneActive_i),
  .rfPartitionActive_i(rfPartitionActive_i),
`endif
       
`ifdef PRF_DEBUG_PORT
  .debugPRFRdAddr_i  (debugPRFAddr_shifted),
  .debugPRFRdData_o  (debugPRFRdData_byte2),
  .debugPRFWrData_i  (debugPRFWrData_i),
  .debugPRFWrEn_i    (debugPRFWrEn_byte2),
`endif //PRF_DEBUG_PORT
	
	.clk               (clk)
	//.reset             (reset && ~dbWe_i)
	);


`ifdef DYNAMIC_CONFIG
PRF_RAM_PARTITIONED #(
`else
PRF_RAM #(
`endif
  .RPORT             (2*`ISSUE_WIDTH),
  .WPORT             (`ISSUE_WIDTH),
	.DEPTH             (`SIZE_PHYSICAL_TABLE),
	.INDEX             (`SIZE_PHYSICAL_LOG),
	.WIDTH             (8)
	)

	PhyRegFile_byte3   (
	
	.addr0_i       (src1Addr_byte3[0]),
	.data0_o       (src1Data_byte3_o[0]),

	.addr1_i       (src2Addr_byte3[0]),
	.data1_o       (src2Data_byte3_o[0]),

	.addr0wr_i     (destAddr_byte3[0]), 
	.data0wr_i     (destData_byte3[0]),
	.we0_i         (destWe_byte3[0]),


`ifdef ISSUE_TWO_WIDE
	.addr2_i       (src1Addr_byte3[1]),
	.data2_o       (src1Data_byte3_o[1]),

	.addr3_i       (src2Addr_byte3[1]),
	.data3_o       (src2Data_byte3_o[1]),

	.addr1wr_i     (destAddr_byte3[1]),
	.data1wr_i     (destData_byte3[1]),
	.we1_i         (destWe_byte3[1]),
`endif


`ifdef ISSUE_THREE_WIDE
	.addr4_i       (src1Addr_byte3[2]),
	.data4_o       (src1Data_byte3_o[2]),

	.addr5_i       (src2Addr_byte3[2]),
	.data5_o       (src2Data_byte3_o[2]),

	.addr2wr_i     (destAddr_byte3[2]),
	.data2wr_i     (destData_byte3[2]),
	.we2_i         (destWe_byte3[2]),
`endif


`ifdef ISSUE_FOUR_WIDE
	.addr6_i       (src1Addr_byte3[3]),
	.data6_o       (src1Data_byte3_o[3]),

	.addr7_i       (src2Addr_byte3[3]),
	.data7_o       (src2Data_byte3_o[3]),

	.addr3wr_i     (destAddr_byte3[3]),
	.data3wr_i     (destData_byte3[3]),
	.we3_i         (destWe_byte3[3]),
`endif

`ifdef ISSUE_FIVE_WIDE
	.addr8_i       (src1Addr_byte3[4]),
	.data8_o       (src1Data_byte3_o[4]),

	.addr9_i       (src2Addr_byte3[4]),
	.data9_o       (src2Data_byte3_o[4]),

	.addr4wr_i     (destAddr_byte3[4]),
	.data4wr_i     (destData_byte3[4]),
	.we4_i         (destWe_byte3[4]),
`endif

`ifdef ISSUE_SIX_WIDE
	.addr10_i      (src1Addr_byte3[5]),
	.data10_o      (src1Data_byte3_o[5]),

	.addr11_i      (src2Addr_byte3[5]),
	.data11_o      (src2Data_byte3_o[5]),

	.addr5wr_i     (destAddr_byte3[5]),
	.data5wr_i     (destData_byte3[5]),
	.we5_i         (destWe_byte3[5]),
`endif

`ifdef ISSUE_SEVEN_WIDE
	.addr12_i      (src1Addr_byte3[6]),
	.data12_o      (src1Data_byte3_o[6]),

	.addr13_i      (src2Addr_byte3[6]),
	.data13_o      (src2Data_byte3_o[6]),

	.addr6wr_i     (destAddr_byte3[6]),
	.data6wr_i     (destData_byte3[6]),
	.we6_i         (destWe_byte3[6]),
`endif

`ifdef ISSUE_EIGHT_WIDE
	.addr14_i      (src1Addr_byte3[7]),
	.data14_o      (src1Data_byte3_o[7]),

	.addr15_i      (src2Addr_byte3[7]),
	.data15_o      (src2Data_byte3_o[7]),

	.addr7wr_i     (destAddr_byte3[7]),
	.data7wr_i     (destData_byte3[7]),
	.we7_i         (destWe_byte3[7]),
`endif

`ifdef DYNAMIC_CONFIG
  .execLaneActive_i   (execLaneActive_i),
  .rfPartitionActive_i(rfPartitionActive_i),
`endif
       
`ifdef PRF_DEBUG_PORT
  .debugPRFRdAddr_i  (debugPRFAddr_shifted),
  .debugPRFRdData_o  (debugPRFRdData_byte3),
  .debugPRFWrData_i  (debugPRFWrData_i),
  .debugPRFWrEn_i    (debugPRFWrEn_byte3),
`endif //PRF_DEBUG_PORT
	
	.clk               (clk)
	//.reset             (reset && ~dbWe_i)
	);


`ifdef DYNAMIC_CONFIG
PRF_RAM_PARTITIONED #(
`else
PRF_RAM #(
`endif
  .RPORT             (2*`ISSUE_WIDTH),
  .WPORT             (`ISSUE_WIDTH),
	.DEPTH             (`SIZE_PHYSICAL_TABLE),
	.INDEX             (`SIZE_PHYSICAL_LOG),
	.WIDTH             (8)
	)

	PhyRegFile_byte4   (
	
	.addr0_i       (src1Addr_byte4[0]),
	.data0_o       (src1Data_byte4_o[0]),

	.addr1_i       (src2Addr_byte4[0]),
	.data1_o       (src2Data_byte4_o[0]),

	.addr0wr_i     (destAddr_byte4[0]), 
	.data0wr_i     (destData_byte4[0]),
	.we0_i         (destWe_byte4[0]),


`ifdef ISSUE_TWO_WIDE
	.addr2_i       (src1Addr_byte4[1]),
	.data2_o       (src1Data_byte4_o[1]),

	.addr3_i       (src2Addr_byte4[1]),
	.data3_o       (src2Data_byte4_o[1]),

	.addr1wr_i     (destAddr_byte4[1]),
	.data1wr_i     (destData_byte4[1]),
	.we1_i         (destWe_byte4[1]),
`endif


`ifdef ISSUE_THREE_WIDE
	.addr4_i       (src1Addr_byte4[2]),
	.data4_o       (src1Data_byte4_o[2]),

	.addr5_i       (src2Addr_byte4[2]),
	.data5_o       (src2Data_byte4_o[2]),

	.addr2wr_i     (destAddr_byte4[2]),
	.data2wr_i     (destData_byte4[2]),
	.we2_i         (destWe_byte4[2]),
`endif


`ifdef ISSUE_FOUR_WIDE
	.addr6_i       (src1Addr_byte4[3]),
	.data6_o       (src1Data_byte4_o[3]),

	.addr7_i       (src2Addr_byte4[3]),
	.data7_o       (src2Data_byte4_o[3]),

	.addr3wr_i     (destAddr_byte4[3]),
	.data3wr_i     (destData_byte4[3]),
	.we3_i         (destWe_byte4[3]),
`endif

`ifdef ISSUE_FIVE_WIDE
	.addr8_i       (src1Addr_byte4[4]),
	.data8_o       (src1Data_byte4_o[4]),

	.addr9_i       (src2Addr_byte4[4]),
	.data9_o       (src2Data_byte4_o[4]),

	.addr4wr_i     (destAddr_byte4[4]),
	.data4wr_i     (destData_byte4[4]),
	.we4_i         (destWe_byte4[4]),
`endif

`ifdef ISSUE_SIX_WIDE
	.addr10_i      (src1Addr_byte4[5]),
	.data10_o      (src1Data_byte4_o[5]),

	.addr11_i      (src2Addr_byte4[5]),
	.data11_o      (src2Data_byte4_o[5]),

	.addr5wr_i     (destAddr_byte4[5]),
	.data5wr_i     (destData_byte4[5]),
	.we5_i         (destWe_byte4[5]),
`endif

`ifdef ISSUE_SEVEN_WIDE
	.addr12_i      (src1Addr_byte4[6]),
	.data12_o      (src1Data_byte4_o[6]),

	.addr13_i      (src2Addr_byte4[6]),
	.data13_o      (src2Data_byte4_o[6]),

	.addr6wr_i     (destAddr_byte4[6]),
	.data6wr_i     (destData_byte4[6]),
	.we6_i         (destWe_byte4[6]),
`endif

`ifdef ISSUE_EIGHT_WIDE
	.addr14_i      (src1Addr_byte4[7]),
	.data14_o      (src1Data_byte4_o[7]),

	.addr15_i      (src2Addr_byte4[7]),
	.data15_o      (src2Data_byte4_o[7]),

	.addr7wr_i     (destAddr_byte4[7]),
	.data7wr_i     (destData_byte4[7]),
	.we7_i         (destWe_byte4[7]),
`endif

`ifdef DYNAMIC_CONFIG
  .execLaneActive_i   (execLaneActive_i),
  .rfPartitionActive_i(rfPartitionActive_i),
`endif
       
`ifdef PRF_DEBUG_PORT
  .debugPRFRdAddr_i  (debugPRFAddr_shifted),
  .debugPRFRdData_o  (debugPRFRdData_byte4),
  .debugPRFWrData_i  (debugPRFWrData_i),
  .debugPRFWrEn_i    (debugPRFWrEn_byte4),
`endif //PRF_DEBUG_PORT
	
	.clk               (clk)
	//.reset             (reset && ~dbWe_i)
	);


`ifdef DYNAMIC_CONFIG
PRF_RAM_PARTITIONED #(
`else
PRF_RAM #(
`endif
  .RPORT             (2*`ISSUE_WIDTH),
  .WPORT             (`ISSUE_WIDTH),
	.DEPTH             (`SIZE_PHYSICAL_TABLE),
	.INDEX             (`SIZE_PHYSICAL_LOG),
	.WIDTH             (8)
	)

	PhyRegFile_byte5   (
	
	.addr0_i       (src1Addr_byte5[0]),
	.data0_o       (src1Data_byte5_o[0]),

	.addr1_i       (src2Addr_byte5[0]),
	.data1_o       (src2Data_byte5_o[0]),

	.addr0wr_i     (destAddr_byte5[0]), 
	.data0wr_i     (destData_byte5[0]),
	.we0_i         (destWe_byte5[0]),


`ifdef ISSUE_TWO_WIDE
	.addr2_i       (src1Addr_byte5[1]),
	.data2_o       (src1Data_byte5_o[1]),

	.addr3_i       (src2Addr_byte5[1]),
	.data3_o       (src2Data_byte5_o[1]),

	.addr1wr_i     (destAddr_byte5[1]),
	.data1wr_i     (destData_byte5[1]),
	.we1_i         (destWe_byte5[1]),
`endif


`ifdef ISSUE_THREE_WIDE
	.addr4_i       (src1Addr_byte5[2]),
	.data4_o       (src1Data_byte5_o[2]),

	.addr5_i       (src2Addr_byte5[2]),
	.data5_o       (src2Data_byte5_o[2]),

	.addr2wr_i     (destAddr_byte5[2]),
	.data2wr_i     (destData_byte5[2]),
	.we2_i         (destWe_byte5[2]),
`endif


`ifdef ISSUE_FOUR_WIDE
	.addr6_i       (src1Addr_byte5[3]),
	.data6_o       (src1Data_byte5_o[3]),

	.addr7_i       (src2Addr_byte5[3]),
	.data7_o       (src2Data_byte5_o[3]),

	.addr3wr_i     (destAddr_byte5[3]),
	.data3wr_i     (destData_byte5[3]),
	.we3_i         (destWe_byte5[3]),
`endif

`ifdef ISSUE_FIVE_WIDE
	.addr8_i       (src1Addr_byte5[4]),
	.data8_o       (src1Data_byte5_o[4]),

	.addr9_i       (src2Addr_byte5[4]),
	.data9_o       (src2Data_byte5_o[4]),

	.addr4wr_i     (destAddr_byte5[4]),
	.data4wr_i     (destData_byte5[4]),
	.we4_i         (destWe_byte5[4]),
`endif

`ifdef ISSUE_SIX_WIDE
	.addr10_i      (src1Addr_byte5[5]),
	.data10_o      (src1Data_byte5_o[5]),

	.addr11_i      (src2Addr_byte5[5]),
	.data11_o      (src2Data_byte5_o[5]),

	.addr5wr_i     (destAddr_byte5[5]),
	.data5wr_i     (destData_byte5[5]),
	.we5_i         (destWe_byte5[5]),
`endif

`ifdef ISSUE_SEVEN_WIDE
	.addr12_i      (src1Addr_byte5[6]),
	.data12_o      (src1Data_byte5_o[6]),

	.addr13_i      (src2Addr_byte5[6]),
	.data13_o      (src2Data_byte5_o[6]),

	.addr6wr_i     (destAddr_byte5[6]),
	.data6wr_i     (destData_byte5[6]),
	.we6_i         (destWe_byte5[6]),
`endif

`ifdef ISSUE_EIGHT_WIDE
	.addr14_i      (src1Addr_byte5[7]),
	.data14_o      (src1Data_byte5_o[7]),

	.addr15_i      (src2Addr_byte5[7]),
	.data15_o      (src2Data_byte5_o[7]),

	.addr7wr_i     (destAddr_byte5[7]),
	.data7wr_i     (destData_byte5[7]),
	.we7_i         (destWe_byte5[7]),
`endif

`ifdef DYNAMIC_CONFIG
  .execLaneActive_i   (execLaneActive_i),
  .rfPartitionActive_i(rfPartitionActive_i),
`endif
       
`ifdef PRF_DEBUG_PORT
  .debugPRFRdAddr_i  (debugPRFAddr_shifted),
  .debugPRFRdData_o  (debugPRFRdData_byte5),
  .debugPRFWrData_i  (debugPRFWrData_i),
  .debugPRFWrEn_i    (debugPRFWrEn_byte5),
`endif //PRF_DEBUG_PORT
	
	.clk               (clk)
	//.reset             (reset && ~dbWe_i)
	);


`ifdef DYNAMIC_CONFIG
PRF_RAM_PARTITIONED #(
`else
PRF_RAM #(
`endif
  .RPORT             (2*`ISSUE_WIDTH),
  .WPORT             (`ISSUE_WIDTH),
	.DEPTH             (`SIZE_PHYSICAL_TABLE),
	.INDEX             (`SIZE_PHYSICAL_LOG),
	.WIDTH             (8)
	)

	PhyRegFile_byte6   (
	
	.addr0_i       (src1Addr_byte6[0]),
	.data0_o       (src1Data_byte6_o[0]),

	.addr1_i       (src2Addr_byte6[0]),
	.data1_o       (src2Data_byte6_o[0]),

	.addr0wr_i     (destAddr_byte6[0]), 
	.data0wr_i     (destData_byte6[0]),
	.we0_i         (destWe_byte6[0]),


`ifdef ISSUE_TWO_WIDE
	.addr2_i       (src1Addr_byte6[1]),
	.data2_o       (src1Data_byte6_o[1]),

	.addr3_i       (src2Addr_byte6[1]),
	.data3_o       (src2Data_byte6_o[1]),

	.addr1wr_i     (destAddr_byte6[1]),
	.data1wr_i     (destData_byte6[1]),
	.we1_i         (destWe_byte6[1]),
`endif


`ifdef ISSUE_THREE_WIDE
	.addr4_i       (src1Addr_byte6[2]),
	.data4_o       (src1Data_byte6_o[2]),

	.addr5_i       (src2Addr_byte6[2]),
	.data5_o       (src2Data_byte6_o[2]),

	.addr2wr_i     (destAddr_byte6[2]),
	.data2wr_i     (destData_byte6[2]),
	.we2_i         (destWe_byte6[2]),
`endif


`ifdef ISSUE_FOUR_WIDE
	.addr6_i       (src1Addr_byte6[3]),
	.data6_o       (src1Data_byte6_o[3]),

	.addr7_i       (src2Addr_byte6[3]),
	.data7_o       (src2Data_byte6_o[3]),

	.addr3wr_i     (destAddr_byte6[3]),
	.data3wr_i     (destData_byte6[3]),
	.we3_i         (destWe_byte6[3]),
`endif

`ifdef ISSUE_FIVE_WIDE
	.addr8_i       (src1Addr_byte6[4]),
	.data8_o       (src1Data_byte6_o[4]),

	.addr9_i       (src2Addr_byte6[4]),
	.data9_o       (src2Data_byte6_o[4]),

	.addr4wr_i     (destAddr_byte6[4]),
	.data4wr_i     (destData_byte6[4]),
	.we4_i         (destWe_byte6[4]),
`endif

`ifdef ISSUE_SIX_WIDE
	.addr10_i      (src1Addr_byte6[5]),
	.data10_o      (src1Data_byte6_o[5]),

	.addr11_i      (src2Addr_byte6[5]),
	.data11_o      (src2Data_byte6_o[5]),

	.addr5wr_i     (destAddr_byte6[5]),
	.data5wr_i     (destData_byte6[5]),
	.we5_i         (destWe_byte6[5]),
`endif

`ifdef ISSUE_SEVEN_WIDE
	.addr12_i      (src1Addr_byte6[6]),
	.data12_o      (src1Data_byte6_o[6]),

	.addr13_i      (src2Addr_byte6[6]),
	.data13_o      (src2Data_byte6_o[6]),

	.addr6wr_i     (destAddr_byte6[6]),
	.data6wr_i     (destData_byte6[6]),
	.we6_i         (destWe_byte6[6]),
`endif

`ifdef ISSUE_EIGHT_WIDE
	.addr14_i      (src1Addr_byte6[7]),
	.data14_o      (src1Data_byte6_o[7]),

	.addr15_i      (src2Addr_byte6[7]),
	.data15_o      (src2Data_byte6_o[7]),

	.addr7wr_i     (destAddr_byte6[7]),
	.data7wr_i     (destData_byte6[7]),
	.we7_i         (destWe_byte6[7]),
`endif

`ifdef DYNAMIC_CONFIG
  .execLaneActive_i   (execLaneActive_i),
  .rfPartitionActive_i(rfPartitionActive_i),
`endif
       
`ifdef PRF_DEBUG_PORT
  .debugPRFRdAddr_i  (debugPRFAddr_shifted),
  .debugPRFRdData_o  (debugPRFRdData_byte6),
  .debugPRFWrData_i  (debugPRFWrData_i),
  .debugPRFWrEn_i    (debugPRFWrEn_byte6),
`endif //PRF_DEBUG_PORT
	
	.clk               (clk)
	//.reset             (reset && ~dbWe_i)
	);


`ifdef DYNAMIC_CONFIG
PRF_RAM_PARTITIONED #(
`else
PRF_RAM #(
`endif
  .RPORT             (2*`ISSUE_WIDTH),
  .WPORT             (`ISSUE_WIDTH),
	.DEPTH             (`SIZE_PHYSICAL_TABLE),
	.INDEX             (`SIZE_PHYSICAL_LOG),
	.WIDTH             (8)
	)

	PhyRegFile_byte7   (
	
	.addr0_i       (src1Addr_byte7[0]),
	.data0_o       (src1Data_byte7_o[0]),

	.addr1_i       (src2Addr_byte7[0]),
	.data1_o       (src2Data_byte7_o[0]),

	.addr0wr_i     (destAddr_byte7[0]), 
	.data0wr_i     (destData_byte7[0]),
	.we0_i         (destWe_byte7[0]),


`ifdef ISSUE_TWO_WIDE
	.addr2_i       (src1Addr_byte7[1]),
	.data2_o       (src1Data_byte7_o[1]),

	.addr3_i       (src2Addr_byte7[1]),
	.data3_o       (src2Data_byte7_o[1]),

	.addr1wr_i     (destAddr_byte7[1]),
	.data1wr_i     (destData_byte7[1]),
	.we1_i         (destWe_byte7[1]),
`endif


`ifdef ISSUE_THREE_WIDE
	.addr4_i       (src1Addr_byte7[2]),
	.data4_o       (src1Data_byte7_o[2]),

	.addr5_i       (src2Addr_byte7[2]),
	.data5_o       (src2Data_byte7_o[2]),

	.addr2wr_i     (destAddr_byte7[2]),
	.data2wr_i     (destData_byte7[2]),
	.we2_i         (destWe_byte7[2]),
`endif


`ifdef ISSUE_FOUR_WIDE
	.addr6_i       (src1Addr_byte7[3]),
	.data6_o       (src1Data_byte7_o[3]),

	.addr7_i       (src2Addr_byte7[3]),
	.data7_o       (src2Data_byte7_o[3]),

	.addr3wr_i     (destAddr_byte7[3]),
	.data3wr_i     (destData_byte7[3]),
	.we3_i         (destWe_byte7[3]),
`endif

`ifdef ISSUE_FIVE_WIDE
	.addr8_i       (src1Addr_byte7[4]),
	.data8_o       (src1Data_byte7_o[4]),

	.addr9_i       (src2Addr_byte7[4]),
	.data9_o       (src2Data_byte7_o[4]),

	.addr4wr_i     (destAddr_byte7[4]),
	.data4wr_i     (destData_byte7[4]),
	.we4_i         (destWe_byte7[4]),
`endif

`ifdef ISSUE_SIX_WIDE
	.addr10_i      (src1Addr_byte7[5]),
	.data10_o      (src1Data_byte7_o[5]),

	.addr11_i      (src2Addr_byte7[5]),
	.data11_o      (src2Data_byte7_o[5]),

	.addr5wr_i     (destAddr_byte7[5]),
	.data5wr_i     (destData_byte7[5]),
	.we5_i         (destWe_byte7[5]),
`endif

`ifdef ISSUE_SEVEN_WIDE
	.addr12_i      (src1Addr_byte7[6]),
	.data12_o      (src1Data_byte7_o[6]),

	.addr13_i      (src2Addr_byte7[6]),
	.data13_o      (src2Data_byte7_o[6]),

	.addr6wr_i     (destAddr_byte7[6]),
	.data6wr_i     (destData_byte7[6]),
	.we6_i         (destWe_byte7[6]),
`endif

`ifdef ISSUE_EIGHT_WIDE
	.addr14_i      (src1Addr_byte7[7]),
	.data14_o      (src1Data_byte7_o[7]),

	.addr15_i      (src2Addr_byte7[7]),
	.data15_o      (src2Data_byte7_o[7]),

	.addr7wr_i     (destAddr_byte7[7]),
	.data7wr_i     (destData_byte7[7]),
	.we7_i         (destWe_byte7[7]),
`endif

`ifdef DYNAMIC_CONFIG
  .execLaneActive_i   (execLaneActive_i),
  .rfPartitionActive_i(rfPartitionActive_i),
`endif
       
`ifdef PRF_DEBUG_PORT
  .debugPRFRdAddr_i  (debugPRFAddr_shifted),
  .debugPRFRdData_o  (debugPRFRdData_byte7),
  .debugPRFWrData_i  (debugPRFWrData_i),
  .debugPRFWrEn_i    (debugPRFWrEn_byte7),
`endif //PRF_DEBUG_PORT
	
	.clk               (clk)
	//.reset             (reset && ~dbWe_i)
	);


endmodule

