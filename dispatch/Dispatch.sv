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

// NOTE: Packets through dispatch keep flowing even though a particular 
// dispatch lane is inactive. This is simply to avoid adding valid bit to packet
// and adding complexity. The various queues (Active List, Issue Queue, LSQ etc) 
// will ignore invalid packets depending dispatchLaneActive bits.

`timescale 1ns/100ps

module Dispatch(
	input                                   clk,
	input                                   reset,

`ifdef DYNAMIC_CONFIG  
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
	input                                   renameReady_i,
  input                                   iqflRamReady_i,

	input                                   recoverFlag_i,
	input  [`SIZE_PC-1:0]                   recoverPC_i,
	input                                   loadViolation_i,
	//input                                   commitCsr_i,

	input  disPkt                           disPacket_i [0:`DISPATCH_WIDTH-1],
  input  [`SIZE_ACTIVELIST_LOG-1:0]       alID_i [0:`DISPATCH_WIDTH-1],
  input  [`SIZE_LSQ_LOG-1:0]              lsqID_i [0:`DISPATCH_WIDTH-1],

  // TODO: Modify issue queue, active list and lsq for the number of write ports
  // depending upon how many dispatch lanes are active.
	output iqPkt                            iqPacket_o  [0:`DISPATCH_WIDTH-1],
	output alPkt                            alPacket_o  [0:`DISPATCH_WIDTH-1],
	output lsqPkt                           lsqPacket_o [0:`DISPATCH_WIDTH-1],
  output exceptionPkt                     disExcptPacket_o,

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
	*  Load-Store Queue, then dispatchReady_o is low. This is like a valid
  *  signal and indicates nothing should be written to the back end structures.
	*  Also InstructionBuffer read and Rename are stalled by asserting 
  *  backEndFull_o.
	*******************************************************************/
  //TODO: dispatchReady might not be needed since all packets going
  // out of dispatch have per instruction slot valid bits.
  output                                  dispatchReady_o,
	output                                  backEndFull_o
  //output                                  stallForCsr_o
	);


reg [`DISPATCH_WIDTH-1:0] expVect;		//Changes:Mohit (Debug hook should be removed before synthesis)


// Counting the number of active DISPATCH lanes
// Should be 1 bit wider as it should hold values from 1 to `DISPATCH_WIDTH
// RBRC
reg [`DISPATCH_WIDTH_LOG:0] numDispatchLaneActive;
reg  [`SIZE_ACTIVELIST_LOG:0]       alSize;
reg  [`SIZE_ISSUEQ_LOG:0]           iqSize;
reg  [`SIZE_LSQ_LOG:0]              lsqSize;
always_comb
begin
`ifdef DYNAMIC_CONFIG  
  int i;
  numDispatchLaneActive = 0;
  for(i = 0; i < `DISPATCH_WIDTH; i++)
    numDispatchLaneActive = numDispatchLaneActive + dispatchLaneActive_i[i];

  case(alPartitionActive_i)
    6'b111111:alSize =  `SIZE_ACTIVELIST;
    6'b011111:alSize =  `SIZE_ACTIVELIST - ((`SIZE_ACTIVELIST/`NUM_PARTS_AL)*1);
    6'b001111:alSize =  `SIZE_ACTIVELIST - ((`SIZE_ACTIVELIST/`NUM_PARTS_AL)*2); 
    6'b000111:alSize =  `SIZE_ACTIVELIST - ((`SIZE_ACTIVELIST/`NUM_PARTS_AL)*3); 
    6'b000011:alSize =  `SIZE_ACTIVELIST - ((`SIZE_ACTIVELIST/`NUM_PARTS_AL)*4); 
    6'b000001:alSize =  `SIZE_ACTIVELIST - ((`SIZE_ACTIVELIST/`NUM_PARTS_AL)*5); 
    default:  alSize =  `SIZE_ACTIVELIST;
  endcase

  case(iqPartitionActive_i)
    4'b1111:iqSize = `SIZE_ISSUEQ;
    4'b0111:iqSize = `SIZE_ISSUEQ-(`SIZE_ISSUEQ/4);
    4'b0011:iqSize = `SIZE_ISSUEQ/2;
    4'b0001:iqSize = `SIZE_ISSUEQ/4;
    default:iqSize = `SIZE_ISSUEQ; 
  endcase

  case(lsqPartitionActive_i)
    4'b1111:lsqSize = `SIZE_LSQ;
    4'b0111:lsqSize = `SIZE_LSQ-(`SIZE_LSQ/4);
    4'b0011:lsqSize = `SIZE_LSQ/2;
    4'b0001:lsqSize = `SIZE_LSQ/4;
    default:lsqSize = `SIZE_LSQ; 
  endcase
`else
  numDispatchLaneActive = `DISPATCH_WIDTH;
  alSize  = `SIZE_ACTIVELIST;
  iqSize  = `SIZE_ISSUEQ;
  lsqSize = `SIZE_LSQ;
`endif
end


/***********************************************************************************
* Count the number of LD/ST instructions in the incoming set of instructions.
***********************************************************************************/
reg  [`DISPATCH_WIDTH_LOG:0]          loadCnt;
reg  [`DISPATCH_WIDTH_LOG:0]          storeCnt;

always_comb
begin
	int i;

	loadCnt    = 0;
	storeCnt   = 0;

  // the qualifier dispatchLaneActive is required as the renDispatch pipeline register
  // might be clock gated and will hold the last value it saw.
	for (i = 0; i < `DISPATCH_WIDTH; i++) 
	begin
//`ifdef DYNAMIC_CONFIG    
//  	loadCnt  = loadCnt  + (disPacket_i[i].isLoad & dispatchLaneActive_i[i]); // Parentheses necessary as '+' has operator precedence over '&' 
//	  storeCnt = storeCnt + (disPacket_i[i].isStore & dispatchLaneActive_i[i]); 
//`else    
  	loadCnt  = loadCnt  + disPacket_i[i].isLoad; 
	  storeCnt = storeCnt + disPacket_i[i].isStore; 
//`endif    
	end
end


/***********************************************************************************
* Check for room in LDQ, STQ, IQ and AL for new instructions.
***********************************************************************************/
wire                                  iqStall;
wire                                  loadStall;
wire                                  storeStall;
wire                                  alStall;
wire                                  stall;

// NOTE: numDispatchLaneActive, lsqSize and alSize are constants in case of STATIC_CONFIG
assign iqStall    = ((issueQueueCnt_i + numDispatchLaneActive) > iqSize) | ~iqflRamReady_i;
assign loadStall  = ((loadQueueCnt_i  + loadCnt)         > lsqSize);
assign storeStall = ((storeQueueCnt_i + storeCnt)        > lsqSize);
assign alStall    = ((activeListCnt_i + numDispatchLaneActive) > alSize);

assign stall      = (loadStall | storeStall | iqStall | alStall);

`ifdef PERF_MON
  assign loadStall_o  = loadStall ;
  assign storeStall_o = storeStall ;
  assign iqStall_o    = iqStall ;
  assign alStall_o    = alStall ;
`endif

/***********************************************************************************
* Assign each instruction to an execution pipe 
***********************************************************************************/

reg  [`INST_TYPES_LOG-1:0]            instTypes [0:`DISPATCH_WIDTH-1];
reg                                   isSimple  [0:`DISPATCH_WIDTH-1];
reg                                   isFP  [0:`DISPATCH_WIDTH-1];
reg  [`ISSUE_WIDTH_LOG-1:0]           exePipes  [0:`DISPATCH_WIDTH-1];

always_comb
begin
	int i;
	for (i = 0; i < `DISPATCH_WIDTH; i++)
	begin
		instTypes[i]            = disPacket_i[i].fu;
	end
end

// The scheduler works based on how many execution lanes are active at a point in time. 
// Load/Store lane one branch execution lane and atleast one simple/complex 
// lane will always be active.

ExePipeScheduler exePipeSched (
	.clk                       (clk),
`ifdef DYNAMIC_CONFIG  
	.reset                     (reset | reconfigureCore_i),
  .execLaneActive_i          (execLaneActive_i),
  .saluLaneActive_i          (saluLaneActive_i),
  .caluLaneActive_i          (caluLaneActive_i),
`else  
	.reset                     (reset),
`endif  

	.recoverFlag_i             (recoverFlag_i),
	.backEndReady_i            (~stall & renameReady_i),

	.instTypes_i               (instTypes),
	.isSimple_o                (isSimple),
	.isFP_o                    (isFP),
	.exePipes_o                (exePipes)
);


/***********************************************************************************
* Outputs 
***********************************************************************************/

/* Stalls IQ, LSQ and AL */
assign dispatchReady_o    = ~stall & renameReady_i;

/* Stalls IB and Rename */
assign backEndFull_o      = stall;


/***********************************************************************************
* Create the Issue Queue Packets 
***********************************************************************************/
wire [`DISPATCH_WIDTH-1:0]            predLoadVio;

// NOTE: The rename-dispatch register acts as an isolation cell and pulls the various
// valid bits in the dispatch packet to 1'b0. This gurantees correctness of control
// logic in Dispatch. When the rename dispatch register is clock gated, the other signals
// can be anything. Have to make sure they just flow through each lane and get written
// into the Issue Queue and Active List only if a dispatch lane is active.
always_comb
begin
	int i;
	for (i = 0; i < `DISPATCH_WIDTH; i++)
	begin
		iqPacket_o[i].seqNo        = disPacket_i[i].seqNo;
		iqPacket_o[i].predLoadVio  = predLoadVio[i];
		iqPacket_o[i].pc           = disPacket_i[i].pc;
		iqPacket_o[i].inst         = disPacket_i[i].inst;
		iqPacket_o[i].fu           = exePipes[i];
		iqPacket_o[i].logDest      = disPacket_i[i].logDest;
		iqPacket_o[i].phyDest      = disPacket_i[i].phyDest;
		iqPacket_o[i].phyDestValid = disPacket_i[i].phyDestValid;
		iqPacket_o[i].phySrc1      = disPacket_i[i].phySrc1;
		iqPacket_o[i].phySrc1Valid = disPacket_i[i].phySrc1Valid;
		iqPacket_o[i].phySrc2      = disPacket_i[i].phySrc2;
		iqPacket_o[i].phySrc2Valid = disPacket_i[i].phySrc2Valid;
		iqPacket_o[i].immed        = disPacket_i[i].immed;
		iqPacket_o[i].immedValid   = disPacket_i[i].immedValid;
    iqPacket_o[i].lsqID        = lsqID_i[i];
    iqPacket_o[i].alID         = alID_i[i];
		iqPacket_o[i].isLoad       = disPacket_i[i].isLoad;
		iqPacket_o[i].isStore      = disPacket_i[i].isStore;
		iqPacket_o[i].isCSR        = disPacket_i[i].isCSR;
		iqPacket_o[i].ldstSize     = disPacket_i[i].ldstSize;
		iqPacket_o[i].isSimple     = isSimple[i];
		iqPacket_o[i].isFP         = isFP[i];
		iqPacket_o[i].ctrlType     = disPacket_i[i].ctrlType;
		iqPacket_o[i].ctiID        = disPacket_i[i].ctiID;
		iqPacket_o[i].predNPC      = disPacket_i[i].predNPC;
		iqPacket_o[i].predDir      = disPacket_i[i].predDir;
		iqPacket_o[i].valid        = disPacket_i[i].valid & ~stall & ~disPacket_i[i].exception; // Do not write to IQ if exception
	end
end


/***********************************************************************************
* Create the Active List Packets 
***********************************************************************************/
// TODO: Adding a valid bit to the packet might help reduce correctness
// logic in ActiveList
// alPacket must be written to Active list only when the corresponding dispatch lane
// is active. 
always_comb
begin
	int i;
	for (i = 0; i < `DISPATCH_WIDTH; i++)
	begin
		alPacket_o[i].seqNo          = disPacket_i[i].seqNo;
		alPacket_o[i].exceptionCause = disPacket_i[i].exceptionCause;
		alPacket_o[i].exception      = disPacket_i[i].exception;
		alPacket_o[i].pc             = disPacket_i[i].pc;
		alPacket_o[i].logDest        = disPacket_i[i].logDest;
		alPacket_o[i].phyDest        = disPacket_i[i].phyDest;
		alPacket_o[i].phyDestValid   = disPacket_i[i].phyDestValid;
		alPacket_o[i].isLoad         = disPacket_i[i].isLoad;
		alPacket_o[i].isStore        = disPacket_i[i].isStore;
		alPacket_o[i].isCSR          = disPacket_i[i].isCSR;
		alPacket_o[i].isScall        = disPacket_i[i].isScall;
		alPacket_o[i].isSbreak       = disPacket_i[i].isSbreak;
		alPacket_o[i].isSret         = disPacket_i[i].isSret;   
		alPacket_o[i].isFP           = isFP[i];	 	//Changes: Mohit (Additional FP flag added to ActiveList and passed from Dispatch) 
		alPacket_o[i].valid          = disPacket_i[i].valid & ~stall; // Write to AL even if exception
	end
end

// Create the exception packet to be written to the Active List
always_comb
begin:EXCPT_PKT
	int                         i;
  int                         exceptionID;
  logic                       exceptionValid;
  logic [`DISPATCH_WIDTH-1:0] exceptionVector;

  exceptionVector = 0;
	for (i = 0; i < `DISPATCH_WIDTH; i++)
	begin
    exceptionVector[i] = disPacket_i[i].exception & disPacket_i[i].valid;
	end
  exceptionValid = |exceptionVector;

  // Priority encoder to indicate the first instruction that excepted
  casex(exceptionVector) //Changes: Mohit (Changed casez -> casex since none of the switch input include 'z')
    8'bxxxxxxx1:exceptionID = 0;
    8'bxxxxxx10:exceptionID = 1;
    8'bxxxxx100:exceptionID = 2;
    8'bxxxx1000:exceptionID = 3;
    8'bxxx10000:exceptionID = 4;
    8'bxx100000:exceptionID = 5;
    8'bx1000000:exceptionID = 6;
    8'b10000000:exceptionID = 7;
    default    :exceptionID = 0;
  endcase

  expVect = exceptionID;		//Changes:Mohit (Debug hook)

	disExcptPacket_o.seqNo          = disPacket_i[exceptionID].seqNo;
	disExcptPacket_o.alID           = alID_i[exceptionID];
	disExcptPacket_o.exceptionCause = disPacket_i[exceptionID].exceptionCause;
	disExcptPacket_o.exception      = disPacket_i[exceptionID].exception;
	//Changes:Mohit (Added ~stall to avoid disExcptPacket updating Exception Activelist before AL entry is updated in case of backend stall)
	disExcptPacket_o.valid          = exceptionValid & ~stall; // Write to AL only if exception 

end

/***********************************************************************************
* Create the LSQ Packets 
***********************************************************************************/
// TODO: Adding a valid bit to the packet might help reduce correctness
// logic in LSU
// lsqPacket must be written to LSQ only when the corresponding dispatch lane
// is active. 
always_comb
begin
	int i;
	for (i = 0; i < `DISPATCH_WIDTH; i++)
	begin
		lsqPacket_o[i].seqNo       = disPacket_i[i].seqNo;
  `ifdef LD_STALL_AT_ISSUE
		lsqPacket_o[i].predLoadVio = 1'b0;
  `else
		lsqPacket_o[i].predLoadVio = predLoadVio[i];
  `endif
//`ifdef DYNAMIC_CONFIG
//		lsqPacket_o[i].isLoad      = dispatchLaneActive_i[i] ? disPacket_i[i].isLoad : 1'b0;
//		lsqPacket_o[i].isStore     = dispatchLaneActive_i[i] ? disPacket_i[i].isStore : 1'b0;
//`else
		lsqPacket_o[i].isLoad      = disPacket_i[i].isLoad;
		lsqPacket_o[i].isStore     = disPacket_i[i].isStore;
		lsqPacket_o[i].valid       = disPacket_i[i].valid & ~stall & ~disPacket_i[i].exception; // Do not write to LSQ if exception
//`endif
	end
end


`ifdef ENABLE_LD_VIOLATION_PRED
/***********************************************************************************
* Extract PC and if the instruction is a load
***********************************************************************************/
reg  [`SIZE_PC-1:0]                    pc     [0:`DISPATCH_WIDTH-1];
reg                                    isLoad [0:`DISPATCH_WIDTH-1];

always_comb
begin
	int i;
	for (i = 0; i < `DISPATCH_WIDTH; i++)
	begin
		pc[i]                              = disPacket_i[i].pc;
		isLoad[i]                          = disPacket_i[i].isLoad;
	end
end

// TODO: Use dispatchLaneActive_i to gate read and write ports
LoadViolationPred ldVioPred (
	.clk                                  (clk),
	.reset                                (reset),

	.loadViolation_i                      (loadViolation_i),
	.recoverFlag_i                        (recoverFlag_i),
	.recoverPC_i                          (recoverPC_i),

	.pc_i                                 (pc),
	.isLoad_i                             (isLoad),

	.predLoadVio_o                        (predLoadVio)
	);
`else

assign predLoadVio = 0;

`endif

endmodule

