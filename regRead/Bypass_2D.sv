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


module Bypass_2D (
	
	input                                clk,
	input                                reset,
	
	input  bypassPkt                     bypassPacket_i [0:`ISSUE_WIDTH-1],
	
	input  [`SIZE_PHYSICAL_LOG-1:0]      phySrc_i,

	input  [`SRAM_DATA_WIDTH-1:0]        datastage0_i,
	input  [`SRAM_DATA_WIDTH-1:0]        datastage1_i,
	input  [`SRAM_DATA_WIDTH-1:0]        datastage2_i,
	input  [`SRAM_DATA_WIDTH-1:0]        datastage3_i,

	output  [`SIZE_DATA-1:0]             data_o
	);


/* Stage-0 signals */
reg  [`ISSUE_WIDTH-1:0]                match_l0;
reg                                    match_l0_OR;

reg  [`SIZE_DATA/2-1:0]                dataLo_l0;
reg  [`SIZE_DATA/2-1:0]                dataHi_l0;


/* Compare phySrc_i with each bypass tag. A match means grab the data */
always_comb
begin
	int i;

	for (i = 0; i < `ISSUE_WIDTH; i++)
	begin
		match_l0[i]     = ((phySrc_i == bypassPacket_i[i].tag) && bypassPacket_i[i].valid);
	end
end

/* High if data should be grabbed from the bypass */
assign match_l0_OR  = |match_l0;

/* Register the data between the this RegRead stage and the next RegRead stage.
 * If there's a bypass match then get the data from the bypass. Else, get the
 * data from the physical register file. 
 * Note: bytes 2 and 3 from the PRF are not the correct values in this cycle.
 * They will arrive next cycle. */
always_ff @(posedge clk)
begin
	int i;

	if (match_l0_OR)
	begin
		/* Use data from the bypass */
		/* Encoder */
		for (i = 0; i < `ISSUE_WIDTH; i++)
		begin
			if (match_l0[i])
			begin
				dataLo_l0  <= bypassPacket_i[i].data[`SIZE_DATA/2-1:0];
			end
		end
	end

	else
	begin
		/* Use data from the previous cycle */
		dataLo_l0      <= {datastage1_i, datastage0_i};
	end


	if (match_l0_OR)
	begin
		/* Use data from the bypass */
		/* Encoder */
		for (i = 0; i < `ISSUE_WIDTH; i++)
		begin
			if (match_l0[i])
			begin
				dataHi_l0  <= bypassPacket_i[i].data[`SIZE_DATA-1:`SIZE_DATA/2];
			end
		end
	end

	else
	begin
		/* Use data from the previous cycle */
		dataHi_l0      <= {datastage3_i, datastage2_i};
	end

end


/* Stage-1 signals */
reg  [`ISSUE_WIDTH-1:0]                match_l1;
reg                                    match_l1_OR;
reg                                    prevMatched;

reg  [`SIZE_DATA/2-1:0]                dataLo_l1;
reg  [`SIZE_DATA/2-1:0]                dataHi_l1;

reg [`SIZE_PHYSICAL_LOG-1:0]           phySrc_l1;


always_ff @(posedge clk)
begin
	/* phySrc_l1 is the physical source register of the instruction in this
	 * bypass stage */
	phySrc_l1        <= phySrc_i;

	/* High if there was a bypass match in the previous bypass stage */
	prevMatched      <= match_l0_OR;
end

/* Compare phySrc_l1 with each bypass tag. Grab the data if there's a match.
 * Else, get data from the previous bypass stage or the physical register file */
always_comb
begin
	int i;
	for (i = 0; i < `ISSUE_WIDTH; i++)
	begin
		match_l1[i]     = ((phySrc_l1 == bypassPacket_i[i].tag) && bypassPacket_i[i].valid);
	end
end

/* High if there's a bypass match this cycle */
assign match_l1_OR  = |match_l1;

/* Bytes 0 and 1 are provided by the physical register file in bypass stage 0.
 * If there's no bypass match this cycle then use the data from the previous
 * cycle. 
 * Bytes 2 and 3 come this cycle from the physical register file. If there's a
 * bypass match this cycle then get the data from the bypass. If there was a
 * match last cycle then use the data from the previous cycle. If there was no
 * match then use the data from the physical register file. */
always_comb
begin
	int i;

	if (match_l1_OR)
	begin
		/* Use data from the bypass */
		/* Encoder */
		for (i = 0; i < `ISSUE_WIDTH; i++)
		begin
			if (match_l1[i])
			begin
				dataLo_l1   = bypassPacket_i[i].data[`SIZE_DATA/2-1:0];
			end
		end
	end

	else
	begin
		/* Use data from the previous cycle */
		dataLo_l1       = dataLo_l0;
	end


	if (match_l1_OR)
	begin
		/* Use data from the bypass */
		/* Encoder */
		for (i = 0; i < `ISSUE_WIDTH; i++)
		begin
			if (match_l1[i])
			begin
				dataHi_l1   = bypassPacket_i[i].data[`SIZE_DATA-1:2*`SIZE_DATA];
			end
		end
	end

	else if (prevMatched)
	begin
		/* Use data from the previous cycle */
		dataHi_l1       = dataHi_l0;
	end

	else
	begin
		/* Use data from the physical register file */
		dataHi_l1       = {datastage3_i, datastage2_i};
	end
end

assign data_o      = {dataHi_l1, dataLo_l1};

endmodule
