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

module IssuePartition #(parameter PARTITION_SIZE = `SIZE_ISSUEQ/`NUM_PARTS_IQ, PARTITION_ID = 0)
  ( 
    input                                  clk,
    input                                  reset,
    input                                  flush_i,

    input  [`DISPATCH_WIDTH-1:0]           dispatchLaneActive_i,
    input                                  partitionActive_i,

    input                                  dispatchReady_i,

    input                                  newSrc1Ready   [0:`DISPATCH_WIDTH-1],
    input                                  newSrc2Ready   [0:`DISPATCH_WIDTH-1],
    input  iqEntryPkt                      freeEntry      [0:`DISPATCH_WIDTH-1],
    input  iqEntryPkt                      selectedEntry  [0:`ISSUE_WIDTH-1],
    input  iqPkt                           iqPacket_i     [0:`DISPATCH_WIDTH-1],

    input  [PARTITION_SIZE-1:0]            src1MatchVect,
    input  [PARTITION_SIZE-1:0]            src2MatchVect,

    output phys_reg  [PARTITION_SIZE-1:0]  phyDestVect_o,
    output [PARTITION_SIZE-1:0]            ISsimple_o,
    output [PARTITION_SIZE-1:0][`ISSUE_WIDTH_LOG-1:0] exePipeVect_o,
    output [PARTITION_SIZE-1:0]            reqVect_o
);


/************************************************************************************
 *  exePipeVect: FU type of the instructions in the Issue Queue. This information is
 *             used for selecting ready instructions for scheduling per functional
 *             unit.
 ************************************************************************************/
reg [PARTITION_SIZE-1:0][`ISSUE_WIDTH_LOG-1:0]  exePipeVect;


/************************************************************************************
 *  iqValidVect: 1-bit indicating validity of each entry in the Issue Queue.
 ************************************************************************************/
reg  [PARTITION_SIZE-1:0]                iqValidVect;

/************************************************************************************
 *  phyDestVect: Used by the select tree to mux tags down so that wakeup can be
 *  done a cycle earlier. 
 *  Every entry is read every cycle by the select tree
 ***********************************************************************************/
phys_reg   [PARTITION_SIZE-1:0]          phyDestVect;

/***********************************************************************************/

/* IQ entries for incoming instructions */
reg  [PARTITION_SIZE-1:0]              freeVect;

/* IQ entries of selected instructions */
reg  [PARTITION_SIZE-1:0]              grantedVect;

/* IQ entries being freed (not all granted entries get freed together) */
iqEntryPkt                             freedEntry      [0:`ISSUE_WIDTH-1];
reg  [PARTITION_SIZE-1:0]              freedVect;


/* newSrcReady sets the srcReady bits of the dispatched instructions */


/* srcValidVect indicates whether operands are ready or not */
reg  [PARTITION_SIZE-1:0]                src1ValidVect;
reg  [PARTITION_SIZE-1:0]                src1Valid_t1;

reg  [PARTITION_SIZE-1:0]                src2ValidVect;
reg  [PARTITION_SIZE-1:0]                src2Valid_t1;

reg  [PARTITION_SIZE-1:0]                reqVect;



reg [PARTITION_SIZE-1:0] ISsimple;


/************************************************************************************
 * (4) Update the ready bit in the IQ for the incoming instructions by
 *     shifting newSrcReady to the free entry given to the instruction
 ************************************************************************************/
always_comb
begin: UPDATE_SRC_READY_BIT
    int i;
    int offset;

    src1Valid_t1 = 0;
    src2Valid_t1 = 0;

    /* TODO: Try rewriting this */
    // This builds an explicit priority logic to 
    // wirte into the valid registers with lower
    // lanes having higher priority. This inspite
    // of the fact that all the freeEntry.id s are
    // unique.
    for (i = 0; i < PARTITION_SIZE; i++)
    begin
        offset = i + PARTITION_ID*PARTITION_SIZE;

        if(dispatchReady_i & (offset == freeEntry[0].id))
        begin
            src1Valid_t1[i]  =  newSrc1Ready[0];
            src2Valid_t1[i]  =  newSrc2Ready[0];
        end

        `ifdef DISPATCH_TWO_WIDE
        else if(dispatchReady_i & (offset == freeEntry[1].id))
        begin
            src1Valid_t1[i]  =  newSrc1Ready[1];
            src2Valid_t1[i]  =  newSrc2Ready[1];
        end
        `endif

        `ifdef DISPATCH_THREE_WIDE
        else if(dispatchReady_i & (offset == freeEntry[2].id))
        begin
            src1Valid_t1[i]  =  newSrc1Ready[2];
            src2Valid_t1[i]  =  newSrc2Ready[2];
        end
        `endif

        `ifdef DISPATCH_FOUR_WIDE
        else if(dispatchReady_i & (offset == freeEntry[3].id))
        begin
            src1Valid_t1[i]  =  newSrc1Ready[3];
            src2Valid_t1[i]  =  newSrc2Ready[3];
        end
        `endif

        `ifdef DISPATCH_FIVE_WIDE
        else if(dispatchReady_i & (offset == freeEntry[4].id))
        begin
            src1Valid_t1[i]  =  newSrc1Ready[4];
            src2Valid_t1[i]  =  newSrc2Ready[4];
        end
        `endif

        `ifdef DISPATCH_SIX_WIDE
        else if(dispatchReady_i & (offset == freeEntry[5].id))
        begin
            src1Valid_t1[i]  =  newSrc1Ready[5];
            src2Valid_t1[i]  =  newSrc2Ready[5];
        end
        `endif

        `ifdef DISPATCH_SEVEN_WIDE
        else if(dispatchReady_i & (offset == freeEntry[6].id))
        begin
            src1Valid_t1[i]  =  newSrc1Ready[6];
            src2Valid_t1[i]  =  newSrc2Ready[6];
        end
        `endif

        `ifdef DISPATCH_EIGHT_WIDE
        else if(dispatchReady_i & (offset == freeEntry[7].id))
        begin
            src1Valid_t1[i]  =  newSrc1Ready[7];
            src2Valid_t1[i]  =  newSrc2Ready[7];
        end
        `endif

        else
        begin
            src1Valid_t1[i]  =  0;
            src2Valid_t1[i]  =  0;
        end
    end
end


/************************************************************************************
 * (5) Update src1ValidVect and src2ValidVect 
 ************************************************************************************/
always_ff @(posedge clk or posedge reset)
begin
    if (reset)
    begin
        src1ValidVect  <= 0;
        src2ValidVect  <= 0;
    end
    else if (flush_i)
    begin
        src1ValidVect  <= 0;
        src2ValidVect  <= 0;
    end
    else
    begin
        src1ValidVect  <= (src1ValidVect | src1MatchVect) & iqValidVect | src1Valid_t1;
        src2ValidVect  <= (src2ValidVect | src2MatchVect) & iqValidVect | src2Valid_t1;
    end
end



/************************************************************************************
 * Get vectors for updating iqValidVect and iqScheduledVect 
 * (1) Free entries assigned to incoming instructions
 * (2) Entries freed by the IQ free list
 * (3) Entries granted by the select logic
 ************************************************************************************/
always_comb
begin: PREPARE_VALID_ARRAY_NORMAL
    int i, j;

    reg                    freeEntryMatch;
    reg                    freedEntryMatch;
    reg                    grantedEntryMatch;

    freeVect   = 0;
    freedVect  = 0;
    grantedVect = 0;

   
    /* (1) Set entries assigned to incoming instructions to 1 */
    for (i = 0; i < PARTITION_SIZE; i++)
    begin

        freeEntryMatch = 0;

        for (j = 0; j < `DISPATCH_WIDTH; j++)
        begin
            freeEntryMatch = freeEntryMatch || (((PARTITION_ID*PARTITION_SIZE + i) == freeEntry[j].id) & dispatchLaneActive_i[j]);
        end

        if (dispatchReady_i && freeEntryMatch)
        begin
            freeVect[i] = 1'h1;
        end

        else
        begin
            freeVect[i] = 1'h0;
        end
    end

    /* (2) Set granted entries to 1 */
    for (i = 0; i < PARTITION_SIZE; i++)
    begin

        grantedEntryMatch = 0;

        for (j = 0; j < `ISSUE_WIDTH; j++)
        begin
            grantedEntryMatch = grantedEntryMatch || (selectedEntry[j].valid & ((i + PARTITION_ID*PARTITION_SIZE) == selectedEntry[j].id));
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


/************************************************************************************
 * Update iqValidVect: set free entries and clear freed entries
 ************************************************************************************/
always_ff @(posedge clk or posedge reset)
begin
    if (reset)
    begin
        iqValidVect     <= 0;
    end

    else if (flush_i)
    begin
        iqValidVect     <= 0;
    end
    else
    begin
        iqValidVect     <= (iqValidVect | freeVect) & ~grantedVect;
    end
end


/************************************************************************************
 * Select Logic. 
 *
 * (1) Create a request vector (reqVect) indicating which IQ entries are
 *     (a) Valid
 *     (b) Not already scheduled
 *     (c) Have both source operands ready
 *
 * (2) Create a subset vector for each execution pipe containing the entries 
 *     going to that pipe.
 *
 * (3) Select one instruction (if any are valid) to be issued to each pipe.
 ************************************************************************************/

/* (1) Create a request vector (reqVect) */
always_comb
begin
`ifdef ISSUE_TWO_DEEP
    reqVect = iqValidVect & src1ValidVect & src2ValidVect;
`else /* ISSUE_ONE_DEEP */
    reqVect = iqValidVect & (src1MatchVect | src1ValidVect) & (src2MatchVect | src2ValidVect);
`endif
end

assign reqVect_o = reqVect;


reg [`SIZE_ISSUEQ_LOG-`NUM_PARTS_IQ_LOG-1:0] wrAddr [0:`DISPATCH_WIDTH-1];
reg                                            wrEn   [0:`DISPATCH_WIDTH-1];
always_comb
begin
  int i;
  for (i = 0; i < `DISPATCH_WIDTH; i++)
  begin
    wrAddr[i] = freeEntry[i].id[`SIZE_ISSUEQ_LOG-`NUM_PARTS_IQ_LOG-1:0];
    wrEn[i]   = dispatchLaneActive_i[i] & (freeEntry[i].id[`SIZE_ISSUEQ_LOG-1:`SIZE_ISSUEQ_LOG-`NUM_PARTS_IQ_LOG] == PARTITION_ID);
  end
end

always_ff @(posedge clk or posedge reset)
begin: newInstructions
    int i;

    if (reset)
    begin
        for (i = 0; i < PARTITION_SIZE; i++)
        begin
            phyDestVect[i] <= 0;
            exePipeVect[i] <= 0;
            ISsimple[i]    <= 0;
        end
    end

    else if (flush_i)
    begin
        for (i = 0; i < PARTITION_SIZE; i++)
        begin
            phyDestVect[i] <= 0;
            exePipeVect[i] <= 0;
            ISsimple[i]    <= 0;
        end
    end
    else if (dispatchReady_i)
    begin
        for (i = 0; i < `DISPATCH_WIDTH; i++)
        begin
          // Write this information only if the particular dispatch lane is active
          if(wrEn[i])
          begin
            // RBRC
            // Added the phyDest valid bit required at a later point
            // to qualify the RSR as only broadcasts from instructions
            // with valid phy dest should wake up dependent instructions
            phyDestVect[wrAddr[i]] <= {iqPacket_i[i].phyDest,iqPacket_i[i].phyDestValid};
            exePipeVect[wrAddr[i]] <= iqPacket_i[i].fu;
            ISsimple[wrAddr[i]]    <= iqPacket_i[i].isSimple;
          end
        end
    end
end

// TODO: Might need to change this
assign exePipeVect_o = exePipeVect;
assign phyDestVect_o = phyDestVect;
assign ISsimple_o    = ISsimple;


endmodule
