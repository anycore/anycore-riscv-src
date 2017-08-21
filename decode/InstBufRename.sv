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


module InstBufRename(
	input                                 clk,
	input                                 reset,

`ifdef DYNAMIC_CONFIG
  input [`DISPATCH_WIDTH-1:0]           laneActive_i,
	output reg [`DISPATCH_WIDTH-1:0]      valid_bundle_o,
`endif  

	// Flush the piepeline if there is Exception/Mis-prediction
	input                                 flush_i,

	input                                 stall_i,

	input                                 instBufferReady_i,

	input  renPkt                         renPacket_i [0:`DISPATCH_WIDTH-1],

	output renPkt                         renPacket_o [0:`DISPATCH_WIDTH-1],

	// For the Rename stage
	output reg                            instBufferReady_o
	);

`ifdef DYNAMIC_CONFIG      
	renPkt                         renPacket_t [0:`DISPATCH_WIDTH-1];

  genvar i;
  generate
    for(i = 0; i < `DISPATCH_WIDTH; i++)
    begin:PIPEREG

      PipeLineReg 
      #(.WIDTH(`REN_PKT_SIZE),.CLKGATE(`PIPEREG_CLK_GATE)) 
      instBufRenReg 
      (
        .clk(clk),
        .reset(reset | flush_i),
        .stall_i(stall_i),
        .clkEn_i(laneActive_i[i]),
        .pwrEn_i(laneActive_i[i]),
        .data_i(renPacket_i[i]),
        .data_o(renPacket_t[i])
      );
    
      //Emulates isolation cell for valid and destValid bit

      always_comb
      begin

        renPacket_o[i] = renPacket_t[i];

        if(~laneActive_i[i] | flush_i)
        begin
          renPacket_o[i].valid         = 1'b0;
          renPacket_o[i].immedValid    = 1'b0;
          renPacket_o[i].logSrc1Valid  = 1'b0;
          renPacket_o[i].logSrc2Valid  = 1'b0;
          renPacket_o[i].logDestValid  = 1'b0;
          renPacket_o[i].isLoad        = 1'b0;
          renPacket_o[i].isStore       = 1'b0;
          renPacket_o[i].isCSR         = 1'b0;
          renPacket_o[i].isScall       = 1'b0;
          renPacket_o[i].isSbreak      = 1'b0;
          renPacket_o[i].isSret        = 1'b0;
          renPacket_o[i].SkipIQ        = 1'b0;
          renPacket_o[i].predDir       = 1'b0;
        end
      end


    end
  endgenerate
`else        
  int i;
  always_ff @ (posedge clk)
  begin
    for(i = 0; i < `DISPATCH_WIDTH; i++)
    begin
    	if (reset || flush_i) 
    	begin
    	  renPacket_o[i]     <= 0;
    	end
    
    	else if(~stall_i) 
    	begin
    		renPacket_o[i]     <= renPacket_i[i];
    	end
    end
  end
`endif

  always_ff @ (posedge clk)
  begin
  	if (reset || flush_i) 
    begin
  		instBufferReady_o    <= 0;
    end
  	else if (~stall_i) 
    begin
  		instBufferReady_o    <= instBufferReady_i;
  	end
  end

`ifdef DYNAMIC_CONFIG
 always_comb 
 begin
  int i;
  for (i = 0; i < `DISPATCH_WIDTH; i++)
  begin
    valid_bundle_o[i] = instBufferReady_i & renPacket_i[i].valid & laneActive_i[i];
  end
 end
`endif

endmodule
