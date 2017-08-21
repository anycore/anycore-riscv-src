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


module AgenLsu (
	input                                 clk,
	input                                 reset,
	input                                 flush_i,

	input  memPkt                         memPacket_i,

	output memPkt                         memPacket_o
	);


always_ff @(posedge clk)
begin
	if (reset | flush_i)
	begin
		memPacket_o      <= 0;
	end

	else
	begin
		memPacket_o.valid <= memPacket_i.valid;

		if (memPacket_i.valid)
		begin
			memPacket_o    <= memPacket_i;
		end

`ifdef SIM
		else
		begin
			memPacket_o    <= 0;
		end
`endif

	end
end


endmodule
