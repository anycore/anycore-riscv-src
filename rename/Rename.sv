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

module Rename(
	input                             clk,
	input                             reset,
	input                             resetRams_i,

`ifdef DYNAMIC_CONFIG  
  input [`COMMIT_WIDTH-1:0]         commitLaneActive_i,
  input [`DISPATCH_WIDTH-1:0]       dispatchLaneActive_i,
  input [`NUM_PARTS_RF-1:0]         rfPartitionActive_i,
  input                             reconfigureCore_i,
`endif  

	input                             stall_i,

	input                             instBufferReady_i,

	input  renPkt                     renPacket_i    [0:`DISPATCH_WIDTH-1],
	output disPkt                     disPacket_o    [0:`DISPATCH_WIDTH-1],

	output phys_reg                   phyDest_o      [0:`DISPATCH_WIDTH-1],

	input  phys_reg                   freedPhyReg_i  [0:`COMMIT_WIDTH-1],

	/* input  recoverPkt                 repairPacket_i [0:`COMMIT_WIDTH-1], */

	input                             recoverFlag_i,
	input                             repairFlag_i,

	input  [`SIZE_RMT_LOG-1:0]        repairAddr_i [0:`N_REPAIR_PACKETS-1],
	input  [`SIZE_PHYSICAL_LOG-1:0]   repairData_i [0:`N_REPAIR_PACKETS-1],
`ifdef PERF_MON
 	output [`SIZE_FREE_LIST_LOG-1:0]  freeListCnt_o,
`endif

	output reg                        freeListEmpty_o,
	output reg                        renameReady_o,
  output                            rmtRamReady_o,
  output                            flRamReady_o
	);


log_reg                                logDest     [0:`DISPATCH_WIDTH-1];
log_reg                                logSrc1     [0:`DISPATCH_WIDTH-1];
log_reg                                logSrc2     [0:`DISPATCH_WIDTH-1];

phys_reg                               phyDest     [0:`DISPATCH_WIDTH-1];
phys_reg                               phySrc1     [0:`DISPATCH_WIDTH-1];
phys_reg                               phySrc2     [0:`DISPATCH_WIDTH-1];

reg  [`SIZE_PHYSICAL_LOG-1:0]          freePhyReg  [0:`DISPATCH_WIDTH-1];
reg                                    reqPhyReg   [0:`DISPATCH_WIDTH-1];

wire                                   freeListEmpty;

`ifdef DYNAMIC_CONFIG  
  wire rmtReady;
  wire freeListReady;
`endif


//* Create Rename Packets
always_comb
begin
	int i;
	for (i = 0; i < `DISPATCH_WIDTH; i++)
	begin
		logDest[i].reg_id               = renPacket_i[i].logDest;
		logDest[i].valid                = renPacket_i[i].logDestValid;
		logSrc1[i].reg_id               = renPacket_i[i].logSrc1;
		logSrc1[i].valid                = renPacket_i[i].logSrc1Valid;
		logSrc2[i].reg_id               = renPacket_i[i].logSrc2;
		logSrc2[i].valid                = renPacket_i[i].logSrc2Valid;
	end

	for (i = 0; i < `DISPATCH_WIDTH; i++)
	begin
		disPacket_o[i].seqNo            = renPacket_i[i].seqNo;
		disPacket_o[i].exceptionCause   = renPacket_i[i].exceptionCause;
		disPacket_o[i].exception        = renPacket_i[i].exception;
		disPacket_o[i].pc               = renPacket_i[i].pc;
		disPacket_o[i].inst             = renPacket_i[i].inst;
		disPacket_o[i].fu               = renPacket_i[i].fu;
		disPacket_o[i].logDest          = renPacket_i[i].logDest;

// TODO: This validation logic may not be required as
// the subsequent pipeline registers are gated anyways
		disPacket_o[i].phyDest          = phyDest[i].reg_id;
		disPacket_o[i].phyDestValid     = phyDest[i].valid;
		disPacket_o[i].phySrc1          = phySrc1[i].reg_id;
		disPacket_o[i].phySrc1Valid     = phySrc1[i].valid;
		disPacket_o[i].phySrc2          = phySrc2[i].reg_id;
		disPacket_o[i].phySrc2Valid     = phySrc2[i].valid;
		disPacket_o[i].immed            = renPacket_i[i].immed;
		disPacket_o[i].immedValid       = renPacket_i[i].immedValid;
		disPacket_o[i].ldstSize         = renPacket_i[i].ldstSize;
		disPacket_o[i].ctrlType         = renPacket_i[i].ctrlType;
		disPacket_o[i].ctiID            = renPacket_i[i].ctiID;
		disPacket_o[i].predNPC          = renPacket_i[i].predNPC;
		disPacket_o[i].predDir          = renPacket_i[i].predDir;
		disPacket_o[i].isLoad           = renPacket_i[i].isLoad;
		disPacket_o[i].isStore          = renPacket_i[i].isStore;
		disPacket_o[i].isCSR            = renPacket_i[i].isCSR;
		disPacket_o[i].isScall          = renPacket_i[i].isScall;
		disPacket_o[i].isSbreak         = renPacket_i[i].isSbreak;
		disPacket_o[i].isSret           = renPacket_i[i].isSret;   
		disPacket_o[i].skipIQ           = renPacket_i[i].skipIQ;   
		disPacket_o[i].valid            = renameReady_o ? renPacket_i[i].valid : 1'b0; //Squash if rename is not ready
	end
end


/***********************************************************************************
* Outputs 
***********************************************************************************/

/* Send the physical destination register to be marked as "not ready" */
always_comb
begin
	int i;
	for (i = 0; i < `DISPATCH_WIDTH; i++)
	begin
`ifdef DYNAMIC_CONFIG    
    PHY_DEST_VALID_CHK_RENAME : assert (~phyDest[i].valid | dispatchLaneActive_i[i])
    else $warning("Assert Failed for %d",i);
`endif    

		phyDest_o[i].reg_id                 = phyDest[i].reg_id;
		phyDest_o[i].valid                  = phyDest[i].valid & ~freeListEmpty;
	end
end


SpecFreeList specfreelist(

	.clk                               (clk),
  .resetRams_i                       (resetRams_i),

`ifdef DYNAMIC_CONFIG  
	.reset                             (reset | reconfigureCore_i),
  .commitLaneActive_i                (commitLaneActive_i),
  .dispatchLaneActive_i              (dispatchLaneActive_i),
  .flPartitionActive_i               (rfPartitionActive_i[`NUM_PARTS_RF-1:2]),
  //.flPartitionActive_i               (rfPartitionActive_i[`NUM_PARTS_RF-1:(64/(`SIZE_PHYSICAL_TABLE/`NUM_PARTS_RF))]),
  //.numDispatchLaneActive_i           (numDispatchLaneActive),
`else  
	.reset                             (reset),
`endif

	.recoverFlag_i                     (recoverFlag_i),
                                     
  //TODO: Stall might be redundant as reqPhyReg already accounts for
  // stall_i and instBufferReady
	.stall_i                           (1'b0),
	//.stall_i                           (stall_i | ~instBufferReady_i),
                                     
	.reqPhyReg_i                       (reqPhyReg),
                                     
	.freePhyReg_o                      (freePhyReg),
                                    
	.freedPhyReg_i                     (freedPhyReg_i),
`ifdef PERF_MON
	.freeListCnt_o                     (freeListCnt_o),
`endif
                                     
	.freeListEmpty_o                   (freeListEmpty),
  .flRamReady_o                      (flRamReady_o)
	);


RenameMapTable RMT(
	.clk                               (clk),
  .resetRams_i                       (resetRams_i),

`ifdef DYNAMIC_CONFIG  
	.reset                             (reset | reconfigureCore_i),
  .dispatchLaneActive_i              (dispatchLaneActive_i),
`else  
	.reset                             (reset),
`endif

	
	.stall_i                           (stall_i | ~instBufferReady_i | freeListEmpty),

	.logDest_i                         (logDest),
	.logSrc1_i                         (logSrc1),
	.logSrc2_i                         (logSrc2),
	
	.free_phys_i                       (freePhyReg),

	.phyDest_o                         (phyDest),
	.phySrc1_o                         (phySrc1),
	.phySrc2_o                         (phySrc2),

	.recoverFlag_i                     (recoverFlag_i),
	.repairFlag_i                      (repairFlag_i),

	/* .repairPacket_i                    (repairPacket_i), */
	.repairAddr_i                      (repairAddr_i),
	.repairData_i                      (repairData_i),
  .rmtRamReady_o                     (rmtRamReady_o)
	);


// TODO: Assert that dest is not valid when lane is inactive
always_comb
begin
	int i;
	for (i = 0; i < `DISPATCH_WIDTH; i = i + 1)
	begin
    // logDestValid is already gated using dispatchLaneActive in ibuffRename pipeline register.
    // renPacket valid is pre-validated with instBufferReady
		reqPhyReg[i] =  renPacket_i[i].valid ? (renPacket_i[i].logDestValid & ~stall_i) : 1'b0;
	end
end

always_comb
begin
  renameReady_o     = instBufferReady_i & ~freeListEmpty & ~stall_i;
  freeListEmpty_o   = freeListEmpty;
end


endmodule

