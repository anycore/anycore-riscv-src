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


module RegReadExecute (
	input                                  clk,
	input                                  reset,

	input                                  flush_i,

	input  fuPkt                           exePacket_i,
	output fuPkt                           exePacket_o
	);


/* Pipeline registers between RegRead and Execute stage. */
always_ff @(posedge clk)
begin
	if (reset | flush_i)
	begin
		exePacket_o       <= {`FU_PKT_SIZE{1'b0}};
	end

	else
	begin
    //TODO: Fix this
		if (exePacket_i.valid)
		begin
			exePacket_o     <= exePacket_i;
		end

		exePacket_o.valid <= exePacket_i.valid;
	end
end

endmodule
