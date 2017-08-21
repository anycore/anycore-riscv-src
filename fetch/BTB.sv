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


module BTB(
	input                     clk,
	input                     reset,
	input                     resetRams_i,

	input                     stall_i,

`ifdef DYNAMIC_CONFIG
  input [`FETCH_WIDTH-1:0]  fetchLaneActive_i,
`endif

	input  [`SIZE_PC-1:0]     PC_i,

	/* BTB updates from the Branch Order Buffer. */
	input                     updateEn_i,
	input  [`SIZE_PC-1:0]     updatePC_i,
	input  [`SIZE_PC-1:0]     updateNPC_i,
	input  [`BRANCH_TYPE_LOG-1:0] updateBrType_i,

	output btbPkt             btbPacket_o [0:`FETCH_WIDTH-1],
  output                    btbRamReady_o
	);


/* BTB width must be a power of two */
localparam BTB_WIDTH = 1<<`FETCH_WIDTH_LOG;

localparam TAG       = (`SIZE_PC-`SIZE_BTB_LOG-`SIZE_INST_BYTE_OFFSET);
localparam INDEX     = (`SIZE_BTB_LOG-`FETCH_WIDTH_LOG);


/* {tag, takenPC, ctrlType, valid} for each instruction */
btbDataPkt                                          btbData       [0:BTB_WIDTH-1];

`ifdef DYNAMIC_CONFIG
  localparam SIZE_TAG = (TAG + `FETCH_WIDTH_LOG);
`else
  localparam SIZE_TAG = TAG;
`endif

/* Used for hit-detection of each instruction */
reg  [SIZE_TAG-1:0]                                 instTag       [0:BTB_WIDTH-1];
reg  [INDEX-1:0]                                    instIndex     [0:BTB_WIDTH-1];
reg  [`FETCH_WIDTH_LOG-1:0]                         instOffset    [0:BTB_WIDTH-1];

/* Unshifted btb data */
reg  [INDEX-1:0]                                    rdAddr        [0:BTB_WIDTH-1];
btbDataPkt                                          rdData        [0:BTB_WIDTH-1];

reg  [INDEX-1:0]                                    wrAddr;
btbDataPkt                                          wrData;
reg                                                 we            [0:BTB_WIDTH-1];


`ifdef DYNAMIC_CONFIG
  wire [BTB_WIDTH-1:0] clkGated;
  `ifdef GATE_CLK
      // Instantiating clk gate cell
      clk_gater_ul clkGate01(.clk_i(clk), .clkGated_o(clkGated[0]), .clkEn_i(fetchLaneActive_i[0]));
      assign clkGated[1] = clkGated[0];
    `ifdef FETCH_THREE_WIDE
      // Instantiating clk gate cell
      clk_gater_ul clkGate23(.clk_i(clk), .clkGated_o(clkGated[2]), .clkEn_i(fetchLaneActive_i[2]));
      assign clkGated[3] = clkGated[2];
    `endif
    `ifdef FETCH_FIVE_WIDE
      // Instantiating clk gate cell
      clk_gater_ul clkGate4567(.clk_i(clk), .clkGated_o(clkGated[4]), .clkEn_i(fetchLaneActive_i[4]));
      assign clkGated[5] = clkGated[4];
      assign clkGated[6] = clkGated[4];
      assign clkGated[7] = clkGated[4];
    `endif
  `else
      assign clkGated[0] = clk;
      assign clkGated[1] = clk;
    `ifdef FETCH_THREE_WIDE
      assign clkGated[2] = clk;
      assign clkGated[3] = clk;
    `endif
    `ifdef FETCH_FIVE_WIDE
      assign clkGated[4] = clk;
      assign clkGated[5] = clk;
      assign clkGated[6] = clk;
      assign clkGated[7] = clk;
    `endif
  `endif //GATE_CLK
`endif //DYNAMIC_CONFIG

//// BIST State Machine to Initialize RAM/CAM /////////////

localparam BIST_SIZE_ADDR   = INDEX;
localparam BIST_SIZE_DATA   = `SIZE_BTB_DATA;
localparam BIST_NUM_ENTRIES = `SIZE_BTB/BTB_WIDTH;
localparam BIST_RESET_MODE  = 0; //0 -> Fixed value; 1 -> Sequential values
localparam BIST_RESET_VALUE = 0; // Initialize all entries to 2=weakly taken

localparam BIST_START = 0;
localparam BIST_RUN   = 1;
localparam BIST_DONE  = 2;

logic                       bistEn;
logic [1:0]                 bistState;
logic [1:0]                 bistNextState;
logic [BIST_SIZE_ADDR-1:0]  bistAddrWr;
logic [BIST_SIZE_ADDR-1:0]  bistNextAddrWr;
logic [BIST_SIZE_DATA-1:0]  bistDataWr;

assign bistDataWr = (BIST_RESET_MODE == 0) ? BIST_RESET_VALUE : {{(BIST_SIZE_DATA-BIST_SIZE_ADDR){1'b0}},bistAddrWr};
assign btbRamReady_o = ~bistEn;

always_ff @(posedge clk or posedge resetRams_i)
begin
  if(resetRams_i)
  begin
    bistState       <= BIST_START;
    bistAddrWr      <= {BIST_SIZE_ADDR{1'b0}};
  end
  else
  begin
    bistState       <= bistNextState;
    bistAddrWr      <= bistNextAddrWr;
  end
end

always_comb
begin
  bistEn              = 1'b0;
  bistNextState       = bistState;
  bistNextAddrWr      = bistAddrWr;

  case(bistState)
    BIST_START: begin
      bistNextState   = BIST_RUN;
      bistNextAddrWr  = 0;
    end
    BIST_RUN: begin
      bistEn = 1'b1;
      bistNextAddrWr  = bistAddrWr + 1'b1;

      if(bistAddrWr == BIST_NUM_ENTRIES-1)
      begin
        bistNextState = BIST_DONE;
      end
      else
      begin
        bistNextState = BIST_RUN;
      end
    end
    BIST_DONE: begin
      bistNextAddrWr  = 0;
      bistNextState   = BIST_DONE;
    end
  endcase
end

//////////////////////////////////////////////////////////
/* Instantiate BTB Tag and BTB Data SRAMs. */
genvar g;
generate

for (g = 0; g < BTB_WIDTH; g = g + 1)
begin: btbTag_gen

BTB_RAM #(
  .RPORT      (1),
  .WPORT      (1),
	.DEPTH      (`SIZE_BTB/BTB_WIDTH),
	.INDEX      (INDEX),
	.WIDTH      (`SIZE_BTB_DATA) // Always store the largest possible tag and compare it
	)

	btbTag (

`ifdef DYNAMIC_CONFIG
	.clk        (clkGated[g]),
`else
	.clk        (clk),
`endif
	//.reset      (reset),

	.addr0_i    (rdAddr[g]),
	.data0_o    (rdData[g]),

	.addr0wr_i  (bistEn ? bistAddrWr : wrAddr),
	.data0wr_i  (bistEn ? bistDataWr : wrData),
	.we0_i      (bistEn ? 1'b1       : we[g])
);


end
endgenerate


/* TODO: Move this to FetchStage1 since i$ and BP also do it */
/* Create the addresses for the BTB */
always_comb
begin
	int i;
	for (i = 0; i < BTB_WIDTH; i = i + 1)
	begin
    `ifdef DYNAMIC_CONFIG
      logic [`SIZE_PC-`SIZE_INST_BYTE_OFFSET-1:0] instPC_t;
      instPC_t = PC_i[`SIZE_PC-1:`SIZE_INST_BYTE_OFFSET] + i;
  		{instIndex[i], instOffset[i]} = instPC_t;
      instTag[i]      = instPC_t[`SIZE_PC-`SIZE_INST_BYTE_OFFSET-1:`SIZE_PC-`SIZE_INST_BYTE_OFFSET-SIZE_TAG];
      casez(fetchLaneActive_i[2])
        1'b0:
        begin
          instIndex[i]  = {instIndex[i],instOffset[i][1]};
          instOffset[i] = instOffset[i] & 2'b01;
        end
        default:
        begin
        end
      endcase
    `else 
  		{instTag[i], instIndex[i], instOffset[i]} = PC_i[`SIZE_PC-1:`SIZE_INST_BYTE_OFFSET] + i;
    `endif
	end
end


/* Rotate the addresses to the correct SRAM */
always_comb
begin
	int i;

	/* TODO: Use coreGen to expand these loops */
	case ({{3-`FETCH_WIDTH_LOG{1'b0}},instOffset[0]})

		3'h0:
		begin
			rdAddr[0] = instIndex[0];
			rdAddr[1] = instIndex[1];

`ifdef FETCH_THREE_WIDE
			rdAddr[2] = instIndex[2];
			rdAddr[3] = instIndex[3];
`endif

`ifdef FETCH_FIVE_WIDE /* 5+ wide */
			rdAddr[4] = instIndex[4];
			rdAddr[5] = instIndex[5];
			rdAddr[6] = instIndex[6];
			rdAddr[7] = instIndex[7];
`endif
			/* 4-wide example:
			 * rdAddr[0] = pc[0];
			 * rdAddr[1] = pc[1];
			 * rdAddr[2] = pc[2];
			 * rdAddr[3] = pc[3]; */
			/* for (i = 0; i < BTB_WIDTH; i = i + 1) */
			/* begin : rdAddr0b */
			/* 	rdAddr[i] = instIndex[i]; */
			/* end */
		end

		3'h1:
		begin
`ifndef FETCH_THREE_WIDE /* 1- or 2-wide */
			rdAddr[0] = instIndex[1];
			rdAddr[1] = instIndex[0];
`endif

`ifdef FETCH_THREE_WIDE
`ifndef FETCH_FIVE_WIDE /* 3- or 4-wide */
    `ifdef DYNAMIC_CONFIG
			rdAddr[0] = fetchLaneActive_i[2] ? instIndex[3] : instIndex[1];
    `else
			rdAddr[0] = instIndex[3];
    `endif
			rdAddr[1] = instIndex[0];
			rdAddr[2] = instIndex[1];
			rdAddr[3] = instIndex[2];
`endif
`endif

`ifdef FETCH_FIVE_WIDE /* 5+ wide */
    `ifdef DYNAMIC_CONFIG
			rdAddr[0] = fetchLaneActive_i[4] ? instIndex[7] : (fetchLaneActive_i[2] ? instIndex[3] : instIndex[1]);
			rdAddr[1] = instIndex[0];
			rdAddr[2] = instIndex[1];
			rdAddr[3] = instIndex[2];
			rdAddr[4] = instIndex[3];
			rdAddr[5] = instIndex[4];
			rdAddr[6] = instIndex[5];
			rdAddr[7] = instIndex[6];
    `else      
			rdAddr[0] = instIndex[7];
			rdAddr[1] = instIndex[0];
			rdAddr[2] = instIndex[1];
			rdAddr[3] = instIndex[2];
			rdAddr[4] = instIndex[3];
			rdAddr[5] = instIndex[4];
			rdAddr[6] = instIndex[5];
			rdAddr[7] = instIndex[6];
    `endif
`endif
			/* 4-wide example:
			 * rdAddr[0] = pc[3];
			 * rdAddr[1] = pc[0];
			 * rdAddr[2] = pc[1];
			 * rdAddr[3] = pc[2]; */
			/* for (i = 0; i < 1; i = i + 1) */
			/* begin : rdAddr1a */
			/* 	rdAddr[i] = instIndex[BTB_WIDTH-i-1]; */
			/* end */

			/* for (i = 1; i < BTB_WIDTH; i = i + 1) */
			/* begin : rdAddr1b */
			/* 	rdAddr[i] = instIndex[i-1]; */
			/* end */
		end

`ifdef FETCH_THREE_WIDE
		3'h2:
		begin
`ifndef FETCH_FIVE_WIDE /* 3- or 4-wide */
			rdAddr[0] = instIndex[2];
			rdAddr[1] = instIndex[3];
			rdAddr[2] = instIndex[0];
			rdAddr[3] = instIndex[1];
`endif

`ifdef FETCH_FIVE_WIDE /* 5+ wide */
    `ifdef DYNAMIC_CONFIG
			rdAddr[0] = fetchLaneActive_i[4] ? instIndex[6] : instIndex[2];
			rdAddr[1] = fetchLaneActive_i[4] ? instIndex[7] : instIndex[3];
			rdAddr[2] = instIndex[0];
			rdAddr[3] = instIndex[1];
			rdAddr[4] = instIndex[2];
			rdAddr[5] = instIndex[3];
			rdAddr[6] = instIndex[4];
			rdAddr[7] = instIndex[5];
    `else
			rdAddr[0] = instIndex[6];
			rdAddr[1] = instIndex[7];
			rdAddr[2] = instIndex[0];
			rdAddr[3] = instIndex[1];
			rdAddr[4] = instIndex[2];
			rdAddr[5] = instIndex[3];
			rdAddr[6] = instIndex[4];
			rdAddr[7] = instIndex[5];
    `endif
`endif
			/* 4-wide example:
			 * rdAddr[0] = pc[2];
			 * rdAddr[1] = pc[3];
			 * rdAddr[2] = pc[0];
			 * rdAddr[3] = pc[1]; */
			/* for (i = 0; i < 2; i = i + 1) */
			/* begin : rdAddr2a */
			/* 	rdAddr[i] = instIndex[BTB_WIDTH-i-1]; */
			/* end */

			/* for (i = 2; i < BTB_WIDTH; i = i + 1) */
			/* begin : rdAddr2b */
			/* 	rdAddr[i] = instIndex[i-2]; */
			/* end */
		end

		3'h3:
		begin
`ifndef FETCH_FIVE_WIDE /* 3- or 4-wide */
			rdAddr[0] = instIndex[1];
			rdAddr[1] = instIndex[2];
			rdAddr[2] = instIndex[3];
			rdAddr[3] = instIndex[0];
`endif

`ifdef FETCH_FIVE_WIDE /* 5+ wide */
    `ifdef DYNAMIC_CONFIG
			rdAddr[0] = fetchLaneActive_i[4] ? instIndex[5] : instIndex[1];
			rdAddr[1] = fetchLaneActive_i[4] ? instIndex[6] : instIndex[2];
			rdAddr[2] = fetchLaneActive_i[4] ? instIndex[7] : instIndex[3];
			rdAddr[3] = instIndex[0];
			rdAddr[4] = instIndex[1];
			rdAddr[5] = instIndex[2];
			rdAddr[6] = instIndex[3];
			rdAddr[7] = instIndex[4];
    `else
			rdAddr[0] = instIndex[5];
			rdAddr[1] = instIndex[6];
			rdAddr[2] = instIndex[7];
			rdAddr[3] = instIndex[0];
			rdAddr[4] = instIndex[1];
			rdAddr[5] = instIndex[2];
			rdAddr[6] = instIndex[3];
			rdAddr[7] = instIndex[4];
    `endif
`endif
			/* 4-wide example:
			 * rdAddr[0] = pc[1];
			 * rdAddr[1] = pc[2];
			 * rdAddr[2] = pc[3];
			 * rdAddr[3] = pc[0]; */
			/* for (i = 0; i < 3; i = i + 1) */
			/* begin : rdAddr3a */
			/* 	rdAddr[i] = instIndex[BTB_WIDTH-i-1]; */
			/* end */

			/* for (i = 3; i < BTB_WIDTH; i = i + 1) */
			/* begin : rdAddr3b */
			/* 	rdAddr[i] = instIndex[i-3]; */
			/* end */
		end
`endif

`ifdef FETCH_FIVE_WIDE
		3'h4:
		begin
			rdAddr[0] = instIndex[4];
			rdAddr[1] = instIndex[5];
			rdAddr[2] = instIndex[6];
			rdAddr[3] = instIndex[7];
			rdAddr[4] = instIndex[0];
			rdAddr[5] = instIndex[1];
			rdAddr[6] = instIndex[2];
			rdAddr[7] = instIndex[3];
			/* for (i = 0; i < 4; i = i + 1) */
			/* begin : rdAddr4a */
			/* 	rdAddr[i] = instIndex[BTB_WIDTH-i-1]; */
			/* end */

			/* for (i = 4; i < BTB_WIDTH; i = i + 1) */
			/* begin : rdAddr4b */
			/* 	rdAddr[i] = instIndex[i-4]; */
			/* end */
		end

		3'h5:
		begin
			rdAddr[0] = instIndex[3];
			rdAddr[1] = instIndex[4];
			rdAddr[2] = instIndex[5];
			rdAddr[3] = instIndex[6];
			rdAddr[4] = instIndex[7];
			rdAddr[5] = instIndex[0];
			rdAddr[6] = instIndex[1];
			rdAddr[7] = instIndex[2];
			/* for (i = 0; i < 5; i = i + 1) */
			/* begin : rdAddr5a */
			/* 	rdAddr[i] = instIndex[BTB_WIDTH-i-1]; */
			/* end */

			/* for (i = 5; i < BTB_WIDTH; i = i + 1) */
			/* begin : rdAddr5b */
			/* 	rdAddr[i] = instIndex[i-5]; */
			/* end */
		end

		3'h6:
		begin
			rdAddr[0] = instIndex[2];
			rdAddr[1] = instIndex[3];
			rdAddr[2] = instIndex[4];
			rdAddr[3] = instIndex[5];
			rdAddr[4] = instIndex[6];
			rdAddr[5] = instIndex[7];
			rdAddr[6] = instIndex[0];
			rdAddr[7] = instIndex[1];
			/* for (i = 0; i < 6; i = i + 1) */
			/* begin : rdAddr6a */
			/* 	rdAddr[i] = instIndex[BTB_WIDTH-i-1]; */
			/* end */

			/* for (i = 6; i < BTB_WIDTH; i = i + 1) */
			/* begin : rdAddr6b */
			/* 	rdAddr[i] = instIndex[i-6]; */
			/* end */
		end

		3'h7:
		begin
			rdAddr[0] = instIndex[1];
			rdAddr[1] = instIndex[2];
			rdAddr[2] = instIndex[3];
			rdAddr[3] = instIndex[4];
			rdAddr[4] = instIndex[5];
			rdAddr[5] = instIndex[6];
			rdAddr[6] = instIndex[7];
			rdAddr[7] = instIndex[0];
			/* for (i = 0; i < 7; i = i + 1) */
			/* begin : rdAddr7a */
			/* 	rdAddr[i] = instIndex[BTB_WIDTH-i-1]; */
			/* end */

			/* for (i = 7; i < BTB_WIDTH; i = i + 1) */
			/* begin : rdAddr7b */
			/* 	rdAddr[i] = instIndex[i-7]; */
			/* end */
		end
`endif

	endcase
end

/* Rotate the data from the SRAM output to the correct order */
always_comb 
begin
	int i;

	for (i = 0; i < BTB_WIDTH; i = i + 1)
	begin
		btbData[i]  = 0;
	end

	case ({{3-`FETCH_WIDTH_LOG{1'b0}},instOffset[0]})

		3'h0:
		begin
			btbData[0] = rdData[0];
			btbData[1] = rdData[1];

`ifdef FETCH_THREE_WIDE
			btbData[2] = rdData[2];
			btbData[3] = rdData[3];

`endif

`ifdef FETCH_FIVE_WIDE /* 5+ wide */
			btbData[4] = rdData[4];
			btbData[5] = rdData[5];
			btbData[6] = rdData[6];
			btbData[7] = rdData[7];

`endif
			/* for (i = 0; i < BTB_WIDTH; i = i + 1) */
			/* begin : btbtag0a */
			/* 	btbData[i]  = rdData[i]; */
			/* end */
		end

		3'h1:
		begin
`ifndef FETCH_THREE_WIDE /* 1- or 2-wide */
			btbData[0] = rdData[1];
			btbData[1] = rdData[0];
`endif

`ifdef FETCH_THREE_WIDE
`ifndef FETCH_FIVE_WIDE /* 3- or 4-wide */
			btbData[0] = rdData[1];
    `ifdef DYNAMIC_CONFIG
			btbData[1] = fetchLaneActive_i[2] ? rdData[2] : rdData[0];
    `else
			btbData[1] = rdData[2];
    `endif
			btbData[2] = rdData[3];
			btbData[3] = rdData[0];
`endif
`endif

`ifdef FETCH_FIVE_WIDE /* 5+ wide */
    `ifdef DYNAMIC_CONFIG
			btbData[0] = rdData[1];
			btbData[1] = fetchLaneActive_i[2] ? rdData[2] : rdData[0]; 
			btbData[2] = rdData[3];                                    
			btbData[3] = fetchLaneActive_i[4] ? rdData[4] : rdData[0]; 
			btbData[4] = rdData[5];
			btbData[5] = rdData[6];
			btbData[6] = rdData[7];
			btbData[7] = rdData[0];

    `else
			btbData[0] = rdData[1];
			btbData[1] = rdData[2]; 
			btbData[2] = rdData[3];                                    
			btbData[3] = rdData[4]; 
			btbData[4] = rdData[5];
			btbData[5] = rdData[6];
			btbData[6] = rdData[7];
			btbData[7] = rdData[0];
    `endif
`endif
			/* for (i = 0; i < BTB_WIDTH-1; i = i + 1) */
			/* begin : btbtag1a */
			/* 	btbData[i]  = rdData[i+1]; */
			/* end */

			/* for (i = BTB_WIDTH-1; i < BTB_WIDTH; i = i + 1) */
			/* begin : btbtag1b */
			/* 	btbData[i]  = rdData[i-(BTB_WIDTH-1)]; */
			/* end */
		end

`ifdef FETCH_THREE_WIDE
		3'h2:
		begin
`ifndef FETCH_FIVE_WIDE /* 3- or 4-wide */
			btbData[0] = rdData[2];
			btbData[1] = rdData[3];
			btbData[2] = rdData[0];
			btbData[3] = rdData[1];
`endif

`ifdef FETCH_FIVE_WIDE /* 5+ wide */
    `ifdef DYNAMIC_CONFIG
			btbData[0] = rdData[2];
			btbData[1] = rdData[3];
			btbData[2] = fetchLaneActive_i[4] ? rdData[4] : rdData[0];
			btbData[3] = fetchLaneActive_i[4] ? rdData[5] : rdData[1];
			btbData[4] = rdData[6];
			btbData[5] = rdData[7];
			btbData[6] = rdData[0];
			btbData[7] = rdData[1];

    `else
			btbData[0] = rdData[2];
			btbData[1] = rdData[3];
			btbData[2] = rdData[4];
			btbData[3] = rdData[5];
			btbData[4] = rdData[6];
			btbData[5] = rdData[7];
			btbData[6] = rdData[0];
			btbData[7] = rdData[1];
    `endif
`endif
			/* for (i = 0; i < BTB_WIDTH-2; i = i + 1) */
			/* begin : btbtag2a */
			/* 	btbData[i]  = rdData[i+2]; */
			/* end */

			/* for (i = BTB_WIDTH-2; i < BTB_WIDTH; i = i + 1) */
			/* begin : btbtag2b */
			/* 	btbData[i]  = rdData[i-(BTB_WIDTH-2)]; */
			/* end */
		end

		3'h3:
		begin
`ifndef FETCH_FIVE_WIDE /* 3- or 4-wide */
			btbData[0] = rdData[3];
			btbData[1] = rdData[0];
			btbData[2] = rdData[1];
			btbData[3] = rdData[2];
`endif

`ifdef FETCH_FIVE_WIDE /* 5+ wide */
    `ifdef DYNAMIC_CONFIG
			btbData[0] = rdData[3];
			btbData[1] = fetchLaneActive_i[4] ? rdData[4] : rdData[0];
			btbData[2] = fetchLaneActive_i[4] ? rdData[5] : rdData[1];
			btbData[3] = fetchLaneActive_i[4] ? rdData[6] : rdData[2];
			btbData[4] = rdData[7];
			btbData[5] = rdData[0];
			btbData[6] = rdData[1];
			btbData[7] = rdData[2];

    `else
			btbData[0] = rdData[3];
			btbData[1] = rdData[4];
			btbData[2] = rdData[5];
			btbData[3] = rdData[6];
			btbData[4] = rdData[7];
			btbData[5] = rdData[0];
			btbData[6] = rdData[1];
			btbData[7] = rdData[2];
    `endif
`endif
			/* for (i = 0; i < BTB_WIDTH-3; i = i + 1) */
			/* begin : btbtag3a */
			/* 	btbData[i]  = rdData[i+3]; */
			/* end */

			/* for (i = BTB_WIDTH-3; i < BTB_WIDTH; i = i + 1) */
			/* begin : btbtag3b */
			/* 	btbData[i]  = rdData[i-(BTB_WIDTH-3)]; */
			/* end */
		end
`endif

`ifdef FETCH_FIVE_WIDE
		3'h4:
		begin
			btbData[0] = rdData[4];
			btbData[1] = rdData[5];
			btbData[2] = rdData[6];
			btbData[3] = rdData[7];
			btbData[4] = rdData[0];
			btbData[5] = rdData[1];
			btbData[6] = rdData[2];
			btbData[7] = rdData[3];
			/* for (i = 0; i < BTB_WIDTH-4; i = i + 1) */
			/* begin : btbtag4a */
			/* 	btbData[i]  = rdData[i+4]; */
			/* end */

			/* for (i = BTB_WIDTH-4; i < BTB_WIDTH; i = i + 1) */
			/* begin : btbtag4b */
			/* 	btbData[i]  = rdData[i-(BTB_WIDTH-4)]; */
			/* end */
		end

		3'h5:
		begin
			btbData[0] = rdData[5];
			btbData[1] = rdData[6];
			btbData[2] = rdData[7];
			btbData[3] = rdData[0];
			btbData[4] = rdData[1];
			btbData[5] = rdData[2];
			btbData[6] = rdData[3];
			btbData[7] = rdData[4];
			/* for (i = 0; i < BTB_WIDTH-5; i = i + 1) */
			/* begin : btbtag5a */
			/* 	btbData[i]  = rdData[i+5]; */
			/* end */

			/* for (i = BTB_WIDTH-5; i < BTB_WIDTH; i = i + 1) */
			/* begin : btbtag5b */
			/* 	btbData[i]  = rdData[i-(BTB_WIDTH-5)]; */
			/* end */
		end

		3'h6:
		begin
			btbData[0] = rdData[6];
			btbData[1] = rdData[7];
			btbData[2] = rdData[0];
			btbData[3] = rdData[1];
			btbData[4] = rdData[2];
			btbData[5] = rdData[3];
			btbData[6] = rdData[4];
			btbData[7] = rdData[5];
			/* for (i = 0; i < BTB_WIDTH-6; i = i + 1) */
			/* begin : btbtag6a */
			/* 	btbData[i]  = rdData[i+6]; */
			/* end */

			/* for (i = BTB_WIDTH-6; i < BTB_WIDTH; i = i + 1) */
			/* begin : btbtag6b */
			/* 	btbData[i]  = rdData[i-(BTB_WIDTH-6)]; */
			/* end */
		end

		3'h7:
		begin
			btbData[0] = rdData[7];
			btbData[1] = rdData[0];
			btbData[2] = rdData[1];
			btbData[3] = rdData[2];
			btbData[4] = rdData[3];
			btbData[5] = rdData[4];
			btbData[6] = rdData[5];
			btbData[7] = rdData[6];
			/* for (i = 0; i < BTB_WIDTH-7; i = i + 1) */
			/* begin : btbtag7a */
			/* 	btbData[i]  = rdData[i+7]; */
			/* end */

			/* for (i = BTB_WIDTH-7; i < BTB_WIDTH; i = i + 1) */
			/* begin : btbtag7b */
			/* 	btbData[i]  = rdData[i-(BTB_WIDTH-7)]; */
			/* end */
		end
`endif

	endcase
end


// LANE: Per lane logic
/* Check for BTB Hit and create the BTB Packets */
always_comb
begin:BTB_HIT
	reg                           hit [0:`FETCH_WIDTH-1];
	reg                           extraHit [0:`FETCH_WIDTH-1];
	int i;

	for (i = 0; i < `FETCH_WIDTH; i = i + 1)
	begin
    `ifdef DYNAMIC_CONFIG
  		hit[i]                    = ((instTag[i] == btbData[i].tag) & fetchLaneActive_i[i]) ? 1'h1 : 1'h0;
    `else
  		hit[i]                    = (instTag[i] == btbData[i].tag) ? 1'h1 : 1'h0;
    `endif

		btbPacket_o[i].takenPC    = btbData[i].takenPC;
		btbPacket_o[i].ctrlType   = btbData[i].ctrlType;
		btbPacket_o[i].hit        = btbData[i].valid & hit[i];
	end
end


/* Update the BTB if the prediction made by BTB was wrong or
 * if BTB never saw this Control Instruction PC in past. The update comes
 * from Ctrl Queue in the program order. */

assign wrData.tag       = updatePC_i[`SIZE_PC-1:`SIZE_PC-SIZE_TAG];
assign wrData.takenPC   = updateNPC_i;
assign wrData.ctrlType  = updateBrType_i;
assign wrData.valid     = 1'h1;

always_comb
begin
	int i;
	reg [`FETCH_WIDTH_LOG-1:0]  updateOffset;

  `ifdef DYNAMIC_CONFIG
    wrAddr           = updatePC_i[`SIZE_BTB_LOG+`SIZE_INST_BYTE_OFFSET-1:`FETCH_WIDTH_LOG+`SIZE_INST_BYTE_OFFSET];
	  updateOffset     = updatePC_i[`FETCH_WIDTH_LOG+`SIZE_INST_BYTE_OFFSET-1:`SIZE_INST_BYTE_OFFSET];
    casez(fetchLaneActive_i[2])
      1'b0:
      begin
        wrAddr  = {wrAddr,updateOffset[1]};
        updateOffset = updateOffset & 2'b01;
      end
      default:
      begin
      end
    endcase
  `else
    wrAddr           = updatePC_i[`SIZE_BTB_LOG+`SIZE_INST_BYTE_OFFSET-1:`FETCH_WIDTH_LOG+`SIZE_INST_BYTE_OFFSET];
	updateOffset     = updatePC_i[`FETCH_WIDTH_LOG+`SIZE_INST_BYTE_OFFSET-1:`SIZE_INST_BYTE_OFFSET];
  `endif

	for (i = 0; i < BTB_WIDTH; i = i + 1)
	begin
		we[i] = updateEn_i && (updateOffset == i);
	end
end

endmodule
