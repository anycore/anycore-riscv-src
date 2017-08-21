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


/* Algorithm

   1. Receive upto 4 instruction (commited) from Active List to update the
      new mapping in AMT.

   2. IMP: In the commit window if the multiple	instructions' logical
      destination are same, only the youngest commiting instruction would
      update the AMT.
      The older instructions' physical mapping would be released to the free
      list.

      //TODO: Might need to change from 4 to number of active RMT write ports
   2. If there is a recovery because of control mis-predict or exception
      (as indicated by Active List), AMT mapping are read in a group of 4
      and sent to RMT for updation.

   3. In a cycle 4 AMT entries are sent because RMT is restricted with only
      4 write ports.
***************************************************************************/


module ArchMapTable(

	input                                          clk,
	input                                          reset,
	input                                          resetRams_i,

`ifdef DYNAMIC_CONFIG  
  input [`COMMIT_WIDTH-1:0]                      commitLaneActive_i,
`endif  

	input  [`SIZE_RMT_LOG-1:0]                     debugAMTAddr_i,
	output [`SIZE_PHYSICAL_LOG-1:0]                debugAMTRdData_o,

	input  commitPkt                               amtPacket_i [0:`COMMIT_WIDTH-1],

	/* Release the old physical map to be inserted into speculative free list. */
	output phys_reg                                freedPhyReg_o  [0:`COMMIT_WIDTH-1],

	/* From ActiveList if there is a load violation or branch misprediction */
	input                                          recoverFlag_i,

	/* From ActiveList if there is an exception */
	input                                          exceptionFlag_i,
`ifdef DYNAMIC_CONFIG  
	input					                                 consolidateFlag_i,
	input  [`SIZE_RMT_LOG-1:0]		                 logAddr_i,
	output [`SIZE_PHYSICAL_LOG-1:0]		             phyAddr_o,
`endif  
	output                                         repairFlag_o,
	output [`SIZE_RMT_LOG-1:0]                     repairAddr_o [0:`N_REPAIR_PACKETS-1],
	output [`SIZE_PHYSICAL_LOG-1:0]                repairData_o [0:`N_REPAIR_PACKETS-1],

  output                                         amtRamReady_o
);


/*  Followinig declares counter for recovery.*/
// Counter size must be 1 bit longer than SIZE_RMT_LOG for 
// the worst case of 1 packet per cycle to prevent overflow and 
// infinite repair state machine.
reg  [`SIZE_RMT_LOG:0]                 repairCounter; 
reg                                    repairFlag;

/*  regs and wires declaration for combinational logic. */
reg                                    dontWriteAMT [0:`COMMIT_WIDTH-1];

reg  [`SIZE_RMT_LOG-1:0]               repairAddr  [0:`N_REPAIR_PACKETS-1];
`ifdef DYNAMIC_CONFIG  
reg  [`SIZE_RMT_LOG-1:0]               repairAddr_0 ;
reg  [`SIZE_RMT_LOG-1:0]               repairAddr_tmp  [0:`N_REPAIR_PACKETS-1];
`endif  
wire [`SIZE_PHYSICAL_LOG-1:0]          data        [0:`COMMIT_WIDTH-1];


/************************************************************************************
* Following instantiates RAM modules for Architectural Map Table. The read and
* write ports depend on the commit width of the processor.
*
* The write address is always logical destination of the committing instruction.
* The read address could be either logical destination of the committing instruction
* in the normal operation or "repairCounter" in the case of exception.
************************************************************************************/

//// BIST State Machine to Initialize RAM/CAM /////////////

localparam BIST_SIZE_ADDR   = `SIZE_RMT_LOG;
localparam BIST_SIZE_DATA   = `SIZE_PHYSICAL_LOG;
localparam BIST_NUM_ENTRIES = `SIZE_RMT;
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

assign amtRamReady_o = ~bistEn;

always_ff @(posedge clk or posedge resetRams_i)
begin
  if(resetRams_i)
  begin
    bistState       <= BIST_START;
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

AMT_RAM #(
  .RPORT        (`COMMIT_WIDTH),
  .WPORT        (`COMMIT_WIDTH),
	.DEPTH        (`SIZE_RMT),
	.INDEX        (`SIZE_RMT_LOG),
	.WIDTH        (`SIZE_PHYSICAL_LOG),
	.N_PACKETS    (`N_REPAIR_PACKETS)
	)

	AMT (

`ifdef DYNAMIC_CONFIG    
  .repairFlag_i (repairFlag || consolidateFlag_i), // Used to MUX rd ports between normal read and repair read
	.repairAddr_i (repairAddr_tmp),
`else
  .repairAddr_i (repairAddr),
`endif 
 
	.repairData_o (repairData_o),

	.addr0_i      (amtPacket_i[0].logDest),
	.data0_o      (data[0]),

	.we0_i        (bistEn ? 1'b1       : amtPacket_i[0].valid && ~dontWriteAMT[0]),
	.addr0wr_i    (bistEn ? bistAddrWr : amtPacket_i[0].logDest),
	.data0wr_i    (bistEn ? bistDataWr : amtPacket_i[0].phyDest),

`ifdef COMMIT_TWO_WIDE
	.addr1_i      (amtPacket_i[1].logDest),
	.data1_o      (data[1]),

	.we1_i        (amtPacket_i[1].valid && ~dontWriteAMT[1]),
	.addr1wr_i    (amtPacket_i[1].logDest),
	.data1wr_i    (amtPacket_i[1].phyDest),
`endif  

`ifdef COMMIT_THREE_WIDE
	.addr2_i      (amtPacket_i[2].logDest),
	.data2_o      (data[2]),

	.we2_i        (amtPacket_i[2].valid && ~dontWriteAMT[2]),
	.addr2wr_i    (amtPacket_i[2].logDest),
	.data2wr_i    (amtPacket_i[2].phyDest),
`endif  

`ifdef COMMIT_FOUR_WIDE
	.addr3_i      (amtPacket_i[3].logDest),
	.data3_o      (data[3]),

	.we3_i        (amtPacket_i[3].valid),
	.addr3wr_i    (amtPacket_i[3].logDest),
	.data3wr_i    (amtPacket_i[3].phyDest),
`endif

`ifdef DYNAMIC_CONFIG
  .commitLaneActive_i (commitLaneActive_i),
  .amtReady_o (),
`endif

`ifdef AMT_DEBUG_PORT
	.debugAMTAddr_i(debugAMTAddr_i),
	.debugAMTRdData_o(debugAMTRdData_o),
`endif

	.clk        (clk),
	//.reset      (reset | exceptionFlag_i)
	.reset      (reset)
	);

`ifdef DYNAMIC_CONFIG
assign repairAddr_0 = consolidateFlag_i ? logAddr_i : repairAddr[0];
assign phyAddr_o    = repairData_o[0];

always_comb 
begin
  int i ;
  repairAddr_tmp[0] = repairAddr_0;
  for (i = 1; i < `N_REPAIR_PACKETS ; i++)
  begin
  repairAddr_tmp[i] = repairAddr[i];
  end
end
`endif

/*  Logic to select the physical register to be released this cycle.  */
// Registering this to meet timing. Basically freeing in the next cycles.
// The register freeing is again bottlenecked by the number of write ports in freelist.
// RBRC Sept 9, 2014
always_comb
begin
	int i;
	for (i = 0; i < `COMMIT_WIDTH; i++)
  begin
  	freedPhyReg_o[i].valid  = amtPacket_i[i].valid;
		freedPhyReg_o[i].reg_id = (dontWriteAMT[i]) ? amtPacket_i[i].phyDest: data[i];
  end
end
//always_ff @(posedge clk or posedge reset)
//begin
//	int i;
//  if(reset)
//  begin
//	  for (i = 0; i < `COMMIT_WIDTH; i++)
//  	  freedPhyReg_o[i]  <= 0;
//  end
//  else
//	begin
//	  for (i = 0; i < `COMMIT_WIDTH; i++)
//    begin
//  		freedPhyReg_o[i].valid  <= amtPacket_i[i].valid;
//	  	freedPhyReg_o[i].reg_id <= (dontWriteAMT[i]) ? amtPacket_i[i].phyDest: data[i];
//    end
//	end
//end


///////////////////////////////////////////////////////////////


/*  Check if destination of an instruction matches with destination of the newer
 *  instruction in the commit window. If there is a match then this instruction
 *  doesn't update the AMT and is released to be written to speculative free list.
 */
always_comb
begin:CHECK_DESTINATION_REG
	int i;
	reg match_0_1;
	reg match_0_2;
	reg match_0_3;
	reg match_1_2;
	reg match_1_3;
	reg match_2_3;

	match_0_1 = 0;
	match_0_2 = 0;
	match_0_3 = 0;
	match_1_2 = 0;
	match_1_3 = 0;
	match_2_3 = 0;

`ifdef COMMIT_TWO_WIDE  
	match_0_1 = (amtPacket_i[0].logDest == amtPacket_i[1].logDest) && amtPacket_i[1].valid;
`endif  

`ifdef COMMIT_THREE_WIDE
	match_0_2 = (amtPacket_i[0].logDest == amtPacket_i[2].logDest) && amtPacket_i[2].valid;
	match_1_2 = (amtPacket_i[1].logDest == amtPacket_i[2].logDest) && amtPacket_i[2].valid;
`endif

`ifdef COMMIT_FOUR_WIDE
	match_0_3 = (amtPacket_i[0].logDest == amtPacket_i[3].logDest) && amtPacket_i[3].valid;
	match_1_3 = (amtPacket_i[1].logDest == amtPacket_i[3].logDest) && amtPacket_i[3].valid;
	match_2_3 = (amtPacket_i[2].logDest == amtPacket_i[3].logDest) && amtPacket_i[3].valid;
`endif

	for (i = 0; i < `COMMIT_WIDTH; i++)
	begin
		dontWriteAMT[i] = 0;
	end

`ifdef COMMIT_TWO_WIDE  
	if (match_0_1 | match_0_2 | match_0_3)
		dontWriteAMT[0] = 1;
`endif

`ifdef COMMIT_THREE_WIDE
	if (match_1_2 | match_1_3)
		dontWriteAMT[1] = 1;
`endif

`ifdef COMMIT_FOUR_WIDE
	if (match_2_3)
		dontWriteAMT[2] = 1;
`endif
end

///////////////////////////////////////////////////////////////

/* Repair the RMT to match the AMT. Send `N_REPAIR_PACKETS
 * logical-to-physical register mappings to the RMT each cycle.
 * Stop when all logical registers have been sent. 
 * The AMT/RMT is broken into segments. The size of each segment is determined by
 * N_REPAIR_PACKETS. In particular, the segment size is
 * ceil(34/N_REPAIR_PACKETS). Each repair packet starts at the start of
 * a segment and increases by one each cycle. After N_REPAIR_CYCLES each of
 * the segments should be fully copied from the AMT to the RMT. */
reg                                    repairState;
reg                                    repairState_next;

localparam IDLE                      = 1'h0;
localparam REPAIR                    = 1'h1;

/* The starting address of each segment */
reg  [5:0]                             segmentBase [0:`N_REPAIR_PACKETS-1];

/* Increments or clears the counter at posedge */
reg                                    incCounter;
reg                                    clearCounter;

always_comb
begin
	repairState_next                   = IDLE;
	repairFlag                         = 1'h0;
	incCounter                         = 1'h0;
	clearCounter                       = 1'h0;
	
	case (repairState)

		IDLE:
		begin
			repairState_next               = IDLE;

			/* Start repairing the RMT this cycle */
			if (recoverFlag_i | exceptionFlag_i)
			begin
				repairState_next             = REPAIR;
				repairFlag                   = 1'h1;
				incCounter                   = 1'h1;
			end
		end

		REPAIR:
		begin
			repairState_next               = REPAIR;
			incCounter                     = 1'h1;
			repairFlag                     = 1'h1;

			if (repairCounter == `N_REPAIR_CYCLES)
			begin
				repairState_next             = IDLE;
				clearCounter                 = 1'h1;
			end
		end
	endcase
end


always_ff @(posedge clk)
begin
	if (reset)
	begin
		repairState                     <= IDLE;
	end

	else
	begin
		repairState                     <= repairState_next;
	end
end


// NOTE: Using async reset as synthesis screws up logic generation
// for synchronous reset
// RBRC: 07/03/2013
always_ff @(posedge clk or posedge reset)
begin
	if (reset)
	begin
		repairCounter                   <= 0;
	end

	else 
    if (clearCounter)
    begin
		  repairCounter                   <= 0;
    end
    else if (incCounter)
	  begin
		  repairCounter                   <= repairCounter + 1;
	  end
end

assign repairFlag_o                  = repairFlag;
assign repairAddr_o                  = repairAddr;


/* Each repairAddr starts at the beginning of a segment and copies one entry
 * over per cycle */
always_comb
begin
	int i;
	for (i = 0; i < `N_REPAIR_PACKETS; i++)
	begin
	    segmentBase[i]                  = i*(`N_REPAIR_CYCLES);
	    repairAddr[i]                   = segmentBase[i] + repairCounter;
	end
end


endmodule
