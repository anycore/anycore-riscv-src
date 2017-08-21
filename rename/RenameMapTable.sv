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

/***************************************************************************
  The Register Map Table (RMT) conatins the current logical register to
  physical register mapping.

  For each set of instructions in Rename stage the physical source register
  mapping is obtained by reading the RMT and the physical destination
  register mapping is obtained by reading the Free List table.
  Eventually, the new logical destination register and physical register
  mapping is updated in the RMT for the future set of the instructions.

  During an RMT recovery, N_REPAIR_PACKETS packets, each containing one log->phy 
  register mapping from the Architecture Map Table (AMT), repair the RMT. 
  Appropriate ports have been provided for the recovery purpose.

***************************************************************************/

/* Renaming

 1. Receive 0 or DISPATCH_WIDTH (or numDispatchLaneActive) decoded instructions from the instruction buffer

 2. Pop a physical register from the SpecFreeList for each valid logDest. 
    If the list is empty, pipeline stages between the instruction buffer and  
    rename are stalled.

 3. Rename the logSrc registers. 
    3a) Read the log->phy mapping from the RMT
    3b) Compare each valid logSrc with the older logDests in the bundle
    3c) Use the youngest mapping if a match was found in b). Else, use a)

 4. Update the RMT with the logDest->phyDest mappings.
    4a) Compare each valid logDest in the bundle and assign one phyDest to each valid logDest
    4b) Update the RMT with the youngest mapping for each logical dest value. 

***************************************************************************/

`timescale 1ns/100ps

module RenameMapTable(
	input                            clk,
	input                            reset,
	input                            resetRams_i,

`ifdef DYNAMIC_CONFIG  
  input [`DISPATCH_WIDTH-1:0]      dispatchLaneActive_i,
`endif  

	input                            stall_i,

	/* All instructions are flushed from the pipeline when
	 * recoverFlag_i is high. */
	input                            recoverFlag_i,

	/* Repair the RMT to the state of the AMT while repairFlag_i is high */
	input                            repairFlag_i,
	input  [`SIZE_RMT_LOG-1:0]       repairAddr_i [0:`N_REPAIR_PACKETS-1],
	input  [`SIZE_PHYSICAL_LOG-1:0]  repairData_i [0:`N_REPAIR_PACKETS-1],

	input  log_reg                   logDest_i   [0:`DISPATCH_WIDTH-1],
	input  log_reg                   logSrc1_i   [0:`DISPATCH_WIDTH-1],
	input  log_reg                   logSrc2_i   [0:`DISPATCH_WIDTH-1],

	input  [`SIZE_PHYSICAL_LOG-1:0]  free_phys_i [0:`DISPATCH_WIDTH-1],

	output phys_reg                  phyDest_o   [0:`DISPATCH_WIDTH-1],
	output phys_reg                  phySrc1_o   [0:`DISPATCH_WIDTH-1],
	output phys_reg                  phySrc2_o   [0:`DISPATCH_WIDTH-1],

  output                           rmtRamReady_o
	);

/* wires and regs definition for combinational logic. */
`ifdef DYNAMIC_CONFIG
  wire  [`SIZE_PHYSICAL_LOG-1:0]  phyDest         [0:`DISPATCH_WIDTH-1];
  wire  [`SIZE_PHYSICAL_LOG-1:0]  phySrc1         [0:`DISPATCH_WIDTH-1];
  wire  [`SIZE_PHYSICAL_LOG-1:0]  phySrc2         [0:`DISPATCH_WIDTH-1];
      
  wire                            dontWriteRMT    [0:`DISPATCH_WIDTH-1];
`else
  reg  [`SIZE_PHYSICAL_LOG-1:0]  phyDest         [0:`DISPATCH_WIDTH-1];
  reg  [`SIZE_PHYSICAL_LOG-1:0]  phySrc1         [0:`DISPATCH_WIDTH-1];
  reg  [`SIZE_PHYSICAL_LOG-1:0]  phySrc2         [0:`DISPATCH_WIDTH-1];
   
  reg                            dontWriteRMT    [0:`DISPATCH_WIDTH-1];
`endif

reg                            writeEn         [0:`DISPATCH_WIDTH-1];

//wire                           rmt_we          [0:3];
wire [`SIZE_PHYSICAL_LOG-1:0]  rmt_data        [0:3];
wire [`SIZE_RMT_LOG-1:0]       rmt_addr        [0:3];



/* Following defines wires for checking true dependencies between
 * the source and preceding destination registers. */
wire [`SIZE_PHYSICAL_LOG-1:0]  rmtMapping1     [0:`DISPATCH_WIDTH-1];
wire [`SIZE_PHYSICAL_LOG-1:0]  rmtMapping2     [0:`DISPATCH_WIDTH-1];



/*******************************************************************************
* Following instantiates RAM modules for Rename Map Table. The read and
* write ports depend on the commit width of the processor.
*
* An instruction updates the RMT only if it has valid destination register and
* it does not matches with destination register of the newer instruction in the
* same window.
*******************************************************************************/

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

assign rmtRamReady_o = ~bistEn;

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

RMT_RAM #(
  .RPORT      (2*`DISPATCH_WIDTH),
  .WPORT      (`DISPATCH_WIDTH),
	.DEPTH      (`SIZE_RMT),
	.INDEX      (`SIZE_RMT_LOG),
	.WIDTH      (`SIZE_PHYSICAL_LOG),
	.N_PACKETS  (`N_REPAIR_PACKETS)
	)

	RenameMap (


//	.repairFlag_i (repairFlag_i),
//	.repairAddr_i (repairAddr_i),
//	.repairData_i (repairData_i),

	.addr0_i      (logSrc1_i[0].reg_id),
	.data0_o      (rmtMapping1[0]),
               
	.addr1_i      (logSrc2_i[0].reg_id),
	.data1_o      (rmtMapping2[0]),

	.we0_i        (bistEn ? 1'b1       : (repairFlag_i ? 1'b1 : writeEn[0])),
	.addr0wr_i    (bistEn ? bistAddrWr : (repairFlag_i ? repairAddr_i[0] : logDest_i[0].reg_id)),
	.data0wr_i    (bistEn ? bistDataWr : (repairFlag_i ? repairData_i[0] : phyDest[0])),

`ifdef DISPATCH_TWO_WIDE
	.addr2_i    (logSrc1_i[1].reg_id),
	.data2_o    (rmtMapping1[1]),

	.addr3_i    (logSrc2_i[1].reg_id),
	.data3_o    (rmtMapping2[1]),

	.we1_i      (writeEn[1]),
	.addr1wr_i  (logDest_i[1].reg_id),
	.data1wr_i  (phyDest[1]),
`endif

`ifdef DISPATCH_THREE_WIDE
	.addr4_i    (logSrc1_i[2].reg_id),
	.data4_o    (rmtMapping1[2]),

	.addr5_i    (logSrc2_i[2].reg_id),
	.data5_o    (rmtMapping2[2]),

	.we2_i      (writeEn[2]),
	.addr2wr_i  (logDest_i[2].reg_id),
	.data2wr_i  (phyDest[2]),
`endif

`ifdef DISPATCH_FOUR_WIDE
	.addr6_i    (logSrc1_i[3].reg_id),
	.data6_o    (rmtMapping1[3]),

	.addr7_i    (logSrc2_i[3].reg_id),
	.data7_o    (rmtMapping2[3]),

	.we3_i      (writeEn[3]),
	.addr3wr_i  (logDest_i[3].reg_id),
	.data3wr_i  (phyDest[3]),
`endif

`ifdef DISPATCH_FIVE_WIDE
	.addr8_i    (logSrc1_i[4].reg_id),
	.data8_o    (rmtMapping1[4]),

	.addr9_i    (logSrc2_i[4].reg_id),
	.data9_o    (rmtMapping2[4]),

	.we4_i      (writeEn[4]),
	.addr4wr_i  (logDest_i[4].reg_id),
	.data4wr_i  (phyDest[4]),
`endif

`ifdef DISPATCH_SIX_WIDE
	.addr10_i   (logSrc1_i[5].reg_id),
	.data10_o   (rmtMapping1[5]),

	.addr11_i   (logSrc2_i[5].reg_id),
	.data11_o   (rmtMapping2[5]),

	.we5_i      (writeEn[5]),
	.addr5wr_i  (logDest_i[5].reg_id),
	.data5wr_i  (phyDest[5]),
`endif

`ifdef DISPATCH_SEVEN_WIDE
	.addr12_i   (logSrc1_i[6].reg_id),
	.data12_o   (rmtMapping1[6]),

	.addr13_i   (logSrc2_i[6].reg_id),
	.data13_o   (rmtMapping2[6]),

	.we6_i      (writeEn[6]),
	.addr6wr_i  (logDest_i[6].reg_id),
	.data6wr_i  (phyDest[6]),
`endif

`ifdef DISPATCH_EIGHT_WIDE
	.addr14_i   (logSrc1_i[7].reg_id),
	.data14_o   (rmtMapping1[7]),

	.addr15_i   (logSrc2_i[7].reg_id),
	.data15_o   (rmtMapping2[7]),

	.we7_i      (writeEn[7]),
	.addr7wr_i  (logDest_i[7].reg_id),
	.data7wr_i  (phyDest[7]),
`endif

	.clk        (clk)
	//.reset      (reset)
	);

/* Assigning renamed logical source and destination registers to output. */
always_comb
begin
	int i;

// NOTE: These valid signals are gated outside or at the subsequent
// pipeline register
// NOTE: writeEn for an inactive lane will be low as logDest_i[i].valid 
// will be pulled low in the preceeding pipeline register
	for (i = 0; i < `DISPATCH_WIDTH; i++)
	begin
		phyDest_o[i].reg_id            = phyDest[i];
		phyDest_o[i].valid             = logDest_i[i].valid;
		phySrc1_o[i].reg_id            = phySrc1[i];
		phySrc1_o[i].valid             = logSrc1_i[i].valid;
		phySrc2_o[i].reg_id            = phySrc2[i]; 
		phySrc2_o[i].valid             = logSrc2_i[i].valid;

		writeEn[i]    = ~recoverFlag_i & ~stall_i & logDest_i[i].valid & ~dontWriteRMT[i];
	end
end



`ifdef DYNAMIC_CONFIG
  genvar ren;
  generate
  for(ren = 0; ren < `DISPATCH_WIDTH; ren++)
  begin:LANEGEN
    reg  [`SIZE_PHYSICAL_LOG-1:0]  phyDestPrevInstr[0:ren];
    always_comb
    begin
      int i;
      for(i = 0; i <= ren; i++)
        phyDestPrevInstr[i] = phyDest[i];
    end

    RenameLane #(.LANE_ID(ren))
    lane
    (
      // Inputs
      //.dispatchLaneActive_i (dispatchLaneActive_i),
      .laneActive_i         (dispatchLaneActive_i[ren]), //Used for power gating only
      .logDest_i            (logDest_i),
      .logSrc1_i            (logSrc1_i[ren]),
      .logSrc2_i            (logSrc2_i[ren]),

      .free_phys_i          (free_phys_i),
      .phyDest_i            (phyDestPrevInstr),
      .rmtMapping1          (rmtMapping1[ren]),
      .rmtMapping2          (rmtMapping2[ren]),

      // Outputs
      .phyDest              (phyDest[ren]),
      .phySrc1              (phySrc1[ren]),
      .phySrc2              (phySrc2[ren]),
      .dontWriteRMT         (dontWriteRMT[ren])
    );
  end
  endgenerate


`else


  /* 3. Rename the logSrc registers. 
   *   3a) Read the log->phy mapping from the RMT
   *   3b) Compare each valid logSrc with the older logDests in the bundle
   *   3c) Use the youngest mapping if a match was found in b). Else, use a)
   */
  /* Check for data dependencies between source and destinations.
   * If a logical source register matches with the logical destination register
   * of an older instruction, then the source should be renamed to the dest.
   * If multiple destinations match, then the youngest (but still older than
   * the source) should be used. If none match, then use the mapping from 
   * the RMT.
   * The outter loop iterates over each instruction, finding the correct
   * source mappings for both source registers.
   * The inner loop iterates over all older instructions in this bundle starting
   * with the oldest in the bundle. Each logical source register is compared
   * with the older instruction's destination. phySrc is replaced with
   * the dest in the case of a match. */
  always_comb
  begin
  	int i, j;
  
  	/* Iterate over each instruction */
  	for (i = 0; i < `DISPATCH_WIDTH; i++)
  	begin
  
  		/* Default is the RMT mapping */
  		phySrc1[i] = rmtMapping1[i];
  
  		/* Iterate over all older instructions looking for a match */
  		for (j = 0; j < i; j++)
  		begin
  			if (logSrc1_i[i] == logDest_i[j])
  			begin
  				phySrc1[i] = phyDest[j];
  			end
  		end
  
  		phySrc2[i] = rmtMapping2[i];
  
  		for (j = 0; j < i; j++)
  		begin
  			if (logSrc2_i[i] == logDest_i[j])
  			begin
  				phySrc2[i] = phyDest[j];
  			end
  		end
  	end
  end
  
  
  
  
  
  
  /*******************************************************************************
  * 4(a)  Following assigns physical registers (popped from the spec free list)
  *       to the destination registers.
  *******************************************************************************/
  
  always_comb
  begin
  	int i;
  	reg  [`DISPATCH_WIDTH-1:0]     logDestValid;
  
  	for (i = 0; i < `DISPATCH_WIDTH; i++)
  	begin
  		logDestValid[i]    = logDest_i[i].valid;
  		phyDest[i]         = logDest_i[i].reg_id; // Default to phyDest = logDest
  	end
    
      case(logDestValid[0])
        1'b0:begin end
        1'b1:phyDest[0] = free_phys_i[0];
      endcase
  
    `ifdef DISPATCH_TWO_WIDE
      casex(logDestValid[1:0])
        2'b0x:begin end 
        2'b10:phyDest[1] = free_phys_i[0];
        2'b11:phyDest[1] = free_phys_i[1];
      endcase
    `endif
  
    `ifdef DISPATCH_THREE_WIDE
      casex(logDestValid[2:0])
        3'b0xx:begin end 
        3'b100:phyDest[2] = free_phys_i[0]; 
        3'b101:phyDest[2] = free_phys_i[1]; 
        3'b110:phyDest[2] = free_phys_i[1];
        3'b111:phyDest[2] = free_phys_i[2]; 
      endcase
    `endif
  
    `ifdef DISPATCH_FOUR_WIDE
      casex(logDestValid[3:0])
        4'b0xxx:begin end
        4'b1000:phyDest[3] = free_phys_i[0]; 
        4'b1001:phyDest[3] = free_phys_i[1]; 
        4'b1010:phyDest[3] = free_phys_i[1];
        4'b1011:phyDest[3] = free_phys_i[2]; 
        4'b1100:phyDest[3] = free_phys_i[1]; 
        4'b1101:phyDest[3] = free_phys_i[2]; 
        4'b1110:phyDest[3] = free_phys_i[2];
        4'b1111:phyDest[3] = free_phys_i[3]; 
      endcase
    `endif
  
    `ifdef DISPATCH_FIVE_WIDE
      casex(logDestValid[4:0])
        5'b0xxxx:begin end
        5'b10000:phyDest[4] = free_phys_i[0]; 
        5'b10001:phyDest[4] = free_phys_i[1]; 
        5'b10010:phyDest[4] = free_phys_i[1];
        5'b10011:phyDest[4] = free_phys_i[2]; 
        5'b10100:phyDest[4] = free_phys_i[1]; 
        5'b10101:phyDest[4] = free_phys_i[2]; 
        5'b10110:phyDest[4] = free_phys_i[2];
        5'b10111:phyDest[4] = free_phys_i[3]; 
        5'b11000:phyDest[4] = free_phys_i[1]; 
        5'b11001:phyDest[4] = free_phys_i[2]; 
        5'b11010:phyDest[4] = free_phys_i[2];
        5'b11011:phyDest[4] = free_phys_i[3]; 
        5'b11100:phyDest[4] = free_phys_i[2]; 
        5'b11101:phyDest[4] = free_phys_i[3]; 
        5'b11110:phyDest[4] = free_phys_i[3];
        5'b11111:phyDest[4] = free_phys_i[4]; 
      endcase
    `endif
  
    `ifdef DISPATCH_SIX_WIDE
      casex(logDestValid[5:0])
        6'b0xxxxx:begin end 
        6'b100000:phyDest[5] = free_phys_i[0]; 
        6'b100001:phyDest[5] = free_phys_i[1]; 
        6'b100010:phyDest[5] = free_phys_i[1];
        6'b100011:phyDest[5] = free_phys_i[2]; 
        6'b100100:phyDest[5] = free_phys_i[1]; 
        6'b100101:phyDest[5] = free_phys_i[2]; 
        6'b100110:phyDest[5] = free_phys_i[2];
        6'b100111:phyDest[5] = free_phys_i[3]; 
        6'b101000:phyDest[5] = free_phys_i[1]; 
        6'b101001:phyDest[5] = free_phys_i[2]; 
        6'b101010:phyDest[5] = free_phys_i[2];
        6'b101011:phyDest[5] = free_phys_i[3]; 
        6'b101100:phyDest[5] = free_phys_i[2]; 
        6'b101101:phyDest[5] = free_phys_i[3]; 
        6'b101110:phyDest[5] = free_phys_i[3];
        6'b101111:phyDest[5] = free_phys_i[4]; 
        6'b110000:phyDest[5] = free_phys_i[1]; 
        6'b110001:phyDest[5] = free_phys_i[2]; 
        6'b110010:phyDest[5] = free_phys_i[2];
        6'b110011:phyDest[5] = free_phys_i[3]; 
        6'b110100:phyDest[5] = free_phys_i[2]; 
        6'b110101:phyDest[5] = free_phys_i[3]; 
        6'b110110:phyDest[5] = free_phys_i[3];
        6'b110111:phyDest[5] = free_phys_i[4]; 
        6'b111000:phyDest[5] = free_phys_i[2]; 
        6'b111001:phyDest[5] = free_phys_i[3]; 
        6'b111010:phyDest[5] = free_phys_i[3];
        6'b111011:phyDest[5] = free_phys_i[4]; 
        6'b111100:phyDest[5] = free_phys_i[3]; 
        6'b111101:phyDest[5] = free_phys_i[4]; 
        6'b111110:phyDest[5] = free_phys_i[4];
        6'b111111:phyDest[5] = free_phys_i[5]; 
      endcase
    `endif
  
    `ifdef DISPATCH_SEVEN_WIDE
      casex(logDestValid[6:0])
        7'b0xxxxxx:begin end 
        7'b1000000:phyDest[6] = free_phys_i[0]; 
        7'b1000001:phyDest[6] = free_phys_i[1]; 
        7'b1000010:phyDest[6] = free_phys_i[1];
        7'b1000011:phyDest[6] = free_phys_i[2]; 
        7'b1000100:phyDest[6] = free_phys_i[1]; 
        7'b1000101:phyDest[6] = free_phys_i[2]; 
        7'b1000110:phyDest[6] = free_phys_i[2];
        7'b1000111:phyDest[6] = free_phys_i[3]; 
        7'b1001000:phyDest[6] = free_phys_i[1]; 
        7'b1001001:phyDest[6] = free_phys_i[2]; 
        7'b1001010:phyDest[6] = free_phys_i[2];
        7'b1001011:phyDest[6] = free_phys_i[3]; 
        7'b1001100:phyDest[6] = free_phys_i[2]; 
        7'b1001101:phyDest[6] = free_phys_i[3]; 
        7'b1001110:phyDest[6] = free_phys_i[3];
        7'b1001111:phyDest[6] = free_phys_i[4]; 
        7'b1010000:phyDest[6] = free_phys_i[1]; 
        7'b1010001:phyDest[6] = free_phys_i[2]; 
        7'b1010010:phyDest[6] = free_phys_i[2];
        7'b1010011:phyDest[6] = free_phys_i[3]; 
        7'b1010100:phyDest[6] = free_phys_i[2]; 
        7'b1010101:phyDest[6] = free_phys_i[3]; 
        7'b1010110:phyDest[6] = free_phys_i[3];
        7'b1010111:phyDest[6] = free_phys_i[4]; 
        7'b1011000:phyDest[6] = free_phys_i[2]; 
        7'b1011001:phyDest[6] = free_phys_i[3]; 
        7'b1011010:phyDest[6] = free_phys_i[3];
        7'b1011011:phyDest[6] = free_phys_i[4]; 
        7'b1011100:phyDest[6] = free_phys_i[3]; 
        7'b1011101:phyDest[6] = free_phys_i[4]; 
        7'b1011110:phyDest[6] = free_phys_i[4];
        7'b1011111:phyDest[6] = free_phys_i[5]; 
        7'b1100000:phyDest[6] = free_phys_i[1]; 
        7'b1100001:phyDest[6] = free_phys_i[2]; 
        7'b1100010:phyDest[6] = free_phys_i[2];
        7'b1100011:phyDest[6] = free_phys_i[3]; 
        7'b1100100:phyDest[6] = free_phys_i[2]; 
        7'b1100101:phyDest[6] = free_phys_i[3]; 
        7'b1100110:phyDest[6] = free_phys_i[3];
        7'b1100111:phyDest[6] = free_phys_i[4]; 
        7'b1101000:phyDest[6] = free_phys_i[2]; 
        7'b1101001:phyDest[6] = free_phys_i[3]; 
        7'b1101010:phyDest[6] = free_phys_i[3];
        7'b1101011:phyDest[6] = free_phys_i[4]; 
        7'b1101100:phyDest[6] = free_phys_i[3]; 
        7'b1101101:phyDest[6] = free_phys_i[4]; 
        7'b1101110:phyDest[6] = free_phys_i[4];
        7'b1101111:phyDest[6] = free_phys_i[5]; 
        7'b1110000:phyDest[6] = free_phys_i[2]; 
        7'b1110001:phyDest[6] = free_phys_i[3]; 
        7'b1110010:phyDest[6] = free_phys_i[3];
        7'b1110011:phyDest[6] = free_phys_i[4]; 
        7'b1110100:phyDest[6] = free_phys_i[3]; 
        7'b1110101:phyDest[6] = free_phys_i[4]; 
        7'b1110110:phyDest[6] = free_phys_i[4];
        7'b1110111:phyDest[6] = free_phys_i[5]; 
        7'b1111000:phyDest[6] = free_phys_i[3]; 
        7'b1111001:phyDest[6] = free_phys_i[4]; 
        7'b1111010:phyDest[6] = free_phys_i[4];
        7'b1111011:phyDest[6] = free_phys_i[5]; 
        7'b1111100:phyDest[6] = free_phys_i[4]; 
        7'b1111101:phyDest[6] = free_phys_i[5]; 
        7'b1111110:phyDest[6] = free_phys_i[5];
        7'b1111111:phyDest[6] = free_phys_i[6]; 
      endcase
    `endif
  
    `ifdef DISPATCH_EIGHT_WIDE
      casex(logDestValid[7:0])
        8'b0xxxxxxx:begin end 
        8'b10000000:phyDest[7] = free_phys_i[0]; 
        8'b10000001:phyDest[7] = free_phys_i[1]; 
        8'b10000010:phyDest[7] = free_phys_i[1];
        8'b10000011:phyDest[7] = free_phys_i[2]; 
        8'b10000100:phyDest[7] = free_phys_i[1]; 
        8'b10000101:phyDest[7] = free_phys_i[2]; 
        8'b10000110:phyDest[7] = free_phys_i[2];
        8'b10000111:phyDest[7] = free_phys_i[3]; 
        8'b10001000:phyDest[7] = free_phys_i[1]; 
        8'b10001001:phyDest[7] = free_phys_i[2]; 
        8'b10001010:phyDest[7] = free_phys_i[2];
        8'b10001011:phyDest[7] = free_phys_i[3]; 
        8'b10001100:phyDest[7] = free_phys_i[2]; 
        8'b10001101:phyDest[7] = free_phys_i[3]; 
        8'b10001110:phyDest[7] = free_phys_i[3];
        8'b10001111:phyDest[7] = free_phys_i[4]; 
        8'b10010000:phyDest[7] = free_phys_i[1]; 
        8'b10010001:phyDest[7] = free_phys_i[2]; 
        8'b10010010:phyDest[7] = free_phys_i[2];
        8'b10010011:phyDest[7] = free_phys_i[3]; 
        8'b10010100:phyDest[7] = free_phys_i[2]; 
        8'b10010101:phyDest[7] = free_phys_i[3]; 
        8'b10010110:phyDest[7] = free_phys_i[3];
        8'b10010111:phyDest[7] = free_phys_i[4]; 
        8'b10011000:phyDest[7] = free_phys_i[2]; 
        8'b10011001:phyDest[7] = free_phys_i[3]; 
        8'b10011010:phyDest[7] = free_phys_i[3];
        8'b10011011:phyDest[7] = free_phys_i[4]; 
        8'b10011100:phyDest[7] = free_phys_i[3]; 
        8'b10011101:phyDest[7] = free_phys_i[4]; 
        8'b10011110:phyDest[7] = free_phys_i[4];
        8'b10011111:phyDest[7] = free_phys_i[5]; 
        8'b10100000:phyDest[7] = free_phys_i[1]; 
        8'b10100001:phyDest[7] = free_phys_i[2]; 
        8'b10100010:phyDest[7] = free_phys_i[2];
        8'b10100011:phyDest[7] = free_phys_i[3]; 
        8'b10100100:phyDest[7] = free_phys_i[2]; 
        8'b10100101:phyDest[7] = free_phys_i[3]; 
        8'b10100110:phyDest[7] = free_phys_i[3];
        8'b10100111:phyDest[7] = free_phys_i[4]; 
        8'b10101000:phyDest[7] = free_phys_i[2]; 
        8'b10101001:phyDest[7] = free_phys_i[3]; 
        8'b10101010:phyDest[7] = free_phys_i[3];
        8'b10101011:phyDest[7] = free_phys_i[4]; 
        8'b10101100:phyDest[7] = free_phys_i[3]; 
        8'b10101101:phyDest[7] = free_phys_i[4]; 
        8'b10101110:phyDest[7] = free_phys_i[4];
        8'b10101111:phyDest[7] = free_phys_i[5]; 
        8'b10110000:phyDest[7] = free_phys_i[2]; 
        8'b10110001:phyDest[7] = free_phys_i[3]; 
        8'b10110010:phyDest[7] = free_phys_i[3];
        8'b10110011:phyDest[7] = free_phys_i[4]; 
        8'b10110100:phyDest[7] = free_phys_i[3]; 
        8'b10110101:phyDest[7] = free_phys_i[4]; 
        8'b10110110:phyDest[7] = free_phys_i[4];
        8'b10110111:phyDest[7] = free_phys_i[5]; 
        8'b10111000:phyDest[7] = free_phys_i[3]; 
        8'b10111001:phyDest[7] = free_phys_i[4]; 
        8'b10111010:phyDest[7] = free_phys_i[4];
        8'b10111011:phyDest[7] = free_phys_i[5]; 
        8'b10111100:phyDest[7] = free_phys_i[4]; 
        8'b10111101:phyDest[7] = free_phys_i[5]; 
        8'b10111110:phyDest[7] = free_phys_i[5];
        8'b10111111:phyDest[7] = free_phys_i[6]; 
        8'b11000000:phyDest[7] = free_phys_i[1]; 
        8'b11000001:phyDest[7] = free_phys_i[2]; 
        8'b11000010:phyDest[7] = free_phys_i[2];
        8'b11000011:phyDest[7] = free_phys_i[3]; 
        8'b11000100:phyDest[7] = free_phys_i[2]; 
        8'b11000101:phyDest[7] = free_phys_i[3]; 
        8'b11000110:phyDest[7] = free_phys_i[3];
        8'b11000111:phyDest[7] = free_phys_i[4]; 
        8'b11001000:phyDest[7] = free_phys_i[2]; 
        8'b11001001:phyDest[7] = free_phys_i[3]; 
        8'b11001010:phyDest[7] = free_phys_i[3];
        8'b11001011:phyDest[7] = free_phys_i[4]; 
        8'b11001100:phyDest[7] = free_phys_i[3]; 
        8'b11001101:phyDest[7] = free_phys_i[4]; 
        8'b11001110:phyDest[7] = free_phys_i[4];
        8'b11001111:phyDest[7] = free_phys_i[5]; 
        8'b11010000:phyDest[7] = free_phys_i[2]; 
        8'b11010001:phyDest[7] = free_phys_i[3]; 
        8'b11010010:phyDest[7] = free_phys_i[3];
        8'b11010011:phyDest[7] = free_phys_i[4]; 
        8'b11010100:phyDest[7] = free_phys_i[3]; 
        8'b11010101:phyDest[7] = free_phys_i[4]; 
        8'b11010110:phyDest[7] = free_phys_i[4];
        8'b11010111:phyDest[7] = free_phys_i[5]; 
        8'b11011000:phyDest[7] = free_phys_i[3]; 
        8'b11011001:phyDest[7] = free_phys_i[4];
        8'b11011010:phyDest[7] = free_phys_i[4];
        8'b11011011:phyDest[7] = free_phys_i[5]; 
        8'b11011100:phyDest[7] = free_phys_i[4]; 
        8'b11011101:phyDest[7] = free_phys_i[5]; 
        8'b11011110:phyDest[7] = free_phys_i[5];
        8'b11011111:phyDest[7] = free_phys_i[6]; 
        8'b11100000:phyDest[7] = free_phys_i[2]; 
        8'b11100001:phyDest[7] = free_phys_i[3]; 
        8'b11100010:phyDest[7] = free_phys_i[3];
        8'b11100011:phyDest[7] = free_phys_i[4]; 
        8'b11100100:phyDest[7] = free_phys_i[3]; 
        8'b11100101:phyDest[7] = free_phys_i[4]; 
        8'b11100110:phyDest[7] = free_phys_i[4];
        8'b11100111:phyDest[7] = free_phys_i[5]; 
        8'b11101000:phyDest[7] = free_phys_i[3]; 
        8'b11101001:phyDest[7] = free_phys_i[4]; 
        8'b11101010:phyDest[7] = free_phys_i[4];
        8'b11101011:phyDest[7] = free_phys_i[5]; 
        8'b11101100:phyDest[7] = free_phys_i[4]; 
        8'b11101101:phyDest[7] = free_phys_i[5]; 
        8'b11101110:phyDest[7] = free_phys_i[5];
        8'b11101111:phyDest[7] = free_phys_i[6]; 
        8'b11110000:phyDest[7] = free_phys_i[3]; 
        8'b11110001:phyDest[7] = free_phys_i[4]; 
        8'b11110010:phyDest[7] = free_phys_i[4];
        8'b11110011:phyDest[7] = free_phys_i[5]; 
        8'b11110100:phyDest[7] = free_phys_i[4]; 
        8'b11110101:phyDest[7] = free_phys_i[5]; 
        8'b11110110:phyDest[7] = free_phys_i[5];
        8'b11110111:phyDest[7] = free_phys_i[6]; 
        8'b11111000:phyDest[7] = free_phys_i[4]; 
        8'b11111001:phyDest[7] = free_phys_i[5]; 
        8'b11111010:phyDest[7] = free_phys_i[5];
        8'b11111011:phyDest[7] = free_phys_i[6]; 
        8'b11111100:phyDest[7] = free_phys_i[5]; 
        8'b11111101:phyDest[7] = free_phys_i[6]; 
        8'b11111110:phyDest[7] = free_phys_i[6];
        8'b11111111:phyDest[7] = free_phys_i[7]; 
      endcase
    `endif
  
  end
  
  /* 4b) Update the RMT with the youngest mapping for each logical dest value. 
   *     If the logical destination register matches with destination of the newer
   *     instruction in the rename bundle, then this instruction doesn't 
   *     update the RMT (dontWriteRMT will be high for the younger instrtuction). */
  always_comb
  begin
  	int i, j;
  
  	/* Iterate over each instruction */
  	for (i = 0; i < `DISPATCH_WIDTH; i++)
  	begin
  
  		dontWriteRMT[i] = 0;
  
  		/* Iterate over each older instruction */
  		for (j = i+1; j < `DISPATCH_WIDTH; j++)
  		begin
  
  			if (logDest_i[i] == logDest_i[j])
  			begin
  				dontWriteRMT[i] = 1;
  			end
  		end
  	end
  end

`endif //DYNAMIC_CONFIG
endmodule
