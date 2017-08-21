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
  The RenameLane module conatins most of the priority and other combinational 
  logic for the renaming operation of a single lane


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
    4a) Compare each valid logDest in the bundle
    4b) Update the RMT with the youngest mapping for each logical dest value. 

***************************************************************************/

`timescale 1ns/100ps

module RenameLane 
  #(parameter LANE_ID=0)
  (

  //input [`DISPATCH_WIDTH-1:0]      dispatchLaneActive_i,
  input                            laneActive_i,  // Used for Power gating

	/* Repair the RMT to the state of the AMT while repairFlag_i is high */

	input  log_reg                   logDest_i   [0:`DISPATCH_WIDTH-1],
	input  log_reg                   logSrc1_i   ,
	input  log_reg                   logSrc2_i   ,

	input  [`SIZE_PHYSICAL_LOG-1:0]  free_phys_i [0:`DISPATCH_WIDTH-1],
	input  [`SIZE_PHYSICAL_LOG-1:0]  phyDest_i   [0:LANE_ID],
  input  [`SIZE_PHYSICAL_LOG-1:0]  rmtMapping1 ,
  input  [`SIZE_PHYSICAL_LOG-1:0]  rmtMapping2 ,

	output reg [`SIZE_PHYSICAL_LOG-1:0]  phyDest,
  output reg [`SIZE_PHYSICAL_LOG-1:0]  phySrc1,
  output reg [`SIZE_PHYSICAL_LOG-1:0]  phySrc2,
  output reg                           dontWriteRMT   

	);



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
	int j;

	/* Default is the RMT mapping */
	phySrc1 = rmtMapping1;

	/* Iterate over all older instructions looking for a match */
	for (j = 0; j < LANE_ID; j++)
	begin
		//if ((logSrc1_i == logDest_i[j]) & dispatchLaneActive_i[j])
    // It is just not possible for a lower numbered lane to be inactive
    // while this lane is active. Hence no qualification using 
    // dispatchLaneActive is needed. Moreover, logDest.valid already
    // accounts for dispatchLaneActive.
		if ((logSrc1_i == logDest_i[j]))
		begin
			phySrc1 = phyDest_i[j];
		end
	end

	/* Default is the RMT mapping */
	phySrc2 = rmtMapping2;

	/* Iterate over all older instructions looking for a match */
	for (j = 0; j < LANE_ID; j++)
	begin
    // It is just not possible for a lower numbered lane to be inactive
    // while this lane is active. Hence no qualification using 
    // dispatchLaneActive is needed. Moreover, logDest.valid already
    // accounts for dispatchLaneActive.
		//if ((logSrc2_i == logDest_i[j]) & dispatchLaneActive_i[j])
		if ((logSrc2_i == logDest_i[j]))
		begin
			phySrc2 = phyDest_i[j];
		end
	end
end


/*******************************************************************************
* 4 (a) Following assigns physical registers (popped from the spec free list)
*       to the destination registers.
*******************************************************************************/

always_comb
begin
	int i;
	reg  [`DISPATCH_WIDTH-1:0]      logDestValid;
  reg  [`DISPATCH_WIDTH_LOG-1:0]  validInstrBefore;

	for (i = 0; i < `DISPATCH_WIDTH; i++)
	begin
		logDestValid[i]    = logDest_i[i].valid;
	end
  
  phyDest         = logDest_i[LANE_ID].reg_id; // Default to phyDest = logDest

  // (a) Count the number of valid destinations in lanes lower than this one
  // This logic has unequal delay, longer delay for higher lanes.
  validInstrBefore = 0;
  for(i = 0; i < LANE_ID; i++)
  begin
    validInstrBefore = validInstrBefore + logDestValid[i];
  end

  // (b) Select the next available free physical register
  phyDest = free_phys_i[validInstrBefore];

end

/* 4(b) Update the RMT with the youngest mapping for each logical dest value. 
 *      If the logical destination register matches with destination of the newer
 *      instruction in the rename bundle, then this instruction doesn't 
 *      update the RMT (dontWriteRMT will be high for the younger instrtuction). */
always_comb
begin
	int j;

	dontWriteRMT = 1'b0;

	/* Iterate over each newer instruction. If a newer instruction
     renames the same logical destination register then don't write
     the mapping for this instruction to the RMT. */
	for (j = LANE_ID+1; j < `DISPATCH_WIDTH; j++)
	begin

		//if ((logDest_i[LANE_ID] == logDest_i[j]) & dispatchLaneActive_i[j])
    // logDest_i.valid already accounts for dispatchLaneActive.
		if ((logDest_i[LANE_ID] == logDest_i[j]))
		begin
			dontWriteRMT = 1'b1;
		end
	end
end

endmodule
