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

  Assumption:  8-instructions can be issued and
  4(?)-instructions will retire in one cycle from Active List.

There are 8 ways and upto 8 issue queue entries
can be freed in a clock cycle.

***************************************************************************/

module AgeOrdering(
	input                           clk,
	input                           reset,
  input [`SIZE_ISSUEQ_LOG:0]      iqSize_i,
  input                           flush_i,

	input                           dispatchReady_i,

  input [`SIZE_ACTIVELIST_LOG-1:0]alHead_i,
  input [`SIZE_ACTIVELIST_LOG-1:0]alTail_i,
  input [`SIZE_ACTIVELIST_LOG-1:0]alID_i [0:`DISPATCH_WIDTH-1],

	/* Free Issue Queue entries for the incoming instructions. */
	input iqEntryPkt                freeEntry_i    [0:`DISPATCH_WIDTH-1],
  input iqPkt                     iqPacket_i [0:`DISPATCH_WIDTH-1],
  input iqEntryPkt                freedEntry_i     [0:`ISSUE_WIDTH-1],
  input payloadPkt                rrPacket_i [0:`ISSUE_WIDTH-1],

  input [`SIZE_ISSUEQ-1:0]        requestVector_i,


  // Variable in case of DYNAMIC_CONFIG - `DISPATCH_WIDTH otherwise
`ifdef DYNAMIC_CONFIG
  input [`DISPATCH_WIDTH-1:0]     dispatchLaneActive_i,
  input [`ISSUE_WIDTH-1:0]        issueLaneActive_i,
  input [`NUM_PARTS_IQ-1:0]       iqPartitionActive_i,
`endif  

  output reg [`SIZE_ISSUEQ-1:0]   agedReqVector_o [0:`ISSUE_WIDTH-1]


	);


//`ifdef SIM
// synopsys translate_off

logic [`SIZE_ISSUEQ_LOG-1:0]  iqEntryVect   [`SIZE_ACTIVELIST-1:0];
logic                         iqEntryValid  [`SIZE_ACTIVELIST-1:0];
logic [`ISSUE_WIDTH_LOG-1:0]  fuTypeVect    [`SIZE_ACTIVELIST-1:0];

logic                         predLdVio     [`SIZE_ISSUEQ-1:0];

always_ff @(posedge clk or posedge reset)
begin
  int i;
  if(reset)
  begin
    for(i = 0; i < `SIZE_ACTIVELIST; i++)
    begin
      iqEntryVect[i] <=  {`SIZE_ISSUEQ_LOG{1'b0}};
      fuTypeVect[i]  <=  {`ISSUE_WIDTH_LOG{1'b0}};
      iqEntryValid[i] <=  1'b0;
    end
    for(i = 0; i < `SIZE_ISSUEQ; i++)
    begin
      predLdVio[i] <=  1'b0;
    end
  end
  else
//    if(flush)
//    begin
//      for(i = 0; i < `SIZE_ACTIVE_LIST; i++)
//      begin
//        iqEntryVect <=  {`SIZE_ISSUEQ_LOG{1'b0}};
//        fuTypeVect  <=  {`ISSUE_WIDTH_LOG{1'b0}};
//      end
//    end
//    else
    begin
      if(dispatchReady_i)
      begin
        iqEntryVect[alID_i[0]]  <=  freeEntry_i[0].id;
        fuTypeVect[alID_i[0]]   <=  iqPacket_i[0].fu;
        iqEntryValid[alID_i[0]] <=  1'b1;
        predLdVio[freeEntry_i[0].id]  <=  iqPacket_i[0].predLoadVio & iqPacket_i[0].isLoad;
      end
  
      `ifdef DISPATCH_TWO_WIDE
      if(dispatchReady_i)
      begin
        iqEntryVect[alID_i[1]]  <=  freeEntry_i[1].id;
        fuTypeVect[alID_i[1]]   <=  iqPacket_i[1].fu;
        iqEntryValid[alID_i[1]] <=  1'b1;
        predLdVio[freeEntry_i[1].id]  <=  iqPacket_i[1].predLoadVio & iqPacket_i[1].isLoad;
      end
      `endif
  
      `ifdef DISPATCH_THREE_WIDE
      if(dispatchReady_i)
      begin
        iqEntryVect[alID_i[2]]  <=  freeEntry_i[2].id;
        fuTypeVect[alID_i[2]]   <=  iqPacket_i[2].fu;
        iqEntryValid[alID_i[2]] <=  1'b1;
        predLdVio[freeEntry_i[2].id]  <=  iqPacket_i[2].predLoadVio & iqPacket_i[2].isLoad;
      end
      `endif
  
      `ifdef DISPATCH_FOUR_WIDE
      if(dispatchReady_i)
      begin
        iqEntryVect[alID_i[3]]  <=  freeEntry_i[3].id;
        fuTypeVect[alID_i[3]]   <=  iqPacket_i[3].fu;
        iqEntryValid[alID_i[3]] <=  1'b1;
        predLdVio[freeEntry_i[3].id]  <=  iqPacket_i[3].predLoadVio & iqPacket_i[3].isLoad;
      end
      `endif

      if(rrPacket_i[0].valid)
        iqEntryValid[rrPacket_i[0].alID] <=  1'b0;

      `ifdef ISSUE_TWO_WIDE
      if(rrPacket_i[1].valid)
        iqEntryValid[rrPacket_i[1].alID] <=  1'b0;
      `endif

      `ifdef ISSUE_THREE_WIDE
      if(rrPacket_i[2].valid)
        iqEntryValid[rrPacket_i[2].alID] <=  1'b0;
      `endif

      `ifdef ISSUE_FOUR_WIDE
      if(rrPacket_i[3].valid)
        iqEntryValid[rrPacket_i[3].alID] <=  1'b0;
      `endif

      `ifdef ISSUE_FIVE_WIDE
      if(rrPacket_i[4].valid)
        iqEntryValid[rrPacket_i[4].alID] <=  1'b0;
      `endif
    end
//  end
end

genvar lane;
generate
for(lane = 0; lane < `ISSUE_WIDTH; lane++)
begin:ORDERING
  always_comb
  begin
    logic [`SIZE_ACTIVELIST_LOG:0]  alPtr;
    logic [`SIZE_ISSUEQ_LOG-1:0]    iqEntry;
    logic [`ISSUE_WIDTH_LOG-1:0]    fuType; 
    logic                           entryValid;
    logic                           ldVio;
  
    agedReqVector_o[lane] = 0;
    alPtr           = {1'b0,alHead_i}; // Need 1 bit filling at MCB since longer than alHead size
  
  	for (int i = 0; i < `SIZE_ACTIVELIST; i++)
  	begin
      iqEntry = iqEntryVect[alPtr];
      fuType  = fuTypeVect[alPtr];
      entryValid = iqEntryValid[alPtr];
      `ifdef LD_STALL_AT_ISSUE
        ldVio   = (i > 16); // Issue a load only if within top 16 AL entries
      `else
        // Issue a violating load only if within top 16 AL entries
        // Other loads are free to issue whenever
        ldVio   = predLdVio[iqEntry] & (i > 16); 
      `endif
  
      if(requestVector_i[iqEntry] & (fuType == lane) & entryValid & ~ldVio)
      begin
        agedReqVector_o[lane][iqEntry] = 1'b1;
        break;
      end

      alPtr++;
      if(alPtr >= `SIZE_ACTIVELIST)
        alPtr = 0;
  
      if (alPtr == alTail_i)
        break;
  	end
  end
end
endgenerate

// synopsys translate_on
//`else
//    always_comb
//    begin
//      int lane;
//      logic [`SIZE_ISSUEQ_LOG-1:0]  iqPtr;
//
//
//      for(lane = 0; lane < `ISSUE_WIDTH; lane++)
//      begin
//        iqPtr = (alHead_i+freedEntry_i[lane].id);
//
//        agedReqVector_o[lane] = 0;
//        if(dispatchReady_i &  requestVector_i[iqPtr])
//        begin
//          agedReqVector_o[lane] = requestVector_i;
//        end
//      end
//    end
//
//`endif
endmodule
