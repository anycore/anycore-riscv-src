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

module CtrlQueue(

	input                            clk,
	input                            reset,
	input                            resetRams_i,

	input                            stall_i,
	input                            recoverFlag_i,
	input                            exceptionFlag_i,

	input                            fs1Ready_i,

  // This should already  have taken into account the fetchLaneActive signals
  // Nothing required here
	input  [`FETCH_WIDTH-1:0]        ctrlVect_i,
	input  [1:0]                     predCounter_i [0:`FETCH_WIDTH-1],

	output [`SIZE_CTI_LOG-1:0]       ctiID_o    [0:`FETCH_WIDTH-1],

	input  [`SIZE_PC-1:0]            exeCtrlPC_i,
	input  [`BRANCH_TYPE_LOG-1:0]        exeCtrlType_i,
	input  [`SIZE_CTI_LOG-1:0]       exeCtiID_i,
	input  [`SIZE_PC-1:0]            exeCtrlNPC_i,
	input                            exeCtrlDir_i,
	input                            exeCtrlValid_i,

  // This should already  have taken into account the commitLaneActive signals
  // Nothing required here
	input  [`COMMIT_WIDTH-1:0]       commitCti_i,

	output [`SIZE_PC-1:0]            updatePC_o,
	output [`SIZE_PC-1:0]            updateNPC_o,
	output [`BRANCH_TYPE_LOG-1:0]    updateCtrlType_o,
	output                           updateDir_o,
	output [1:0]                     updateCounter_o,
	output                           updateEn_o,
`ifdef USE_GSHARE_BPU
	input  [`SIZE_CNT_TBL_LOG-1:0]   predIndex_i [0:`FETCH_WIDTH-1],
  output [`SIZE_CNT_TBL_LOG-1:0]   updateIndex_o,
`endif  

	output                           ctiQueueFull_o,
  output                           ctiqRamReady_o
	);



/* Signals to update the BTB/BP when a control instruction commits */
reg  [`SIZE_CTI_LOG:0]                  queueCount;
wire                                    commit;
wire [`SIZE_PC-1:0]                     updatePC;
wire [`SIZE_PC-1:0]                     updateNPC;
wire [`BRANCH_TYPE_LOG-1:0]                 updateCtrlType;
wire [1:0]                              updateCounter;
wire [`SIZE_CNT_TBL_LOG-1:0]            updateIndex;
wire                                    updateDir;
wire                                    updateEn;

assign updatePC_o                     = updatePC;
assign updateNPC_o                    = updateNPC;
assign updateCtrlType_o               = updateCtrlType;
assign updateDir_o                    = updateDir;
assign updateCounter_o                = updateCounter;
assign updateIndex_o                  = updateIndex;
assign updateEn                       = commit & |queueCount & ~recoverFlag_i;
assign updateEn_o                     = updateEn;


/* Update the head and commit Pointers.
 * headPtr: next entry that needs to update the BTB/BP. Advances up to 1/cycle
 * commitPtr: oldest non-committed entry. Advances up to `COMMIT_WIDTH/cycle */
reg  [`SIZE_CTI_LOG-1:0]                headPtr;
reg  [`SIZE_CTI_LOG-1:0]                commitPtr;
reg  [`SIZE_CTI_LOG-1:0]                commitPtr_next;

/* Count of committing control instructions */
reg  [`COMMIT_WIDTH_LOG:0]              commitCnt;

always_comb
begin
    commitPtr_next      = commitPtr + commitCnt;
end

always_ff @(posedge clk or posedge reset)
begin
	/* if (reset | exceptionFlag_i) */
	if (reset)
	begin
		headPtr         <= 0;
		commitPtr       <= 0;
	end

	else
	begin
		if (updateEn)
		begin
			headPtr       <= headPtr + 1'b1;
		end

		commitPtr       <= commitPtr_next;
	end
end


/* Update the tail pointer. This is used for assigning ctiIDs */
reg  [`SIZE_CTI_LOG-1:0]                tailPtr;

wire                                    ctiQueueFull;


reg  [`SIZE_CTI_LOG-1:0]                tailPtr_next;
always_comb
begin
	int i;
	tailPtr_next = tailPtr;

	for (i = 0; i < `FETCH_WIDTH; i++)
	begin
		tailPtr_next = tailPtr_next + ctrlVect_i[i];
	end
end


always_ff @(posedge clk or posedge reset)
begin : UPDATE_TAILPTR

	/* if (reset || exceptionFlag_i) */
	if (reset)
	begin
		tailPtr      <= 0;
	end

	else
	begin
		if (recoverFlag_i || exceptionFlag_i)
		begin
      // bhdwiel: We could be committing a CTI instruction
			tailPtr    <= commitPtr + commitCnt;
		end

		else
		begin
			if (fs1Ready_i && ~stall_i && ~ctiQueueFull)
			begin
				tailPtr  <= tailPtr_next;
			end
		end
	end
end



/* Calculate the counts */

/* Count of incoming control instructions */
reg  [`FETCH_WIDTH_LOG:0]               ctrlCount;

/* Count of valid entries in the CTI queue */
reg  [`SIZE_CTI_LOG:0]                  queueCount_next;
reg  [`SIZE_CTI_LOG:0]                  queueCount_recover;

always_comb
begin : QUEUE_COUNT
	int i;
	reg  [`FETCH_WIDTH_LOG:0]             queueCount_t0;
	reg                                   queueCount_t1;

	/* Commit Count */
	commitCnt      = 0;

	for (i = 0; i < `COMMIT_WIDTH; i++)
	begin
		commitCnt    = commitCnt + commitCti_i[i];
	end

	/* Control Count */
	ctrlCount  = 0;

	for (i = 0; i < `FETCH_WIDTH; i++)
	begin
		ctrlCount  = ctrlCount + ctrlVect_i[i];
	end

	/* Queue Count */

	/* queueCount_t0 is the count of pushed control instructions */
	if (fs1Ready_i && ~stall_i && ~ctiQueueFull)
	begin
		queueCount_t0         = ctrlCount;
	end

	else
	begin
		queueCount_t0         = 0;
	end

	/* queueCount_t1 is the count of popped control instructions */
	if (updateEn)
	begin
		queueCount_t1 = 1'h1;
	end

	else
	begin
		queueCount_t1 = 1'h0;
	end

	queueCount_next = queueCount + queueCount_t0 - queueCount_t1;

	queueCount_recover = (commitPtr_next >= headPtr) ?
	                     (commitPtr_next - headPtr) :
	                     (`SIZE_CTI_QUEUE - headPtr + commitPtr_next);
end


always_ff @(posedge clk or posedge reset)
begin
	/* if (reset || exceptionFlag_i) */
	if (reset)
	begin
		queueCount       <= 0;
	end

	else if (recoverFlag_i || exceptionFlag_i)
	begin
		queueCount       <= queueCount_recover;
	end

	else
	begin
		queueCount       <= queueCount_next;
	end
end

assign ctiQueueFull     = (ctrlCount > (`SIZE_CTI_QUEUE-queueCount));
assign ctiQueueFull_o   = ctiQueueFull;


/* Write the PC, NPC, ctrlType and direction to the control queue.
 * The data comes from the writeback stage of the branch execution pipe */
reg  [`SIZE_CTI_LOG-1:0]                commitPtr_t [0:`COMMIT_WIDTH-1];
reg                                     commitWe  [0:`COMMIT_WIDTH-1];

always_comb
begin
	int i;
	for (i = 0; i < `COMMIT_WIDTH; i++)
	begin
		commitPtr_t[i]     = commitPtr + i;
	end
end

always_comb
begin
	int i;

	for (i = 0; i < `COMMIT_WIDTH; i++)
	begin
		commitWe[i]   = 1'h0;
	end

	/* if (~reset && ~exceptionFlag_i && ~recoverFlag_i) */
    // if recoverFlag_i then we could be committing 1 cti
	//if (~reset && ~exceptionFlag_i)
	//if (~reset)
	//begin

		case (commitCnt) //synopsys full_case

			4'h0:
			begin
			end

			4'h1:
			begin
				commitWe[0]         = 1'h1;
			end

`ifdef COMMIT_TWO_WIDE
			4'h2:
			begin
				commitWe[0]         = 1'h1;
				commitWe[1]         = 1'h1;
			end
`endif

`ifdef COMMIT_THREE_WIDE
			4'h3:
			begin
				commitWe[0]         = 1'h1;
				commitWe[1]         = 1'h1;
				commitWe[2]         = 1'h1;
			end
`endif

`ifdef COMMIT_FOUR_WIDE
			4'h4:
			begin
				commitWe[0]         = 1'h1;
				commitWe[1]         = 1'h1;
				commitWe[2]         = 1'h1;
				commitWe[3]         = 1'h1;
			end
`endif
		endcase
	//end
end


/* Control Queue IDs for incoming control instructions */
reg  [`SIZE_CTI_LOG-1:0]                ctiID     [0:`FETCH_WIDTH-1];

`ifdef ZERO
always_ff @(posedge simulate.clk)
begin
    if ((commitWe[0]) &&
        (ctiqData.ram[commitPtr_t[0]][`BRANCH_TYPE_LOG:1] == `RETURN))
    begin
        $display("[%0d] committing a return (pc: %08x nextPC: %08x ctiID: %d)\n",
            simulate.CYCLE_COUNT,
            ctiqData.ram[commitPtr_t[0]][`SIZE_PC+`SIZE_PC+`BRANCH_TYPE_LOG:`SIZE_PC+`BRANCH_TYPE_LOG+1],
            ctiqData.ram[commitPtr_t[0]][`SIZE_PC+`BRANCH_TYPE_LOG:`BRANCH_TYPE_LOG+1],
            commitPtr_t[0]);
    end
    if ((commitWe[1]) &&
        (ctiqData.ram[commitPtr_t[1]][`BRANCH_TYPE_LOG:1] == `RETURN))
    begin
        $display("[%0d] committing a return (pc: %08x nextPC: %08x ctiID: %d)\n",
            simulate.CYCLE_COUNT,
            ctiqData.ram[commitPtr_t[1]][`SIZE_PC+`SIZE_PC+`BRANCH_TYPE_LOG:`SIZE_PC+`BRANCH_TYPE_LOG+1],
            ctiqData.ram[commitPtr_t[1]][`SIZE_PC+`BRANCH_TYPE_LOG:`BRANCH_TYPE_LOG+1],
            commitPtr_t[1]);
    end
    if ((commitWe[2]) &&
        (ctiqData.ram[commitPtr_t[2]][`BRANCH_TYPE_LOG:1] == `RETURN))
    begin
        $display("[%0d] committing a return (pc: %08x nextPC: %08x ctiID: %d)\n",
            simulate.CYCLE_COUNT,
            ctiqData.ram[commitPtr_t[2]][`SIZE_PC+`SIZE_PC+`BRANCH_TYPE_LOG:`SIZE_PC+`BRANCH_TYPE_LOG+1],
            ctiqData.ram[commitPtr_t[2]][`SIZE_PC+`BRANCH_TYPE_LOG:`BRANCH_TYPE_LOG+1],
            commitPtr_t[2]);
    end
    if ((commitWe[3]) &&
        (ctiqData.ram[commitPtr_t[3]][`BRANCH_TYPE_LOG:1] == `RETURN))
    begin
        $display("[%0d] committing a return (pc: %08x nextPC: %08x ctiID: %d)\n",
            simulate.CYCLE_COUNT,
            ctiqData.ram[commitPtr_t[3]][`SIZE_PC+`SIZE_PC+`BRANCH_TYPE_LOG:`SIZE_PC+`BRANCH_TYPE_LOG+1],
            ctiqData.ram[commitPtr_t[3]][`SIZE_PC+`BRANCH_TYPE_LOG:`BRANCH_TYPE_LOG+1],
            commitPtr_t[3]);
    end
end
`endif

assign ctiID_o          = ctiID;

reg  [`FETCH_WIDTH-1:0]        ctrlVect;

always_comb
begin
    ctrlVect           = {`FETCH_WIDTH{1'b0}};
  if (~ctiQueueFull)
  begin
    ctrlVect           = ctrlVect_i;
  end
end


//// BIST State Machine to Initialize RAM/CAM /////////////

localparam BIST_SIZE_ADDR   = `SIZE_CTI_LOG;
localparam BIST_SIZE_DATA   = (`SIZE_PC+`SIZE_PC+`BRANCH_TYPE_LOG+1);
localparam BIST_NUM_ENTRIES = `SIZE_CTI_QUEUE;
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

assign bistDataWr = (BIST_RESET_MODE == 0) ? BIST_RESET_VALUE : {{(BIST_SIZE_DATA-BIST_SIZE_ADDR){1'b0}},bistAddrWr};
assign ctiqRamReady_o = ~bistEn;

always_ff @(posedge clk or posedge resetRams_i)
begin
  if(resetRams_i)
  begin
    bistState       <= BIST_START;
    bistAddrWr      <= 0;
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
      bistNextAddrWr  = bistAddrWr + 1'b1;

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

`ifdef USE_GSHARE_BPU

// This RAM stores the index from where the counters were read out
// This is required as the BHR would have changed when the counter
// iss finally updated and it will be impossible to calculate the 
// index.
CTI_COUNTER_RAM #(
	.DEPTH      (`SIZE_CTI_QUEUE),
	.INDEX      (`SIZE_CTI_LOG),
	.WIDTH      (`SIZE_CNT_TBL_LOG)
)
	ctiqIndex (

	.addr0_i    (headPtr),
	.data0_o    (updateIndex),

	.addr0wr_i  (ctiID[0]),
	.data0wr_i  (predIndex_i[0]),
	.we0_i      (ctrlVect_i[0]),

`ifdef FETCH_TWO_WIDE
	.addr1wr_i  (ctiID[1]),
	.data1wr_i  (predIndex_i[1]),
	.we1_i      (ctrlVect_i[1]),
`endif

`ifdef FETCH_THREE_WIDE
	.addr2wr_i  (ctiID[2]),
	.data2wr_i  (predIndex_i[2]),
	.we2_i      (ctrlVect_i[2]),
`endif

`ifdef FETCH_FOUR_WIDE
	.addr3wr_i  (ctiID[3]),
	.data3wr_i  (predIndex_i[3]),
	.we3_i      (ctrlVect_i[3]),
`endif

`ifdef FETCH_FIVE_WIDE
	.addr4wr_i  (ctiID[4]),
	.data4wr_i  (predIndex_i[4]),
	.we4_i      (ctrlVect_i[4]),
`endif

`ifdef FETCH_SIX_WIDE
	.addr5wr_i  (ctiID[5]),
	.data5wr_i  (predIndex_i[5]),
	.we5_i      (ctrlVect_i[5]),
`endif

`ifdef FETCH_SEVEN_WIDE
	.addr6wr_i  (ctiID[6]),
	.data6wr_i  (predIndex_i[6]),
	.we6_i      (ctrlVect_i[6]),
`endif

`ifdef FETCH_EIGHT_WIDE
	.addr7wr_i  (ctiID[7]),
	.data7wr_i  (predIndex_i[7]),
	.we7_i      (ctrlVect_i[7]),
`endif

	.clk        (clk),
	.reset      (reset)
);


`endif

CTI_COUNTER_RAM #(
  .RPORT      (1),
  .WPORT      (`FETCH_WIDTH),
	.DEPTH      (`SIZE_CTI_QUEUE),
	.INDEX      (`SIZE_CTI_LOG),
	.WIDTH      (2)
)
	ctiqCounter (

	.addr0_i    (headPtr),
	.data0_o    (updateCounter),

	.addr0wr_i  (ctiID[0]),
	.data0wr_i  (predCounter_i[0]),
	.we0_i      (ctrlVect[0]),

`ifdef FETCH_TWO_WIDE
	.addr1wr_i  (ctiID[1]),
	.data1wr_i  (predCounter_i[1]),
	.we1_i      (ctrlVect[1]),
`endif

`ifdef FETCH_THREE_WIDE
	.addr2wr_i  (ctiID[2]),
	.data2wr_i  (predCounter_i[2]),
	.we2_i      (ctrlVect[2]),
`endif

`ifdef FETCH_FOUR_WIDE
	.addr3wr_i  (ctiID[3]),
	.data3wr_i  (predCounter_i[3]),
	.we3_i      (ctrlVect[3]),
`endif

`ifdef FETCH_FIVE_WIDE
	.addr4wr_i  (ctiID[4]),
	.data4wr_i  (predCounter_i[4]),
	.we4_i      (ctrlVect[4]),
`endif

`ifdef FETCH_SIX_WIDE
	.addr5wr_i  (ctiID[5]),
	.data5wr_i  (predCounter_i[5]),
	.we5_i      (ctrlVect[5]),
`endif

`ifdef FETCH_SEVEN_WIDE
	.addr6wr_i  (ctiID[6]),
	.data6wr_i  (predCounter_i[6]),
	.we6_i      (ctrlVect[6]),
`endif

`ifdef FETCH_EIGHT_WIDE
	.addr7wr_i  (ctiID[7]),
	.data7wr_i  (predCounter_i[7]),
	.we7_i      (ctrlVect[7]),
`endif

	.clk        (clk),
	.reset      (reset)
);


RAM_1R1W #(
  .RPORT      (1),
  .WPORT      (1),
	.DEPTH      (`SIZE_CTI_QUEUE),
	.INDEX      (`SIZE_CTI_LOG),
	.WIDTH      (`SIZE_PC+`SIZE_PC+`BRANCH_TYPE_LOG+1)
	)

	ctiqData (

	.clk        (clk),
	//.reset      (reset),

	.addr0_i    (headPtr),
	.data0_o    ({updatePC, updateNPC, updateCtrlType, updateDir}),

  // TODO: This should be made equal to the number of control execution lanes
	.addr0wr_i  (bistEn ? bistAddrWr : exeCtiID_i),
	.data0wr_i  (bistEn ? bistDataWr : {exeCtrlPC_i, exeCtrlNPC_i, exeCtrlType_i, exeCtrlDir_i}),
	.we0_i      (bistEn ? 1'b0       : exeCtrlValid_i)
	);


CTI_COMMIT_RAM #(
  .RPORT      (1),
  .WPORT      (`COMMIT_WIDTH+1),
	.DEPTH      (`SIZE_CTI_QUEUE),
	.INDEX      (`SIZE_CTI_LOG),
	.WIDTH      (1)
	)

	ctiqCommitted (

	.addr0_i    (headPtr),
	.data0_o    (commit),

  // This port is used to make the commit bit 0
	.addr0wr_i  (headPtr),
	.we0_i      (updateEn),
	.data0wr_i  (1'h0),

	.addr1wr_i  (commitPtr_t[0]),
	.data1wr_i  (1'h1),
	.we1_i      (commitWe[0]),

`ifdef COMMIT_TWO_WIDE
	.addr2wr_i  (commitPtr_t[1]),
	.data2wr_i  (1'h1),
	.we2_i      (commitWe[1]),
`endif

`ifdef COMMIT_THREE_WIDE
	.addr3wr_i  (commitPtr_t[2]),
	.data3wr_i  (1'h1),
	.we3_i      (commitWe[2]),
`endif

`ifdef COMMIT_FOUR_WIDE
	.addr4wr_i  (commitPtr_t[3]),
	.data4wr_i  (1'h1),
	.we4_i      (commitWe[3]),
`endif

	.clk        (clk),
	.reset      (reset)
	//.reset      (reset | exceptionFlag_i)
	);


// Rangeen Jan 31-13 - Made this per bit to make the code smaller
/* For n new control instructions, shift the next n IDs to them. */
// LANE: Per Lane logic
always_comb
begin: TAG_ASSIGN
	int i;
	reg  [`SIZE_CTI_LOG-1:0] tag         [0:`FETCH_WIDTH-1];

	for (i = 0; i < `FETCH_WIDTH; i++)
	begin
		tag[i]     = tailPtr + i;
		ctiID[i] = 0;
	end

	  case (ctrlVect_i[0])
	  	1'b0: ctiID[0] = 0;
	  	1'b1: ctiID[0] = tag[0] ;
    endcase

  `ifdef FETCH_TWO_WIDE
	  casex (ctrlVect_i[1:0])
	  	2'b0x:  ctiID[1] = 0;
	  	2'b10:	ctiID[1] = tag[0] ;
	  	2'b11:	ctiID[1] = tag[1] ;
    endcase
  `endif

  `ifdef FETCH_THREE_WIDE
	  casex (ctrlVect_i[2:0])
	  	3'b0xx: ctiID[2] = 0;
	  	3'b100:	ctiID[2] = tag[0] ;
	  	3'b101:	ctiID[2] = tag[1] ;
	  	3'b110:	ctiID[2] = tag[1] ;
	  	3'b111:	ctiID[2] = tag[2] ;
    endcase
  `endif

  `ifdef FETCH_FOUR_WIDE
	  casex (ctrlVect_i[3:0])
	  	4'b0xxx:  ctiID[3] = 0;  
	  	4'b1000:	ctiID[3] = tag[0] ;
	  	4'b1001:	ctiID[3] = tag[1] ;
	  	4'b1010:	ctiID[3] = tag[1] ;
	  	4'b1011:	ctiID[3] = tag[2] ;
	  	4'b1100:	ctiID[3] = tag[1] ;
	  	4'b1101:	ctiID[3] = tag[2] ;
	  	4'b1110:	ctiID[3] = tag[2] ;
	  	4'b1111:	ctiID[3] = tag[3] ;
    endcase
  `endif

  `ifdef FETCH_FIVE_WIDE
	  casex (ctrlVect_i[4:0])
	  	5'b0xxxx: ctiID[4] = 0;  
	  	5'b10000:	ctiID[4] = tag[0] ;
	  	5'b10001:	ctiID[4] = tag[1] ;
	  	5'b10010:	ctiID[4] = tag[1] ;
	  	5'b10011:	ctiID[4] = tag[2] ;
	  	5'b10100:	ctiID[4] = tag[1] ;
	  	5'b10101:	ctiID[4] = tag[2] ;
	  	5'b10110:	ctiID[4] = tag[2] ;
	  	5'b10111:	ctiID[4] = tag[3] ;
	  	5'b11000:	ctiID[4] = tag[1] ;
	  	5'b11001:	ctiID[4] = tag[2] ;
	  	5'b11010:	ctiID[4] = tag[2] ;
	  	5'b11011:	ctiID[4] = tag[3] ;
	  	5'b11100:	ctiID[4] = tag[2] ;
	  	5'b11101:	ctiID[4] = tag[3] ;
	  	5'b11110:	ctiID[4] = tag[3] ;
	  	5'b11111:	ctiID[4] = tag[4] ;
    endcase
  `endif

  `ifdef FETCH_SIX_WIDE
	  casex (ctrlVect_i[5:0])
	  	6'b0xxxxx:  ctiID[5] = 0;  
	  	6'b100000:	ctiID[5] = tag[0] ;
	  	6'b100001:	ctiID[5] = tag[1] ;
	  	6'b100010:	ctiID[5] = tag[1] ;
	  	6'b100011:	ctiID[5] = tag[2] ;
	  	6'b100100:	ctiID[5] = tag[1] ;
	  	6'b100101:	ctiID[5] = tag[2] ;
	  	6'b100110:	ctiID[5] = tag[2] ;
	  	6'b100111:	ctiID[5] = tag[3] ;
	  	6'b101000:	ctiID[5] = tag[1] ;
	  	6'b101001:	ctiID[5] = tag[2] ;
	  	6'b101010:	ctiID[5] = tag[2] ;
	  	6'b101011:	ctiID[5] = tag[3] ;
	  	6'b101100:	ctiID[5] = tag[2] ;
	  	6'b101101:	ctiID[5] = tag[3] ;
	  	6'b101110:	ctiID[5] = tag[3] ;
	  	6'b101111:	ctiID[5] = tag[4] ;
	  	6'b110000:	ctiID[5] = tag[1] ;
	  	6'b110001:	ctiID[5] = tag[2] ;
	  	6'b110010:	ctiID[5] = tag[2] ;
	  	6'b110011:	ctiID[5] = tag[3] ;
	  	6'b110100:	ctiID[5] = tag[2] ;
	  	6'b110101:	ctiID[5] = tag[3] ;
	  	6'b110110:	ctiID[5] = tag[3] ;
	  	6'b110111:	ctiID[5] = tag[4] ;
	  	6'b111000:	ctiID[5] = tag[2] ;
	  	6'b111001:	ctiID[5] = tag[3] ;
	  	6'b111010:	ctiID[5] = tag[3] ;
	  	6'b111011:	ctiID[5] = tag[4] ;
	  	6'b111100:	ctiID[5] = tag[3] ;
	  	6'b111101:	ctiID[5] = tag[4] ;
	  	6'b111110:	ctiID[5] = tag[4] ;
	  	6'b111111:	ctiID[5] = tag[5] ;
    endcase
  `endif

  `ifdef FETCH_SEVEN_WIDE
	  casex (ctrlVect_i[6:0])
	  	7'b0xxxxxx: ctiID[6] = 0;  
	  	7'b1000000:	ctiID[6] = tag[0] ;
	  	7'b1000001:	ctiID[6] = tag[1] ;
	  	7'b1000010:	ctiID[6] = tag[1] ;
	  	7'b1000011:	ctiID[6] = tag[2] ;
	  	7'b1000100:	ctiID[6] = tag[1] ;
	  	7'b1000101:	ctiID[6] = tag[2] ;
	  	7'b1000110:	ctiID[6] = tag[2] ;
	  	7'b1000111:	ctiID[6] = tag[3] ;
	  	7'b1001000:	ctiID[6] = tag[1] ;
	  	7'b1001001:	ctiID[6] = tag[2] ;
	  	7'b1001010:	ctiID[6] = tag[2] ;
	  	7'b1001011:	ctiID[6] = tag[3] ;
	  	7'b1001100:	ctiID[6] = tag[2] ;
	  	7'b1001101:	ctiID[6] = tag[3] ;
	  	7'b1001110:	ctiID[6] = tag[3] ;
	  	7'b1001111:	ctiID[6] = tag[4] ;
	  	7'b1010000:	ctiID[6] = tag[1] ;
	  	7'b1010001:	ctiID[6] = tag[2] ;
	  	7'b1010010:	ctiID[6] = tag[2] ;
	  	7'b1010011:	ctiID[6] = tag[3] ;
	  	7'b1010100:	ctiID[6] = tag[2] ;
	  	7'b1010101:	ctiID[6] = tag[3] ;
	  	7'b1010110:	ctiID[6] = tag[3] ;
	  	7'b1010111:	ctiID[6] = tag[4] ;
	  	7'b1011000:	ctiID[6] = tag[2] ;
	  	7'b1011001:	ctiID[6] = tag[3] ;
	  	7'b1011010:	ctiID[6] = tag[3] ;
	  	7'b1011011:	ctiID[6] = tag[4] ;
	  	7'b1011100:	ctiID[6] = tag[3] ;
	  	7'b1011101:	ctiID[6] = tag[4] ;
	  	7'b1011110:	ctiID[6] = tag[4] ;
	  	7'b1011111:	ctiID[6] = tag[5] ;
	  	7'b1100000:	ctiID[6] = tag[1] ;
	  	7'b1100001:	ctiID[6] = tag[2] ;
	  	7'b1100010:	ctiID[6] = tag[2] ;
	  	7'b1100011:	ctiID[6] = tag[3] ;
	  	7'b1100100:	ctiID[6] = tag[2] ;
	  	7'b1100101:	ctiID[6] = tag[3] ;
	  	7'b1100110:	ctiID[6] = tag[3] ;
	  	7'b1100111:	ctiID[6] = tag[4] ;
	  	7'b1101000:	ctiID[6] = tag[2] ;
	  	7'b1101001:	ctiID[6] = tag[3] ;
	  	7'b1101010:	ctiID[6] = tag[3] ;
	  	7'b1101011:	ctiID[6] = tag[4] ;
	  	7'b1101100:	ctiID[6] = tag[3] ;
	  	7'b1101101:	ctiID[6] = tag[4] ;
	  	7'b1101110:	ctiID[6] = tag[4] ;
	  	7'b1101111:	ctiID[6] = tag[5] ;
	  	7'b1110000:	ctiID[6] = tag[2] ;
	  	7'b1110001:	ctiID[6] = tag[3] ;
	  	7'b1110010:	ctiID[6] = tag[3] ;
	  	7'b1110011:	ctiID[6] = tag[4] ;
	  	7'b1110100:	ctiID[6] = tag[3] ;
	  	7'b1110101:	ctiID[6] = tag[4] ;
	  	7'b1110110:	ctiID[6] = tag[4] ;
	  	7'b1110111:	ctiID[6] = tag[5] ;
	  	7'b1111000:	ctiID[6] = tag[3] ;
	  	7'b1111001:	ctiID[6] = tag[4] ;
	  	7'b1111010:	ctiID[6] = tag[4] ;
	  	7'b1111011:	ctiID[6] = tag[5] ;
	  	7'b1111100:	ctiID[6] = tag[4] ;
	  	7'b1111101:	ctiID[6] = tag[5] ;
	  	7'b1111110:	ctiID[6] = tag[5] ;
	  	7'b1111111:	ctiID[6] = tag[6] ;
    endcase
  `endif

  `ifdef FETCH_EIGHT_WIDE
	  casex (ctrlVect_i[7:0])
	  	8'b0xxxxxxx:  ctiID[7] = 0;  
	  	8'b10000000:	ctiID[7] = tag[0] ;
	  	8'b10000001:	ctiID[7] = tag[1] ;
	  	8'b10000010:	ctiID[7] = tag[1] ;
	  	8'b10000011:	ctiID[7] = tag[2] ;
	  	8'b10000100:	ctiID[7] = tag[1] ;
	  	8'b10000101:	ctiID[7] = tag[2] ;
	  	8'b10000110:	ctiID[7] = tag[2] ;
	  	8'b10000111:	ctiID[7] = tag[3] ;
	  	8'b10001000:	ctiID[7] = tag[1] ;
	  	8'b10001001:	ctiID[7] = tag[2] ;
	  	8'b10001010:	ctiID[7] = tag[2] ;
	  	8'b10001011:	ctiID[7] = tag[3] ;
	  	8'b10001100:	ctiID[7] = tag[2] ;
	  	8'b10001101:	ctiID[7] = tag[3] ;
	  	8'b10001110:	ctiID[7] = tag[3] ;
	  	8'b10001111:	ctiID[7] = tag[4] ;
	  	8'b10010000:	ctiID[7] = tag[1] ;
	  	8'b10010001:	ctiID[7] = tag[2] ;
	  	8'b10010010:	ctiID[7] = tag[2] ;
	  	8'b10010011:	ctiID[7] = tag[3] ;
	  	8'b10010100:	ctiID[7] = tag[2] ;
	  	8'b10010101:	ctiID[7] = tag[3] ;
	  	8'b10010110:	ctiID[7] = tag[3] ;
	  	8'b10010111:	ctiID[7] = tag[4] ;
	  	8'b10011000:	ctiID[7] = tag[2] ;
	  	8'b10011001:	ctiID[7] = tag[3] ;
	  	8'b10011010:	ctiID[7] = tag[3] ;
	  	8'b10011011:	ctiID[7] = tag[4] ;
	  	8'b10011100:	ctiID[7] = tag[3] ;
	  	8'b10011101:	ctiID[7] = tag[4] ;
	  	8'b10011110:	ctiID[7] = tag[4] ;
	  	8'b10011111:	ctiID[7] = tag[5] ;
	  	8'b10100000:	ctiID[7] = tag[1] ;
	  	8'b10100001:	ctiID[7] = tag[2] ;
	  	8'b10100010:	ctiID[7] = tag[2] ;
	  	8'b10100011:	ctiID[7] = tag[3] ;
	  	8'b10100100:	ctiID[7] = tag[2] ;
	  	8'b10100101:	ctiID[7] = tag[3] ;
	  	8'b10100110:	ctiID[7] = tag[3] ;
	  	8'b10100111:	ctiID[7] = tag[4] ;
	  	8'b10101000:	ctiID[7] = tag[2] ;
	  	8'b10101001:	ctiID[7] = tag[3] ;
	  	8'b10101010:	ctiID[7] = tag[3] ;
	  	8'b10101011:	ctiID[7] = tag[4] ;
	  	8'b10101100:	ctiID[7] = tag[3] ;
	  	8'b10101101:	ctiID[7] = tag[4] ;
	  	8'b10101110:	ctiID[7] = tag[4] ;
	  	8'b10101111:	ctiID[7] = tag[5] ;
	  	8'b10110000:	ctiID[7] = tag[2] ;
	  	8'b10110001:	ctiID[7] = tag[3] ;
	  	8'b10110010:	ctiID[7] = tag[3] ;
	  	8'b10110011:	ctiID[7] = tag[4] ;
	  	8'b10110100:	ctiID[7] = tag[3] ;
	  	8'b10110101:	ctiID[7] = tag[4] ;
	  	8'b10110110:	ctiID[7] = tag[4] ;
	  	8'b10110111:	ctiID[7] = tag[5] ;
	  	8'b10111000:	ctiID[7] = tag[3] ;
	  	8'b10111001:	ctiID[7] = tag[4] ;
	  	8'b10111010:	ctiID[7] = tag[4] ;
	  	8'b10111011:	ctiID[7] = tag[5] ;
	  	8'b10111100:	ctiID[7] = tag[4] ;
	  	8'b10111101:	ctiID[7] = tag[5] ;
	  	8'b10111110:	ctiID[7] = tag[5] ;
	  	8'b10111111:	ctiID[7] = tag[6] ;
	  	8'b11000000:	ctiID[7] = tag[1] ;
	  	8'b11000001:	ctiID[7] = tag[2] ;
	  	8'b11000010:	ctiID[7] = tag[2] ;
	  	8'b11000011:	ctiID[7] = tag[3] ;
	  	8'b11000100:	ctiID[7] = tag[2] ;
	  	8'b11000101:	ctiID[7] = tag[3] ;
	  	8'b11000110:	ctiID[7] = tag[3] ;
	  	8'b11000111:	ctiID[7] = tag[4] ;
	  	8'b11001000:	ctiID[7] = tag[2] ;
	  	8'b11001001:	ctiID[7] = tag[3] ;
	  	8'b11001010:	ctiID[7] = tag[3] ;
	  	8'b11001011:	ctiID[7] = tag[4] ;
	  	8'b11001100:	ctiID[7] = tag[3] ;
	  	8'b11001101:	ctiID[7] = tag[4] ;
	  	8'b11001110:	ctiID[7] = tag[4] ;
	  	8'b11001111:	ctiID[7] = tag[5] ;
	  	8'b11010000:	ctiID[7] = tag[2] ;
	  	8'b11010001:	ctiID[7] = tag[3] ;
	  	8'b11010010:	ctiID[7] = tag[3] ;
	  	8'b11010011:	ctiID[7] = tag[4] ;
	  	8'b11010100:	ctiID[7] = tag[3] ;
	  	8'b11010101:	ctiID[7] = tag[4] ;
	  	8'b11010110:	ctiID[7] = tag[4] ;
	  	8'b11010111:	ctiID[7] = tag[5] ;
	  	8'b11011000:	ctiID[7] = tag[3] ;
	  	8'b11011001:	ctiID[7] = tag[4] ;
	  	8'b11011010:	ctiID[7] = tag[4] ;
	  	8'b11011011:	ctiID[7] = tag[5] ;
	  	8'b11011100:	ctiID[7] = tag[4] ;
	  	8'b11011101:	ctiID[7] = tag[5] ;
	  	8'b11011110:	ctiID[7] = tag[5] ;
	  	8'b11011111:	ctiID[7] = tag[6] ;
	  	8'b11100000:	ctiID[7] = tag[2] ;
	  	8'b11100001:	ctiID[7] = tag[3] ;
	  	8'b11100010:	ctiID[7] = tag[3] ;
	  	8'b11100011:	ctiID[7] = tag[4] ;
	  	8'b11100100:	ctiID[7] = tag[3] ;
	  	8'b11100101:	ctiID[7] = tag[4] ;
	  	8'b11100110:	ctiID[7] = tag[4] ;
	  	8'b11100111:	ctiID[7] = tag[5] ;
	  	8'b11101000:	ctiID[7] = tag[3] ;
	  	8'b11101001:	ctiID[7] = tag[4] ;
	  	8'b11101010:	ctiID[7] = tag[4] ;
	  	8'b11101011:	ctiID[7] = tag[5] ;
	  	8'b11101100:	ctiID[7] = tag[4] ;
	  	8'b11101101:	ctiID[7] = tag[5] ;
	  	8'b11101110:	ctiID[7] = tag[5] ;
	  	8'b11101111:	ctiID[7] = tag[6] ;
	  	8'b11110000:	ctiID[7] = tag[3] ;
	  	8'b11110001:	ctiID[7] = tag[4] ;
	  	8'b11110010:	ctiID[7] = tag[4] ;
	  	8'b11110011:	ctiID[7] = tag[5] ;
	  	8'b11110100:	ctiID[7] = tag[4] ;
	  	8'b11110101:	ctiID[7] = tag[5] ;
	  	8'b11110110:	ctiID[7] = tag[5] ;
	  	8'b11110111:	ctiID[7] = tag[6] ;
	  	8'b11111000:	ctiID[7] = tag[4] ;
	  	8'b11111001:	ctiID[7] = tag[5] ;
	  	8'b11111010:	ctiID[7] = tag[5] ;
	  	8'b11111011:	ctiID[7] = tag[6] ;
	  	8'b11111100:	ctiID[7] = tag[5] ;
	  	8'b11111101:	ctiID[7] = tag[6] ;
	  	8'b11111110:	ctiID[7] = tag[6] ;
	  	8'b11111111:	ctiID[7] = tag[7] ;
    endcase
  `endif

end


endmodule

