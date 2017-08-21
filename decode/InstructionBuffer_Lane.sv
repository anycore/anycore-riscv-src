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


module InstructionBufferLane(
	input                                 clk,
	input                                 reset,

`ifdef DYNAMIC_CONFIG  
  input  [`FETCH_WIDTH-1:0]             fetchLaneActive_i,
  input  [`DISPATCH_WIDTH-1:0]          dispatchLaneActive_i,
  input  [`STRUCT_PARTS-1:0]            ibuffPartitionActive_i,
  output                                ibuffInsufficientCnt_o,
`endif  

	/* flush_i signal indicates that there is Control misprediction
	* and instBuffer has to flush all its entries.
	*/
	input                                 flush_i,

	/* stall_i is the signal from the further stages to indicate
	* either physical registers or issue queue or Active List are
	* full and can't accept more instructions.
	*/
	input                                 stall_i,

  /* stallFetch_i is the signal from Power manager
  *  and prevents the instructions to be written
  *  into the buffer so that the backend and instr
  *  buffer can drain out and reconfiguration can be
  *  applied.
  *  RBRC
  */
  input                                 stallFetch_i,

	input                                 decodeReady_i,

	input  renPkt                         ibPacket_i [0:2*`FETCH_WIDTH-1],

	/* instBufferFull_o is the signal for FetchStage1 and FetchStage2 if
	* the instBuffer doesn't have enough space to store 4 (Fetch Bandwidth)
	* instructions.
	*/
	output                                instBufferFull_o,

  // Goes to Dispatch indicating sufficient number of instructions in the buffer
	output reg                            instBufferReady_o,
`ifdef PERF_MON
  output [`INST_QUEUE_LOG:0]            instCount_o,
`endif
	output renPkt                         renPacket_o [0:`DISPATCH_WIDTH-1]
	);


/* This defines the Fetch Queue, which decouples instruction fetch and
   decode stage by a circular queue */
reg  [`INST_QUEUE_LOG-1:0]              headPtr;
reg  [`INST_QUEUE_LOG-1:0]              tailPtr;
// RBRC: Jul 18, 13 - Should be 1 bit longer in order to 
// hold numbers equal to ibuff size and higher
reg  [`INST_QUEUE_LOG:0]                headPtr_next;
reg  [`INST_QUEUE_LOG:0]                tailPtr_next;

/* Following counts the number of waiting instructions in the instBuffer.*/
reg  [`INST_QUEUE_LOG:0]                instCount;


/* wires and regs definition for combinational logic. */
reg  [`INST_QUEUE_LOG:0]                instCount_f;

reg  [`INST_QUEUE_LOG-1:0]              rdAddr      [0:`DISPATCH_WIDTH-1];
reg  [`INST_QUEUE_LOG-1:0]              wrAddr     [0:2*`FETCH_WIDTH-1];
reg                                     wrEn   [0:2*`FETCH_WIDTH-1];

wire                                    instBufferFull;



/* Following instantiate multiported FIFO for Instruction Buffer. */

IBUFF_RAM #(
	.DEPTH       (`INST_QUEUE),
	.INDEX       (`INST_QUEUE_LOG),
	.WIDTH       (`REN_PKT_SIZE)
	)
	instBuffer(

	.addr0_i     (rdAddr[0]),
	.data0_o     (renPacket_o[0]),

`ifdef DISPATCH_TWO_WIDE
	.addr1_i     (rdAddr[1]),
	.data1_o     (renPacket_o[1]),
`endif

`ifdef DISPATCH_THREE_WIDE
	.addr2_i     (rdAddr[2]),
	.data2_o     (renPacket_o[2]),
`endif

`ifdef DISPATCH_FOUR_WIDE
	.addr3_i     (rdAddr[3]),
	.data3_o     (renPacket_o[3]),
`endif

`ifdef DISPATCH_FIVE_WIDE
	.addr4_i     (rdAddr[4]),
	.data4_o     (renPacket_o[4]),
`endif

`ifdef DISPATCH_SIX_WIDE
	.addr5_i     (rdAddr[5]),
	.data5_o     (renPacket_o[5]),
`endif

`ifdef DISPATCH_SEVEN_WIDE
	.addr6_i     (rdAddr[6]),
	.data6_o     (renPacket_o[6]),
`endif

`ifdef DISPATCH_EIGHT_WIDE
	.addr7_i     (rdAddr[7]),
	.data7_o     (renPacket_o[7]),
`endif


	.we0_i       (wrEn[0]),
	.addr0wr_i   (wrAddr[0]),
	.data0wr_i   (ibPacket_i[0]),

	.we1_i       (wrEn[1]),
	.addr1wr_i   (wrAddr[1]),
	.data1wr_i   (ibPacket_i[1]),

`ifdef FETCH_TWO_WIDE
	.we2_i       (wrEn[2]),
	.addr2wr_i   (wrAddr[2]),
	.data2wr_i   (ibPacket_i[2]),

	.we3_i       (wrEn[3]),
	.addr3wr_i   (wrAddr[3]),
	.data3wr_i   (ibPacket_i[3]),
`endif

`ifdef FETCH_THREE_WIDE
	.we4_i       (wrEn[4]),
	.addr4wr_i   (wrAddr[4]),
	.data4wr_i   (ibPacket_i[4]),

	.we5_i       (wrEn[5]),
	.addr5wr_i   (wrAddr[5]),
	.data5wr_i   (ibPacket_i[5]),
`endif

`ifdef FETCH_FOUR_WIDE
	.we6_i       (wrEn[6]),
	.addr6wr_i   (wrAddr[6]),
	.data6wr_i   (ibPacket_i[6]),

	.we7_i       (wrEn[7]),
	.addr7wr_i   (wrAddr[7]),
	.data7wr_i   (ibPacket_i[7]),
`endif

`ifdef FETCH_FIVE_WIDE
	.we8_i       (wrEn[8]),
	.addr8wr_i   (wrAddr[8]),
	.data8wr_i   (ibPacket_i[8]),

	.we9_i       (wrEn[9]),
	.addr9wr_i   (wrAddr[9]),
	.data9wr_i   (ibPacket_i[9]),
`endif

`ifdef FETCH_SIX_WIDE
	.we10_i      (wrEn[10]),
	.addr10wr_i  (wrAddr[10]),
	.data10wr_i  (ibPacket_i[10]),

	.we11_i      (wrEn[11]),
	.addr11wr_i  (wrAddr[11]),
	.data11wr_i  (ibPacket_i[11]),
`endif

`ifdef FETCH_SEVEN_WIDE
	.we12_i      (wrEn[12]),
	.addr12wr_i  (wrAddr[12]),
	.data12wr_i  (ibPacket_i[12]),

	.we13_i      (wrEn[13]),
	.addr13wr_i  (wrAddr[13]),
	.data13wr_i  (ibPacket_i[13]),
`endif

`ifdef FETCH_EIGHT_WIDE
	.we14_i      (wrEn[14]),
	.addr14wr_i  (wrAddr[14]),
	.data14wr_i  (ibPacket_i[14]),

	.we15_i      (wrEn[15]),
	.addr15wr_i  (wrAddr[15]),
	.data15wr_i  (ibPacket_i[15]),
`endif

`ifdef DYNAMIC_CONFIG
  .fetchLaneActive_i(fetchLaneActive_i),
  .dispatchLaneActive_i(dispatchLaneActive_i),
  .ibuffPartitionActive_i(ibuffPartitionActive_i),
  .ibuffRamReady_o(),
`endif

	.clk         (clk),
	.reset       (reset | flush_i)
	);


// Counting the number of active DISPATCH lanes
// Should be 1 bit wider as it should hold values from 1 to `DISPATCH_WIDTH
// RBRC
reg [`DISPATCH_WIDTH_LOG:0] numDispatchLaneActive;
reg [`FETCH_WIDTH_LOG:0]    numFetchLaneActive;
reg [`INST_QUEUE_LOG:0] ibuffSize;
always_comb
begin

`ifdef DYNAMIC_CONFIG    
  int i;
  numDispatchLaneActive = 0;
  numFetchLaneActive    = 0;

  for(i = 0; i < `DISPATCH_WIDTH; i++)
    numDispatchLaneActive = numDispatchLaneActive + dispatchLaneActive_i[i];

  for(i = 0; i < `FETCH_WIDTH; i++)
    numFetchLaneActive = numFetchLaneActive + fetchLaneActive_i[i];


  case(ibuffPartitionActive_i)
    4'b1111:ibuffSize = `INST_QUEUE;
    4'b0111:ibuffSize = `INST_QUEUE - (`INST_QUEUE/4);
    4'b0011:ibuffSize = `INST_QUEUE/2;
    4'b0001:ibuffSize = `INST_QUEUE/4;
    default:ibuffSize = `INST_QUEUE;
  endcase

`else
  numDispatchLaneActive = `DISPATCH_WIDTH;  // Constant and logic will be optimized
  numFetchLaneActive    = `FETCH_WIDTH;     // Constant and logic will be optimized
  ibuffSize = `INST_QUEUE;
`endif

end

`ifdef DYNAMIC_CONFIG
  // Indicates that only residual instructions < dispatch bundle size
  // are held in instruction buffer and it might be safe to reconfigure,
  // depending upon other conditions off course.
  assign ibuffInsufficientCnt_o = (instCount < numDispatchLaneActive) & // Ibuff does not have sufficient instructions
                                  (instCount_f < numDispatchLaneActive);// Sufficient instructions are not being written this cycle
`endif



/* Following reads the instBuffer and CtrlTagQueue from the HEAD if the count
 * of instructions is more than "DISPATCH_WIDTH-1".
 */
assign instBufferReady_o  = ((instCount >= numDispatchLaneActive) &&
                             (~stall_i))                     ? 1 : 0;


/* Following updates the head pointer if there is no stall signal from the
 * further stages.
 * If there is no stall from the later stages and there is atleast DISPATCH_WIDTH
 * instructions in the buffer, headPtr is increamented by DISPATCH_WIDTH;
 */
// LANE: Monolithic Logic
always_comb
begin

  headPtr_next = headPtr;

	if (~stall_i & (instCount >= numDispatchLaneActive))
	begin
		headPtr_next  = headPtr_next + numDispatchLaneActive;
	end

  // Explicit wrap around logic to support arbitrary size
  if(headPtr_next >= ibuffSize)
  begin
    headPtr_next = headPtr_next - ibuffSize;
  end

end

// RBRC: Using asynchronous reset to avoid synthesis issue
always_ff @(posedge clk or posedge reset)
begin
  if(reset)
  begin
    headPtr <= 0;
  end
  else
  begin
    if(flush_i)
    begin
      headPtr <=  0;
    end
    else
    begin
      headPtr <=  headPtr_next;
    end
  end
end



/* Following writes the instBuffer from the TAIL if the count of instructions
 * is less than "INST_QUEUE-2*FETCH_WIDTH+1" as in any cycle 2*FETCH_WIDTH
 * number of instructions can be written from Decode due to fission instructions*/
// Fixed on Apr 29, RBRC (Was 2*`DISPATCH_WIDTH previously)
// ibuffSize is constant in case of STATIC config
assign instBufferFull    = (instCount > (ibuffSize-2*numFetchLaneActive)) ? 1:0;
assign instBufferFull_o  =  instBufferFull;

/* Following generates addresses and write enable to write in the instruction
 * buffer from the tail pointer. */
// TODO: This is also a ladder type of logic. 
// Try to come up with a better logic if possible
// LANE: Per Lane logic  
always_comb
begin
	int i;
  // Need the following register (1 bit longer) for explicit wrap around logic
  reg  [`INST_QUEUE_LOG:0]              wrAddr_t     [0:2*`FETCH_WIDTH-1];

	wrAddr[0]   = tailPtr;
  wrAddr_t[0] = tailPtr;
	wrEn[0] = decodeReady_i & ibPacket_i[0].valid  & ~instBufferFull & ~stallFetch_i;

	for (i = 1; i < 2*`FETCH_WIDTH; i = i + 1)
	begin
		if (ibPacket_i[i-1].valid)
		begin
			wrAddr_t[i] = wrAddr_t[i-1] + 1;
		end

		else
		begin
			wrAddr_t[i] = wrAddr_t[i-1];
		end

    // Explicit wrap around logic to enable use of arbitrary size
    wrAddr[i] = wrAddr_t[i];
    if(wrAddr_t[i] >= ibuffSize)
      wrAddr[i] = wrAddr_t[i] - ibuffSize;
    // NOTE Nov 11 : Modified to break the critical path
    //  wrAddr_t[i] = wrAddr_t[i] - ibuffSize;

    //wrAddr[i] = wrAddr_t[i];
		wrEn[i] = decodeReady_i & ibPacket_i[i].valid  & ~instBufferFull & ~stallFetch_i;
	end
end

// TODO: Terrible logic. Can be improved
/* Following updates the tail pointer every cycle. */
// LANE: Monolithic logic
always_comb
begin
	int i;

	tailPtr_next = tailPtr;

	for (i = 0; i < 2*`FETCH_WIDTH; i = i + 1)
	begin
		tailPtr_next = tailPtr_next + wrEn[i];
	end

  // Explicit wrap around logic to support arbitrary size
  if(tailPtr_next >= ibuffSize)
    tailPtr_next = tailPtr_next - ibuffSize;
end


// RBRC: Using asynchronous reset to avoid synthesis issue
always_ff @(posedge clk or posedge reset)
begin
  if(reset)
  begin
		tailPtr <= 0;
  end
  else
  begin
	  if (flush_i)
	  begin
	  	tailPtr <= 0;
	  end

	  else
	  begin
	  	tailPtr <= tailPtr_next;
	  end
  end
end



/* Following updates the number of valid instructions in the instBuffer. The instruction
   count is updated based on incoming valid instructions and outgoing instructions.

   case1: upto DISPATCH_WIDTH instructions coming to buffer and DISPATCH_WIDTH instructions
          leaving from buffer (ideal case!!)

   case2: No instruction coming to buffer and DISPATCH_WIDTH instructions leaving from
          buffer

   case3: upto DISPATCH_WIDTH instructions coming to buffer and no instruction leaving buffer

   case4: No instruction coming to buffer and no instruction leaving buffer
*/
// LANE: Monolithic logic
always_comb
begin : UPDATE_INST_COUNT
	int i;
	//reg [`INST_QUEUE_LOG:0] instcnt_1;

	//instcnt_1 = instCount;
	instCount_f = instCount;

	if (decodeReady_i & ~instBufferFull & ~stallFetch_i)
	begin

		for (i = 0; i < 2*`FETCH_WIDTH; i = i + 1)
		begin
			instCount_f = instCount_f + ibPacket_i[i].valid;
		end
	end

  if(instBufferReady_o)
	begin
		instCount_f = instCount_f - numDispatchLaneActive;
	end

//	else
//	begin
//		instCount_f = instcnt_1;
//	end
end


// RBRC: Sept 2, 2013 - Using async reset
always_ff @(posedge clk or posedge reset)
begin
	if (reset)
	begin
		instCount <= 0;
	end

	else
	begin
    if(flush_i)
		  instCount <= 0;
    else
		  instCount <= instCount_f;
	end
end


// NOTE: Need not be changed to numDispatchLaneActive as 
// headPtr update logic takes care of updating correctly
// RBRC
// LANE: Per lane logic
always_comb
begin
	int i;
  // Need the following register for explicit wrap around logic
  reg  [`INST_QUEUE_LOG:0]              rdAddr_t     [0:`DISPATCH_WIDTH-1];

	for (i = 0; i < `DISPATCH_WIDTH; i = i + 1)
	begin
		rdAddr_t[i]    = headPtr + i;

    // Explicit wrap around logic to enable use of arbitrary size
    if(rdAddr_t[i] >= ibuffSize)
      rdAddr_t[i] = rdAddr_t[i] - ibuffSize;

    rdAddr[i] = rdAddr_t[i];
	end
end

`ifdef PERF_MON
assign instCount_o = instCount ;
`endif

endmodule
