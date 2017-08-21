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


module RenameDispatch(
	input                                 clk,
	input                                 reset,

`ifdef DYNAMIC_CONFIG
  input  [`DISPATCH_WIDTH-1:0]          laneActive_i,
`endif

`ifdef DYNAMIC_CONFIG
	output reg [`DISPATCH_WIDTH-1:0]      valid_bundle_o,
`endif
	input                                 flush_i,
	input                                 stall_i,

	input                                 renameReady_i,

	input  disPkt                         disPacket_i [0:`DISPATCH_WIDTH-1],
	output disPkt                         disPacket_o [0:`DISPATCH_WIDTH-1],

	output reg                            renameReady_o
	);

  // LANE: Per Lane Logic
`ifdef DYNAMIC_CONFIG      

	disPkt                         disPacket_t [0:`DISPATCH_WIDTH-1];

  genvar i;
  generate
    for(i = 0; i < `DISPATCH_WIDTH; i++)
    begin:PIPEREG

      PipeLineReg 
      #(.WIDTH(`DIS_PKT_SIZE),.CLKGATE(`PIPEREG_CLK_GATE)) renDisReg 
      (
        .clk(clk),
        .reset(reset | flush_i),
        .stall_i(stall_i),
        .clkEn_i(laneActive_i[i]),
        .pwrEn_i(laneActive_i[i]),
        .data_i(disPacket_i[i]),
        .data_o(disPacket_t[i])
      );
    
      //Emulates isolation cell for valid and destValid bit
      always_comb
      begin

        disPacket_o[i] = disPacket_t[i];

        if(~laneActive_i[i] | flush_i)
        begin
          disPacket_o[i].immedValid    = 1'b0;
          disPacket_o[i].phySrc1Valid  = 1'b0;
          disPacket_o[i].phySrc2Valid  = 1'b0;
          disPacket_o[i].phyDestValid  = 1'b0;
          disPacket_o[i].isLoad        = 1'b0;
          disPacket_o[i].isStore       = 1'b0;
          disPacket_o[i].isCSR         = 1'b0;
          disPacket_o[i].isScall       = 1'b0;
          disPacket_o[i].isSbreak      = 1'b0;
          disPacket_o[i].isSret        = 1'b0;
          disPacket_o[i].SkipIQ        = 1'b0;
          disPacket_o[i].predDir       = 1'b0;
        end
      end

    end
  endgenerate
`else        
  int i;
  always_ff @(posedge clk)
  begin
    for(i = 0; i < `DISPATCH_WIDTH; i++)
    begin
    	if (reset || flush_i)
    	begin
    	  disPacket_o[i] <= 0;
    	end
    	else if (~stall_i)
    	begin
    		disPacket_o[i] <= disPacket_i[i];
    	end
    end
  end
`endif

  always_ff @(posedge clk)
  begin
  
  	if (reset || flush_i)
  	begin
  		renameReady_o    <= 0;
  	end
  
  	else if (~stall_i)
  	begin
  		renameReady_o    <= renameReady_i;
  	end
  end

`ifdef DYNAMIC_CONFIG
 always_comb 
 begin
  int i;
  for (i = 0; i < `DISPATCH_WIDTH; i++)
  begin
    valid_bundle_o[i] = (~stall_i) & renameReady_i & laneActive_i[i];
  end
 end
`endif

endmodule
