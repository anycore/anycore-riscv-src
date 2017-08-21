/*************************NORTH CAROLINA STATE UNIVERSITY***********************
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

module STX_path (
	input                                 clk,
	input                                 reset,

	input                                 recoverFlag_i,
	input                                 backEndReady_i,
	
	/* From Dispatch stage */
	input  lsqPkt                         lsqPacket_i [0:`DISPATCH_WIDTH-1],

	/* Either from AGEN or the replay Packet */
	//input  memPkt                         memPacket_i,
	input  memPkt                         ldPacket_i,
	input  memPkt                         stPacket_i,

	/* Indicates that a load has received data from D$ or STQ */
	input                                 loadDataValid_i,

	input  [`SIZE_LSQ_LOG-1:0]            ldqHead_i,
	input  [`SIZE_LSQ_LOG-1:0]            ldqHead_t_i,
	input  [`SIZE_LSQ_LOG-1:0]            ldqHeadPlusOne_i,
	input  [`SIZE_LSQ_LOG-1:0]            ldqTail_i,
	input  [`SIZE_LSQ_LOG:0]              ldqCount_i,

	/* lsqIDs of each dispatched load instruction. Non-loads will be 0 */
	input  [`SIZE_LSQ_LOG-1:0]            ldqID_i         [0:`DISPATCH_WIDTH-1],

	/* lsqIDs of each dispatched store instruction. Non-stores will be 0 */
	input  [`SIZE_LSQ_LOG-1:0]            stqID_i         [0:`DISPATCH_WIDTH-1],

	/* The ldqID of the next load for each store being dispatched */
	input  [`SIZE_LSQ_LOG-1:0]            nextLd_i        [0:`DISPATCH_WIDTH-1],

	/* Count of load instructions being committed */
	input  [`COMMIT_WIDTH_LOG:0]          commitLdCount_i,

	/* lsqIDs of the committing loads */
	input  [`SIZE_LSQ_LOG-1:0]            commitLdIndex_i [0:`COMMIT_WIDTH-1],

	/* Load to replay next */
	output memPkt                         replayPacket_o,

	/* Load violation packet */
	output ldVioPkt                       stxVioPacket_o
);


reg [`SIZE_EXE_FLAGS-1:0]                       ldqFlags     [0:`SIZE_LSQ-1]; /* Part of Store Queue */ 
reg [`SIZE_PHYSICAL_LOG-1:0]                     ldqPhyDest   [0:`SIZE_LSQ-1]; /* Part of Store Queue */  
reg [`SIZE_ACTIVELIST_LOG-1:0]                   ldqALid      [0:`SIZE_LSQ-1]; /* Part of Store Queue */  
reg [`LDST_TYPES_LOG-1:0]                        ldqSize      [0:`SIZE_LSQ-1]; /* Part of Store Queue */  
reg [`SIZE_VIRT_ADDR-1:`SIZE_DATA_BYTE_OFFSET] ldqAddr1     [0:`SIZE_LSQ-1]; /* Part of Store Queue */  
reg [`SIZE_DATA_BYTE_OFFSET-1:0]                 ldqAddr2     [0:`SIZE_LSQ-1]; /* Part of Store Queue */  
reg [`SIZE_LSQ-1:0]                              ldqAddrValid;                 /* Part of Store Queue */   
reg [`SIZE_LSQ-1:0]                              ldqWriteBack;                 /* Part of Store Queue */   
reg [`SIZE_LSQ_LOG-1:0]                          followingLD  [0:`SIZE_LSQ-1]; /* Part of Store Queue */       

`ifdef SIM
// Used only during simulation and debugging
reg [`SIZE_PC-1:0]                               ldqPC        [0:`SIZE_LSQ-1]; /* Part of Store Queue */ 
reg [31:0]                                       ldqSeq       [0:`SIZE_LSQ-1]; /* Part of Store Queue */ 
`endif

exeFlgs                                 ldPacket_flags;
exeFlgs                                 stPacket_flags;

assign ldPacket_flags                 = ldPacket_i.flags;
assign stPacket_flags                 = stPacket_i.flags;


reg [`COMMIT_WIDTH-1:0]                 commitLdCount_vec;

reg [`SIZE_ACTIVELIST_LOG-1:0]          violateLdALid;
reg                                     violateLdValid;
`ifdef SIM
reg [31:0]                              violateLdSeqNo;
`endif

logic  [`SIZE_LSQ_LOG-1:0]                replayLSQId;
reg                                     replayLdValid;
reg                                     ld_replay_valid;
reg                                     ld_already_hit;

`ifdef SIM
assign stxVioPacket_o.seqNo           = violateLdSeqNo;
`else
assign stxVioPacket_o.seqNo           = {32{1'bx}};
`endif
assign stxVioPacket_o.alID            = violateLdALid;
assign stxVioPacket_o.valid           = violateLdValid; 


/* Create a replay load packet which will be executed if no instruction packet */
/*  is sent to this unit by the agen in any cycle. This packet is created from */
/*  the load that was stalled earlier (during disambiguation check) and is now */
/*  at the head of load queue                                                  */
`ifndef REPLAY_TWO_DEEP
  always_comb
  begin:CREATE_REPLAY_PKT
  
  	replayPacket_o  = 0;
  	replayLdValid   = 1'h0;
  
    // BUG: Replaying just from head creates a deadlock in case of a split dlw
    // Must replay from next slot if the head entry has already completed.
    // This is a problem because in a split instruction, head Ld never commits
    // unless the next load is also complete but the next load never replays because
    // the head load never commits.
    //replayLSQId     = ldqWriteBack[ldqHead_i] ? ldqHeadPlusOne_i :  ldqHead_i;
    replayLSQId     = ldqHead_i;
  
  //  if(ldqWriteBack[replayLSQId])
  //  begin
  //    replayLSQId = ldqHead_i + 1'b1;
  //    // Wrap around for arbitrary LSQ sizes
  //    if(replayLSQId == `SIZE_LSQ) 
  //      replayLSQId = 'h0; 
  //  end
  
  	if (ldqAddrValid[replayLSQId] && !ldqWriteBack[replayLSQId])
  	begin
  		replayLdValid = 1'h1;
  	end
  
  	replayPacket_o  = 0;
  
  	replayPacket_o.flags    = ldqFlags[replayLSQId];
  	replayPacket_o.phyDest  = ldqPhyDest[replayLSQId];
  	replayPacket_o.alID     = ldqALid[replayLSQId];
  	replayPacket_o.ldstSize = ldqSize[replayLSQId];
  	replayPacket_o.lsqID    = replayLSQId;
  	replayPacket_o.address  = {ldqAddr1[replayLSQId], ldqAddr2[replayLSQId]};
  	replayPacket_o.valid    = replayLdValid;
  `ifdef SIM
    replayPacket_o.pc       = ldqPC[replayLSQId];
    replayPacket_o.seqNo    = ldqSeq[replayLSQId];
  `endif
  end

`else //REPLAY_TWO_DEEP

  assign replayLSQId     = ldqHead_t_i;

  always_ff @(posedge clk or posedge reset)
  begin
    if(reset)
    begin
  
    	replayPacket_o.flags    <= 0; 
    	replayPacket_o.phyDest  <= 0; 
    	replayPacket_o.alID     <= 0; 
    	replayPacket_o.ldstSize <= 0; 
    	replayPacket_o.lsqID    <= 0; 
    	replayPacket_o.address  <= 0; 
    `ifdef SIM
      replayPacket_o.pc       <= 0; 
    `endif
    end
    else
    begin
  
    	replayPacket_o.flags    <= ldqFlags[replayLSQId];
    	replayPacket_o.phyDest  <= ldqPhyDest[replayLSQId];
    	replayPacket_o.alID     <= ldqALid[replayLSQId];
    	replayPacket_o.ldstSize <= ldqSize[replayLSQId];
    	replayPacket_o.lsqID    <= replayLSQId;
    	replayPacket_o.address  <= {ldqAddr1[replayLSQId], ldqAddr2[replayLSQId]};
    `ifdef SIM
      replayPacket_o.pc       <= ldqPC[replayLSQId];
      replayPacket_o.seqNo    <= ldqSeq[replayLSQId];
    `endif
  
    end
  end
  
  always_ff @(posedge clk or posedge reset)
  begin
    if(reset)
    begin
      ld_replay_valid         <= 1'b0;
      ld_already_hit          <= 1'b0;
    end
    else
    begin
      if(recoverFlag_i)
      begin
        ld_replay_valid         <= 1'b0;
        ld_already_hit          <= 1'b0;
      end
      else
      begin
        if (ldqAddrValid[replayLSQId] && !ldqWriteBack[replayLSQId])
          ld_replay_valid       <= 1'b1;
        else
          ld_replay_valid       <= 1'b0;

        ld_already_hit          <= (ldPacket_i.lsqID == replayLSQId) & ldPacket_i.valid & loadDataValid_i; 
      end
    end
  end

  always_comb
  begin
    replayPacket_o.valid    = ld_replay_valid & ~ld_already_hit;
  end

  //always_comb
  //begin
  //  if (ldqAddrValid[replayPacket_o.lsqID] && !ldqWriteBack[replayPacket_o.lsqID])
  //    replayPacket_o.valid    = 1'b1;
  //  else
  //    replayPacket_o.valid    = 1'b0;
  //end


`endif //REPLAY_TWO_DEEP

/* Load violation detection logic
 * (1): Find all loads in the vulnerability window. These are loads younger than
 *      the store.
 * (2): Find all loads that access the same byte-addresses.
 * (3): AND the vectors from (1) and (2) with the valid and executed vectors to
 *      get a vector of all loads that violated.
 * (4): Find the youngest load that violated and mark it in the AL. 
 */

always_comb
begin:LD_VIOLATION
	int i;
	reg [`SIZE_LSQ-1:0]                     matchVector_st;
	reg [`SIZE_LSQ-1:0]                     matchVector_st1;
	reg [`SIZE_LSQ-1:0]                     matchVector_st2;
	reg [`SIZE_LSQ-1:0]                     matchVector_st3;
	reg [`SIZE_LSQ-1:0]                     vulnerableLdVector_t1;
	reg [`SIZE_LSQ-1:0]                     vulnerableLdVector_t2;
	reg [`SIZE_LSQ-1:0]                     vulnerableLdVector_t3;
	reg [`SIZE_LSQ-1:0]                     vulnerableLdVector_t4;
	reg [`SIZE_LSQ-1:0]                     violateVector;
	reg                                     agenLdqMatch;
	reg [`SIZE_LSQ_LOG-1:0]                 firstMatch;
	reg [`SIZE_LSQ_LOG-1:0]                 nextLoad;
	reg [`SIZE_LSQ_LOG-1:0]                 index;
	reg                                     ldqWrap;
	reg [`LDST_TYPES_LOG-1:0]               maxsize;

  //Default to avoid latch
  //RBRC: 07/12/2013
  index = {`SIZE_LSQ_LOG{1'b0}};

	/* Get the index of the 1st load younger than this store */
	nextLoad              = followingLD[stPacket_i.lsqID];

	/* Know whether the LDQ wraps or not */
	ldqWrap               = (ldqTail_i < nextLoad);


	/* (1): Find all loads in the vulnerability window. These are loads younger
	 *      than the store.
	 * vulnerableLdVector: Loads between nextLoad and ldqTail. These are vulnerable
	 * to have violated. 
	 * t1: vector when the LDQ doesn't wrap.
	 * t2: vector when the LDQ wraps. */
	for (i = 0; i < `SIZE_LSQ; i = i + 1)
	begin
		if ((i >= nextLoad ) && (i < ldqTail_i))
		begin
			vulnerableLdVector_t1[i] = 1'b1;
		end

		else
		begin
			vulnerableLdVector_t1[i] = 1'b0;
		end

		if ((i >= nextLoad) || (i < ldqTail_i))
		begin
			vulnerableLdVector_t2[i] = 1'b1;
		end

		else
		begin
			vulnerableLdVector_t2[i] = 1'b0;
		end
	end

	if (ldqWrap)
	begin
		vulnerableLdVector_t3  = vulnerableLdVector_t2;
	end

	else
	begin
		vulnerableLdVector_t3  = vulnerableLdVector_t1;
	end


	if ((ldqTail_i == nextLoad) && (ldqHead_i == nextLoad) && (ldqCount_i > 0))
	begin

		for (i = 0; i < `SIZE_LSQ; i = i + 1)
		begin
			vulnerableLdVector_t4[i] = 1'h1;
		end
	end

	else
	begin
		vulnerableLdVector_t4 = vulnerableLdVector_t3;
	end

	/* (2): Find all loads that access the same byte-addresses. */ 
	for (i = 0; i < `SIZE_LSQ; i = i + 1)
	begin
		matchVector_st1[i]= (stPacket_i.address[`SIZE_VIRT_ADDR-1:`SIZE_DATA_BYTE_OFFSET] == ldqAddr1[i]);

		/* TODO: Test the cycle time/IPC implications of causing a violation whenever a
		 * load and store access the same word. Don't check sizes and byte offsets
		 * (i.e., the following logic in this for loop can be removed).
		 */ 
		matchVector_st2[i]= (stPacket_i.address[1] == ldqAddr2[i][1]);
		matchVector_st3[i]= (stPacket_i.address[0] == ldqAddr2[i][0]);

		if (stPacket_i.ldstSize > ldqSize[i])
		begin
			maxsize = stPacket_i.ldstSize;
		end

		else
		begin
			maxsize = ldqSize[i];
		end

		/* CAM read port for ldqSize */
		if (maxsize == `LDST_BYTE)
		begin
			matchVector_st[i] = matchVector_st1[i] & matchVector_st2[i] & matchVector_st3[i];
		end

		else if (maxsize == `LDST_HALF_WORD)
		begin
			matchVector_st[i] = matchVector_st1[i] & matchVector_st2[i];
		end

		else
		begin
			matchVector_st[i] = matchVector_st1[i];
		end
	end


	/* (3): AND the vectors from (1) and (2) with the valid and executed vectors
	 *      to get a vector of all loads that violated. */
	violateVector         = ldqAddrValid & ldqWriteBack & vulnerableLdVector_t4 & matchVector_st;


	/* (4): Find the youngest load that violated and mark it in the AL. */
	agenLdqMatch        = 0;
	firstMatch          = 0;
	violateLdValid      = 0;
	violateLdALid       = 0;
`ifdef SIM
  violateLdSeqNo      = 0;
`endif

	/* TODO: Test w/o 'if (agenStore)' */
	if (stPacket_i.valid && ~stPacket_flags.destValid)
	begin
		for (i = 0; i < `SIZE_LSQ; i = i + 1)
		begin
      // RBRC: Sept 2, 2013 - Needs an explicit wrap around
      // logic to support arbitrary sizes.
			index = nextLoad + i;
      if(index >= `SIZE_LSQ)
        index = index - `SIZE_LSQ;

			if (violateVector[index] & ~agenLdqMatch)
			begin
				agenLdqMatch    = 1'h1;
				firstMatch      = index;
			end
		end

		if (agenLdqMatch)
		begin
			violateLdValid          = 1'h1;
			violateLdALid           = ldqALid[firstMatch];
    `ifdef SIM
      violateLdSeqNo          = ldqSeq[firstMatch];
    `endif
		end
	end
end


always_comb
begin
	case (commitLdCount_i)
		3'h1    : commitLdCount_vec = 4'b0001;
`ifdef COMMIT_TWO_WIDE    
		3'h2    : commitLdCount_vec = 4'b0011;
`endif    
`ifdef COMMIT_THREE_WIDE
		3'h3    : commitLdCount_vec = 4'b0111;
`endif    
`ifdef COMMIT_FOUR_WIDE
		3'h4    : commitLdCount_vec = 4'b1111;
`endif    
		default : commitLdCount_vec = 4'b0000;
	endcase
end


/* Loads update their payload :
 * ldqAdress
 * Size of Load
 * ldqAddrValid
 * ldqWriteback
 * ldq (contains AL ID, IQ ID etc.) 
 */
always_ff @(posedge clk or posedge reset)
begin:LDQ_UPDATE
	integer i;
	integer l;

	if (reset)
	begin
		ldqAddrValid      <= 0;
		ldqWriteBack      <= 0;

		/* TODO: Test without clearing these on a recovery */
		for (i = 0; i < `SIZE_LSQ; i = i + 1)
		begin
			ldqFlags[i]     <= 0;
			ldqPhyDest[i]   <= 0;
			ldqALid[i]      <= 0;
			ldqSize[i]      <= 0;
			ldqAddr1[i]     <= 0;
			ldqAddr2[i]     <= 0;
`ifdef SIM      
      ldqPC[i]        <= 0;
      ldqSeq[i]       <= 0;
`endif      
		end
	end

	else if (recoverFlag_i)
	begin
		ldqAddrValid      <= 0;
		ldqWriteBack      <= 0;

		/* TODO: Test without clearing these on a recovery */
		for (i = 0; i < `SIZE_LSQ; i = i + 1)
		begin
			ldqFlags[i]     <= 0;
			ldqPhyDest[i]   <= 0;
			ldqALid[i]      <= 0;
			ldqSize[i]      <= 0;
			ldqAddr1[i]     <= 0;
			ldqAddr2[i]     <= 0;
`ifdef SIM      
      ldqPC[i]        <= 0;
      ldqSeq[i]       <= 0;
`endif      
		end
	end
	else 
	begin

		/* update during execute - either a new load or a replayed load */
		if (ldPacket_i.valid && ldPacket_flags.destValid)
		begin
			ldqFlags[ldPacket_i.lsqID]                   <=  ldPacket_i.flags;
			ldqPhyDest[ldPacket_i.lsqID]                 <=  ldPacket_i.phyDest;
			ldqALid[ldPacket_i.lsqID]                    <=  ldPacket_i.alID;
			ldqSize[ldPacket_i.lsqID]                    <=  ldPacket_i.ldstSize;
			ldqAddrValid[ldPacket_i.lsqID]               <=  1'h1;
			ldqAddr1[ldPacket_i.lsqID]                   <=  ldPacket_i.address[`SIZE_VIRT_ADDR-1:`SIZE_DATA_BYTE_OFFSET];
			ldqAddr2[ldPacket_i.lsqID]                   <=  ldPacket_i.address[`SIZE_DATA_BYTE_OFFSET-1:0];
`ifdef SIM
			ldqPC[ldPacket_i.lsqID]                      <=  ldPacket_i.pc;
			ldqSeq[ldPacket_i.lsqID]                     <=  ldPacket_i.seqNo;
`endif

			/* Following updates the WriteBack bit for LDQ, if the result is broadcasted 
			 * this cycle and writen back to Active List.
			 */
			ldqWriteBack[ldPacket_i.lsqID]               <= loadDataValid_i;
		end

		if (backEndReady_i)
		begin
			/* TODO: These two vectors are cleared when (1) a load is dispatched and
			 * (2) when the load commits. In the normal case, the bit should already
			 * be cleared when the load is dispatched so (1) is probably for loads
			 * that executed but were squashed by a misprediction. However, we already
			 * clear the entire vectors on a recovery. Test without either (1) or
			 * the clearing of the vectors on a recovery. */
			if (lsqPacket_i[0].isLoad)
			begin
				ldqAddrValid[ldqID_i[0]]   <= 1'h0;
				ldqWriteBack[ldqID_i[0]]   <= 1'h0;
			end

`ifdef DISPATCH_TWO_WIDE
			if (lsqPacket_i[1].isLoad)
			begin
				ldqAddrValid[ldqID_i[1]]   <= 1'h0;
				ldqWriteBack[ldqID_i[1]]   <= 1'h0;
			end
`endif

`ifdef DISPATCH_THREE_WIDE
			if (lsqPacket_i[2].isLoad)
			begin
				ldqAddrValid[ldqID_i[2]]   <= 1'h0;
				ldqWriteBack[ldqID_i[2]]   <= 1'h0;
			end
`endif

`ifdef DISPATCH_FOUR_WIDE
			if (lsqPacket_i[3].isLoad)
			begin
				ldqAddrValid[ldqID_i[3]]   <= 1'h0;
				ldqWriteBack[ldqID_i[3]]   <= 1'h0;
			end
`endif

`ifdef DISPATCH_FIVE_WIDE
			if (lsqPacket_i[4].isLoad)
			begin
				ldqAddrValid[ldqID_i[4]]   <= 1'h0;
				ldqWriteBack[ldqID_i[4]]   <= 1'h0;
			end
`endif

`ifdef DISPATCH_SIX_WIDE
			if (lsqPacket_i[5].isLoad)
			begin
				ldqAddrValid[ldqID_i[5]]   <= 1'h0;
				ldqWriteBack[ldqID_i[5]]   <= 1'h0;
			end
`endif

`ifdef DISPATCH_SEVEN_WIDE
			if (lsqPacket_i[6].isLoad)
			begin
				ldqAddrValid[ldqID_i[6]]   <= 1'h0;
				ldqWriteBack[ldqID_i[6]]   <= 1'h0;
			end
`endif

`ifdef DISPATCH_EIGHT_WIDE
			if (lsqPacket_i[7].isLoad)
			begin
				ldqAddrValid[ldqID_i[7]]   <= 1'h0;
				ldqWriteBack[ldqID_i[7]]   <= 1'h0;
			end
`endif

			/* update at retire */
			if (commitLdCount_vec[0])
			begin
				ldqAddrValid[commitLdIndex_i[0]]       <= 1'h0;
				ldqWriteBack[commitLdIndex_i[0]]       <= 1'h0;
			end

`ifdef COMMIT_TWO_WIDE      
			if (commitLdCount_vec[1])
			begin
				ldqAddrValid[commitLdIndex_i[1]]       <= 1'h0;
				ldqWriteBack[commitLdIndex_i[1]]       <= 1'h0;
			end
`endif      

`ifdef COMMIT_THREE_WIDE
			if (commitLdCount_vec[2])
			begin
				ldqAddrValid[commitLdIndex_i[2]]       <= 1'h0;
				ldqWriteBack[commitLdIndex_i[2]]       <= 1'h0;
			end
`endif      

`ifdef COMMIT_FOUR_WIDE
			if (commitLdCount_vec[3])
			begin
				ldqAddrValid[commitLdIndex_i[3]]       <= 1'h0;
				ldqWriteBack[commitLdIndex_i[3]]       <= 1'h0;
			end
`endif      

		end
	end
end


/* Store execution path also contains FollowingLd structure, which contains the 
 * following load for the various store enteries. It is a part of stqpayload 
 * and placed here as it is also a part of st execution. */
always_ff @(posedge clk or posedge reset)
begin:STQ_UPDATE
	integer i;

	if (reset)
	begin
		/* TODO: Test without clearing during a recovery */
		for (i = 0; i < `SIZE_LSQ; i = i + 1)
		begin
			followingLD[i] <= 0;
		end
	end

	else if (recoverFlag_i)
	begin
		/* TODO: Test without clearing during a recovery */
		for (i = 0; i < `SIZE_LSQ; i = i + 1)
		begin
			followingLD[i] <= 0;
		end
	end
	else 
	begin

		/* update at dispatch */
		if (backEndReady_i)
		begin
			if (lsqPacket_i[0].isStore)
			begin
				followingLD[stqID_i[0]]   <= nextLd_i[0];
			end

`ifdef DISPATCH_TWO_WIDE
			if (lsqPacket_i[1].isStore)
			begin
				followingLD[stqID_i[1]]   <= nextLd_i[1];
			end
`endif

`ifdef DISPATCH_THREE_WIDE
			if (lsqPacket_i[2].isStore)
			begin
				followingLD[stqID_i[2]]   <= nextLd_i[2];
			end
`endif

`ifdef DISPATCH_FOUR_WIDE
			if (lsqPacket_i[3].isStore)
			begin
				followingLD[stqID_i[3]]   <= nextLd_i[3];
			end
`endif

`ifdef DISPATCH_FIVE_WIDE
			if (lsqPacket_i[4].isStore)
			begin
				followingLD[stqID_i[4]]   <= nextLd_i[4];
			end
`endif

`ifdef DISPATCH_SIX_WIDE
			if (lsqPacket_i[5].isStore)
			begin
				followingLD[stqID_i[5]]   <= nextLd_i[5];
			end
`endif

`ifdef DISPATCH_SEVEN_WIDE
			if (lsqPacket_i[6].isStore)
			begin
				followingLD[stqID_i[6]]   <= nextLd_i[6];
			end
`endif

`ifdef DISPATCH_EIGHT_WIDE
			if (lsqPacket_i[7].isStore)
			begin
				followingLD[stqID_i[7]]   <= nextLd_i[7];
			end
`endif

		end
	end
end

endmodule
