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

module ppa_execute_m
  (

  /* Ports for physical register file */
	input                                 clk,
	input                                 reset,

`ifdef DYNAMIC_CONFIG  
  input [`ISSUE_WIDTH-1:0]              execLaneActive_i,
  input [`NUM_PARTS_AL-1:0]             alPartitionActive_i,
`endif  

	/* INPUTS COMING FROM THE R-R STAGE */
	input [`SIZE_PHYSICAL_LOG-1:0]        phySrc1_i [0:`ISSUE_WIDTH-1],
	input [`SIZE_PHYSICAL_LOG-1:0]        phySrc2_i [0:`ISSUE_WIDTH-1],

	/* INPUTS COMING FROM THE WRITEBACK STAGE */
	input  bypassPkt                      bypassPacket_i   [0:`ISSUE_WIDTH-1],

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
	output [`SRAM_DATA_WIDTH-1:0]         debugPRFRdData_o,

  /* Ports for Issueq2RegRead */
`ifdef DYNAMIC_CONFIG
	output reg                            valid_bundle_o,
`endif
	/* Payload and Destination of incoming instructions */
	input  payloadPkt                     rrPacket_i,

  /* Ports for the execution lane */
	// inputs from the lsu coming to the writeback stage
	input  wbPkt                          wbPacket_i,

	input  ldVioPkt                       ldVioPacket_i,
	output ldVioPkt                       ldVioPacket_o,

	// bypass going from this pipe to other pipes
	output bypassPkt                      bypassPacket_o,

	// the output from the agen going to the lsu via the agenlsu latch
	output memPkt                         memPacket_o,

	// output going to the active list from the load store pipe
	output ctrlPkt                        ctrlPacket_o,

  // Some common inputs needed in many stages

  input                                 loadNewConfig_i,

  input                                 recoverFlag_i,
  input  [`SIZE_PC-1:0]                 recoverPC_i,

  input                                 exceptionFlag_i,
  input  [`SIZE_PC-1:0]                 exceptionPC_i

  );

  	/* INPUTS COMING FROM THE R-R STAGE */
  	reg [`SIZE_PHYSICAL_LOG-1:0]        phySrc1 [0:`ISSUE_WIDTH-1];
  	reg [`SIZE_PHYSICAL_LOG-1:0]        phySrc2 [0:`ISSUE_WIDTH-1];
  
  	/* INPUTS COMING FROM THE WRITEBACK STAGE */
  	bypassPkt                           bypassPacket [0:`ISSUE_WIDTH-1];
  
  	payloadPkt                          rrPacket_l1;

    always_comb
    begin
      int i;
      // Lane 0 signals connect directly to the execution lane instance
      for(i = 1;i < `ISSUE_WIDTH;i++)
      begin
        bypassPacket[i] = bypassPacket_i[i];
        phySrc1[i]      = phySrc1_i[i];
        phySrc2[i]      = phySrc2_i[i];
      end
    end

/************************************************************************************
* "iq_regread" module is the pipeline stage between Issue Queue stage and physical
* register file read stage.
*
* This module also interfaces with RSR.
*
************************************************************************************/
IssueQRegRead #(.NUM_LANES(1)) iq_regread (

	.clk                  (clk),
	.reset                (reset),

`ifdef DYNAMIC_CONFIG
  .laneActive_i         (execLaneActive_i[0]),
	.flush_i              (recoverFlag_i | exceptionFlag_i | loadNewConfig_i),
`else
	.flush_i              (recoverFlag_i | exceptionFlag_i),
`endif

`ifdef DYNAMIC_CONFIG
  .valid_bundle_o       (valid_bundle_o),
`endif  
	.rrPacket_i           (rrPacket_i),
	.rrPacket_o           (rrPacket_l1)
);

`ifdef DYNAMIC_CONFIG
  logic [`NUM_PARTS_RF-1:0] rfPartitionActive = {alPartitionActive_i,2'b1};
`endif


// NOTE: Not much opportunity for per lane logic except for
// gating the decoder and output muxes. This has to be decided
// based on power numbers.
PhyRegFile registerfile (

	.clk(clk),
	.reset(reset),

`ifdef DYNAMIC_CONFIG  
  .execLaneActive_i (execLaneActive_i),
  .rfPartitionActive_i(rfPartitionActive),
`endif  

`ifdef DYNAMIC_CONFIG
	/* inputs coming from the r-r stage */
	.phySrc1_i  (phySrc1),
	.phySrc2_i  (phySrc2),
	// inputs coming from the writeback stage
	.bypassPacket_i(bypassPacket),
`else
	/* inputs coming from the r-r stage */
	.phySrc1_i  (phySrc1),
	.phySrc2_i  (phySrc2),
	// inputs coming from the writeback stage
	.bypassPacket_i(bypassPacket),
`endif


	// outputs going to the r-r stage
	.src1Data_byte0_o(src1Data_byte0_o),
	.src1Data_byte1_o(src1Data_byte1_o),
	.src1Data_byte2_o(src1Data_byte2_o),
	.src1Data_byte3_o(src1Data_byte3_o),
	.src1Data_byte4_o(src1Data_byte4_o),
	.src1Data_byte5_o(src1Data_byte5_o),
	.src1Data_byte6_o(src1Data_byte6_o),
	.src1Data_byte7_o(src1Data_byte7_o),

	.src2Data_byte0_o(src2Data_byte0_o),
	.src2Data_byte1_o(src2Data_byte1_o),
	.src2Data_byte2_o(src2Data_byte2_o),
	.src2Data_byte3_o(src2Data_byte3_o),
	.src2Data_byte4_o(src2Data_byte4_o),
	.src2Data_byte5_o(src2Data_byte5_o),
	.src2Data_byte6_o(src2Data_byte6_o),
	.src2Data_byte7_o(src2Data_byte7_o),

	/* Initialize the PRF from top */
	.dbAddr_i        (dbAddr_i),
	.dbData_i        (dbData_i),
	.dbWe_i          (dbWe_i),
        
  .debugPRFAddr_i  (debugPRFAddr_i),
  .debugPRFWrData_i(debugPRFWrData_i),             
  .debugPRFWrEn_i  (debugPRFWrEn_i),
  .debugPRFRdData_o(debugPRFRdData_o)

);


ExecutionPipe_M 
	exePipe0 (

	.clk(clk),
	.reset(reset),
	.recoverFlag_i(recoverFlag_i),
	.exceptionFlag_i(exceptionFlag_i),

`ifdef DYNAMIC_CONFIG  
  .laneActive_i   (execLaneActive_i[0]),
`endif  

	// inputs coming from the register file
	.src1Data_byte0_i(src1Data_byte0_o[0]),
	.src1Data_byte1_i(src1Data_byte1_o[0]),
	.src1Data_byte2_i(src1Data_byte2_o[0]),
	.src1Data_byte3_i(src1Data_byte3_o[0]),
	.src1Data_byte4_i(src1Data_byte4_o[0]),
	.src1Data_byte5_i(src1Data_byte5_o[0]),
	.src1Data_byte6_i(src1Data_byte6_o[0]),
	.src1Data_byte7_i(src1Data_byte7_o[0]),

	.src2Data_byte0_i(src2Data_byte0_o[0]),
	.src2Data_byte1_i(src2Data_byte1_o[0]),
	.src2Data_byte2_i(src2Data_byte2_o[0]),
	.src2Data_byte3_i(src2Data_byte3_o[0]),
	.src2Data_byte4_i(src2Data_byte4_o[0]),
	.src2Data_byte5_i(src2Data_byte5_o[0]),
	.src2Data_byte6_i(src2Data_byte6_o[0]),
	.src2Data_byte7_i(src2Data_byte7_o[0]),

	// input from the issue queue going to the reg read stage
	.rrPacket_i(rrPacket_l1),

	// bypasses coming from adjacent execution pipes
	.bypassPacket_i (bypassPacket),

	// inputs from the lsu coming to the writeback stage
	.wbPacket_i(wbPacket_i),
	.ldVioPacket_i(ldVioPacket_i),
	.ldVioPacket_o(ldVioPacket_o),

	// bypass going from this pipe to other pipes
	.bypassPacket_o(bypassPacket[0]),

	// the output from the agen going to the lsu via the agenlsu latch
	.memPacket_o(memPacket_o),

	// output going to the active list from the load store pipe
	.ctrlPacket_o   (ctrlPacket_o),

	// source operands extracted from the packet going to the physical register file
	.phySrc1_o(phySrc1[0]),
	.phySrc2_o(phySrc2[0])

);

endmodule
