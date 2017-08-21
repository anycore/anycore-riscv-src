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


module CommitStore (
	input  [`COMMIT_WIDTH-1:0]            commitStore_i,
	input  [`SIZE_LSQ_LOG-1:0]            stqCommitPtr_i,

	output reg [2:0]                      commitStCount_o,

	output reg [`SIZE_LSQ_LOG-1:0]        commitStIndex_o [0:`COMMIT_WIDTH-1]
);


always_comb
begin
	commitStCount_o    = 0;
	commitStIndex_o[0] = 0;
	commitStIndex_o[1] = 0;
	commitStIndex_o[2] = 0;
	commitStIndex_o[3] = 0;


	/* Following combinational logic counts the number of LD commitructions in the
	 * incoming retiring commitructions. */
	case (commitStore_i)
		4'b0001:
		begin
			commitStCount_o          = 1;
			commitStIndex_o[0]       = stqCommitPtr_i;
		end

		4'b0010:
		begin
			commitStCount_o          = 1;
			commitStIndex_o[0]       = stqCommitPtr_i;
		end

		4'b0011:
		begin
			commitStCount_o          = 2;
			commitStIndex_o[0]       = stqCommitPtr_i;
			commitStIndex_o[1]       = stqCommitPtr_i + 1;
		end

		4'b0100:
		begin
			commitStCount_o          = 1;
			commitStIndex_o[0]       = stqCommitPtr_i;
		end

		4'b0101:
		begin
			commitStCount_o          = 2;
			commitStIndex_o[0]       = stqCommitPtr_i;
			commitStIndex_o[1]       = stqCommitPtr_i + 1;
		end

		4'b0110:
		begin
			commitStCount_o          = 2;
			commitStIndex_o[0]       = stqCommitPtr_i;
			commitStIndex_o[1]       = stqCommitPtr_i + 1;
		end

		4'b0111:
		begin
			commitStCount_o          = 3;
			commitStIndex_o[0]       = stqCommitPtr_i;
			commitStIndex_o[1]       = stqCommitPtr_i + 1;
			commitStIndex_o[2]       = stqCommitPtr_i + 2;
		end

		4'b1000:
		begin
			commitStCount_o          = 1;
			commitStIndex_o[0]       = stqCommitPtr_i;
		end

		4'b1001:
		begin
			commitStCount_o          = 2;
			commitStIndex_o[0]       = stqCommitPtr_i;
			commitStIndex_o[1]       = stqCommitPtr_i + 1;
		end

		4'b1010:
		begin
			commitStCount_o          = 2;
			commitStIndex_o[0]       = stqCommitPtr_i;
			commitStIndex_o[1]       = stqCommitPtr_i + 1;
		end

		4'b1011:
		begin
			commitStCount_o          = 3;
			commitStIndex_o[0]       = stqCommitPtr_i;
			commitStIndex_o[1]       = stqCommitPtr_i + 1;
			commitStIndex_o[2]       = stqCommitPtr_i + 2;
		end

		4'b1100:
		begin
			commitStCount_o          = 2;
			commitStIndex_o[0]       = stqCommitPtr_i;
			commitStIndex_o[1]       = stqCommitPtr_i + 1;
		end

		4'b1101:
		begin
			commitStCount_o          = 3;
			commitStIndex_o[0]       = stqCommitPtr_i;
			commitStIndex_o[1]       = stqCommitPtr_i + 1;
			commitStIndex_o[2]       = stqCommitPtr_i + 2;
		end

		4'b1110:
		begin
			commitStCount_o          = 3;
			commitStIndex_o[0]       = stqCommitPtr_i;
			commitStIndex_o[1]       = stqCommitPtr_i + 1;
			commitStIndex_o[2]       = stqCommitPtr_i + 2;
		end

		4'b1111:
		begin
			commitStCount_o          = 4;
			commitStIndex_o[0]       = stqCommitPtr_i;
			commitStIndex_o[1]       = stqCommitPtr_i + 1;
			commitStIndex_o[2]       = stqCommitPtr_i + 2;
			commitStIndex_o[3]       = stqCommitPtr_i + 3;
		end
	endcase 
end

endmodule
