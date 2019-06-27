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


module Decode(

	input                             clk,
	input                             reset,

`ifdef DYNAMIC_CONFIG
  input [`FETCH_WIDTH-1:0]          fetchLaneActive_i,
`endif  

	input                             fs2Ready_i,

	input  decPkt                     decPacket_i [0:`FETCH_WIDTH-1],

  // Number of ibPacket is twice the number of decPacket because potentially,
  // each instruction can be a complex instruction and can be split into two
  // parts
	output renPkt                     ibPacket_o  [0:2*`FETCH_WIDTH-1],

	output                            decodeReady_o
	);


/********************************** I/O Declaration ************************************/


assign decodeReady_o       = fs2Ready_i;


/* Following instantiates RISV decode blocks for FETCH_WIDTH instructions. */

// LANE: Per lane logic
// TODO: Need isolation cells for valid bit
genvar g;
generate
for (g = 0; g < `FETCH_WIDTH; g = g + 1)
begin : decode_RISCV_gen

Decode_RISCV decode_RISCV (
  
`ifdef DYNAMIC_CONFIG
  .laneActive_i            (fetchLaneActive_i[g]),
`endif

	.decPacket_i             (decPacket_i[g]),

	.ibPacket0_o             (ibPacket_o[2*g]),
	.ibPacket1_o             (ibPacket_o[2*g+1])
	);

end
endgenerate

endmodule

