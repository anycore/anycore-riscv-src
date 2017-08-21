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

module LDQ_RAM #(
	/* Parameters */
  parameter RPORT = 1,
  parameter WPORT = 1,
	parameter DEPTH = 16,
	parameter INDEX = 4,
	parameter WIDTH = 8
) (

	input  [INDEX-1:0]       addr0_i,
	output [WIDTH-1:0]       data0_o,
	                         
	input  [INDEX-1:0]       addr1_i,
	output [WIDTH-1:0]       data1_o,
	                         
                           
	input  [INDEX-1:0]       addr0wr_i,
	input  [WIDTH-1:0]       data0wr_i,
	input                    we0_i,
                           
	//input  [INDEX-1:0]       addr1wr_i,
	//input  [WIDTH-1:0]       data1wr_i,
	//input                    we1_i,
                           

//`ifdef DYNAMIC_CONFIG
//  input [`STRUCT_PARTS_LSQ-1:0]    lsqPartitionActive_i,
//  output                       stqRamReady_o,
//`endif  

	//input                    reset,
	input                    clk
);

//`ifndef DYNAMIC_CONFIG

`ifdef LDQ_RAM_COMPILED
//synopsys translate_off
`endif
  
  reg [WIDTH-1:0]            ram [DEPTH-1:0];
  
  
  /* Read operation */
  assign data0_o           = ram[addr0_i];
  
  assign data1_o           = ram[addr1_i];
  
  
  /* Write operation */
  always_ff @(posedge clk)
  begin
  	int i;
  
  	//if (reset)
  	//begin
  	//	for (i = 0; i < DEPTH; i++)
  	//	begin
  	//		ram[i]         <= {WIDTH{1'b0}};
  	//	end
  	//end
    // 
  	//else
  	//begin
  		if (we0_i)
  		begin
  			ram[addr0wr_i] <= data0wr_i;
  		end
  
  		//if (we1_i)
  		//begin
  		//	ram[addr1wr_i] <= data1wr_i;
  		//end
  
  	//end
  end

`ifdef LDQ_RAM_COMPILED
//synopsys translate_on
`endif

//`else //DYNAMIC_CONFIG
//
//  //wire [1:0]                we;
//  //wire [1:0][INDEX-1:0]     addrWr;
//  //wire [1:0][WIDTH-1:0]     dataWr;
//  wire [0:0]                we;
//  wire [0:0][INDEX-1:0]     addrWr;
//  wire [0:0][WIDTH-1:0]     dataWr;
//
//  wire [1:0][INDEX-1:0]     addr;
//  wire [1:0][WIDTH-1:0]     rdData;
//
//  //wire [1:0]                writePortGated;
//  wire [0:0]                writePortGated;
//  wire [1:0]                readPortGated;
//  wire [`STRUCT_PARTS_LSQ-1:0]  partitionGated;
//
//  assign writePortGated   = 2'b00;
//  assign readPortGated    = 2'b00;
//  assign partitionGated   = ~lsqPartitionActive_i;
//
//
//    assign we[0] = we0_i;
//    assign addrWr[0] = addr0wr_i;
//    assign dataWr[0] = data0wr_i;
//
//    //assign we[1] = we1_i;
//    //assign addrWr[1] = addr1wr_i;
//    //assign dataWr[1] = data1wr_i;
//  
//
//  RAM_CONFIGURABLE #(
//  	/* Parameters */
//  	.DEPTH(DEPTH),
//  	.INDEX(INDEX),
//  	.WIDTH(WIDTH),
//    .NUM_WR_PORTS(1),
//    .NUM_RD_PORTS(2),
//    .WR_PORTS_LOG(1),
//    .RESET_VAL(`RAM_RESET_ZERO),
//    .SEQ_START(0),   
//    .NUM_PARTS(`STRUCT_PARTS_LSQ),
//    .NUM_PARTS_LOG(`STRUCT_PARTS_LSQ_LOG),
//    .PARENT_MODULE("LDX_PATH")
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
//  	.reset(1'b0),
//    .ramReady_o(stqRamReady_o)
//  );
//
//
//  /* Read operation */
//  assign addr[0]     = addr0_i;
//  assign data0_o     = rdData[0];
//  
//  assign addr[1]     = addr1_i;
//  assign data1_o     = rdData[1];
//  
//
//`endif //DYNAMIC_CONFIG


endmodule


