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

module ALREADY_RAM #(

	/* Parameters */
  parameter RPORT = `COMMIT_WIDTH,
  parameter WPORT = (`ISSUE_WIDTH+`COMMIT_WIDTH),
	parameter DEPTH = 16,
	parameter INDEX = 4,
	parameter WIDTH = 8
	) (

	input  [INDEX-1:0]                addr0_i,
	output [WIDTH-1:0]                data0_o,

`ifdef COMMIT_TWO_WIDE
	input  [INDEX-1:0]                addr1_i,
	output [WIDTH-1:0]                data1_o,
`endif

`ifdef COMMIT_THREE_WIDE
	input  [INDEX-1:0]                addr2_i,
	output [WIDTH-1:0]                data2_o,
`endif

`ifdef COMMIT_FOUR_WIDE
	input  [INDEX-1:0]                addr3_i,
	output [WIDTH-1:0]                data3_o,
`endif


	input  [INDEX-1:0]                addr0wr_i,
	input  [WIDTH-1:0]                data0wr_i,
	input                             we0_i,

`ifdef ISSUE_TWO_WIDE
	input  [INDEX-1:0]                addr1wr_i,
	input  [WIDTH-1:0]                data1wr_i,
	input                             we1_i,
`endif

`ifdef ISSUE_THREE_WIDE
	input  [INDEX-1:0]                addr2wr_i,
	input  [WIDTH-1:0]                data2wr_i,
	input                             we2_i,
`endif

`ifdef ISSUE_FOUR_WIDE
	input  [INDEX-1:0]                addr3wr_i,
	input  [WIDTH-1:0]                data3wr_i,
	input                             we3_i,
`endif

`ifdef ISSUE_FIVE_WIDE
	input  [INDEX-1:0]                addr4wr_i,
	input  [WIDTH-1:0]                data4wr_i,
	input                             we4_i,
`endif

`ifdef ISSUE_SIX_WIDE
	input  [INDEX-1:0]                addr5wr_i,
	input  [WIDTH-1:0]                data5wr_i,
	input                             we5_i,
`endif

`ifdef ISSUE_SEVEN_WIDE
	input  [INDEX-1:0]                addr6wr_i,
	input  [WIDTH-1:0]                data6wr_i,
	input                             we6_i,
`endif

`ifdef ISSUE_EIGHT_WIDE
	input  [INDEX-1:0]                addr7wr_i,
	input  [WIDTH-1:0]                data7wr_i,
	input                             we7_i,
`endif

	input  [INDEX-1:0]                addr10wr_i,
	input  [WIDTH-1:0]                data10wr_i,
	input                             we10_i,

`ifdef COMMIT_TWO_WIDE
	input  [INDEX-1:0]                addr11wr_i,
	input  [WIDTH-1:0]                data11wr_i,
	input                             we11_i,
`endif

`ifdef COMMIT_THREE_WIDE
	input  [INDEX-1:0]                addr12wr_i,
	input  [WIDTH-1:0]                data12wr_i,
	input                             we12_i,
`endif

`ifdef COMMIT_FOUR_WIDE
	input  [INDEX-1:0]                addr13wr_i,
	input  [WIDTH-1:0]                data13wr_i,
	input                             we13_i,
`endif

`ifdef DYNAMIC_CONFIG
  input  [`ISSUE_WIDTH-1:0]         issueLaneActive_i,
  input  [`COMMIT_WIDTH-1:0]        commitLaneActive_i,
  input  [`NUM_PARTS_AL-1:0]        alPartitionActive_i,
  output                            alReadyBitReady_o,
`endif  

	input                             clk,
	input                             reset
);


//`ifndef DYNAMIC_CONFIG

  reg  [WIDTH-1:0]                    ram [DEPTH-1:0];
  
  
  /* Read operation */
  assign data0_o                    = ram[addr0_i];
  
  `ifdef COMMIT_TWO_WIDE
  assign data1_o                    = ram[addr1_i];
  `endif
  
  `ifdef COMMIT_THREE_WIDE
  assign data2_o                    = ram[addr2_i];
  `endif
  
  `ifdef COMMIT_FOUR_WIDE
  assign data3_o                    = ram[addr3_i];
  `endif

  `ifdef VERILATOR
  initial
  begin
      int i;
      for (i = 0; i < DEPTH; i++)
      begin
          ram[i]         <= 0;
      end
  end
  `endif

  /* Write operation */
  always_ff @(posedge clk)
  begin
  	int i;
  
  	if (reset)
  	begin
                `ifndef VERILATOR
  		for (i = 0; i < DEPTH; i++)
  		begin
  			ram[i]         <= 0;
  		end
                `endif
  	end
  
  	else
  	begin
  		if (we0_i)
  		begin
  			ram[addr0wr_i] <= data0wr_i;
  		end
  
  `ifdef ISSUE_TWO_WIDE
  		if (we1_i)
  		begin
  			ram[addr1wr_i] <= data1wr_i;
  		end
  `endif
  
  `ifdef ISSUE_THREE_WIDE
  		if (we2_i)
  		begin
  			ram[addr2wr_i] <= data2wr_i;
  		end
  `endif
  
  `ifdef ISSUE_FOUR_WIDE
  		if (we3_i)
  		begin
  			ram[addr3wr_i] <= data3wr_i;
  		end
  `endif
  
  `ifdef ISSUE_FIVE_WIDE
  		if (we4_i)
  		begin
  			ram[addr4wr_i] <= data4wr_i;
  		end
  `endif
  
  `ifdef ISSUE_SIX_WIDE
  		if (we5_i)
  		begin
  			ram[addr5wr_i] <= data5wr_i;
  		end
  `endif
  
  `ifdef ISSUE_SEVEN_WIDE
  		if (we6_i)
  		begin
  			ram[addr6wr_i] <= data6wr_i;
  		end
  `endif
  
  `ifdef ISSUE_EIGHT_WIDE
  		if (we7_i)
  		begin
  			ram[addr7wr_i] <= data7wr_i;
  		end
  `endif
  
  
  		if (we10_i)
  		begin
  			ram[addr10wr_i] <= data10wr_i;
  		end
  
  `ifdef COMMIT_TWO_WIDE
  		if (we11_i)
  		begin
  			ram[addr11wr_i] <= data11wr_i;
  		end
  `endif
  
  `ifdef COMMIT_THREE_WIDE
  		if (we12_i)
  		begin
  			ram[addr12wr_i] <= data12wr_i;
  		end
  `endif
  
  `ifdef COMMIT_FOUR_WIDE
  		if (we13_i)
  		begin
  			ram[addr13wr_i] <= data13wr_i;
  		end
  `endif
  	end
  end

//`else //DYNAMIC_CONFIG
//
//  wire [`ISSUE_WIDTH+`COMMIT_WIDTH-1:0]              we;
//  wire [`ISSUE_WIDTH+`COMMIT_WIDTH-1:0][INDEX-1:0]   addrWr;
//  wire [`ISSUE_WIDTH+`COMMIT_WIDTH-1:0][WIDTH-1:0]   dataWr;
//
//  wire [`COMMIT_WIDTH-1:0][INDEX-1:0]     addr;
//  wire [`COMMIT_WIDTH-1:0][WIDTH-1:0]     rdData;
//
//  wire [`ISSUE_WIDTH+`COMMIT_WIDTH-1:0]              writePortGated;
//  wire [`COMMIT_WIDTH-1:0]             readPortGated;
//  wire [`NUM_PARTS_AL-1:0]             partitionGated;
//
//  assign writePortGated = ~{commitLaneActive_i,issueLaneActive_i};
//  assign readPortGated  = ~commitLaneActive_i;
//  assign partitionGated = ~alPartitionActive_i;
//
//
//    assign we[0] = we0_i;
//    assign addrWr[0] = addr0wr_i;
//    assign dataWr[0] = data0wr_i;
//
//  `ifdef ISSUE_TWO_WIDE
//    assign we[1] = we1_i;
//    assign addrWr[1] = addr1wr_i;
//    assign dataWr[1] = data1wr_i;
//  `endif
//  
//  `ifdef ISSUE_THREE_WIDE
//    assign we[2] = we2_i;
//    assign addrWr[2] = addr2wr_i;
//    assign dataWr[2] = data2wr_i;
//  `endif
//  
//  `ifdef ISSUE_FOUR_WIDE
//    assign we[3] = we3_i;
//    assign addrWr[3] = addr3wr_i;
//    assign dataWr[3] = data3wr_i;
//  `endif
//  
//  `ifdef ISSUE_FIVE_WIDE
//    assign we[4] = we4_i;
//    assign addrWr[4] = addr4wr_i;
//    assign dataWr[4] = data4wr_i;
//  `endif
//  
//
//    assign we[5] = we10_i;
//    assign addrWr[5] = addr10wr_i;
//    assign dataWr[5] = data10wr_i;
//  
//  `ifdef COMMIT_TWO_WIDE
//    assign we[6] = we11_i;
//    assign addrWr[6] = addr11wr_i;
//    assign dataWr[6] = data11wr_i;
//  `endif
//  
//  `ifdef COMMIT_THREE_WIDE
//    assign we[7] = we12_i;
//    assign addrWr[7] = addr12wr_i;
//    assign dataWr[7] = data12wr_i;
//  `endif
//  
//  `ifdef COMMIT_FOUR_WIDE
//    assign we[8] = we13_i;
//    assign addrWr[8] = addr13wr_i;
//    assign dataWr[8] = data13wr_i;
//  `endif
//
//
//  /* Read operation */
//  assign addr[0]     = addr0_i;
//  assign data0_o     = rdData[0];
//  
//  `ifdef COMMIT_TWO_WIDE
//  assign addr[1]     = addr1_i;
//  assign data1_o     = rdData[1];
//  `endif
//  
//  `ifdef COMMIT_THREE_WIDE
//  assign addr[2]     = addr2_i;
//  assign data2_o     = rdData[2];
//  `endif
//  
//  `ifdef COMMIT_FOUR_WIDE
//  assign addr[3]     = addr3_i;
//  assign data3_o     = rdData[3];
//  `endif
//  
//
//
//
//  //TODO: Write the reset state machine
//
//
//  RAM_CONFIGURABLE #(
//  	/* Parameters */
//  	.DEPTH(DEPTH),
//  	.INDEX(INDEX),
//  	.WIDTH(WIDTH),
//    .NUM_WR_PORTS(`ISSUE_WIDTH+`COMMIT_WIDTH),
//    .NUM_RD_PORTS(`COMMIT_WIDTH),
//    .WR_PORTS_LOG(`ISSUE_WIDTH_LOG+1),
//    .NUM_PARTS(`NUM_PARTS_AL),
//    .NUM_PARTS_LOG(`NUM_PARTS_AL_LOG),
//    .RESET_VAL(`RAM_RESET_ZERO),
//    .SEQ_START(0),   // Reset the RMT rams to contain first LOG_REG sequential mappings
//    .PARENT_MODULE("ALVIO") // Used for debug prints inside
//  ) ram_configurable
//  (
//  
//    .writePortGated_i(writePortGated),
//    .readPortGated_i(readPortGated),
//    .partitionGated_i(partitionGated),
//  
//  	.addr_i(addr),
//  	.data_o(rdData),
//  
//  	.addrWr_i(addrWr),
//  	.dataWr_i(dataWr),
//  
//  	.wrEn_i(we),
//  
//  	.clk(clk),
//  	.reset(reset),
//    .ramReady_o(alReadyBitReady_o)
//  );
//
//
//
//`endif //DYNAMIC_CONFIG

endmodule

