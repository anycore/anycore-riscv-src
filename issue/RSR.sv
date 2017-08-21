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


// rsr /////////////////////////////////////////////////////////////////////////
// rsrs are shift registers that delay the broadcasting of bypass tags for
// wakeup. the number of delay cycles is equal to the number of cycles the
// instruction will spend executing. note: this excludes cycles spent the in
// register read stage. currently simple and control instructions take 1 cycle
// to execute, complex instructions take `FU1_LATENCY, and loads have an
// indeterminate latency. tags for simple and control instructions will be
// broadcasted by the rsr 1 cycle after they are issued, tags for complex 
// instructions will be broadcasted `FU1_LATENCY cycles after issue. Since loads
// may miss/stall in the lsu, they broadcast their tags from the writeback stage
// and do not use the rsr. 
// for lanes that support simple and complex instructions, care must be taken so
// that a simple instruction and complex instruction do not finish execution in
// the same cycle. complex instructions deposit their bypass tag into the end of
// the rsr for that lane. when the tag is 1 cycle away from being broadcasted,
// the select logic will ignore any simple instructions in that lane. this is
// done by the ignoreSimple_o signal which is just the rsr valid signal one stage
// back from the head. simple instructions deposit their tag into the head of
// the rsr. the ignoreSimple_o signal guarantees that there will not be a conflict
// between a simple and complex instruction for the head position.
////////////////////////////////////////////////////////////////////////////////

module RSR (
	input                           clk,
	input                           reset,
	
	input                           ISsimple_i    [0:`ISSUE_WIDTH-1],
	input  phys_reg                 grantedDest_i [0:`ISSUE_WIDTH-1],

	output phys_reg                 rsrTag_o [0:`ISSUE_WIDTH-1],
	output [`ISSUE_WIDTH-1:0]       ignoreSimple_o
	);


// execution pipe 0 ///////////
assign ignoreSimple_o[0]  = 1'h0;

reg  [`SIZE_PHYSICAL_LOG-1:0] RSR0          [1:0];
reg                           RSR0_VALID    [1:0];

assign rsrTag_o[0].valid    = RSR0_VALID[0];
assign rsrTag_o[0].reg_id   = RSR0[0];

always_ff @(posedge clk)
begin:UPDATE0
    if (reset)
    begin
      RSR0[1]                <= 0; 
      RSR0_VALID[1]          <= 0; 
      RSR0[0]                <= 0; 
      RSR0_VALID[0]          <= 0; 
    end
    else
    begin
      RSR0[1]                <= grantedDest_i[0].reg_id;
      RSR0_VALID[1]          <= grantedDest_i[0].valid;
      RSR0[0]                <= RSR0[1];
      RSR0_VALID[0]          <= RSR0_VALID[1];
    end
end

// execution pipe 1 ///////////////////////////////////
reg  [`SIZE_PHYSICAL_LOG-1:0] ctrlTag;
reg                           ctrlGranted;
reg  [`SIZE_PHYSICAL_LOG-1:0] RSR1          [0:0];
reg                           RSR1_VALID    [0:0];

assign ignoreSimple_o[1]    = 1'h0;

assign rsrTag_o[1].valid    = RSR1_VALID[0];
assign rsrTag_o[1].reg_id   = RSR1[0];

always_ff @(posedge clk)
begin:UPDATE1
    RSR1[0]                <= grantedDest_i[1].reg_id;
    RSR1_VALID[0]          <= grantedDest_i[1].valid;
end
///////////////////////////////////////////////////////


`ifdef ISSUE_THREE_WIDE
// execution pipe 2 ///////////////////////////////////
reg  [`SIZE_PHYSICAL_LOG-1:0] simpleTag2;
reg                           simpleGranted2;
reg  [`SIZE_PHYSICAL_LOG-1:0] complexTag2;
reg                           complexGranted2;
reg  [`SIZE_PHYSICAL_LOG-1:0] RSR2          [`FU1_LATENCY-1:0];
reg                           RSR2_VALID    [`FU1_LATENCY-1:0]; 

assign ignoreSimple_o[2]    = RSR2_VALID[1];

assign rsrTag_o[2].valid    = RSR2_VALID[0];
assign rsrTag_o[2].reg_id   = RSR2[0];

always_comb
begin
    simpleTag2              = grantedDest_i[2].reg_id;
    complexTag2             = grantedDest_i[2].reg_id;

    if (grantedDest_i[2].valid && ISsimple_i[2])
    begin
        simpleGranted2      = 1'h1;
        complexGranted2     = 1'h0;
    end

    else if (grantedDest_i[2].valid && !ISsimple_i[2])
    begin
        simpleGranted2      = 1'h0;
        complexGranted2     = 1'h1;
    end

    else
    begin
        simpleGranted2      = 1'h0;
        complexGranted2     = 1'h0;
    end
end

// manage the rsr shift register
// complex tags enter at the tail. 
// simple tags enter at the head.
always_ff @(posedge clk)
begin:UPDATE2
    int i;

    if (reset)
    begin
        for(i = 0; i < `FU1_LATENCY; i++)
        begin
            RSR2[i]        <= 0;
            RSR2_VALID[i]  <= 0;
        end
    end

    else
    begin
        // deposit complex tags at the tail
        RSR2[`FU1_LATENCY-1]             <= complexTag2;
        RSR2_VALID[`FU1_LATENCY-1]       <= complexGranted2;

        // perform the shift
        for (i = 1; i < `FU1_LATENCY-1; i++)
        begin
            RSR2[i]        <= RSR2[i+1];
            RSR2_VALID[i]  <= RSR2_VALID[i+1];
        end

        // override the head position if a simple has been granted.
        // as explained above, we can safely ignore any potential 
        // for conflicts when overwriting the head.
        if (simpleGranted2)
        begin
            RSR2[0]        <= simpleTag2;
            RSR2_VALID[0]  <= 1'h1;
        end
        else
        begin
            RSR2[0]        <= RSR2[1];
            RSR2_VALID[0]  <= RSR2_VALID[1];
        end
    end
end
///////////////////////////////////////////////////////
`endif


`ifdef ISSUE_FOUR_WIDE
// execution pipe 3 ///////////////////////////////////
reg  [`SIZE_PHYSICAL_LOG-1:0] simpleTag3;
reg                           simpleGranted3;
reg  [`SIZE_PHYSICAL_LOG-1:0] complexTag3;
reg                           complexGranted3;
reg  [`SIZE_PHYSICAL_LOG-1:0] RSR3          [`FU1_LATENCY-1:0];
reg                           RSR3_VALID    [`FU1_LATENCY-1:0]; 

assign ignoreSimple_o[3]    = RSR3_VALID[1];

assign rsrTag_o[3].valid    = RSR3_VALID[0];
assign rsrTag_o[3].reg_id   = RSR3[0];

always_comb
begin
    simpleTag3              = grantedDest_i[3].reg_id;
    complexTag3             = grantedDest_i[3].reg_id;

    if (grantedDest_i[3].valid && ISsimple_i[3])
    begin
        simpleGranted3      = 1'h1;
        complexGranted3     = 1'h0;
    end

    else if (grantedDest_i[3].valid && !ISsimple_i[3])
    begin
        simpleGranted3      = 1'h0;
        complexGranted3     = 1'h1;
    end

    else
    begin
        simpleGranted3      = 1'h0;
        complexGranted3     = 1'h0;
    end
end

// manage the rsr shift register
// complex tags enter at the tail. 
// simple tags enter at the head.
always_ff @(posedge clk)
begin:UPDATE3
    int i;

    if (reset)
    begin
        for(i = 0; i < `FU1_LATENCY; i++)
        begin
            RSR3[i]         <= 0;
            RSR3_VALID[i]   <= 0;
        end
    end

    else
    begin
        // deposit complex tags at the tail
        RSR3[`FU1_LATENCY-1]             <= complexTag3;
        RSR3_VALID[`FU1_LATENCY-1]       <= complexGranted3;

        // perform the shift
        for (i = 1; i < `FU1_LATENCY-1; i++)
        begin
            RSR3[i]       <= RSR3[i+1];
            RSR3_VALID[i] <= RSR3_VALID[i+1];
        end

        // override the head position if a simple has been granted.
        // as explained above, we can safely ignore any potential 
        // for conflicts when overwriting the head.
        if (simpleGranted3)
        begin
            RSR3[0]       <= simpleTag3;
            RSR3_VALID[0] <= 1'h1;
        end
        else
        begin
            RSR3[0]       <= RSR3[1];
            RSR3_VALID[0] <= RSR3_VALID[1];
        end
    end
end
///////////////////////////////////////////////////////
`endif


`ifdef ISSUE_FIVE_WIDE
// execution pipe 4 ///////////////////////////////////
reg  [`SIZE_PHYSICAL_LOG-1:0] simpleTag4;
reg                           simpleGranted4;
reg  [`SIZE_PHYSICAL_LOG-1:0] complexTag4;
reg                           complexGranted4;
reg  [`SIZE_PHYSICAL_LOG-1:0] RSR4          [`FU1_LATENCY-1:0];
reg                           RSR4_VALID    [`FU1_LATENCY-1:0]; 

assign ignoreSimple_o[4]    = RSR4_VALID[1];

assign rsrTag_o[4].valid    = RSR4_VALID[0];
assign rsrTag_o[4].reg_id   = RSR4[0];

always_comb
begin
    simpleTag4  = grantedDest_i[4].reg_id;
    complexTag4 = grantedDest_i[4].reg_id;

    if (grantedDest_i[4].valid && ISsimple_i[4])
    begin
        simpleGranted4  = 1'h1;
        complexGranted4 = 1'h0;
    end

    else if (grantedDest_i[4].valid && !ISsimple_i[4])
    begin
        simpleGranted4  = 1'h0;
        complexGranted4 = 1'h1;
    end

    else
    begin
        simpleGranted4  = 1'h0;
        complexGranted4 = 1'h0;
    end
end

// manage the rsr shift register
// complex tags enter at the tail. 
// simple tags enter at the head.
always_ff @(posedge clk)
begin:UPDATE4
    int i;

    if (reset)
    begin
        for(i = 0; i < `FU1_LATENCY; i++)
        begin
            RSR4[i]         <= 0;
            RSR4_VALID[i]   <= 0;
        end
    end

    else
    begin
        // deposit complex tags at the tail
        RSR4[`FU1_LATENCY-1]             <= complexTag4;
        RSR4_VALID[`FU1_LATENCY-1]       <= complexGranted4;

        // perform the shift
        for (i = 1; i < `FU1_LATENCY-1; i++)
        begin
            RSR4[i]       <= RSR4[i+1];
            RSR4_VALID[i] <= RSR4_VALID[i+1];
        end

        // override the head position if a simple has been granted.
        // as explained above, we can safely ignore any potential 
        // for conflicts when overwriting the head.
        if (simpleGranted4)
        begin
            RSR4[0]       <= simpleTag4;
            RSR4_VALID[0] <= 1'h1;
        end
        else
        begin
            RSR4[0]       <= RSR4[1];
            RSR4_VALID[0] <= RSR4_VALID[1];
        end
    end
end
///////////////////////////////////////////////////////
`endif


`ifdef ISSUE_SIX_WIDE
// execution pipe 5 ///////////////////////////////////
reg  [`SIZE_PHYSICAL_LOG-1:0] simpleTag5;
reg                           simpleGranted5;
reg  [`SIZE_PHYSICAL_LOG-1:0] complexTag5;
reg                           complexGranted5;
reg  [`SIZE_PHYSICAL_LOG-1:0] RSR5          [`FU1_LATENCY-1:0];
reg                           RSR5_VALID    [`FU1_LATENCY-1:0]; 

assign ignoreSimple_o[5]    = RSR5_VALID[1];

assign rsrTag_o[5].valid    = RSR5_VALID[0];
assign rsrTag_o[5].reg_id   = RSR5[0];

always_comb
begin
    simpleTag5  = grantedDest_i[5].reg_id;
    complexTag5 = grantedDest_i[5].reg_id;

    if (grantedDest_i[5].valid && ISsimple_i[5])
    begin
        simpleGranted5  = 1'h1;
        complexGranted5 = 1'h0;
    end

    else if (grantedDest_i[5].valid && !ISsimple_i[5])
    begin
        simpleGranted5  = 1'h0;
        complexGranted5 = 1'h1;
    end

    else
    begin
        simpleGranted5  = 1'h0;
        complexGranted5 = 1'h0;
    end
end

// manage the rsr shift register
// complex tags enter at the tail. 
// simple tags enter at the head.
always_ff @(posedge clk)
begin:UPDATE5
    int i;

    if (reset)
    begin
        for(i = 0; i < `FU1_LATENCY; i++)
        begin
            RSR5[i]         <= 0;
            RSR5_VALID[i]   <= 0;
        end
    end

    else
    begin
        // deposit complex tags at the tail
        RSR5[`FU1_LATENCY-1]             <= complexTag5;
        RSR5_VALID[`FU1_LATENCY-1]       <= complexGranted5;

        // perform the shift
        for (i = 1; i < `FU1_LATENCY-1; i++)
        begin
            RSR5[i]       <= RSR5[i+1];
            RSR5_VALID[i] <= RSR5_VALID[i+1];
        end

        // override the head position if a simple has been granted.
        // as explained above, we can safely ignore any potential 
        // for conflicts when overwriting the head.
        if (simpleGranted5)
        begin
            RSR5[0]       <= simpleTag5;
            RSR5_VALID[0] <= 1'h1;
        end
        else
        begin
            RSR5[0]       <= RSR5[1];
            RSR5_VALID[0] <= RSR5_VALID[1];
        end
    end
end
///////////////////////////////////////////////////////
`endif


`ifdef ISSUE_SEVEN_WIDE
// execution pipe 6 ///////////////////////////////////
reg  [`SIZE_PHYSICAL_LOG-1:0] simpleTag6;
reg                           simpleGranted6;
reg  [`SIZE_PHYSICAL_LOG-1:0] complexTag6;
reg                           complexGranted6;
reg  [`SIZE_PHYSICAL_LOG-1:0] RSR6          [`FU1_LATENCY-1:0];
reg                           RSR6_VALID    [`FU1_LATENCY-1:0]; 

assign ignoreSimple_o[6]    = RSR6_VALID[1];

assign rsrTag_o[6].valid    = RSR6_VALID[0];
assign rsrTag_o[6].reg_id   = RSR6[0];

always_comb
begin
    simpleTag6  = grantedDest_i[6].reg_id;
    complexTag6 = grantedDest_i[6].reg_id;

    if (grantedDest_i[6].valid && ISsimple_i[6])
    begin
        simpleGranted6  = 1'h1;
        complexGranted6 = 1'h0;
    end

    else if (grantedDest_i[6].valid && !ISsimple_i[6])
    begin
        simpleGranted6  = 1'h0;
        complexGranted6 = 1'h1;
    end

    else
    begin
        simpleGranted6  = 1'h0;
        complexGranted6 = 1'h0;
    end
end

// manage the rsr shift register
// complex tags enter at the tail. 
// simple tags enter at the head.
always_ff @(posedge clk)
begin:UPDATE6
    int i;

    if (reset)
    begin
        for(i = 0; i < `FU1_LATENCY; i++)
        begin
            RSR6[i]         <= 0;
            RSR6_VALID[i]   <= 0;
        end
    end

    else
    begin
        // deposit complex tags at the tail
        RSR6[`FU1_LATENCY-1]             <= complexTag6;
        RSR6_VALID[`FU1_LATENCY-1]       <= complexGranted6;

        // perform the shift
        for (i = 1; i < `FU1_LATENCY-1; i++)
        begin
            RSR6[i]       <= RSR6[i+1];
            RSR6_VALID[i] <= RSR6_VALID[i+1];
        end

        // override the head position if a simple has been granted.
        // as explained above, we can safely ignore any potential 
        // for conflicts when overwriting the head.
        if (simpleGranted6)
        begin
            RSR6[0]       <= simpleTag6;
            RSR6_VALID[0] <= 1'h1;
        end
        else
        begin
            RSR6[0]       <= RSR6[1];
            RSR6_VALID[0] <= RSR6_VALID[1];
        end
    end
end
///////////////////////////////////////////////////////
`endif

`ifdef ISSUE_EIGHT_WIDE
// execution pipe 7 ///////////////////////////////////
reg  [`SIZE_PHYSICAL_LOG-1:0] simpleTag7;
reg                           simpleGranted7;
reg  [`SIZE_PHYSICAL_LOG-1:0] complexTag7;
reg                           complexGranted7;
reg  [`SIZE_PHYSICAL_LOG-1:0] RSR7          [`FU1_LATENCY-1:0];
reg                           RSR7_VALID    [`FU1_LATENCY-1:0]; 

assign ignoreSimple_o[7]    = RSR7_VALID[1];

assign rsrTag_o[7].valid    = RSR7_VALID[0];
assign rsrTag_o[7].reg_id   = RSR7[0];

always_comb
begin
    simpleTag7  = grantedDest_i[7].reg_id;
    complexTag7 = grantedDest_i[7].reg_id;

    if (grantedDest_i[7].valid && ISsimple_i[7])
    begin
        simpleGranted7  = 1'h1;
        complexGranted7 = 1'h0;
    end

    else if (grantedDest_i[7].valid && !ISsimple_i[7])
    begin
        simpleGranted7  = 1'h0;
        complexGranted7 = 1'h1;
    end

    else
    begin
        simpleGranted7  = 1'h0;
        complexGranted7 = 1'h0;
    end
end

// manage the rsr shift register
// complex tags enter at the tail. 
// simple tags enter at the head.
always_ff @(posedge clk)
begin:UPDATE7
    int i;

    if (reset)
    begin
        for(i = 0; i < `FU1_LATENCY; i++)
        begin
            RSR7[i]         <= 0;
            RSR7_VALID[i]   <= 0;
        end
    end

    else
    begin
        // deposit complex tags at the tail
        RSR7[`FU1_LATENCY-1]             <= complexTag7;
        RSR7_VALID[`FU1_LATENCY-1]       <= complexGranted7;

        // perform the shift
        for (i = 1; i < `FU1_LATENCY-1; i++)
        begin
            RSR7[i]       <= RSR7[i+1];
            RSR7_VALID[i] <= RSR7_VALID[i+1];
        end

        // override the head position if a simple has been granted.
        // as explained above, we can safely ignore any potential 
        // for conflicts when overwriting the head.
        if (simpleGranted7)
        begin
            RSR7[0]       <= simpleTag7;
            RSR7_VALID[0] <= 1'h1;
        end
        else
        begin
            RSR7[0]       <= RSR7[1];
            RSR7_VALID[0] <= RSR7_VALID[1];
        end
    end
end
///////////////////////////////////////////////////////
`endif

endmodule
