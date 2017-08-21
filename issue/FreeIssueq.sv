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

module FreeIssueq (

	input                          clk,
	input                          reset,

  // Number of freelist write ports does not depend on issue lanes.
  // It is an independent design parameter and determines the freeing of 
  // issue queue entries. Hence the write ports are never gated.
//`ifdef DYNAMIC_CONFIG
//  // This is required to control the number of entries
//  // being freed in one cycle depending upon the number
//  // of available write ports in the Free List RAM.
//  input [`ISSUE_WIDTH-1:0]       issueLaneActive_i,
//`endif
	
	input  iqEntryPkt              grantedEntry_i [0:`ISSUE_WIDTH-1],
	output iqEntryPkt              freedEntry_o   [0:`ISSUE_WIDTH-1]
	);


/* wires and regs declaration for combinational logic. */
reg  [`SIZE_ISSUEQ-1:0]     freedVector;
reg  [`SIZE_ISSUEQ-1:0]     freedVector_t;

wire                        freeingScalar    [0:`ISSUE_WIDTH-1];
wire [`SIZE_ISSUEQ_LOG-1:0] freeingCandidate [0:`ISSUE_WIDTH-1];

iqEntryPkt                  freedEntry [0:`ISSUE_WIDTH-1];

localparam ENTRY_PER_BLOCK = `SIZE_ISSUEQ/`ISSUE_WIDTH;

always_comb
begin
	int i;
	for (i = 0; i < `ISSUE_WIDTH; i++)
	begin
		freedEntry_o[i] = freedEntry[i];
	end
end


/* Following combinational logic updates the freedValid vector based on:
 *   1. if there are instructions issued this cycle from issue queue
 *      (they need to be freed)
 *   2. if there is a branch mispredict this cycle, freedVector need to
 *      be updated with mispredictVector.
 *   3. if a issue queue entry has been freed this cycle, its corresponding
 *      bit in the freedVector should be set to 0.
 */

always_comb
begin: UPDATE_FREED_VECTOR
	int i, j;
	reg              grantedEntryMatch;
	reg              freedEntryMatch;
	reg  [`SIZE_ISSUEQ-1:0]     freedVector_t1;

	for (i = 0; i < `ISSUE_WIDTH; i = i + 1)
	begin
		freedEntry[i].valid = freeingScalar[i];

    // RBRC: Free an entry only if sufficient write ports are available into
    // FreeList RAM
  //`ifdef DYNAMIC_CONFIG
	//	if (freeingScalar[i] & issueLaneActive_i[i])
  //`else
		if (freeingScalar[i])
  //`endif
		begin
			freedEntry[i].id = (ENTRY_PER_BLOCK*i) + freeingCandidate[i];
		end

		else
		begin
			freedEntry[i].id = 0;
		end
	end

	freedVector_t1 = freedVector;


	for (i = 0; i < `SIZE_ISSUEQ; i = i + 1)
	begin
		grantedEntryMatch = 0;
		freedEntryMatch   = 0;

		for (j = 0; j < `ISSUE_WIDTH; j = j + 1)
		begin
			grantedEntryMatch = grantedEntryMatch || (grantedEntry_i[j].valid && (i == grantedEntry_i[j].id));
			freedEntryMatch   = freedEntryMatch   || (freedEntry[j].valid   && (i == freedEntry[j].id));
		end

		if (grantedEntryMatch)
		begin
			freedVector_t[i] = 1'b1;
		end

		else if (freedEntryMatch)
		begin
			freedVector_t[i] = 1'b0;
		end

		else
		begin
			freedVector_t[i] = freedVector_t1[i];
		end
	end
end

/* Following writes newly computed freed vector to freedVector register every cycle. */
always_ff @(posedge clk or posedge reset)
begin
	if (reset)
	begin
		freedVector <= 0;
	end

	else
	begin
		freedVector <= freedVector_t;
	end
end

/* Following instantiate "SelectFromBlock" module to get upto 8 freed issue queue
 * entries this cycle. The number of entries that can be freed in one cycle is
 * limitted by the number of write ports in the IQFreeList queue. Hence some
 * sort of selection mechanism is required as more than 8 issue entries might be
 * free at a time */

//* If `SIZE_ISSUEQ/`ISSUE_WIDTH is not an integer, the last select block will be larger.
localparam LAST_EPB = `SIZE_ISSUEQ - ((`ISSUE_WIDTH-1) * ENTRY_PER_BLOCK);

genvar g;
generate
for (g = 0; g < `ISSUE_WIDTH-1; g = g + 1)
begin : SelectFromBlock_gen

  reg freeingScalar_t;

	SelectFromBlock #(
		.ENTRY_PER_BLOCK  (ENTRY_PER_BLOCK)
		)
		SelectFromBlock_0 (
		.blockVector_i      (freedVector[g*ENTRY_PER_BLOCK +: ENTRY_PER_BLOCK]),
		.freeingScalar_o    (freeingScalar_t),
		.freeingCandidate_o (freeingCandidate[g])
		);

//  `ifdef DYNAMIC_CONFIG    
//    // RBRC: Free an entry only if sufficient write ports are available into
//    // FreeList RAM
//    assign freeingScalar[g] = freeingScalar_t & issueLaneActive_i[g];
//  `else
    assign freeingScalar[g] = freeingScalar_t;
//  `endif

end

wire freeingScalar_t_1;

SelectFromBlock #(
	.ENTRY_PER_BLOCK  (LAST_EPB)
	)
	SelectFromBlock_1 (
	.blockVector_i      (freedVector[(`ISSUE_WIDTH-1)*ENTRY_PER_BLOCK +: LAST_EPB]),
	.freeingScalar_o    (freeingScalar_t_1),
	.freeingCandidate_o (freeingCandidate[(`ISSUE_WIDTH-1)])
	);

//  `ifdef DYNAMIC_CONFIG    
//    // RBRC: Free an entry only if sufficient write ports are available into
//    // FreeList RAM
//    assign freeingScalar[(`ISSUE_WIDTH-1)] = freeingScalar_t_1 & issueLaneActive_i[(`ISSUE_WIDTH-1)];
//  `else
    assign freeingScalar[(`ISSUE_WIDTH-1)] = freeingScalar_t_1;
//  `endif

endgenerate

endmodule
