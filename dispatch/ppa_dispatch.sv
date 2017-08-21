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

module ppa_dispatch

(

	input                                   clk,
	input                                   reset,

`ifdef DYNAMIC_CONFIG  
  input [`FETCH_WIDTH-1:0]                fetchLaneActive_i,
  input [`DISPATCH_WIDTH-1:0]             dispatchLaneActive_i,
  input [`ISSUE_WIDTH-1:0]                execLaneActive_i,
  input [`ISSUE_WIDTH-1:0]                saluLaneActive_i,
  input [`ISSUE_WIDTH-1:0]                caluLaneActive_i,
  input [`NUM_PARTS_AL-1:0]               alPartitionActive_i,
  input [`NUM_PARTS_IQ-1:0]               iqPartitionActive_i,
  input [`STRUCT_PARTS_LSQ-1:0]           lsqPartitionActive_i,
  // Resets the pre-steering logic so that existing lane assignments do
  // not affect the lane assignments post reconfiguration.
  input                                   reconfigureCore_i,    
`endif  

	/* Rename stage is ready with new instructions */
	input                                   loadViolation_i,

  // TODO: Modify issue queue, active list and lsq for the number of write ports
  // depending upon how many dispatch lanes are active.
	output iqPkt                            iqPacket_o  [0:`DISPATCH_WIDTH-1],
	output alPkt                            alPacket_o  [0:`DISPATCH_WIDTH-1],
	output lsqPkt                           lsqPacket_o [0:`DISPATCH_WIDTH-1],

	/* Current count of instructions in Load Queue */
	input  [`SIZE_LSQ_LOG:0]                loadQueueCnt_i,

	/* Current count of instructions in Store Queue */
	input  [`SIZE_LSQ_LOG:0]                storeQueueCnt_i,

	/* Current count of instructions in Issue Queue */
	input  [`SIZE_ISSUEQ_LOG:0]             issueQueueCnt_i,

	/* Current count of instructions in Active List */
	input  [`SIZE_ACTIVELIST_LOG:0]         activeListCnt_i,

`ifdef PERF_MON
	output                                  loadStall_o,
	output                                  storeStall_o,
	output                                  iqStall_o,
	output                                  alStall_o,
`endif
	/******************************************************************
	*  If there is no empty space in Issue Queue or Active List or
	*  Load-Store Queue, then backEndReady_o is low. Instructions
	*  reading from the Instructrion Queue should be stalled. Also
	*  Front End pipe stages (Decode and Rename) after InstructionBuffer
	*  should be stalled.
	*******************************************************************/
	output                                  backEndReady_o,
	output                                  stallfrontEnd_o,


  // Ports for RenameDispatch pipeline register

`ifdef DYNAMIC_CONFIG
	output reg [`DISPATCH_WIDTH-1:0]        valid_bundle_o,
`endif

	input                                   renameReady_i,
	input  disPkt                           disPacket_i [0:`DISPATCH_WIDTH-1],

  // Some common inputs needed in many stages

  input                                   recoverFlag_i,
  input  [`SIZE_PC-1:0]                   recoverPC_i,

  input                                   exceptionFlag_i,
  input  [`SIZE_PC-1:0]                   exceptionPC_i


);

	disPkt                           disPacket_l1 [0:`DISPATCH_WIDTH-1];
  wire                             renameReady_l1;

RenameDispatch renDis (
	.clk                   (clk),
	.reset                 (reset),

`ifdef DYNAMIC_CONFIG  
  .laneActive_i          (dispatchLaneActive_i),  
  .valid_bundle_o        (valid_bundle_o),
	.flush_i               (recoverFlag_i | exceptionFlag_i | reconfigureCore_i),
`else
	.flush_i               (recoverFlag_i | exceptionFlag_i),
`endif  
	.stall_i               (stallfrontEnd_o),

	.renameReady_i         (renameReady_i),

	.disPacket_i           (disPacket_i),
	.disPacket_o           (disPacket_l1),

	.renameReady_o         (renameReady_l1)
	);



/***********************************************************************************
* "dispatch" module dispatches renamed packets to Issue Queue, Active List, and
* Load-Store queue.
*
***********************************************************************************/

// NOTE: Most of the logic is either monolithic control logic or
// simple per lane assigns. No need to do complex per lane gating.
// Everything can be in always on domain. 
// Dispatch probably also has most correctness logic.
Dispatch dispatch (
	.clk                   (clk),
	.reset                 (reset),

`ifdef DYNAMIC_CONFIG  
  .dispatchLaneActive_i  (dispatchLaneActive_i),
  .execLaneActive_i      (execLaneActive_i),
  .saluLaneActive_i      (saluLaneActive_i),
  .caluLaneActive_i      (caluLaneActive_i),
  .alPartitionActive_i   (alPartitionActive_i),
  .iqPartitionActive_i   (iqPartitionActive_i),
  .lsqPartitionActive_i  (lsqPartitionActive_i),
  .reconfigureCore_i     (reconfigureCore_i),    
`endif  

	.renameReady_i         (renameReady_l1),

	.recoverFlag_i         (recoverFlag_i),
	.recoverPC_i           (recoverPC_i),
	.loadViolation_i       (loadViolation_i),

	.disPacket_i           (disPacket_l1),

	.iqPacket_o            (iqPacket_o),
	.alPacket_o            (alPacket_o),
	.lsqPacket_o           (lsqPacket_o),

	.loadQueueCnt_i        (loadQueueCnt_i ),
	.storeQueueCnt_i       (storeQueueCnt_i),
	.issueQueueCnt_i       (issueQueueCnt_i),
	.activeListCnt_i       (activeListCnt_i),

`ifdef PERF_MON
  .loadStall_o           (loadStall_o),
  .storeStall_o          (storeStall_o),
  .iqStall_o             (iqStall_o),
  .alStall_o             (alStall_o),
`endif

	.backEndReady_o        (backEndReady_o),
	.stallfrontEnd_o       (stallfrontEnd_o)
);

endmodule
