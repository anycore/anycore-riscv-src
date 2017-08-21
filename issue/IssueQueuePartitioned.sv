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

/***************************************************************************

Assumption:  
[1] `DISPATCH_WIDTH-instructions can be renamed in one cycle.
[2] There are 4-Functional Units (Integer Type) including
AGEN block which is a dedicated FU for Load/Store.
FU0  2'b00     // Simple ALU
FU1  2'b01     // Complex ALU (for MULTIPLY & DIVIDE)
FU2  2'b10     // ALU for CONTROL Instructions
FU3  2'b11     // LOAD/STORE Address Generator
[3] All the Functional Units are pipelined.

granted packet contains following information:
(14) Branch mask:
(13) Issue Queue ID:
(12) Src Reg-1:
(11) Src Reg-2:
(10) LD/ST Queue ID:
(9)  Active List ID:
(8)  Checkpoint ID:
(7)  Destination Reg:
(6)  Immediate data:
(5)  LD/ST Type:
(4)  Opcode:
(3)  Program Counter:
(2)  Predicted Target Addr:
(1)  CTI Queue ID:
(0)  Branch Prediction:

***************************************************************************/

module IssueQueuePartitioned ( 
    input                                  clk,
    input                                  reset,
	  input                                  resetRams_i,
    input                                  flush_i,

    input  [`ISSUE_WIDTH-1:0]              issueLaneActive_i,
    input  [`DISPATCH_WIDTH-1:0]           dispatchLaneActive_i,
    input  [`ISSUE_WIDTH-1:0]              execLaneActive_i,
    input  [`NUM_PARTS_IQ-1:0]             iqPartitionActive_i,
    input                                  reconfigureCore_i,

    input                                  exceptionFlag_i,

    input                                  dispatchReady_i,

    input  iqPkt                           iqPacket_i [0:`DISPATCH_WIDTH-1],

    input  phys_reg                        phyDest_i [0:`DISPATCH_WIDTH-1],

	  input  [`SIZE_ACTIVELIST_LOG-1:0]      alHead_i,
	  input  [`SIZE_ACTIVELIST_LOG-1:0]      alTail_i,
    input  [`SIZE_ACTIVELIST_LOG-1:0]      alID_i [0:`DISPATCH_WIDTH-1],
    input  [`SIZE_LSQ_LOG-1:0]             lsqID_i [0:`DISPATCH_WIDTH-1],

    /* Payload and Destination of instructions */
    output payloadPkt                      rrPacket_o [0:`ISSUE_WIDTH-1],
    output reg [`DISPATCH_WIDTH-1:0]       valid_bundle_o,

`ifdef PERF_MON
    output reg [`SIZE_LSQ_LOG:0]           reqCount_o,
    output reg [`SIZE_LSQ_LOG:0]           issuedCount_o,
`endif

    /* Bypass tags + valid bit for LD/ST */
    input  [`SIZE_PHYSICAL_LOG:0]          rsr0Tag_i,

    /* Count of Valid Issue Q Entries goes to Dispatch */
    output [`SIZE_ISSUEQ_LOG:0]            cntInstIssueQ_o,
    output                                 iqflRamReady_o
);


/* Newly definied register. This has been shifteg from the RegRead Stage*/	//modified
// TODO: Not partitioned
reg  [`SIZE_PHYSICAL_TABLE-1:0]        phyRegValidVect;

/************************************************************************************
 *  exePipeVect: FU type of the instructions in the Issue Queue. This information is
 *             used for selecting ready instructions for scheduling per functional
 *             unit.
 ************************************************************************************/
//reg  [`ISSUE_WIDTH_LOG-1:0]            exePipeVect [`SIZE_ISSUEQ-1:0];
reg  [`SIZE_ISSUEQ-1:0][`ISSUE_WIDTH_LOG-1:0]  exePipeVect;


/************************************************************************************
 *  iqScheduledVect: 1-bit indicating whether the issue queue entry has been issued
 *                    for execution.
 ************************************************************************************/
//reg  [`SIZE_ISSUEQ-1:0]                iqScheduledVect;


/************************************************************************************
 *  phyDestVect: Used by the select tree to mux tags down so that wakeup can be
 *  done a cycle earlier. 
 *  Every entry is read every cycle by the select tree
 ***********************************************************************************/
//reg [`SIZE_PHYSICAL_LOG-1:0]           phyDestVect [`SIZE_ISSUEQ-1:0];
//phys_reg                               phyDestVect [`SIZE_ISSUEQ-1:0];
phys_reg  [`SIZE_ISSUEQ-1:0]             phyDestVect;

/***********************************************************************************/

/* IQ entries for incoming instructions */
iqEntryPkt                             freeEntry_t [0:`DISPATCH_WIDTH-1];
iqEntryPkt                             freeEntry   [0:`DISPATCH_WIDTH-1];

/* IQ entries of selected instructions */
iqEntryPkt                             grantedEntry    [0:`ISSUE_WIDTH-1];
iqEntryPkt                             grantedEntry_t  [0:`ISSUE_WIDTH-1];
iqEntryPkt                             selectedEntry   [0:`ISSUE_WIDTH-1];
wire                                   selectedEntryValid   [0:`ISSUE_WIDTH-1];

/* IQ entries being freed (not all granted entries get freed together) */
iqEntryPkt                             freedEntry      [0:`ISSUE_WIDTH-1];

reg     [0:`DISPATCH_WIDTH-1]          src1RsrMatch;
reg     [0:`DISPATCH_WIDTH-1]          src2RsrMatch;
reg     [0:`DISPATCH_WIDTH-1]          src1RsrMatch_t  [0:`ISSUE_WIDTH-1];
reg     [0:`DISPATCH_WIDTH-1]          src2RsrMatch_t  [0:`ISSUE_WIDTH-1];
reg     [0:`DISPATCH_WIDTH-1]          src1RsrMatch_lane  [0:`ISSUE_WIDTH-1];
reg     [0:`DISPATCH_WIDTH-1]          src2RsrMatch_lane  [0:`ISSUE_WIDTH-1];

/* newSrcReady sets the srcReady bits of the dispatched instructions */
reg                                    newSrc1Ready    [0:`DISPATCH_WIDTH-1];
reg                                    newSrc2Ready    [0:`DISPATCH_WIDTH-1];



reg  [`SIZE_ISSUEQ-1:0]                reqVect;


/* Wires to "alias" the RSR + valid bit*/
wire                                   payloadRamReady_o;
phys_reg                               rsrTag_t [0:`ISSUE_WIDTH-1];
phys_reg                               rsrTag   [0:`ISSUE_WIDTH-1];


reg [`SIZE_ISSUEQ-1:0] ISsimple;
reg ISsimple_t [0:`ISSUE_WIDTH-1];


// Counting the number of active DISPATCH lanes
// Should be 1 bit wider as it should hold values from 1 to `DISPATCH_WIDTH
// RBRC
reg [`DISPATCH_WIDTH_LOG:0] numDispatchLaneActive;
reg [`SIZE_ISSUEQ_LOG:0] iqSize;
always_comb
begin
  int i;
  numDispatchLaneActive = 0;
  for(i = 0; i < `DISPATCH_WIDTH; i++)
    numDispatchLaneActive = numDispatchLaneActive + dispatchLaneActive_i[i];

  case(iqPartitionActive_i)
    4'b1111:iqSize = `SIZE_ISSUEQ;
    4'b0111:iqSize = `SIZE_ISSUEQ-(`SIZE_ISSUEQ/4);
    4'b0011:iqSize = `SIZE_ISSUEQ/2;
    4'b0001:iqSize = `SIZE_ISSUEQ/4;
    default:iqSize = `SIZE_ISSUEQ; 
  endcase
end


/************************************************************************************
 * Issue Queue Free List.
 *   A circular buffer that keeps tracks of free IQ entries.
 ************************************************************************************/

IssueQFreeList issueQfreelist (

    .clk                (clk),
    .reset              (reset),
    .resetRams_i        (resetRams_i),
    .iqSize_i           (iqSize),
    .numDispatchLaneActive_i (numDispatchLaneActive),

    .flush_i            (flush_i | reconfigureCore_i),
    .dispatchLaneActive_i(dispatchLaneActive_i),
    .issueLaneActive_i (issueLaneActive_i),
    .iqPartitionActive_i(iqPartitionActive_i),

    //.dispatchReady_i     (dispatchReady_i),

    /* IQ entries selected for issuing this cycle */
    .grantedEntry_i     (selectedEntry),

    /* IQ entries freed this cycle. Not all granted entries are freed. */
    .freedEntry_o       (freedEntry),

    /* Free IQ entries for the incoming instructions. */
    .freeEntry_o        (freeEntry_t),

    /* Count of valid IQ entries. Goes to dispatch */
    .cntInstIssueQ_o    (cntInstIssueQ_o),
    .iqflRamReady_o     (iqflRamReady_o)
);

genvar wr;
generate
  for (wr = 0; wr < `DISPATCH_WIDTH; wr = wr + 1)
  begin:CLAMP_WR
      PGIsolationCell #(
        .WIDTH(`SIZE_ISSUEQ_LOG+1)
      ) wrAddrClamp
      (
        .clampEn(~dispatchLaneActive_i[wr]),
        .signalIn(freeEntry_t[wr]),
        .signalOut(freeEntry[wr]),
        .clampValue({(`SIZE_ISSUEQ_LOG+1){1'b0}})
      );
  end
endgenerate


/************************************************************************************
 * Set and clear the physical register valid bits. Set the bits of tags broadcasted 
 * by the RSR. Clear the bits of incoming instruction's destination register (if valid)
 ************************************************************************************/
always_ff @(posedge clk or posedge reset)
begin:UPDATE_PHY_REG
    int i;

    if (reset)
    begin
        for (i = 0; i < `SIZE_RMT; i++)
        begin
            phyRegValidVect[i] <= 1'b1;
        end

        for (i = `SIZE_RMT; i < `SIZE_PHYSICAL_TABLE; i++)
        begin
            phyRegValidVect[i] <= 1'b0;
        end
    end

    else if (exceptionFlag_i)
    begin
        for (i = 0; i < `SIZE_RMT; i++)
        begin
            phyRegValidVect[i] <= 1'b1;
        end

        for (i = `SIZE_RMT; i < `SIZE_PHYSICAL_TABLE; i++)
        begin
            phyRegValidVect[i] <= 1'b0;
        end
    end

    else if (reconfigureCore_i)
    begin
        for (i = 0; i < `SIZE_RMT; i++)
        begin
            phyRegValidVect[i] <= 1'b1;
        end

        for (i = `SIZE_RMT; i < `SIZE_PHYSICAL_TABLE; i++)
        begin
            phyRegValidVect[i] <= 1'b0;
        end
    end

    else
    begin

        /* Clear ready bit of incoming instruction's dest reg */
        for (i = 0; i < `DISPATCH_WIDTH; i++)
        begin
            // The valid bit in an inactive dispatch lane should never be 1
            if (phyDest_i[i].valid & dispatchLaneActive_i[i]) 
            begin
                phyRegValidVect[phyDest_i[i].reg_id] <= 1'b0;
            end
        end


        /* Set ready bit of instructions leaving the RSR */
        for (i = 0; i < `ISSUE_WIDTH; i++)
        begin
            if (rsrTag[i].valid)  
            begin
                phyRegValidVect[rsrTag[i].reg_id]    <= 1'b1;
            end
        end
    end
end


/************************************************************************************
 * ISSUEQ_PAYLOAD: Has all the necessary information required by function unit to
 *  execute the instruction. Implemented as payloadRAM
 *  (Source registers, LD/ST queue ID, Active List ID, Destination register,
 *  Immediate data, LD/ST data size, Opcode, Program counter, Predicted
 *  Target Address, Ctiq Tag, Predicted Branch direction)
 ************************************************************************************/

payloadPkt                             payloadData   [0:`ISSUE_WIDTH-1];

payloadPkt                             payloadWrData [0:`DISPATCH_WIDTH-1];
reg                                    payloadWe     [0:`DISPATCH_WIDTH-1];


always_comb
begin
    int i;
    for (i = 0; i < `DISPATCH_WIDTH; i++)
    begin
        payloadWrData[i].seqNo    = iqPacket_i[i].seqNo;
        payloadWrData[i].pc       = iqPacket_i[i].pc;
        payloadWrData[i].inst     = iqPacket_i[i].inst;
        payloadWrData[i].logDest  = iqPacket_i[i].logDest;
        payloadWrData[i].phyDest  = iqPacket_i[i].phyDest;
        payloadWrData[i].phySrc2  = iqPacket_i[i].phySrc2;
        payloadWrData[i].phySrc1  = iqPacket_i[i].phySrc1;
        payloadWrData[i].immed    = iqPacket_i[i].immed;
        payloadWrData[i].lsqID    = lsqID_i[i];
        payloadWrData[i].alID     = alID_i[i];
        payloadWrData[i].ldstSize = iqPacket_i[i].ldstSize; // why was this commented out TODO Anil
        payloadWrData[i].predNPC  = iqPacket_i[i].predNPC;
        payloadWrData[i].isSimple = iqPacket_i[i].isSimple;
        payloadWrData[i].isFP     = iqPacket_i[i].isFP;
        payloadWrData[i].ctrlType = iqPacket_i[i].ctrlType;
        payloadWrData[i].ctiID    = iqPacket_i[i].ctiID;
        payloadWrData[i].predDir  = iqPacket_i[i].predDir;
        payloadWrData[i].valid    = 0;
        payloadWe[i]              = dispatchReady_i & dispatchLaneActive_i[i];
    end
end

IQPAYLOAD_RAM_PARTITIONED #(
    .RPORT       (`ISSUE_WIDTH),
    .WPORT       (`DISPATCH_WIDTH),
    .DEPTH       (`SIZE_ISSUEQ),
    .INDEX       (`SIZE_ISSUEQ_LOG),
    .WIDTH       (`PAYLOAD_PKT_SIZE)
)

payloadRAM (

    .addr0_i    (grantedEntry[0].id),
    .data0_o    (payloadData[0]),

    `ifdef ISSUE_TWO_WIDE
    .addr1_i    (grantedEntry[1].id),
    .data1_o    (payloadData[1]),
    `endif

    `ifdef ISSUE_THREE_WIDE
    .addr2_i    (grantedEntry[2].id),
    .data2_o    (payloadData[2]),
    `endif

    `ifdef ISSUE_FOUR_WIDE
    .addr3_i    (grantedEntry[3].id),
    .data3_o    (payloadData[3]),
    `endif

    `ifdef ISSUE_FIVE_WIDE
    .addr4_i    (grantedEntry[4].id),
    .data4_o    (payloadData[4]),
    `endif

    `ifdef ISSUE_SIX_WIDE
    .addr5_i    (grantedEntry[5].id),
    .data5_o    (payloadData[5]),
    `endif

    `ifdef ISSUE_SEVEN_WIDE
    .addr6_i    (grantedEntry[6].id),
    .data6_o    (payloadData[6]),
    `endif

    `ifdef ISSUE_EIGHT_WIDE
    .addr7_i    (grantedEntry[7].id),
    .data7_o    (payloadData[7]),
    `endif


    .addr0wr_i  (freeEntry[0].id),
    .data0wr_i  (payloadWrData[0]),
    .we0_i      (payloadWe[0]),

    `ifdef DISPATCH_TWO_WIDE
    .addr1wr_i  (freeEntry[1].id),
    .data1wr_i  (payloadWrData[1]),
    .we1_i      (payloadWe[1]),
    `endif

    `ifdef DISPATCH_THREE_WIDE
    .addr2wr_i  (freeEntry[2].id),
    .data2wr_i  (payloadWrData[2]),
    .we2_i      (payloadWe[2]),
    `endif

    `ifdef DISPATCH_FOUR_WIDE
    .addr3wr_i  (freeEntry[3].id),
    .data3wr_i  (payloadWrData[3]),
    .we3_i      (payloadWe[3]),
    `endif

    `ifdef DISPATCH_FIVE_WIDE
    .addr4wr_i  (freeEntry[4].id),
    .data4wr_i  (payloadWrData[4]),
    .we4_i      (payloadWe[4]),
    `endif

    `ifdef DISPATCH_SIX_WIDE
    .addr5wr_i  (freeEntry[5].id),
    .data5wr_i  (payloadWrData[5]),
    .we5_i      (payloadWe[5]),
    `endif

    `ifdef DISPATCH_SEVEN_WIDE
    .addr6wr_i  (freeEntry[6].id),
    .data6wr_i  (payloadWrData[6]),
    .we6_i      (payloadWe[6]),
    `endif

    `ifdef DISPATCH_EIGHT_WIDE
    .addr7wr_i  (freeEntry[7].id),
    .data7wr_i  (payloadWrData[7]),
    .we7_i      (payloadWe[7]),
    `endif

    .dispatchLaneActive_i (dispatchLaneActive_i),
    .issueLaneActive_i    (issueLaneActive_i),
    .iqPartitionActive_i  (iqPartitionActive_i),

    .clk        (clk)
    //.reset      (reset)
);


/************************************************************************************
 * WAKEUP
 *   (1) Search the src1 and src2 CAMs for entries matching the RSR tags
 *   (2) OR the match vectors for all tags
 *   (3) Determine the ready bits for incoming instruction's sources
 *   (4) Shift the ready bits to their assigned entries
 *   (5) Update src1ValidVect and src2ValidVect with the vectors from (2) and (4)
 ************************************************************************************/

reg  [`SIZE_ISSUEQ-1:0]                src1MatchVect_t [0:`ISSUE_WIDTH-1];
reg  [`SIZE_ISSUEQ-1:0]                src1MatchVect;

reg  [`SIZE_ISSUEQ-1:0]                src2MatchVect_t [0:`ISSUE_WIDTH-1];
reg  [`SIZE_ISSUEQ-1:0]                src2MatchVect;


/* (1) Search the src1 CAM for entries matching the RSR tags */
WAKEUP_CAM_PARTITIONED #(
    .RPORT       (`ISSUE_WIDTH),
    .WPORT       (`DISPATCH_WIDTH),
    .DEPTH       (`SIZE_ISSUEQ),
    .INDEX       (`SIZE_ISSUEQ_LOG),
    .WIDTH       (`SIZE_PHYSICAL_LOG)
)

src1Cam (

    .tag0_i      (rsrTag[0].reg_id),
    .vect0_o     (src1MatchVect_t[0]),

    `ifdef ISSUE_TWO_WIDE
    .tag1_i      (rsrTag[1].reg_id),
    .vect1_o     (src1MatchVect_t[1]),
    `endif

    `ifdef ISSUE_THREE_WIDE
    .tag2_i      (rsrTag[2].reg_id),
    .vect2_o     (src1MatchVect_t[2]),
    `endif

    `ifdef ISSUE_FOUR_WIDE
    .tag3_i      (rsrTag[3].reg_id),
    .vect3_o     (src1MatchVect_t[3]),
    `endif

    `ifdef ISSUE_FIVE_WIDE
    .tag4_i      (rsrTag[4].reg_id),
    .vect4_o     (src1MatchVect_t[4]),
    `endif

    `ifdef ISSUE_SIX_WIDE
    .tag5_i      (rsrTag[5].reg_id),
    .vect5_o     (src1MatchVect_t[5]),
    `endif

    `ifdef ISSUE_SEVEN_WIDE
    .tag6_i      (rsrTag[6].reg_id),
    .vect6_o     (src1MatchVect_t[6]),
    `endif

    `ifdef ISSUE_EIGHT_WIDE
    .tag7_i      (rsrTag[7].reg_id),
    .vect7_o     (src1MatchVect_t[7]),
    `endif


    .addr0wr_i   (freeEntry[0].id),
    .data0wr_i   (iqPacket_i[0].phySrc1),
    .we0_i       (dispatchReady_i),

    `ifdef DISPATCH_TWO_WIDE
    .addr1wr_i   (freeEntry[1].id),
    .data1wr_i   (iqPacket_i[1].phySrc1),
    .we1_i       (dispatchReady_i),
    `endif

    `ifdef DISPATCH_THREE_WIDE
    .addr2wr_i   (freeEntry[2].id),
    .data2wr_i   (iqPacket_i[2].phySrc1),
    .we2_i       (dispatchReady_i),
    `endif

    `ifdef DISPATCH_FOUR_WIDE
    .addr3wr_i   (freeEntry[3].id),
    .data3wr_i   (iqPacket_i[3].phySrc1),
    .we3_i       (dispatchReady_i),
    `endif

    `ifdef DISPATCH_FIVE_WIDE
    .addr4wr_i   (freeEntry[4].id),
    .data4wr_i   (iqPacket_i[4].phySrc1),
    .we4_i       (dispatchReady_i),
    `endif

    `ifdef DISPATCH_SIX_WIDE
    .addr5wr_i   (freeEntry[5].id),
    .data5wr_i   (iqPacket_i[5].phySrc1),
    .we5_i       (dispatchReady_i),
    `endif

    `ifdef DISPATCH_SEVEN_WIDE
    .addr6wr_i   (freeEntry[6].id),
    .data6wr_i   (iqPacket_i[6].phySrc1),
    .we6_i       (dispatchReady_i),
    `endif

    `ifdef DISPATCH_EIGHT_WIDE
    .addr7wr_i   (freeEntry[7].id),
    .data7wr_i   (iqPacket_i[7].phySrc1),
    .we7_i       (dispatchReady_i),
    `endif

    .dispatchLaneActive_i(dispatchLaneActive_i),
    .issueLaneActive_i(issueLaneActive_i),
    .iqPartitionActive_i  (iqPartitionActive_i),

    .clk         (clk)
    //.reset       (reset)
);


WAKEUP_CAM_PARTITIONED #(
    .RPORT       (`ISSUE_WIDTH),
    .WPORT       (`DISPATCH_WIDTH),
    .DEPTH       (`SIZE_ISSUEQ),
    .INDEX       (`SIZE_ISSUEQ_LOG),
    .WIDTH       (`SIZE_PHYSICAL_LOG)
)

src2Cam (

    .tag0_i      (rsrTag[0].reg_id),
    .vect0_o     (src2MatchVect_t[0]),

    `ifdef ISSUE_TWO_WIDE
    .tag1_i      (rsrTag[1].reg_id),
    .vect1_o     (src2MatchVect_t[1]),
    `endif

    `ifdef ISSUE_THREE_WIDE
    .tag2_i      (rsrTag[2].reg_id),
    .vect2_o     (src2MatchVect_t[2]),
    `endif

    `ifdef ISSUE_FOUR_WIDE
    .tag3_i      (rsrTag[3].reg_id),
    .vect3_o     (src2MatchVect_t[3]),
    `endif

    `ifdef ISSUE_FIVE_WIDE
    .tag4_i      (rsrTag[4].reg_id),
    .vect4_o     (src2MatchVect_t[4]),
    `endif

    `ifdef ISSUE_SIX_WIDE
    .tag5_i      (rsrTag[5].reg_id),
    .vect5_o     (src2MatchVect_t[5]),
    `endif

    `ifdef ISSUE_SEVEN_WIDE
    .tag6_i      (rsrTag[6].reg_id),
    .vect6_o     (src2MatchVect_t[6]),
    `endif

    `ifdef ISSUE_EIGHT_WIDE
    .tag7_i      (rsrTag[7].reg_id),
    .vect7_o     (src2MatchVect_t[7]),
    `endif


    .addr0wr_i   (freeEntry[0].id),
    .data0wr_i   (iqPacket_i[0].phySrc2),
    .we0_i       (dispatchReady_i),

    `ifdef DISPATCH_TWO_WIDE
    .addr1wr_i   (freeEntry[1].id),
    .data1wr_i   (iqPacket_i[1].phySrc2),
    .we1_i       (dispatchReady_i),
    `endif

    `ifdef DISPATCH_THREE_WIDE
    .addr2wr_i   (freeEntry[2].id),
    .data2wr_i   (iqPacket_i[2].phySrc2),
    .we2_i       (dispatchReady_i),
    `endif

    `ifdef DISPATCH_FOUR_WIDE
    .addr3wr_i   (freeEntry[3].id),
    .data3wr_i   (iqPacket_i[3].phySrc2),
    .we3_i       (dispatchReady_i),
    `endif

    `ifdef DISPATCH_FIVE_WIDE
    .addr4wr_i   (freeEntry[4].id),
    .data4wr_i   (iqPacket_i[4].phySrc2),
    .we4_i       (dispatchReady_i),
    `endif

    `ifdef DISPATCH_SIX_WIDE
    .addr5wr_i   (freeEntry[5].id),
    .data5wr_i   (iqPacket_i[5].phySrc2),
    .we5_i       (dispatchReady_i),
    `endif

    `ifdef DISPATCH_SEVEN_WIDE
    .addr6wr_i   (freeEntry[6].id),
    .data6wr_i   (iqPacket_i[6].phySrc2),
    .we6_i       (dispatchReady_i),
    `endif

    `ifdef DISPATCH_EIGHT_WIDE
    .addr7wr_i   (freeEntry[7].id),
    .data7wr_i   (iqPacket_i[7].phySrc2),
    .we7_i       (dispatchReady_i),
    `endif

    .dispatchLaneActive_i(dispatchLaneActive_i),
    .issueLaneActive_i(issueLaneActive_i),
    .iqPartitionActive_i  (iqPartitionActive_i),

    .clk         (clk)
    //.reset       (reset)
);


// TODO: This logic can go inside the WAKEUP_CAM and become partitioned
/* (2) OR the match vectors for all tags */
always_comb
begin
    int i;

    src1MatchVect = 0;
    src2MatchVect = 0;

    for (i = 0; i < `ISSUE_WIDTH; i++)
    begin
        src1MatchVect = src1MatchVect | (src1MatchVect_t[i] & {`SIZE_ISSUEQ{rsrTag[i].valid}});
        src2MatchVect = src2MatchVect | (src2MatchVect_t[i] & {`SIZE_ISSUEQ{rsrTag[i].valid}});
    end
end

/* Create payload packet using updated branch mask and read payload */
always_comb
begin
    int i;

    for (i = 0; i < `ISSUE_WIDTH; i++)
    begin
        rrPacket_o[i]        = payloadData[i];
        rrPacket_o[i].valid  = grantedEntry[i].valid;
    end
end




always_comb
begin:CHECK_NEW_INSTS_SOURCE_OPERAND
    int i;

    for (i = 0; i < `DISPATCH_WIDTH; i++)
    begin
        src1RsrMatch[i]   = 0;
        src2RsrMatch[i]   = 0;
    end


    // Bitwise OR the vectors together
    for (i = 0; i < `ISSUE_WIDTH; i++)
    begin
        src1RsrMatch   = src1RsrMatch | src1RsrMatch_lane[i];
        src2RsrMatch   = src2RsrMatch | src2RsrMatch_lane[i];
    end

    for (i = 0; i < `DISPATCH_WIDTH; i++)
    begin

        newSrc1Ready[i] = ( src1RsrMatch[i]                        || /* (i)   */
                            phyRegValidVect[iqPacket_i[i].phySrc1] || /* (ii)  */
                            ~iqPacket_i[i].phySrc1Valid)           &  /* (iii) */
                            dispatchLaneActive_i[i]?                  /* Is active? */
                            1'h1 : 1'h0;

        newSrc2Ready[i] = ( src2RsrMatch[i]                        || /* (i)   */
                            phyRegValidVect[iqPacket_i[i].phySrc2] || /* (ii)  */
                            ~iqPacket_i[i].phySrc2Valid)           &  /* (iii) */
                            dispatchLaneActive_i[i]?                  /* Is active? */
                            1'h1 : 1'h0;

    end
end

localparam PARTITION_SIZE = `SIZE_ISSUEQ/`NUM_PARTS_IQ;

phys_reg       [PARTITION_SIZE-1:0]                    phyDestVect_t[`NUM_PARTS_IQ-1:0];
reg  [`ISSUE_WIDTH_LOG-1:0][PARTITION_SIZE-1:0]        exePipeVect_t[`NUM_PARTS_IQ-1:0];

genvar part;
generate
  for (part = 0; part < `NUM_PARTS_IQ; part++)
  begin:ISSUE_PART
    IssuePartition #(.PARTITION_ID(part)) 
      part_inst (

        .clk          (clk),
        .reset        (reset),
        .flush_i      (flush_i),

        .dispatchLaneActive_i(dispatchLaneActive_i),
        .partitionActive_i(iqPartitionActive_i[part]),

        .dispatchReady_i(dispatchReady_i),

        .newSrc1Ready (newSrc1Ready),
        .newSrc2Ready (newSrc2Ready),
        .freeEntry    (freeEntry),
        .selectedEntry(selectedEntry),
        .iqPacket_i   (iqPacket_i), 

        .src1MatchVect(src1MatchVect[((part+1)*PARTITION_SIZE-1):part*PARTITION_SIZE]),
        .src2MatchVect(src2MatchVect[((part+1)*PARTITION_SIZE-1):part*PARTITION_SIZE]),

        .phyDestVect_o(phyDestVect[((part+1)*PARTITION_SIZE-1):part*PARTITION_SIZE]),
        .exePipeVect_o(exePipeVect[((part+1)*PARTITION_SIZE-1):part*PARTITION_SIZE]),
        .ISsimple_o   (ISsimple[((part+1)*PARTITION_SIZE-1):part*PARTITION_SIZE]),
        .reqVect_o    (reqVect[((part+1)*PARTITION_SIZE-1):part*PARTITION_SIZE])

      );

  end
endgenerate

`ifdef AGE_BASED_ORDERING

  logic [`SIZE_ISSUEQ-1:0]        agedReqVect [0:`ISSUE_WIDTH-1];

  AgeOrdering ageOrdering(
	  .clk                (clk),
	  .reset              (reset|flush_i),
    .iqSize_i           (),
    .flush_i            (flush_i),
	  .dispatchReady_i     (dispatchReady_i),
    .alHead_i           (alHead_i),
    .alTail_i           (alTail_i),
    .alID_i             (alID_i),
	  .freeEntry_i        (freeEntry),
    .iqPacket_i         (iqPacket_i),
	  .freedEntry_i       (freedEntry),
	  .rrPacket_i         (rrPacket_o),
    .requestVector_i    (reqVect),

    .agedReqVector_o    (agedReqVect) 

	);

  logic [`ISSUE_WIDTH-1:0]  ageBasedOrdering;

  always_comb
  begin
    ageBasedOrdering = 0;

    `ifdef AGE_BASED_ORDERING_LANE0
      ageBasedOrdering[0] = 1'b1;
    `endif

    `ifdef AGE_BASED_ORDERING_LANE1
      ageBasedOrdering[1] = 1'b1;
    `endif

    `ifdef AGE_BASED_ORDERING_LANE2
      ageBasedOrdering[2] = 1'b1;
    `endif

    `ifdef AGE_BASED_ORDERING_LANE3
      ageBasedOrdering[3] = 1'b1;
    `endif

    `ifdef AGE_BASED_ORDERING_LANE4
      ageBasedOrdering[4] = 1'b1;
    `endif

    `ifdef AGE_BASED_ORDERING_LANE5
      ageBasedOrdering[4] = 1'b1;
    `endif

    `ifdef AGE_BASED_ORDERING_LANE6
      ageBasedOrdering[6] = 1'b1;
    `endif

    `ifdef AGE_BASED_ORDERING_LANE7
      ageBasedOrdering[7] = 1'b1;
    `endif
  end

`endif // AGE_BASED_ORDERING


genvar lane;
generate
  for (lane = 0; lane < `ISSUE_WIDTH; lane++)
  begin:ISSUE_LANE


    IssueLane #(.ISSUE_LANE_ID(lane))
      lane_inst (
        .clk          (clk),
        .reset        (reset),
        .flush_i      (flush_i),
        .dispatchReady_i(dispatchReady_i),
        .dispatchLaneActive_i(dispatchLaneActive_i),
        .laneActive_i  (issueLaneActive_i[lane]),

        .iqPacket_i   (iqPacket_i),
        .freeEntry    (freeEntry),
        .rsr0Tag_i    (rsr0Tag_i),
        .reqVect      (reqVect),

      `ifdef AGE_BASED_ORDERING
        .ageBasedOrdering  (ageBasedOrdering[lane]),
        .agedReqVect  (agedReqVect[lane]),
      `endif

        .phyDestVect(phyDestVect),
        .exePipeVect(exePipeVect),
        .ISsimple(ISsimple),

        .rsrTag       (rsrTag_t[lane]),
        .grantedEntry (grantedEntry_t[lane]),
        .selectedEntry(selectedEntry[lane]),
        .src1RsrMatch_o(src1RsrMatch_t[lane]),
        .src2RsrMatch_o(src2RsrMatch_t[lane])
      );

    // Mimic Isolation
    always_comb
    begin
      grantedEntry[lane]  = grantedEntry_t[lane];
      rsrTag[lane]        = rsrTag_t[lane];

      if(~issueLaneActive_i[lane])
      begin
        grantedEntry[lane].valid = 1'b0;
        rsrTag[lane].valid = 1'b0;
      end
      
      src1RsrMatch_lane[lane] = src1RsrMatch_t[lane] & {`DISPATCH_WIDTH{issueLaneActive_i[lane]}};
      src2RsrMatch_lane[lane] = src2RsrMatch_t[lane] & {`DISPATCH_WIDTH{issueLaneActive_i[lane]}};
    end

  end
  

endgenerate

always_comb 
begin
  int i;
  for (i = 0; i < `DISPATCH_WIDTH; i++)
  begin
    valid_bundle_o[i] = dispatchReady_i & dispatchLaneActive_i[i];
  end
end

`ifdef PERF_MON
  logic   [`SIZE_LSQ_LOG:0] reqCount_next;
  logic   [`SIZE_LSQ_LOG:0] issuedCount_next;

  always_ff @(posedge clk or posedge reset)
  begin
    if(reset)
    begin
      reqCount_o      <= 0;
      issuedCount_o   <= 0;
    end
    else
    begin
      reqCount_o      <= reqCount_next;
      issuedCount_o   <= issuedCount_next;
    end
  end
 
    reg                    grantedEntryMatch;
    reg  [`SIZE_ISSUEQ-1:0]                grantedVect;
    
    always_comb
    begin
      int i,j;
      grantedVect = 0;
      for(i=0;i<`SIZE_ISSUEQ;i++)
      begin

        grantedEntryMatch = 0;
    
        for (j = 0; j < `ISSUE_WIDTH; j++)
        begin
            grantedEntryMatch = grantedEntryMatch || (selectedEntry[j].valid & (i == selectedEntry[j].id));
        end
    
        if (grantedEntryMatch)
        begin
            grantedVect[i] = 1'h1;
        end
    
        else
        begin
            grantedVect[i] = 1'h0;
        end
      end
    end

  always_comb
  begin
    int i;
    reqCount_next     = 0;;
    issuedCount_next  = 0;
    for(i=0;i<`SIZE_ISSUEQ;i++)
    begin
      reqCount_next     = reqCount_next + reqVect[i];
      issuedCount_next  = issuedCount_next + grantedVect[i];
    end
  end
`endif

endmodule
