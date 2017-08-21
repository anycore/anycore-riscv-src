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

module ExecutionPipe_SC #(
	parameter  SIMPLE  = `PIPE_HAS_SIMPLE,
	parameter  COMPLEX = `PIPE_HAS_COMPLEX,
  parameter  FP      = `PIPE_HAS_FP
)(

	input                                clk,
	input                                reset,

	input                                recoverFlag_i,
	input                                exceptionFlag_i,

  output                               toggleFlag_o,

`ifdef DYNAMIC_CONFIG  
  input                                laneActive_i,
  input                                saluLaneActive_i,
  input                                caluLaneActive_i,
`endif  

	/* inputs coming from the register file */
	input  [`SIZE_DATA-1:0]              src1Data_i,
	input  [`SIZE_DATA-1:0]              src2Data_i,

	/* input from the issue queue going to the reg read stage */
	input  payloadPkt                    rrPacket_i,

	/* bypasses coming from all execution pipes */
	input  bypassPkt                     bypassPacket_i [0:`ISSUE_WIDTH-1],

	/* bypass going from this pipe to other pipes */
	output bypassPkt                     bypassPacket_o,

	/* output going to the active list from the simple pipe */
	output ctrlPkt                       ctrlPacket_o,

	/* source operands extracted from the packet going to the physical register file */
	output [`SIZE_PHYSICAL_LOG-1:0]      phySrc1_o,
	output [`SIZE_PHYSICAL_LOG-1:0]      phySrc2_o
	);


wire clkGated;

`ifdef DYNAMIC_CONFIG
  `ifdef GATE_CLK
    // Instantiating clk gate cell
    clk_gater_ul clkGate (.clk_i(clk),.clkGated_o(clkGated),.clkEn_i(laneActive_i));
  `else
    assign clkGated = clk;
  `endif //GATE_CLK
`else
  assign clkGated = clk;
`endif


/* declaring wires for internal connections */
fuPkt                                  exePacket;
fuPkt                                  exePacket_l1;

wbPkt                                  wbPacket;


/* Instantiations of the reg-read, execute and writeback stages */

RegRead regread (

	.clk                                (clkGated),
	.reset                              (reset),

	.recoverFlag_i                      (recoverFlag_i),

	.src1Data_i                         (src1Data_i),
	.src2Data_i                         (src2Data_i),

	.rrPacket_i                         (rrPacket_i),

	.exePacket_o                        (exePacket),

	.phySrc1_o                          (phySrc1_o),
	.phySrc2_o                          (phySrc2_o),

	.bypassPacket_i                     (bypassPacket_i),

	.csrRdData_i                        (),
	.csrRdAddr_o                        ()
);


RegReadExecute rr_exe (

	.clk                                (clkGated),
	.reset                              (reset),

	.flush_i                            (recoverFlag_i | exceptionFlag_i),

	.exePacket_i                        (exePacket),
	.exePacket_o                        (exePacket_l1)
);


Execute_SC #(
	.SIMPLE                             (SIMPLE),
	.COMPLEX                            (COMPLEX),
	.FP                                 (FP)     
)
	execute (

	.clk                                (clkGated),
	.reset                              (reset),

	.recoverFlag_i                      (recoverFlag_i | exceptionFlag_i),

  .toggleFlag_o                       (toggleFlag_o),

	.exePacket_i                        (exePacket_l1),
	.wbPacket_o                         (wbPacket),

	.bypassPacket_i                     (bypassPacket_i)
);


Writeback_SC writeback (

	.clk                                (clkGated),
	.reset                              (reset),

	.recoverFlag_i                      (recoverFlag_i|exceptionFlag_i),

	.wbPacket_i                         (wbPacket),

	.ctrlPacket_o                       (ctrlPacket_o),
	.bypassPacket_o                     (bypassPacket_o)
);

endmodule
