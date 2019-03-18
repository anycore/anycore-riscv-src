/***************************************************************************
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

module LDVIO_VLD_RAM #(

	/* Parameters */
  parameter RPORT = `DISPATCH_WIDTH,
  parameter WPORT = 1,
	parameter DEPTH = 16,
	parameter INDEX = 4,
	parameter WIDTH = 8
) (

	input  [INDEX-1:0]                addr0_i,
	output [WIDTH-1:0]                data0_o,

`ifdef DISPATCH_TWO_WIDE
	input  [INDEX-1:0]                addr1_i,
	output [WIDTH-1:0]                data1_o,
`endif

`ifdef DISPATCH_THREE_WIDE
	input  [INDEX-1:0]                addr2_i,
	output [WIDTH-1:0]                data2_o,
`endif

`ifdef DISPATCH_FOUR_WIDE
	input  [INDEX-1:0]                addr3_i,
	output [WIDTH-1:0]                data3_o,
`endif

`ifdef DISPATCH_FIVE_WIDE
	input  [INDEX-1:0]                addr4_i,
	output [WIDTH-1:0]                data4_o,
`endif

`ifdef DISPATCH_SIX_WIDE
	input  [INDEX-1:0]                addr5_i,
	output [WIDTH-1:0]                data5_o,
`endif

`ifdef DISPATCH_SEVEN_WIDE
	input  [INDEX-1:0]                addr6_i,
	output [WIDTH-1:0]                data6_o,
`endif

`ifdef DISPATCH_EIGHT_WIDE
	input  [INDEX-1:0]                addr7_i,
	output [WIDTH-1:0]                data7_o,
`endif


	input  [INDEX-1:0]                addr0wr_i,
	input  [WIDTH-1:0]                data0wr_i,
	input                             we0_i,

	input                             clk,
	input                             reset
);


// NOTE: Too small to be converted into RAMs

reg  [WIDTH-1:0]                    ram [DEPTH-1:0];


/* Read operation */
assign data0_o                    = ram[addr0_i];

`ifdef DISPATCH_TWO_WIDE
assign data1_o                    = ram[addr1_i];
`endif

`ifdef DISPATCH_THREE_WIDE
assign data2_o                    = ram[addr2_i];
`endif

`ifdef DISPATCH_FOUR_WIDE
assign data3_o                    = ram[addr3_i];
`endif

`ifdef DISPATCH_FIVE_WIDE
assign data4_o                    = ram[addr4_i];
`endif

`ifdef DISPATCH_SIX_WIDE
assign data5_o                    = ram[addr5_i];
`endif

`ifdef DISPATCH_SEVEN_WIDE
assign data6_o                    = ram[addr6_i];
`endif

`ifdef DISPATCH_EIGHT_WIDE
assign data7_o                    = ram[addr7_i];
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
	end
end

endmodule


