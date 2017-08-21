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


module Bypass_1D (
	input                                clk,
	input                                reset,
	
	input  bypassPkt                     bypassPacket_i [0:`ISSUE_WIDTH-1],
	
	input  [`SIZE_PHYSICAL_LOG-1:0]      phySrc_i,

	input  [`SIZE_DATA-1:0]              datastage0_i,

	output  [`SIZE_DATA-1:0]             data_o
	);


reg  [`ISSUE_WIDTH-1:0]                match;
reg  [`SIZE_DATA-1:0]                  data;


always_comb
begin
	int i;

	for (i = 0; i < `ISSUE_WIDTH; i++)
	begin
		match[i]     = ((phySrc_i == bypassPacket_i[i].tag) && bypassPacket_i[i].valid);
	end
end


always_comb
begin
	int i;

	data      = datastage0_i;

	/* Priority encoder */
	for (i = 0; i < `ISSUE_WIDTH; i++)
	begin
		if (match[i])
		begin
			data  = bypassPacket_i[i].data;
		end
	end
end


assign data_o = data;

endmodule
