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


fs2Pkt  [0:`FETCH_WIDTH-1]                   fs2Packet;
fs2Pkt  [0:`FETCH_WIDTH-1]                   fs2Packet_l1;

assign        fs2Packet     = coreTop.fs1fs2.fs2Packet_i;
assign        fs2Packet_l1  = coreTop.fs1fs2.fs2Packet_o;

decPkt  [0:`FETCH_WIDTH-1]                   decPacket;
decPkt  [0:`FETCH_WIDTH-1]                   decPacket_l1;
renPkt  [0:2*`FETCH_WIDTH-1]                 ibPacket;

assign        decPacket     = coreTop.fs2dec.decPacket_i;
assign        decPacket_l1  = coreTop.fs2dec.decPacket_o;
assign        ibPacket      = coreTop.decode.ibPacket_o;

renPkt  [0:`DISPATCH_WIDTH-1]                renPacket;
renPkt  [0:`DISPATCH_WIDTH-1]                renPacket_l1;

assign        renPacket     = coreTop.instBufRen.renPacket_i;
assign        renPacket_l1  = coreTop.instBufRen.renPacket_o;


disPkt  [0:`DISPATCH_WIDTH-1]                     disPacket_l1;
iqPkt   [0:`DISPATCH_WIDTH-1]                     iqPacket;
//alPkt   [0:`DISPATCH_WIDTH-1]                     alPacket;
lsqPkt  [0:`DISPATCH_WIDTH-1]                     lsqPacket;

assign        disPacket_l1                = coreTop.renDis.disPacket_o;
assign        iqPacket                    = coreTop.dispatch.iqPacket_o;
//assign        alPacket                    = coreTop.dispatch.alPacket_o;
assign        lsqPacket                   = coreTop.lsu.lsqPacket_i;

iqEntryPkt    [0:`ISSUE_WIDTH-1]              iqGrantedEntry;
iqEntryPkt    [0:`ISSUE_WIDTH-1]              iqFreedEntry  ;
iqEntryPkt    [0:`DISPATCH_WIDTH-1]           iqFreeEntry   ;

assign        iqGrantedEntry                = coreTop.issueq.issueQfreelist.grantedEntry_i;
//assign        iqFreedEntry                  = coreTop.issueq.issueQfreelist.freedEntry_o;
assign        iqFreeEntry                   = coreTop.issueq.issueQfreelist.freeEntry_o;

payloadPkt                                    iqPldWrPacket [0:`DISPATCH_WIDTH-1];
  assign        iqPldWrPacket[0] = coreTop.issueq.payloadRAM.data0wr_i;
`ifdef DISPATCH_TWO_WIDE
  assign        iqPldWrPacket[1] = coreTop.issueq.payloadRAM.data1wr_i;
`endif
`ifdef DISPATCH_THREE_WIDE
  assign        iqPldWrPacket[2] = coreTop.issueq.payloadRAM.data2wr_i;
`endif
`ifdef DISPATCH_FOUR_WIDE
  assign        iqPldWrPacket[3] = coreTop.issueq.payloadRAM.data3wr_i;
`endif
`ifdef DISPATCH_FIVE_WIDE
  assign        iqPldWrPacket[4] = coreTop.issueq.payloadRAM.data4wr_i;
`endif
`ifdef DISPATCH_SIX_WIDE
  assign        iqPldWrPacket[5] = coreTop.issueq.payloadRAM.data5wr_i;
`endif
`ifdef DISPATCH_SEVEN_WIDE
  assign        iqPldWrPacket[6] = coreTop.issueq.payloadRAM.data6wr_i;
`endif
`ifdef DISPATCH_EIGHT_WIDE
  assign        iqPldWrPacket[7] = coreTop.issueq.payloadRAM.data7wr_i;
`endif


payloadPkt                                    iqPldRdPacket [0:`ISSUE_WIDTH-1];
  assign        iqPldRdPacket[0] = coreTop.issueq.payloadRAM.data0_o;
`ifdef ISSUE_TWO_WIDE
  assign        iqPldRdPacket[1] = coreTop.issueq.payloadRAM.data1_o;
`endif
`ifdef ISSUE_THREE_WIDE
  assign        iqPldRdPacket[2] = coreTop.issueq.payloadRAM.data2_o;
`endif
`ifdef ISSUE_FOUR_WIDE
  assign        iqPldRdPacket[3] = coreTop.issueq.payloadRAM.data3_o;
`endif
`ifdef ISSUE_FIVE_WIDE
  assign        iqPldRdPacket[4] = coreTop.issueq.payloadRAM.data4_o;
`endif
`ifdef ISSUE_SIX_WIDE
  assign        iqPldRdPacket[5] = coreTop.issueq.payloadRAM.data5_o;
`endif
`ifdef ISSUE_SEVEN_WIDE
  assign        iqPldRdPacket[6] = coreTop.issueq.payloadRAM.data6_o;
`endif
`ifdef ISSUE_EIGHT_WIDE
  assign        iqPldRdPacket[7] = coreTop.issueq.payloadRAM.data7_o;
`endif


payloadPkt  [0:`ISSUE_WIDTH-1]                    rrPacket_l1;
//bypassPkt   [0:`ISSUE_WIDTH-1]                    bypassPacket;

assign        rrPacket_l1                 = coreTop.iq_regread.rrPacket_o;
assign        bypassPacket                = coreTop.registerfile.bypassPacket_i;

//fuPkt                           exePacket      [0:`ISSUE_WIDTH-1];
fuPkt                           exePacket_s    [0:`ISSUE_WIDTH-1];
fuPkt                           exePacket_c    [0:`ISSUE_WIDTH-1];


assign    exePacket[0]      = coreTop.exePipe0.execute.exePacket_i;
assign    exePacket[1]      = coreTop.exePipe1.execute.exePacket_i;
assign    exePacket[2]      = coreTop.exePipe2.execute.exePacket_i;
//assign    exePacket_s[2]    = coreTop.exePipe2.execute.simple_complex.salu.exePacket_i;
//assign    exePacket_c[2]    = coreTop.exePipe2.execute.simple_complex.calu.exePacket_i;

`ifdef ISSUE_FOUR_WIDE
assign    exePacket[3]      = coreTop.exePipe3.execute.exePacket_i;
//assign    exePacket_s[3]    = coreTop.exePipe2.execute.simple_complex.salu.exePacket_i;
//assign    exePacket_c[3]    = coreTop.exePipe2.execute.simple_complex.calu.exePacket_i;
`endif
`ifdef ISSUE_FIVE_WIDE
assign    exePacket[4]      = coreTop.exePipe4.execute.exePacket_i;
//assign    exePacket_s[4]    = coreTop.exePipe2.execute.simple_complex.salu.exePacket_i;
`endif
`ifdef ISSUE_SIX_WIDE
assign    exePacket[5]      = coreTop.exePipe5.execute.exePacket_i;
//assign    exePacket_s[5]    = coreTop.exePipe2.execute.simple_complex.salu.exePacket_i;
`endif


memPkt                         memPacket;

wbPkt                          lsuWbPacket;
ldVioPkt                       ldVioPacket;

assign    memPacket         = coreTop.exePipe0.memPacket_o;
assign    lsuWbPacket       = coreTop.lsu.wbPacket_o;
assign    ldVioPacket       = coreTop.lsu.ldVioPacket_o;




