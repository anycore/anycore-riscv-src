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

module Core_OOO(

  input                               clk,
  input                               reset,
  input                               resetFetch_i,
  
  output reg                          toggleFlag_o,
  
  input  [`SIZE_PC-1:0]               startPC_i,
  
  output [`SIZE_PC-1:0]               instPC_o [0:`FETCH_WIDTH-1],
  output                              fetchReq_o, //Indicates whether the instruction PC 
                                                 // in a particular clock cycle is valid
  output                              fetchRecoverFlag_o, // Indicates that fetch is being recovered
                                                   // due to a bad event in CPU
  input  [`SIZE_INSTRUCTION-1:0]      inst_i   [0:`FETCH_WIDTH-1],
  input                               instValid_i, //Indicates whether the instruction stream 
                                                   // in a particular clock cycle is valid
  input  exceptionPkt                 instException_i,

`ifdef SCRATCH_PAD
  input [`DEBUG_INST_RAM_LOG+`DEBUG_INST_RAM_WIDTH_LOG-1:0]   instScratchAddr_i   ,
  input  [7:0]                        instScratchWrData_i ,
  input                               instScratchWrEn_i   ,
  output [7:0]                        instScratchRdData_o ,
  input  [`DEBUG_DATA_RAM_LOG+`DEBUG_DATA_RAM_WIDTH_LOG-1:0]  dataScratchAddr_i   ,
  input  [7:0]                        dataScratchWrData_i ,
  input                               dataScratchWrEn_i   ,
  output [7:0]                        dataScratchRdData_o ,
  input                               instScratchPadEn_i,
  input                               dataScratchPadEn_i,
`endif

`ifdef INST_CACHE
  output [`ICACHE_BLOCK_ADDR_BITS-1:0]ic2memReqAddr_o,      // memory read address
  output                              ic2memReqValid_o,     // memory read enable
  input  [`ICACHE_TAG_BITS-1:0]       mem2icTag_i,          // tag of the incoming data
  input  [`ICACHE_INDEX_BITS-1:0]     mem2icIndex_i,        // index of the incoming data
  input  [`ICACHE_BITS_IN_LINE-1:0]   mem2icData_i,         // requested data
  input                               mem2icRespValid_i,    // requested data is ready
  //input                               instCacheBypass_i,
  input                               icScratchModeEn_i,    // Should ideally be disabled by default
  input [`ICACHE_INDEX_BITS+`ICACHE_BYTES_IN_LINE_LOG-1:0]  icScratchWrAddr_i,
  input                               icScratchWrEn_i,
  input [7:0]                         icScratchWrData_i,
  output [7:0]                        icScratchRdData_o,
  input                               icFlush_i,
  output                              icFlushDone_o,
`endif  

`ifdef DATA_CACHE
  input                               dataCacheBypass_i,
  input                               dcScratchModeEn_i,    // Should ideally be disabled by default

  // cache-to-memory interface for Loads
  output [`DCACHE_BLOCK_ADDR_BITS-1:0]dc2memLdAddr_o,  // memory read address
  output reg                          dc2memLdValid_o, // memory read enable

  // memory-to-cache interface for Loads
  input  [`DCACHE_TAG_BITS-1:0]       mem2dcLdTag_i,       // tag of the incoming datadetermine
  input  [`DCACHE_INDEX_BITS-1:0]     mem2dcLdIndex_i,     // index of the incoming data
  input  [`DCACHE_BITS_IN_LINE-1:0]   mem2dcLdData_i,      // requested data
  input                               mem2dcLdValid_i,     // indicates the requested data is ready

  // cache-to-memory interface for stores
  output [`DCACHE_ST_ADDR_BITS-1:0]   dc2memStAddr_o,  // memory read address
  output [`SIZE_DATA-1:0]             dc2memStData_o,  // memory read address
  output [2:0]                        dc2memStSize_o,  // memory read address
  output reg                          dc2memStValid_o, // memory read enable

  // memory-to-cache interface for stores
  input                               mem2dcStComplete_i,
  input                               mem2dcStStall_i,

  input [`DCACHE_INDEX_BITS+`DCACHE_BYTES_IN_LINE_LOG-1:0]  dcScratchWrAddr_i,
  input                               dcScratchWrEn_i,
  input [7:0]                         dcScratchWrData_i,
  output [7:0]                        dcScratchRdData_o,
  input                               dcFlush_i,
  output                              dcFlushDone_o,
`endif

  // These should be controlled by power manager
  // Making these as inputs to the core for now
`ifdef DYNAMIC_CONFIG
// wires for the power management unit that does dynamic reconfiguration
  input                               stallFetch_i,
  input  [`FETCH_WIDTH-1:0]           fetchLaneActive_i,
  input  [`DISPATCH_WIDTH-1:0]        dispatchLaneActive_i,
  input  [`ISSUE_WIDTH-1:0]           issueLaneActive_i,
  input  [`ISSUE_WIDTH-1:0]           execLaneActive_i,
  input  [`ISSUE_WIDTH-1:0]           saluLaneActive_i,
  input  [`ISSUE_WIDTH-1:0]           caluLaneActive_i,
  input  [`COMMIT_WIDTH-1:0]          commitLaneActive_i,
  input  [`NUM_PARTS_RF-1:0]          rfPartitionActive_i,
  input  [`NUM_PARTS_AL-1:0]          alPartitionActive_i,
  input  [`STRUCT_PARTS_LSQ-1:0]      lsqPartitionActive_i,
  input  [`NUM_PARTS_IQ-1:0]          iqPartitionActive_i,
  input  [`STRUCT_PARTS-1:0]          ibuffPartitionActive_i,
  input                               reconfigureCore_i,

  output                              reconfigDone_o,
  output                              pipeDrained_o,
`endif

`ifdef PERF_MON
  input  [7:0]                        perfMonRegAddr_i,
  output [31:0]                       perfMonRegData_o,
  input                               perfMonRegRun_i       ,
  input                               perfMonRegClr_i       ,
  input                               perfMonRegGlobalClr_i ,           
`endif


	/* To memory */
	output [`SIZE_PC-1:0]               ldAddr_o,
	input  [`SIZE_DATA-1:0]             ldData_i,
  input                               ldDataValid_i,
  input  exceptionPkt                 ldException_i,
	output                              ldEn_o,

	output [`SIZE_PC-1:0]               stAddr_o,
	output [`SIZE_DATA-1:0]             stData_o,
	output [7:0]                        stEn_o,
  input  exceptionPkt                 stException_i,

	output [1:0]                        ldStSize_o,

  output                              resetDone_o,

  // This is used to update the fake Gshare in the testbench
	output [`COMMIT_WIDTH-1:0]          actualDir_o,
	output [`COMMIT_WIDTH-1:0]          ctrlType_o,

	input  [`SIZE_PHYSICAL_LOG-1:0]     dbAddr_i,
	input  [`SIZE_DATA-1:0]             dbData_i,
	input                               dbWe_i,

	input  [`SIZE_PHYSICAL_LOG+`SIZE_DATA_BYTE_OFFSET-1:0]       debugPRFAddr_i,
	input  [`SRAM_DATA_WIDTH-1:0]       debugPRFWrData_i,
	input                               debugPRFWrEn_i,
	output [`SRAM_DATA_WIDTH-1:0]       debugPRFRdData_o,

	input  [`SIZE_RMT_LOG-1:0]          debugAMTAddr_i,
	output [`SIZE_PHYSICAL_LOG-1:0]     debugAMTRdData_o
	);


/*****************************logic Declaration**********************************/

// wires from FetchStage1 module
fs2Pkt                            fs2Packet      [0:`FETCH_WIDTH-1];
fs2Pkt                            fs2Packet_l1   [0:`FETCH_WIDTH-1];

logic                             fs1Ready;
logic                             fs1Ready_l1;

logic [`SIZE_PC-1:0]              addrRAS;

reg  [1:0]                        predCounter    [0:`FETCH_WIDTH-1];
reg  [`SIZE_CNT_TBL_LOG-1:0]      predIndex      [0:`FETCH_WIDTH-1];
reg  [`SIZE_CNT_TBL_LOG-1:0]      predIndex_l1   [0:`FETCH_WIDTH-1];
reg  [1:0]                        predCounter_l1 [0:`FETCH_WIDTH-1];


// wires from FetchStage2 module
logic                             fs2RecoverFlag;
logic [`SIZE_PC-1:0]              fs2RecoverPC;
logic                             fs2MissedReturn;
logic                             fs2MissedCall;
logic [`SIZE_PC-1:0]              fs2CallPC;

logic [`SIZE_PC-1:0]              updatePC;
logic [`SIZE_PC-1:0]              updateNPC;
logic [`BRANCH_TYPE_LOG-1:0]          updateCtrlType;
logic                             updateDir;
logic [1:0]                       updateCounter;
wire [`SIZE_CNT_TBL_LOG-1:0]      updateIndex;
logic                             updateEn;

logic                             ctiQueueFull;
logic                             fs2Ready;

decPkt                            decPacket    [0:`FETCH_WIDTH-1];
decPkt                            decPacket_l1 [0:`FETCH_WIDTH-1];


// wires from Fetch2Decode module
logic [`SIZE_PC-1:0]              updatePC_l1;
logic [`SIZE_PC-1:0]              updateNPC_l1;
logic [`BRANCH_TYPE_LOG-1:0]          updateCtrlType_l1;
logic                             updateDir_l1;
logic [1:0]                       updateCounter_l1;
wire [`SIZE_CNT_TBL_LOG-1:0]      updateIndex_l1;
wire [`FETCH_WIDTH-1:0]           specBHRCtrlVect;
logic                             updateEn_l1;

logic                             fs2Ready_l1;


// wires from Decode module
logic                             decodeReady;

renPkt                            ibPacket [0:2*`FETCH_WIDTH-1];
renPkt                            ibPacketClamped [0:2*`FETCH_WIDTH-1];

// wires from Instruction Buffer module
logic                             instBufferFull;
logic                             instBufferReady;

renPkt                            renPacket [0:`DISPATCH_WIDTH-1];


// wires from InstBufRename
logic                             instBufferReady_l1;

renPkt                            renPacket_l1 [0:`DISPATCH_WIDTH-1];

// wires from Rename module
logic                             freeListEmpty;
logic                             renameReady;

disPkt                            disPacket [0:`DISPATCH_WIDTH-1];
phys_reg                          phyDest   [0:`DISPATCH_WIDTH-1];

// wires from RenameDispatch module
logic                             renameReady_l1;
disPkt                            disPacket_l1 [0:`DISPATCH_WIDTH-1];

//wires from Dispatch module
logic                             backEndFull;
logic                             stallForCsr;

//wires from Dispatch module
logic                             dispatchReady;

iqPkt                             iqPacket  [0:`DISPATCH_WIDTH-1];
alPkt                             alPacket  [0:`DISPATCH_WIDTH-1];
lsqPkt                            lsqPacket [0:`DISPATCH_WIDTH-1];


// wires for issueq module
logic [`SIZE_ISSUEQ_LOG:0]        cntInstIssueQ;
payloadPkt                        rrPacket      [0:`ISSUE_WIDTH-1];

// wires for iq_regread module
payloadPkt                        rrPacket_l1   [0:`ISSUE_WIDTH-1];


// wires from execute module
memPkt                            memPacket;
logic  [`ISSUE_WIDTH-1:0]         toggleFlag;

//Changes: Mohit (Floating-point exception_flags sent between fp-unit and Activelist)
fpexcptPkt                        fpExcptPacket;
	
// logic from writeback module
logic [`SIZE_PC-1:0]              exeCtrlPC;
logic [`BRANCH_TYPE_LOG-1:0]          exeCtrlType;
logic                             exeCtrlValid;
logic [`SIZE_PC-1:0]              exeCtrlNPC;
logic                             exeCtrlDir;
logic [`SIZE_CTI_LOG-1:0]         exeCtiID;

ctrlPkt                           ctrlPacket [0:`ISSUE_WIDTH-1];
ctrlPkt                           ctrlPacket_a1 [0:`ISSUE_WIDTH-1];

memPkt                            memPacket_l1;


// logic from Load-Store Unit
reg  [`SIZE_LSQ_LOG-1:0]          lsqID [0:`DISPATCH_WIDTH-1];
logic [`SIZE_LSQ_LOG:0]           ldqCount;
logic [`SIZE_LSQ_LOG:0]           stqCount;
wbPkt                             wbPacket;
ldVioPkt                          ldVioPacket;
ldVioPkt                          ldVioPacket_l1;
exceptionPkt                      memExcptPacket;
exceptionPkt                      disExcptPacket;


// wires from activeList module
reg  [`SIZE_ACTIVELIST_LOG-1:0]   alHead;
reg  [`SIZE_ACTIVELIST_LOG-1:0]   alTail;
reg  [`SIZE_ACTIVELIST_LOG-1:0]   alID [0:`DISPATCH_WIDTH-1];

commitPkt                         amtPacket [0:`COMMIT_WIDTH-1];
logic [`SIZE_ACTIVELIST_LOG:0]    activeListCnt;
reg  [`COMMIT_WIDTH-1:0]          commitStore;
reg  [`COMMIT_WIDTH-1:0]          commitLoad;
logic [`COMMIT_WIDTH-1:0]         commitCti;
logic                             commitCsr;
logic [`COMMIT_WIDTH_LOG:0]       totalCommit; 
logic                             recoverFlag;
/* logic                             repairFlag; */
logic [`SIZE_PC-1:0]              recoverPC;
logic                             exceptionFlag;
logic [`SIZE_PC-1:0]              exceptionPC;
logic [`EXCEPTION_CAUSE_LOG-1:0]       exceptionCause;
logic [`SIZE_VIRT_ADDR-1:0]     stCommitAddr;
logic [`SIZE_VIRT_ADDR-1:0]     ldCommitAddr;
logic                             loadViolation;


// wires from amt module
phys_reg                          freedPhyReg  [0:`COMMIT_WIDTH-1];
/* recoverPkt                           repairPacket [0:`COMMIT_WIDTH-1]; */
logic                             repairFlag;
reg  [`SIZE_RMT_LOG-1:0]          repairAddr  [0:`N_REPAIR_PACKETS-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]     repairData  [0:`N_REPAIR_PACKETS-1];

// wires declared for the interaction between register file and execution pipes
reg  [`SIZE_PHYSICAL_LOG-1:0]     phySrc1 [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]     phySrc2 [0:`ISSUE_WIDTH-1];
reg  [`SIZE_DATA-1:0]             src1Data [0:`ISSUE_WIDTH-1];
reg  [`SIZE_DATA-1:0]             src2Data [0:`ISSUE_WIDTH-1];

reg  [`CSR_WIDTH_LOG-1:0]          csrRdAddr;
reg                               csrRdEn;
reg  [`CSR_WIDTH-1:0]        csrRdData;
reg  [`CSR_WIDTH_LOG-1:0]          csrWrAddr;  
reg  [`CSR_WIDTH-1:0]        csrWrData;
reg                               csrWrEn;
reg                               csrViolateFlag;
reg                               interruptPending;
reg  [`SIZE_PC-1:0]               csr_epc;
reg  [`SIZE_PC-1:0]               csr_evec;
reg  [`CSR_WIDTH-1:0]        	  csr_status;		//Changes: Mohit (Checks FP_DISABLED status)
reg  [`CSR_WIDTH-1:0]        	  csr_frm;		//Changes: Mohit (Used in FP-unit for dynamic rounding mode)
reg  [`CSR_WIDTH-1:0]        	  csr_fflags;		//Changes: Mohit (Updated at retire in SupRegFile based on fp_exception)
reg                               sretFlag;

bypassPkt                         bypassPacket [0:`ISSUE_WIDTH-1];
bypassPkt                         bypassPacket_a1 [0:`ISSUE_WIDTH-1];

// wires used for core reset logic
logic                             btbRamReady   ;
logic                             bpRamReady    ;
logic                             rasRamReady   ;
logic                             ctiqRamReady  ;
logic                             rmtRamReady   ;
logic                             flRamReady    ;
logic                             iqflRamReady  ;
logic                             stqRamReady   ;
logic                             ldqRamReady   ;
logic                             alRamReady   ;
logic                             amtRamReady   ;
logic                             resetRams     ;
logic                             resetLogic    ;
logic                             resetDone     ;
assign resetDone = resetDone_o;

`ifdef INST_CACHE  
  logic                           icMiss;
`endif

`ifdef DATA_CACHE
  logic                           ldMiss;
  logic                           stMiss;
  logic                           stallStCommit;
`endif

`ifdef DYNAMIC_CONFIG
  logic [`FETCH_WIDTH-1:0]        fs1Fs2Valid;
  logic [`FETCH_WIDTH-1:0]        fs2DecValid;
  logic [`DISPATCH_WIDTH-1:0]     renDisValid;
  logic [`DISPATCH_WIDTH-1:0]     instBufRenValid;
  logic [`DISPATCH_WIDTH-1:0]     disIqValid;
  logic [`ISSUE_WIDTH-1:0]        iqRegReadValid;
  logic                           ibuffInsufficientCnt;

  logic 				                  consolidateFlag;
  logic 				                  consolidationDone;
  logic [`SIZE_RMT_LOG-1:0]	      logAddr;
  //logic [`SIZE_PHYSICAL_LOG-1:0]  	  phyAddrToPRF;
  logic [`SIZE_PHYSICAL_LOG-1:0]  phyAddrFromAMT;
  bypassPkt                       bypassPacket_recon;
  logic [`SIZE_PHYSICAL_LOG-1:0]  phySrc1_recon;
  logic 				                  beginConsolidation;

  reg  [`SIZE_PHYSICAL_LOG-1:0]   phySrc1_PRF [0:`ISSUE_WIDTH-1];
  reg  [`SIZE_PHYSICAL_LOG-1:0]   phySrc2_PRF [0:`ISSUE_WIDTH-1];
  bypassPkt                       bypassPacket_PRF [0:`ISSUE_WIDTH-1];


  logic  [`FETCH_WIDTH-1:0]       fetchLaneActive;
  logic  [`DISPATCH_WIDTH-1:0]    dispatchLaneActive;
  logic  [`ISSUE_WIDTH-1:0]       issueLaneActive;
  logic  [`ISSUE_WIDTH-1:0]       execLaneActive;
  logic  [`ISSUE_WIDTH-1:0]       saluLaneActive;
  logic  [`ISSUE_WIDTH-1:0]       caluLaneActive;
  logic  [`COMMIT_WIDTH-1:0]      commitLaneActive;
  logic  [`NUM_PARTS_RF-1:0]      rfPartitionActive;
  logic  [`NUM_PARTS_AL-1:0]      alPartitionActive;
  logic  [`STRUCT_PARTS_LSQ-1:0]  lsqPartitionActive;
  logic  [`NUM_PARTS_IQ-1:0]      iqPartitionActive;
  logic  [`STRUCT_PARTS-1:0]      ibuffPartitionActive;
  logic                           stallFetch;
  logic                           loadNewConfig;
  logic                           reconfigureFlag;

`endif


`ifdef PERF_MON
  logic [`INST_QUEUE_LOG:0]       instBuffCount     ;
  logic [`SIZE_FREE_LIST_LOG-1:0] freeListCnt;
  logic [`SIZE_LSQ_LOG:0]         iqReqCount;
  logic [`SIZE_LSQ_LOG:0]         iqIssuedCount;
  logic [`COMMIT_WIDTH-1:0]       commitValid; 
  logic                           loadStall;
  logic                           storeStall;
  logic                           iqStall;
  logic                           alStall;
`endif



ResetControl rstCtrl(
  .clk                  (clk),
  .reset                (reset),
                                     
  .btbRamReady_i        (btbRamReady),
  .bpRamReady_i         (bpRamReady),
  .rasRamReady_i        (rasRamReady),
  .ctiqRamReady_i       (ctiqRamReady),
  .rmtRamReady_i        (rmtRamReady),
  .flRamReady_i         (flRamReady),
  .iqflRamReady_i       (iqflRamReady),
  .stqRamReady_i        (stqRamReady),
  .ldqRamReady_i        (ldqRamReady),
  .alRamReady_i         (alRamReady),
  .amtRamReady_i        (amtRamReady),
                                     
  .resetRams_o          (resetRams),
  .resetLogic_o         (resetLogic),
  .resetDone_o          (resetDone_o)
);

 /**********************************************************************************
 *  "fetch1" module is the first stage of the instruction fetching process. This
 *  module contains L1 Insturction Cache, Branch Target Buffer, Branch Prediction
 *  Buffer and Return Address Stack structures.
 **********************************************************************************/

assign fetchRecoverFlag_o =  recoverFlag | exceptionFlag | fs2RecoverFlag;



FetchStage1 fs1(
  .clk                  (clk),
  .reset                (resetLogic),
  .resetRams_i          (resetRams),
  .resetFetch_i         (resetFetch_i), // Does not reset the cache

  .startPC_i            (startPC_i),

`ifdef SCRATCH_PAD
  .instScratchAddr_i    (instScratchAddr_i),
  .instScratchWrData_i  (instScratchWrData_i),
  .instScratchWrEn_i    (instScratchWrEn_i),
  .instScratchRdData_o  (instScratchRdData_o),
  .instScratchPadEn_i   (instScratchPadEn_i),
`endif

`ifdef INST_CACHE
  .ic2memReqAddr_o      (ic2memReqAddr_o     ),      // memory read address
  .ic2memReqValid_o     (ic2memReqValid_o    ),     // memory read enable
  .mem2icTag_i          (mem2icTag_i         ),          // tag of the incoming data
  .mem2icIndex_i        (mem2icIndex_i       ),        // index of the incoming data
  .mem2icData_i         (mem2icData_i        ),         // requested data
  .mem2icRespValid_i    (mem2icRespValid_i   ),    // requested data is ready
  //.instCacheBypass_i    (instCacheBypass_i ),
  .icScratchModeEn_i    (icScratchModeEn_i),

  .icScratchWrAddr_i    (icScratchWrAddr_i),
  .icScratchWrEn_i      (icScratchWrEn_i  ),
  .icScratchWrData_i    (icScratchWrData_i),
  .icScratchRdData_o    (icScratchRdData_o),
`endif  

`ifdef PERF_MON
  .icMiss_o             (icMiss),
`endif
  //TODO: stallFetch might not be needed as
  // it is part of instBufferFull
`ifdef DYNAMIC_CONFIG  
	.stall_i              (instBufferFull | ctiQueueFull | stallFetch),
	//.stall_i              (instBufferFull | ctiQueueFull),
  .fetchLaneActive_i    (fetchLaneActive),
  .stallFetch_i         (stallFetch),
  .reconfigureCore_i    (loadNewConfig),
`else
	.stall_i              (instBufferFull | ctiQueueFull),
`endif

	.recoverFlag_i        (recoverFlag),
	.recoverPC_i          (recoverPC),

	.exceptionFlag_i      (exceptionFlag),
	.exceptionPC_i        (exceptionPC),

	.fs2RecoverFlag_i     (fs2RecoverFlag),
	.fs2MissedCall_i      (fs2MissedCall),
	.fs2CallPC_i          (fs2CallPC),
	.fs2MissedReturn_i    (fs2MissedReturn),
	.fs2RecoverPC_i       (fs2RecoverPC),

	.updatePC_i           (updatePC_l1),
	.updateNPC_i          (updateNPC_l1),
	.updateBrType_i       (updateCtrlType_l1),
	.updateDir_i          (updateDir_l1),
	.updateCounter_i      (updateCounter_l1),
	.updateEn_i           (updateEn_l1),

	.instPC_o             (instPC_o),
  .fetchReq_o           (fetchReq_o),
	.inst_i               (inst_i),
  .instValid_i          (instValid_i),
  .instException_i      (instException_i),

	.fs1Ready_o           (fs1Ready),
	.addrRAS_o            (addrRAS),
	.predCounter_o        (predCounter),
`ifdef USE_GSHARE_BPU  
  .predIndex_o          (predIndex),
	.updateIndex_i        (updateIndex_l1),
  .specBHRCtrlVect_i    (specBHRCtrlVect),
`endif  

	.fs2Packet_o          (fs2Packet),
  .btbRamReady_o        (btbRamReady),
  .bpRamReady_o         (bpRamReady),
  .rasRamReady_o        (rasRamReady)

	);



 /**********************************************************************************
 *  "fs1fs2" module is the pipeline stage between Fetch Stage-1 and Fetch
 *  Stage-2.
 **********************************************************************************/
// If FetchStage1 is stalled by asserting stallFetch_i, it will pull the fs1Ready low,
// indicating to the successive stages that it is not fetching valid isntructions. Whatever
// instructions it has already fetched before stallFetch_i went high, should be decoded and
// written into the instruction buffer, provided there's enough space in the instruction buffer.
Fetch1Fetch2 fs1fs2(
	.clk                  (clk),
	.reset                (resetLogic),

	.flush_i              (fs2RecoverFlag | recoverFlag | exceptionFlag | resetFetch_i),
  //TODO: stallFetch might not be needed as
  // it is part of instBufferFull
`ifdef DYNAMIC_CONFIG
  .laneActive_i         (fetchLaneActive),
	//.stall_i              (instBufferFull | ctiQueueFull | stallFetch),
	.stall_i              (instBufferFull | ctiQueueFull),
`else
	.stall_i              (instBufferFull | ctiQueueFull),
`endif

`ifdef DYNAMIC_CONFIG
	.valid_bundle_o       (fs1Fs2Valid),
`endif
	.fs1Ready_i           (fs1Ready),
	.predCounter_i        (predCounter),
  .predIndex_i          (predIndex),
	.fs2Packet_i          (fs2Packet),

	.fs1Ready_o           (fs1Ready_l1),
	.predCounter_o        (predCounter_l1),
  .predIndex_o          (predIndex_l1),
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
	.reset                (resetLogic | resetFetch_i),
  .resetRams_i          (resetRams),

	.recoverFlag_i        (recoverFlag),
	.exceptionFlag_i      (exceptionFlag),
  //TODO: stallFetch might not be needed as
  // it is part of instBufferFull
`ifdef DYNAMIC_CONFIG  
	//.stall_i              (instBufferFull | stallFetch),
	.stall_i              (instBufferFull),
  .fetchLaneActive_i    (fetchLaneActive),
`else
	.stall_i              (instBufferFull),
`endif

	.fs1Ready_i           (fs1Ready_l1),
	.addrRAS_i            (addrRAS),
	.predCounter_i        (predCounter_l1),
`ifdef USE_GSHARE_BPU
	.predIndex_i          (predIndex_l1),
	.updateIndex_o        (updateIndex),
  .specBHRCtrlVect_o    (specBHRCtrlVect),
`endif  

	.fs2Packet_i          (fs2Packet_l1),

	.decPacket_o          (decPacket),

	.exeCtrlPC_i          (exeCtrlPC),
	.exeCtrlType_i        (exeCtrlType),
	.exeCtiID_i           (exeCtiID),
	.exeCtrlNPC_i         (exeCtrlNPC),
	.exeCtrlDir_i         (exeCtrlDir),
	.exeCtrlValid_i       (exeCtrlValid),

	.commitCti_i          (commitCti),

	.fs2RecoverFlag_o     (fs2RecoverFlag),
	.fs2RecoverPC_o       (fs2RecoverPC),
	.fs2MissedReturn_o    (fs2MissedReturn),
	.fs2MissedCall_o      (fs2MissedCall),
	.fs2CallPC_o          (fs2CallPC),

	.updatePC_o           (updatePC),
	.updateNPC_o          (updateNPC),
	.updateCtrlType_o     (updateCtrlType),
	.updateDir_o          (updateDir),
	.updateCounter_o      (updateCounter),
	.updateEn_o           (updateEn),

	.fs2Ready_o           (fs2Ready),
	.ctiQueueFull_o       (ctiQueueFull),

  .ctiqRamReady_o       (ctiqRamReady)
	);



 /**********************************************************************************
 * "fs2dec" module is the pipeline stage between Fetch Stage-2 and decode stage.
 **********************************************************************************/
Fetch2Decode fs2dec(
	.clk                  (clk),
	.reset                (resetLogic),
	.flush_i              (recoverFlag | exceptionFlag | resetFetch_i),
	.stall_i              (instBufferFull),

  //TODO: stallFetch might not be needed as
  // it is part of instBufferFull
`ifdef DYNAMIC_CONFIG  
  .laneActive_i         (fetchLaneActive),
	.valid_bundle_o       (fs2DecValid),
`endif

	.updatePC_i           (updatePC),
	.updateNPC_i          (updateNPC),
	.updateCtrlType_i     (updateCtrlType),
	.updateDir_i          (updateDir),
	.updateCounter_i      (updateCounter),
	.updateIndex_i        (updateIndex),
	.updateEn_i           (updateEn),

	.fs2Ready_i           (fs2Ready),

	.decPacket_i          (decPacket),
	.decPacket_o          (decPacket_l1),

	.updatePC_o           (updatePC_l1),
	.updateNPC_o          (updateNPC_l1),
	.updateCtrlType_o     (updateCtrlType_l1),
	.updateDir_o          (updateDir_l1),
	.updateCounter_o      (updateCounter_l1),
	.updateIndex_o        (updateIndex_l1),
	.updateEn_o           (updateEn_l1),

	.fs2Ready_o           (fs2Ready_l1)
	);



 /**********************************************************************************
 * "decode" module decodes the incoming instruction and generate appropriate
 * signals required by the rest of the pipeline stages.
 **********************************************************************************/

// NOTE: Already per lane and can be easily power gated
Decode decode (
	.clk                  (clk),
	.reset                (resetLogic),

`ifdef DYNAMIC_CONFIG  
  .fetchLaneActive_i    (fetchLaneActive),
`endif  

	.fs2Ready_i           (fs2Ready_l1),

	.decPacket_i          (decPacket_l1),

	.ibPacket_o           (ibPacket),

	.decodeReady_o        (decodeReady)
	);


 /**********************************************************************************
 *  "InstructionBuffer" module decouples instruction fetching process and the rest
 *   of the pipeline stages.
 *
 *  This module contains Instruction Queue structure, which can accept variable
 *  number of instructions but always 4 instructions can be read from instruction
 *  buffer.
 **********************************************************************************/

// NOTE: Not much opportunity for per lane power gating.
// Correctness is taken care by clamping valid bits from 
// Decode stage and using valid bits in Instruction buffer
// write logic.

InstructionBuffer instBuf (
	.clk                  (clk),
	.reset                (resetLogic),

`ifdef DYNAMIC_CONFIG  
  .fetchLaneActive_i    (fetchLaneActive),
  .dispatchLaneActive_i (dispatchLaneActive),
  //.ibuffPartitionActive_i (ibuffPartitionActive),
  .//ibuffPartitionActive_i ({`STRUCT_PARTS{1'b1}}), // Making instbuff non-configurable
  .ibuffInsufficientCnt_o (ibuffInsufficientCnt),

  // Stall read side (Dispatch) when trying to reconfigure so that no new
  // instructions are dispatched. Does not affect the writing of new instructions
  // by decode, provided space is available in instruction buffer.
  // Instruction read out of instruction buffer is stalled during loading new config as
  // there is a possibility that previously partial dispatch bundles might issue due to
  // narrowing of the dispatch width. Keep it stalled until the backend is ready to accept
  // new instructions. The sequencing is controlled by power manager state machine.
	.stall_i              (freeListEmpty | backEndFull | repairFlag | reconfigureFlag),
`else  
	.stall_i              (freeListEmpty | backEndFull | repairFlag),
`endif

  // Cannot flush during reconfiguring as there might be residual instructions
  // that could not be dispatched due to lack of a full dispatch bundle.
  // Moreover the size is not being reconfigured and flush is not needed.
	.flush_i              (recoverFlag | exceptionFlag | resetFetch_i),  
	.commitCsr_i          (commitCsr),

	.decodeReady_i        (decodeReady),

	.ibPacket_i           (ibPacket),

	.csr_status_i	      (csr_status),	//Changes: Mohit (Check if FP_DISABLED and raise exception)

	.instBufferFull_o     (instBufferFull),
	.instBufferReady_o    (instBufferReady),
`ifdef PERF_MON
	.instCount_o          (instBuffCount),
`endif

	.renPacket_o          (renPacket)
	);


 /**********************************************************************************
 *  "InstBufRename" module is the pipeline stage between Instruction buffer and
 *  Rename Stage.
 **********************************************************************************/

InstBufRename instBufRen (
	.clk                  (clk),
	.reset                (resetLogic),

`ifdef DYNAMIC_CONFIG
  .laneActive_i         (dispatchLaneActive),
	.flush_i              (recoverFlag | exceptionFlag | reconfigureFlag),
	.valid_bundle_o       (instBufRenValid),
`else  
	.flush_i              (recoverFlag | exceptionFlag),
`endif

	.stall_i              (freeListEmpty | backEndFull | repairFlag),
	.instBufferReady_i    (instBufferReady),

	.renPacket_i          (renPacket),
	.renPacket_o          (renPacket_l1),

	.instBufferReady_o    (instBufferReady_l1)
	);


 /**********************************************************************************
 *  "rename" module remaps logical source and destination registers to physical
 *  source and destination registers.
 *  This module contains Rename Map Table and Speculative Free List structures.
 **********************************************************************************/

// NOTE: Rename converted to per lane modular logic.
Rename rename (
	.clk                  (clk),
	.reset                (resetLogic),
  .resetRams_i          (resetRams),
	//.reset                (reset | exceptionFlag),

`ifdef DYNAMIC_CONFIG  
  .commitLaneActive_i   (commitLaneActive),
  .dispatchLaneActive_i (dispatchLaneActive),
  .rfPartitionActive_i  (rfPartitionActive),
  .reconfigureCore_i    (reconfigureFlag),
`endif  

	.stall_i              (backEndFull),

	.instBufferReady_i    (instBufferReady_l1),

	.renPacket_i          (renPacket_l1),
	.disPacket_o          (disPacket),

	.phyDest_o            (phyDest),

	.freedPhyReg_i        (freedPhyReg),

	/* .repairPacket_i       (repairPacket), */

	.recoverFlag_i        (recoverFlag),
	.repairFlag_i         (repairFlag),
	.repairAddr_i         (repairAddr),
	.repairData_i         (repairData),
`ifdef PERF_MON
	.freeListCnt_o        (freeListCnt),
`endif

	.freeListEmpty_o      (freeListEmpty),
	.renameReady_o        (renameReady),

  .rmtRamReady_o        (rmtRamReady),
  .flRamReady_o         (flRamReady)
	);


/*********************************************************************************
* "renDis" module is the pipeline stage between Rename and Dispatch Stage.
*
**********************************************************************************/

RenameDispatch renDis (
	.clk                   (clk),
	.reset                 (resetLogic),

`ifdef DYNAMIC_CONFIG  
  .laneActive_i          (dispatchLaneActive),  
  .valid_bundle_o        (renDisValid),
	.flush_i               (recoverFlag | exceptionFlag | reconfigureFlag),
`else
	.flush_i               (recoverFlag | exceptionFlag),
`endif  
	.stall_i               (backEndFull),

	.renameReady_i         (renameReady),

	.disPacket_i           (disPacket),
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
	.reset                 (resetLogic),

`ifdef DYNAMIC_CONFIG  
  .dispatchLaneActive_i  (dispatchLaneActive),
  .execLaneActive_i      (execLaneActive),
  .saluLaneActive_i      (saluLaneActive),
  .caluLaneActive_i      (caluLaneActive),
  .alPartitionActive_i   (alPartitionActive),
  .iqPartitionActive_i   (iqPartitionActive),
  .lsqPartitionActive_i  (lsqPartitionActive),
  .reconfigureCore_i     (reconfigureFlag),    
`endif  

	.renameReady_i         (renameReady_l1),

	.recoverFlag_i         (recoverFlag),
	.recoverPC_i           (recoverPC),
	.loadViolation_i       (loadViolation),
	//.commitCsr_i           (commitCsr),
  // TODO: See if ramReady is really required. Is the freeList RAM being reset?
  // Can it simply not be rolled back?
  .iqflRamReady_i        (iqflRamReady),

	.disPacket_i           (disPacket_l1),
	.alID_i                (alID),
	.lsqID_i               (lsqID),

	.iqPacket_o            (iqPacket),
	.alPacket_o            (alPacket),
	.lsqPacket_o           (lsqPacket),
  .disExcptPacket_o      (disExcptPacket),

	.loadQueueCnt_i        (ldqCount),
	.storeQueueCnt_i       (stqCount),
	.issueQueueCnt_i       (cntInstIssueQ),
	.activeListCnt_i       (activeListCnt),
`ifdef PERF_MON
  .loadStall_o           (loadStall),
  .storeStall_o          (storeStall),
  .iqStall_o             (iqStall),
  .alStall_o             (alStall),
`endif
  // When high, indicates a packet is being dispatched this cycle.
	.dispatchReady_o       (dispatchReady),
	.backEndFull_o         (backEndFull)
	//.stallForCsr_o         (stallForCsr)
);


/************************************************************************************
* "issueq" module implements wake-up and select logic.
*
************************************************************************************/

// The issueQueue acts as the pipeline stage between dispatch and backend
`ifdef DYNAMIC_CONFIG  
  IssueQueuePartition issueq (
`else
  IssueQueue issueq (
`endif
	.clk                  (clk),
	.reset                (resetLogic),
  .resetRams_i          (resetRams),
	.flush_i              (recoverFlag | exceptionFlag),

`ifdef DYNAMIC_CONFIG  
  .issueLaneActive_i    (issueLaneActive),
  .dispatchLaneActive_i (dispatchLaneActive),
  .execLaneActive_i     (execLaneActive),
  .iqPartitionActive_i  (iqPartitionActive),
  .reconfigureCore_i    (loadNewConfig),
`endif  

	.exceptionFlag_i      (exceptionFlag),
  // When high, indicates a packet is being dispatched this cycle.
	.dispatchReady_i      (dispatchReady),

	.phyDest_i            (phyDest),

	.iqPacket_i           (iqPacket),

`ifdef AGE_BASED_ORDERING
	.alHead_i             (alHead),
	.alTail_i             (alTail),
	.alID_i               (alID),
	.lsqID_i              (lsqID),
`endif

	.rrPacket_o           (rrPacket),

`ifdef DYNAMIC_CONFIG
  .valid_bundle_o       (disIqValid),
`endif  

`ifdef PERF_MON
  .reqCount_o           (iqReqCount),
  .issuedCount_o        (iqIssuedCount),
`endif
	// this input comes from the bypass coming out of the load-store execution pipe
  // Instructions dependent on loads should only be woken up when the load completes
  // execution. Hence the bypass tag is used to wake up such instructions instead
  // internal RSR tag
	.rsr0Tag_i            ({bypassPacket[0].tag, bypassPacket[0].valid}),

	.cntInstIssueQ_o      (cntInstIssueQ),

  .iqflRamReady_o       (iqflRamReady)
);


/************************************************************************************
* "iq_regread" module is the pipeline stage between Issue Queue stage and physical
* register file read stage.
*
* This module also interfaces with RSR.
*
************************************************************************************/
IssueQRegRead iq_regread (

	.clk                  (clk),
	.reset                (resetLogic),

`ifdef DYNAMIC_CONFIG
  .laneActive_i         (execLaneActive),
	.flush_i              (recoverFlag | exceptionFlag | loadNewConfig),
`else
	.flush_i              (recoverFlag | exceptionFlag),
`endif

`ifdef DYNAMIC_CONFIG
  .valid_bundle_o       (iqRegReadValid),
`endif  
	.rrPacket_i           (rrPacket),
	.rrPacket_o           (rrPacket_l1)
);


/************************************************************************************
* THE FOLLOWING IS THE INSTANTIATION OF THE PHYSICAL REGISTER FILE
************************************************************************************/

// NOTE: Not much opportunity for per lane logic except for
// gating the decoder and output muxes. This has to be decided
// based on power numbers.
PhyRegFile registerfile (

	.clk(clk),
	.reset(resetLogic),

`ifdef DYNAMIC_CONFIG  
  .execLaneActive_i     (execLaneActive),
  .rfPartitionActive_i  (rfPartitionActive),
`endif  

`ifdef DYNAMIC_CONFIG
	/* inputs coming from the r-r stage */
	.phySrc1_i            (phySrc1_PRF),
	.phySrc2_i            (phySrc2_PRF),
	// inputs coming from the writeback stage
	.bypassPacket_i       (bypassPacket_PRF),
`else
	/* inputs coming from the r-r stage */
	.phySrc1_i            (phySrc1),
	.phySrc2_i            (phySrc2),
	// inputs coming from the writeback stage
	.bypassPacket_i       (bypassPacket),
`endif


	// outputs going to the r-r stage
	.src1Data_o           (src1Data),
	.src2Data_o           (src2Data),

	/* Initialize the PRF from top */
  .debugPRFAddr_i       (debugPRFAddr_i),
  .debugPRFWrData_i     (debugPRFWrData_i),             
  .debugPRFWrEn_i       (debugPRFWrEn_i),
  .debugPRFRdData_o     (debugPRFRdData_o)

);


/************************************************************************************
* THE FOLLOWING IS THE INSTANTIATION OF THE SUPERVISORY REGISTER FILE
************************************************************************************/
SupRegFile supregisterfile (

	.clk                  (clk),
	.reset                (resetLogic),
	.flush_i              (recoverFlag | exceptionFlag),

  .regWrData_i          (csrWrData),
  .regWrAddr_i          (csrWrAddr),
  .regWrEn_i            (csrWrEn),
  .commitReg_i          (commitCsr),

  .regRdAddr_i          (csrRdAddr),  
  .regRdEn_i            (csrRdEn),
  .regRdData_o          (csrRdData),

  .totalCommit_i        (totalCommit),
  .exceptionFlag_i      (exceptionFlag),
  .exceptionPC_i        (exceptionPC),
  .exceptionCause_i     (exceptionCause),
  .stCommitAddr_i       (stCommitAddr),
  .ldCommitAddr_i       (ldCommitAddr),
  .sretFlag_i           (sretFlag),

  .csr_fflags_i		(csr_fflags),		//Changes: Mohit (Update CSR_FFLAGS at retire)

  .atomicRdVioFlag_o    (csrViolateFlag),
  .interruptPending_o   (interruptPending),
  .csr_epc_o            (csr_epc),
  .csr_evec_o           (csr_evec),


  .csr_status_o		(csr_status),		//Changes: Mohit (Check for FP_DISABLED)
  .csr_frm_o		(csr_frm)		//Changes: Mohit (Pass-through to FP-ALU for dynamic rounding mode)

);

/************************************************************************************
* THE FOLLOWING ARE THE INSTANTIATIONS OF THE EXECUTION PIPES
************************************************************************************/

ExecutionPipe_M 
	exePipe0 (

	.clk                  (clk),
	.reset                (resetLogic),
	.recoverFlag_i        (recoverFlag),
	.exceptionFlag_i      (exceptionFlag),

`ifdef DYNAMIC_CONFIG  
  .laneActive_i         (execLaneActive[0]),
`endif  

	// inputs coming from the register file
	.src1Data_i           (src1Data[0]),
	.src2Data_i           (src2Data[0]),

	// input from the issue queue going to the reg read stage
	.rrPacket_i           (rrPacket_l1[0]),

	// bypasses coming from adjacent execution pipes
	.bypassPacket_i       (bypassPacket),

	// bypass going from this pipe to other pipes
	.bypassPacket_o       (bypassPacket_a1[0]),

	// output going to the active list from the load store pipe
	.ctrlPacket_o         (ctrlPacket_a1[0]),

	// the output from the agen going to the lsu via the agenlsu latch
	.memPacket_o          (memPacket),

	// inputs from the lsu coming to the writeback stage
	.wbPacket_i           (wbPacket),
	.ldVioPacket_i        (ldVioPacket),
	.ldVioPacket_o        (ldVioPacket_l1),

	// source operands extracted from the packet going to the physical register file
	.phySrc1_o            (phySrc1[0]),
	.phySrc2_o            (phySrc2[0])

);


ExecutionPipe_Ctrl
	exePipe1 (

	.clk                  (clk),
	.reset                (resetLogic),
	.recoverFlag_i        (recoverFlag),
	.exceptionFlag_i      (exceptionFlag),

`ifdef DYNAMIC_CONFIG  
  .laneActive_i         (execLaneActive[1]),
`endif  

	// inputs coming from the register file
	.src1Data_i           (src1Data[1]),
	.src2Data_i           (src2Data[1]),

	// input from the issue queue going to the reg read stage
	.rrPacket_i           (rrPacket_l1[1]),

	// bypasses coming from adjacent execution pipes
	.bypassPacket_i       (bypassPacket),

	// bypass going from this pipe to other pipes
	.bypassPacket_o       (bypassPacket_a1[1]),

	// outputs going to the active list
	.ctrlPacket_o         (ctrlPacket_a1[1]),

	// miscellaneous signals going to frontend stages as well as to other execution pipes
	.exeCtrlPC_o          (exeCtrlPC),
	.exeCtrlType_o        (exeCtrlType),
	.exeCtrlValid_o       (exeCtrlValid),
	.exeCtrlNPC_o         (exeCtrlNPC),
	.exeCtrlDir_o         (exeCtrlDir),
	.exeCtiID_o           (exeCtiID),

	// source operands extracted from the packet going to the physical register file
	.phySrc1_o            (phySrc1[1]),
	.phySrc2_o            (phySrc2[1]),

	.csrRdAddr_o          (csrRdAddr),
	.csrRdEn_o            (csrRdEn),
	.csrRdData_i          (csrRdData),
  .csrWrData_o          (csrWrData),
  .csrWrAddr_o          (csrWrAddr),
  .csrWrEn_o            (csrWrEn)

);


localparam SIMPLE_VECT  = `SIMPLE_VECT;
localparam COMPLEX_VECT = `COMPLEX_VECT;
localparam FP_VECT      = `FP_VECT;

ExecutionPipe_SC #(
	.SIMPLE               (SIMPLE_VECT[2]),
	.COMPLEX              (COMPLEX_VECT[2]),
  .FP                   (FP_VECT[2])
)
	exePipe2 (

	.clk                  (clk),
	.reset                (resetLogic),
  .toggleFlag_o         (toggleFlag[2]),

`ifdef DYNAMIC_CONFIG  
  .laneActive_i         (execLaneActive[2]),
  .saluLaneActive_i     (saluLaneActive[2] & execLaneActive[2]),
  .caluLaneActive_i     (caluLaneActive[2] & execLaneActive[2]),
`endif  

	.recoverFlag_i        (recoverFlag),
	.exceptionFlag_i      (exceptionFlag),

	// inputs coming from the register file
	.src1Data_i           (src1Data[2]),
	.src2Data_i           (src2Data[2]),

	// input from the issue queue going to the reg read stage
	.rrPacket_i           (rrPacket_l1[2]),

	// bypasses coming from adjacent execution pipes
	.bypassPacket_i       (bypassPacket),

	.csr_frm_i	      (csr_frm),

	// bypass going from this pipe to other pipes
	.bypassPacket_o       (bypassPacket_a1[2]),

	// output going to the active list from the simple pipe
	.ctrlPacket_o         (ctrlPacket_a1[2]),

	// source operands extracted from the packet going to the physical register file
	.phySrc1_o            (phySrc1[2]),
	.phySrc2_o            (phySrc2[2]),
	
	
  	.fpExcptPacket_o     (fpExcptPacket)	//Changes: Mohit (Write FP_Exception Packet to Activelist)
);


`ifdef ISSUE_FOUR_WIDE
ExecutionPipe_SC #(
	.SIMPLE               (SIMPLE_VECT[3]),
	.COMPLEX              (COMPLEX_VECT[3])
)
	exePipe3 (

	.clk                  (clk),
	.reset                (resetLogic),
  .toggleFlag_o         (toggleFlag[3]),

`ifdef DYNAMIC_CONFIG  
  .laneActive_i         (execLaneActive[3]),
  .saluLaneActive_i     (saluLaneActive[3] & execLaneActive[3]),
  .caluLaneActive_i     (caluLaneActive[3] & execLaneActive[3]),
`endif

	.recoverFlag_i        (recoverFlag),
	.exceptionFlag_i      (exceptionFlag),

	// inputs coming from the register file
	.src1Data_i           (src1Data[3]),
	.src2Data_i           (src2Data[3]),

	// input from the issue queue going to the reg read stage
	.rrPacket_i           (rrPacket_l1[3]),

	// bypasses coming from adjacent execution pipes
	.bypassPacket_i       (bypassPacket),

	// bypass going from this pipe to other pipes
	.bypassPacket_o       (bypassPacket_a1[3]),

	// output going to the active list from the simple pipe
	.ctrlPacket_o         (ctrlPacket_a1[3]),

	// source operands extracted from the packet going to the physical register file
	.phySrc1_o            (phySrc1[3]),
	.phySrc2_o            (phySrc2[3])
);

`endif


`ifdef ISSUE_FIVE_WIDE
ExecutionPipe_SC #(
	.SIMPLE               (SIMPLE_VECT[4]),
	.COMPLEX              (COMPLEX_VECT[4])
)
	exePipe4 (

	.clk                  (clk),
	.reset                (resetLogic),
  .toggleFlag_o         (toggleFlag[4]),

`ifdef DYNAMIC_CONFIG  
  .laneActive_i         (execLaneActive[4]),
  .saluLaneActive_i     (saluLaneActive[4] & execLaneActive[4]),
  .caluLaneActive_i     (caluLaneActive[4] & execLaneActive[4]),
`endif

	.recoverFlag_i        (recoverFlag),
	.exceptionFlag_i      (exceptionFlag),

	// inputs coming from the register file
	.src1Data_i           (src1Data[4]),
	.src2Data_i           (src2Data[4]),

	// input from the issue queue going to the reg read stage
	.rrPacket_i           (rrPacket_l1[4]),

	// bypasses coming from adjacent execution pipes
	.bypassPacket_i       (bypassPacket),

	// bypass going from this pipe to other pipes
	.bypassPacket_o       (bypassPacket_a1[4]),

	// output going to the active list from the simple pipe
	.ctrlPacket_o         (ctrlPacket_a1[4]),

	// source operands extracted from the packet going to the physical register file
	.phySrc1_o            (phySrc1[4]),
	.phySrc2_o            (phySrc2[4])
);

`endif


`ifdef ISSUE_SIX_WIDE
ExecutionPipe_SC #(
	.SIMPLE               (SIMPLE_VECT[5]),
	.COMPLEX              (COMPLEX_VECT[5])
)
	exePipe5 (

	.clk                  (clk),
	.reset                (resetLogic),
  .toggleFlag_o         (toggleFlag[5]),

`ifdef DYNAMIC_CONFIG  
  .laneActive_i         (execLaneActive[5]),
  .saluLaneActive_i     (saluLaneActive[5] & execLaneActive[5]),
  .caluLaneActive_i     (caluLaneActive[5] & execLaneActive[5]),
`endif

	.recoverFlag_i        (recoverFlag),
	.exceptionFlag_i      (exceptionFlag),

	// inputs coming from the register file
	.src1Data_i           (src1Data[5]),
	.src2Data_i           (src2Data[5]),

	// input from the issue queue going to the reg read stage
	.rrPacket_i           (rrPacket_l1[5]),

	// bypasses coming from adjacent execution pipes
	.bypassPacket_i       (bypassPacket),

	// bypass going from this pipe to other pipes
	.bypassPacket_o       (bypassPacket_a1[5]),

	// output going to the active list from the simple pipe
	.ctrlPacket_o         (ctrlPacket_a1[5]),

	// source operands extracted from the packet going to the physical register file
	.phySrc1_o            (phySrc1[5]),
	.phySrc2_o            (phySrc2[5])
);

`endif


`ifdef ISSUE_SEVEN_WIDE
ExecutionPipe_SC #(
	.SIMPLE               (SIMPLE_VECT[6]),
	.COMPLEX              (COMPLEX_VECT[6])
)
	exePipe6 (

	.clk                  (clk),
	.reset                (resetLogic),
  .toggleFlag_o         (toggleFlag[6]),

`ifdef DYNAMIC_CONFIG  
  .laneActive_i         (execLaneActive[6]),
  .saluLaneActive_i     (saluLaneActive[6] & execLaneActive[6]),
  .caluLaneActive_i     (caluLaneActive[6] 7 execLaneActive[6]),
`endif

	.recoverFlag_i        (recoverFlag),
	.exceptionFlag_i      (exceptionFlag),

	// inputs coming from the register file
	.src1Data_i           (src1Data[6]),
	.src2Data_i           (src2Data[6]),

	// input from the issue queue going to the reg read stage
	.rrPacket_i           (rrPacket_l1[6]),

	// bypasses coming from adjacent execution pipes
	.bypassPacket_i       (bypassPacket),

	// bypass going from this pipe to other pipes
	.bypassPacket_o       (bypassPacket_a1[6]),

	// output going to the active list from the simple pipe
	.ctrlPacket_o         (ctrlPacket_a1[6]),

	// source operands extracted from the packet going to the physical register file
	.phySrc1_o            (phySrc1[6]),
	.phySrc2_o            (phySrc2[6])
);

`endif


`ifdef ISSUE_EIGHT_WIDE
ExecutionPipe_SC #(
	.SIMPLE               (SIMPLE_VECT[7]),
	.COMPLEX              (COMPLEX_VECT[7])
)
	exePipe7 (

	.clk                  (clk),
	.reset                (resetLogic),
  .toggleFlag_o         (toggleFlag[7]),

`ifdef DYNAMIC_CONFIG  
  .laneActive_i         (execLaneActive[7]),
  .saluLaneActive_i     (saluLaneActive[7] & execLaneActive[7]),
  .caluLaneActive_i     (caluLaneActive[7] & execLaneActive[7]),
`endif

	.recoverFlag_i        (recoverFlag),
	.exceptionFlag_i      (exceptionFlag),

	// inputs coming from the register file
	.src1Data_i           (src1Data[7]),
	.src2Data_i           (src2Data[7]),

	// input from the issue queue going to the reg read stage
	.rrPacket_i           (rrPacket_l1[7]),

	// bypasses coming from adjacent execution pipes
	.bypassPacket_i       (bypassPacket),

	// bypass going from this pipe to other pipes
	.bypassPacket_o       (bypassPacket_a1[7]),

	// output going to the active list from the simple pipe
	.ctrlPacket_o         (ctrlPacket_a1[7]),

	// source operands extracted from the packet going to the physical register file
	.phySrc1_o            (phySrc1[7]),
	.phySrc2_o            (phySrc2[7])
);

`endif

always_comb
begin
  int i;
  for(i=0;i<`ISSUE_WIDTH;i++)
  begin
    bypassPacket[i] = bypassPacket_a1[i];
    ctrlPacket[i]   = ctrlPacket_a1[i];
    

    `ifdef DYNAMIC_CONFIG
      // Clamp the valid bits so that any floating output from off lanes
      // do not affect the on lanes.
      bypassPacket[i].valid   = execLaneActive[i] ? bypassPacket_a1[i].valid : 1'b0;
      ctrlPacket[i].valid     = execLaneActive[i] ? ctrlPacket_a1[i].valid : 1'b0;
    `endif
  end
end

assign toggleFlag[0]  = 1'b0; //Mem Lane
assign toggleFlag[1]  = 1'b0; //Ctrl Lane

// This serves as a signal to the outside world that the chip
// is alive. 
always_ff @(posedge clk or posedge resetLogic)
begin
  if(resetLogic)
  begin
    toggleFlag_o  <= 1'b0;
  end
  else
  begin
    `ifdef DYNAMIC_CONFIG
      toggleFlag_o  <= toggleFlag_o ^ (|(toggleFlag & issueLaneActive));
    `else
      toggleFlag_o  <= toggleFlag_o ^ (|toggleFlag);
    `endif
  end
end


/************************************************************************************
* "lsu" module is the pipeline stage between functional unit-3 (address generator)
*  stage and data cache. The pipeline stage contains load-store address disambiguation
*  logic.
*
*  The module interfaces with AGEN and Writeback modules.
*
************************************************************************************/
// TODO: Opportunity for per lane gating present but needs rewriting some 
// code.
LSU lsu (
	.clk                  (clk),
	.reset                (resetLogic),
  .resetRams_i          (resetRams),
 
`ifdef SCRATCH_PAD  
  .dataScratchAddr_i    (dataScratchAddr_i),
  .dataScratchWrData_i  (dataScratchWrData_i),
  .dataScratchWrEn_i    (dataScratchWrEn_i),
  .dataScratchRdData_o  (dataScratchRdData_o),
  .dataScratchPadEn_i   (dataScratchPadEn_i),
`endif  

`ifdef DYNAMIC_CONFIG  
  .dispatchLaneActive_i (dispatchLaneActive),
  .commitLaneActive_i   (commitLaneActive_i),
  .lsqPartitionActive_i (lsqPartitionActive),
`endif  


`ifdef DATA_CACHE
  .dataCacheBypass_i    (dataCacheBypass_i),
  .dcScratchModeEn_i    (dcScratchModeEn_i),

  .dc2memLdAddr_o       (dc2memLdAddr_o     ), // memory read address
  .dc2memLdValid_o      (dc2memLdValid_o    ), // memory read enable
                                           
  .mem2dcLdTag_i        (mem2dcLdTag_i      ), // tag of the incoming datadetermine
  .mem2dcLdIndex_i      (mem2dcLdIndex_i    ), // index of the incoming data
  .mem2dcLdData_i       (mem2dcLdData_i     ), // requested data
  .mem2dcLdValid_i      (mem2dcLdValid_i    ), // indicates the requested data is ready
                                           
  .dc2memStAddr_o       (dc2memStAddr_o     ), // memory read address
  .dc2memStData_o       (dc2memStData_o     ), // memory read address
  .dc2memStSize_o       (dc2memStSize_o     ), // memory read address
  .dc2memStValid_o      (dc2memStValid_o    ), // memory read enable
                                           
  .mem2dcStComplete_i   (mem2dcStComplete_i ),
  .mem2dcStStall_i      (mem2dcStStall_i    ),

  .stallStCommit_o      (stallStCommit    ),

  .dcScratchWrAddr_i    (dcScratchWrAddr_i),
  .dcScratchWrEn_i      (dcScratchWrEn_i  ),
  .dcScratchWrData_i    (dcScratchWrData_i),
  .dcScratchRdData_o    (dcScratchRdData_o),

  .dcFlush_i            (dcFlush_i),
  .dcFlushDone_o        (dcFlushDone_o),
`endif    

`ifdef PERF_MON
  `ifdef DATA_CACHE
    .ldMiss_o           (ldMiss),
    .stMiss_o           (stMiss),
  `endif
`endif

	.recoverFlag_i        (recoverFlag | exceptionFlag),
  // When high, indicates a packet is being dispatched this cycle.
	.dispatchReady_i      (dispatchReady),

	.lsqPacket_i          (lsqPacket),
	
	.lsqID_o              (lsqID),

	.commitLoad_i         (commitLoad),
	.commitStore_i        (commitStore),

	.memPacket_i          (memPacket),

	.ldqCount_o           (ldqCount),
	.stqCount_o           (stqCount),

	.wbPacket_o           (wbPacket),
	.ldVioPacket_o        (ldVioPacket),
  .memExcptPacket_o     (memExcptPacket),
  .stCommitAddr_o       (stCommitAddr),
  .ldCommitAddr_o       (ldCommitAddr),

	.ldAddr_o             (ldAddr_o),
	.ldData_i             (ldData_i),
  .ldDataValid_i        (ldDataValid_i),
	.ldEn_o               (ldEn_o),
  .ldException_i        (ldException_i),

	.stAddr_o             (stAddr_o),
	.stData_o             (stData_o),
	.stEn_o               (stEn_o),
  .stException_i        (stException_i),

  .ldStSize_o           (ldStSize_o),

  .ldqRamReady_o        (ldqRamReady),
  .stqRamReady_o        (stqRamReady)
	);



/************************************************************************************
* "activeList" module is the pipeline stage between Dispatch stage and out-of-order
*  back-end.
*  The module interfaces with Active List, Issue Queue and Load-Store Queue.
*
************************************************************************************/

// NOTE: Not much opportunity for per lane power gating.
// Most of the logic is monolitic except some minor combinational
// logic.

ActiveList activeList(
	.clk                  (clk),
	.reset                (resetLogic),
  .resetRams_i          (resetRams),

`ifdef DYNAMIC_CONFIG  
  .dispatchLaneActive_i (dispatchLaneActive),
  .issueLaneActive_i    (issueLaneActive),
  .commitLaneActive_i   (commitLaneActive),
  .alPartitionActive_i  (alPartitionActive),
  .squashPipe_i         (1'b0),
`endif  

//`ifdef DATA_CACHE
//  .stallStCommit_i      (stallStCommit),
//`else
  .stallStCommit_i      (1'b0),
//`endif

  // When high, indicates a packet is being dispatched this cycle.
	.dispatchReady_i      (dispatchReady),

	.alPacket_i           (alPacket),

	.alHead_o             (alHead),
	.alTail_o             (alTail),
	.alID_o               (alID),

	.ctrlPacket_i         (ctrlPacket),

	.ldVioPacket_i        (ldVioPacket_l1),
  .memExcptPacket_i     (memExcptPacket),
  .disExcptPacket_i     (disExcptPacket),
  .fpExcptPacket_i     (fpExcptPacket),	//Changes: Mohit (FP_Exception Packet generated in FP execution unit)
  .csrViolateFlag_i     (csrViolateFlag),
  .interruptPending_i   (interruptPending),

  .csr_epc_i            (csr_epc),
  .csr_evec_i           (csr_evec),
  .sretFlag_o           (sretFlag),

	.activeListCnt_o      (activeListCnt),

	.amtPacket_o          (amtPacket),
`ifdef PERF_MON
  .commitValid_o        (commitValid),
`endif
	.totalCommit_o        (totalCommit),
	.commitStore_o        (commitStore),
	.commitLoad_o         (commitLoad),

	.commitCti_o          (commitCti),
	.actualDir_o          (actualDir_o),
	.ctrlType_o           (ctrlType_o),

	.commitCsr_o          (commitCsr),

	.recoverFlag_o        (recoverFlag),
	.recoverPC_o          (recoverPC),

	.exceptionFlag_o      (exceptionFlag),
	.exceptionPC_o        (exceptionPC),
	.exceptionCause_o     (exceptionCause),

	.loadViolation_o      (loadViolation),
  	.alRamReady_o         (alRamReady),
        .csr_fflags_o         (csr_fflags)	//Changes: Mohit (Update CSR_FFLAGS at retire)
	);


/************************************************************************************
* "amt" module is the pipeline stage between Dispatch stage and out-of-order
*  back-end.
*  The module interfaces with ActiveList Pipe, Issue Queue and Load-Store Queue.
*
************************************************************************************/

//TODO: Fix the repair mechanism so that it can change dynamically 
// depending upon the number of read ports in AMT and number of
// write ports in RMT. 
// *** Might be able to use all ports (even inactive ones) but this
// might have higer penalty of restoring RAMs and all. Rather just
// use the active ports
ArchMapTable amt(

	.clk                  (clk),
  .resetRams_i          (resetRams),

`ifdef DYNAMIC_CONFIG  
	.reset                (resetLogic | loadNewConfig), // Needs to be reset to original mapping
  .commitLaneActive_i   (commitLaneActive),
`else  
	.reset                (resetLogic),
`endif  

	.debugAMTAddr_i       (debugAMTAddr_i),
	.debugAMTRdData_o     (debugAMTRdData_o),
	
	.recoverFlag_i        (recoverFlag),
	.exceptionFlag_i      (exceptionFlag),

	.amtPacket_i          (amtPacket),

	.freedPhyReg_o        (freedPhyReg),
`ifdef DYNAMIC_CONFIG  
	.consolidateFlag_i    (consolidateFlag),
	.logAddr_i	          (logAddr),
	.phyAddr_o	          (phyAddrFromAMT),	
`endif  
	.repairFlag_o         (repairFlag),
	/* .repairPacket_o       (repairPacket) */
	.repairAddr_o         (repairAddr),
	.repairData_o         (repairData),

  .amtRamReady_o        (amtRamReady)
	);


/**************************************************************************************
* This unit captures all vital counters that can be used to monitor performance.

**************************************************************************************/
`ifdef PERF_MON
 
PerfMon perfmon (
	.clk                  (clk),
	.reset                (resetLogic),
	.perfMonRegAddr_i     (perfMonRegAddr_i),
	.perfMonRegData_o     (perfMonRegData_o),
  .perfMonRegRun_i      (perfMonRegRun_i),
  .perfMonRegClr_i      (perfMonRegClr_i),
  .perfMonRegGlobalClr_i(perfMonRegGlobalClr_i),
`ifdef DATA_CACHE  
  .loadMiss_i           (ldMiss),
  .storeMiss_i          (stMiss),
  .l2InstFetchReq_i     (dc2memLdValid_o),
`endif  
`ifdef INST_CACHE  
  .instMiss_i           (icMiss),
  .l2DataFetchReq_i     (ic2memReqValid_o),
`endif  
  .commitStore_i        (commitStore),
  .commitLoad_i         (commitLoad),
  .recoverFlag_i        (recoverFlag),
  .loadViolation_i      (loadViolation),
  .totalCommit_i        (totalCommit),
	.ibCount_i            (instBuffCount),
	.flCount_i            (freeListCnt),
	.iqCount_i            (cntInstIssueQ),
	.ldqCount_i           (ldqCount),
	.stqCount_i	          (stqCount),
	.alCount_i            (activeListCnt),
`ifdef DYNAMIC_CONFIG  
  .fetch1_stall_i       (instBufferFull | ctiQueueFull),   
`else
  .fetch1_stall_i       (instBufferFull | ctiQueueFull),   
`endif
  .ctiq_stall_i         (ctiQueueFull),    
  .instBuf_stall_i      (instBufferFull), 
  .freelist_stall_i     (freeListEmpty),
  .backend_stall_i      (backEndFull), 
  .ldq_stall_i          (loadStall),     
  .stq_stall_i          (storeStall),     
  .iq_stall_i           (iqStall),      
  .rob_stall_i          (alStall),
	.fs1Fs2Valid_i        (fs1Fs2Valid),     
	.fs2DecValid_i        (fs2DecValid),     
	.renDisValid_i        (renDisValid),     
	.instBufRenValid_i    (instBufRenValid),
	.disIqValid_i         (disIqValid), 
	.iqRegReadValid_i     (iqRegReadValid),
  
  .iqReqCount_i         (iqReqCount),
  .iqIssuedCount_i      (iqIssuedCount)
	);
`endif

`ifdef DYNAMIC_CONFIG
RegisterConsolidate rc (
	.clk			            (clk),
	.reset			          (resetLogic),
	
	.startConsolidate_i	  (beginConsolidation),
	.phyAddrAMT_i         (phyAddrFromAMT),
	.phySrc1_i  	        (phySrc1),
	.phySrc2_i  	        (phySrc2),
  .bypassPacket_i       (bypassPacket),
	.regVal_byte0_i       (src1Data_byte0),
	.regVal_byte1_i       (src1Data_byte1),
	.regVal_byte2_i       (src1Data_byte2),
	.regVal_byte3_i       (src1Data_byte3),
	.regVal_byte4_i       (src1Data_byte4),
	.regVal_byte5_i       (src1Data_byte5),
	.regVal_byte6_i       (src1Data_byte6),
	.regVal_byte7_i       (src1Data_byte7),

	.logAddr_o		        (logAddr),
	.phySrc1_rd_o		      (phySrc1_PRF),
	.phySrc2_rd_o		      (phySrc2_PRF),
  .bypassPacket_o       (bypassPacket_PRF),
	.consolidateFlag_o    (consolidateFlag),
	.doneConsolidate_o	  (consolidationDone)
);

/**************************************************************************************
* This is a place holder for the power management unit that will be plugged in
* to control dynamic reconfiguartion of the core
*
*
**************************************************************************************/
PowerManager PwrMan
( 
  .clk                  (clk),
  .reset                (resetLogic),

  .fetchLaneActive_i    (fetchLaneActive_i),
  .dispatchLaneActive_i (dispatchLaneActive_i),
  .issueLaneActive_i    (issueLaneActive_i),
  .execLaneActive_i     (execLaneActive_i),
  .saluLaneActive_i     (saluLaneActive_i),
  .caluLaneActive_i     (caluLaneActive_i),
  .commitLaneActive_i   (commitLaneActive_i),
  .rfPartitionActive_i  (rfPartitionActive_i),
  .alPartitionActive_i  (alPartitionActive_i),
  .lsqPartitionActive_i (lsqPartitionActive_i),
  .iqPartitionActive_i  (iqPartitionActive_i),
  .ibuffPartitionActive_i(ibuffPartitionActive_i),


  .reconfigureCore_i    (reconfigureCore_i),
  .stallFetch_i         (stallFetch_i),
  .activeListCnt_i      (activeListCnt),
  .fs1Fs2Valid_i        (fs1Fs2Valid),
  .fs2DecValid_i        (fs2DecValid),
  .instBufRenValid_i    (instBufRenValid),
  .renDisValid_i        (renDisValid),
  .disIqValid_i         (disIqValid),
  .ibuffInsufficientCnt_i(ibuffInsufficientCnt),

  .consolidationDone_i  (consolidationDone),

  .fetchLaneActive_o    (fetchLaneActive),
  .dispatchLaneActive_o (dispatchLaneActive),
  .issueLaneActive_o    (issueLaneActive),
  .execLaneActive_o     (execLaneActive),
  .saluLaneActive_o     (saluLaneActive),
  .caluLaneActive_o     (caluLaneActive),
  .commitLaneActive_o   (commitLaneActive),
  .rfPartitionActive_o  (rfPartitionActive),
  .alPartitionActive_o  (alPartitionActive),
  .lsqPartitionActive_o (lsqPartitionActive),
  .iqPartitionActive_o  (iqPartitionActive),
  .ibuffPartitionActive_o(ibuffPartitionActive),

  .reconfigureFlag_o    (reconfigureFlag),
  .loadNewConfig_o      (loadNewConfig),
  .drainPipeFlag_o      (stallFetch),
  .beginConsolidation_o (beginConsolidation),
  .reconfigDone_o       (reconfigDone_o),
  .pipeDrained_o        (pipeDrained_o)
);
`endif

endmodule
