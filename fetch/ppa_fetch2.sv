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


module ppa_fetch2
(

    input                            clk,
    input                            reset,
    input                            resetFetch_i, // Resets everything except Cache

  `ifdef DYNAMIC_CONFIG
    input [`FETCH_WIDTH-1:0]         fetchLaneActive_i,
  	output reg [`FETCH_WIDTH-1:0]    valid_bundle_o,
  `endif  
  
  	input                            flush_i,
  	input                            stall_i,
  
  	input                            fs1Ready_i,
  	input  [1:0]                     predCounter_i [0:`FETCH_WIDTH-1],
  	input      fs2Pkt                fs2Packet_i   [0:`FETCH_WIDTH-1],
  

  	input                            instBufferFull_i,

    input  [`SIZE_PC-1:0]            addrRAS_i,


    input  [`SIZE_PC-1:0]            exeCtrlPC_i,
    input  [`BRANCH_TYPE_LOG-1:0]        exeCtrlType_i,
    input  [`SIZE_CTI_LOG-1:0]       exeCtiID_i,
    input  [`SIZE_PC-1:0]            exeCtrlNPC_i,
    input                            exeCtrlDir_i,
    input                            exeCtrlValid_i,
    input  [`COMMIT_WIDTH-1:0]       commitCti_i,

    output decPkt                    decPacket_o [0:`FETCH_WIDTH-1],

    output                           fs2RecoverFlag_o,
    output [`SIZE_PC-1:0]            fs2RecoverPC_o,
    output                           fs2MissedReturn_o,
    output                           fs2MissedCall_o,
    output [`SIZE_PC-1:0]            fs2CallPC_o,

    output [`SIZE_PC-1:0]            updatePC_o,
    output [`SIZE_PC-1:0]            updateNPC_o,
    output [`BRANCH_TYPE_LOG-1:0]        updateCtrlType_o,
    output                           updateDir_o,
    output [1:0]                     updateCounter_o,
    output                           updateEn_o,
    output                           fs2Ready_o,

    // Some common inputs needed in many stages
    input                            recoverFlag_i,
    input  [`SIZE_PC-1:0]            recoverPC_i,

    input                            exceptionFlag_i,
    input  [`SIZE_PC-1:0]            exceptionPC_i


);

  	logic                       fs1Ready_l1;
  	logic [1:0]                 predCounter_l1 [0:`FETCH_WIDTH-1];
  	fs2Pkt                      fs2Packet_l1   [0:`FETCH_WIDTH-1];
    wire                        ctiQueueFull;


 /**********************************************************************************
 *  "fs1fs2" module is the pipeline stage between Fetch Stage-1 and Fetch
 *  Stage-2.
 **********************************************************************************/

Fetch1Fetch2 fs1fs2(
	.clk                  (clk),
	.reset                (reset),

	.flush_i              (fs2RecoverFlag_o | recoverFlag_i | exceptionFlag_i | resetFetch_i),
  //TODO: stallFetch might not be needed as
  // it is part of instBufferFull
`ifdef DYNAMIC_CONFIG
  .laneActive_i         (fetchLaneActive_i),
	.valid_bundle_o       (valid_bundle_o),
`endif
	.stall_i              (instBufferFull_i | ctiQueueFull),

	.fs1Ready_i           (fs1Ready_i),
	.predCounter_i        (predCounter_i),
	.fs2Packet_i          (fs2Packet_i),

	.fs1Ready_o           (fs1Ready_l1),
	.predCounter_o        (predCounter_l1),
	.fs2Packet_o          (fs2Packet_l1)
	);




 /**********************************************************************************
 *  "fetch2" module is the second stage of the instruction fetching process. This
 *  module contains small decode logic for control instructions and verifies the
 *  target address provided by BTB or RAS in "fetch1".
 *
 *  The module also contains CTI Queue structure, which keeps tracks of number of
 *  branch instructions in the processor.
 **********************************************************************************/
// NOTE: Clamping of valid bits is not necessary as the corresponding lane in
// the following pipeline register and decode stage will also be gated and
// valid bits from Decode will be clamped. Note that valid bit from decode
// needs to be clamped as Instruction buffer is more or less a monolithic
// piece of logic and valid clamping is necessary for correctness purposes.

// NOTE: Not much except the predecode can be converted to per lane logic.
// Hence, just gate the predecodes and leave rest of the logic as a single
// blob.
FetchStage2 fs2(

	.clk                  (clk),
	.reset                (reset | resetFetch_i),

	.recoverFlag_i        (recoverFlag_i),
	.exceptionFlag_i      (exceptionFlag_i),

`ifdef DYNAMIC_CONFIG  
  .fetchLaneActive_i    (fetchLaneActive_i),
`endif

	.stall_i              (instBufferFull_i),

	.fs1Ready_i           (fs1Ready_l1),
	.addrRAS_i            (addrRAS_i),
	.predCounter_i        (predCounter_l1),

	.fs2Packet_i          (fs2Packet_l1),

	.decPacket_o          (decPacket_o),

	.exeCtrlPC_i          (exeCtrlPC_i),
	.exeCtrlType_i        (exeCtrlType_i),
	.exeCtiID_i           (exeCtiID_i),
	.exeCtrlNPC_i         (exeCtrlNPC_i),
	.exeCtrlDir_i         (exeCtrlDir_i),
	.exeCtrlValid_i       (exeCtrlValid_i),

	.commitCti_i          (commitCti_i),

	.fs2RecoverFlag_o     (fs2RecoverFlag_o),
	.fs2RecoverPC_o       (fs2RecoverPC_o),
	.fs2MissedReturn_o    (fs2MissedReturn_o),
	.fs2MissedCall_o      (fs2MissedCall_o),
	.fs2CallPC_o          (fs2CallPC_o),

	.updatePC_o           (updatePC_o),
	.updateNPC_o          (updateNPC_o),
	.updateCtrlType_o     (updateCtrlType_o),
	.updateDir_o          (updateDir_o),
	.updateCounter_o      (updateCounter_o),
	.updateEn_o           (updateEn_o),

	.fs2Ready_o           (fs2Ready_o),
	.ctiQueueFull_o       (ctiQueueFull)
	);




endmodule
