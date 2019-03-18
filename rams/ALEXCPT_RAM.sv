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

module ALEXCPT_RAM #(

	/* Parameters */
  parameter RPORT = `COMMIT_WIDTH,
  parameter WPORT = 2,
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

	input  [INDEX-1:0]                addr1wr_i,
	input  [WIDTH-1:0]                data1wr_i,
	input                             we1_i,

`ifdef DYNAMIC_CONFIG  
  input  [`COMMIT_WIDTH-1:0]        commitLaneActive_i,
  input  [`NUM_PARTS_AL-1:0]        alPartitionActive_i,
  output                            alVioReady_o,
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

  		if (we1_i)
  		begin
  			ram[addr1wr_i] <= data1wr_i;
  		end
  	end
  end

//`else
//
//  wire                                  we;
//  wire                    [INDEX-1:0]   addrWr;
//  wire                    [WIDTH-1:0]   dataWr;
//
//  wire [`COMMIT_WIDTH-1:0][INDEX-1:0]     addr;
//  wire [`COMMIT_WIDTH-1:0][WIDTH-1:0]     rdData;
//
//  wire                                 writePortGated;
//  wire [`COMMIT_WIDTH-1:0]             readPortGated;
//  wire [`NUM_PARTS_AL-1:0]             partitionGated;
//
//  assign writePortGated = 1'b0;
//  assign readPortGated  = ~commitLaneActive_i;
//  assign partitionGated = ~alPartitionActive_i;
//
//
//  assign we = we0_i;
//  assign addrWr = addr0wr_i;
//  assign dataWr = data0wr_i;
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
//    .NUM_WR_PORTS(1),
//    .NUM_RD_PORTS(`COMMIT_WIDTH),
//    .WR_PORTS_LOG(1),
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
//    .ramReady_o(alVioReady_o)
//  );
//
//
//
//`endif //DYNAMIC_CONFIG

endmodule

