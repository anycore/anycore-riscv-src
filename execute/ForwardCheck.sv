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


module ForwardCheck (
	input  [`SIZE_PHYSICAL_LOG-1:0]      srcReg_i,
	input  [`SIZE_DATA-1:0]              srcData_i,

	input  bypassPkt                     bypassPacket_i [0:`ISSUE_WIDTH-1],

	output [`SIZE_DATA-1:0]              dataOut_o
	);

reg  [`SIZE_DATA-1:0]          dataOut;


assign dataOut_o = dataOut;

always_comb
begin:FORWARD_CHECK
	int i;
	reg  [`ISSUE_WIDTH-1:0]  match;

	for (i = 0; i < `ISSUE_WIDTH; i = i + 1)
	begin
		match[i] = bypassPacket_i[i].valid && (srcReg_i == bypassPacket_i[i].tag);
	end

	case (match) // synopsys full_case
		8'b00000000: dataOut = srcData_i;

		8'b00000001: 
		begin
			/* dataOut = {bypassPacket_i[0].byte3, bypassPacket_i[0].byte2, bypassPacket_i[0].byte1, bypassPacket_i[0].byte0}; */
			dataOut = bypassPacket_i[0].data;
		end

		8'b00000010: 
		begin
			/* dataOut = {bypassPacket_i[1].byte3, bypassPacket_i[1].byte2, bypassPacket_i[1].byte1, bypassPacket_i[1].byte0}; */
			dataOut = bypassPacket_i[1].data;
		end

		8'b00000100: 
		begin
			/* dataOut = {bypassPacket_i[2].byte3, bypassPacket_i[2].byte2, bypassPacket_i[2].byte1, bypassPacket_i[2].byte0}; */
			dataOut = bypassPacket_i[2].data;
		end

`ifdef ISSUE_FOUR_WIDE
		8'b00001000: 
		begin
			/* dataOut = {bypassPacket_i[3].byte3, bypassPacket_i[3].byte2, bypassPacket_i[3].byte1, bypassPacket_i[3].byte0}; */
			dataOut = bypassPacket_i[3].data;
		end
`endif

`ifdef ISSUE_FIVE_WIDE
		8'b00010000: 
		begin
			/* dataOut = {bypassPacket_i[4].byte3, bypassPacket_i[4].byte2, bypassPacket_i[4].byte1, bypassPacket_i[4].byte0}; */
			dataOut = bypassPacket_i[4].data;
		end
`endif

`ifdef ISSUE_SIX_WIDE
		8'b00100000: 
		begin
			/* dataOut = {bypassPacket_i[5].byte3, bypassPacket_i[5].byte2, bypassPacket_i[5].byte1, bypassPacket_i[5].byte0}; */
			dataOut = bypassPacket_i[5].data;
		end
`endif

`ifdef ISSUE_SEVEN_WIDE
		8'b01000000: 
		begin
			/* dataOut = {bypassPacket_i[6].byte3, bypassPacket_i[6].byte2, bypassPacket_i[6].byte1, bypassPacket_i[6].byte0}; */
			dataOut = bypassPacket_i[6].data;
		end
`endif

`ifdef ISSUE_EIGHT_WIDE
		8'b10000000: 
		begin
			/* dataOut = {bypassPacket_i[7].byte3, bypassPacket_i[7].byte2, bypassPacket_i[7].byte1, bypassPacket_i[7].byte0}; */
			dataOut = bypassPacket_i[7].data;
		end
`endif
	endcase
end

endmodule
