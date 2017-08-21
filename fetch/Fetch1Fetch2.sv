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

module Fetch1Fetch2(

	input                            clk,
	input                            reset,
`ifdef DYNAMIC_CONFIG
  input [`FETCH_WIDTH-1:0]         laneActive_i,
	output reg [`FETCH_WIDTH-1:0]    valid_bundle_o,
`endif  

	input                            flush_i,
	input                            stall_i,

	input                            fs1Ready_i,
	input  [1:0]                     predCounter_i [0:`FETCH_WIDTH-1],
	input  [`SIZE_CNT_TBL_LOG-1:0]   predIndex_i   [0:`FETCH_WIDTH-1],
	input      fs2Pkt                fs2Packet_i   [0:`FETCH_WIDTH-1],

	output reg                       fs1Ready_o,
	output reg [1:0]                 predCounter_o [0:`FETCH_WIDTH-1],
	output reg [`SIZE_CNT_TBL_LOG-1:0]  predIndex_o   [0:`FETCH_WIDTH-1],
	output     fs2Pkt                fs2Packet_o   [0:`FETCH_WIDTH-1]
	);

  // LANE: Per Lane Logic
`ifdef DYNAMIC_CONFIG      
  genvar i;
  generate
    for(i = 0; i < `FETCH_WIDTH; i++)
    begin:PIPEREG

      PipeLineReg 
      #(.WIDTH(`FS2_PKT_SIZE+2),.CLKGATE(`PIPEREG_CLK_GATE)) 
      fs1fs2Reg 
      (
        .clk(clk),
        .reset(reset | flush_i),
        .stall_i(stall_i),
        .clkEn_i(laneActive_i[i]),
        .pwrEn_i(laneActive_i[i]),
        .data_i({fs2Packet_i[i],predCounter_i[i]}),
        .data_o({fs2Packet_o[i],predCounter_o[i]})
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
    		/* TODO: Test not clearing the packet on flush_i. Clearing fs1Ready_o should
    		 * be sufficient */
    		predCounter_o[i]         <= 0;
			  predIndex_o[i]           <= 0;
    		fs2Packet_o[i]           <= 0;
    	end
      else if (~stall_i)
    	begin
    		predCounter_o[i]       <= predCounter_i[i];
				predIndex_o[i]         <= predIndex_i[i];
    		fs2Packet_o[i]         <= fs2Packet_i[i];
    	end
    end
  end
`endif        

  always_ff @(posedge clk)
  begin
      	if (reset || flush_i)
      	begin
      		fs1Ready_o                 <= 0;
        end
        else if(~stall_i)
        begin
      			fs1Ready_o               <= fs1Ready_i;
        end
  end

`ifdef DYNAMIC_CONFIG
 always_comb
 begin
  int i;
  for (i = 0; i < `FETCH_WIDTH; i++)
  begin
    valid_bundle_o[i] = fs2Packet_i[i].valid & laneActive_i[i];
  end
 end
`endif

endmodule

