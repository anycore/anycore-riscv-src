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

module DispatchedLoad (
	input                                 dispatchReady_i,
	input  lsqPkt                         lsqPacket_i   [0:`DISPATCH_WIDTH-1],

	input  [`SIZE_LSQ_LOG-1:0]            ldqHead_i,
	input  [`SIZE_LSQ_LOG-1:0]            ldqTail_i,
  input  [`SIZE_LSQ_LOG:0]              lsqSize_i,

	/* Count of new load instructions */
	output reg [`SIZE_LSQ_LOG-1:0]        newLdCount_o,

	/* LDQ IDs of the new load instructions */
	output reg [`SIZE_LSQ_LOG-1:0]        ldqID_o       [0:`DISPATCH_WIDTH-1],

	/* The LDQ IDs available to the new load instructions */
	output reg [`SIZE_LSQ_LOG-1:0]        newLdIndex_o  [0:`DISPATCH_WIDTH-1],

	/* Each non-load's index to the next-youngest load */
	output reg [`SIZE_LSQ_LOG-1:0]        nextLdIndex_o [0:`DISPATCH_WIDTH-1]
);


reg [`SIZE_LSQ_LOG:0]      newLdIndex  [0:7];
reg [`SIZE_LSQ_LOG-1:0]    nextLdIndex [0:7];


always_comb
begin
	int i;
	for (i = 0; i < `DISPATCH_WIDTH; i++)
	begin
		newLdIndex_o[i]    = newLdIndex[i];
		nextLdIndex_o[i]   = nextLdIndex[i];
	end
end

// TODO: Make this logic smaller
always_comb
begin:DISPATCHED_LD
	reg  [`DISPATCH_WIDTH-1:0]  loadVector;
	int i;

  //Default to avoid latch
  //RBRC: 07/12/2013
  loadVector = {`DISPATCH_WIDTH{1'b0}};

	for (i = 0; i < `DISPATCH_WIDTH; i++)
	begin
		newLdIndex[i]    = ldqTail_i + i;
    // Explicit wrap around
    if(newLdIndex[i] >= lsqSize_i)
      newLdIndex[i] = newLdIndex[i] - lsqSize_i;

		ldqID_o[i]       = 0;

		nextLdIndex[i]   = newLdIndex[0];
	end

	newLdCount_o      = 0;

	if (dispatchReady_i)
	begin
		/* Following combinational logic counts the number of LD instructions in the
		 * incoming set of instructions. */
		for (i = 0; i < `DISPATCH_WIDTH; i++)
		begin
			newLdCount_o = newLdCount_o + lsqPacket_i[i].isLoad;
			loadVector[i] = lsqPacket_i[i].isLoad;
		end

		case (loadVector)
	
		8'b00000001:
		begin
			ldqID_o[0]      = newLdIndex[0];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = newLdIndex[1];
			nextLdIndex[5]     = newLdIndex[1];
			nextLdIndex[6]     = newLdIndex[1];
			nextLdIndex[7]     = newLdIndex[1];
		end

`ifdef DISPATCH_TWO_WIDE
		8'b00000010:
		begin
			ldqID_o[1]      = newLdIndex[0];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = newLdIndex[1];
			nextLdIndex[5]     = newLdIndex[1];
			nextLdIndex[6]     = newLdIndex[1];
			nextLdIndex[7]     = newLdIndex[1];
		end

		8'b00000011:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[2];
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = newLdIndex[2];
			nextLdIndex[7]     = newLdIndex[2];
		end
`endif

`ifdef DISPATCH_THREE_WIDE
		8'b00000100:
		begin
			ldqID_o[2]      = newLdIndex[0];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = newLdIndex[1];
			nextLdIndex[5]     = newLdIndex[1];
			nextLdIndex[6]     = newLdIndex[1];
			nextLdIndex[7]     = newLdIndex[1];
		end

		8'b00000101:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = newLdIndex[2];
			nextLdIndex[7]     = newLdIndex[2];
		end

		8'b00000110:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = newLdIndex[2];
			nextLdIndex[7]     = newLdIndex[2];
		end

		8'b00000111:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[2]      = newLdIndex[2];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[3];
			nextLdIndex[4]     = newLdIndex[3];
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = newLdIndex[3];
		end
`endif

`ifdef DISPATCH_FOUR_WIDE
		8'b00001000:
		begin
			ldqID_o[3]      = newLdIndex[0];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = newLdIndex[0];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[1];
			nextLdIndex[5]     = newLdIndex[1];
			nextLdIndex[6]     = newLdIndex[1];
			nextLdIndex[7]     = newLdIndex[1];
		end

		8'b00001001:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = newLdIndex[2];
			nextLdIndex[7]     = newLdIndex[2];
		end

		8'b00001010:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = newLdIndex[2];
			nextLdIndex[7]     = newLdIndex[2];
		end

		8'b00001011:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[2];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[3];
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b00001100:
		begin
			ldqID_o[2]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = newLdIndex[2];
			nextLdIndex[7]     = newLdIndex[2];
		end

		8'b00001101:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[3];
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b00001110:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[3];
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b00001111:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[2]      = newLdIndex[2];
			ldqID_o[3]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[4];
			nextLdIndex[5]     = newLdIndex[4];
			nextLdIndex[6]     = newLdIndex[4];
			nextLdIndex[7]     = newLdIndex[4];
		end
`endif

`ifdef DISPATCH_FIVE_WIDE
		8'b00010000:
		begin
			ldqID_o[4]      = newLdIndex[0];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = newLdIndex[0];
			nextLdIndex[3]     = newLdIndex[0];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[1];
			nextLdIndex[6]     = newLdIndex[1];
			nextLdIndex[7]     = newLdIndex[1];
		end

		8'b00010001:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[4]      = newLdIndex[1];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = newLdIndex[2];
			nextLdIndex[7]     = newLdIndex[2];
		end

		8'b00010010:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[4]      = newLdIndex[1];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = newLdIndex[2];
			nextLdIndex[7]     = newLdIndex[2];
		end

		8'b00010011:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[2];
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b00010100:
		begin
			ldqID_o[2]      = newLdIndex[0];
			ldqID_o[4]      = newLdIndex[1];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = newLdIndex[2];
			nextLdIndex[7]     = newLdIndex[2];
		end

		8'b00010101:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b00010110:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b00010111:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[2]      = newLdIndex[2];
			ldqID_o[4]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[3];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[4];
			nextLdIndex[6]     = newLdIndex[4];
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b00011000:
		begin
			ldqID_o[3]      = newLdIndex[0];
			ldqID_o[4]      = newLdIndex[1];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = newLdIndex[0];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = newLdIndex[2];
			nextLdIndex[7]     = newLdIndex[2];
		end

		8'b00011001:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b00011010:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b00011011:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[4]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[2];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[4];
			nextLdIndex[6]     = newLdIndex[4];
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b00011100:
		begin
			ldqID_o[2]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b00011101:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[4]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[4];
			nextLdIndex[6]     = newLdIndex[4];
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b00011110:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[4]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[4];
			nextLdIndex[6]     = newLdIndex[4];
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b00011111:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[2]      = newLdIndex[2];
			ldqID_o[3]      = newLdIndex[3];
			ldqID_o[4]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[5];
			nextLdIndex[6]     = newLdIndex[5];
			nextLdIndex[7]     = newLdIndex[5];
		end
`endif

`ifdef DISPATCH_SIX_WIDE
		8'b00100000:
		begin
			ldqID_o[5]      = newLdIndex[0];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = newLdIndex[0];
			nextLdIndex[3]     = newLdIndex[0];
			nextLdIndex[4]     = newLdIndex[0];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[1];
			nextLdIndex[7]     = newLdIndex[1];
		end

		8'b00100001:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[5]      = newLdIndex[1];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = newLdIndex[1];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[2];
			nextLdIndex[7]     = newLdIndex[2];
		end

		8'b00100010:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[5]      = newLdIndex[1];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = newLdIndex[1];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[2];
			nextLdIndex[7]     = newLdIndex[2];
		end

		8'b00100011:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[2];
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b00100100:
		begin
			ldqID_o[2]      = newLdIndex[0];
			ldqID_o[5]      = newLdIndex[1];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = newLdIndex[1];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[2];
			nextLdIndex[7]     = newLdIndex[2];
		end

		8'b00100101:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b00100110:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b00100111:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[2]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[3];
			nextLdIndex[4]     = newLdIndex[3];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[4];
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b00101000:
		begin
			ldqID_o[3]      = newLdIndex[0];
			ldqID_o[5]      = newLdIndex[1];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = newLdIndex[0];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[1];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[2];
			nextLdIndex[7]     = newLdIndex[2];
		end

		8'b00101001:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b00101010:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b00101011:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[2];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[3];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[4];
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b00101100:
		begin
			ldqID_o[2]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b00101101:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[3];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[4];
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b00101110:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[3];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[4];
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b00101111:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[2]      = newLdIndex[2];
			ldqID_o[3]      = newLdIndex[3];
			ldqID_o[5]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[4];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[5];
			nextLdIndex[7]     = newLdIndex[5];
		end

		8'b00110000:
		begin
			ldqID_o[4]      = newLdIndex[0];
			ldqID_o[5]      = newLdIndex[1];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = newLdIndex[0];
			nextLdIndex[3]     = newLdIndex[0];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[2];
			nextLdIndex[7]     = newLdIndex[2];
		end

		8'b00110001:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[4]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b00110010:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[4]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b00110011:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[2];
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[4];
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b00110100:
		begin
			ldqID_o[2]      = newLdIndex[0];
			ldqID_o[4]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b00110101:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[4];
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b00110110:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[4];
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b00110111:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[2]      = newLdIndex[2];
			ldqID_o[4]      = newLdIndex[3];
			ldqID_o[5]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[3];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[5];
			nextLdIndex[7]     = newLdIndex[5];
		end

		8'b00111000:
		begin
			ldqID_o[3]      = newLdIndex[0];
			ldqID_o[4]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = newLdIndex[0];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b00111001:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[4];
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b00111010:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[4];
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b00111011:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[4]      = newLdIndex[3];
			ldqID_o[5]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[2];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[5];
			nextLdIndex[7]     = newLdIndex[5];
		end

		8'b00111100:
		begin
			ldqID_o[2]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[4];
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b00111101:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[4]      = newLdIndex[3];
			ldqID_o[5]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[5];
			nextLdIndex[7]     = newLdIndex[5];
		end

		8'b00111110:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[4]      = newLdIndex[3];
			ldqID_o[5]      = newLdIndex[4];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[5];
			nextLdIndex[7]     = newLdIndex[5];
		end

		8'b00111111:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[2]      = newLdIndex[2];
			ldqID_o[3]      = newLdIndex[3];
			ldqID_o[4]      = newLdIndex[4];
			ldqID_o[5]      = newLdIndex[5];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[6];
			nextLdIndex[7]     = newLdIndex[6];
		end
`endif

`ifdef DISPATCH_SEVEN_WIDE
		8'b01000000:
		begin
			ldqID_o[6]      = newLdIndex[0];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = newLdIndex[0];
			nextLdIndex[3]     = newLdIndex[0];
			nextLdIndex[4]     = newLdIndex[0];
			nextLdIndex[5]     = newLdIndex[0];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[1];
		end

		8'b01000001:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[6]      = newLdIndex[1];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = newLdIndex[1];
			nextLdIndex[5]     = newLdIndex[1];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[2];
		end

		8'b01000010:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[6]      = newLdIndex[1];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = newLdIndex[1];
			nextLdIndex[5]     = newLdIndex[1];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[2];
		end

		8'b01000011:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[6]      = newLdIndex[2];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[2];
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b01000100:
		begin
			ldqID_o[2]      = newLdIndex[0];
			ldqID_o[6]      = newLdIndex[1];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = newLdIndex[1];
			nextLdIndex[5]     = newLdIndex[1];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[2];
		end

		8'b01000101:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[6]      = newLdIndex[2];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b01000110:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[6]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b01000111:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[2]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[3];
			nextLdIndex[4]     = newLdIndex[3];
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b01001000:
		begin
			ldqID_o[3]      = newLdIndex[0];
			ldqID_o[6]      = newLdIndex[1];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = newLdIndex[0];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[1];
			nextLdIndex[5]     = newLdIndex[1];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[2];
		end

		8'b01001001:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[6]      = newLdIndex[2];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b01001010:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[6]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b01001011:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[2];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[3];
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b01001100:
		begin
			ldqID_o[2]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[6]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b01001101:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[3];
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b01001110:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[3];
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b01001111:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[2]      = newLdIndex[2];
			ldqID_o[3]      = newLdIndex[3];
			ldqID_o[6]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[4];
			nextLdIndex[5]     = newLdIndex[4];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[5];
		end

		8'b01010000:
		begin
			ldqID_o[4]      = newLdIndex[0];
			ldqID_o[6]      = newLdIndex[1];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = newLdIndex[0];
			nextLdIndex[3]     = newLdIndex[0];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[1];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[2];
		end

		8'b01010001:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[4]      = newLdIndex[1];
			ldqID_o[6]      = newLdIndex[2];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b01010010:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[4]      = newLdIndex[1];
			ldqID_o[6]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b01010011:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[2];
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b01010100:
		begin
			ldqID_o[2]      = newLdIndex[0];
			ldqID_o[4]      = newLdIndex[1];
			ldqID_o[6]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b01010101:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b01010110:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b01010111:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[2]      = newLdIndex[2];
			ldqID_o[4]      = newLdIndex[3];
			ldqID_o[6]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[3];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[4];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[5];
		end

		8'b01011000:
		begin
			ldqID_o[3]      = newLdIndex[0];
			ldqID_o[4]      = newLdIndex[1];
			ldqID_o[6]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = newLdIndex[0];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b01011001:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b01011010:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b01011011:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[4]      = newLdIndex[3];
			ldqID_o[6]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[2];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[4];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[5];
		end

		8'b01011100:
		begin
			ldqID_o[2]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b01011101:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[4]      = newLdIndex[3];
			ldqID_o[6]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[4];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[5];
		end

		8'b01011110:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[4]      = newLdIndex[3];
			ldqID_o[6]      = newLdIndex[4];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[4];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[5];
		end

		8'b01011111:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[2]      = newLdIndex[2];
			ldqID_o[3]      = newLdIndex[3];
			ldqID_o[4]      = newLdIndex[4];
			ldqID_o[6]      = newLdIndex[5];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[5];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[6];
		end

		8'b01100000:
		begin
			ldqID_o[5]      = newLdIndex[0];
			ldqID_o[6]      = newLdIndex[1];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = newLdIndex[0];
			nextLdIndex[3]     = newLdIndex[0];
			nextLdIndex[4]     = newLdIndex[0];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[2];
		end

		8'b01100001:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[5]      = newLdIndex[1];
			ldqID_o[6]      = newLdIndex[2];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = newLdIndex[1];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b01100010:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[5]      = newLdIndex[1];
			ldqID_o[6]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = newLdIndex[1];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b01100011:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[2];
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b01100100:
		begin
			ldqID_o[2]      = newLdIndex[0];
			ldqID_o[5]      = newLdIndex[1];
			ldqID_o[6]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = newLdIndex[1];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b01100101:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b01100110:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b01100111:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[2]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];
			ldqID_o[6]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[3];
			nextLdIndex[4]     = newLdIndex[3];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[5];
		end

		8'b01101000:
		begin
			ldqID_o[3]      = newLdIndex[0];
			ldqID_o[5]      = newLdIndex[1];
			ldqID_o[6]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = newLdIndex[0];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[1];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b01101001:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b01101010:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b01101011:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];
			ldqID_o[6]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[2];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[3];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[5];
		end

		8'b01101100:
		begin
			ldqID_o[2]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b01101101:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];
			ldqID_o[6]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[3];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[5];
		end

		8'b01101110:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];
			ldqID_o[6]      = newLdIndex[4];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[3];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[5];
		end

		8'b01101111:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[2]      = newLdIndex[2];
			ldqID_o[3]      = newLdIndex[3];
			ldqID_o[5]      = newLdIndex[4];
			ldqID_o[6]      = newLdIndex[5];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[4];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[6];
		end

		8'b01110000:
		begin
			ldqID_o[4]      = newLdIndex[0];
			ldqID_o[5]      = newLdIndex[1];
			ldqID_o[6]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = newLdIndex[0];
			nextLdIndex[3]     = newLdIndex[0];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[3];
		end

		8'b01110001:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[4]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b01110010:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[4]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b01110011:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];
			ldqID_o[6]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[2];
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[5];
		end

		8'b01110100:
		begin
			ldqID_o[2]      = newLdIndex[0];
			ldqID_o[4]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b01110101:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];
			ldqID_o[6]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[5];
		end

		8'b01110110:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];
			ldqID_o[6]      = newLdIndex[4];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[5];
		end

		8'b01110111:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[2]      = newLdIndex[2];
			ldqID_o[4]      = newLdIndex[3];
			ldqID_o[5]      = newLdIndex[4];
			ldqID_o[6]      = newLdIndex[5];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[3];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[6];
		end

		8'b01111000:
		begin
			ldqID_o[3]      = newLdIndex[0];
			ldqID_o[4]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = newLdIndex[0];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[4];
		end

		8'b01111001:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];
			ldqID_o[6]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[5];
		end

		8'b01111010:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];
			ldqID_o[6]      = newLdIndex[4];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[5];
		end

		8'b01111011:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[4]      = newLdIndex[3];
			ldqID_o[5]      = newLdIndex[4];
			ldqID_o[6]      = newLdIndex[5];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[2];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[6];
		end

		8'b01111100:
		begin
			ldqID_o[2]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];
			ldqID_o[6]      = newLdIndex[4];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[5];
		end

		8'b01111101:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[4]      = newLdIndex[3];
			ldqID_o[5]      = newLdIndex[4];
			ldqID_o[6]      = newLdIndex[5];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[6];
		end

		8'b01111110:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[4]      = newLdIndex[3];
			ldqID_o[5]      = newLdIndex[4];
			ldqID_o[6]      = newLdIndex[5];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[6];
		end

		8'b01111111:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[2]      = newLdIndex[2];
			ldqID_o[3]      = newLdIndex[3];
			ldqID_o[4]      = newLdIndex[4];
			ldqID_o[5]      = newLdIndex[5];
			ldqID_o[6]      = newLdIndex[6];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = newLdIndex[7];
		end
`endif

`ifdef DISPATCH_EIGHT_WIDE
		8'b10000000:
		begin
			ldqID_o[7]      = newLdIndex[0];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = newLdIndex[0];
			nextLdIndex[3]     = newLdIndex[0];
			nextLdIndex[4]     = newLdIndex[0];
			nextLdIndex[5]     = newLdIndex[0];
			nextLdIndex[6]     = newLdIndex[0];
			nextLdIndex[7]     = 0;
		end

		8'b10000001:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[7]      = newLdIndex[1];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = newLdIndex[1];
			nextLdIndex[5]     = newLdIndex[1];
			nextLdIndex[6]     = newLdIndex[1];
			nextLdIndex[7]     = 0;
		end

		8'b10000010:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[7]      = newLdIndex[1];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = newLdIndex[1];
			nextLdIndex[5]     = newLdIndex[1];
			nextLdIndex[6]     = newLdIndex[1];
			nextLdIndex[7]     = 0;
		end

		8'b10000011:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[7]      = newLdIndex[2];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[2];
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = newLdIndex[2];
			nextLdIndex[7]     = 0;
		end

		8'b10000100:
		begin
			ldqID_o[2]      = newLdIndex[0];
			ldqID_o[7]      = newLdIndex[1];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = newLdIndex[1];
			nextLdIndex[5]     = newLdIndex[1];
			nextLdIndex[6]     = newLdIndex[1];
			nextLdIndex[7]     = 0;
		end

		8'b10000101:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[7]      = newLdIndex[2];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = newLdIndex[2];
			nextLdIndex[7]     = 0;
		end

		8'b10000110:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[7]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = newLdIndex[2];
			nextLdIndex[7]     = 0;
		end

		8'b10000111:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[2]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[3];
			nextLdIndex[4]     = newLdIndex[3];
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = 0;
		end

		8'b10001000:
		begin
			ldqID_o[3]      = newLdIndex[0];
			ldqID_o[7]      = newLdIndex[1];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = newLdIndex[0];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[1];
			nextLdIndex[5]     = newLdIndex[1];
			nextLdIndex[6]     = newLdIndex[1];
			nextLdIndex[7]     = 0;
		end

		8'b10001001:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[7]      = newLdIndex[2];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = newLdIndex[2];
			nextLdIndex[7]     = 0;
		end

		8'b10001010:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[7]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = newLdIndex[2];
			nextLdIndex[7]     = 0;
		end

		8'b10001011:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[2];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[3];
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = 0;
		end

		8'b10001100:
		begin
			ldqID_o[2]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[7]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = newLdIndex[2];
			nextLdIndex[7]     = 0;
		end

		8'b10001101:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[3];
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = 0;
		end

		8'b10001110:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[3];
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = 0;
		end

		8'b10001111:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[2]      = newLdIndex[2];
			ldqID_o[3]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[4];
			nextLdIndex[5]     = newLdIndex[4];
			nextLdIndex[6]     = newLdIndex[4];
			nextLdIndex[7]     = 0;
		end

		8'b10010000:
		begin
			ldqID_o[4]      = newLdIndex[0];
			ldqID_o[7]      = newLdIndex[1];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = newLdIndex[0];
			nextLdIndex[3]     = newLdIndex[0];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[1];
			nextLdIndex[6]     = newLdIndex[1];
			nextLdIndex[7]     = 0;
		end

		8'b10010001:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[4]      = newLdIndex[1];
			ldqID_o[7]      = newLdIndex[2];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = newLdIndex[2];
			nextLdIndex[7]     = 0;
		end

		8'b10010010:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[4]      = newLdIndex[1];
			ldqID_o[7]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = newLdIndex[2];
			nextLdIndex[7]     = 0;
		end

		8'b10010011:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[2];
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = 0;
		end

		8'b10010100:
		begin
			ldqID_o[2]      = newLdIndex[0];
			ldqID_o[4]      = newLdIndex[1];
			ldqID_o[7]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = newLdIndex[2];
			nextLdIndex[7]     = 0;
		end

		8'b10010101:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = 0;
		end

		8'b10010110:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = 0;
		end

		8'b10010111:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[2]      = newLdIndex[2];
			ldqID_o[4]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[3];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[4];
			nextLdIndex[6]     = newLdIndex[4];
			nextLdIndex[7]     = 0;
		end

		8'b10011000:
		begin
			ldqID_o[3]      = newLdIndex[0];
			ldqID_o[4]      = newLdIndex[1];
			ldqID_o[7]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = newLdIndex[0];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = newLdIndex[2];
			nextLdIndex[7]     = 0;
		end

		8'b10011001:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = 0;
		end

		8'b10011010:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = 0;
		end

		8'b10011011:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[4]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[2];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[4];
			nextLdIndex[6]     = newLdIndex[4];
			nextLdIndex[7]     = 0;
		end

		8'b10011100:
		begin
			ldqID_o[2]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = 0;
		end

		8'b10011101:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[4]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[4];
			nextLdIndex[6]     = newLdIndex[4];
			nextLdIndex[7]     = 0;
		end

		8'b10011110:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[4]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[4];
			nextLdIndex[6]     = newLdIndex[4];
			nextLdIndex[7]     = 0;
		end

		8'b10011111:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[2]      = newLdIndex[2];
			ldqID_o[3]      = newLdIndex[3];
			ldqID_o[4]      = newLdIndex[4];
			ldqID_o[7]      = newLdIndex[5];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[5];
			nextLdIndex[6]     = newLdIndex[5];
			nextLdIndex[7]     = 0;
		end

		8'b10100000:
		begin
			ldqID_o[5]      = newLdIndex[0];
			ldqID_o[7]      = newLdIndex[1];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = newLdIndex[0];
			nextLdIndex[3]     = newLdIndex[0];
			nextLdIndex[4]     = newLdIndex[0];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[1];
			nextLdIndex[7]     = 0;
		end

		8'b10100001:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[5]      = newLdIndex[1];
			ldqID_o[7]      = newLdIndex[2];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = newLdIndex[1];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[2];
			nextLdIndex[7]     = 0;
		end

		8'b10100010:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[5]      = newLdIndex[1];
			ldqID_o[7]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = newLdIndex[1];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[2];
			nextLdIndex[7]     = 0;
		end

		8'b10100011:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[2];
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = 0;
		end

		8'b10100100:
		begin
			ldqID_o[2]      = newLdIndex[0];
			ldqID_o[5]      = newLdIndex[1];
			ldqID_o[7]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = newLdIndex[1];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[2];
			nextLdIndex[7]     = 0;
		end

		8'b10100101:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = 0;
		end

		8'b10100110:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = 0;
		end

		8'b10100111:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[2]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[3];
			nextLdIndex[4]     = newLdIndex[3];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[4];
			nextLdIndex[7]     = 0;
		end

		8'b10101000:
		begin
			ldqID_o[3]      = newLdIndex[0];
			ldqID_o[5]      = newLdIndex[1];
			ldqID_o[7]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = newLdIndex[0];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[1];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[2];
			nextLdIndex[7]     = 0;
		end

		8'b10101001:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = 0;
		end

		8'b10101010:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = 0;
		end

		8'b10101011:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[2];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[3];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[4];
			nextLdIndex[7]     = 0;
		end

		8'b10101100:
		begin
			ldqID_o[2]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = 0;
		end

		8'b10101101:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[3];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[4];
			nextLdIndex[7]     = 0;
		end

		8'b10101110:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[3];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[4];
			nextLdIndex[7]     = 0;
		end

		8'b10101111:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[2]      = newLdIndex[2];
			ldqID_o[3]      = newLdIndex[3];
			ldqID_o[5]      = newLdIndex[4];
			ldqID_o[7]      = newLdIndex[5];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[4];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[5];
			nextLdIndex[7]     = 0;
		end

		8'b10110000:
		begin
			ldqID_o[4]      = newLdIndex[0];
			ldqID_o[5]      = newLdIndex[1];
			ldqID_o[7]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = newLdIndex[0];
			nextLdIndex[3]     = newLdIndex[0];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[2];
			nextLdIndex[7]     = 0;
		end

		8'b10110001:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[4]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = 0;
		end

		8'b10110010:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[4]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = 0;
		end

		8'b10110011:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[2];
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[4];
			nextLdIndex[7]     = 0;
		end

		8'b10110100:
		begin
			ldqID_o[2]      = newLdIndex[0];
			ldqID_o[4]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = 0;
		end

		8'b10110101:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[4];
			nextLdIndex[7]     = 0;
		end

		8'b10110110:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[4];
			nextLdIndex[7]     = 0;
		end

		8'b10110111:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[2]      = newLdIndex[2];
			ldqID_o[4]      = newLdIndex[3];
			ldqID_o[5]      = newLdIndex[4];
			ldqID_o[7]      = newLdIndex[5];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[3];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[5];
			nextLdIndex[7]     = 0;
		end

		8'b10111000:
		begin
			ldqID_o[3]      = newLdIndex[0];
			ldqID_o[4]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = newLdIndex[0];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[3];
			nextLdIndex[7]     = 0;
		end

		8'b10111001:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[4];
			nextLdIndex[7]     = 0;
		end

		8'b10111010:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[4];
			nextLdIndex[7]     = 0;
		end

		8'b10111011:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[4]      = newLdIndex[3];
			ldqID_o[5]      = newLdIndex[4];
			ldqID_o[7]      = newLdIndex[5];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[2];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[5];
			nextLdIndex[7]     = 0;
		end

		8'b10111100:
		begin
			ldqID_o[2]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[4];
			nextLdIndex[7]     = 0;
		end

		8'b10111101:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[4]      = newLdIndex[3];
			ldqID_o[5]      = newLdIndex[4];
			ldqID_o[7]      = newLdIndex[5];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[5];
			nextLdIndex[7]     = 0;
		end

		8'b10111110:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[4]      = newLdIndex[3];
			ldqID_o[5]      = newLdIndex[4];
			ldqID_o[7]      = newLdIndex[5];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[5];
			nextLdIndex[7]     = 0;
		end

		8'b10111111:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[2]      = newLdIndex[2];
			ldqID_o[3]      = newLdIndex[3];
			ldqID_o[4]      = newLdIndex[4];
			ldqID_o[5]      = newLdIndex[5];
			ldqID_o[7]      = newLdIndex[6];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = newLdIndex[6];
			nextLdIndex[7]     = 0;
		end

		8'b11000000:
		begin
			ldqID_o[6]      = newLdIndex[0];
			ldqID_o[7]      = newLdIndex[1];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = newLdIndex[0];
			nextLdIndex[3]     = newLdIndex[0];
			nextLdIndex[4]     = newLdIndex[0];
			nextLdIndex[5]     = newLdIndex[0];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11000001:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[6]      = newLdIndex[1];
			ldqID_o[7]      = newLdIndex[2];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = newLdIndex[1];
			nextLdIndex[5]     = newLdIndex[1];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11000010:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[6]      = newLdIndex[1];
			ldqID_o[7]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = newLdIndex[1];
			nextLdIndex[5]     = newLdIndex[1];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11000011:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[6]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[2];
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11000100:
		begin
			ldqID_o[2]      = newLdIndex[0];
			ldqID_o[6]      = newLdIndex[1];
			ldqID_o[7]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = newLdIndex[1];
			nextLdIndex[5]     = newLdIndex[1];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11000101:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[6]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11000110:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[6]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11000111:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[2]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[3];
			nextLdIndex[4]     = newLdIndex[3];
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11001000:
		begin
			ldqID_o[3]      = newLdIndex[0];
			ldqID_o[6]      = newLdIndex[1];
			ldqID_o[7]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = newLdIndex[0];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[1];
			nextLdIndex[5]     = newLdIndex[1];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11001001:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[6]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11001010:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[6]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11001011:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[2];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[3];
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11001100:
		begin
			ldqID_o[2]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[6]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11001101:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[3];
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11001110:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[3];
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11001111:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[2]      = newLdIndex[2];
			ldqID_o[3]      = newLdIndex[3];
			ldqID_o[6]      = newLdIndex[4];
			ldqID_o[7]      = newLdIndex[5];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[4];
			nextLdIndex[5]     = newLdIndex[4];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11010000:
		begin
			ldqID_o[4]      = newLdIndex[0];
			ldqID_o[6]      = newLdIndex[1];
			ldqID_o[7]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = newLdIndex[0];
			nextLdIndex[3]     = newLdIndex[0];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[1];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11010001:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[4]      = newLdIndex[1];
			ldqID_o[6]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11010010:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[4]      = newLdIndex[1];
			ldqID_o[6]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11010011:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[2];
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11010100:
		begin
			ldqID_o[2]      = newLdIndex[0];
			ldqID_o[4]      = newLdIndex[1];
			ldqID_o[6]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11010101:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11010110:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11010111:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[2]      = newLdIndex[2];
			ldqID_o[4]      = newLdIndex[3];
			ldqID_o[6]      = newLdIndex[4];
			ldqID_o[7]      = newLdIndex[5];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[3];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[4];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11011000:
		begin
			ldqID_o[3]      = newLdIndex[0];
			ldqID_o[4]      = newLdIndex[1];
			ldqID_o[6]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = newLdIndex[0];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[2];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11011001:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11011010:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11011011:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[4]      = newLdIndex[3];
			ldqID_o[6]      = newLdIndex[4];
			ldqID_o[7]      = newLdIndex[5];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[2];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[4];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11011100:
		begin
			ldqID_o[2]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[3];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11011101:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[4]      = newLdIndex[3];
			ldqID_o[6]      = newLdIndex[4];
			ldqID_o[7]      = newLdIndex[5];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[4];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11011110:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[4]      = newLdIndex[3];
			ldqID_o[6]      = newLdIndex[4];
			ldqID_o[7]      = newLdIndex[5];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[4];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11011111:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[2]      = newLdIndex[2];
			ldqID_o[3]      = newLdIndex[3];
			ldqID_o[4]      = newLdIndex[4];
			ldqID_o[6]      = newLdIndex[5];
			ldqID_o[7]      = newLdIndex[6];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = newLdIndex[5];
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11100000:
		begin
			ldqID_o[5]      = newLdIndex[0];
			ldqID_o[6]      = newLdIndex[1];
			ldqID_o[7]      = newLdIndex[2];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = newLdIndex[0];
			nextLdIndex[3]     = newLdIndex[0];
			nextLdIndex[4]     = newLdIndex[0];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11100001:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[5]      = newLdIndex[1];
			ldqID_o[6]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = newLdIndex[1];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11100010:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[5]      = newLdIndex[1];
			ldqID_o[6]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = newLdIndex[1];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11100011:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[2];
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11100100:
		begin
			ldqID_o[2]      = newLdIndex[0];
			ldqID_o[5]      = newLdIndex[1];
			ldqID_o[6]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = newLdIndex[1];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11100101:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11100110:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11100111:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[2]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];
			ldqID_o[6]      = newLdIndex[4];
			ldqID_o[7]      = newLdIndex[5];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[3];
			nextLdIndex[4]     = newLdIndex[3];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11101000:
		begin
			ldqID_o[3]      = newLdIndex[0];
			ldqID_o[5]      = newLdIndex[1];
			ldqID_o[6]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = newLdIndex[0];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[1];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11101001:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11101010:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11101011:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];
			ldqID_o[6]      = newLdIndex[4];
			ldqID_o[7]      = newLdIndex[5];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[2];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[3];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11101100:
		begin
			ldqID_o[2]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[2];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11101101:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];
			ldqID_o[6]      = newLdIndex[4];
			ldqID_o[7]      = newLdIndex[5];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[3];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11101110:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];
			ldqID_o[6]      = newLdIndex[4];
			ldqID_o[7]      = newLdIndex[5];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[3];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11101111:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[2]      = newLdIndex[2];
			ldqID_o[3]      = newLdIndex[3];
			ldqID_o[5]      = newLdIndex[4];
			ldqID_o[6]      = newLdIndex[5];
			ldqID_o[7]      = newLdIndex[6];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = newLdIndex[4];
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11110000:
		begin
			ldqID_o[4]      = newLdIndex[0];
			ldqID_o[5]      = newLdIndex[1];
			ldqID_o[6]      = newLdIndex[2];
			ldqID_o[7]      = newLdIndex[3];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = newLdIndex[0];
			nextLdIndex[3]     = newLdIndex[0];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11110001:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[4]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11110010:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[4]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11110011:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];
			ldqID_o[6]      = newLdIndex[4];
			ldqID_o[7]      = newLdIndex[5];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[2];
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11110100:
		begin
			ldqID_o[2]      = newLdIndex[0];
			ldqID_o[4]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[1];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11110101:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];
			ldqID_o[6]      = newLdIndex[4];
			ldqID_o[7]      = newLdIndex[5];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11110110:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];
			ldqID_o[6]      = newLdIndex[4];
			ldqID_o[7]      = newLdIndex[5];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[2];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11110111:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[2]      = newLdIndex[2];
			ldqID_o[4]      = newLdIndex[3];
			ldqID_o[5]      = newLdIndex[4];
			ldqID_o[6]      = newLdIndex[5];
			ldqID_o[7]      = newLdIndex[6];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = newLdIndex[3];
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11111000:
		begin
			ldqID_o[3]      = newLdIndex[0];
			ldqID_o[4]      = newLdIndex[1];
			ldqID_o[5]      = newLdIndex[2];
			ldqID_o[6]      = newLdIndex[3];
			ldqID_o[7]      = newLdIndex[4];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = newLdIndex[0];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11111001:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];
			ldqID_o[6]      = newLdIndex[4];
			ldqID_o[7]      = newLdIndex[5];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11111010:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];
			ldqID_o[6]      = newLdIndex[4];
			ldqID_o[7]      = newLdIndex[5];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[1];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11111011:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[4]      = newLdIndex[3];
			ldqID_o[5]      = newLdIndex[4];
			ldqID_o[6]      = newLdIndex[5];
			ldqID_o[7]      = newLdIndex[6];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = newLdIndex[2];
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11111100:
		begin
			ldqID_o[2]      = newLdIndex[0];
			ldqID_o[3]      = newLdIndex[1];
			ldqID_o[4]      = newLdIndex[2];
			ldqID_o[5]      = newLdIndex[3];
			ldqID_o[6]      = newLdIndex[4];
			ldqID_o[7]      = newLdIndex[5];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11111101:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[4]      = newLdIndex[3];
			ldqID_o[5]      = newLdIndex[4];
			ldqID_o[6]      = newLdIndex[5];
			ldqID_o[7]      = newLdIndex[6];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = newLdIndex[1];
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11111110:
		begin
			ldqID_o[1]      = newLdIndex[0];
			ldqID_o[2]      = newLdIndex[1];
			ldqID_o[3]      = newLdIndex[2];
			ldqID_o[4]      = newLdIndex[3];
			ldqID_o[5]      = newLdIndex[4];
			ldqID_o[6]      = newLdIndex[5];
			ldqID_o[7]      = newLdIndex[6];

			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end

		8'b11111111:
		begin
			ldqID_o[0]      = newLdIndex[0];
			ldqID_o[1]      = newLdIndex[1];
			ldqID_o[2]      = newLdIndex[2];
			ldqID_o[3]      = newLdIndex[3];
			ldqID_o[4]      = newLdIndex[4];
			ldqID_o[5]      = newLdIndex[5];
			ldqID_o[6]      = newLdIndex[6];
			ldqID_o[7]      = newLdIndex[7];

			nextLdIndex[0]     = 0;
			nextLdIndex[1]     = 0;
			nextLdIndex[2]     = 0;
			nextLdIndex[3]     = 0;
			nextLdIndex[4]     = 0;
			nextLdIndex[5]     = 0;
			nextLdIndex[6]     = 0;
			nextLdIndex[7]     = 0;
		end
`endif
    default:
    begin
			nextLdIndex[0]     = newLdIndex[0];
			nextLdIndex[1]     = newLdIndex[0];
			nextLdIndex[2]     = newLdIndex[0];
			nextLdIndex[3]     = newLdIndex[0];
			nextLdIndex[4]     = newLdIndex[0];
			nextLdIndex[5]     = newLdIndex[0];
			nextLdIndex[6]     = newLdIndex[0];
			nextLdIndex[7]     = newLdIndex[0];
    end
		endcase 
	end
end

endmodule
