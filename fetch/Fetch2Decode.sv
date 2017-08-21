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

module Fetch2Decode(
	input                                clk,
	input                                reset,

`ifdef DYNAMIC_CONFIG
  input [`FETCH_WIDTH-1:0]             laneActive_i,
`endif

	input                                flush_i,
	input                                stall_i,

	input  decPkt                        decPacket_i [0:`FETCH_WIDTH-1],
	output decPkt                        decPacket_o [0:`FETCH_WIDTH-1],

	input      [`SIZE_PC-1:0]            updatePC_i,
	input      [`SIZE_PC-1:0]            updateNPC_i,
	input      [`BRANCH_TYPE_LOG-1:0]        updateCtrlType_i,
	input                                updateDir_i,
	input      [1:0]                     updateCounter_i,
	input      [`SIZE_CNT_TBL_LOG-1:0]   updateIndex_i,
	input                                updateEn_i,
	input                                fs2Ready_i,

`ifdef DYNAMIC_CONFIG
	output reg [`FETCH_WIDTH-1:0]        valid_bundle_o,
`endif
	output reg [`SIZE_PC-1:0]            updatePC_o,
	output reg [`SIZE_PC-1:0]            updateNPC_o,
	output reg [`BRANCH_TYPE_LOG-1:0]        updateCtrlType_o,
	output reg                           updateDir_o,
	output reg [1:0]                     updateCounter_o,
	output reg [`SIZE_CNT_TBL_LOG-1:0]   updateIndex_o,
	output reg                           updateEn_o,
	output reg                           fs2Ready_o
	);

always_ff @(posedge clk) 
begin
	if (reset) 
	begin
		updatePC_o          <= 0;
		updateNPC_o         <= 0;
		updateCtrlType_o    <= 0;
		updateDir_o         <= 0;
		updateCounter_o     <= 0;
		updateIndex_o       <= 0;
		updateEn_o          <= 0;
	end

	else 
	begin
		updatePC_o          <= updatePC_i;
		updateNPC_o         <= updateNPC_i;
		updateCtrlType_o    <= updateCtrlType_i;
		updateDir_o         <= updateDir_i;
		updateCounter_o     <= updateCounter_i;
		updateIndex_o       <= updateIndex_i;  
		updateEn_o          <= updateEn_i;
	end
end

  // LANE: Per Lane Logic
`ifdef DYNAMIC_CONFIG      
  genvar i;
  generate
    for(i = 0; i < `FETCH_WIDTH; i++)
    begin:PIPEREG

      PipeLineReg 
      #(.WIDTH(`DEC_PKT_SIZE),.CLKGATE(`PIPEREG_CLK_GATE)) 
      fs2DecReg 
      (
        .clk(clk),
        .reset(reset | flush_i),
        .stall_i(stall_i),
        .clkEn_i(laneActive_i[i]),
        .pwrEn_i(laneActive_i[i]),
        .data_i(decPacket_i[i]),
        .data_o(decPacket_o[i])
      );
    
    // TODO: Emulate isolation cell for valid bit

    end
  endgenerate
`else        
  always_ff @(posedge clk) 
  begin
  	int i;
    for (i = 0; i < `FETCH_WIDTH; i++)
    begin
  	  if (reset || flush_i) 
  	  begin
  	  	decPacket_o[i]        <= 0;
  	  end
  	  else if (~stall_i) 
  	  begin
  	  	decPacket_o[i]      <= decPacket_i[i];
  	  end
    end
  end
`endif  

always_ff @(posedge clk)
begin
  if (reset || flush_i)
  begin
    fs2Ready_o          <= 0;
  end
  else if(~stall_i)
  begin
  	fs2Ready_o          <= fs2Ready_i;
  end

end

`ifdef DYNAMIC_CONFIG
 always_comb 
 begin
  int i;
  for (i = 0; i < `FETCH_WIDTH; i++)
  begin
    valid_bundle_o[i] = laneActive_i[i] ? decPacket_i[i].valid : 1'b0;
  end
 end
`endif

endmodule

