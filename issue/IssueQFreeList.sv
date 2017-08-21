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

module IssueQFreeList(
	input                           clk,
	input                           reset,
	input                           resetRams_i,
  input                           flush_i,
  input [`SIZE_ISSUEQ_LOG:0]      iqSize_i,

  // Variable in case of DYNAMIC_CONFIG - `DISPATCH_WIDTH otherwise
  input [`DISPATCH_WIDTH_LOG:0]   numDispatchLaneActive_i, 
`ifdef DYNAMIC_CONFIG
  input [`DISPATCH_WIDTH-1:0]     dispatchLaneActive_i,
  input [`ISSUE_WIDTH-1:0]        issueLaneActive_i,
  input [`NUM_PARTS_IQ-1:0]       iqPartitionActive_i,
`endif  

	//input                           dispatchReady_i,
  input [0:`DISPATCH_WIDTH-1]     reqFreeEntry_i,

	/* Entries being freed once they have been issued. */
	input  iqEntryPkt               grantedEntry_i [0:`ISSUE_WIDTH-1],

	output iqEntryPkt               freedEntry_o   [0:`ISSUE_WIDTH-1],

	/* Free Issue Queue entries for the incoming instructions. */
	output iqEntryPkt               freeEntry_o    [0:`DISPATCH_WIDTH-1],

	/* Count of occupied Issue Q entries goes to Dispatch */
	output [`SIZE_ISSUEQ_LOG:0]     cntInstIssueQ_o,
	output                          iqflRamReady_o 
	);


reg  [`SIZE_ISSUEQ_LOG-1:0]      headPtr;
reg  [`SIZE_ISSUEQ_LOG-1:0]      headPtr_t;
reg  [`SIZE_ISSUEQ_LOG-1:0]      readPtr    [0:`DISPATCH_WIDTH-1];
reg  [`SIZE_ISSUEQ_LOG-1:0]      readPtrGated [0:`DISPATCH_WIDTH-1];

reg  [`SIZE_ISSUEQ_LOG-1:0]      tailPtr;
reg  [`SIZE_ISSUEQ_LOG-1:0]      tailPtr_t;
reg  [`SIZE_ISSUEQ_LOG-1:0]      writePtr    [0:`ISSUE_WIDTH-1];
reg  [`SIZE_ISSUEQ_LOG-1:0]      writePtrGated [0:`ISSUE_WIDTH-1];

iqEntryPkt                       freeEntry_t  [0:`DISPATCH_WIDTH-1];

iqEntryPkt                       freedEntry   [0:`ISSUE_WIDTH-1];
reg  [`SIZE_ISSUEQ_LOG-1:0]      freedEntry_t [0:`ISSUE_WIDTH-1];
reg  [`ISSUE_WIDTH-1:0]          freedValid;

reg                              writeEn      [0:`ISSUE_WIDTH-1];

reg  [`SIZE_ISSUEQ_LOG:0]        issueQCount;
reg  [`SIZE_ISSUEQ_LOG:0]        issueQCount_f;


always_comb
begin
	int i;
	for (i = 0; i < `ISSUE_WIDTH; i++)
	begin
		freedEntry_o[i].id    = freedEntry[i].id;
		freedEntry_o[i].valid = freedEntry[i].valid;
	end
end

/* Sending Issue Queue occupied entries to Dispatch. */
assign cntInstIssueQ_o  = issueQCount;

/* added explicit wrap around of pointers in order
 * to support arbitrary issue queue sizes */
always_comb
begin: CALCULATE_PTRS
	int i;
  //Must be 1-bit longer to contain the 2^WIDTH_LOG value
	reg [`DISPATCH_WIDTH_LOG:0] totalRequested;
	reg [`ISSUE_WIDTH_LOG:0] totalFreed;

  totalRequested = 0;

	for (i = 0; i < `DISPATCH_WIDTH; i++)
	begin
		totalRequested = totalRequested + reqFreeEntry_i[i];
	end
	headPtr_t = headPtr + totalRequested;
  if(headPtr_t >= iqSize_i)
    headPtr_t = headPtr_t - iqSize_i;

	totalFreed = 0;

	for (i = 0; i < `ISSUE_WIDTH; i++)
	begin
		totalFreed = totalFreed + freedEntry[i].valid;
	end

	tailPtr_t = tailPtr + totalFreed;
  if(tailPtr_t >= iqSize_i)
    tailPtr_t = tailPtr_t - iqSize_i;

	issueQCount_f = issueQCount - totalFreed + totalRequested;
end

/* Following updates the Free List Head Pointer, only if there is no control
* mispredict. */
/* Follwoing maintains the issue queue occupancy count each cycle. */
always_ff @(posedge clk or posedge reset)
begin:UPDATE_PTRS
	if(reset)
	begin
		headPtr     <= 0;
		tailPtr     <= 0;
		issueQCount <= 0;
	end
	else
    if(flush_i)
  	begin
		  headPtr     <= 0;
      tailPtr     <= 0;
		  issueQCount <= 0;
    end
    else
    begin
		  headPtr     <= headPtr_t;
	  	tailPtr     <= tailPtr_t;
		  issueQCount <= issueQCount_f;
	  end

end

/* Generates read addresses for the FREELIST FIFO, using head pointer. */
always_comb
begin
	int i;
	for (i = 0; i < `DISPATCH_WIDTH; i++)
	begin
		readPtr[i] = headPtr + i;
    // Explicit wrap around logic
    if(readPtr[i] >= iqSize_i)
      readPtr[i] = readPtr[i] - iqSize_i;
	end
end

/* Following updates the FREE LIST counter and pushes the freed Issue
*  Queue entry into the FREE LIST. */
always_comb
begin
	int i;
	for (i = 0; i < `ISSUE_WIDTH; i = i + 1)
	begin
		writePtr[i] = tailPtr + i;
    // Explicit wrap around logic
    if(writePtr[i] >= iqSize_i)
      writePtr[i] = writePtr[i] - iqSize_i;
	end
end

// Gating the popping of free entries fo inactive dispatch lanes

// Gating the write address for freed entries into the free list.
// Only active ISSUE width number of entries are freed every cycle.
// This keeps fixed config and Anycore consistent with each other.
`ifdef DYNAMIC_CONFIG
  genvar rd;
  genvar wr;
  generate
	  for (rd = 0; rd < `DISPATCH_WIDTH; rd = rd + 1)
    begin:CLAMP_RD
        PGIsolationCell #(
          .WIDTH(`SIZE_ISSUEQ_LOG)
        ) wrAddrClamp
        (
          .clampEn(~dispatchLaneActive_i[rd]),
          .signalIn(readPtr[rd]),
          .signalOut(readPtrGated[rd]),
          .clampValue({`SIZE_ISSUEQ_LOG{1'b0}})
        );
    end
  endgenerate

  generate
	  for (wr = 0; wr < `ISSUE_WIDTH; wr = wr + 1)
    begin:CLAMP_WR
        PGIsolationCell #(
          .WIDTH(`SIZE_ISSUEQ_LOG)
        ) wrAddrClamp
        (
          .clampEn(~issueLaneActive_i[wr]),
          .signalIn(writePtr[wr]),
          .signalOut(writePtrGated[wr]),
          .clampValue({`SIZE_ISSUEQ_LOG{1'b0}})
        );
    end
  endgenerate

`else
  always_comb
  begin
    int rd;
    int wr;
	  for (rd = 0; rd < `DISPATCH_WIDTH; rd = rd + 1)
	  begin
      readPtrGated[rd]   = readPtr[rd]  ;
    end

	  for (wr = 0; wr < `ISSUE_WIDTH; wr = wr + 1)
	  begin
      writePtrGated[wr]   = writePtr[wr]  ;
    end
  end
`endif

// All issue queue entries that have been freed (issued) are written to a vector
// in FreeIssueQueue. The freeing logic then pushes these freed entries one-by-one 
// onto the issue queue free list. The freed vector must be reset on a flush as part
// flushing all speculative state and restoring default state in the various structures.
FreeIssueq freeIq (
	.clk                (clk),
	.reset              (reset | flush_i),

//`ifdef DYNAMIC_CONFIG  
//  // Number of freelist write ports does not depend on issue lanes.
//  // It is an independent design parameter and determines the freeing of 
//  // issue queue entries. Hence the write ports are never gated.
//  //.issueLaneActive_i  (5'b11111),
//  .issueLaneActive_i  (issueLaneActive_i),
//`endif

	.grantedEntry_i     (grantedEntry_i),
	.freedEntry_o       (freedEntry)
	);


//// BIST State Machine to Initialize RAM/CAM /////////////

localparam BIST_SIZE_ADDR   = `SIZE_ISSUEQ_LOG;
localparam BIST_SIZE_DATA   = `SIZE_ISSUEQ_LOG;
localparam BIST_NUM_ENTRIES = `SIZE_ISSUEQ;
localparam BIST_RESET_MODE  = 1; //0 -> Fixed value; 1 -> Sequential values
localparam BIST_RESET_VALUE = 0; // Initialize all entries to this value if RESET_MODE = 0; starting from this value if RESET_MODE = 1

localparam BIST_START = 0;
localparam BIST_RUN   = 1;
localparam BIST_DONE  = 2;

logic                       bistEn;
logic [1:0]                 bistState;
logic [1:0]                 bistNextState;
logic [BIST_SIZE_ADDR-1:0]  bistAddrWr;
logic [BIST_SIZE_ADDR-1:0]  bistNextAddrWr;
logic [BIST_SIZE_DATA-1:0]  bistDataWr;
logic [BIST_SIZE_DATA-1:0]  bistNextDataWr;

assign iqflRamReady_o = ~bistEn;

always_ff @(posedge clk or posedge resetRams_i)
begin
  if(resetRams_i)
  begin
    bistState       <= BIST_START;
    bistAddrWr      <= 0;
    bistDataWr      <= BIST_RESET_VALUE;
  end
  else if(flush_i)
  begin
    bistState       <= BIST_RUN;
    bistAddrWr      <= 0;
    bistDataWr      <= BIST_RESET_VALUE;
  end
  else
  begin
    bistState       <= bistNextState;
    bistAddrWr      <= bistNextAddrWr;
    bistDataWr      <= bistNextDataWr;
  end
end

always_comb
begin
  bistEn              = 1'b0;
  bistNextState       = bistState;
  bistNextAddrWr      = bistAddrWr;
  bistNextDataWr      = bistDataWr;

  case(bistState)
    BIST_START: begin
      bistNextState   = BIST_RUN;
      bistNextAddrWr  = 0;
    end
    BIST_RUN: begin
      bistEn = 1'b1;
      bistNextAddrWr  = bistAddrWr + 1'b1;
      bistNextDataWr  = (BIST_RESET_MODE == 0) ? bistDataWr : bistDataWr + 1'b1;

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
      bistNextDataWr  = BIST_RESET_VALUE;
      bistNextState   = BIST_DONE;
    end
  endcase
end

//////////////////////////////////////////////////////////

// TODO: Change the queue implementation to have a
// one-to-one correspondence between write port and 
// freedEntry and vary the writeAddr instead. 
// This will make for a much simpler code and probably
// a better synthesis.
// TODO: Include partitioning of the RAM

`ifdef RANGEEN_TRIAL

reg  [`SIZE_ISSUEQ_LOG-1:0]      wrAddr_t     [0:`ISSUE_WIDTH-1];

IQFREELIST_RAM #(
  .RPORT      (`DISPATCH_WIDTH),
  .WPORT      (`ISSUE_WIDTH),
	.DEPTH      (`SIZE_ISSUEQ),
	.INDEX      (`SIZE_ISSUEQ_LOG),
	.WIDTH      (`SIZE_ISSUEQ_LOG)
	)
	iqfreelist  (

	.addr0_i    (readPtrGated[0]),
	.data0_o    (freeEntry_t[0].id),

`ifdef DISPATCH_TWO_WIDE
	.addr1_i    (readPtrGated[1]),
	.data1_o    (freeEntry_t[1].id),
`endif

`ifdef DISPATCH_THREE_WIDE
	.addr2_i    (readPtrGated[2]),
	.data2_o    (freeEntry_t[2].id),
`endif

`ifdef DISPATCH_FOUR_WIDE
	.addr3_i    (readPtrGated[3]),
	.data3_o    (freeEntry_t[3].id),
`endif

`ifdef DISPATCH_FIVE_WIDE
	.addr4_i    (readPtrGated[4]),
	.data4_o    (freeEntry_t[4].id),
`endif

`ifdef DISPATCH_SIX_WIDE
	.addr5_i    (readPtrGated[5]),
	.data5_o    (freeEntry_t[5].id),
`endif

`ifdef DISPATCH_SEVEN_WIDE
	.addr6_i    (readPtrGated[6]),
	.data6_o    (freeEntry_t[6].id),
`endif

`ifdef DISPATCH_EIGHT_WIDE
	.addr7_i    (readPtrGated[7]),
	.data7_o    (freeEntry_t[7].id),
`endif


	.addr0wr_i  (wrAddr_t[0]),
	.data0wr_i  (freedEntry_t[0]),
	.we0_i      (writeEn[0]),

`ifdef ISSUE_TWO_WIDE
	.addr1wr_i  (wrAddr_t[1]),
	.data1wr_i  (freedEntry_t[1]),
	.we1_i      (writeEn[1]),
`endif

`ifdef ISSUE_THREE_WIDE
	.addr2wr_i  (wrAddr_t[2]),
	.data2wr_i  (freedEntry_t[2]),
	.we2_i      (writeEn[2]),
`endif

`ifdef ISSUE_FOUR_WIDE
	.addr3wr_i  (wrAddr_t[3]),
	.data3wr_i  (freedEntry_t[3]),
	.we3_i      (writeEn[3]),
`endif

`ifdef ISSUE_FIVE_WIDE
	.addr4wr_i  (wrAddr_t[4]),
	.data4wr_i  (freedEntry_t[4]),
	.we4_i      (writeEn[4]),
`endif

`ifdef ISSUE_SIX_WIDE
	.addr5wr_i  (wrAddr_t[5]),
	.data5wr_i  (freedEntry_t[5]),
	.we5_i      (writeEn[5]),
`endif

`ifdef ISSUE_SEVEN_WIDE
	.addr6wr_i  (wrAddr_t[6]),
	.data6wr_i  (freedEntry_t[6]),
	.we6_i      (writeEn[6]),
`endif

`ifdef ISSUE_EIGHT_WIDE
	.addr7wr_i  (wrAddr_t[7]),
	.data7wr_i  (freedEntry_t[7]),
	.we7_i      (writeEn[7]),
`endif

	.clk        (clk),
	.reset      (reset)
	);


// Generation of correct write address  
// TODO: This is a triangular logic and could 
// benefit from dynamic reconfiguration
// LANE: Per lane logic
reg [2:0] prevValidCnt_t [0:7];
always_comb
begin
	int i;
	for (i = 0; i < `ISSUE_WIDTH; i = i + 1)
	begin
		writeEn[i]   = freedEntry[i].valid;
    freedEntry_t[i] = freedEntry[i].id;
    wrAddr_t[i] = 0;
	end

    wrAddr_t[0]       = writePtr[0];

  `ifdef ISSUE_TWO_WIDE    
    prevValidCnt_t[1] = writeEn[0];
    wrAddr_t[1]  = writePtr[prevValidCnt_t[1]]; // muxing between 2 choices 
  `endif

  `ifdef ISSUE_THREE_WIDE    
    prevValidCnt_t[2] = {3'b0,(writeEn[0] + writeEn[1])}; // Padding to make sure that result is always 3 bit
    wrAddr_t[2]  = writePtr[prevValidCnt_t[2]]; // muxing between 3 choices 
  `endif

  `ifdef ISSUE_FOUR_WIDE    
    prevValidCnt_t[3] = {3'b0,(writeEn[0] + writeEn[1] + writeEn[2])}; // Padding to make sure that result is always 3 bit
    wrAddr_t[3]  = writePtr[prevValidCnt_t[3]]; // muxing between 4 choices 
  `endif

  `ifdef ISSUE_FIVE_WIDE    
    prevValidCnt_t[4] = {3'b0,(writeEn[0] + writeEn[1] + writeEn[2] + writeEn[3])}; // Padding to make sure that result is always 3 bit
    wrAddr_t[4]  = writePtr[prevValidCnt_t[4]]; // muxing between 5 choices 
  `endif

  `ifdef ISSUE_SIX_WIDE    
    prevValidCnt_t[5] = {3'b0,(writeEn[0] + writeEn[1] + writeEn[2] 
                              + writeEn[3] + writeEn[4])}; // Padding to make sure that result is always 3 bit
    wrAddr_t[5]  = writePtr[prevValidCnt_t[5]]; // muxing between 6 choices 
  `endif

  `ifdef ISSUE_SEVEN_WIDE    
    prevValidCnt_t[6] = {3'b0,(writeEn[0] + writeEn[1] + writeEn[2] 
                          + writeEn[3] + writeEn[4] + writeEn[5])}; // Padding to make sure that result is always 3 bit
    wrAddr_t[6]  = writePtr[prevValidCnt_t[6]]; // muxing between 7 choices 
  `endif

  `ifdef ISSUE_EIGHT_WIDE    
    prevValidCnt_t[7] = {3'b0,(writeEn[0] + writeEn[1] + writeEn[2] 
                            + writeEn[3] + writeEn[4] + writeEn[5] + writeEn[6])}; // Padding to make sure that result is always 3 bit
    wrAddr_t[7]  = writePtr[prevValidCnt_t[7]]; // muxing between 8 choices 
  `endif


end



`else //RANGEEN_TRIAL

/* Generates free entries for dispatched instructions. */
always_comb
begin
	int i;
	for (i = 0; i < `DISPATCH_WIDTH; i++)
	begin
		freeEntry_o[i].id    = freeEntry_t[i].id;
		freeEntry_o[i].valid = reqFreeEntry_i[i];
  end
end



`ifdef DYNAMIC_CONFIG
IQFREELIST_RAM_PARTITIONED #(
`else
IQFREELIST_RAM #(
`endif
  .RPORT      (`DISPATCH_WIDTH),
  .WPORT      (`ISSUE_WIDTH),
	.DEPTH      (`SIZE_ISSUEQ),
	.INDEX      (`SIZE_ISSUEQ_LOG),
	.WIDTH      (`SIZE_ISSUEQ_LOG)
	)
	iqfreelist  (

	.addr0_i    (readPtrGated[0]),
	.data0_o    (freeEntry_t[0].id),

`ifdef DISPATCH_TWO_WIDE
	.addr1_i    (readPtrGated[1]),
	.data1_o    (freeEntry_t[1].id),
`endif

`ifdef DISPATCH_THREE_WIDE
	.addr2_i    (readPtrGated[2]),
	.data2_o    (freeEntry_t[2].id),
`endif

`ifdef DISPATCH_FOUR_WIDE
	.addr3_i    (readPtrGated[3]),
	.data3_o    (freeEntry_t[3].id),
`endif

`ifdef DISPATCH_FIVE_WIDE
	.addr4_i    (readPtrGated[4]),
	.data4_o    (freeEntry_t[4].id),
`endif

`ifdef DISPATCH_SIX_WIDE
	.addr5_i    (readPtrGated[5]),
	.data5_o    (freeEntry_t[5].id),
`endif

`ifdef DISPATCH_SEVEN_WIDE
	.addr6_i    (readPtrGated[6]),
	.data6_o    (freeEntry_t[6].id),
`endif

`ifdef DISPATCH_EIGHT_WIDE
	.addr7_i    (readPtrGated[7]),
	.data7_o    (freeEntry_t[7].id),
`endif


	.addr0wr_i  (bistEn ? bistAddrWr : writePtrGated[0]),
	.data0wr_i  (bistEn ? bistDataWr : freedEntry_t[0]),
	.we0_i      (bistEn ? 1'b1       : writeEn[0]),

`ifdef ISSUE_TWO_WIDE
	.addr1wr_i  (writePtrGated[1]),
	.data1wr_i  (freedEntry_t[1]),
	.we1_i      (writeEn[1]),
`endif

`ifdef ISSUE_THREE_WIDE
	.addr2wr_i  (writePtrGated[2]),
	.data2wr_i  (freedEntry_t[2]),
	.we2_i      (writeEn[2]),
`endif

`ifdef ISSUE_FOUR_WIDE
	.addr3wr_i  (writePtrGated[3]),
	.data3wr_i  (freedEntry_t[3]),
	.we3_i      (writeEn[3]),
`endif

`ifdef ISSUE_FIVE_WIDE
	.addr4wr_i  (writePtrGated[4]),
	.data4wr_i  (freedEntry_t[4]),
	.we4_i      (writeEn[4]),
`endif

`ifdef ISSUE_SIX_WIDE
	.addr5wr_i  (writePtrGated[5]),
	.data5wr_i  (freedEntry_t[5]),
	.we5_i      (writeEn[5]),
`endif

`ifdef ISSUE_SEVEN_WIDE
	.addr6wr_i  (writePtrGated[6]),
	.data6wr_i  (freedEntry_t[6]),
	.we6_i      (writeEn[6]),
`endif

`ifdef ISSUE_EIGHT_WIDE
	.addr7wr_i  (writePtrGated[7]),
	.data7wr_i  (freedEntry_t[7]),
	.we7_i      (writeEn[7]),
`endif

`ifdef DYNAMIC_CONFIG
  .dispatchLaneActive_i (dispatchLaneActive_i),
  // TODO:Number of freelist write ports does not depend on issue lanes.
  // It is an independent design parameter and determines the freeing of 
  // issue queue entries.
  .issueLaneActive_i    (5'b11111),            
  .iqPartitionActive_i  (iqPartitionActive_i),
`endif

	.clk        (clk)
	//.reset      (reset)
	);


// TODO: Change this to a more efficient code

/* (Nothing else below) */
always_comb
begin
	int i;
	for (i = 0; i < `ISSUE_WIDTH; i = i + 1)
	begin
		freedEntry_t[i] = 0;
		writeEn[i]   = 1'h0;
		freedValid[i] = freedEntry[i].valid;
	end

	case(freedValid)

		8'b00000000:
		begin
		end

		8'b00000001:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;
		end

		8'b00000010:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;
		end

		8'b00000011:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;
		end

		8'b00000100:
		begin
			freedEntry_t[0] = freedEntry[2].id;
			writeEn[0]   = 1'h1;
		end

		8'b00000101:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;
		end

		8'b00000110:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;
		end

		8'b00000111:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[2].id;
			writeEn[2]   = 1'h1;
		end

`ifdef ISSUE_FOUR_WIDE
		8'b00001000:
		begin
			freedEntry_t[0] = freedEntry[3].id;
			writeEn[0]   = 1'h1;
		end

		8'b00001001:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;
		end

		8'b00001010:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;
		end

		8'b00001011:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;
		end

		8'b00001100:
		begin
			freedEntry_t[0] = freedEntry[2].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;
		end

		8'b00001101:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;
		end

		8'b00001110:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;
		end

		8'b00001111:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[2].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[3].id;
			writeEn[3]   = 1'h1;
		end
`endif

`ifdef ISSUE_FIVE_WIDE
		8'b00010000:
		begin
			freedEntry_t[0] = freedEntry[4].id;
			writeEn[0]   = 1'h1;
		end

		8'b00010001:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[4].id;
			writeEn[1]   = 1'h1;
		end

		8'b00010010:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[4].id;
			writeEn[1]   = 1'h1;
		end

		8'b00010011:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;
		end

		8'b00010100:
		begin
			freedEntry_t[0] = freedEntry[2].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[4].id;
			writeEn[1]   = 1'h1;
		end

		8'b00010101:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;
		end

		8'b00010110:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;
		end

		8'b00010111:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[2].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[4].id;
			writeEn[3]   = 1'h1;
		end

		8'b00011000:
		begin
			freedEntry_t[0] = freedEntry[3].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[4].id;
			writeEn[1]   = 1'h1;
		end

		8'b00011001:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;
		end

		8'b00011010:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;
		end

		8'b00011011:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[4].id;
			writeEn[3]   = 1'h1;
		end

		8'b00011100:
		begin
			freedEntry_t[0] = freedEntry[2].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;
		end

		8'b00011101:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[4].id;
			writeEn[3]   = 1'h1;
		end

		8'b00011110:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[4].id;
			writeEn[3]   = 1'h1;
		end

		8'b00011111:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[2].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[3].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[4].id;
			writeEn[4]   = 1'h1;
		end
`endif

`ifdef ISSUE_SIX_WIDE
		8'b00100000:
		begin
			freedEntry_t[0] = freedEntry[5].id;
			writeEn[0]   = 1'h1;
		end

		8'b00100001:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[5].id;
			writeEn[1]   = 1'h1;
		end

		8'b00100010:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[5].id;
			writeEn[1]   = 1'h1;
		end

		8'b00100011:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;
		end

		8'b00100100:
		begin
			freedEntry_t[0] = freedEntry[2].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[5].id;
			writeEn[1]   = 1'h1;
		end

		8'b00100101:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;
		end

		8'b00100110:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;
		end

		8'b00100111:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[2].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;
		end

		8'b00101000:
		begin
			freedEntry_t[0] = freedEntry[3].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[5].id;
			writeEn[1]   = 1'h1;
		end

		8'b00101001:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;
		end

		8'b00101010:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;
		end

		8'b00101011:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;
		end

		8'b00101100:
		begin
			freedEntry_t[0] = freedEntry[2].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;
		end

		8'b00101101:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;
		end

		8'b00101110:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;
		end

		8'b00101111:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[2].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[3].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[5].id;
			writeEn[4]   = 1'h1;
		end

		8'b00110000:
		begin
			freedEntry_t[0] = freedEntry[4].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[5].id;
			writeEn[1]   = 1'h1;
		end

		8'b00110001:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[4].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;
		end

		8'b00110010:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[4].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;
		end

		8'b00110011:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;
		end

		8'b00110100:
		begin
			freedEntry_t[0] = freedEntry[2].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[4].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;
		end

		8'b00110101:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;
		end

		8'b00110110:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;
		end

		8'b00110111:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[2].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[4].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[5].id;
			writeEn[4]   = 1'h1;
		end

		8'b00111000:
		begin
			freedEntry_t[0] = freedEntry[3].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[4].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;
		end

		8'b00111001:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;
		end

		8'b00111010:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;
		end

		8'b00111011:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[4].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[5].id;
			writeEn[4]   = 1'h1;
		end

		8'b00111100:
		begin
			freedEntry_t[0] = freedEntry[2].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;
		end

		8'b00111101:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[4].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[5].id;
			writeEn[4]   = 1'h1;
		end

		8'b00111110:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[4].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[5].id;
			writeEn[4]   = 1'h1;
		end

		8'b00111111:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[2].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[3].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[4].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[5].id;
			writeEn[5]   = 1'h1;
		end
`endif

`ifdef ISSUE_SEVEN_WIDE
		8'b01000000:
		begin
			freedEntry_t[0] = freedEntry[6].id;
			writeEn[0]   = 1'h1;
		end

		8'b01000001:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[6].id;
			writeEn[1]   = 1'h1;
		end

		8'b01000010:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[6].id;
			writeEn[1]   = 1'h1;
		end

		8'b01000011:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[6].id;
			writeEn[2]   = 1'h1;
		end

		8'b01000100:
		begin
			freedEntry_t[0] = freedEntry[2].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[6].id;
			writeEn[1]   = 1'h1;
		end

		8'b01000101:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[6].id;
			writeEn[2]   = 1'h1;
		end

		8'b01000110:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[6].id;
			writeEn[2]   = 1'h1;
		end

		8'b01000111:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[2].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;
		end

		8'b01001000:
		begin
			freedEntry_t[0] = freedEntry[3].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[6].id;
			writeEn[1]   = 1'h1;
		end

		8'b01001001:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[6].id;
			writeEn[2]   = 1'h1;
		end

		8'b01001010:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[6].id;
			writeEn[2]   = 1'h1;
		end

		8'b01001011:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;
		end

		8'b01001100:
		begin
			freedEntry_t[0] = freedEntry[2].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[6].id;
			writeEn[2]   = 1'h1;
		end

		8'b01001101:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;
		end

		8'b01001110:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;
		end

		8'b01001111:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[2].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[3].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[6].id;
			writeEn[4]   = 1'h1;
		end

		8'b01010000:
		begin
			freedEntry_t[0] = freedEntry[4].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[6].id;
			writeEn[1]   = 1'h1;
		end

		8'b01010001:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[4].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[6].id;
			writeEn[2]   = 1'h1;
		end

		8'b01010010:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[4].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[6].id;
			writeEn[2]   = 1'h1;
		end

		8'b01010011:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;
		end

		8'b01010100:
		begin
			freedEntry_t[0] = freedEntry[2].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[4].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[6].id;
			writeEn[2]   = 1'h1;
		end

		8'b01010101:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;
		end

		8'b01010110:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;
		end

		8'b01010111:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[2].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[4].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[6].id;
			writeEn[4]   = 1'h1;
		end

		8'b01011000:
		begin
			freedEntry_t[0] = freedEntry[3].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[4].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[6].id;
			writeEn[2]   = 1'h1;
		end

		8'b01011001:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;
		end

		8'b01011010:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;
		end

		8'b01011011:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[4].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[6].id;
			writeEn[4]   = 1'h1;
		end

		8'b01011100:
		begin
			freedEntry_t[0] = freedEntry[2].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;
		end

		8'b01011101:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[4].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[6].id;
			writeEn[4]   = 1'h1;
		end

		8'b01011110:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[4].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[6].id;
			writeEn[4]   = 1'h1;
		end

		8'b01011111:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[2].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[3].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[4].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[6].id;
			writeEn[5]   = 1'h1;
		end

		8'b01100000:
		begin
			freedEntry_t[0] = freedEntry[5].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[6].id;
			writeEn[1]   = 1'h1;
		end

		8'b01100001:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[5].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[6].id;
			writeEn[2]   = 1'h1;
		end

		8'b01100010:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[5].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[6].id;
			writeEn[2]   = 1'h1;
		end

		8'b01100011:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;
		end

		8'b01100100:
		begin
			freedEntry_t[0] = freedEntry[2].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[5].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[6].id;
			writeEn[2]   = 1'h1;
		end

		8'b01100101:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;
		end

		8'b01100110:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;
		end

		8'b01100111:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[2].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[6].id;
			writeEn[4]   = 1'h1;
		end

		8'b01101000:
		begin
			freedEntry_t[0] = freedEntry[3].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[5].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[6].id;
			writeEn[2]   = 1'h1;
		end

		8'b01101001:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;
		end

		8'b01101010:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;
		end

		8'b01101011:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[6].id;
			writeEn[4]   = 1'h1;
		end

		8'b01101100:
		begin
			freedEntry_t[0] = freedEntry[2].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;
		end

		8'b01101101:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[6].id;
			writeEn[4]   = 1'h1;
		end

		8'b01101110:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[6].id;
			writeEn[4]   = 1'h1;
		end

		8'b01101111:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[2].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[3].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[5].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[6].id;
			writeEn[5]   = 1'h1;
		end

		8'b01110000:
		begin
			freedEntry_t[0] = freedEntry[4].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[5].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[6].id;
			writeEn[2]   = 1'h1;
		end

		8'b01110001:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[4].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;
		end

		8'b01110010:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[4].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;
		end

		8'b01110011:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[6].id;
			writeEn[4]   = 1'h1;
		end

		8'b01110100:
		begin
			freedEntry_t[0] = freedEntry[2].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[4].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;
		end

		8'b01110101:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[6].id;
			writeEn[4]   = 1'h1;
		end

		8'b01110110:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[6].id;
			writeEn[4]   = 1'h1;
		end

		8'b01110111:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[2].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[4].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[5].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[6].id;
			writeEn[5]   = 1'h1;
		end

		8'b01111000:
		begin
			freedEntry_t[0] = freedEntry[3].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[4].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;
		end

		8'b01111001:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[6].id;
			writeEn[4]   = 1'h1;
		end

		8'b01111010:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[6].id;
			writeEn[4]   = 1'h1;
		end

		8'b01111011:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[4].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[5].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[6].id;
			writeEn[5]   = 1'h1;
		end

		8'b01111100:
		begin
			freedEntry_t[0] = freedEntry[2].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[6].id;
			writeEn[4]   = 1'h1;
		end

		8'b01111101:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[4].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[5].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[6].id;
			writeEn[5]   = 1'h1;
		end

		8'b01111110:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[4].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[5].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[6].id;
			writeEn[5]   = 1'h1;
		end

		8'b01111111:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[2].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[3].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[4].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[5].id;
			writeEn[5]   = 1'h1;

			freedEntry_t[6] = freedEntry[6].id;
			writeEn[6]   = 1'h1;
		end
`endif

`ifdef ISSUE_EIGHT_WIDE
		8'b10000000:
		begin
			freedEntry_t[0] = freedEntry[7].id;
			writeEn[0]   = 1'h1;
		end

		8'b10000001:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[7].id;
			writeEn[1]   = 1'h1;
		end

		8'b10000010:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[7].id;
			writeEn[1]   = 1'h1;
		end

		8'b10000011:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[7].id;
			writeEn[2]   = 1'h1;
		end

		8'b10000100:
		begin
			freedEntry_t[0] = freedEntry[2].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[7].id;
			writeEn[1]   = 1'h1;
		end

		8'b10000101:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[7].id;
			writeEn[2]   = 1'h1;
		end

		8'b10000110:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[7].id;
			writeEn[2]   = 1'h1;
		end

		8'b10000111:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[2].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b10001000:
		begin
			freedEntry_t[0] = freedEntry[3].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[7].id;
			writeEn[1]   = 1'h1;
		end

		8'b10001001:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[7].id;
			writeEn[2]   = 1'h1;
		end

		8'b10001010:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[7].id;
			writeEn[2]   = 1'h1;
		end

		8'b10001011:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b10001100:
		begin
			freedEntry_t[0] = freedEntry[2].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[7].id;
			writeEn[2]   = 1'h1;
		end

		8'b10001101:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b10001110:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b10001111:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[2].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[3].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b10010000:
		begin
			freedEntry_t[0] = freedEntry[4].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[7].id;
			writeEn[1]   = 1'h1;
		end

		8'b10010001:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[4].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[7].id;
			writeEn[2]   = 1'h1;
		end

		8'b10010010:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[4].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[7].id;
			writeEn[2]   = 1'h1;
		end

		8'b10010011:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b10010100:
		begin
			freedEntry_t[0] = freedEntry[2].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[4].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[7].id;
			writeEn[2]   = 1'h1;
		end

		8'b10010101:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b10010110:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b10010111:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[2].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[4].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b10011000:
		begin
			freedEntry_t[0] = freedEntry[3].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[4].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[7].id;
			writeEn[2]   = 1'h1;
		end

		8'b10011001:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b10011010:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b10011011:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[4].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b10011100:
		begin
			freedEntry_t[0] = freedEntry[2].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b10011101:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[4].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b10011110:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[4].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b10011111:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[2].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[3].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[4].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[7].id;
			writeEn[5]   = 1'h1;
		end

		8'b10100000:
		begin
			freedEntry_t[0] = freedEntry[5].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[7].id;
			writeEn[1]   = 1'h1;
		end

		8'b10100001:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[5].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[7].id;
			writeEn[2]   = 1'h1;
		end

		8'b10100010:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[5].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[7].id;
			writeEn[2]   = 1'h1;
		end

		8'b10100011:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b10100100:
		begin
			freedEntry_t[0] = freedEntry[2].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[5].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[7].id;
			writeEn[2]   = 1'h1;
		end

		8'b10100101:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b10100110:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b10100111:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[2].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b10101000:
		begin
			freedEntry_t[0] = freedEntry[3].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[5].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[7].id;
			writeEn[2]   = 1'h1;
		end

		8'b10101001:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b10101010:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b10101011:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b10101100:
		begin
			freedEntry_t[0] = freedEntry[2].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b10101101:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b10101110:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b10101111:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[2].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[3].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[5].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[7].id;
			writeEn[5]   = 1'h1;
		end

		8'b10110000:
		begin
			freedEntry_t[0] = freedEntry[4].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[5].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[7].id;
			writeEn[2]   = 1'h1;
		end

		8'b10110001:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[4].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b10110010:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[4].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b10110011:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b10110100:
		begin
			freedEntry_t[0] = freedEntry[2].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[4].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b10110101:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b10110110:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b10110111:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[2].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[4].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[5].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[7].id;
			writeEn[5]   = 1'h1;
		end

		8'b10111000:
		begin
			freedEntry_t[0] = freedEntry[3].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[4].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b10111001:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b10111010:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b10111011:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[4].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[5].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[7].id;
			writeEn[5]   = 1'h1;
		end

		8'b10111100:
		begin
			freedEntry_t[0] = freedEntry[2].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b10111101:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[4].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[5].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[7].id;
			writeEn[5]   = 1'h1;
		end

		8'b10111110:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[4].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[5].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[7].id;
			writeEn[5]   = 1'h1;
		end

		8'b10111111:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[2].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[3].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[4].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[5].id;
			writeEn[5]   = 1'h1;

			freedEntry_t[6] = freedEntry[7].id;
			writeEn[6]   = 1'h1;
		end

		8'b11000000:
		begin
			freedEntry_t[0] = freedEntry[6].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[7].id;
			writeEn[1]   = 1'h1;
		end

		8'b11000001:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[6].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[7].id;
			writeEn[2]   = 1'h1;
		end

		8'b11000010:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[6].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[7].id;
			writeEn[2]   = 1'h1;
		end

		8'b11000011:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[6].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b11000100:
		begin
			freedEntry_t[0] = freedEntry[2].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[6].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[7].id;
			writeEn[2]   = 1'h1;
		end

		8'b11000101:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[6].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b11000110:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[6].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b11000111:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[2].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b11001000:
		begin
			freedEntry_t[0] = freedEntry[3].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[6].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[7].id;
			writeEn[2]   = 1'h1;
		end

		8'b11001001:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[6].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b11001010:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[6].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b11001011:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b11001100:
		begin
			freedEntry_t[0] = freedEntry[2].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[6].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b11001101:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b11001110:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b11001111:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[2].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[3].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[6].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[7].id;
			writeEn[5]   = 1'h1;
		end

		8'b11010000:
		begin
			freedEntry_t[0] = freedEntry[4].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[6].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[7].id;
			writeEn[2]   = 1'h1;
		end

		8'b11010001:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[4].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[6].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b11010010:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[4].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[6].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b11010011:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b11010100:
		begin
			freedEntry_t[0] = freedEntry[2].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[4].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[6].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b11010101:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b11010110:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b11010111:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[2].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[4].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[6].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[7].id;
			writeEn[5]   = 1'h1;
		end

		8'b11011000:
		begin
			freedEntry_t[0] = freedEntry[3].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[4].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[6].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b11011001:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b11011010:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b11011011:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[4].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[6].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[7].id;
			writeEn[5]   = 1'h1;
		end

		8'b11011100:
		begin
			freedEntry_t[0] = freedEntry[2].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b11011101:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[4].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[6].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[7].id;
			writeEn[5]   = 1'h1;
		end

		8'b11011110:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[4].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[6].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[7].id;
			writeEn[5]   = 1'h1;
		end

		8'b11011111:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[2].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[3].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[4].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[6].id;
			writeEn[5]   = 1'h1;

			freedEntry_t[6] = freedEntry[7].id;
			writeEn[6]   = 1'h1;
		end

		8'b11100000:
		begin
			freedEntry_t[0] = freedEntry[5].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[6].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[7].id;
			writeEn[2]   = 1'h1;
		end

		8'b11100001:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[5].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[6].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b11100010:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[5].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[6].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b11100011:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b11100100:
		begin
			freedEntry_t[0] = freedEntry[2].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[5].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[6].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b11100101:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b11100110:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b11100111:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[2].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[6].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[7].id;
			writeEn[5]   = 1'h1;
		end

		8'b11101000:
		begin
			freedEntry_t[0] = freedEntry[3].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[5].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[6].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b11101001:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b11101010:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b11101011:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[6].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[7].id;
			writeEn[5]   = 1'h1;
		end

		8'b11101100:
		begin
			freedEntry_t[0] = freedEntry[2].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b11101101:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[6].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[7].id;
			writeEn[5]   = 1'h1;
		end

		8'b11101110:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[6].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[7].id;
			writeEn[5]   = 1'h1;
		end

		8'b11101111:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[2].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[3].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[5].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[6].id;
			writeEn[5]   = 1'h1;

			freedEntry_t[6] = freedEntry[7].id;
			writeEn[6]   = 1'h1;
		end

		8'b11110000:
		begin
			freedEntry_t[0] = freedEntry[4].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[5].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[6].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[7].id;
			writeEn[3]   = 1'h1;
		end

		8'b11110001:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[4].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b11110010:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[4].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b11110011:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[6].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[7].id;
			writeEn[5]   = 1'h1;
		end

		8'b11110100:
		begin
			freedEntry_t[0] = freedEntry[2].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[4].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b11110101:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[6].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[7].id;
			writeEn[5]   = 1'h1;
		end

		8'b11110110:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[6].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[7].id;
			writeEn[5]   = 1'h1;
		end

		8'b11110111:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[2].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[4].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[5].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[6].id;
			writeEn[5]   = 1'h1;

			freedEntry_t[6] = freedEntry[7].id;
			writeEn[6]   = 1'h1;
		end

		8'b11111000:
		begin
			freedEntry_t[0] = freedEntry[3].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[4].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[5].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[6].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[7].id;
			writeEn[4]   = 1'h1;
		end

		8'b11111001:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[6].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[7].id;
			writeEn[5]   = 1'h1;
		end

		8'b11111010:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[6].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[7].id;
			writeEn[5]   = 1'h1;
		end

		8'b11111011:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[4].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[5].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[6].id;
			writeEn[5]   = 1'h1;

			freedEntry_t[6] = freedEntry[7].id;
			writeEn[6]   = 1'h1;
		end

		8'b11111100:
		begin
			freedEntry_t[0] = freedEntry[2].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[3].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[4].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[5].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[6].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[7].id;
			writeEn[5]   = 1'h1;
		end

		8'b11111101:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[4].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[5].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[6].id;
			writeEn[5]   = 1'h1;

			freedEntry_t[6] = freedEntry[7].id;
			writeEn[6]   = 1'h1;
		end

		8'b11111110:
		begin
			freedEntry_t[0] = freedEntry[1].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[2].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[3].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[4].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[5].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[6].id;
			writeEn[5]   = 1'h1;

			freedEntry_t[6] = freedEntry[7].id;
			writeEn[6]   = 1'h1;
		end

		8'b11111111:
		begin
			freedEntry_t[0] = freedEntry[0].id;
			writeEn[0]   = 1'h1;

			freedEntry_t[1] = freedEntry[1].id;
			writeEn[1]   = 1'h1;

			freedEntry_t[2] = freedEntry[2].id;
			writeEn[2]   = 1'h1;

			freedEntry_t[3] = freedEntry[3].id;
			writeEn[3]   = 1'h1;

			freedEntry_t[4] = freedEntry[4].id;
			writeEn[4]   = 1'h1;

			freedEntry_t[5] = freedEntry[5].id;
			writeEn[5]   = 1'h1;

			freedEntry_t[6] = freedEntry[6].id;
			writeEn[6]   = 1'h1;

			freedEntry_t[7] = freedEntry[7].id;
			writeEn[7]   = 1'h1;
		end
`endif
	endcase
end
`endif //RANGEEN_TRIAL

endmodule
