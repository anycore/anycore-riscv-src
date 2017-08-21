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

module RegisterConsolidate( 
	input					                        clk,
	input					                        reset,

	input					                        startConsolidate_i,
	input      [`SIZE_PHYSICAL_LOG-1:0]	  phyAddrAMT_i,
  input      [`SIZE_PHYSICAL_LOG-1:0]   phySrc1_i [0:`ISSUE_WIDTH-1],
  input      [`SIZE_PHYSICAL_LOG-1:0]   phySrc2_i [0:`ISSUE_WIDTH-1],
  input  bypassPkt                      bypassPacket_i [0:`ISSUE_WIDTH-1],

  input      [`SRAM_DATA_WIDTH-1:0]     regVal_byte0_i [0:`ISSUE_WIDTH-1],
  input      [`SRAM_DATA_WIDTH-1:0]     regVal_byte1_i [0:`ISSUE_WIDTH-1],
  input      [`SRAM_DATA_WIDTH-1:0]     regVal_byte2_i [0:`ISSUE_WIDTH-1],
  input      [`SRAM_DATA_WIDTH-1:0]     regVal_byte3_i [0:`ISSUE_WIDTH-1],
  input      [`SRAM_DATA_WIDTH-1:0]     regVal_byte4_i [0:`ISSUE_WIDTH-1],
  input      [`SRAM_DATA_WIDTH-1:0]     regVal_byte5_i [0:`ISSUE_WIDTH-1],
  input      [`SRAM_DATA_WIDTH-1:0]     regVal_byte6_i [0:`ISSUE_WIDTH-1],
  input      [`SRAM_DATA_WIDTH-1:0]     regVal_byte7_i [0:`ISSUE_WIDTH-1],


	output reg [`SIZE_RMT_LOG-1:0]		    logAddr_o,
  output reg [`SIZE_PHYSICAL_LOG-1:0]	  phySrc1_rd_o   [0:`ISSUE_WIDTH-1],
  output reg [`SIZE_PHYSICAL_LOG-1:0]	  phySrc2_rd_o   [0:`ISSUE_WIDTH-1],
  output bypassPkt                      bypassPacket_o[0:`ISSUE_WIDTH-1],
	output reg  		                      consolidateFlag_o,
	output reg				                    doneConsolidate_o	
);

logic [`SIZE_DATA-1:0]		        registerArray [`SIZE_RMT-1:0];
logic [`SIZE_RMT_LOG-1:0]	        nextLogAddr;
logic [`SIZE_PHYSICAL_LOG-1:0]		nextPhyAddr_o;
logic [`SIZE_PHYSICAL_LOG-1:0]		nextWrPhyAddr;
logic [`SIZE_PHYSICAL_LOG-1:0]		rdPhyAddr;
logic [`SIZE_PHYSICAL_LOG-1:0]	  wrPhyAddr;
logic                             consolidateFlag_d1;
logic					                    writePRFFlag;

logic [8*`SRAM_DATA_WIDTH-1:0] regVal_rd_i;
logic [`SIZE_PHYSICAL_LOG-1:0] phySrc1Ctrl_i;

assign regVal_rd_i    = {regVal_byte7_i[1],regVal_byte6_i[1],regVal_byte5_i[1],regVal_byte4_i[1],regVal_byte3_i[1],regVal_byte2_i[1],regVal_byte1_i[1],regVal_byte0_i[1]};
assign phySrc1Ctrl_i  = phySrc1_i[1];

enum {WAIT,READ_PRF,GAP,WRITE_PRF,FINISH} currentState,nextState;

always_ff @ (posedge clk or posedge reset)
begin
  if (reset)
  begin
    currentState      <= WAIT;
    logAddr_o         <= 0;
    wrPhyAddr         <= 0;
  end
  else
  begin
    currentState      <= nextState;
    logAddr_o         <= nextLogAddr;
    wrPhyAddr         <= nextWrPhyAddr;
  end
end


always_comb
begin
  nextState         = currentState;
  nextLogAddr       = 0 ;
  nextWrPhyAddr     = 0 ;
  doneConsolidate_o = 0;
  writePRFFlag      = 1'b0;
  consolidateFlag_o = 1'b0;
  case (currentState)
  WAIT: if(startConsolidate_i)
     begin
       nextState          = READ_PRF;
     end
  READ_PRF: begin
       consolidateFlag_o  = 1'b1;
       nextLogAddr        = logAddr_o + 1;
       if(logAddr_o == `SIZE_RMT-1)
       begin
         nextState        = GAP;
       end
     end
  GAP: begin
       nextState          = WRITE_PRF;
  end
  WRITE_PRF: begin
       writePRFFlag       = 1'b1;
       nextWrPhyAddr      = wrPhyAddr + 1;
       if (wrPhyAddr == `SIZE_RMT-1)
       begin
         nextState        = FINISH;
       end
      end
  FINISH: begin
       doneConsolidate_o = 1;
       nextState          = WAIT;
     end
  default:begin
  end
  endcase
end

always_ff @(posedge clk or posedge reset)
begin
  int i;
  if(reset)
  begin
    rdPhyAddr           <= 0;
    consolidateFlag_d1  <=  1'b0;
    for(i=0; i < `SIZE_RMT; i++)
      registerArray[i] = {`SIZE_DATA{1'b0}}; 
  end
  else
  begin
    rdPhyAddr         <= phyAddrAMT_i;
    consolidateFlag_d1  <=  consolidateFlag_o;
    // PRF is read in the next cycle of obtaining the mapping from AMT
    if(consolidateFlag_d1)
      registerArray[logAddr_o-1] = regVal_rd_i; 
  end
end
always_comb
begin
  int i;
  for(i = 0; i < `ISSUE_WIDTH ; i++)
  begin
    phySrc1_rd_o[i]   = phySrc1_i[i];
    phySrc2_rd_o[i]   = phySrc2_i[i];
    bypassPacket_o[i] = bypassPacket_i[i];
  end

  bypassPacket_o[1].tag   = writePRFFlag  ? wrPhyAddr                      : bypassPacket_i[1].tag ;
  bypassPacket_o[1].data  = writePRFFlag  ? registerArray[wrPhyAddr]       : bypassPacket_i[1].data ;
  bypassPacket_o[1].valid = writePRFFlag  ? 1'b1                           : bypassPacket_i[1].valid ;


  phySrc1_rd_o[1]      = consolidateFlag_d1 ? rdPhyAddr : phySrc1Ctrl_i;
end


// PRF is read in the next cycle of obtaining the mapping from AMT
endmodule
