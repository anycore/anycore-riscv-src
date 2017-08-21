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

module IssueLane #(parameter ISSUE_LANE_ID = 0) 
  (
    input                                  clk,
    input                                  reset,
    input                                  flush_i,
    input                                  dispatchReady_i,
    input [`DISPATCH_WIDTH-1:0]            dispatchLaneActive_i,
    input                                  laneActive_i,

    /* Bypass tags + valid bit for LD/ST */
    input  iqPkt                           iqPacket_i [0:`DISPATCH_WIDTH-1],
    input  iqEntryPkt                      freeEntry [0:`DISPATCH_WIDTH-1],
    input  [`SIZE_PHYSICAL_LOG:0]          rsr0Tag_i,
    input  [`SIZE_ISSUEQ-1:0]              reqVect,

  `ifdef AGE_BASED_ORDERING
    input                                  ageBasedOrdering,
    input  [`SIZE_ISSUEQ-1:0]              agedReqVect,
  `endif

    input  phys_reg [`SIZE_ISSUEQ-1:0]     phyDestVect,
    //input  [`SIZE_ISSUEQ-1:0][`ISSUE_WIDTH_LOG-1:0]   exePipeVect,
    input  [`SIZE_ISSUEQ-1:0][`ISSUE_WIDTH_LOG-1:0] exePipeVect,
    input  [`SIZE_ISSUEQ-1:0]              ISsimple,

    output phys_reg                        rsrTag,
    output iqEntryPkt                      grantedEntry,
    output iqEntryPkt                      selectedEntry,
    output [0:`DISPATCH_WIDTH-1]           src1RsrMatch_o,
    output [0:`DISPATCH_WIDTH-1]           src2RsrMatch_o   

  );

/************************************************************************************
 *  exePipeVect: FU type of the instructions in the Issue Queue. This information is
 *             used for selecting ready instructions for scheduling per functional
 *             unit.
 ************************************************************************************/
//reg  [`ISSUE_WIDTH_LOG-1:0]            exePipeVect [`SIZE_ISSUEQ-1:0];


/************************************************************************************
 *  phyDestVect: Used by the select tree to mux tags down so that wakeup can be
 *  done a cycle earlier. 
 *  Every entry is read every cycle by the select tree
 ***********************************************************************************/
//phys_reg                               phyDestVect [`SIZE_ISSUEQ-1:0];


/* IQ entries of selected instructions */
//iqEntryPkt                             selectedEntry;
phys_reg                               grantedDest  ;


/* Wires to "alias" the RSR + valid bit*/
phys_reg                               rsrTag_t;


//reg   ISsimple   [`SIZE_ISSUEQ-1:0];
reg   ISsimple_t;
wire  ignoreSimple;

reg   [0:`DISPATCH_WIDTH-1]            src1RsrMatch;
reg   [0:`DISPATCH_WIDTH-1]            src2RsrMatch;

/************************************************************************************
 * (i) Check the broadcasted RSR tags for a match.
 * This is the common "If reading a location being written into this cycle, bypass the
 * 'being written into' value instead of reading the currently stored value" logic.
 ************************************************************************************/
// TODO: Part of IssueQLane Each creating one DISPATCH_WIDTH long vector. These ISSUE_WIDTH
// number of vectors are then ORed together here to form the src1RsrMatch
always_comb
begin
    src1RsrMatch[0] = ((iqPacket_i[0].phySrc1 == rsrTag.reg_id) & rsrTag.valid);
    src2RsrMatch[0] = ((iqPacket_i[0].phySrc2 == rsrTag.reg_id) & rsrTag.valid);

    `ifdef DISPATCH_TWO_WIDE
    src1RsrMatch[1] = ((iqPacket_i[1].phySrc1 == rsrTag.reg_id) & rsrTag.valid);
    src2RsrMatch[1] = ((iqPacket_i[1].phySrc2 == rsrTag.reg_id) & rsrTag.valid);
    `endif

    `ifdef DISPATCH_THREE_WIDE
    src1RsrMatch[2] = ((iqPacket_i[2].phySrc1 == rsrTag.reg_id) & rsrTag.valid);
    src2RsrMatch[2] = ((iqPacket_i[2].phySrc2 == rsrTag.reg_id) & rsrTag.valid);
    `endif

    `ifdef DISPATCH_FOUR_WIDE
    src1RsrMatch[3] = ((iqPacket_i[3].phySrc1 == rsrTag.reg_id) & rsrTag.valid);
    src2RsrMatch[3] = ((iqPacket_i[3].phySrc2 == rsrTag.reg_id) & rsrTag.valid);
    `endif

    `ifdef DISPATCH_FIVE_WIDE
    src1RsrMatch[4] = ((iqPacket_i[4].phySrc1 == rsrTag.reg_id) & rsrTag.valid);
    src2RsrMatch[4] = ((iqPacket_i[4].phySrc2 == rsrTag.reg_id) & rsrTag.valid);
    `endif

    `ifdef DISPATCH_SIX_WIDE
    src1RsrMatch[5] = ((iqPacket_i[5].phySrc1 == rsrTag.reg_id) & rsrTag.valid);
    src2RsrMatch[5] = ((iqPacket_i[5].phySrc2 == rsrTag.reg_id) & rsrTag.valid);
    `endif

    `ifdef DISPATCH_SEVEN_WIDE
    src1RsrMatch[6] = ((iqPacket_i[6].phySrc1 == rsrTag.reg_id) & rsrTag.valid);
    src2RsrMatch[6] = ((iqPacket_i[6].phySrc2 == rsrTag.reg_id) & rsrTag.valid);
    `endif

    `ifdef DISPATCH_EIGHT_WIDE
    src1RsrMatch[7] = ((iqPacket_i[7].phySrc1 == rsrTag.reg_id) & rsrTag.valid);
    src2RsrMatch[7] = ((iqPacket_i[7].phySrc2 == rsrTag.reg_id) & rsrTag.valid);
    `endif
end

assign src1RsrMatch_o = src1RsrMatch;
assign src2RsrMatch_o = src2RsrMatch;


/* Put the created packet into the select/payload pipeline register */
`ifdef ISSUE_THREE_DEEP
always_ff @(posedge clk)
begin: SELECT_PAYLOAD_PIPELINE_REGISTER
    int i;

    if (reset | flush_i)
    begin
      grantedEntry                  <= 0;
    end

    else
    begin
      grantedEntry                  <= selectedEntry;
    end
end

`else

always_comb
begin: SELECT_PAYLOAD_PIPELINE

      grantedEntry                  = selectedEntry;
end

`endif


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

/* (2) Create the subset vector for pipe 0 */
reg  [`SIZE_ISSUEQ-1:0]                reqVectFU;

always_comb
begin : REQ_VECT
    int i;

    for (i = 0; i < `SIZE_ISSUEQ; i++)
    begin
      `ifdef AGE_BASED_ORDERING
        // This is not a dynamic MUXins as ageBasedOrdering is constant and should be optimized away by synthesis
        reqVectFU[i] = ageBasedOrdering ? agedReqVect[i] & (!ignoreSimple | !ISsimple[i]) :
                                          reqVect[i] &  (exePipeVect[i] == ISSUE_LANE_ID) & (!ignoreSimple || !ISsimple[i]);
      `else 
        reqVectFU[i] = reqVect[i] &  (exePipeVect[i] == ISSUE_LANE_ID) & (!ignoreSimple || !ISsimple[i]);
      `endif
    end
end

// TODO: Select logic can be optimized for dynamic config
/* (3) Select one instruction for pipe 0 */
Select #(
    .ISSUE_DEPTH       (`SIZE_ISSUEQ),
    .SIZE_SELECT_BLOCK (`SIZE_SELECT_BLOCK)
)

select_inst (

    .clk             (clk),
    .reset           (reset),
    .requestVector_i (reqVectFU),

    .grantedEntryA_o (selectedEntry.id),
    .grantedValidA_o (selectedEntry.valid)
);


/************************************************************************************
 * Write the incoming instruction's physical destination register and 
 * execution pipe assignment.
 ************************************************************************************/
/*
always_ff @(posedge clk or posedge reset)
begin: newInstructions
    int i;

    if (reset)
    begin
        for (i = 0; i < `SIZE_ISSUEQ; i++)
        begin
            phyDestVect[i] <= 0;
            exePipeVect[i] <= 0;
            ISsimple[i]    <= 0;
        end
    end

    else if (flush_i)
    begin
        for (i = 0; i < `SIZE_ISSUEQ; i++)
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
          if(dispatchLaneActive_i[i])
          begin
            // RBRC
            // Added the phyDest valid bit required at a later point
            // to qualify the RSR as only broadcasts from instructions
            // with valid phy dest should wake up dependent instructions
            phyDestVect[freeEntry[i].id] <= {iqPacket_i[i].phyDest,iqPacket_i[i].phyDestValid};
            exePipeVect[freeEntry[i].id] <= iqPacket_i[i].fu;
            ISsimple[freeEntry[i].id]    <= iqPacket_i[i].isSimple;
          end
        end
    end
end
*/



/****************************
 * RSR INSIDE ISSUEQ MODULE *
 ***************************/

always_comb
begin

  grantedDest.reg_id       = phyDestVect[selectedEntry.id].reg_id;
  // RSR
  // Broadcasted RSR tags should not be valid if instruction does not have a valid destination
  grantedDest.valid        = selectedEntry.valid & phyDestVect[selectedEntry.id].valid ;
  ISsimple_t               = ISsimple[selectedEntry.id];
end

localparam COMPLEX_VECT = `COMPLEX_VECT;

RSRLane #(
    .LANE_ID(ISSUE_LANE_ID),
    .FU_LATENCY(COMPLEX_VECT[ISSUE_LANE_ID] ? `FU1_LATENCY : 1)
   )
rsr(

    .clk              (clk),
    .reset            (reset | flush_i),

    .ISsimple_i       (ISsimple_t),
    .grantedDest_i    (grantedDest),
    .rsrTag_o         (rsrTag_t),
    .ignoreSimple_o   (ignoreSimple)
);

/* rsrTag contain the producer tags for wake-up */
always_comb
begin
    rsrTag.valid  = rsrTag_t.valid;
    rsrTag.reg_id = rsrTag_t.valid ? rsrTag_t.reg_id : 0;

    `ifndef LD_SPECULATIVELY_WAKES_DEPENDENT
      if(ISSUE_LANE_ID == 0)
      begin
        rsrTag = rsr0Tag_i; // Override with rstTag from LSU
      end
    `endif
end


endmodule
