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

module ResetControl(
  input         reset,
  input         clk,

  input         btbRamReady_i,
  input         bpRamReady_i,
  input         rasRamReady_i,
  input         ctiqRamReady_i,
  input         rmtRamReady_i,
  input         flRamReady_i,
  input         iqflRamReady_i,
  input         stqRamReady_i,
  input         ldqRamReady_i,
  input         alRamReady_i,
  input         amtRamReady_i,

  output reg    resetRams_o,
  output reg    resetLogic_o,
  output        resetDone_o
);


//// RST State Machine to Initialize RAM/CAM /////////////

enum {RST_START, RST_RAMS, RST_WAIT, RST_DONE} rstState, rstNextState;

logic [3:0]                 rstCounter;
logic [3:0]                 rstNextCounter;
logic                       allRamsReady;
logic                       allRamsReadyReg;
logic                       resetRams;
logic                       resetLogic;
logic                       resetDone;
logic                       reset_l1;
logic                       reset_l2;

assign allRamsReady = btbRamReady_i   &  
                      bpRamReady_i    &
                      rasRamReady_i   &
                      ctiqRamReady_i  &
                      rmtRamReady_i   &
                      flRamReady_i    &
                      iqflRamReady_i  &
                      stqRamReady_i   &
                      ldqRamReady_i   &
                      alRamReady_i    &
                      amtRamReady_i   ;

assign resetDone_o  = resetDone;

always_ff @(posedge clk)
begin
  reset_l1    <=  reset;
  reset_l2    <=  reset_l1;
end

always_ff @(posedge clk or posedge reset_l2)
begin
  if(reset_l2)
  begin
    rstState        <=  RST_START;
    allRamsReadyReg <=  1'b0;
    rstCounter      <=  4'h0;
    resetRams_o     <=  1'b0;                      
    resetLogic_o    <=  1'b1; // Keep reset asserted before the reset sequence begins                      
  end
  else
  begin
    rstState        <=  rstNextState;
    allRamsReadyReg <=  allRamsReady;
    rstCounter      <=  rstNextCounter;
    resetRams_o     <=  resetRams;                      
    resetLogic_o    <=  resetLogic;                      
  end
end

always_comb
begin
  rstNextState        = rstState;
  rstNextCounter      = 4'h0;      
  resetRams           = 1'b0;
  resetLogic          = 1'b0;
  resetDone           = 1'b0;

  case(rstState)
    RST_START: begin
      rstNextState   = RST_RAMS;
      resetRams      = 1'b1;
    end
    RST_RAMS: begin
      resetRams      = 1'b0;
      resetLogic     = 1'b1;

      rstNextCounter = rstCounter + 1;

      if(rstCounter == 4'hf)
      begin
        rstNextState = RST_WAIT;
      end
    end
    RST_WAIT: begin
      resetRams      = 1'b0;
      resetLogic     = 1'b1;

      if(allRamsReadyReg)
      begin
        rstNextState = RST_DONE;
      end
      else
      begin
        rstNextState = RST_WAIT;
      end
    end
    RST_DONE: begin
      resetDone      = 1'b1;
      rstNextState   = RST_DONE;
    end
  endcase
end


endmodule
