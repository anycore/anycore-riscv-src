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

module DEBUG_DATA_RAM #(

	/* Parameters */
	parameter DEPTH = 256,
	parameter INDEX = 8,
	parameter WIDTH = 64
	) (

`ifdef SCRATCH_PAD

	input  [INDEX-1:0]                addr0rd_i,
	output [WIDTH-1:0]                data0rd_o,


	input  [INDEX-1:0]                addr0wr_i,
	input  [WIDTH-1:0]                data0wr_i,
	input                             we0_i,

  input  [`DEBUG_DATA_RAM_LOG+`DEBUG_DATA_RAM_WIDTH_LOG-1:0]  dataScratchAddr_i   ,
  input                             [7:0]  dataScratchWrData_i ,
  input                                    dataScratchWrEn_i   ,
  output                            [7:0]  dataScratchRdData_o, 

`endif

	input                             clk,
	input                             reset
);

// Disable compilation of logic if SCRATCH_PAD is not defined
`ifdef SCRATCH_PAD

  reg  [WIDTH-1:0]                    ram [DEPTH-1:0];
  
  
  /* Read operation */
  assign data0rd_o                  = ram[addr0rd_i];
  assign dataScratchRdData_o        = ram[dataScratchAddr_i[`DEBUG_DATA_RAM_LOG-1:0]][(8*(dataScratchAddr_i[`DEBUG_DATA_RAM_LOG+`DEBUG_DATA_RAM_WIDTH_LOG-1:`DEBUG_DATA_RAM_LOG]+1)-1)-:8];
  
  
  /* Write operation */
  always_ff @(posedge clk)
  begin
  	int i;
  
  	if (reset)
  	begin
  		for (i = 0; i < DEPTH; i++)
  		begin
  			ram[i]         <= 0;
  		end
  	end
  
  	else
  	begin
                  if (dataScratchWrEn_i)
  		begin
  	                ram[dataScratchAddr_i[`DEBUG_DATA_RAM_LOG-1:0]][(8*(dataScratchAddr_i[`DEBUG_DATA_RAM_LOG+`DEBUG_DATA_RAM_WIDTH_LOG-1:`DEBUG_DATA_RAM_LOG]+1)-1)-:8] <= dataScratchWrData_i; 
  		end
  		else if (we0_i)
  		begin
  			ram[addr0wr_i] <= data0wr_i;
  		end
  			end
  end
`endif

endmodule

