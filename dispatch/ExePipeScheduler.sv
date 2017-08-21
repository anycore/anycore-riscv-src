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


/*******************************************************************************
*******************************************************************************/


/*******************************************************************************
 Inputs:
 1. clk: Processor clock
 2. reset: Processor reset signal
 3. recoverFlag_i: Signal broadcasted by the AL on the occurance of a bad-event
    (eg. branch-misprediction, load-violation).

 Outputs:
*******************************************************************************/


`timescale 1ns/100ps

module ExePipeScheduler(
	input                             clk,
	input                             reset,
  
`ifdef DYNAMIC_CONFIG  
  input   [`ISSUE_WIDTH-1:0]         execLaneActive_i,
  input   [`ISSUE_WIDTH-1:0]         saluLaneActive_i,
  input   [`ISSUE_WIDTH-1:0]         caluLaneActive_i,
`endif  

	input                             recoverFlag_i,
	input                             backEndReady_i,

	input      [`INST_TYPES_LOG-1:0]  instTypes_i [0:`DISPATCH_WIDTH-1],

	output reg                        isSimple_o  [0:`DISPATCH_WIDTH-1],
	output reg                        isFP_o  [0:`DISPATCH_WIDTH-1],
	output reg [`ISSUE_WIDTH_LOG-1:0] exePipes_o  [0:`DISPATCH_WIDTH-1]
	);


/* One exePipePtr for each instruction type. Instructions are scheduled to
 * the pipe that their pointer currently points to. */
reg  [`ISSUE_WIDTH_LOG-1:0]         exePipePtr      [0:3];
reg  [`ISSUE_WIDTH_LOG-1:0]         exePipePtr_next [0:3];



/* The following piece of logic finds out the next EXEC lane 
 * that can be used for a particular kind of instruction. It 
 * achieves this by using a priority encoder on a bit vector.
 * The bit vector indicates which lanes are usable and active
 * for a particular type of instruction. The bit representing 
 * the lane used in current cycle in masked to 0 so that it is
 * not used in the next cycle. This continues until all bits(lanes)
 * have been used and at this point the vector is reloaded from
 * the original vector. So the whole schedule repeats again.
*/
`ifdef DYNAMIC_CONFIG

  wire  [`ISSUE_WIDTH-1:0] simpleExecVect;
  wire  [`ISSUE_WIDTH-1:0] complexExecVect;

  // Depending upon configuration, one might want to schedule Complex instructions
  // only to a subset of the CALUs. Same might be true for Simple instructions.
  // This is why separate caluLaneActive_i and saluLaneActive_i are used as there
  // might be lanes which are capable of both simple and complex instructions but
  // one might want to use it for only one instruction type.
  assign simpleExecVect   = execLaneActive_i & saluLaneActive_i & `SIMPLE_VECT;
  assign complexExecVect  = execLaneActive_i & caluLaneActive_i & `COMPLEX_VECT;

  always_comb
  begin:POINTER_CALCULATION_SIMPLE
    reg [`ISSUE_WIDTH_LOG:0] exePipePtrPlusOne[0:3];
    reg [`ISSUE_WIDTH_LOG:0] exePipePtrMinusOne[0:3];

  	/* Memory instructions always go to pipe 0 */
  	exePipePtr_next[0]   = 3'h0;
  
  	/* Control instructions always go to pipe 1 */
  	exePipePtr_next[1]   = 3'h1;


    /* Find the next pipe for simple instructions. The pipes that support simple
    * instructions are always pipes [2:2+m), where m is the number of pipes
    * supporting simple instructions. */

    exePipePtrPlusOne[2] = exePipePtr[2] + 1'b1;
    if(exePipePtrPlusOne[2] >= `ISSUE_WIDTH)
      exePipePtrPlusOne[2] = 2; // Revert to first simple lane

    // If the particular lane is inactive, fall back to 
    // the first lane
    if(simpleExecVect[exePipePtrPlusOne[2]] == 1'b0)
      exePipePtr_next[2] = 3'd2;
    else
      exePipePtr_next[2] = exePipePtrPlusOne[2];


    /* Find the next pipe for complex instructions. The pipes that support complex
    * instructions are always the last n pipes, where n is the number of pipes
    * supporting complex instructions. */

    exePipePtrPlusOne[3] = exePipePtr[3] + 1'b1;
    if(exePipePtrPlusOne[3] >= `ISSUE_WIDTH)
      exePipePtrPlusOne[3] = 2; // Revert to first complex lane

    //exePipePtrMinusOne = exePipePtr[3] - 1'b1;

    // If the particular lane is inactive, fall back to 
    // the last lane
    // NOTE: Complex lanes must be turned off from high to low
    if(complexExecVect[exePipePtrPlusOne[3]] == 1'b0)
      exePipePtr_next[3] = 3'd2;
    else
      exePipePtr_next[3] = exePipePtrPlusOne[3];
  end
 

`else // NOT DYNAMIC_CONFIG

  always_comb
  begin : POINTER_CALCULATION
  
  	/* Memory instructions always go to pipe 0 */
  	exePipePtr_next[0]   = 3'h0;
  
  	/* Control instructions always go to pipe 1 */
  	exePipePtr_next[1]   = 3'h1;
  
  /* Find the next pipe for simple instructions. The pipes that support simple
   * instructions are always pipes [2:2+m), where m is the number of pipes
   * supporting simple instructions. */
  	case (exePipePtr[2])
  `ifdef SIX_SIMPLE
  		3'd6 : exePipePtr_next[2]   = 3'd7;
  `endif
  
  `ifdef FIVE_SIMPLE
  		3'd5 : exePipePtr_next[2]   = 3'd6;
  `endif
  
  `ifdef FOUR_SIMPLE
  		3'd4 : exePipePtr_next[2]   = 3'd5;
  `endif
  
  `ifdef THREE_SIMPLE
  		3'd3 : exePipePtr_next[2]   = 3'd4;
  `endif
  
  `ifdef TWO_SIMPLE
  		3'd2 : exePipePtr_next[2]   = 3'd3;
  `endif
  		default: exePipePtr_next[2] = 3'd2;
  	endcase
  
  
  /* Find the next pipe for complex instructions. The pipes that support complex
   * instructions are always the last n pipes, where n is the number of pipes
   * supporting complex instructions. */
  
  `ifdef ISSUE_EIGHT_WIDE
  	case (exePipePtr[3])
  `ifdef SIX_COMPLEX
  		3'd6 : exePipePtr_next[3]   = 3'd7;
  `endif
  
  `ifdef FIVE_COMPLEX
  		3'd5 : exePipePtr_next[3]   = 3'd6;
  `endif
  
  `ifdef FOUR_COMPLEX
  		3'd4 : exePipePtr_next[3]   = 3'd5;
  `endif
  
  `ifdef THREE_COMPLEX
  		3'd3 : exePipePtr_next[3]   = 3'd4;
  `endif
  
  `ifdef TWO_COMPLEX
  		3'd2 : exePipePtr_next[3]   = 3'd3;
  `endif
  		default: exePipePtr_next[3] = 3'd2;
  	endcase
  
  `elsif ISSUE_SEVEN_WIDE
  	case (exePipePtr[3])
  `ifdef FIVE_COMPLEX
  		3'd5 : exePipePtr_next[3]   = 3'd6;
  `endif
  
  `ifdef FOUR_COMPLEX
  		3'd4 : exePipePtr_next[3]   = 3'd5;
  `endif
  
  `ifdef THREE_COMPLEX
  		3'd3 : exePipePtr_next[3]   = 3'd4;
  `endif
  
  `ifdef TWO_COMPLEX
  		3'd2 : exePipePtr_next[3]   = 3'd3;
  `endif
  		default: exePipePtr_next[3] = 3'd2;
  	endcase
  
  `elsif ISSUE_SIX_WIDE
  	case (exePipePtr[3])
  `ifdef FOUR_COMPLEX
  		3'd4 : exePipePtr_next[3]   = 3'd5;
  `endif
  
  `ifdef THREE_COMPLEX
  		3'd3 : exePipePtr_next[3]   = 3'd4;
  `endif
  
  `ifdef TWO_COMPLEX
  		3'd2 : exePipePtr_next[3]   = 3'd3;
  `endif
  		default: exePipePtr_next[3] = 3'd2;
  	endcase
  
  `elsif ISSUE_FIVE_WIDE
  	case (exePipePtr[3])
  `ifdef THREE_COMPLEX
  		3'd3 : exePipePtr_next[3]   = 3'd4;
  `endif
  
  `ifdef TWO_COMPLEX
  		3'd2 : exePipePtr_next[3]   = 3'd3;
  `endif
  		default: exePipePtr_next[3] = 3'd2;
  	endcase
  
  `elsif ISSUE_FOUR_WIDE
  	case (exePipePtr[3])
  `ifdef TWO_COMPLEX
  		3'd2 : exePipePtr_next[3]   = 3'd3;
  `endif
  		default: exePipePtr_next[3] = 3'd2;
  	endcase
  
  `elsif ISSUE_THREE_WIDE
  	exePipePtr_next[3]            = 3'h2;
  `endif
  end

`endif  // `ifdef DYNAMIC_CONFIG

localparam FUNC_TYPES = 4; // The classes of instructions

reg                      advPtr [0:FUNC_TYPES-1];

`ifdef FIVE_SIMPLE
  localparam               MAX_LANE_S = 6 ;
`elsif FOUR_SIMPLE
  localparam               MAX_LANE_S = 5 ;
`elsif THREE_SIMPLE
  localparam               MAX_LANE_S = 4 ;
`elsif TWO_SIMPLE
  localparam               MAX_LANE_S = 3 ;
`else
  localparam               MAX_LANE_S = 2 ;
`endif

reg [`ISSUE_WIDTH_LOG-1:0] exePipePtr_S[0:`DISPATCH_WIDTH-1];

/* Schedule each instruction based on its type. */
always_comb
begin:FU_ALLOCATION_COMBO
	int i;
  reg [`ISSUE_WIDTH_LOG-1:0] exePipePtr_S_t;

  for(i = 0; i < FUNC_TYPES; i++)
  begin
    advPtr[i]          = 0;
  end

  // Allocate a different FU lane for each 
  // simple int in the bundle. This should
  // improve nearby ILP extraction.
  // 
  exePipePtr_S_t = exePipePtr[2];

	for (i = 0; i < `DISPATCH_WIDTH; i++)
	begin
    if(instTypes_i[i] == `SIMPLE_TYPE)
    begin
      exePipePtr_S_t = exePipePtr_S_t + 1'b1;
      if(exePipePtr_S_t > MAX_LANE_S)
      begin
        exePipePtr_S_t = 2;
      end
    end

    exePipePtr_S[i] = exePipePtr_S_t;
  end

	for (i = 0; i < `DISPATCH_WIDTH; i++)
	begin
		isSimple_o[i]      = 0;
		isFP_o[i]          = 0;

		case (instTypes_i[i])

			`MEMORY_TYPE:
			begin
				exePipes_o[i]  = exePipePtr[0];
				advPtr[0]      = 1'h1;
			end

			`CONTROL_TYPE:
			begin
				exePipes_o[i]  = exePipePtr[1];
				advPtr[1]      = 1'h1;
			end

			`SIMPLE_TYPE:
			begin
        `ifdef NEW_SCHED
  				exePipes_o[i]  = exePipePtr_S[i];
        `else
  				exePipes_o[i]  = exePipePtr[2];
        `endif
				advPtr[2]      = 1'h1;
				isSimple_o[i]  = 1'h1;
			end

     `FP_TYPE:  //Replicating SIMPLE TYPE code, as FP are to be considered Simple as far as the latency is concerned
			begin
        `ifdef NEW_SCHED
  				exePipes_o[i]  = exePipePtr_S[i];
        `else
  				exePipes_o[i]  = exePipePtr[2];
        `endif
				advPtr[2]      = 1'h1;
				isSimple_o[i]  = 1'h1;
				isFP_o[i]  = 1'h1;
			end

			`COMPLEX_TYPE:
			begin
				exePipes_o[i]  = exePipePtr[3];
				advPtr[3]      = 1'h1;
			end
		endcase
	end
end


/* Update each pointer that was used this cycle */
always_ff @(posedge clk or posedge reset)
begin : POINTER_UPDATE
	int i;

	if (reset)
	begin
		//exePipePtr[0] <= exePipePtr_next[0];
		//exePipePtr[1] <= exePipePtr_next[1];
		//exePipePtr[2] <= exePipePtr_next[2];
		//exePipePtr[3] <= exePipePtr_next[3];
		exePipePtr[0] <= 0;
		exePipePtr[1] <= 1;
		exePipePtr[2] <= 2;              // Second lane is always simple
		exePipePtr[3] <= 2;              // Second lane is always complex
	end

	else if (backEndReady_i)
	begin
		if (advPtr[0])
		begin
			exePipePtr[0] <= exePipePtr_next[0];
		end

		if (advPtr[1])
		begin
			exePipePtr[1] <= exePipePtr_next[1];
		end

		if (advPtr[2])
		begin
			exePipePtr[2] <= exePipePtr_next[2];
		end

		if (advPtr[3])
		begin
			exePipePtr[3] <= exePipePtr_next[3];
		end
	end
end

endmodule

