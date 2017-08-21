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
// to execute, complex instructions take FU_LATENCY, and loads have an
// indeterminate latency. tags for simple and control instructions will be
// broadcasted by the rsr 1 cycle after they are issued, tags for complex 
// instructions will be broadcasted FU_LATENCY cycles after issue. Since loads
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

module RSRLane #(parameter LANE_ID = 0, FU_LATENCY = 1)
  (
	input                           clk,
	input                           reset,
	
	input                           ISsimple_i,
	input  phys_reg                 grantedDest_i,

	output phys_reg                 rsrTag_o,
	output                          ignoreSimple_o
	);


//localparam FU_LATENCY = (LANE_ID < 2) ? 1 : `FU1_LATENCY;

generate
if(LANE_ID == 0)
begin:LOAD_STORE
assign ignoreSimple_o  = 1'h0;

reg  [`SIZE_PHYSICAL_LOG-1:0] RSR0          [1:0];
reg                           RSR0_VALID    [1:0];

assign rsrTag_o.valid    = RSR0_VALID[0];
assign rsrTag_o.reg_id   = RSR0[0];

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
      RSR0[1]                <= grantedDest_i.reg_id;
      RSR0_VALID[1]          <= grantedDest_i.valid;
      RSR0[0]                <= RSR0[1];
      RSR0_VALID[0]          <= RSR0_VALID[1];
    end
end

end
else if(FU_LATENCY == 1)
begin:SIMPLE_PIPES
  // execution pipe 0 & 1 ///////////////////////////////////
  reg  [`SIZE_PHYSICAL_LOG-1:0] RSR1          [0:0];
  reg                           RSR1_VALID    [0:0];
  
  assign ignoreSimple_o    = 1'h0;
  
  assign rsrTag_o.valid    = RSR1_VALID[0];
  assign rsrTag_o.reg_id   = RSR1[0];
  
  always_ff @(posedge clk)
  begin:UPDATE1
      RSR1[0]                <= grantedDest_i.reg_id;
      RSR1_VALID[0]          <= grantedDest_i.valid;
  end

end
else
begin: COMPLEX_PIPES

  // execution pipe  ///////////////////////////////////
  reg  [`SIZE_PHYSICAL_LOG-1:0] simpleTag;
  reg                           simpleGranted;
  reg  [`SIZE_PHYSICAL_LOG-1:0] complexTag;
  reg                           complexGranted;
  reg  [`SIZE_PHYSICAL_LOG-1:0] RSR          [FU_LATENCY-1:0];
  reg                           RSR_VALID    [FU_LATENCY-1:0]; 
  
  assign ignoreSimple_o    = RSR_VALID[1];
  
  assign rsrTag_o.valid    = RSR_VALID[0];
  assign rsrTag_o.reg_id   = RSR[0];
  
  always_comb
  begin
      simpleTag              = grantedDest_i.reg_id;
      complexTag             = grantedDest_i.reg_id;
  
      if (grantedDest_i.valid && ISsimple_i)
      begin
          simpleGranted      = 1'h1;
          complexGranted     = 1'h0;
      end
  
      else if (grantedDest_i.valid && !ISsimple_i)
      begin
          simpleGranted      = 1'h0;
          complexGranted     = 1'h1;
      end
  
      else
      begin
          simpleGranted      = 1'h0;
          complexGranted     = 1'h0;
      end
  end
  
  // manage the rsr shift register
  // complex tags enter at the tail. 
  // simple tags enter at the head.
  always_ff @(posedge clk)
  begin:UPDATE
      int i;
  
      if (reset)
      begin
          for(i = 0; i < FU_LATENCY; i++)
          begin
              RSR[i]        <= 0;
              RSR_VALID[i]  <= 0;
          end
      end
  
      else
      begin
          // deposit complex tags at the tail
          RSR[FU_LATENCY-1]             <= complexTag;
          RSR_VALID[FU_LATENCY-1]       <= complexGranted;
  
          // perform the shift
          for (i = 1; i < FU_LATENCY-1; i++)
          begin
              RSR[i]        <= RSR[i+1];
              RSR_VALID[i]  <= RSR_VALID[i+1];
          end
  
          // override the head position if a simple has been granted.
          // as explained above, we can safely ignore any potential 
          // for conflicts when overwriting the head.
          if (simpleGranted)
          begin
              RSR[0]        <= simpleTag;
              RSR_VALID[0]  <= 1'h1;
          end
          else
          begin
              RSR[0]        <= RSR[1];
              RSR_VALID[0]  <= RSR_VALID[1];
          end
      end
  end
  ///////////////////////////////////////////////////////

end
endgenerate


endmodule
