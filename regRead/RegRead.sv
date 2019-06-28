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


module RegRead (
	input                                clk,
	input                                reset,

	input                                recoverFlag_i,

	/* inputs coming from the register files will come here */
	input  [`SIZE_DATA-1:0]              src1Data_i,
	input  [`SIZE_DATA-1:0]              src2Data_i,

	input  payloadPkt                    rrPacket_i,

	input  bypassPkt                     bypassPacket_i [0:`ISSUE_WIDTH-1],

	output fuPkt                         exePacket_o,

	output [`SIZE_PHYSICAL_LOG-1:0]      phySrc1_o,
	output [`SIZE_PHYSICAL_LOG-1:0]      phySrc2_o,

	input  [`CSR_WIDTH-1:0]         csrRdData_i,
	output [`CSR_WIDTH_LOG-1:0]           csrRdAddr_o,
	output                               csrRdEn_o
);


wire [`SIZE_DATA-1:0]                  src1Data;
wire [`SIZE_DATA-1:0]                  src2Data;
wire [`CSR_WIDTH-1:0]             CSRregData;

fuPkt                                  exePacket_l0;
fuPkt                                  exePacket_l1;
fuPkt                                  exePacket_l2;
fuPkt                                  exePacket_l3;

/* Convert the rrPkt into an fuPkt and then delay it according to the register
 * read depth */
always_comb  
begin
	exePacket_l0.seqNo        = rrPacket_i.seqNo;
	exePacket_l0.pc           = rrPacket_i.pc;
	exePacket_l0.inst         = rrPacket_i.inst;
	exePacket_l0.logDest      = rrPacket_i.logDest;
	exePacket_l0.phyDest      = rrPacket_i.phyDest;
	exePacket_l0.phyDestValid = rrPacket_i.phyDestValid;
	exePacket_l0.phySrc1      = rrPacket_i.phySrc1;
	exePacket_l0.phySrc2      = rrPacket_i.phySrc2;
	exePacket_l0.src1Data     = 0;
	exePacket_l0.src2Data     = 0;
	exePacket_l0.lsqID        = rrPacket_i.lsqID;
	exePacket_l0.alID         = rrPacket_i.alID;
	exePacket_l0.immed        = rrPacket_i.immed;
	exePacket_l0.valid        = rrPacket_i.valid;
	exePacket_l0.ctiID        = rrPacket_i.ctiID;
	exePacket_l0.isSimple     = rrPacket_i.isSimple;
	exePacket_l0.isFP     	  = rrPacket_i.isFP;	//Changes: Mohit (Added missing copy statement from rrPacket to exePacket)
	exePacket_l0.isCSR        = rrPacket_i.isCSR;
	exePacket_l0.isFP         = rrPacket_i.isFP;
	exePacket_l0.ctrlType     = rrPacket_i.ctrlType;
	exePacket_l0.predNPC      = rrPacket_i.predNPC;
	exePacket_l0.predDir      = rrPacket_i.predDir;
	exePacket_l0.valid        = rrPacket_i.valid;
end


`ifdef RR_THREE_DEEP
/* 3- and 4-deep delays byte 1 */
always_ff @(posedge clk)
begin
	if (reset | recoverFlag_i) 
	begin
		exePacket_l1       <= 0;
	end

	else
	begin
		exePacket_l1       <= exePacket_l0;
	end
end
`endif

`ifdef RR_TWO_DEEP
/* 2- 3- and 4-deep delays byte 2 */
always_ff @(posedge clk)
begin
	if (reset | recoverFlag_i) 
	begin
		exePacket_l2       <= 0;
	end

	else
	begin
		exePacket_l2       <= exePacket_l1;
	end
end
`endif

`ifdef RR_FOUR_DEEP
/* 4-deep delays byte 3 */
always_ff @(posedge clk)
begin
	if (reset | recoverFlag_i) 
	begin
		exePacket_l3       <= 0;
	end

	else
	begin
		exePacket_l3       <= exePacket_l2;
	end
end
`endif

always_comb
begin
`ifndef RR_THREE_DEEP
	exePacket_l1          = exePacket_l0;
`endif

`ifndef RR_TWO_DEEP
	exePacket_l2          = exePacket_l1;
`endif

`ifndef RR_FOUR_DEEP
	exePacket_l3          = exePacket_l2;
`endif

	exePacket_o.seqNo         = exePacket_l3.seqNo;
	exePacket_o.pc            = exePacket_l3.pc;
	exePacket_o.inst          = exePacket_l3.inst;
	exePacket_o.logDest       = exePacket_l3.logDest;
	exePacket_o.phyDest       = exePacket_l3.phyDest;
	exePacket_o.phyDestValid  = exePacket_l3.phyDestValid;
	exePacket_o.phySrc1       = exePacket_l3.phySrc1;
	exePacket_o.phySrc2       = exePacket_l3.phySrc2;
	exePacket_o.src1Data      = src1Data;
	exePacket_o.src2Data      = exePacket_l3.isCSR ? csrRdData_i : src2Data;
	exePacket_o.lsqID         = exePacket_l3.lsqID;
	exePacket_o.alID          = exePacket_l3.alID;
	exePacket_o.immed         = exePacket_l3.immed;
	exePacket_o.valid         = exePacket_l3.valid;
	exePacket_o.ctiID         = exePacket_l3.ctiID;
	exePacket_o.isSimple      = exePacket_l3.isSimple;
	exePacket_o.isCSR         = exePacket_l3.isCSR;   
	exePacket_o.isFP          = exePacket_l3.isFP;    
	exePacket_o.ctrlType      = exePacket_l3.ctrlType;
	exePacket_o.predNPC       = exePacket_l3.predNPC;
	exePacket_o.predDir       = exePacket_l3.predDir;
	exePacket_o.valid         = exePacket_l3.valid;
end

  assign  phySrc1_o         = rrPacket_i.phySrc1;
  assign  phySrc2_o         = rrPacket_i.phySrc2;
  assign  csrRdAddr_o       = rrPacket_i.inst[31:20];
  assign  csrRdEn_o         = rrPacket_i.isCSR & rrPacket_i.valid; // Read the CSR register only if a CSR inst

/* Check the bypasses each cycle for a match. */
`ifdef RR_FOUR_DEEP
`define BYPASS Bypass_4D
`elsif RR_THREE_DEEP
`define BYPASS Bypass_3D
`elsif RR_TWO_DEEP
`define BYPASS Bypass_2D
`else
`define BYPASS Bypass_1D
`endif

/* Check the bypasses each cycle for a match. */
`BYPASS src1Bypass (

	.clk                                (clk),
	.reset                              (reset),

	.bypassPacket_i                     (bypassPacket_i),

	.phySrc_i                           (rrPacket_i.phySrc1),
	
	.datastage0_i                       (src1Data_i),

	.data_o                             (src1Data)
	);

`BYPASS src2Bypass (

	.clk                                (clk),
	.reset                              (reset),

	.bypassPacket_i                     (bypassPacket_i),

	.phySrc_i                           (rrPacket_i.phySrc2),

	.datastage0_i                       (src2Data_i),

	.data_o                             (src2Data)
	);


endmodule

