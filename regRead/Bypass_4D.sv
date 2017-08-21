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


module Bypass_4D (
	
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

reg  [`SRAM_DATA_WIDTH-1:0]            byte0_l0;
reg  [`SRAM_DATA_WIDTH-1:0]            byte1_l0;
reg  [`SRAM_DATA_WIDTH-1:0]            byte2_l0;
reg  [`SRAM_DATA_WIDTH-1:0]            byte3_l0;


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
 * Note: bytes 1, 2 and 3 from the PRF are not the correct values in this cycle.
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
				byte0_l0  <= bypassPacket_i[i].data[`SRAM_DATA_WIDTH-1:0];
				byte1_l0  <= bypassPacket_i[i].data[2*`SRAM_DATA_WIDTH-1:`SRAM_DATA_WIDTH];
				byte2_l0  <= bypassPacket_i[i].data[3*`SRAM_DATA_WIDTH-1:2*`SRAM_DATA_WIDTH];
				byte3_l0  <= bypassPacket_i[i].data[4*`SRAM_DATA_WIDTH-1:3*`SRAM_DATA_WIDTH];
			end
		end
	end

	else
	begin
		/* Use data from the previous cycle */
		byte0_l0     <= datastage0_i;
		byte1_l0     <= datastage1_i;
		byte2_l0     <= datastage2_i;
		byte3_l0     <= datastage3_i;
	end


	/* if (match_l0_OR) */
	/* begin */
	/* 	/1* Use data from the bypass *1/ */
	/* 	/1* Encoder *1/ */
	/* 	for (i = 0; i < `ISSUE_WIDTH; i++) */
	/* 	begin */
	/* 		if (match_l0[i]) */
	/* 		begin */
	/* 			byte1_l0  <= bypassPacket_i[i].data[15:8]; */
	/* 		end */
	/* 	end */
	/* end */

	/* else */
	/* begin */
	/* 	/1* Use data from the previous cycle *1/ */
	/* 	byte1_l0     <= datastage1_i; */
	/* end */


	/* if (match_l0_OR) */
	/* begin */
	/* 	/1* Use data from the bypass *1/ */
	/* 	/1* Encoder *1/ */
	/* 	for (i = 0; i < `ISSUE_WIDTH; i++) */
	/* 	begin */
	/* 		if (match_l0[i]) */
	/* 		begin */
	/* 			byte2_l0  <= bypassPacket_i[i].data[23:16]; */
	/* 		end */
	/* 	end */
	/* end */

	/* else */
	/* begin */
	/* 	/1* Use data from the previous cycle *1/ */
	/* 	byte2_l0     <= datastage2_i; */
	/* end */


	/* if (match_l0_OR) */
	/* begin */
	/* 	/1* Use data from the bypass *1/ */
	/* 	/1* Encoder *1/ */
	/* 	for (i = 0; i < `ISSUE_WIDTH; i++) */
	/* 	begin */
	/* 		if (match_l0[i]) */
	/* 		begin */
	/* 			byte3_l0  <= bypassPacket_i[i].data[31:24]; */
	/* 		end */
	/* 	end */
	/* end */

	/* else */
	/* begin */
	/* 	/1* Use data from the previous cycle *1/ */
	/* 	byte3_l0     <= datastage3_i; */
	/* end */

end


/* Stage-1 signals */
reg  [`ISSUE_WIDTH-1:0]                match_l1;
reg                                    match_l1_OR;
reg                                    prevMatched_l1;

reg  [`SRAM_DATA_WIDTH-1:0]            byte0_l1;
reg  [`SRAM_DATA_WIDTH-1:0]            byte1_l1;
reg  [`SRAM_DATA_WIDTH-1:0]            byte2_l1;
reg  [`SRAM_DATA_WIDTH-1:0]            byte3_l1;

reg [`SIZE_PHYSICAL_LOG-1:0]           phySrc_l1;


always_ff @(posedge clk)
begin
	/* phySrc_l1 is the physical source register of the instruction in this
	 * bypass stage */
	phySrc_l1        <= phySrc_i;

	/* High if there was a bypass match in the previous bypass stage */
	prevMatched_l1   <= match_l0_OR;
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

/* Byte 0 is provided by the physical register file in bypass stage 0.
 * If there's no bypass match this cycle then use the data from the previous
 * cycle. 
 * Byte 1 comes this cycle from the physical register file. If there's a
 * bypass match this cycle then get the data from the bypass. If there was a
 * match last cycle then use the data from the previous cycle. If there was no
 * match then use the data from the physical register file. 
 * Bytes 2 and 3 are provided by the physical register file in the next bypass
 * stage. If there's no bypass match this cycle then use the data from the previous
 * cycle. */
always_ff @(posedge clk)
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
				byte0_l1  <= bypassPacket_i[i].data[`SRAM_DATA_WIDTH-1:0];
			end
		end
	end

	else
	begin
		/* Use data from the previous cycle */
		byte0_l1      <= byte0_l0;
	end


	if (match_l1_OR)
	begin
		/* Use data from the bypass */
		/* Encoder */
		for (i = 0; i < `ISSUE_WIDTH; i++)
		begin
			if (match_l1[i])
			begin
				byte1_l1  <= bypassPacket_i[i].data[2*`SRAM_DATA_WIDTH-1:`SRAM_DATA_WIDTH];
			end
		end
	end

	else if (prevMatched_l1)
	begin
		/* Use data from the previous cycle */
		byte1_l1      <= byte1_l0;
	end

	else
	begin
		/* Use data from the physical register file */
		byte1_l1      <= datastage1_i;
	end


	if (match_l1_OR)
	begin
		/* Use data from the bypass */
		/* Encoder */
		for (i = 0; i < `ISSUE_WIDTH; i++)
		begin
			if (match_l1[i])
			begin
				byte2_l1  <= bypassPacket_i[i].data[3*`SRAM_DATA_WIDTH-1:2*`SRAM_DATA_WIDTH];
				byte3_l1  <= bypassPacket_i[i].data[4*`SRAM_DATA_WIDTH-1:3*`SRAM_DATA_WIDTH];
			end
		end
	end

	else
	begin
		/* Use data from the previous cycle */
		byte2_l1      <= byte2_l0;
		byte3_l1      <= byte3_l0;
	end

end


/* Stage-2 signals */
reg  [`ISSUE_WIDTH-1:0]                match_l2;
reg                                    match_l2_OR;
reg                                    prevMatched_l2;

reg  [`SRAM_DATA_WIDTH-1:0]            byte0_l2;
reg  [`SRAM_DATA_WIDTH-1:0]            byte1_l2;
reg  [`SRAM_DATA_WIDTH-1:0]            byte2_l2;
reg  [`SRAM_DATA_WIDTH-1:0]            byte3_l2;

reg [`SIZE_PHYSICAL_LOG-1:0]           phySrc_l2;


always_ff @(posedge clk)
begin
	/* phySrc_l2 is the physical source register of the instruction in this
	 * bypass stage */
	phySrc_l2        <= phySrc_l1;

	/* High if there was a bypass match in the previous bypass stage */
	prevMatched_l2   <= prevMatched_l1 | match_l1_OR;
end

/* Compare phySrc_l2 with each bypass tag. Grab the data if there's a match.
 * Else, get data from the previous bypass stage or the physical register file */
always_comb
begin
	int i;
	for (i = 0; i < `ISSUE_WIDTH; i++)
	begin
		match_l2[i]     = ((phySrc_l2 == bypassPacket_i[i].tag) && bypassPacket_i[i].valid);
	end
end

/* High if there's a bypass match this cycle */
assign match_l2_OR  = |match_l2;

/* Bytes 0 and 1 are provided by the physical register file in previous bypass stages.
 * If there's no bypass match this cycle then use the data from the previous
 * cycle. 
 * Byte 2 comes this cycle from the physical register file. If there's a
 * bypass match this cycle then get the data from the bypass. If there was a
 * match last cycle then use the data from the previous cycle. If there was no
 * match then use the data from the physical register file. 
 * Byte 3 is provided by the physical register file in the next bypass
 * stage. If there's no bypass match this cycle then use the data from the previous
 * cycle. */
always_ff @(posedge clk)
begin
	int i;

	if (match_l2_OR)
	begin
		/* Use data from the bypass */
		/* Encoder */
		for (i = 0; i < `ISSUE_WIDTH; i++)
		begin
			if (match_l2[i])
			begin
				byte0_l2  <= bypassPacket_i[i].data[`SRAM_DATA_WIDTH-1:0];
				byte1_l2  <= bypassPacket_i[i].data[2*`SRAM_DATA_WIDTH-1:`SRAM_DATA_WIDTH];
			end
		end
	end

	else
	begin
		/* Use data from the previous cycle */
		byte0_l2      <= byte0_l1;
		byte1_l2      <= byte1_l1;
	end


	/* if (match_l2_OR) */
	/* begin */
	/* 	/1* Use data from the bypass *1/ */
	/* 	/1* Encoder *1/ */
	/* 	for (i = 0; i < `ISSUE_WIDTH; i++) */
	/* 	begin */
	/* 		if (match_l2[i]) */
	/* 		begin */
	/* 			byte1_l2  <= bypassPacket_i[i].data[15:8]; */
	/* 		end */
	/* 	end */
	/* end */

	/* else */
	/* begin */
	/* 	/1* Use data from the previous cycle *1/ */
	/* 	byte1_l2      <= byte1_l1; */
	/* end */


	if (match_l2_OR)
	begin
		/* Use data from the bypass */
		/* Encoder */
		for (i = 0; i < `ISSUE_WIDTH; i++)
		begin
			if (match_l2[i])
			begin
				byte2_l2  <= bypassPacket_i[i].data[3*`SRAM_DATA_WIDTH-1:2*`SRAM_DATA_WIDTH];
			end
		end
	end

	else if (prevMatched_l2)
	begin
		/* Use data from the previous cycle */
		byte2_l2      <= byte2_l1;
	end

	else
	begin
		/* Use data from the physical register file */
		byte2_l2      <= datastage2_i;
	end


	if (match_l2_OR)
	begin
		/* Use data from the bypass */
		/* Encoder */
		for (i = 0; i < `ISSUE_WIDTH; i++)
		begin
			if (match_l2[i])
			begin
				byte3_l2  <= bypassPacket_i[i].data[4*`SRAM_DATA_WIDTH-1:3*`SRAM_DATA_WIDTH];
			end
		end
	end

	else
	begin
		/* Use data from the previous cycle */
		byte3_l2      <= byte3_l1;
	end

end


/* Stage-3 signals */
reg  [`ISSUE_WIDTH-1:0]                match_l3;
reg                                    match_l3_OR;
reg                                    prevMatched_l3;

reg  [`SRAM_DATA_WIDTH-1:0]            byte0_l3;
reg  [`SRAM_DATA_WIDTH-1:0]            byte1_l3;
reg  [`SRAM_DATA_WIDTH-1:0]            byte2_l3;
reg  [`SRAM_DATA_WIDTH-1:0]            byte3_l3;

reg [`SIZE_PHYSICAL_LOG-1:0]           phySrc_l3;


always_ff @(posedge clk)
begin
	/* phySrc_l3 is the physical source register of the instruction in this
	 * bypass stage */
	phySrc_l3        <= phySrc_l2;

	/* High if there was a bypass match in the previous bypass stage */
	prevMatched_l3   <= prevMatched_l2 | match_l2_OR;
end

/* Compare phySrc_l3 with each bypass tag. Grab the data if there's a match.
 * Else, get data from the previous bypass stage or the physical register file.
 * There should be, at most, 1 bypass match. */
always_comb
begin
	int i;
	for (i = 0; i < `ISSUE_WIDTH; i++)
	begin
		match_l3[i]     = ((phySrc_l3 == bypassPacket_i[i].tag) && bypassPacket_i[i].valid);
	end
end

/* High if there's a bypass match this cycle */
assign match_l3_OR  = |match_l3;

/* Bytes 0, 1 and 2 are provided by the physical register file in previous bypass stages.
 * If there's no bypass match this cycle then use the data from the previous
 * cycle. 
 * Byte 3 comes this cycle from the physical register file. If there's a
 * bypass match this cycle then get the data from the bypass. If there was a
 * match last cycle then use the data from the previous cycle. If there was no
 * match then use the data from the physical register file. */
always_comb
begin
	int i;

	if (match_l3_OR)
	begin
		/* Use data from the bypass */
		/* Encoder */
		for (i = 0; i < `ISSUE_WIDTH; i++)
		begin
			if (match_l3[i])
			begin
				byte0_l3   = bypassPacket_i[i].data[`SRAM_DATA_WIDTH-1:0];
				byte1_l3   = bypassPacket_i[i].data[2*`SRAM_DATA_WIDTH-1:`SRAM_DATA_WIDTH];
				byte2_l3   = bypassPacket_i[i].data[3*`SRAM_DATA_WIDTH-1:2*`SRAM_DATA_WIDTH];
			end
		end
	end

	else
	begin
		/* Use data from the previous cycle */
		byte0_l3       = byte0_l2;
		byte1_l3       = byte1_l2;
		byte2_l3       = byte2_l2;
	end


	/* if (match_l3_OR) */
	/* begin */
	/* 	/1* Use data from the bypass *1/ */
	/* 	/1* Encoder *1/ */
	/* 	for (i = 0; i < `ISSUE_WIDTH; i++) */
	/* 	begin */
	/* 		if (match_l3[i]) */
	/* 		begin */
	/* 			byte1_l3   = bypassPacket_i[i].data[15:8]; */
	/* 		end */
	/* 	end */
	/* end */

	/* else */
	/* begin */
	/* 	/1* Use data from the previous cycle *1/ */
	/* 	byte1_l3       = byte1_l2; */
	/* end */


	/* if (match_l3_OR) */
	/* begin */
	/* 	/1* Use data from the bypass *1/ */
	/* 	/1* Encoder *1/ */
	/* 	for (i = 0; i < `ISSUE_WIDTH; i++) */
	/* 	begin */
	/* 		if (match_l3[i]) */
	/* 		begin */
	/* 			byte2_l3   = bypassPacket_i[i].data[23:16]; */
	/* 		end */
	/* 	end */
	/* end */

	/* else */
	/* begin */
	/* 	/1* Use data from the previous cycle *1/ */
	/* 	byte2_l3       = byte2_l2; */
	/* end */


	if (match_l3_OR)
	begin
		/* Use data from the bypass */
		/* Encoder */
		for (i = 0; i < `ISSUE_WIDTH; i++)
		begin
			if (match_l3[i])
			begin
				byte3_l3   = bypassPacket_i[i].data[4*`SRAM_DATA_WIDTH-1:3*`SRAM_DATA_WIDTH];
			end
		end
	end

	else if (prevMatched_l3)
	begin
		/* Use data from the previous cycle */
		byte3_l3       = byte3_l2;
	end

	else
	begin
		/* Use data from the physical register file */
		byte3_l3       = datastage3_i;
	end

end

assign data_o      = {byte3_l3, byte2_l3, byte1_l3, byte0_l3};

endmodule
