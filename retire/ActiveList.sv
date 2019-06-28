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

/* Algorithm:

   1. Active List is a circular buffer with head and tail pointers.
      New instructions are written at the tail and old instructions are
      retired from the head.

   2. Receives 4 or 0 new insturctions from the Dispatch stage, along
      with back-end Ready signal.
      If there is no empty space in Issue Queue or Active List or Load-Store
      Queue, then back-end Ready is low.

   3. For each new instruction following information should be registered
      into ActiveList RAM:
      (a.) PC of instruction
      (b.) Logical destination register
      (c.) Current physical destination register mapping
      (d.) Old physical destination register mapping
      (e.) Control info -> [Executed, Exception, Mispredict for branches]
      Instruction info (a.,b.,c. & d.) doesn't change over time. Info e. is
      writen by Functional Unit after the instruction has executed.

   4. ActiveList ID is generated for each incoming instructions and sent to
      Issue Queue module and Load-Store Queue module.

   5. Upto 4 instructions are commited each cycle based on the Executed bit
      associated with each buffer entry.

   6. On a commit, current physical mapping is writen into Arch Map Table
      and old destination physical mapping is freed (written back to Spec
      free list).

   7. Maintains a total entry counter, which counts number of valid
      instructions in the ActiveList. The count value is used by the dispatch
      unit to generate back-end Ready signal.

   8. If there is a branch mis-predict the tail pointer is rolled back to
      offending instruction in the ActiveList.

   9. Exception is handled at the head of the ActiveList. On an exception, AMT
      is copied into RMT.


****************************************************************************/
//`ifdef GATE_SIM
//module ActiveList_tb (
//`else
module ActiveList (
//`endif
	input                                  clk,
	input                                  reset,
	input                                  resetRams_i,

`ifdef DYNAMIC_CONFIG  
  input [`DISPATCH_WIDTH-1:0]            dispatchLaneActive_i,
  input [`ISSUE_WIDTH-1:0]               issueLaneActive_i,
  input [`COMMIT_WIDTH-1:0]              commitLaneActive_i,
  input [`NUM_PARTS_AL-1:0]              alPartitionActive_i,
  input                                  squashPipe_i,
`endif  

//`ifdef DATA_CACHE
  input                                  stallStCommit_i, // Indicates that store write-through buffer is full
//`endif

	input                                  dispatchReady_i,

	input  alPkt                           alPacket_i   [0:`DISPATCH_WIDTH-1],

	input  ldVioPkt                        ldVioPacket_i,
  input  exceptionPkt                    memExcptPacket_i,
  input  exceptionPkt                    disExcptPacket_i,
  input  fpexcptPkt                    	 fpExcptPacket_i,	//Changes: Mohit(FP exception updates coming from FP_ALU)
  input                                  csrViolateFlag_i,
  input                                  interruptPending_i,
  input  [`SIZE_PC-1:0]                  csr_evec_i,
  input  [`SIZE_PC-1:0]                  csr_epc_i,
  output                                 sretFlag_o,

	/* input  [`SIZE_ACTIVELIST_LOG:0]        ldViolationPacket_i, */

	input  ctrlPkt                         ctrlPacket_i [0:`ISSUE_WIDTH-1],

	output [`SIZE_ACTIVELIST_LOG-1:0]      alHead_o,
	output [`SIZE_ACTIVELIST_LOG-1:0]      alTail_o,
	output [`SIZE_ACTIVELIST_LOG-1:0]      alID_o       [0:`DISPATCH_WIDTH-1],

	output [`SIZE_ACTIVELIST_LOG:0]        activeListCnt_o,

	/* NOTE: amtPacket_o.valid is set to 1 only if the retiring instruction has a valid
	   destination register. */
	output commitPkt                       amtPacket_o [0:`COMMIT_WIDTH-1],

`ifdef PERF_MON
  output  reg [`COMMIT_WIDTH-1:0]        commitValid_o,                 
`endif

  output     [`COMMIT_WIDTH_LOG:0]       totalCommit_o,                 
	output reg [`COMMIT_WIDTH-1:0]         commitStore_o,
	output reg [`COMMIT_WIDTH-1:0]         commitLoad_o,
	
	output reg [`COMMIT_WIDTH-1:0]         commitCti_o,
	output reg [`COMMIT_WIDTH-1:0]         actualDir_o,
	output reg [`COMMIT_WIDTH-1:0]         ctrlType_o,

	output reg                             commitCsr_o,

	output                                 recoverFlag_o,
	output [`SIZE_PC-1:0]                  recoverPC_o,

	output                                 exceptionFlag_o,
	output [`SIZE_PC-1:0]                  exceptionPC_o,
	output [`EXCEPTION_CAUSE_LOG-1:0]      exceptionCause_o,

	output                                 loadViolation_o,
  output                                 alRamReady_o,
  output     [`CSR_WIDTH-1:0]            csr_fflags_o
	);



/* Active List head pointer and tail pointer */
reg  [`SIZE_ACTIVELIST_LOG-1:0]     headPtr;
reg  [`SIZE_ACTIVELIST_LOG-1:0]     headPtr_next;
reg  [`SIZE_ACTIVELIST_LOG-1:0]     headAddr [0:`COMMIT_WIDTH-1];

reg  [`SIZE_ACTIVELIST_LOG-1:0]     tailPtr;
reg  [`SIZE_ACTIVELIST_LOG-1:0]     tailPtr_next;
reg  [`SIZE_ACTIVELIST_LOG-1:0]     tailAddr [0:`DISPATCH_WIDTH-1];

reg  [`SIZE_ACTIVELIST_LOG:0]       alCount;
reg  [`SIZE_ACTIVELIST_LOG:0]       alCount_next;
reg  [`SIZE_ACTIVELIST_LOG:0]       dispatchedInsts;

wire                                violateBit  [0:`COMMIT_WIDTH-1];
reg                                 violateFlag [0:`COMMIT_WIDTH-1];
reg                                 violateFlag_reg;
reg                                 fissionViolation;

reg                                 sretFlag [0:`COMMIT_WIDTH-1];
reg                                 csrViolateFlag [0:`COMMIT_WIDTH-1];

reg  [`SIZE_PC-1:0]                 recoverPC;

reg                                 mispredFlag [0:`COMMIT_WIDTH-1];
reg                                 mispredFlag_reg;

reg  [`SIZE_PC-1:0]                 targetPC;
wire [`SIZE_PC-1:0]                 targetAddr;

reg                                 exceptionFlag  [0:`COMMIT_WIDTH-1];
reg                                 exceptionFlag_reg;
reg  [`SIZE_PC-1:0]                 exceptionPC;
reg  [`EXCEPTION_CAUSE_LOG-1:0]     exceptionCause;

reg                                 loadViolation;
reg                                 atomicityViolation;
reg                                 interruptPending_d1;
reg                                 interruptPulse;


/* Wires and regs for the combinatorial logic */
reg  [`COMMIT_WIDTH-1:0]            totalCommit;

reg  [`COMMIT_WIDTH-1:0]            commitVector;
reg  [`COMMIT_WIDTH-1:0]            commitVector_t1;

reg  [`COMMIT_WIDTH-1:0]            commitFission;
wire [`COMMIT_WIDTH-1:0]            commitReady;


alPkt                               dataAl          [0:`COMMIT_WIDTH-1];
wire [`SIZE_EXE_FLAGS+1-1:0]        ctrlAl          [0:`COMMIT_WIDTH-1]; // 1 extra for actualDir
exceptionPkt                        exceptionAl     [0:`COMMIT_WIDTH-1];
wire  [`CSR_WIDTH-1:0]		    fp_exceptionAl  [0:`COMMIT_WIDTH-1];

`ifdef SIM
reg  [`SIZE_PC-1:0]                 commitPC     [0:`COMMIT_WIDTH-1];
/* reg                                 commitVerify [0:`COMMIT_WIDTH-1]; */

/* integer                             commitCount; */
/* integer                             commitCount_f; */

/* integer                             commitCnt [0:`COMMIT_WIDTH-1]; */

logic [`SIZE_PC-1:0]  currentCommitPC;
assign currentCommitPC = commitPC[0];

logic [`SIZE_PC-1:0] prevCommitPC;

always @(posedge clk) begin
    prevCommitPC <= currentCommitPC;
end

always @(posedge clk) begin
    if (prevCommitPC != currentCommitPC) begin
        $display("currentCommitPC changed from 0x%x to 0x%x", prevCommitPC, currentCommitPC);
    end
end
`endif

`ifdef DYNAMIC_CONFIG
  wire alDataReady;
  wire alCtrlReady;
  wire alReadyBitReady;
  wire alNPcReady;
  wire alVioReady;
`endif


/************************************************************************************
   Following instantiates RAM modules for Active List. 2 seperate RAM modules have
   been instantisted each for static and control information associated with each
   instruction.
   Modules "activeList" and "ctrlActiveList" have different Read/Write ports
   requirements. "ctrlActiveList" needs additional write ports to write the control
   information when an instruction has completed execution.
************************************************************************************/

//// BIST State Machine to Initialize RAM/CAM /////////////

localparam BIST_SIZE_ADDR   = `SIZE_ACTIVELIST_LOG;
localparam BIST_SIZE_DATA   = `AL_PKT_SIZE;
localparam BIST_SIZE_DATA1  = (`SIZE_EXE_FLAGS+1);
localparam BIST_SIZE_DATA2  = `SIZE_PC;
localparam BIST_NUM_ENTRIES = `SIZE_ACTIVELIST;
localparam BIST_RESET_MODE  = 0; //0 -> Fixed value; 1 -> Sequential values
localparam BIST_RESET_VALUE = 0; // Initialize all entries to 2=weakly taken

localparam BIST_START = 0;
localparam BIST_RUN   = 1;
localparam BIST_DONE  = 2;

logic                       bistEn;
logic [1:0]                 bistState;
logic [1:0]                 bistNextState;
logic [BIST_SIZE_ADDR-1:0]  bistAddrWr;
logic [BIST_SIZE_ADDR-1:0]  bistNextAddrWr;
logic [BIST_SIZE_DATA-1:0]  bistDataWr;
logic [BIST_SIZE_DATA1-1:0] bistDataWr1;
logic [BIST_SIZE_DATA2-1:0] bistDataWr2;


assign bistDataWr   = (BIST_RESET_MODE == 0) ? BIST_RESET_VALUE : {32'b0,bistAddrWr};
assign bistDataWr1  = (BIST_RESET_MODE == 0) ? BIST_RESET_VALUE : {32'b0,bistAddrWr};
assign bistDataWr2  = (BIST_RESET_MODE == 0) ? BIST_RESET_VALUE : {32'b0,bistAddrWr};
assign alRamReady_o = ~bistEn;

always_ff @(posedge clk or posedge resetRams_i)
begin
  if(resetRams_i)
  begin
    bistState       <= BIST_START;
    bistAddrWr      <= {BIST_SIZE_ADDR{1'b0}};
  end
  else
  begin
    bistState       <= bistNextState;
    bistAddrWr      <= bistNextAddrWr;
  end
end

always_comb
begin
  bistEn              = 1'b0;
  bistNextState       = bistState;
  bistNextAddrWr      = bistAddrWr;

  case(bistState)
    BIST_START: begin
      bistNextState   = BIST_RUN;
      bistNextAddrWr  = 0;
    end
    BIST_RUN: begin
      bistEn = 1'b1;
      bistNextAddrWr  = bistNextAddrWr + 1;

      if(bistAddrWr == BIST_NUM_ENTRIES-1)
      begin
        bistNextState = BIST_DONE;
      end
      else
      begin
        bistNextState = BIST_RUN;
      end
    end
    BIST_DONE: begin
      bistNextAddrWr  = 0;
      bistNextState   = BIST_DONE;
    end
  endcase
end

//////////////////////////////////////////////////////////

`ifdef DYNAMIC_CONFIG
ALDATA_RAM_PARTITIONED #(
`else
ALDATA_RAM #(
`endif
  .RPORT      (`COMMIT_WIDTH),
  .WPORT      (`DISPATCH_WIDTH),
	.DEPTH      (`SIZE_ACTIVELIST),
	.INDEX      (`SIZE_ACTIVELIST_LOG),
	.WIDTH      (`AL_PKT_SIZE)
	)

	activeList  (

	.addr0_i   (headAddr[0]),
	.data0_o   (dataAl[0]),

`ifdef COMMIT_TWO_WIDE
	.addr1_i   (headAddr[1]),
	.data1_o   (dataAl[1]),
`endif

`ifdef COMMIT_THREE_WIDE
	.addr2_i   (headAddr[2]),
	.data2_o   (dataAl[2]),
`endif

`ifdef COMMIT_FOUR_WIDE
	.addr3_i   (headAddr[3]),
	.data3_o   (dataAl[3]),
`endif


	.addr0wr_i (bistEn ? bistAddrWr : tailAddr[0]),
  .we0_i     (bistEn ? 1'b1       : alPacket_i[0].valid),
  .data0wr_i (bistEn ? bistDataWr : alPacket_i[0]),


`ifdef DISPATCH_TWO_WIDE
	.addr1wr_i (tailAddr[1]),
	.we1_i     (alPacket_i[1].valid),
	.data1wr_i (alPacket_i[1]),
`endif

`ifdef DISPATCH_THREE_WIDE
	.addr2wr_i (tailAddr[2]),
	.we2_i     (alPacket_i[2].valid),
	.data2wr_i (alPacket_i[2]),
`endif

`ifdef DISPATCH_FOUR_WIDE
	.addr3wr_i (tailAddr[3]),
	.we3_i     (alPacket_i[3].valid),
	.data3wr_i (alPacket_i[3]),
`endif

`ifdef DISPATCH_FIVE_WIDE
	.addr4wr_i (tailAddr[4]),
	.we4_i     (alPacket_i[4].valid),
	.data4wr_i (alPacket_i[4]),
`endif

`ifdef DISPATCH_SIX_WIDE
	.addr5wr_i (tailAddr[5]),
	.we5_i     (alPacket_i[5].valid),
	.data5wr_i (alPacket_i[5]),
`endif

`ifdef DISPATCH_SEVEN_WIDE
	.addr6wr_i (tailAddr[6]),
	.we6_i     (alPacket_i[6].valid),
	.data6wr_i (alPacket_i[6]),
`endif

`ifdef DISPATCH_EIGHT_WIDE
	.addr7wr_i (tailAddr[7]),
	.we7_i     (alPacket_i[7].valid),
	.data7wr_i (alPacket_i[7]),
`endif

`ifdef DYNAMIC_CONFIG
  .dispatchLaneActive_i(dispatchLaneActive_i),
  .commitLaneActive_i(commitLaneActive_i),
  .alPartitionActive_i(alPartitionActive_i),
  .alDataReady_o(alDataReady),
`endif

	.clk       (clk)
	//.reset     (reset | violateFlag_reg | mispredFlag_reg | exceptionFlag_reg)

	);


`ifdef DYNAMIC_CONFIG
ALCTRL_RAM_PARTITIONED #(
`else
ALCTRL_RAM #(
`endif
  .RPORT      (`COMMIT_WIDTH),
  .WPORT      (`ISSUE_WIDTH),
	.DEPTH      (`SIZE_ACTIVELIST),
	.INDEX      (`SIZE_ACTIVELIST_LOG),
	.WIDTH      (`SIZE_EXE_FLAGS+1) // 1 extra for branch direction
	)

	ctrlActiveList (

	.addr0_i    (headAddr[0]),
	.data0_o    (ctrlAl[0]),

`ifdef COMMIT_TWO_WIDE
	.addr1_i    (headAddr[1]),
	.data1_o    (ctrlAl[1]),
`endif

`ifdef COMMIT_THREE_WIDE
	.addr2_i    (headAddr[2]),
	.data2_o    (ctrlAl[2]),
`endif

`ifdef COMMIT_FOUR_WIDE
	.addr3_i    (headAddr[3]),
	.data3_o    (ctrlAl[3]),
`endif

  .addr0wr_i  (bistEn ? bistAddrWr  : ctrlPacket_i[0].alID),
  .we0_i      (bistEn ? 1'b1        : ctrlPacket_i[0].valid),
  .data0wr_i  (bistEn ? bistDataWr1 : {ctrlPacket_i[0].actualDir,ctrlPacket_i[0].flags}),

`ifdef ISSUE_TWO_WIDE
	.addr1wr_i  (ctrlPacket_i[1].alID),
	.we1_i      (ctrlPacket_i[1].valid),
	.data1wr_i  ({ctrlPacket_i[1].actualDir,ctrlPacket_i[1].flags}),
`endif

`ifdef ISSUE_THREE_WIDE
	.addr2wr_i  (ctrlPacket_i[2].alID),
	.we2_i      (ctrlPacket_i[2].valid),
	.data2wr_i  ({ctrlPacket_i[2].actualDir,ctrlPacket_i[2].flags}),
`endif

`ifdef ISSUE_FOUR_WIDE
	.addr3wr_i  (ctrlPacket_i[3].alID),
	.we3_i      (ctrlPacket_i[3].valid),
	.data3wr_i  ({ctrlPacket_i[3].actualDir,ctrlPacket_i[3].flags}),
`endif

`ifdef ISSUE_FIVE_WIDE
	.addr4wr_i  (ctrlPacket_i[4].alID),
	.we4_i      (ctrlPacket_i[4].valid),
	.data4wr_i  ({ctrlPacket_i[4].actualDir,ctrlPacket_i[4].flags}),
`endif

`ifdef ISSUE_SIX_WIDE
	.addr5wr_i  (ctrlPacket_i[5].alID),
	.we5_i      (ctrlPacket_i[5].valid),
	.data5wr_i  ({ctrlPacket_i[5].actualDir,ctrlPacket_i[5].flags}),
`endif

`ifdef ISSUE_SEVEN_WIDE
	.addr6wr_i  (ctrlPacket_i[6].alID),
	.we6_i      (ctrlPacket_i[6].valid),
	.data6wr_i  ({ctrlPacket_i[6].actualDir,ctrlPacket_i[6].flags}),
`endif

`ifdef ISSUE_EIGHT_WIDE
	.addr7wr_i  (ctrlPacket_i[7].alID),
	.we7_i      (ctrlPacket_i[7].valid),
	.data7wr_i  ({ctrlPacket_i[7].actualDir,ctrlPacket_i[7].flags}),
`endif

`ifdef DYNAMIC_CONFIG
  .issueLaneActive_i(issueLaneActive_i),
  .commitLaneActive_i(commitLaneActive_i),
  .alPartitionActive_i(alPartitionActive_i),
  .alCtrlReady_o(alCtrlReady),
`endif

	.clk        (clk)
	//.reset      (reset | violateFlag_reg | mispredFlag_reg | exceptionFlag_reg)

	);


ALREADY_RAM #(
  .RPORT      (`COMMIT_WIDTH),
  .WPORT      (`ISSUE_WIDTH+`COMMIT_WIDTH),
	.DEPTH      (`SIZE_ACTIVELIST),
	.INDEX      (`SIZE_ACTIVELIST_LOG),
	.WIDTH      (1)
	)

	executedActiveList (

	.addr0_i    (headAddr[0]),
	.data0_o    (commitReady[0]),

`ifdef COMMIT_TWO_WIDE
	.addr1_i    (headAddr[1]),
	.data1_o    (commitReady[1]),
`endif

`ifdef COMMIT_THREE_WIDE
	.addr2_i    (headAddr[2]),
	.data2_o    (commitReady[2]),
`endif

`ifdef COMMIT_FOUR_WIDE
	.addr3_i    (headAddr[3]),
	.data3_o    (commitReady[3]),
`endif


	.addr0wr_i  (ctrlPacket_i[0].alID),
	.we0_i      (ctrlPacket_i[0].valid),
	.data0wr_i  (ctrlPacket_i[0].flags[2]),

`ifdef ISSUE_TWO_WIDE
	.addr1wr_i  (ctrlPacket_i[1].alID),
	.we1_i      (ctrlPacket_i[1].valid),
	.data1wr_i  (ctrlPacket_i[1].flags[2]),
`endif

`ifdef ISSUE_THREE_WIDE
	.addr2wr_i  (ctrlPacket_i[2].alID),
	.we2_i      (ctrlPacket_i[2].valid),
	.data2wr_i  (ctrlPacket_i[2].flags[2]),
`endif

`ifdef ISSUE_FOUR_WIDE
	.addr3wr_i  (ctrlPacket_i[3].alID),
	.we3_i      (ctrlPacket_i[3].valid),
	.data3wr_i  (ctrlPacket_i[3].flags[2]),
`endif

`ifdef ISSUE_FIVE_WIDE
	.addr4wr_i  (ctrlPacket_i[4].alID),
	.we4_i      (ctrlPacket_i[4].valid),
	.data4wr_i  (ctrlPacket_i[4].flags[2]),
`endif

`ifdef ISSUE_SIX_WIDE
	.addr5wr_i  (ctrlPacket_i[5].alID),
	.we5_i      (ctrlPacket_i[5].valid),
	.data5wr_i  (ctrlPacket_i[5].flags[2]),
`endif

`ifdef ISSUE_SEVEN_WIDE
	.addr6wr_i  (ctrlPacket_i[6].alID),
	.we6_i      (ctrlPacket_i[6].valid),
	.data6wr_i  (ctrlPacket_i[6].flags[2]),
`endif

`ifdef ISSUE_EIGHT_WIDE
	.addr7wr_i  (ctrlPacket_i[7].alID),
	.we7_i      (ctrlPacket_i[7].valid),
	.data7wr_i  (ctrlPacket_i[7].flags[2]),
`endif


	.addr10wr_i (headAddr[0]),
	.we10_i     (commitVector_t1[0]),
	.data10wr_i (1'h0),

`ifdef COMMIT_TWO_WIDE
	.addr11wr_i (headAddr[1]),
	.we11_i     (commitVector_t1[1]),
	.data11wr_i (1'h0),
`endif  

`ifdef COMMIT_THREE_WIDE
	.addr12wr_i (headAddr[2]),
	.we12_i     (commitVector_t1[2]),
	.data12wr_i (1'h0),
`endif

`ifdef COMMIT_FOUR_WIDE
	.addr13wr_i (headAddr[3]),
	.we13_i     (commitVector_t1[3]),
	.data13wr_i (1'h0),
`endif

`ifdef DYNAMIC_CONFIG
  .issueLaneActive_i(issueLaneActive_i),
  .commitLaneActive_i(commitLaneActive_i),
  .alPartitionActive_i(alPartitionActive_i),
  .alReadyBitReady_o(alReadyBitReady),
`endif

	.clk        (clk),
	.reset      (reset | violateFlag_reg | mispredFlag_reg | exceptionFlag_reg)

	);


/* The "targetAddrActiveList" RAM contain computed target address of control
* instructions.
* The target address is required for the mis-prediction recovery model being
* supported, currently. The mis-predicted contol instruction is resolved when
* it reaches the head of the Active List.
*/
`ifdef DYNAMIC_CONFIG
ALNPC_RAM_PARTITIONED #(
`else
ALNPC_RAM #(
`endif
  .RPORT      (1),
  //.WPORT      (`ISSUE_WIDTH),
  .WPORT      (1),
	.DEPTH      (`SIZE_ACTIVELIST),
	.INDEX      (`SIZE_ACTIVELIST_LOG),
	.WIDTH      (`SIZE_PC)
	)

	targetAddrActiveList (

	.addr0_i    (headAddr[0]),
	.data0_o    (targetAddr),

  .addr0wr_i  (bistEn ? bistAddrWr  : ctrlPacket_i[1].alID),
  .we0_i      (bistEn ? 1'b1        : ctrlPacket_i[1].valid),
  .data0wr_i  (bistEn ? bistDataWr2 : ctrlPacket_i[1].nextPC),

//TODO: Rest of these ports are not really needed since a branch
// instruction is always executed by the Ctrl execution lane.

//`ifdef ISSUE_TWO_WIDE
//	.addr1wr_i  (ctrlPacket_i[1].alID),
//	.we1_i      (ctrlPacket_i[1].valid),
//	.data1wr_i  (ctrlPacket_i[1].nextPC),
//`endif
//
//`ifdef ISSUE_THREE_WIDE
//	.addr2wr_i  (ctrlPacket_i[2].alID),
//	.we2_i      (ctrlPacket_i[2].valid),
//	.data2wr_i  (ctrlPacket_i[2].nextPC),
//`endif
//
//`ifdef ISSUE_FOUR_WIDE
//	.addr3wr_i  (ctrlPacket_i[3].alID),
//	.we3_i      (ctrlPacket_i[3].valid),
//	.data3wr_i  (ctrlPacket_i[3].nextPC),
//`endif
//
//`ifdef ISSUE_FIVE_WIDE
//	.addr4wr_i  (ctrlPacket_i[4].alID),
//	.we4_i      (ctrlPacket_i[4].valid),
//	.data4wr_i  (ctrlPacket_i[4].nextPC),
//`endif
//
//`ifdef ISSUE_SIX_WIDE
//	.addr5wr_i  (ctrlPacket_i[5].alID),
//	.we5_i      (ctrlPacket_i[5].valid),
//	.data5wr_i  (ctrlPacket_i[5].nextPC),
//`endif
//
//`ifdef ISSUE_SEVEN_WIDE
//	.addr6wr_i  (ctrlPacket_i[6].alID),
//	.we6_i      (ctrlPacket_i[6].valid),
//	.data6wr_i  (ctrlPacket_i[6].nextPC),
//`endif
//
//`ifdef ISSUE_EIGHT_WIDE
//	.addr7wr_i  (ctrlPacket_i[7].alID),
//	.we7_i      (ctrlPacket_i[7].valid),
//	.data7wr_i  (ctrlPacket_i[7].nextPC),
//`endif

`ifdef DYNAMIC_CONFIG
  .issueLaneActive_i(issueLaneActive_i),
  .alPartitionActive_i(alPartitionActive_i),
  .alNPcReady_o(alNPcReady),
`endif  

	.clk        (clk)
	//.reset      (reset | violateFlag_reg | mispredFlag_reg | exceptionFlag_reg)

	);


ALVIO_RAM #(
  .RPORT      (`COMMIT_WIDTH),
  .WPORT      (1),
	.DEPTH      (`SIZE_ACTIVELIST),
	.INDEX      (`SIZE_ACTIVELIST_LOG),
	.WIDTH      (1)
	)

	ldViolateVector(

	.addr0_i    (headAddr[0]),
	.data0_o    (violateBit[0]),

`ifdef COMMIT_TWO_WIDE
	.addr1_i    (headAddr[1]),
	.data1_o    (violateBit[1]),
`endif

`ifdef COMMIT_THREE_WIDE
	.addr2_i    (headAddr[2]),
	.data2_o    (violateBit[2]),
`endif

`ifdef COMMIT_FOUR_WIDE
	.addr3_i    (headAddr[3]),
	.data3_o    (violateBit[3]),
`endif

	.addr0wr_i  (ldVioPacket_i.alID),
	.we0_i      (ldVioPacket_i.valid),
	.data0wr_i  (ldVioPacket_i.valid),

`ifdef DYNAMIC_CONFIG
  .commitLaneActive_i(commitLaneActive_i),
  .alPartitionActive_i(alPartitionActive_i),
  .alVioReady_o(alVioReady),
`endif

	.clk        (clk),
	.reset      (reset | violateFlag_reg | mispredFlag_reg | exceptionFlag_reg)
	);


ALEXCPT_RAM #(
  .RPORT      (`COMMIT_WIDTH),
  .WPORT      (1),
	.DEPTH      (`SIZE_ACTIVELIST),
	.INDEX      (`SIZE_ACTIVELIST_LOG),
	.WIDTH      (`EXCEPTION_PKT_SIZE)
	)

	excptActiveList (

	.addr0_i    (headAddr[0]),
	.data0_o    (exceptionAl[0]),

`ifdef COMMIT_TWO_WIDE
	.addr1_i    (headAddr[1]),
	.data1_o    (exceptionAl[1]),
`endif

`ifdef COMMIT_THREE_WIDE
	.addr2_i    (headAddr[2]),
	.data2_o    (exceptionAl[2]),
`endif

`ifdef COMMIT_FOUR_WIDE
	.addr3_i    (headAddr[3]),
	.data3_o    (exceptionAl[3]),
`endif

	.addr0wr_i  (memExcptPacket_i.alID),
	.we0_i      (memExcptPacket_i.valid),
	.data0wr_i  (memExcptPacket_i),

  // Dispatch needs to notify only about the first fetch exception
  // in a bundle. Everything after that will be squashed anyway
	.addr1wr_i  (disExcptPacket_i.alID),
	.we1_i      (disExcptPacket_i.valid),
	.data1wr_i  (disExcptPacket_i),

`ifdef DYNAMIC_CONFIG
  .commitLaneActive_i(commitLaneActive_i),
  .alPartitionActive_i(alPartitionActive_i),
  .alVioReady_o(alVioReady),
`endif

	.clk        (clk),
	.reset      (reset | violateFlag_reg | mispredFlag_reg | exceptionFlag_reg)
	);


/*-----------------------Changes: Mohit----------------------*/
// RAM instance for Floating-point Exception bits corresponding to all FP 
// instructions. The exception bits are then updated in CSR_FFLAGS during retire
ALEXCPT_RAM #(
  .RPORT      (`COMMIT_WIDTH),
  .WPORT      (1),
	.DEPTH      (`SIZE_ACTIVELIST),
	.INDEX      (`SIZE_ACTIVELIST_LOG),
	.WIDTH      (`CSR_WIDTH)	//Stores the fflags_csr for each alID
	)

	fp_excptActiveList (

	.addr0_i    (headAddr[0]),
	.data0_o    (fp_exceptionAl[0]),

`ifdef COMMIT_TWO_WIDE
	.addr1_i    (headAddr[1]),
	.data1_o    (fp_exceptionAl[1]),
`endif

`ifdef COMMIT_THREE_WIDE
	.addr2_i    (headAddr[2]),
	.data2_o    (fp_exceptionAl[2]),
`endif

`ifdef COMMIT_FOUR_WIDE
	.addr3_i    (headAddr[3]),
	.data3_o    (fp_exceptionAl[3]),
`endif

	.addr0wr_i  (fpExcptPacket_i.alID),
	.we0_i      (fpExcptPacket_i.valid),
	.data0wr_i  (fpExcptPacket_i.fflags),

	.we1_i      (1'b0),

	.clk        (clk),
	.reset      (reset | violateFlag_reg | exceptionFlag_reg)
	);


reg [`CSR_WIDTH-1:0]	csr_fflags_temp;
// Combine the exception flags of all the retiring insturctions together
always_comb
begin	
	int i;
	csr_fflags_temp = (dataAl[0].isFP & dataAl[0].valid & commitReady[0])?fp_exceptionAl[0]:64'h0;
	for(i = 1; i < `COMMIT_WIDTH; i++) begin
		csr_fflags_temp = csr_fflags_temp | ((dataAl[i].isFP & dataAl[i].valid & commitReady[i])?fp_exceptionAl[i]:64'h0); 
	end
end

assign  csr_fflags_o = csr_fflags_temp;


/*-----------------------------------------------------------------*/


// Counting the number of active DISPATCH lanes
// Should be 1 bit wider as it should hold values from 1 to `DISPATCH_WIDTH
// RBRC
reg [`DISPATCH_WIDTH_LOG:0] numDispatchLaneActive;
reg  [`SIZE_ACTIVELIST_LOG:0]       alSize;
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

`else
  numDispatchLaneActive = `DISPATCH_WIDTH;
  alSize = `SIZE_ACTIVELIST;
`endif
end


/*******************************************************************************
* In case of load violation or control mis-prediction, recover flag is raised to
* flush the pipeline.
*
* In case of load violation, nextPC is PC of the offending instruction.
* In case of control mis-prediction, nextPC is the target address.
*******************************************************************************/
/* TODO: Disjoin violateFlag_reg and mispredFlag_reg */
assign recoverFlag_o    = violateFlag_reg | mispredFlag_reg | exceptionFlag_reg;
assign recoverPC_o      = (mispredFlag_reg) ? targetPC : recoverPC;

assign loadViolation_o  = loadViolation;


/*******************************************************************************
* In case of SYSCALL, exception flag is raised to flush the pipeline.
* A behavioral code to handle SYSCALL is called.
*******************************************************************************/
assign exceptionFlag_o  = exceptionFlag_reg;
assign exceptionPC_o    = exceptionPC;
assign exceptionCause_o = exceptionCause;


/* Following generates write address for writing into Active List, starting
 * from the tail.
 */

reg  [`SIZE_ACTIVELIST_LOG:0]     tailAddr_t [0:`DISPATCH_WIDTH-1];
always_comb
begin
	int i;
	for (i = 0; i < `DISPATCH_WIDTH; i = i + 1)
	begin
		tailAddr_t[i]  = {1'b0,tailPtr} + i;
    if(tailAddr_t[i] >= alSize)
      tailAddr_t[i] = tailAddr_t[i] - alSize;

//    `ifdef DYNAMIC_CONFIG
//      // Discard the MSB which is used only for correct wrap around logic
//      tailAddr[i] = dispatchLaneActive_i[i] ? tailAddr_t[i][`SIZE_ACTIVELIST_LOG-1:0] : {`SIZE_ACTIVELIST_LOG{1'b0}};
//    `else
//      // Discard the MSB which is used only for correct wrap around logic
//      tailAddr[i] = tailAddr_t[i][`SIZE_ACTIVELIST_LOG-1:0];
//    `endif
	end
end

`ifdef DYNAMIC_CONFIG
  genvar wr;
  generate
	  for (wr = 0; wr < `DISPATCH_WIDTH; wr = wr + 1)
    begin:CLAMP_WR
        PGIsolationCell #(
          .WIDTH(`SIZE_ACTIVELIST_LOG)
        ) wrAddrClamp
        (
          .clampEn(~dispatchLaneActive_i[wr]),
          .signalIn(tailAddr_t[wr][`SIZE_ACTIVELIST_LOG-1:0]),
          .signalOut(tailAddr[wr]),
          .clampValue({`SIZE_ACTIVELIST_LOG{1'b0}})
        );
    end
  endgenerate
`else
  always_comb
  begin
    int wr;
	  for (wr = 0; wr < `DISPATCH_WIDTH; wr = wr + 1)
	  begin
      tailAddr[wr]   = tailAddr_t[wr]  ;
    end
  end
`endif

/* Following generates read address for reading from Active List, starting
 * from the head.
 */

reg  [`SIZE_ACTIVELIST_LOG:0]     headAddr_t [0:`COMMIT_WIDTH-1];
always_comb
begin
	int i;
	for (i = 0; i < `COMMIT_WIDTH; i = i + 1)
	begin
		headAddr_t[i]  = {1'b0,headPtr} + i;
    if(headAddr_t[i] >= alSize)
      headAddr_t[i] = headAddr_t[i] - alSize;

//    `ifdef DYNAMIC_CONFIG
//      // Discard the MSB which is used only for correct wrap around logic
//      headAddr[i] = commitLaneActive_i[i] ? headAddr_t[i][`SIZE_ACTIVELIST_LOG-1:0] : {`SIZE_ACTIVELIST_LOG{1'b0}};
//    `else
//      // Discard the MSB which is used only for correct wrap around logic
//      headAddr[i] = headAddr_t[i][`SIZE_ACTIVELIST_LOG-1:0];
//    `endif
	end
end


`ifdef DYNAMIC_CONFIG
  genvar rd;
  generate
	  for (rd = 0; rd < `COMMIT_WIDTH; rd = rd + 1)
    begin:CLAMP_RD
        PGIsolationCell #(
          .WIDTH(`SIZE_ACTIVELIST_LOG)
        ) rdAddrClamp
        (
          .clampEn(~commitLaneActive_i[rd]),
          .signalIn(headAddr_t[rd][`SIZE_ACTIVELIST_LOG-1:0]),
          .signalOut(headAddr[rd]),
          .clampValue({`SIZE_ACTIVELIST_LOG{1'b0}})
        );
    end
  endgenerate
`else
  always_comb
  begin
    int rd;
	  for (rd = 0; rd < `COMMIT_WIDTH; rd = rd + 1)
	  begin
      headAddr[rd]   = headAddr_t[rd]  ;
    end
  end
`endif

always_comb
begin
	int i;
	for (i = 0; i < `COMMIT_WIDTH; i = i + 1)
	begin
	/* The violate flag is used to mark a load violation.
	 * An instruction with the violate bit set waits until it reaches 
	 * the head of the AL and then causes a recovery without committing. */
		/* violateFlag[i]    = violateBit[i] && commitReady[i] || fissionViolation; */
		violateFlag[i]    = (violateBit[i] && commitReady[i]) | interruptPulse;

    csrViolateFlag[i] = csrViolateFlag_i & commitReady[i] & dataAl[i].isCSR;

    // Prevent an sret instruction from retiring until it is at the head of the activeList.
    // Also prevent any instruction after the sret to retire.
    sretFlag[i] = dataAl[i].isSret & commitReady[i];

	/* The mispredict flag is used to mark a misprediction.
	 * An instruction with the mispredict bit set commits only at 
	 * the head of the AL. */
		mispredFlag[i]    = ctrlAl[i][0] && commitReady[i];

	/* The exception flag is used to mark the system call. 
	 * An instruction with the exception bit set waits until it reaches 
	 * the head of the AL before committing. After it has committed, 
	 * a recovery occurs and the system call is handled. */
		//exceptionFlag[i]  = ctrlAl[i][1] && commitReady[i];
		exceptionFlag[i]  = (exceptionAl[i].exception && commitReady[i]) |
                        (exceptionAl[i].exception & dataAl[i].valid);//(dataAl[i].isScall | dataAl[i].isSbreak));

	end
	violateFlag[0]    = (violateBit[0] && commitReady[0]) || 
                      (violateBit[1] && commitReady[0] && commitReady[1] && ctrlAl[0][3]) ||
                      interruptPulse;

end

assign sretFlag_o = sretFlag[0];

logic [`COMMIT_WIDTH-1:0] htifCommitMask;
logic [6:0]               instret;
localparam INTERVAL = 50;

// Detect an HTIF boundary and avoid committing instructions
// beyond an HTIF boundary
always_comb
begin:HTIF_BOUNDARY
  case(INTERVAL - instret)
    1: htifCommitMask = 4'h0001;
  `ifdef COMMIT_TWO_WIDE
    2: htifCommitMask = 4'h0011;
  `endif
  `ifdef COMMIT_THREE_WIDE
    3: htifCommitMask = 4'h0111;
  `endif
  `ifdef COMMIT_FOUR_WIDE
    4: htifCommitMask = 4'h1111;
  `endif
    default:
       htifCommitMask = `COMMIT_WIDTH'b1;
  endcase
end

always_ff @(posedge clk or posedge reset)
begin
  if(reset)
  begin
    instret <= 0;
  end
  else
  begin
    instret <= (instret + totalCommit) >= INTERVAL ? 0 : (instret + totalCommit);
  end
end


reg [`COMMIT_WIDTH-1:0]        commitVector_f;
always_comb
begin:COMMIT
	int i;

	totalCommit          = 0;

	for (i = 0; i < `COMMIT_WIDTH; i = i + 1) 
	begin
		amtPacket_o[i]      = {`COMMIT_PKT_SIZE{1'b0}};

		commitFission[i]  = ctrlAl[i][3] && commitReady[i];

`ifdef SIM
		/* commitVerify[i]   = 0; */
		/* commitCnt[i]      = commitCount; */
`endif
	end

	commitStore_o       = {`COMMIT_WIDTH{1'b0}};
	commitLoad_o        = {`COMMIT_WIDTH{1'b0}};
	commitCti_o         = {`COMMIT_WIDTH{1'b0}};
	actualDir_o         = {`COMMIT_WIDTH{1'b0}};
	ctrlType_o          = {`COMMIT_WIDTH{1'b0}};
  commitCsr_o         = 1'b0;

`ifdef SIM
	/* commitCount_f   = commitCount; */
`endif

  // LANE: Per Lane Logic
  // The instruction at the head of the AL commits in cases of misprediction and an SRET instructions.
  // In all other cases, it is squashed along with everything else.
	commitVector_f[0] = (alCount > 0) & commitReady[0] & ~violateFlag[0] & ~csrViolateFlag[0]  & ~exceptionFlag[0];

	for (i = 1; i < `COMMIT_WIDTH; i = i + 1) 
	begin
		commitVector_f[i] = ( alCount > i) & commitReady[i] & 
                          ~mispredFlag[i] & ~mispredFlag[0] &
                          ~sretFlag[i]    & ~sretFlag[0] &
		                      ~violateFlag[i] & ~csrViolateFlag[i] & 
                          ~exceptionFlag[i];
	end

	/* Retire the fission instructions together */
	for (i = 0; i < `COMMIT_WIDTH-1; i = i + 1) 
	begin
		if (commitFission[i])
		begin
			commitVector[i] = commitVector_f[i] & commitVector_f[i+1] ;
		end
		else
		begin
			commitVector[i] = commitVector_f[i];
		end
	end

	if (commitFission[`COMMIT_WIDTH-1])
	begin
		commitVector[`COMMIT_WIDTH-1] = 1'b0;
	end
	else
	begin
		commitVector[`COMMIT_WIDTH-1] = commitVector_f[`COMMIT_WIDTH-1];
	end

	/* Detect the corner case when the second load of a DLW violates.
	 * Cause the first load to violate to prevent a deadlock */
	fissionViolation   = 1'h0;

	if (commitReady[0] && commitFission[0] && commitReady[1] && violateFlag[1])
	begin
		fissionViolation = 1'h1;
	end

  // Although the COMMIT_READY ram read port for a particular
  // RAM is already gated and the ready bit will 0 for an inactive
  // lane, it is better to put this mask here in case the RAMs are
  // power gated and logic levels are not guaranteed.
`ifdef DYNAMIC_CONFIG
  commitVector = commitVector & commitLaneActive_i;
`endif

  // If there's a Data Cache, make sure that the write through
  // buffer is not full. If full, don't commit anything.
  // This is too restrictive as non-store instructions should be 
  // allowed to commit.
`ifdef DATA_CACHE
  commitVector = stallStCommit_i ? {`COMMIT_WIDTH{1'b0}} :  commitVector;
`endif

  commitVector = commitVector & htifCommitMask;

	commitVector_t1               = 4'h0;

  // Extending to 4 bits
  // CAVEAT: Any floating bit in this vector will cause improper
  // commit operation
  casez ({{4-`COMMIT_WIDTH{1'b0}},commitVector})
    4'b0000:  begin
    end
    4'b??01:  begin
      commitVector_t1 = 4'h1;
      totalCommit     = 1;
    end
`ifdef COMMIT_TWO_WIDE
    4'b?011:  begin
      commitVector_t1 = 4'h3;
      totalCommit     = 2;
    end
`endif    
`ifdef COMMIT_THREE_WIDE
    4'b0111:  begin
      commitVector_t1 = 4'h7;
      totalCommit     = 3;
    end
`endif    
`ifdef COMMIT_FOUR_WIDE
    4'b1111:  begin
      commitVector_t1 = 4'hf;
      totalCommit     = 4;
    end
`endif    
    default: begin
      commitVector_t1 = 4'h0;
      totalCommit     = 0;
    end
  endcase

  // LANE: Per lane logic
  // Control signals are low if commitVector_t1 for
  // a particular lane is 0
	for (i = 0; i < `COMMIT_WIDTH; i = i + 1) 
	begin
    amtPacket_o[i].seqNo      = dataAl[i].seqNo;
		amtPacket_o[i].logDest    = dataAl[i].logDest; 
		amtPacket_o[i].phyDest    = dataAl[i].phyDest;
		amtPacket_o[i].valid      = dataAl[i].phyDestValid & commitVector_t1[i];
		commitStore_o[i]          = dataAl[i].isStore & commitVector_t1[i];
		commitLoad_o[i]           = dataAl[i].isLoad & dataAl[i].phyDestValid & commitVector_t1[i];
		commitCti_o[i]            = ctrlAl[i][7] & commitVector_t1[i];
    actualDir_o[i]            = ctrlAl[i][8];
    ctrlType_o[i]             = ctrlAl[i][5];
    commitCsr_o               = commitCsr_o | dataAl[i].isCSR & commitVector_t1[i];
  end

end

/* Following generates the active list empty entries count each cycle.
 *
 * In the normal operation, difference between tail and head pointer (taking warpping into
 * account) is the count.
 *
 * In the case of branch misprediction, differnce between offending instruction's active
 * list ID and head pointer is the count. Active list ID of the offending instruction is
 * sent by the corresponding functional unit.
 */

always_comb
begin : GENERATE_COUNT
  int i;
	//newInsts   = dispatchReady_i ? numDispatchLaneActive : 0;
  dispatchedInsts = 0;
  for(i=0;i<`DISPATCH_WIDTH;i++)
  	dispatchedInsts   = dispatchedInsts + alPacket_i[i].valid;

	alCount_next  = (alCount + dispatchedInsts) - totalCommit;
end

/* Compute tail and head pointers for the next cycle
 * based upon dispatched and committed instruction counts. */

// Putting in explicit wrap around logic so that arbitrary 
// AL sizes besides power of 2 can be supported
// May 22, 2013  RBRC
// LANE: Monolithic Logic
always_comb
begin: POINTER_UPDATE

  reg  [`SIZE_ACTIVELIST_LOG:0]     headPtr_next_t;
  reg  [`SIZE_ACTIVELIST_LOG:0]     headPtr_next_wrap;
  reg  [`SIZE_ACTIVELIST_LOG:0]     tailPtr_next_t;
  reg  [`SIZE_ACTIVELIST_LOG:0]     tailPtr_next_wrap;

  /* Compute headPtr_next */
  // alSize is constant in case of static configuration
	headPtr_next_t        = {1'b0,headPtr} + totalCommit;

  headPtr_next_wrap   = ({1'b0,headPtr} + totalCommit) - alSize;
  if(headPtr_next_t >= alSize)
  begin
    headPtr_next_t  = headPtr_next_wrap;
  end

  // Discard the MSB which is used only for correct wrap around logic
  headPtr_next = headPtr_next_t[`SIZE_ACTIVELIST_LOG-1:0];
  

  /* Compute tailPtr_next */
  // numdispatchLaneActive is constant in case of STATIC_CONFIG
	tailPtr_next_t    = dispatchReady_i ? ({1'b0,tailPtr} + dispatchedInsts) : {1'b0,tailPtr};

  tailPtr_next_wrap = dispatchReady_i ? ({1'b0,tailPtr} + dispatchedInsts) - alSize : ({1'b0,tailPtr} - alSize);

  if(tailPtr_next_t >= alSize)
  begin
    tailPtr_next_t = tailPtr_next_wrap;
  end

  // Discard the MSB which is used only for correct wrap around logic
  tailPtr_next = tailPtr_next_t[`SIZE_ACTIVELIST_LOG-1:0];

end    

/* Update the Active List tail pointer:
 * Set the tail pointer to 0 if there is a recovery.
 * Else, increment it by DISPATCH_WIDTH if dispatchReady_i is high. */

/* Updates the Active List head pointer:
 * Increment the head pointer for each committing instruction. */ 
// LANE: Monolithic Logic
always_ff @(posedge clk or posedge reset)
begin
	if (reset)
	begin
		headPtr  <= 0;
		tailPtr  <= {`SIZE_ACTIVELIST_LOG{1'b0}};
		alCount  <= 0;
	end
  else
  begin
    if(violateFlag_reg | mispredFlag_reg | exceptionFlag_reg)
    begin
		  headPtr  <= 0;
		  tailPtr  <= {`SIZE_ACTIVELIST_LOG{1'b0}};
    end
	  else
  	begin
		  headPtr  <= headPtr_next;
		  tailPtr  <= tailPtr_next;
	  end

    /* Maintain the active list occupancy count each cycle */
    // TODO: Why is the count reset one cycle in advance
	  if ((violateFlag[0] | csrViolateFlag[0] | mispredFlag[0] | sretFlag[0] | exceptionFlag[0] | interruptPulse) & ~stallStCommit_i) // Delay recovery until ready to commit again
	  	alCount <= 0;
	  else if (violateFlag_reg | mispredFlag_reg | exceptionFlag_reg)
	  	alCount <= 0;
	  else	
      alCount <= alCount_next;

  end
end

/* Assign output signals of this module */
assign alHead_o           = headPtr;
assign alTail_o           = tailPtr;
assign alID_o             = tailAddr;
assign activeListCnt_o    = alCount;


/* Maintain the recover flag register. Recover flag 
 * will flush the pipeline when high. */

// LANE: Monolithic Logic
always_ff @(posedge clk or posedge reset)
begin
	if (reset)
	begin
		violateFlag_reg       <= 1'b0;
		mispredFlag_reg       <= 1'b0;
		exceptionFlag_reg     <= 1'b0;
		loadViolation         <= 1'b0;

		targetPC              <= `SIZE_PC'h0;
		recoverPC             <= `SIZE_PC'h0;
		exceptionPC           <= `SIZE_PC'h0;
    exceptionCause        <= `EXCEPTION_CAUSE_LOG'h0;
	end

	else
	begin
	  if (violateFlag_reg | mispredFlag_reg | exceptionFlag_reg)
    begin
		  violateFlag_reg       <= 1'b0;
		  mispredFlag_reg       <= 1'b0;
		  exceptionFlag_reg     <= 1'b0;
		  loadViolation         <= 1'b0;
		  atomicityViolation    <= 1'b0;

		  targetPC              <= `SIZE_PC'h0;
		  recoverPC             <= `SIZE_PC'h0;
		  exceptionPC           <= `SIZE_PC'h0;
      exceptionCause        <= `EXCEPTION_CAUSE_LOG'h0;
    end
    else
    begin
		  if (mispredFlag[0] & ~stallStCommit_i)
		  begin
		  	mispredFlag_reg     <= 1'b1;
		  	targetPC            <= targetAddr;
		  end

		  if (violateFlag[0] & ~stallStCommit_i)
		  begin
		  	violateFlag_reg     <= 1'b1;
		  	recoverPC           <= dataAl[0].pc;
		  	loadViolation       <= 1'b1;
		  end

		  if (csrViolateFlag[0] & ~stallStCommit_i)
		  begin
		  	violateFlag_reg     <= 1'b1;
		  	recoverPC           <= dataAl[0].pc;
		  	atomicityViolation  <= 1'b1;
		  end

      // Use a delayed version of the sretFlag to allow the SRET instruction to commit
		  if (sretFlag[0] & ~stallStCommit_i)
		  begin
		  	violateFlag_reg     <= 1'b1;
		  	recoverPC           <= csr_epc_i;
		  end

      if (interruptPulse)
      begin
		  	violateFlag_reg     <= 1'b1;
		  	recoverPC           <= csr_evec_i;
      end

		  if (exceptionFlag[0] & ~stallStCommit_i)
		  begin
		  	exceptionFlag_reg   <= 1'b1;
		  	//exceptionPC         <= dataAl[0].pc + `SIZE_INSTRUCTION_BYTE;
		  	exceptionPC         <= dataAl[0].pc; // Should report the PC that faulted
		  	recoverPC           <= csr_evec_i;
        exceptionCause      <= exceptionAl[0].exceptionCause;
		  end

    end
	end
end

// Generate a single pulse when an interrupt is accepted for processing
always_ff @(posedge clk or posedge reset)
begin
  if(reset)
    interruptPending_d1 <= 1'b0;
  else
    interruptPending_d1 <= interruptPending_i;
end
assign interruptPulse = interruptPending_i & ~interruptPending_d1;

`ifdef SIM
  always_comb
  begin
  	int i;
  	for (i = 0; i < `COMMIT_WIDTH; i = i + 1)
  	begin
  		commitPC[i]    = dataAl[i].pc;
  	end
  end
  
  reg  [`SIZE_RMT_LOG-1:0]      logDest [0:3];
  reg  [`SIZE_PHYSICAL_LOG-1:0] phyDest [0:3];
  
  always_comb
  begin
  	int i;
  	for (i = 0; i < 4; i++)
  	begin
  		logDest[i] = dataAl[i].logDest;
  		phyDest[i] = dataAl[i].phyDest;
  	end
  end
`endif

`ifdef PERF_MON
  always_comb
  begin
  	int index;
  	for (index = 0 ; index < `COMMIT_WIDTH ; index++)
  		commitValid_o[index] = amtPacket_o[index].valid;
  end
  
`endif
assign totalCommit_o = totalCommit;

endmodule

