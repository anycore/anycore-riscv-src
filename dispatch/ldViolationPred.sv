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


/*******************************************************************************
 For maximum performance, an out-of-order processor must issue load instructions
 as early as possible, while avoiding memory-order violations with prior store
 instructions that write to the same memory location.

 Load Violation Predictor: During instruction renaming it is hard to identify
 dependence between memory instructions because their addresses are unknown. To
 achieve higher performance loads speculatively execute ignoring prior unresolved
 stores. If a load frequently causes memory-order violation then it is predicted
 to execute conservatively.

 Note: Current implementation of predictor is based on simple direct-map table
 but it can be augumented for more complicated structures.

 Implementation:
 1. Predictor table and predictor table valid array are indexed by PCs of
    load instructions that are currently being dispatched.

 2. Predictor table contains tags (upper bits of PC), and in case of tag match
    the load instruction is predicted to execute consevatively.

 3. On a load violation the predictor table is updated with the load PC
    (broadcasted from ActiveList).

 4. Predictor table is periodically flushed to avoid false predictions.
*******************************************************************************/

/*******************************************************************************
 Inputs:
 1. clk: processor clock
 2. reset: processor reset signal
 3. loadViolation_i: signal broadcasted by ActiveList on the occurance of a
    load violation
 4. recoverFlag_i: signal broadcasted by ActiveList on the occurance of a
    bad-event (eg. branch-misprediction, load-violation)
 5. recoverPC_i: PC of instruction that caused bad-event
 6. dispatchLoad_i: each bit identifies if a dispatched instruction is a load

 Outputs:
 1. predLoadVio_o: load-violation prediction for each dispatched
    load instruction
*******************************************************************************/

`timescale 1ns/100ps


module LoadViolationPred (

	input                                 clk,
	input                                 reset,

	input                                 loadViolation_i,
	input                                 recoverFlag_i,
	input  [`SIZE_PC-1:0]                 recoverPC_i,

	input  [`SIZE_PC-1:0]                 pc_i [0:`DISPATCH_WIDTH-1],

	input                                 isLoad_i[0:`DISPATCH_WIDTH-1],

	output reg [`DISPATCH_WIDTH-1:0]      predLoadVio_o
	);


localparam SIZE_TAG = `SIZE_PC-`SIZE_LD_VIOLATION_PRED_LOG-`SIZE_INST_BYTE_OFFSET;

// Declare wires and regs for combinational logic.
reg  [`SIZE_LD_VIOLATION_PRED_LOG-1:0] predAddr  [0:`DISPATCH_WIDTH-1];

wire                                   predValid [0:`DISPATCH_WIDTH-1];
wire [SIZE_TAG-1:0]                    predTag   [0:`DISPATCH_WIDTH-1];
reg  [SIZE_TAG-1:0]                    instTag   [0:`DISPATCH_WIDTH-1];


// Extract index bits for load violation predictor from each PC.
always_comb
begin
	int i;
	for (i = 0; i < `DISPATCH_WIDTH; i++)
	begin
		predAddr[i] = pc_i[i][`SIZE_LD_VIOLATION_PRED_LOG+`SIZE_INST_BYTE_OFFSET-1:`SIZE_INST_BYTE_OFFSET];
		instTag[i]  = pc_i[i][`SIZE_PC-1:`SIZE_LD_VIOLATION_PRED_LOG+`SIZE_INST_BYTE_OFFSET];
	end
end


// Create the prediction
always_comb
begin
	int i;
	for (i = 0; i < `DISPATCH_WIDTH; i++)
	begin
		predLoadVio_o[i] = predValid[i] ? (predTag[i] == instTag[i]) & isLoad_i[i] : 1'b0;
	end
end


// Update signals for load violation predictor
wire [`SIZE_LD_VIOLATION_PRED_LOG-1:0] predAddr0wr;
wire [SIZE_TAG-1:0]                    predTag0wr;
wire                                   predWe0;

assign predAddr0wr = recoverPC_i[`SIZE_LD_VIOLATION_PRED_LOG+`SIZE_INST_BYTE_OFFSET-1:`SIZE_INST_BYTE_OFFSET];
assign predTag0wr  = recoverPC_i[`SIZE_PC-1:`SIZE_LD_VIOLATION_PRED_LOG+`SIZE_INST_BYTE_OFFSET];
assign predWe0     = loadViolation_i & recoverFlag_i;

reg [13:0] flushCounter;
always_ff @(posedge clk or posedge reset)
begin
  if(reset)
    flushCounter <= 0;
  else
    flushCounter <= flushCounter + 1'b1;
end

wire flush;

`ifdef LDVIO_PRED_PERIODIC_FLUSH
  assign flush = &flushCounter;
`else
  assign flush = 1'b0;
`endif

LDVIO_RAM #(
  .RPORT       (`DISPATCH_WIDTH),
  .WPORT       (1),
	.DEPTH       (`SIZE_LD_VIOLATION_PRED),
	.INDEX       (`SIZE_LD_VIOLATION_PRED_LOG),
	.WIDTH       (SIZE_TAG)
	)

	ldViolatePredictor (
		.clk       (clk),
		//.reset     (reset|flush),

		.addr0_i   (predAddr[0]),
		.data0_o   (predTag[0]),

`ifdef DISPATCH_TWO_WIDE
		.addr1_i   (predAddr[1]),
		.data1_o   (predTag[1]),
`endif

`ifdef DISPATCH_THREE_WIDE
		.addr2_i   (predAddr[2]),
		.data2_o   (predTag[2]),
`endif

`ifdef DISPATCH_FOUR_WIDE
		.addr3_i   (predAddr[3]),
		.data3_o   (predTag[3]),
`endif

`ifdef DISPATCH_FIVE_WIDE
		.addr4_i   (predAddr[4]),
		.data4_o   (predTag[4]),
`endif

`ifdef DISPATCH_SIX_WIDE
		.addr5_i   (predAddr[5]),
		.data5_o   (predTag[5]),
`endif

`ifdef DISPATCH_SEVEN_WIDE
		.addr6_i   (predAddr[6]),
		.data6_o   (predTag[6]),
`endif

`ifdef DISPATCH_EIGHT_WIDE
		.addr7_i   (predAddr[7]),
		.data7_o   (predTag[7]),
`endif

		.addr0wr_i (predAddr0wr),
		.data0wr_i (predTag0wr),
		.we0_i     (predWe0)
	);

LDVIO_VLD_RAM #(
  .RPORT       (`DISPATCH_WIDTH),
  .WPORT       (1),
	.DEPTH       (`SIZE_LD_VIOLATION_PRED),
	.INDEX       (`SIZE_LD_VIOLATION_PRED_LOG),
	.WIDTH       (1)
	)
	ldViolatePredictorValid (
		.clk       (clk),
		.reset     (reset|flush),

		.addr0_i   (predAddr[0]),
		.data0_o   (predValid[0]),

`ifdef DISPATCH_TWO_WIDE
		.addr1_i   (predAddr[1]),
		.data1_o   (predValid[1]),
`endif

`ifdef DISPATCH_THREE_WIDE
		.addr2_i   (predAddr[2]),
		.data2_o   (predValid[2]),
`endif

`ifdef DISPATCH_FOUR_WIDE
		.addr3_i   (predAddr[3]),
		.data3_o   (predValid[3]),
`endif

`ifdef DISPATCH_FIVE_WIDE
		.addr4_i   (predAddr[4]),
		.data4_o   (predValid[4]),
`endif

`ifdef DISPATCH_SIX_WIDE
		.addr5_i   (predAddr[5]),
		.data5_o   (predValid[5]),
`endif

`ifdef DISPATCH_SEVEN_WIDE
		.addr6_i   (predAddr[6]),
		.data6_o   (predValid[6]),
`endif

`ifdef DISPATCH_EIGHT_WIDE
		.addr7_i   (predAddr[7]),
		.data7_o   (predValid[7]),
`endif

		.addr0wr_i (predAddr0wr),
		.data0wr_i (loadViolation_i),
		.we0_i     (predWe0)
	);

endmodule
