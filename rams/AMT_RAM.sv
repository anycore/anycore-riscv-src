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

module AMT_RAM #(

/* Parameters */
  parameter RPORT = `COMMIT_WIDTH,
  parameter WPORT = `COMMIT_WIDTH,
	parameter DEPTH = 16,
	parameter INDEX = 4,
	parameter WIDTH = 8,
	parameter N_PACKETS  = 8
	) (

	input      [INDEX-1:0]       repairAddr_i [0:N_PACKETS-1],
	output reg [WIDTH-1:0]       repairData_o [0:N_PACKETS-1],

`ifdef DYNAMIC_CONFIG  
  // Used to MUX read ports between normal and repair packet reads
  input                        repairFlag_i,
`endif 

	input      [INDEX-1:0]       addr0_i,
	output     [WIDTH-1:0]       data0_o,
                               
`ifdef COMMIT_TWO_WIDE
	input      [INDEX-1:0]       addr1_i,
	output     [WIDTH-1:0]       data1_o,
`endif
                               
`ifdef COMMIT_THREE_WIDE
	input      [INDEX-1:0]       addr2_i,
	output     [WIDTH-1:0]       data2_o,
`endif  
                               
`ifdef COMMIT_FOUR_WIDE
	input      [INDEX-1:0]       addr3_i,
	output     [WIDTH-1:0]       data3_o,
`endif
                               
	input      [INDEX-1:0]       addr0wr_i,
	input      [WIDTH-1:0]       data0wr_i,
	input                        we0_i,

`ifdef COMMIT_TWO_WIDE
	input      [INDEX-1:0]       addr1wr_i,
	input      [WIDTH-1:0]       data1wr_i,
	input                        we1_i,
`endif

`ifdef COMMIT_THREE_WIDE
	input      [INDEX-1:0]       addr2wr_i,
	input      [WIDTH-1:0]       data2wr_i,
	input                        we2_i,
`endif  

`ifdef COMMIT_FOUR_WIDE
	input      [INDEX-1:0]       addr3wr_i,
	input      [WIDTH-1:0]       data3wr_i,
	input                        we3_i,
`endif

`ifdef DYNAMIC_CONFIG
  input [`COMMIT_WIDTH-1:0]    commitLaneActive_i,
  output                       amtReady_o,
`endif

`ifdef AMT_DEBUG_PORT
	input  [`SIZE_RMT_LOG-1:0]     debugAMTAddr_i,
	output [`SIZE_PHYSICAL_LOG-1:0]debugAMTRdData_o,
`endif

	input                        clk,
	input                        reset
);


//`ifndef DYNAMIC_CONFIG

`ifdef AMT_RAM_COMPILED
//synopsys translate_off
`endif

  reg  [WIDTH-1:0]               ram [DEPTH-1:0];
  
  
  /* Read operation */
  assign data0_o               = ram[addr0_i];
  `ifdef COMMIT_TWO_WIDE
  assign data1_o               = ram[addr1_i];
  `endif
  `ifdef COMMIT_THREE_WIDE
  assign data2_o               = ram[addr2_i];
  `endif
  `ifdef COMMIT_FOUR_WIDE
  assign data3_o               = ram[addr3_i];
  `endif
  
  always_comb
  begin
  	int i;
  	for (i = 0; i < N_PACKETS; i++)
  	begin
  		repairData_o[i] = ram[repairAddr_i[i]];
  	end
  end
  
  
  /* Write operation */
  always @(posedge clk)
  begin
  	int i;
  
  	if (reset)
  	begin
  		for (i = 0; i < DEPTH; i++)
  		begin
  			ram[i] <= i;
  		end
  	end
  
  	else
  	begin
  		if (we0_i)
  		begin
  			ram[addr0wr_i] <= data0wr_i;
  		end
  
  `ifdef COMMIT_TWO_WIDE
  		if (we1_i)
  		begin
  			ram[addr1wr_i] <= data1wr_i;
  		end
  `endif
  
  `ifdef COMMIT_THREE_WIDE
  		if (we2_i)
  		begin
  			ram[addr2wr_i] <= data2wr_i;
  		end
  `endif
  
  `ifdef COMMIT_FOUR_WIDE
  		if (we3_i)
  		begin
  			ram[addr3wr_i] <= data3wr_i;
  		end
  `endif
  	end
  end

`ifdef AMT_RAM_COMPILED
//synopsys translate_on
`endif



endmodule


