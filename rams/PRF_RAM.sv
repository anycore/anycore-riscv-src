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

module PRF_RAM #(
	/* Parameters */
  parameter RPORT = (2*`ISSUE_WIDTH),
  parameter WPORT = `ISSUE_WIDTH,
	parameter DEPTH       = 16,
	parameter INDEX       = 4,
	parameter WIDTH       = 8
) (

	input  [INDEX-1:0]       addr0_i,
	output [WIDTH-1:0]       data0_o,
	                         
	input  [INDEX-1:0]       addr1_i,
	output [WIDTH-1:0]       data1_o,

	input  [INDEX-1:0]       addr0wr_i,
	input  [WIDTH-1:0]       data0wr_i,
	input                    we0_i,
                           
	                         
`ifdef ISSUE_TWO_WIDE   
	input  [INDEX-1:0]       addr2_i,
	output [WIDTH-1:0]       data2_o,
	                         
	input  [INDEX-1:0]       addr3_i,
	output [WIDTH-1:0]       data3_o,

	input  [INDEX-1:0]       addr1wr_i,
	input  [WIDTH-1:0]       data1wr_i,
	input                    we1_i,
`endif                     
	                         
`ifdef ISSUE_THREE_WIDE   
	input  [INDEX-1:0]       addr4_i,
	output [WIDTH-1:0]       data4_o,

	input  [INDEX-1:0]       addr5_i,
	output [WIDTH-1:0]       data5_o,

	input  [INDEX-1:0]       addr2wr_i,
	input  [WIDTH-1:0]       data2wr_i,
	input                    we2_i,
`endif                     
	                         
`ifdef ISSUE_FOUR_WIDE   
	input  [INDEX-1:0]       addr6_i,
	output [WIDTH-1:0]       data6_o,

	input  [INDEX-1:0]       addr7_i,
	output [WIDTH-1:0]       data7_o,

	input  [INDEX-1:0]       addr3wr_i,
	input  [WIDTH-1:0]       data3wr_i,
	input                    we3_i,
`endif                     
	                         
`ifdef ISSUE_FIVE_WIDE   
	input  [INDEX-1:0]       addr8_i,
	output [WIDTH-1:0]       data8_o,

	input  [INDEX-1:0]       addr9_i,
	output [WIDTH-1:0]       data9_o,

	input  [INDEX-1:0]       addr4wr_i,
	input  [WIDTH-1:0]       data4wr_i,
	input                    we4_i,
`endif                     
	                         
`ifdef ISSUE_SIX_WIDE   
	input  [INDEX-1:0]       addr10_i,
	output [WIDTH-1:0]       data10_o,

	input  [INDEX-1:0]       addr11_i,
	output [WIDTH-1:0]       data11_o,

	input  [INDEX-1:0]       addr5wr_i,
	input  [WIDTH-1:0]       data5wr_i,
	input                    we5_i,
`endif                     
	                         
`ifdef ISSUE_SEVEN_WIDE   
	input  [INDEX-1:0]       addr12_i,
	output [WIDTH-1:0]       data12_o,

	input  [INDEX-1:0]       addr13_i,
	output [WIDTH-1:0]       data13_o,

	input  [INDEX-1:0]       addr6wr_i,
	input  [WIDTH-1:0]       data6wr_i,
	input                    we6_i,
`endif                     
	                         
`ifdef ISSUE_EIGHT_WIDE   
	input  [INDEX-1:0]       addr14_i,
	output [WIDTH-1:0]       data14_o,

	input  [INDEX-1:0]       addr15_i,
	output [WIDTH-1:0]       data15_o,

	input  [INDEX-1:0]       addr7wr_i,
	input  [WIDTH-1:0]       data7wr_i,
	input                    we7_i,
`endif                     
                           

	input                    reset,
	input                    clk
);

//`ifndef DYNAMIC_CONFIG

`ifdef PRF_RAM_COMPILED
//synopsys translate_off
`endif
  
  reg [WIDTH-1:0]            ram [DEPTH-1:0];
  
  
  /* Read operation */
    assign data0_o           = ram[addr0_i];
    assign data1_o           = ram[addr1_i];
  
  `ifdef ISSUE_TWO_WIDE
    assign data2_o           = ram[addr2_i];
    assign data3_o           = ram[addr3_i];
  `endif
  
  `ifdef ISSUE_THREE_WIDE
    assign data4_o           = ram[addr4_i];
    assign data5_o           = ram[addr5_i];
  `endif
  
  `ifdef ISSUE_FOUR_WIDE
    assign data6_o           = ram[addr6_i];
    assign data7_o           = ram[addr7_i];
  `endif
  
  `ifdef ISSUE_FIVE_WIDE
    assign data8_o           = ram[addr8_i];
    assign data9_o           = ram[addr9_i];
  `endif
  
  `ifdef ISSUE_SIX_WIDE
    assign data10_o          = ram[addr10_i];
    assign data11_o          = ram[addr11_i];
  `endif
  
  `ifdef ISSUE_SEVEN_WIDE
    assign data12_o          = ram[addr12_i];
    assign data13_o          = ram[addr13_i];
  `endif
  
  `ifdef ISSUE_EIGHT_WIDE
    assign data14_o          = ram[addr14_i];
    assign data15_o          = ram[addr15_i];
  `endif
  
  `ifdef VERILATOR
  initial
  begin
      int i;
      for (i = 0; i < DEPTH; i++)
      begin
          ram[i]         <= {WIDTH{1'b0}};
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
  			ram[i]         <= {WIDTH{1'b0}};
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
  
  	end
  end

`ifdef PRF_RAM_COMPILED
//synopsys translate_on
`endif


endmodule


