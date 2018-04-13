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

module BranchPrediction(
	input                            clk,
	input                            reset,
	input                            resetRams_i,

`ifdef DYNAMIC_CONFIG
  input [`FETCH_WIDTH-1:0]         fetchLaneActive_i,
`endif

	input  [`SIZE_PC-1:0]            PC_i,

	input  [`SIZE_PC-1:0]            updatePC_i,
	input                            updateDir_i,
	input  [1:0]                     updateCounter_i,
	input                            updateEn_i,

	output reg [`FETCH_WIDTH-1:0]    predDir_o,
	output reg [1:0]                 predCounter_o [0:`FETCH_WIDTH-1],
  output                           bpRamReady_o
	);


/* BP width must be a power of two */
localparam BP_WIDTH = 1<<`FETCH_WIDTH_LOG;
localparam INDEX    = `SIZE_CNT_TBL_LOG-`FETCH_WIDTH_LOG;


reg  [INDEX-1:0]                                    rdAddr [0:BP_WIDTH-1];
wire [1:0]                                          rdData [0:BP_WIDTH-1];

reg  [INDEX-1:0]                                    wrAddr;
reg  [1:0]                                          wrData;
reg                                                 wrEn   [0:BP_WIDTH-1];

`ifdef DYNAMIC_CONFIG
  wire [BP_WIDTH-1:0] clkGated;
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
localparam BIST_SIZE_DATA   = 2;
localparam BIST_NUM_ENTRIES = `SIZE_CNT_TABLE/BP_WIDTH;
localparam BIST_RESET_MODE  = 0; //0 -> Fixed value; 1 -> Sequential values
localparam BIST_RESET_VALUE = 2; // Initialize all entries to 2=weakly taken

localparam BIST_START = 0;
localparam BIST_RUN   = 1;
localparam BIST_DONE  = 2;

logic                       bistEn;
logic [1:0]                 bistState;
logic [1:0]                 bistNextState;
logic [BIST_SIZE_ADDR-1:0]  bistAddrWr;
logic [BIST_SIZE_ADDR-1:0]  bistNextAddrWr;
logic [BIST_SIZE_DATA-1:0]  bistDataWr;

//assign bistDataWr = (BIST_RESET_MODE == 0) ? BIST_RESET_VALUE : {{(BIST_SIZE_DATA-BIST_SIZE_ADDR){1'b0}},bistAddrWr};
assign bpRamReady_o = ~bistEn;

always_ff @(posedge clk or posedge resetRams_i)
begin
  if(resetRams_i)
  begin
    bistState       <= BIST_START;
    bistAddrWr      <= 0;
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

genvar g;
generate
for (g = 0; g < BP_WIDTH; g++)
begin:counter_gen

BP_RAM #(
  .RPORT      (1),
  .WPORT      (1),
	.DEPTH      (`SIZE_CNT_TABLE/BP_WIDTH),
	.INDEX      (INDEX),
	.WIDTH      (2)
)
	counterTable (

`ifdef DYNAMIC_CONFIG    
	.clk                      (clkGated[g]),
`else
	.clk                      (clk),
`endif
	.reset                    (reset),

	.addr0_i                  (rdAddr[g]),
	.data0_o                  (rdData[g]),

	.addr0wr_i                (bistEn ? bistAddrWr : wrAddr),
	.data0wr_i                (bistEn ? bistDataWr : wrData),
	.we0_i                    (bistEn ? 1'b1       : wrEn[g])
);

end
endgenerate


//initial
//begin
//  if(simulate.loggingOn)
//    $display("\n***** USING BIMODAL BRANCH PREDICTOR*****\n");
//end

reg  [INDEX-1:0]                                    instIndex     [0:BP_WIDTH-1];
reg  [`FETCH_WIDTH_LOG-1:0]                         instOffset    [0:BP_WIDTH-1];
reg  [1:0]                                          predCounter   [0:BP_WIDTH-1];

always_comb
begin
	int i;
	for (i = 0; i < BP_WIDTH; i++)
	begin
		{instIndex[i], instOffset[i]} = PC_i[`SIZE_PC-1:`SIZE_INST_BYTE_OFFSET] + i;

    // RBRC - Modify the index and offsets based on how many lanes are active
//    `ifdef DYNAMIC_CONFIG
//      casez({fetchLaneActive_i[4],fetchLaneActive_i[2]})
//        2'b01:
//        begin
//          instIndex[i]  = {instIndex[i],instOffset[i][2]};
//          instOffset[i] = instOffset[i] & 3'b011;
//        end
//        2'b00:
//        begin
//          instIndex[i]  = {instIndex[i],instOffset[i][2:1]};
//          instOffset[i] = instOffset[i] & 3'b001;
//        end
//        default:
//        begin
//        end
//      endcase
//    `endif
    `ifdef DYNAMIC_CONFIG
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
    `endif
	end
end


/* Rotate the addresses to the correct RAM */
always_comb
begin
	int i;

	/* TODO: Use coreGen to expand these loops */
	case ({{3-`FETCH_WIDTH_LOG{1'b0}},instOffset[0]})

		3'h0:
		begin
			/* 4-wide example:
			 * rdAddr[0] = pc[0];
			 * rdAddr[1] = pc[1];
			 * rdAddr[2] = pc[2];
			 * rdAddr[3] = pc[3]; */
			rdAddr[0] = instIndex[0];
			rdAddr[1] = instIndex[1];
`ifdef FETCH_THREE_WIDE
			rdAddr[2] = instIndex[2];
			rdAddr[3] = instIndex[3];
`endif

`ifdef FETCH_FIVE_WIDE
			rdAddr[4] = instIndex[4];
			rdAddr[5] = instIndex[5];
			rdAddr[6] = instIndex[6];
			rdAddr[7] = instIndex[7];
`endif
			/* for (i = 0; i < BP_WIDTH; i++) */
			/* begin */
			/* 	rdAddr[i] = instIndex[i]; */
			/* end */
		end

		3'h1:
		begin
			/* 4-wide example:
			 * rdAddr[0] = pc[3];
			 * rdAddr[1] = pc[0];
			 * rdAddr[2] = pc[1];
			 * rdAddr[3] = pc[2]; */
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
			/* for (i = 0; i < 1; i++) */
			/* begin */
			/* 	rdAddr[i] = instIndex[BP_WIDTH-i-1]; */
			/* end */

			/* for (i = 1; i < BP_WIDTH; i++) */
			/* begin */
			/* 	rdAddr[i] = instIndex[i-1]; */
			/* end */
		end

`ifdef FETCH_THREE_WIDE
		3'h2:
		begin
			/* 4-wide example:
			 * rdAddr[0] = pc[2];
			 * rdAddr[1] = pc[3];
			 * rdAddr[2] = pc[0];
			 * rdAddr[3] = pc[1]; */
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
			/* for (i = 0; i < 2; i++) */
			/* begin */
			/* 	rdAddr[i] = instIndex[BP_WIDTH-i-1]; */
			/* end */

			/* for (i = 2; i < BP_WIDTH; i++) */
			/* begin */
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
			/* for (i = 0; i < 3; i++) */
			/* begin */
			/* 	rdAddr[i] = instIndex[BP_WIDTH-i-1]; */
			/* end */

			/* for (i = 3; i < BP_WIDTH; i++) */
			/* begin */
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
			/* for (i = 0; i < 4; i++) */
			/* begin */
			/* 	rdAddr[i] = instIndex[BP_WIDTH-i-1]; */
			/* end */

			/* for (i = 4; i < BP_WIDTH; i++) */
			/* begin */
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
			/* for (i = 0; i < 5; i++) */
			/* begin */
			/* 	rdAddr[i] = instIndex[BP_WIDTH-i-1]; */
			/* end */

			/* for (i = 5; i < BP_WIDTH; i++) */
			/* begin */
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
			/* for (i = 0; i < 6; i++) */
			/* begin */
			/* 	rdAddr[i] = instIndex[BP_WIDTH-i-1]; */
			/* end */

			/* for (i = 6; i < BP_WIDTH; i++) */
			/* begin */
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
			/* for (i = 0; i < 7; i++) */
			/* begin */
			/* 	rdAddr[i] = instIndex[BP_WIDTH-i-1]; */
			/* end */

			/* for (i = 7; i < BP_WIDTH; i++) */
			/* begin */
			/* 	rdAddr[i] = instIndex[i-7]; */
			/* end */
		end
`endif

	endcase
end


/* Rotate the data from the RAM output to the correct order */
always_comb
begin
	int i;

	for (i = 0; i < BP_WIDTH; i++)
	begin
		predCounter[i]  = 0;
	end

	case ({{3-`FETCH_WIDTH_LOG{1'b0}},instOffset[0]}) // synopsys full_case

		3'h0:
		begin
			predCounter[0]  = rdData[0];
			predCounter[1]  = rdData[1];
`ifdef FETCH_THREE_WIDE
			predCounter[2]  = rdData[2];
			predCounter[3]  = rdData[3];
`endif

`ifdef FETCH_FIVE_WIDE
			predCounter[4]  = rdData[4];
			predCounter[5]  = rdData[5];
			predCounter[6]  = rdData[6];
			predCounter[7]  = rdData[7];
`endif
			/* for (i = 0; i < BP_WIDTH; i++) */
			/* begin */
			/* 	predCounter[i]  = rdData[i]; */
			/* end */
		end

		3'h1:
		begin
`ifndef FETCH_THREE_WIDE /* 1- or 2-wide */
			predCounter[0]  = rdData[1];
			predCounter[1]  = rdData[0];
`endif

`ifdef FETCH_THREE_WIDE
`ifndef FETCH_FIVE_WIDE /* 3- or 4-wide */
			predCounter[0]  = rdData[1];
    `ifdef DYNAMIC_CONFIG
			predCounter[1]  = fetchLaneActive_i[2] ? rdData[2] : rdData[0];
    `else
			predCounter[1]  = rdData[2];
    `endif
			predCounter[2]  = rdData[3];
			predCounter[3]  = rdData[0];
`endif
`endif

`ifdef FETCH_FIVE_WIDE /* 5+ wide */
    `ifdef DYNAMIC_CONFIG
			predCounter[0]  = rdData[1];
			predCounter[1]  = fetchLaneActive_i[2] ? rdData[2] : rdData[0];
			predCounter[2]  = rdData[3];
			predCounter[3]  = fetchLaneActive_i[4] ? rdData[4] : rdData[0];
			predCounter[4]  = rdData[5];
			predCounter[5]  = rdData[6];
			predCounter[6]  = rdData[7];
			predCounter[7]  = rdData[0];
    `else
			predCounter[0]  = rdData[1];
			predCounter[1]  = rdData[2];
			predCounter[2]  = rdData[3];
			predCounter[3]  = rdData[4];
			predCounter[4]  = rdData[5];
			predCounter[5]  = rdData[6];
			predCounter[6]  = rdData[7];
			predCounter[7]  = rdData[0];
    `endif
`endif
			/* for (i = 0; i < BP_WIDTH-1; i++) */
			/* begin */
			/* 	predCounter[i]  = rdData[i+1]; */
			/* end */

			/* for (i = BP_WIDTH-1; i < BP_WIDTH; i++) */
			/* begin */
			/* 	predCounter[i]  = rdData[i-(BP_WIDTH-1)]; */
			/* end */
		end

`ifdef FETCH_THREE_WIDE
		3'h2:
		begin
`ifndef FETCH_FIVE_WIDE /* 3- or 4-wide */
			predCounter[0]  = rdData[2];
			predCounter[1]  = rdData[3];
			predCounter[2]  = rdData[0];
			predCounter[3]  = rdData[1];
`endif

`ifdef FETCH_FIVE_WIDE /* 5+ wide */
    `ifdef DYNAMIC_CONFIG
			predCounter[0]  = rdData[2];
			predCounter[1]  = rdData[3];
			predCounter[2]  = fetchLaneActive_i[4] ? rdData[4] : rdData[0];
			predCounter[3]  = fetchLaneActive_i[4] ? rdData[5] : rdData[1];
			predCounter[4]  = rdData[6];
			predCounter[5]  = rdData[7];
			predCounter[6]  = rdData[0];
			predCounter[7]  = rdData[1];
    `else
			predCounter[0]  = rdData[2];
			predCounter[1]  = rdData[3];
			predCounter[2]  = rdData[4];
			predCounter[3]  = rdData[5];
			predCounter[4]  = rdData[6];
			predCounter[5]  = rdData[7];
			predCounter[6]  = rdData[0];
			predCounter[7]  = rdData[1];
    `endif
`endif
			/* for (i = 0; i < BP_WIDTH-2; i++) */
			/* begin */
			/* 	predCounter[i]  = rdData[i+2]; */
			/* end */

			/* for (i = BP_WIDTH-2; i < BP_WIDTH; i++) */
			/* begin */
			/* 	predCounter[i]  = rdData[i-(BP_WIDTH-2)]; */
			/* end */
		end

		3'h3:
		begin
`ifndef FETCH_FIVE_WIDE /* 3- or 4-wide */
			predCounter[0]  = rdData[3];
			predCounter[1]  = rdData[0];
			predCounter[2]  = rdData[1];
			predCounter[3]  = rdData[2];
`endif

`ifdef FETCH_FIVE_WIDE /* 5+ wide */
    `ifdef DYNAMIC_CONFIG
			predCounter[0]  = rdData[3];
			predCounter[1]  = fetchLaneActive_i[4] ? rdData[4] : rdData[0];
			predCounter[2]  = fetchLaneActive_i[4] ? rdData[5] : rdData[1];
			predCounter[3]  = fetchLaneActive_i[4] ? rdData[6] : rdData[2];
			predCounter[4]  = rdData[7];
      predCounter[5]  = rdData[0];
			predCounter[6]  = rdData[1];
			predCounter[7]  = rdData[2];
    `else
			predCounter[0]  = rdData[3];
			predCounter[1]  = rdData[4];
			predCounter[2]  = rdData[5];
			predCounter[3]  = rdData[6];
			predCounter[4]  = rdData[7];
			predCounter[5]  = rdData[0];
			predCounter[6]  = rdData[1];
			predCounter[7]  = rdData[2];
    `endif
`endif
			/* for (i = 0; i < BP_WIDTH-3; i++) */
			/* begin */
			/* 	predCounter[i]  = rdData[i+3]; */
			/* end */

			/* for (i = BP_WIDTH-3; i < BP_WIDTH; i++) */
			/* begin */
			/* 	predCounter[i]  = rdData[i-(BP_WIDTH-3)]; */
			/* end */
		end
`endif

`ifdef FETCH_FIVE_WIDE
		3'h4:
		begin
			predCounter[0]  = rdData[4];
			predCounter[1]  = rdData[5];
			predCounter[2]  = rdData[6];
			predCounter[3]  = rdData[7];
			predCounter[4]  = rdData[0];
			predCounter[5]  = rdData[1];
			predCounter[6]  = rdData[2];
			predCounter[7]  = rdData[3];
			/* for (i = 0; i < BP_WIDTH-4; i++) */
			/* begin */
			/* 	predCounter[i]  = rdData[i+4]; */
			/* end */

			/* for (i = BP_WIDTH-4; i < BP_WIDTH; i++) */
			/* begin */
			/* 	predCounter[i]  = rdData[i-(BP_WIDTH-4)]; */
			/* end */
		end

		3'h5:
		begin
			predCounter[0]  = rdData[5];
			predCounter[1]  = rdData[6];
			predCounter[2]  = rdData[7];
			predCounter[3]  = rdData[0];
			predCounter[4]  = rdData[1];
			predCounter[5]  = rdData[2];
			predCounter[6]  = rdData[3];
			predCounter[7]  = rdData[4];
			/* for (i = 0; i < BP_WIDTH-5; i++) */
			/* begin */
			/* 	predCounter[i]  = rdData[i+5]; */
			/* end */

			/* for (i = BP_WIDTH-5; i < BP_WIDTH; i++) */
			/* begin */
			/* 	predCounter[i]  = rdData[i-(BP_WIDTH-5)]; */
			/* end */
		end

		3'h6:
		begin
			predCounter[0]  = rdData[6];
			predCounter[1]  = rdData[7];
			predCounter[2]  = rdData[0];
			predCounter[3]  = rdData[1];
			predCounter[4]  = rdData[2];
			predCounter[5]  = rdData[3];
			predCounter[6]  = rdData[4];
			predCounter[7]  = rdData[5];
			/* for (i = 0; i < BP_WIDTH-6; i++) */
			/* begin */
			/* 	predCounter[i]  = rdData[i+6]; */
			/* end */

			/* for (i = BP_WIDTH-6; i < BP_WIDTH; i++) */
			/* begin */
			/* 	predCounter[i]  = rdData[i-(BP_WIDTH-6)]; */
			/* end */
		end

		3'h7:
		begin
			predCounter[0]  = rdData[7];
			predCounter[1]  = rdData[0];
			predCounter[2]  = rdData[1];
			predCounter[3]  = rdData[2];
			predCounter[4]  = rdData[3];
			predCounter[5]  = rdData[4];
			predCounter[6]  = rdData[5];
			predCounter[7]  = rdData[6];
			/* for (i = 0; i < BP_WIDTH-7; i++) */
			/* begin */
			/* 	predCounter[i]  = rdData[i+7]; */
			/* end */

			/* for (i = BP_WIDTH-7; i < BP_WIDTH; i++) */
			/* begin */
			/* 	predCounter[i]  = rdData[i-(BP_WIDTH-7)]; */
			/* end */
		end
`endif

	endcase
end


/* Make prediction based on the counter value */
reg  [`FETCH_WIDTH-1:0]                             predDir;

always_comb
begin
	int i;
	for (i = 0; i < `FETCH_WIDTH; i++)
	begin
		predDir[i] = (predCounter[i] > 2'b01) ? 1'b1 : 1'b0;
`ifndef GSHARE 
    predDir_o[i]     = predDir[i];
		predCounter_o[i] = predCounter[i];
`endif
	end
end

//assign predDir_o     = predDir;
/* assign predCounter_o = predCounter; */


/* Update the counter table from the CTI Queue */

always_comb
begin
	wrData           = updateDir_i ?

	                  ((updateCounter_i == 2'b11) ?
	                   updateCounter_i :
	                   updateCounter_i + 1'b1) :

	                 ((updateCounter_i == 2'b00) ?
	                   updateCounter_i :
	                   updateCounter_i - 1'b1);
end

always_comb
begin
	int i;
	reg [`FETCH_WIDTH_LOG-1:0]  updateOffset;

  wrAddr            =   updatePC_i[`SIZE_CNT_TBL_LOG+`SIZE_INST_BYTE_OFFSET-1:`FETCH_WIDTH_LOG+`SIZE_INST_BYTE_OFFSET];
	updateOffset      =   updatePC_i[`FETCH_WIDTH_LOG+`SIZE_INST_BYTE_OFFSET-1:`SIZE_INST_BYTE_OFFSET];

  // RBRC - Modify the index and offsets based on how many lanes are active
//  `ifdef DYNAMIC_CONFIG
//    casez({fetchLaneActive_i[4],fetchLaneActive_i[2]})
//      2'b01:
//      begin
//        wrAddr  = {wrAddr,updateOffset[2]};
//        updateOffset = updateOffset & 3'b011;
//      end
//      2'b00:
//      begin
//        wrAddr  = {wrAddr,updateOffset[2:1]};
//        updateOffset = updateOffset & 3'b001;
//      end
//      default:
//      begin
//      end
//    endcase
//  `endif

  `ifdef DYNAMIC_CONFIG
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
  `endif
	for (i = 0; i < BP_WIDTH; i++)
	begin
		wrEn[i] = updateEn_i && (updateOffset == i);
	end
end


endmodule

