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


module Writeback_M (
	
	// these inputs come from the execution pipe with the branch unit
	input                                clk,
	input                                reset,

	input                                recoverFlag_i,

	/* these are the inputs and outputs for one particular function unit*/
	input  wbPkt                         wbPacket_i,
	input  ldVioPkt                      ldVioPacket_i,

	output ctrlPkt                       ctrlPacket_o,

	output bypassPkt                     bypassPacket_o,

	output ldVioPkt                      ldVioPacket_o
	);


reg                                                invalidateLsuPacket;
reg                                                invalidatelsuPacket;

wbPkt                                              wbPacket;
ldVioPkt                                           ldVioPacket;


assign ldVioPacket_o                 = ldVioPacket;

/* assign the parsed values to the output bypasses */
assign bypassPacket_o.tag            = wbPacket.phyDest;
assign bypassPacket_o.data           = wbPacket.destData;
/* assign bypassPacket_o.byte0          = wbPacket.destData[7:0]; */  
/* assign bypassPacket_o.byte1          = wbPacket.destData[15:8]; */ 
/* assign bypassPacket_o.byte2          = wbPacket.destData[23:16]; */
/* assign bypassPacket_o.byte3          = wbPacket.destData[31:24]; */
assign bypassPacket_o.valid          = wbPacket.valid & wbPacket.flags[4];


always_comb 
begin
	ctrlPacket_o.seqNo                 = wbPacket.seqNo;
	ctrlPacket_o.valid                 = wbPacket.valid;
	ctrlPacket_o.alID                  = wbPacket.alID;
	ctrlPacket_o.flags                 = wbPacket.flags;
	ctrlPacket_o.nextPC                = 0;
  ctrlPacket_o.actualDir             = 0;
end


always_ff @(posedge clk)
begin
	if (reset | recoverFlag_i)
	begin
		wbPacket          <= {`WB_PKT_SIZE{1'b0}};
		ldVioPacket       <= {`LD_VIO_PKT_SIZE{1'b0}};
	end

	else
	begin
		wbPacket          <= wbPacket_i;

		ldVioPacket       <= ldVioPacket_i;

`ifdef VERIFY
		if(~wbPacket_i.valid)
		begin
			wbPacket        <= 0;
		end
`endif

	end
end

endmodule

