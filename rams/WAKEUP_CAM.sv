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

module WAKEUP_CAM #(
	/* Parameters */
  parameter RPORT = `ISSUE_WIDTH,
  parameter WPORT = `DISPATCH_WIDTH,
	parameter DEPTH = 16,
	parameter INDEX = 4,
	parameter WIDTH = 8
	) (

	input      [WIDTH-1:0]                tag0_i,
	output reg [DEPTH-1:0]                vect0_o,
	
`ifdef ISSUE_TWO_WIDE
	input      [WIDTH-1:0]                tag1_i,
	output reg [DEPTH-1:0]                vect1_o,
`endif

`ifdef ISSUE_THREE_WIDE
	input      [WIDTH-1:0]                tag2_i,
	output reg [DEPTH-1:0]                vect2_o,
`endif

`ifdef ISSUE_FOUR_WIDE
	input      [WIDTH-1:0]                tag3_i,
	output reg [DEPTH-1:0]                vect3_o,
`endif

`ifdef ISSUE_FIVE_WIDE
	input      [WIDTH-1:0]                tag4_i,
	output reg [DEPTH-1:0]                vect4_o,
`endif

`ifdef ISSUE_SIX_WIDE
	input      [WIDTH-1:0]                tag5_i,
	output reg [DEPTH-1:0]                vect5_o,
`endif

`ifdef ISSUE_SEVEN_WIDE
	input      [WIDTH-1:0]                tag6_i,
	output reg [DEPTH-1:0]                vect6_o,
`endif

`ifdef ISSUE_EIGHT_WIDE
	input      [WIDTH-1:0]                tag7_i,
	output reg [DEPTH-1:0]                vect7_o,
`endif


	input      [INDEX-1:0]                addr0wr_i,
	input      [WIDTH-1:0]                data0wr_i,
	input                                 we0_i,

`ifdef DISPATCH_TWO_WIDE
	input      [INDEX-1:0]                addr1wr_i,
	input      [WIDTH-1:0]                data1wr_i,
	input                                 we1_i,
`endif

`ifdef DISPATCH_THREE_WIDE
	input      [INDEX-1:0]                addr2wr_i,
	input      [WIDTH-1:0]                data2wr_i,
	input                                 we2_i,
`endif

`ifdef DISPATCH_FOUR_WIDE
	input      [INDEX-1:0]                addr3wr_i,
	input      [WIDTH-1:0]                data3wr_i,
	input                                 we3_i,
`endif

`ifdef DISPATCH_FIVE_WIDE
	input      [INDEX-1:0]                addr4wr_i,
	input      [WIDTH-1:0]                data4wr_i,
	input                                 we4_i,
`endif

`ifdef DISPATCH_SIX_WIDE
	input      [INDEX-1:0]                addr5wr_i,
	input      [WIDTH-1:0]                data5wr_i,
	input                                 we5_i,
`endif

`ifdef DISPATCH_SEVEN_WIDE
	input      [INDEX-1:0]                addr6wr_i,
	input      [WIDTH-1:0]                data6wr_i,
	input                                 we6_i,
`endif

`ifdef DISPATCH_EIGHT_WIDE
	input      [INDEX-1:0]                addr7wr_i,
	input      [WIDTH-1:0]                data7wr_i,
	input                                 we7_i,
`endif


	//input                                 reset,
	input                                 clk
);



//`ifndef DYNAMIC_CONFIG

`ifdef WAKEUP_CAM_COMPILED
//synopsys translate_off
`endif

  /* The RAM reg */
  reg  [WIDTH-1:0]                   ram [DEPTH-1:0];

  /* Read operation */
  always_comb
  begin
  	int i;
  
  	for (i = 0; i < DEPTH; i++)
  	begin
  		vect0_o[i]   = 1'h0;
  
  		if (ram[i] == tag0_i)
  		begin
  			vect0_o[i] = 1'h1;
  		end
  
  `ifdef ISSUE_TWO_WIDE
  		vect1_o[i]   = 1'h0;
  
  		if (ram[i] == tag1_i)
  		begin
  			vect1_o[i] = 1'h1;
  		end
  `endif
  
  `ifdef ISSUE_THREE_WIDE
  		vect2_o[i]   = 1'h0;
  
  		if (ram[i] == tag2_i)
  		begin
  			vect2_o[i] = 1'h1;
  		end
  `endif
  
  `ifdef ISSUE_FOUR_WIDE
  		vect3_o[i]   = 1'h0;
  
  		if (ram[i] == tag3_i)
  		begin
  			vect3_o[i] = 1'h1;
  		end
  `endif
  
  `ifdef ISSUE_FIVE_WIDE
  		vect4_o[i]   = 1'h0;
  
  		if (ram[i] == tag4_i)
  		begin
  			vect4_o[i] = 1'h1;
  		end
  `endif
  
  `ifdef ISSUE_SIX_WIDE
  		vect5_o[i]   = 1'h0;
  
  		if (ram[i] == tag5_i)
  		begin
  			vect5_o[i] = 1'h1;
  		end
  `endif
  
  `ifdef ISSUE_SEVEN_WIDE
  		vect6_o[i]   = 1'h0;
  
  		if (ram[i] == tag6_i)
  		begin
  			vect6_o[i] = 1'h1;
  		end
  `endif
  
  `ifdef ISSUE_EIGHT_WIDE
  		vect7_o[i]   = 1'h0;
  
  		if (ram[i] == tag7_i)
  		begin
  			vect7_o[i] = 1'h1;
  		end
  `endif
  	end
  end


  /* Write operation */
  always_ff @(posedge clk)
  begin
  	int i;
  
  	//if (reset)
  	//begin
  	//	for (i = 0; i < DEPTH; i++)
  	//	begin
  	//		ram[i]              <= 0;
  	//	end
  	//end
    // 
  	//else
  	//begin
  		if (we0_i)
  		begin
  			ram[addr0wr_i]      <= data0wr_i;
  		end
  
  `ifdef DISPATCH_TWO_WIDE
  		if (we1_i)
  		begin
  			ram[addr1wr_i]      <= data1wr_i;
  		end
  `endif
  
  `ifdef DISPATCH_THREE_WIDE
  		if (we2_i)
  		begin
  			ram[addr2wr_i]      <= data2wr_i;
  		end
  `endif
  
  `ifdef DISPATCH_FOUR_WIDE
  		if (we3_i)
  		begin
  			ram[addr3wr_i]      <= data3wr_i;
  		end
  `endif
  
  `ifdef DISPATCH_FIVE_WIDE
  		if (we4_i)
  		begin
  			ram[addr4wr_i]      <= data4wr_i;
  		end
  `endif
  
  `ifdef DISPATCH_SIX_WIDE
  		if (we5_i)
  		begin
  			ram[addr5wr_i]      <= data5wr_i;
  		end
  `endif
  
  `ifdef DISPATCH_SEVEN_WIDE
  		if (we6_i)
  		begin
  			ram[addr6wr_i]      <= data6wr_i;
  		end
  `endif
  
  `ifdef DISPATCH_EIGHT_WIDE
  		if (we7_i)
  		begin
  			ram[addr7wr_i]      <= data7wr_i;
  		end
  `endif
  	//end
  end

`ifdef WAKEUP_CAM_COMPILED
//synopsys translate_on
`endif


endmodule


