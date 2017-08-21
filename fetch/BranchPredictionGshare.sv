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

module BranchPredictionGshare(
	input                               clk,
	input                               reset,

	input  [`SIZE_PC-1:0]               PC_i,
  input  [`SIZE_INSTRUCTION-1:0]      inst_i   [0:`FETCH_WIDTH-1],

  input                               recoverFlag_i,
  input                               exceptionFlag_i,
  input                               fs2RecoverFlag_i,

  input  btbPkt                       btbPacket_i [0:`FETCH_WIDTH-1], // This comes in the same cycle
  input  [`FETCH_WIDTH-1:0]           specBHRCtrlVect_i, // This comes in the next cycle

	input  [`SIZE_PC-1:0]               updatePC_i,
  input  [`SIZE_CNT_TBL_LOG-1:0]      updateIndex_i,   // Also contains bank information embedded
	input                               updateDir_i,
	input  [1:0]                        updateCounter_i,
	input                               updateEn_i,

	output [`FETCH_WIDTH-1:0]           predDir_o,
	output reg [1:0]                    predCounter_o [0:`FETCH_WIDTH-1],
	output reg [`SIZE_CNT_TBL_LOG-1:0]  predIndex_o [0:`FETCH_WIDTH-1]

	);


// Defines that choose between the different indexing styles
// and BHR update styles

//`define NEXT_CYCLE_BHR_UPDATE
//`define SAME_CYCLE_BHR_UPDATE
//`define 



/* BP width must be a power of two */
localparam BP_WIDTH = 1<<`FETCH_WIDTH_LOG;
localparam INDEX    = `SIZE_CNT_TBL_LOG-`FETCH_WIDTH_LOG;
// BHR should have enough bits to index the entire counter table plus the number of
// bits being ignored each time (FETCH_WIDTH)
//localparam NUM_BITS_IGNORE = `FETCH_WIDTH; // This is for hashing style 1
//localparam NUM_BITS_IGNORE = 0; // This is for the hashing style 2 and specBHR style 1
localparam NUM_BITS_IGNORE = `FETCH_WIDTH; // This is for the hashing style 2 and specBHR style 2
//localparam NUM_BITS_IGNORE = 2*`FETCH_WIDTH; // This is for hashing style 3
localparam BHR_WIDTH = INDEX + NUM_BITS_IGNORE;


reg  [INDEX-1:0]                                    rdAddr [0:BP_WIDTH-1];
wire [1:0]                                          rdData [0:BP_WIDTH-1];
reg  [`FETCH_WIDTH-1:0]                             predDir;
reg  [`FETCH_WIDTH-1:0]                             predDir_d1;

wire [INDEX-1:0]                                    wrAddr;
reg  [INDEX-1:0]                                    wrAddr_d1;
wire [1:0]                                          updateCounter [0:BP_WIDTH-1];
reg  [1:0]                                          wrData;
reg                                                 wrEn   [0:BP_WIDTH-1];

wire [`FETCH_WIDTH-1:0] preDecodeCtrlVect; 
wire [`BRANCH_TYPE_LOG-1:0] preDecodeCtrlType[0:`FETCH_WIDTH-1]; 

reg   [1:0]           updateCounterSpec [0:BP_WIDTH-1];
reg   [INDEX-1:0]     updateAddrSpec [0:BP_WIDTH-1];
wire  [BP_WIDTH-1:0]  wrEnSpec;

genvar g;
generate
for (g = 0; g < BP_WIDTH; g++)
begin

BP_RAM_GSHARE #(
	.DEPTH                    (`SIZE_CNT_TABLE/BP_WIDTH),
	.INDEX                    (INDEX),
	.WIDTH                    (2)
)
	counterTable (

	.clk                      (clk),
	.reset                    (reset),

	.addr0_i                  (rdAddr[g]),
	.data0_o                  (rdData[g]),

`ifdef PIPELINED_PHT_UPDATE
  //Used to read out the counters before updating in next cycle
  .addr1_i                  (wrAddr),     
  .data1_o                  (updateCounter[g]), 

	.addr0wr_i                (wrAddr_d1),
	.data0wr_i                (wrData),
	.we0_i                    (wrEn[g])
`elsif SPECULATIVE_PHT_UPDATE  
	.addr0wr_i                (updateAddrSpec[g]),
	.data0wr_i                (updateCounterSpec[g]),
	.we0_i                    (wrEnSpec[g])
`else  
	.addr0wr_i                (wrAddr),
	.data0wr_i                (wrData),
	.we0_i                    (wrEn[g])
`endif

);

end
endgenerate

fs2Pkt                    fs2Packet [0:`FETCH_WIDTH-1];

generate
for (g = 0; g < `FETCH_WIDTH; g = g + 1)
begin : preDecode_gen

always_comb
begin
    fs2Packet[g].inst = inst_i[g];
end


PreDecode_PISA preDecode(
    .fs2Packet_i    (fs2Packet[g]),

    .ctrlInst_o     (preDecodeCtrlVect[g]),
    .predNPC_o      (),
    .ctrlType_o     (preDecodeCtrlType[g])
    );

end
endgenerate



reg  [INDEX-1:0]                                    instIndex     [0:BP_WIDTH-1];
reg  [`FETCH_WIDTH_LOG-1:0]                         instOffset    [0:BP_WIDTH-1];
reg  [1:0]                                          predCounter   [0:BP_WIDTH-1];
reg  [INDEX-1:0]                                    phtIndex      [0:`FETCH_WIDTH-1]; //Enough bits to index one counter RAM
reg  [BHR_WIDTH-1:0]                    specBranchHistory;  // Speculative branch history registors
reg  [BHR_WIDTH-1:0]                    specBranchHistory_d1;  // Speculative branch history registors
reg  [BHR_WIDTH-1:0]                    specBranchHistory_d2;  // Speculative branch history registors
reg  [BHR_WIDTH-1:0]                    specBranchHistoryNext;  // Speculative branch history registors
reg  [BHR_WIDTH-1:0]                    archBranchHistory;  // Committed branch history register



always_ff @(posedge clk)
begin
  if(reset)
  begin
    $display("\n**** GHSARE *****\n");
    predDir_d1    <=  {`FETCH_WIDTH{1'b1}};
    specBranchHistory_d1 <=  {BHR_WIDTH{1'b1}};
    specBranchHistory_d2 <=  {BHR_WIDTH{1'b1}};
  end
  else
  begin
    predDir_d1    <=  predDir;
    specBranchHistory_d1 <=  specBranchHistory;
    specBranchHistory_d2 <=  specBranchHistory_d1;
  end
end

/***************************************************************
//   THIS SPECULATIVE PHT UPDATE IS BASELESS AND DOES NOT WORK
////////////////////////////////////////////////////////////////

// Speculatively update the PHT after each prediction is made
// Pipeline this update the use the predecoded branch information 
// from FetchStage2 to update the counters only for the instructions
// that are branches.
//TODO: Figure out a repair mechanism that is low complexity
// NOTE: Speculative PHT update without feedback from branch resolution
// keeps the counters saturated at one pole. So that is no good. Instead
// do not update the PHT speculatively. Instead have a queue type of structure
// to store the speculative updates to be used by nerwer branches. Finally when
// the branch resolves, update the PHT in-order and non-speculatively as the
// normal case and pop the speculative value from the queue. If the branch is
// predicted correct, updated value in PHT will equal the speculative value
// in the queue and branches after the committing branch would have benefitted
// from the speculative value in the queue. If not, PHT will have the 
// correct value and the entire queue and all following instructions will 
// be squashed.

always_ff @(posedge clk)
begin
  int i;
  if(reset)
  begin
    for(i = 0; i < `FETCH_WIDTH; i++)
    begin
      updateCounterSpec[i]  <= 2'b0; 
      updateAddrSpec[i]     <= {INDEX{1'b0}};
    end
  end
  else
  begin
    for(i = 0; i < `FETCH_WIDTH; i++)
    begin
      updateCounterSpec[i]  <= (predCounter[i][1])
                              ?((predCounter[i] == 3) ? 3 : (predCounter[i] + 1))
                              :((predCounter[i] == 0) ? 0 : (predCounter[i] - 1));

      updateAddrSpec[i]     <= {instOffset[i],phtIndex[i]}; // Store the index and bank information
    end
  end
end
// FETCH_WIDTH and BP_WIDTH can be different
// TODO: Take care of the above somehow
// TODO: specBHRCtrlVect_i has a large input delay
// The counter update might need to be pipelined further
// to take care of the write latency unless the write
// is already synchronous.
assign wrEnSpec = specBHRCtrlVect_i;

// TODO: Use a speculatively updated queue to store counters
// for future use. This will be beneficial only if there is
// decent amount of aliasing and prediction to commit latency
// for branches is high.

************************************************************/



// Different ways to update the specBranchHistory:
// 1) Use BTB hit information to determine which instructions are branches and which 
// predcitions need to be pushed into the specBranchHistory. This method can cause severe
// mismatch between the archBranchHistory and specBranchHistory since not all branches hit
// in the BTB. 
//
// 2) Shift in the predictions in the next cycle when the branches in the fetch bundle are
// known after predecoding. This will still have incorrect predictions in the specBHR
// but it will not have predictions missing for branches due to BTB misses

//TODO: This always_comb will synthesize really bad with huge muxes
// Have to find a better solution than this
reg [`FETCH_WIDTH_LOG-1:0] numShifts;
reg [0:`FETCH_WIDTH-1] shiftVect;
always_comb
begin
      int i;

      numShifts = 0;
      shiftVect = {`FETCH_WIDTH{1'b0}}; //Default to not taken
      for(i=0; i < `FETCH_WIDTH; i++)
      begin
      //  if(btbPacket_i[i].hit)  // specBHR update style 1
      //  begin
      //   shiftVect[numShifts] = predDir[i]; 
      //   numShifts++;
      //  end

// ICACHE_PREDECODE performs worse than next cycle update
`ifdef USE_ICACHE_PREDECODE
        if(preDecodeCtrlVect[i] & (preDecodeCtrlType[i] == `COND_BRANCH))  // specBHR update style 2
        begin
          shiftVect[numShifts] = predDir[i];  // The branches in the Fetch Bundle are known in same cycle
          numShifts++;
        end
`else
        if(specBHRCtrlVect_i[i])  // specBHR update style 2
        begin
          shiftVect[numShifts] = predDir_d1[i];  // Use a registered version of the predDir as branches are 
          numShifts++;
        end
`endif
      end

      case(numShifts) // synopsys full_case
        'h0: specBranchHistoryNext = specBranchHistory;
        'h1: specBranchHistoryNext = {specBranchHistory[BHR_WIDTH-2:0], shiftVect[0]};
      `ifdef FETCH_TWO_WIDE
        'h2: specBranchHistoryNext = {specBranchHistory[BHR_WIDTH-3:0], shiftVect[0:1]};
      `endif
      `ifdef FETCH_THREE_WIDE
        'h3: specBranchHistoryNext = {specBranchHistory[BHR_WIDTH-4:0], shiftVect[0:2]};
      `endif
      `ifdef FETCH_FOUR_WIDE
        'h4: specBranchHistoryNext = {specBranchHistory[BHR_WIDTH-5:0], shiftVect[0:3]};
      `endif
      `ifdef FETCH_FIVE_WIDE
        'h5: specBranchHistoryNext = {specBranchHistory[BHR_WIDTH-6:0], shiftVect[0:4]};
      `endif
      `ifdef FETCH_SIX_WIDE
        'h6: specBranchHistoryNext = {specBranchHistory[BHR_WIDTH-7:0], shiftVect[0:5]};
      `endif
      `ifdef FETCH_SEVEN_WIDE
        'h7: specBranchHistoryNext = {specBranchHistory[BHR_WIDTH-8:0], shiftVect[0:6]};
      `endif
      `ifdef FETCH_EIGHT_WIDE
        'h8: specBranchHistoryNext = {specBranchHistory[BHR_WIDTH-9:0], shiftVect[0:7]};
      `endif
    endcase
end

// Update the BHR speculatively with current predictions
// Recover the BHR using the ARCH BHR if there is a branch
// misprediction. A single committed BHR works since in AnyCore,
// branch mispredictions are handles at the head of the Active List.
// In case a different misprediction handling mechanism is used,
// checkpoints of BHR needs to be maintained.

always_ff @(posedge clk)
begin
  if(reset)
  begin
    specBranchHistory <= {BHR_WIDTH{1'b1}}; // Initialize with all branches not taken
    archBranchHistory <= {BHR_WIDTH{1'b1}}; // Initialize with all branches not taken
  end
  else
  begin
    if(recoverFlag_i)
      specBranchHistory <= archBranchHistory;

    else if(fs2RecoverFlag_i)
      //specBranchHistory <= specBranchHistory_d1;
      specBranchHistory <= specBranchHistory;

    else
    begin
      //TODO: Update the specBranchHistory but use the branch information obtained from the BTB to update
      //TODO: There will probably not be enough slack to use the BTB results to update the specBranchHistory
      // Instead, register the result from the BTB and d
      specBranchHistory <= specBranchHistoryNext;
    end

    if(updateEn_i & ~recoverFlag_i)
      archBranchHistory <= {archBranchHistory[BHR_WIDTH-2:0],updateDir_i};  // Shift in the committed direction
  end

end

// Using the implementation where the first few bits of the BHR are ignored
// so that indexing of all the branches are consistent
// Different ways to create the hash:
// 1) Use successive parts of the specBHR to hash the PC. i.e create the hash input 
// shifting the specBHR by one bit for hashing each consecutive instructions. The specBHR
// has enough bits to hash FETCH_WIDTH number of PCs while ignoring lower NUM_BITS_IGNORE
// bits and still not underflow. This may have lower accuracy as non-branch instructions
// are considered as valid branches and the later branches use an incorrect sequence of predictions
// to hash their PCs. - This has bad performance
//
// 2) Use the entire BHR and entire PCs for each successive PCs. This will atleast make sure that
// all branches in a bundle (even non-branches for that matter) will observe a consistent prediction
// pattern for hashing their PCs. This will produce hashes that are closer to ones that would be 
// produced if hashing with archBHR - This was the first implementation - Also used upper bits of 
// PC (instIndex[i]) instead of the entire PC or lower INDEX number of bits
//
// 4) This style uses a flipped version of the BHR to hash the PC. The idea behind this is that the most
// important parts of the two vectors namely PC and BHR, are xored with the least important parts of the other
// to form the index. This should reduce aliasing to quite a large extent.

reg [BHR_WIDTH-1:0] specBranchHistoryFlipped;
always_comb
begin
  int j;
  for(j = 0; j < BHR_WIDTH; j++)
    specBranchHistoryFlipped[j] = specBranchHistory[BHR_WIDTH-1-j];
end

wire [INDEX-1:0]  firstInstPC;

assign firstInstPC = PC_i[`SIZE_PC-1:`SIZE_INST_BYTE_OFFSET+`FETCH_WIDTH_LOG]; 

reg [`FETCH_WIDTH_LOG-1:0] branchIndex[0:`FETCH_WIDTH-1];
always_comb
begin
  reg [`FETCH_WIDTH-1:0]  condBranchVect;
	int i;
	for (i = 0; i < BP_WIDTH; i++)
    condBranchVect[i] = preDecodeCtrlVect[i] & (preDecodeCtrlType[i] == `COND_BRANCH);

    branchIndex[0] = 0;
  `ifdef FETCH_TWO_WIDE
    branchIndex[1] = condBranchVect[0];
  `endif
  `ifdef FETCH_THREE_WIDE
    branchIndex[2] = condBranchVect[0] + condBranchVect[1];
  `endif
  `ifdef FETCH_FOUR_WIDE
    branchIndex[3] = condBranchVect[0] + condBranchVect[1] + condBranchVect[2];
  `endif
  `ifdef FETCH_FIVE_WIDE
    branchIndex[4] = condBranchVect[0] + condBranchVect[1] + condBranchVect[2] + condBranchVect[3];
  `endif
  `ifdef FETCH_SIX_WIDE
    branchIndex[5] = condBranchVect[0] + condBranchVect[1] + condBranchVect[2] + condBranchVect[3] + condBranchVect[4];
  `endif
  `ifdef FETCH_SEVEN_WIDE
    branchIndex[6] = condBranchVect[0] + condBranchVect[1] + condBranchVect[2] + condBranchVect[3] + condBranchVect[4]
                      + condBranchVect[5];
  `endif
  `ifdef FETCH_EIGHT_WIDE
    branchIndex[7] = condBranchVect[0] + condBranchVect[1] + condBranchVect[2] + condBranchVect[3] + condBranchVect[4]
                      + condBranchVect[5] + condBranchVect[6];
  `endif

end
      
always_comb
begin
	int i;
	for (i = 0; i < BP_WIDTH; i++)
	begin
		{instIndex[i], instOffset[i]} = PC_i[`SIZE_PC-1:`SIZE_INST_BYTE_OFFSET] + i;

    //Ignore the first NUM_BITS_IGNORE number of history bits
    //phtIndex[i] = specBranchHistory[(BHR_WIDTH-1-i)-:INDEX] ^ instIndex[i]; // Hashing style 1
    //phtIndex[i] = specBranchHistory[BHR_WIDTH-1-:INDEX] ^ instIndex[i]; // Hashing style 1
    //phtIndex[i] = specBranchHistoryFlipped[BHR_WIDTH-1-:INDEX] ^ instIndex[i]; // Hashing style 1
    //phtIndex[i] = specBranchHistory[BHR_WIDTH-1:NUM_BITS_IGNORE] ^ instIndex[i]; // Hashing style 2
    //phtIndex[i] = specBranchHistory[(BHR_WIDTH-1-i)-:INDEX] ^ instIndex[i]; // Hashing style 3
    phtIndex[i] = specBranchHistoryFlipped[(BHR_WIDTH-NUM_BITS_IGNORE+i)-:INDEX] ^ instIndex[i]; // First instr ignores 3 of its prior bnranch outcomes
    //phtIndex[i] = specBranchHistoryFlipped[(BHR_WIDTH-1)-:INDEX] ^ firstInstPC; // Hashing style 5 
    //phtIndex[i] = specBranchHistoryFlipped[(BHR_WIDTH-NUM_BITS_IGNORE+branchIndex[i])-:INDEX] ^ instIndex[i]; // FIrst instr ignores 3 of its prior bnranch outcomes
	end
end


/* Rotate the addresses to the correct RAM */
always_comb
begin
	int i;

	/* TODO: Use coreGen to expand these loops */
	case (instOffset[0])

		3'h0:
		begin
			/* 4-wide example:
			 * rdAddr[0] = pc[0];
			 * rdAddr[1] = pc[1];
			 * rdAddr[2] = pc[2];
			 * rdAddr[3] = pc[3]; */
			rdAddr[0] = phtIndex[0];
			rdAddr[1] = phtIndex[1];
`ifdef FETCH_THREE_WIDE
			rdAddr[2] = phtIndex[2];
			rdAddr[3] = phtIndex[3];
`endif

`ifdef FETCH_FIVE_WIDE
			rdAddr[4] = phtIndex[4];
			rdAddr[5] = phtIndex[5];
			rdAddr[6] = phtIndex[6];
			rdAddr[7] = phtIndex[7];
`endif
			/* for (i = 0; i < BP_WIDTH; i++) */
			/* begin */
			/* 	rdAddr[i] = phtIndex[i]; */
			/* end */
		end

		3'h1:
		begin
			/* 4-wide example:
			 * rdAddr[0] = pc[3];
			 * rdAddr[1] = pc[0];
			 * rdAddr[2] = pc[1];
			 * rdAddr[3] = pc[2]; */
`ifndef FETCH_THREE_WIDE /* 1- or 2-wide */
			rdAddr[0] = phtIndex[1];
			rdAddr[1] = phtIndex[0];
`endif

`ifdef FETCH_THREE_WIDE
`ifndef FETCH_FIVE_WIDE /* 3- or 4-wide */
			rdAddr[0] = phtIndex[3];
			rdAddr[1] = phtIndex[0];
			rdAddr[2] = phtIndex[1];
			rdAddr[3] = phtIndex[2];
`endif
`endif

`ifdef FETCH_FIVE_WIDE /* 5+ wide */
			rdAddr[0] = phtIndex[7];
			rdAddr[1] = phtIndex[0];
			rdAddr[2] = phtIndex[1];
			rdAddr[3] = phtIndex[2];
			rdAddr[4] = phtIndex[3];
			rdAddr[5] = phtIndex[4];
			rdAddr[6] = phtIndex[5];
			rdAddr[7] = phtIndex[6];
`endif
			/* for (i = 0; i < 1; i++) */
			/* begin */
			/* 	rdAddr[i] = phtIndex[BP_WIDTH-i-1]; */
			/* end */

			/* for (i = 1; i < BP_WIDTH; i++) */
			/* begin */
			/* 	rdAddr[i] = phtIndex[i-1]; */
			/* end */
		end

`ifdef FETCH_THREE_WIDE
		3'h2:
		begin
			/* 4-wide example:
			 * rdAddr[0] = pc[2];
			 * rdAddr[1] = pc[3];
			 * rdAddr[2] = pc[0];
			 * rdAddr[3] = pc[1]; */
`ifndef FETCH_FIVE_WIDE /* 3- or 4-wide */
			rdAddr[0] = phtIndex[2];
			rdAddr[1] = phtIndex[3];
			rdAddr[2] = phtIndex[0];
			rdAddr[3] = phtIndex[1];
`endif

`ifdef FETCH_FIVE_WIDE /* 5+ wide */
			rdAddr[0] = phtIndex[6];
			rdAddr[1] = phtIndex[7];
			rdAddr[2] = phtIndex[0];
			rdAddr[3] = phtIndex[1];
			rdAddr[4] = phtIndex[2];
			rdAddr[5] = phtIndex[3];
			rdAddr[6] = phtIndex[4];
			rdAddr[7] = phtIndex[5];
`endif
			/* for (i = 0; i < 2; i++) */
			/* begin */
			/* 	rdAddr[i] = phtIndex[BP_WIDTH-i-1]; */
			/* end */

			/* for (i = 2; i < BP_WIDTH; i++) */
			/* begin */
			/* 	rdAddr[i] = phtIndex[i-2]; */
			/* end */
		end

		3'h3:
		begin
`ifndef FETCH_FIVE_WIDE /* 3- or 4-wide */
			rdAddr[0] = phtIndex[1];
			rdAddr[1] = phtIndex[2];
			rdAddr[2] = phtIndex[3];
			rdAddr[3] = phtIndex[0];
`endif

`ifdef FETCH_FIVE_WIDE /* 5+ wide */
			rdAddr[0] = phtIndex[5];
			rdAddr[1] = phtIndex[6];
			rdAddr[2] = phtIndex[7];
			rdAddr[3] = phtIndex[0];
			rdAddr[4] = phtIndex[1];
			rdAddr[5] = phtIndex[2];
			rdAddr[6] = phtIndex[3];
			rdAddr[7] = phtIndex[4];
`endif
			/* 4-wide example:
			 * rdAddr[0] = pc[1];
			 * rdAddr[1] = pc[2];
			 * rdAddr[2] = pc[3];
			 * rdAddr[3] = pc[0]; */
			/* for (i = 0; i < 3; i++) */
			/* begin */
			/* 	rdAddr[i] = phtIndex[BP_WIDTH-i-1]; */
			/* end */

			/* for (i = 3; i < BP_WIDTH; i++) */
			/* begin */
			/* 	rdAddr[i] = phtIndex[i-3]; */
			/* end */
		end
`endif

`ifdef FETCH_FIVE_WIDE
		3'h4:
		begin
			rdAddr[0] = phtIndex[4];
			rdAddr[1] = phtIndex[5];
			rdAddr[2] = phtIndex[6];
			rdAddr[3] = phtIndex[7];
			rdAddr[4] = phtIndex[0];
			rdAddr[5] = phtIndex[1];
			rdAddr[6] = phtIndex[2];
			rdAddr[7] = phtIndex[3];
			/* for (i = 0; i < 4; i++) */
			/* begin */
			/* 	rdAddr[i] = phtIndex[BP_WIDTH-i-1]; */
			/* end */

			/* for (i = 4; i < BP_WIDTH; i++) */
			/* begin */
			/* 	rdAddr[i] = phtIndex[i-4]; */
			/* end */
		end

		3'h5:
		begin
			rdAddr[0] = phtIndex[3];
			rdAddr[1] = phtIndex[4];
			rdAddr[2] = phtIndex[5];
			rdAddr[3] = phtIndex[6];
			rdAddr[4] = phtIndex[7];
			rdAddr[5] = phtIndex[0];
			rdAddr[6] = phtIndex[1];
			rdAddr[7] = phtIndex[2];
			/* for (i = 0; i < 5; i++) */
			/* begin */
			/* 	rdAddr[i] = phtIndex[BP_WIDTH-i-1]; */
			/* end */

			/* for (i = 5; i < BP_WIDTH; i++) */
			/* begin */
			/* 	rdAddr[i] = phtIndex[i-5]; */
			/* end */
		end

		3'h6:
		begin
			rdAddr[0] = phtIndex[2];
			rdAddr[1] = phtIndex[3];
			rdAddr[2] = phtIndex[4];
			rdAddr[3] = phtIndex[5];
			rdAddr[4] = phtIndex[6];
			rdAddr[5] = phtIndex[7];
			rdAddr[6] = phtIndex[0];
			rdAddr[7] = phtIndex[1];
			/* for (i = 0; i < 6; i++) */
			/* begin */
			/* 	rdAddr[i] = phtIndex[BP_WIDTH-i-1]; */
			/* end */

			/* for (i = 6; i < BP_WIDTH; i++) */
			/* begin */
			/* 	rdAddr[i] = phtIndex[i-6]; */
			/* end */
		end

		3'h7:
		begin
			rdAddr[0] = phtIndex[1];
			rdAddr[1] = phtIndex[2];
			rdAddr[2] = phtIndex[3];
			rdAddr[3] = phtIndex[4];
			rdAddr[4] = phtIndex[5];
			rdAddr[5] = phtIndex[6];
			rdAddr[6] = phtIndex[7];
			rdAddr[7] = phtIndex[0];
			/* for (i = 0; i < 7; i++) */
			/* begin */
			/* 	rdAddr[i] = phtIndex[BP_WIDTH-i-1]; */
			/* end */

			/* for (i = 7; i < BP_WIDTH; i++) */
			/* begin */
			/* 	rdAddr[i] = phtIndex[i-7]; */
			/* end */
		end
`endif

	endcase
end


/* Rotate the data from the RAM output to the correct order */
always_comb
begin
	int i;

	for (i = 0; i < BP_WIDTH; i++)
	begin
		predCounter[i]  = 0;
	end

	case (instOffset[0]) // synopsys full_case

		3'h0:
		begin
			predCounter[0]  = rdData[0];
			predCounter[1]  = rdData[1];
`ifdef FETCH_THREE_WIDE
			predCounter[2]  = rdData[2];
			predCounter[3]  = rdData[3];
`endif

`ifdef FETCH_FIVE_WIDE
			predCounter[4]  = rdData[4];
			predCounter[5]  = rdData[5];
			predCounter[6]  = rdData[6];
			predCounter[7]  = rdData[7];
`endif
			/* for (i = 0; i < BP_WIDTH; i++) */
			/* begin */
			/* 	predCounter[i]  = rdData[i]; */
			/* end */
		end

		3'h1:
		begin
`ifndef FETCH_THREE_WIDE /* 1- or 2-wide */
			predCounter[0]  = rdData[1];
			predCounter[1]  = rdData[0];
`endif

`ifdef FETCH_THREE_WIDE
`ifndef FETCH_FIVE_WIDE /* 3- or 4-wide */
			predCounter[0]  = rdData[1];
			predCounter[1]  = rdData[2];
			predCounter[2]  = rdData[3];
			predCounter[3]  = rdData[0];
`endif
`endif

`ifdef FETCH_FIVE_WIDE /* 5+ wide */
			predCounter[0]  = rdData[1];
			predCounter[1]  = rdData[2];
			predCounter[2]  = rdData[3];
			predCounter[3]  = rdData[4];
			predCounter[4]  = rdData[5];
			predCounter[5]  = rdData[6];
			predCounter[6]  = rdData[7];
			predCounter[7]  = rdData[0];
`endif
			/* for (i = 0; i < BP_WIDTH-1; i++) */
			/* begin */
			/* 	predCounter[i]  = rdData[i+1]; */
			/* end */

			/* for (i = BP_WIDTH-1; i < BP_WIDTH; i++) */
			/* begin */
			/* 	predCounter[i]  = rdData[i-(BP_WIDTH-1)]; */
			/* end */
		end

`ifdef FETCH_THREE_WIDE
		3'h2:
		begin
`ifndef FETCH_FIVE_WIDE /* 3- or 4-wide */
			predCounter[0]  = rdData[2];
			predCounter[1]  = rdData[3];
			predCounter[2]  = rdData[0];
			predCounter[3]  = rdData[1];
`endif

`ifdef FETCH_FIVE_WIDE /* 5+ wide */
			predCounter[0]  = rdData[2];
			predCounter[1]  = rdData[3];
			predCounter[2]  = rdData[4];
			predCounter[3]  = rdData[5];
			predCounter[4]  = rdData[6];
			predCounter[5]  = rdData[7];
			predCounter[6]  = rdData[0];
			predCounter[7]  = rdData[1];
`endif
			/* for (i = 0; i < BP_WIDTH-2; i++) */
			/* begin */
			/* 	predCounter[i]  = rdData[i+2]; */
			/* end */

			/* for (i = BP_WIDTH-2; i < BP_WIDTH; i++) */
			/* begin */
			/* 	predCounter[i]  = rdData[i-(BP_WIDTH-2)]; */
			/* end */
		end

		3'h3:
		begin
`ifndef FETCH_FIVE_WIDE /* 3- or 4-wide */
			predCounter[0]  = rdData[3];
			predCounter[1]  = rdData[0];
			predCounter[2]  = rdData[1];
			predCounter[3]  = rdData[2];
`endif

`ifdef FETCH_FIVE_WIDE /* 5+ wide */
			predCounter[0]  = rdData[3];
			predCounter[1]  = rdData[4];
			predCounter[2]  = rdData[5];
			predCounter[3]  = rdData[6];
			predCounter[4]  = rdData[7];
			predCounter[5]  = rdData[0];
			predCounter[6]  = rdData[1];
			predCounter[7]  = rdData[2];
`endif
			/* for (i = 0; i < BP_WIDTH-3; i++) */
			/* begin */
			/* 	predCounter[i]  = rdData[i+3]; */
			/* end */

			/* for (i = BP_WIDTH-3; i < BP_WIDTH; i++) */
			/* begin */
			/* 	predCounter[i]  = rdData[i-(BP_WIDTH-3)]; */
			/* end */
		end
`endif

`ifdef FETCH_FIVE_WIDE
		3'h4:
		begin
			predCounter[0]  = rdData[4];
			predCounter[1]  = rdData[5];
			predCounter[2]  = rdData[6];
			predCounter[3]  = rdData[7];
			predCounter[4]  = rdData[0];
			predCounter[5]  = rdData[1];
			predCounter[6]  = rdData[2];
			predCounter[7]  = rdData[3];
			/* for (i = 0; i < BP_WIDTH-4; i++) */
			/* begin */
			/* 	predCounter[i]  = rdData[i+4]; */
			/* end */

			/* for (i = BP_WIDTH-4; i < BP_WIDTH; i++) */
			/* begin */
			/* 	predCounter[i]  = rdData[i-(BP_WIDTH-4)]; */
			/* end */
		end

		3'h5:
		begin
			predCounter[0]  = rdData[5];
			predCounter[1]  = rdData[6];
			predCounter[2]  = rdData[7];
			predCounter[3]  = rdData[0];
			predCounter[4]  = rdData[1];
			predCounter[5]  = rdData[2];
			predCounter[6]  = rdData[3];
			predCounter[7]  = rdData[4];
			/* for (i = 0; i < BP_WIDTH-5; i++) */
			/* begin */
			/* 	predCounter[i]  = rdData[i+5]; */
			/* end */

			/* for (i = BP_WIDTH-5; i < BP_WIDTH; i++) */
			/* begin */
			/* 	predCounter[i]  = rdData[i-(BP_WIDTH-5)]; */
			/* end */
		end

		3'h6:
		begin
			predCounter[0]  = rdData[6];
			predCounter[1]  = rdData[7];
			predCounter[2]  = rdData[0];
			predCounter[3]  = rdData[1];
			predCounter[4]  = rdData[2];
			predCounter[5]  = rdData[3];
			predCounter[6]  = rdData[4];
			predCounter[7]  = rdData[5];
			/* for (i = 0; i < BP_WIDTH-6; i++) */
			/* begin */
			/* 	predCounter[i]  = rdData[i+6]; */
			/* end */

			/* for (i = BP_WIDTH-6; i < BP_WIDTH; i++) */
			/* begin */
			/* 	predCounter[i]  = rdData[i-(BP_WIDTH-6)]; */
			/* end */
		end

		3'h7:
		begin
			predCounter[0]  = rdData[7];
			predCounter[1]  = rdData[0];
			predCounter[2]  = rdData[1];
			predCounter[3]  = rdData[2];
			predCounter[4]  = rdData[3];
			predCounter[5]  = rdData[4];
			predCounter[6]  = rdData[5];
			predCounter[7]  = rdData[6];
			/* for (i = 0; i < BP_WIDTH-7; i++) */
			/* begin */
			/* 	predCounter[i]  = rdData[i+7]; */
			/* end */

			/* for (i = BP_WIDTH-7; i < BP_WIDTH; i++) */
			/* begin */
			/* 	predCounter[i]  = rdData[i-(BP_WIDTH-7)]; */
			/* end */
		end
`endif

	endcase
end


/* Make prediction based on the counter value */
// Also create the predIndex to be stored in CTI
// queue so that it can be used while updating the
// counter values at commit if using non-speculative
// PHT update.  
always_comb
begin
	int i;
	for (i = 0; i < `FETCH_WIDTH; i++)
	begin
		predDir[i] = (predCounter[i] > 2'b01) ? 1'b1 : 1'b0;
		predCounter_o[i] = predCounter[i];
		predIndex_o[i]   = {instOffset[i],phtIndex[i]};
	end
end

assign predDir_o     = predDir;
/* assign predCounter_o = predCounter; */


/*** Storing th eindex in the CTI queue right now. Might change this later ****/
// TODO: Determine if storing the index in CTI queue is necessary.
// Try to figure out if the archBranchHistory can be used to 

// NOTE: If using archBranchHistory and updatePC to calculate the index and bank of the counter to be updated, a few 
//        different cases need to be considered:
//
// 1) In case of correct prediction of all branches previous to the branch in question and all branches hit in BTB:
//    In this case, when the branch is being committed, the archBranchHistory will reflect the state of the specBranchHistory
//    when the prediction for the branch in question was read out.
// 2) In case of incorrect prediction of all branches previous to the branch being updated and all branches hit in BTB:
//    In this case, the branch in question will never be committed and hence never updated as there is a misprediction
//    and consequently a recovery before this branch. The archBranchHistory will reflect the state of the specBranchHistory
//    when prediction for the mispredicted branch was read out although in this case, the PHT will not be updates since 
//    there is a misprediction. Hence this will not be a problem
// 3) Not all previous branches hit in the BTB and the branch that did not hit was actually not taken: 
//    In this case, the archBranchHistory will not reflect the state of the specBranchHistory when the prediction was made.
//    But, the specBranchHistory was incorrect and the prediction was made from a wrong index in the PHT. We should update
//    the correct counter in the PHT. One can get the correct index using branchPC and archBranchHistory but we will not
//    have the predicted counter for the index as while making the prediction, the couter was read out from a different 
//    index. We can ignore this anomaly and update the new index using the incorrect counter value but since this is probably
//    the most common case during operation, might lead to some inefficiencies.

/* Update the counter table from the CTI Queue */
wire [`FETCH_WIDTH_LOG-1:0]  updateOffset;
wire [1:0]  updateCounterMuxed;

`ifdef UPDATE_USING_ARCH_BHR
  reg  [BHR_WIDTH-1:0]  archBranchHistoryFlipped;
  always_comb
  begin
    int i;
    for( i = 0; i < BHR_WIDTH; i++)
      archBranchHistoryFlipped[i] = archBranchHistory[BHR_WIDTH-1-i];
  end
  assign  wrAddr        = archBranchHistoryFlipped[BHR_WIDTH-1:NUM_BITS_IGNORE-1] ^ updatePC_i[`SIZE_PC-1:`SIZE_INST_BYTE_OFFSET+`FETCH_WIDTH_LOG];
  assign  updateOffset  = updatePC_i[`SIZE_PC-1:`SIZE_INST_BYTE_OFFSET];
`else
  // Lower part of the Index is the row of a RAM
  assign  wrAddr           = updateIndex_i[`SIZE_CNT_TBL_LOG-`FETCH_WIDTH_LOG-1:0];
  // Higher bits select which RAM the write goes to
  assign  updateOffset     = updateIndex_i[`SIZE_CNT_TBL_LOG-1 -: `FETCH_WIDTH_LOG];
`endif

assign updateCounterMuxed = updateCounter[updateOffset];

/*** Even correctly updating the PHT in an out of order processor might be tricky ***/
// Althought the counter used to make the prediction for a particular branch is
// stored in the CTI queue, there is a possibility that by the time this branch
// commits, the particular entry in the PHT has been updated by a prior instruction.
// This is mainly a problem when the same count is used to predict multiple branches
// which are mipredicted. Instead of quickly taking the counter to saturation in the
// opposite direction, the update process will keep overwriting the counter with a 
// non-saturated count in the wrong direction leading to possible mispredicts in future
// A more frequent branch would otherwise saturate a counter giving a strong correct 
// prediction for the following instances. This can be avoided if, while updating, i
// the current value is read out, operated on and then written back. This can be easily
// done by adding another read port into the RAMs and pipelining the update process.

//TODO: This situation probably never happens and so is giving a worse performance
// due to latency of updates
`ifdef PIPELINED_PHT_UPDATE
always_ff @(posedge clk)
begin
  int i;
  if(reset)
  begin
	  wrData           <= 2'b0; 
    wrAddr_d1        <= {INDEX{1'b0}};                     
	  for (i = 0; i < BP_WIDTH; i++)
	  begin
	  	wrEn[i]   <= 1'b0;
	  end


  end
  else
  begin
	  wrData           <= updateDir_i ?

	                   ((updateCounterMuxed == 2'b11) ?
	                     updateCounterMuxed :
	                     updateCounterMuxed + 1) :

	                   ((updateCounterMuxed == 2'b00) ?
	                     updateCounterMuxed :
	                     updateCounterMuxed - 1);
    wrAddr_d1        <= wrAddr;                     
    // Just a decoder
	  for (i = 0; i < BP_WIDTH; i++)
	  begin
	  	wrEn[i]   <= updateEn_i && (updateOffset == i);
	  end
  end

end
`else
always_comb
begin
	int i;
	wrData           = updateDir_i ?

	                  ((updateCounter_i == 2'b11) ?
	                   updateCounter_i :
	                   updateCounter_i + 1) :

	                 ((updateCounter_i == 2'b00) ?
	                   updateCounter_i :
	                   updateCounter_i - 1);

  // Just a decoder
	for (i = 0; i < BP_WIDTH; i++)
	begin
		wrEn[i] = updateEn_i && (updateOffset == i);
	end

end
`endif

`ifdef SIM_1
// Test Point or print point for the module
// If adding signals, add corresponding signals in the structure as well

  testPoint.wrAddr = wrAddr;
  testPoint.wrEn   = wrEn;
  wrData = wrData;
  updatePC_i = updatePC_i;
  updateIndex_i = updateIndex_i;
  predDir = predDir;
  predIndex = predIndex;
  specBranchHistory = specBranchHistory;
  specBranchHistoryNext = specBranchHistoryNext;
  archBranchHistory = archBranchHistory;
  numShifts = numShifts;
  shiftVect = shiftVect;

`endif


endmodule

