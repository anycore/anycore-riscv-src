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


module ppa_rename
(

    input                            clk,
    input                            reset,

   	// Flush the piepeline if there is Exception/Mis-prediction
   	input                            flush_i,
   
   	input                            stallfrontEnd_i,
   
   	input                            instBufferReady_i,
   
   	input  renPkt                    renPacket_i [0:`DISPATCH_WIDTH-1],
   

  `ifdef DYNAMIC_CONFIG  
	  output reg [`DISPATCH_WIDTH-1:0] valid_bundle_o,
    input [`COMMIT_WIDTH-1:0]        commitLaneActive_i,
    input [`FETCH_WIDTH-1:0]         fetchLaneActive_i,
    input [`DISPATCH_WIDTH-1:0]      dispatchLaneActive_i,
    input [`NUM_PARTS_AL-1:0]        alPartitionActive_i,
    input                            reconfigureCore_i,
    input                            reconfigureFlag_i,
  `endif  
  
  	output disPkt                    disPacket_o    [0:`DISPATCH_WIDTH-1],
  
  	output phys_reg                  phyDest_o      [0:`DISPATCH_WIDTH-1],
  
  	input  phys_reg                  freedPhyReg_i  [0:`COMMIT_WIDTH-1],
  
  	input                            repairFlag_i,
  
  	input  [`SIZE_RMT_LOG-1:0]       repairAddr_i [0:`N_REPAIR_PACKETS-1],
  	input  [`SIZE_PHYSICAL_LOG-1:0]  repairData_i [0:`N_REPAIR_PACKETS-1],
  `ifdef PERF_MON
   	output [`SIZE_FREE_LIST_LOG-1:0] freeListCnt_o,
  `endif
  
  	output                           freeListEmpty_o,
  	output                           renameReady_o,

    // Some common inputs needed in many stages
    input                            recoverFlag_i,
    input  [`SIZE_PC-1:0]            recoverPC_i,

    input                            exceptionFlag_i,
    input  [`SIZE_PC-1:0]            exceptionPC_i,


  	input                            instBufferFull_i,
    input                            ctiQueueFull_i
);

   	// For the Rename stage
    logic                       instBufferReady_l1;
  	renPkt                      renPacket_l1    [0:`DISPATCH_WIDTH-1];

 /**********************************************************************************
 *  "InstBufRename" module is the pipeline stage between Instruction buffer and
 *  Rename Stage.
 **********************************************************************************/

InstBufRename instBufRen (
	.clk                  (clk),
	.reset                (reset),

`ifdef DYNAMIC_CONFIG
  .laneActive_i         (dispatchLaneActive_i),
	.valid_bundle_o       (valid_bundle_o),
	.flush_i              (recoverFlag_i | exceptionFlag_i | reconfigureFlag_i),
`else  
	.flush_i              (recoverFlag_i | exceptionFlag_i),
`endif

	.stall_i              (freeListEmpty_o | stallfrontEnd_i | repairFlag_i),
	.instBufferReady_i    (instBufferReady_i),

	.renPacket_i          (renPacket_i),
	.renPacket_o          (renPacket_l1),

	.instBufferReady_o    (instBufferReady_l1)
	);



 /**********************************************************************************
 *  "rename" module remaps logical source and destination registers to physical
 *  source and destination registers.
 *  This module contains Rename Map Table and Speculative Free List structures.
 **********************************************************************************/
`ifdef DYNAMIC_CONFIG
  logic [`NUM_PARTS_RF-1:0] rfPartitionActive = {alPartitionActive_i,2'b1};
`endif

// NOTE: Rename converted to per lane modular logic.
Rename rename (
	.clk                  (clk),
	.reset                (reset | exceptionFlag_i),

`ifdef DYNAMIC_CONFIG  
  .commitLaneActive_i   (commitLaneActive_i),
  .dispatchLaneActive_i (dispatchLaneActive_i),
  .rfPartitionActive_i  (rfPartitionActive),
  .reconfigureCore_i    (reconfigureFlag_i),
`endif  

	.stall_i              (stallfrontEnd_i),

	.decodeReady_i        (instBufferReady_l1),

	.renPacket_i          (renPacket_l1),
	.disPacket_o          (disPacket_o),

	.phyDest_o            (phyDest_o),

	.freedPhyReg_i        (freedPhyReg_i),

	.recoverFlag_i        (recoverFlag_i),
	.repairFlag_i         (repairFlag_i),
	.repairAddr_i         (repairAddr_i),
	.repairData_i         (repairData_i),

`ifdef PERF_MON
	.freeListCnt_o        (freeListCnt_o),
`endif

	.freeListEmpty_o      (freeListEmpty_o),
	.renameReady_o        (renameReady_o)
	);


endmodule
