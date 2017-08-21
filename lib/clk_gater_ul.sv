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

`ifdef SIM
  primitive udp_tlat (out, in, hold, clr_, set_, NOTIFIER);
     output out;  
     input  in, hold, clr_, set_, NOTIFIER;
     reg    out;
  
     table
  
  // in  hold  clr_   set_  NOT  : Qt : Qt+1
  //
     1  0   1   ?   ?   : ?  :  1  ; // 
     0  0   ?   1   ?   : ?  :  0  ; // 
     1  *   1   ?   ?   : 1  :  1  ; // reduce pessimism
     0  *   ?   1   ?   : 0  :  0  ; // reduce pessimism
     *  1   ?   ?   ?   : ?  :  -  ; // no changes when in switches
     ?  ?   ?   0   ?   : ?  :  1  ; // set output
     ?  1   1   *   ?   : 1  :  1  ; // cover all transistions on set_
     1  ?   1   *   ?   : 1  :  1  ; // cover all transistions on set_
     ?  ?   0   1   ?   : ?  :  0  ; // reset output
     ?  1   *   1   ?   : 0  :  0  ; // cover all transistions on clr_
     0  ?   *   1   ?   : 0  :  0  ; // cover all transistions on clr_
     ?  ?   ?   ?   *   : ?  :  x  ; // any notifier changed
  
     endtable
  endprimitive // udp_tlat

  module TLATNCAX8TF (ECK, E, CK);
  output ECK;
  input  E, CK;
  reg NOTIFIER;
  
  supply1 R, S;
  
    udp_tlat I0 (n0, E, CK, R, S, NOTIFIER);
    and      I1 (ECK, n0, CK);
  endmodule //TLATNCAX8TF

  primitive udp_plat (out, ena, ovrd, clock, NOTIFIER);
     output out;  
     input  ena, ovrd, clock, NOTIFIER;
     reg    out;
  
     table
  
  // ovrd clock ena NOTIFIER : Qt : Qt+1
  //
     1    ?    ?    ?   : ?  :  1  ;
     0    0    0    ?   : ?  :  0  ;
     0    0    1    ?   : ?  :  1  ;
     0    1    ?    ?   : ?  :  -  ;
     ?    1    *    ?   : ?  :  -  ; // no changes when in switches
     ?    ?    ?    *   : ?  :  x  ; // any notifier changed
  
     endtable
  endprimitive // udp_plat

  module POSTICG_X9B_A12TR (ECK, E, SEN, CK);
  output ECK;
  input  E, SEN, CK;
  reg NOTIFIER;
  wire dE;
  wire dSEN;
  wire dCK;
  
  supply1 R, S;
  
    not      I0 (ovrd, SEN);
    udp_plat I1 (n0, ovrd, dCK, dE, NOTIFIER);
    and      I2 (ECK, n0, dCK);
  
  endmodule //POSTICG_X9B_A12TR
`endif   //SIM

module clk_gater_ul(clk_i,clkGated_o,clkEn_i);

  input       clk_i;
  input       clkEn_i;
  output      clkGated_o;
  
  `ifdef PROCESS_45_NM
    `CLK_GATE_CELL_UL latch ( .E(clkEn_i), .CK(clk_i), .ECK(clkGated_o), .SEN(1'b0));
  `else
    `CLK_GATE_CELL_UL latch ( .E(clkEn_i), .CK(clk_i), .ECK(clkGated_o) );
  `endif



endmodule  

