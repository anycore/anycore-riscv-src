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

module SelectFromBlock #(
	parameter ENTRY_PER_BLOCK = 32
	)(

	input  [ENTRY_PER_BLOCK-1:0]   blockVector_i,
	output                         freeingScalar_o,
	output [`SIZE_ISSUEQ_LOG-1:0]  freeingCandidate_o
);

reg                         freeingScalar;
reg [`SIZE_ISSUEQ_LOG-1:0]  freeingCandidate;

assign freeingCandidate_o = freeingCandidate;
assign freeingScalar_o    = freeingScalar;

always_comb
begin:FIND_FREEING_CANDIDATE_0
	casex (blockVector_i)

		32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1:
		begin
			freeingCandidate = 7'b0000000;
			freeingScalar = 1'b1;
		end

		32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10:
		begin
			freeingCandidate = 7'b0000001;
			freeingScalar = 1'b1;
		end

		32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxx100:
		begin
			freeingCandidate = 7'b0000010;
			freeingScalar = 1'b1;
		end

		32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxx1000:
		begin
			freeingCandidate = 7'b0000011;
			freeingScalar = 1'b1;
		end

		32'bxxxxxxxxxxxxxxxxxxxxxxxxxxx10000:
		begin
			freeingCandidate = 7'b0000100;
			freeingScalar = 1'b1;
		end

		32'bxxxxxxxxxxxxxxxxxxxxxxxxxx100000:
		begin
			freeingCandidate = 7'b0000101;
			freeingScalar = 1'b1;
		end

		32'bxxxxxxxxxxxxxxxxxxxxxxxxx1000000:
		begin
			freeingCandidate = 7'b0000110;
			freeingScalar = 1'b1;
		end

		32'bxxxxxxxxxxxxxxxxxxxxxxxx10000000:
		begin
			freeingCandidate = 7'b0000111;
			freeingScalar = 1'b1;
		end

		32'bxxxxxxxxxxxxxxxxxxxxxxx100000000:
		begin
			freeingCandidate = 7'b0001000;
			freeingScalar = 1'b1;
		end

		32'bxxxxxxxxxxxxxxxxxxxxxx1000000000:
		begin
			freeingCandidate = 7'b0001001;
			freeingScalar = 1'b1;
		end

		32'bxxxxxxxxxxxxxxxxxxxxx10000000000:
		begin
			freeingCandidate = 7'b0001010;
			freeingScalar = 1'b1;
		end

		32'bxxxxxxxxxxxxxxxxxxxx100000000000:
		begin
			freeingCandidate = 7'b0001011;
			freeingScalar = 1'b1;
		end

		32'bxxxxxxxxxxxxxxxxxxx1000000000000:
		begin
			freeingCandidate = 7'b0001100;
			freeingScalar = 1'b1;
		end

		32'bxxxxxxxxxxxxxxxxxx10000000000000:
		begin
			freeingCandidate = 7'b0001101;
			freeingScalar = 1'b1;
		end

		32'bxxxxxxxxxxxxxxxxx100000000000000:
		begin
			freeingCandidate = 7'b0001110;
			freeingScalar = 1'b1;
		end

		32'bxxxxxxxxxxxxxxxx1000000000000000:
		begin
			freeingCandidate = 7'b0001111;
			freeingScalar = 1'b1;
		end

		32'bxxxxxxxxxxxxxxx10000000000000000:
		begin
			freeingCandidate = 7'b0010000;
			freeingScalar = 1'b1;
		end

		32'bxxxxxxxxxxxxxx100000000000000000:
		begin
			freeingCandidate = 7'b0010001;
			freeingScalar = 1'b1;
		end

		32'bxxxxxxxxxxxxx1000000000000000000:
		begin
			freeingCandidate = 7'b0010010;
			freeingScalar = 1'b1;
		end

		32'bxxxxxxxxxxxx10000000000000000000:
		begin
			freeingCandidate = 7'b0010011;
			freeingScalar = 1'b1;
		end

		32'bxxxxxxxxxxx100000000000000000000:
		begin
			freeingCandidate = 7'b0010100;
			freeingScalar = 1'b1;
		end

		32'bxxxxxxxxxx1000000000000000000000:
		begin
			freeingCandidate = 7'b0010101;
			freeingScalar = 1'b1;
		end

		32'bxxxxxxxxx10000000000000000000000:
		begin
			freeingCandidate = 7'b0010110;
			freeingScalar = 1'b1;
		end

		32'bxxxxxxxx100000000000000000000000:
		begin
			freeingCandidate = 7'b0010111;
			freeingScalar = 1'b1;
		end

		32'bxxxxxxx1000000000000000000000000:
		begin
			freeingCandidate = 7'b0011000;
			freeingScalar = 1'b1;
		end

		32'bxxxxxx10000000000000000000000000:
		begin
			freeingCandidate = 7'b0011001;
			freeingScalar = 1'b1;
		end

		32'bxxxxx100000000000000000000000000:
		begin
			freeingCandidate = 7'b0011010;
			freeingScalar = 1'b1;
		end

		32'bxxxx1000000000000000000000000000:
		begin
			freeingCandidate = 7'b0011011;
			freeingScalar = 1'b1;
		end

		32'bxxx10000000000000000000000000000:
		begin
			freeingCandidate = 7'b0011100;
			freeingScalar = 1'b1;
		end

		32'bxx100000000000000000000000000000:
		begin
			freeingCandidate = 7'b0011101;
			freeingScalar = 1'b1;
		end

		32'bx1000000000000000000000000000000:
		begin
			freeingCandidate = 7'b0011110;
			freeingScalar = 1'b1;
		end

		32'b10000000000000000000000000000000:
		begin
			freeingCandidate = 7'b0011111;
			freeingScalar = 1'b1;
		end

		default:
		begin
				freeingCandidate = 0;
				freeingScalar = 0;
			end
	endcase
end

endmodule
