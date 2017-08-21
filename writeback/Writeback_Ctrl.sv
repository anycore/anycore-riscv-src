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


module Writeback_Ctrl (

	input                               clk,
	input                               reset,
	
	input                               recoverFlag_i,

	/* these are the inputs and outputs for one particular function unit*/
	input  wbPkt                        wbPacket_i,

	output ctrlPkt                      ctrlPacket_o,

	output bypassPkt                    bypassPacket_o, 
  output [`CSR_WIDTH-1:0]        csrWrData_o,
  output [`CSR_WIDTH_LOG-1:0]          csrWrAddr_o,
  output                              csrWrEn_o,

	// these are the outputs from the execution pipe which holds the branch function unit

	output [`SIZE_PC-1:0]               exeCtrlPC_o,
	output [`BRANCH_TYPE_LOG-1:0]           exeCtrlType_o,
	output                              exeCtrlValid_o,
	output [`SIZE_PC-1:0]               exeCtrlNPC_o,
	output                              exeCtrlDir_o,
	output [`SIZE_CTI_LOG-1:0]          exeCtiID_o
	);


wbPkt                                 wbPacket;


/* assign the parsed values to the output bypasses */
assign bypassPacket_o.tag            = wbPacket.phyDest;
assign bypassPacket_o.data           = wbPacket.destData;
/* assign bypassPacket_o.byte0          = wbPacket.destData[7:0]; */   
/* assign bypassPacket_o.byte1          = wbPacket.destData[15:8]; */  
/* assign bypassPacket_o.byte2          = wbPacket.destData[23:16]; */ 
/* assign bypassPacket_o.byte3          = wbPacket.destData[31:24]; */ 
assign bypassPacket_o.valid          = wbPacket.valid & wbPacket.flags.destValid;

assign csrWrData_o                   = wbPacket.csrWrData;
assign csrWrAddr_o                   = wbPacket.csrWrAddr;
assign csrWrEn_o                     = wbPacket.csrWrEn & wbPacket.valid;

assign exeCtrlPC_o                   = wbPacket.pc;    
assign exeCtrlType_o                 = wbPacket.ctrlType;    
assign exeCtrlValid_o                = wbPacket.valid & wbPacket.flags.isControl;    
assign exeCtrlNPC_o                  = wbPacket.nextPC;  
assign exeCtrlDir_o                  = wbPacket.ctrlDir; 
assign exeCtiID_o                    = wbPacket.ctiID;   


always_comb 
begin
	ctrlPacket_o.seqNo                 = wbPacket.seqNo;
	ctrlPacket_o.valid                 = wbPacket.valid;
	ctrlPacket_o.alID                  = wbPacket.alID;
	ctrlPacket_o.flags                 = wbPacket.flags;
	ctrlPacket_o.nextPC                = wbPacket.nextPC;
  ctrlPacket_o.actualDir             = wbPacket.ctrlDir;
end


always_ff @(posedge clk)
begin
	if (reset | recoverFlag_i)
	begin
		wbPacket       <= {`WB_PKT_SIZE{1'b0}};
	end

	else
	begin
		wbPacket       <= wbPacket_i;
	end
end

endmodule

