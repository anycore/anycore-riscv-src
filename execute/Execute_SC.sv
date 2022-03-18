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

/* Algorithm

   1. Receive new packet to execute each cycle, if there are ready instructions
      in the Issue Queue.

   2. Execute packet contains following information:
       (.) Opcode
       (.) Source Data-1
       (.) Source Register-1
       (.) Source Data-2
       (.) Source Register-2
       (.) Destination Register
       (.) Active List ID
       (.) Load-Store Queue ID
       (.) Ctiq Tag
       (.) Predicted Target Address (for control inst)
       (.) Predicted Direction      (for branch inst)
       (.) Packet Valid bit

   3. Receive bypass inputs from the previous cycle from all functional units.
      Instruction entering into the Execute should compare its source registers
      to bypassed destination registers.
        If, comparision result is true pick the bypassed value.

   4. Bypassed data should contain following information:
       (.) Destination Register
       (.) Output Data

   5. [ For current implementation Load instruction's RSR latency is same as Load execution
        latency plus register file read latency. This means load dependent instructions will not
        have back to back execution in best case. ]

      For Load dependent instructions, source tag should be compared against the load destination.
      If there is a match and the disambi stall signal is high, the instruction should be terminated.
      And the corresponding scheduled bit for the load dependent instruction in the issue queue
      should be set to 0.

   6. Output of a global Functional unit would be:
       (12) Destination Valid
       (11) Executed
       (10) Exception
       (9)  Mispredict
       (8)  Destination Register
       (7)  Active List ID
       (6)  Output Data
       (4)  Load-Store Queue ID
       (2)  Ctiq Tag
       (1)  Computed Target Address
       (0)  Computed Direction

***************************************************************************/

module Execute_SC #(
    parameter  SIMPLE  = 1,
    parameter  COMPLEX = 0,
    parameter  FP      = 0
)(
    input                               clk,
    input                               reset,
    input                               recoverFlag_i,
    output                              toggleFlag_o,

    input  fuPkt                        exePacket_i,

    /* all the bypasses coming from the different pipes */
    input  bypassPkt                    bypassPacket_i [0:`ISSUE_WIDTH-1],
    input  [`CSR_WIDTH-1:0]		csr_frm_i,	//Changes: Mohit (Register for dynamic rounding mode)

    output wbPkt                        wbPacket_o,
    
    output fpexcptPkt	                fpExcptPacket_o	//Changes: Mohit (FP_Exception flag packet for execution exceptions like Overflow, Underflow, Inexact etc.)
    );


/* Defining wire and regs for combinational logic. */
wire [`SIZE_DATA-1:0]                   src1Data;
wire [`SIZE_DATA-1:0]                   src2Data;

/* Following checks for any data forwarding required for the incoming
 *  functional unit packet.
 * Destination register of each bypassed packet is compared with source
 * registers of each FU packet. If there is a match then bypassed
 * data is forwarded to the corresponding functional unit. */

ForwardCheck src1Bypass (
    .srcReg_i                           (exePacket_i.phySrc1),
    .srcData_i                          (exePacket_i.src1Data),

    .bypassPacket_i                     (bypassPacket_i),

    .dataOut_o                          (src1Data)
    );

ForwardCheck src2Bypass (
    .srcReg_i                           (exePacket_i.phySrc2),
    .srcData_i                          (exePacket_i.src2Data),

    .bypassPacket_i                     (bypassPacket_i),

    .dataOut_o                          (src2Data)
    );

wire [`SIZE_PC-1:0] tp_pc;
assign tp_pc = exePacket_i.pc;

wire toggleFlag_S;
wire toggleFlag_C;
wire toggleFlag_F;




generate

/* This pipe handles both simple and complex instructions */
if ((SIMPLE == 1) && (COMPLEX == 1) && (FP == 1))
begin:simple_complex_fp

  fuPkt                               exePacket_S;
  fuPkt                               exePacket_C;
  fuPkt                               exePacket_F;
  wbPkt                               wbPacket_S;
  wbPkt                               wbPacket_C;
  wbPkt                               wbPacket_F;
  
  /* Create a simple and complex packet from exePacket_i. 
   * Invalidate one based on exePacket_i.isSimple */
  Demux3 demux (
  
      .input_1                            (exePacket_i),
  
      .output_1                           (exePacket_S),
      .output_2                           (exePacket_C),
      .output_3                           (exePacket_F)
  );
  
  
  wire [`SIZE_DATA-1:0]                  result_S;
  exeFlgs                                flags_S;
  
  wire [`SIZE_DATA-1:0]                  result_C;
  exeFlgs                                flags_C;
  
  
  Simple_ALU salu (
      .exePacket_i                        (exePacket_S),
      .toggleFlag_o                       (toggleFlag_S),
      .data1_i                            (src1Data),
      .data2_i                            (src2Data),
      .immd_i                             (exePacket_S.immed),
      .inst_i                             (exePacket_S.inst),
      .wbPacket_o                         (wbPacket_S)
  );
  
  
  // 08/27/2013 RBRC Imported DW based complex ALU from 3dIC 
  // This has a multicycle complex ALU and is great
  // for achieving high frequencies.
  Complex_ALU #(
      .DEPTH  (`FU1_LATENCY)
  )
      calu (
  
      .clk                                (clk),
      .reset                              (reset),
      .toggleFlag_o                       (toggleFlag_C),
      .recoverFlag_i                      (recoverFlag_i),
  
      .exePacket_i                        (exePacket_C),
      .data1_i                            (src1Data),
      .data2_i                            (src2Data),
      .immd_i                             (exePacket_C.immed),
      .inst_i                             (exePacket_C.inst),
      .wbPacket_o                         (wbPacket_C)
  );

  fpexcptPkt	 	    fpExcptPacket_temp; //Changes: Mohit (FP_exception output from FP-ALU)
  
  FP_ALU falu(
        /*-----------Changes: fpnew----------------*/
        .clk_i                            (clk),
        .rst_ni                           (reset),
        /*-----------------------------------------*/
        .exePacket_i                      (exePacket_F),
        .toggleFlag_o                     (toggleFlag_F),
        .data1_i                          (src1Data),
        .data2_i                          (src2Data),
        .csr_frm_i                        (csr_frm_i),	//Changes: Mohit (Rounding mode)
        .wbPacket_o                       (wbPacket_F),
        .fpExcptPacket_o                  (fpExcptPacket_temp)	//Changes: Mohit (FP_Exception like Overflow, Underflow, Inexact etc.)
    );

  
  /* Send the valid packet to writeback */
  Mux3 mux (
  
      .input_1                            (wbPacket_S),
      .input_2                            (wbPacket_C),
      .input_3                            (wbPacket_F),
  
      .output_1                           (wbPacket_o)
  );
  
  assign toggleFlag_o = toggleFlag_S | toggleFlag_C | toggleFlag_F;

  assign fpExcptPacket_o = fpExcptPacket_temp;	//Changes: Mohit (FP_Exception like Overflow, Underflow, Inexact etc.)
end


/* This pipe handles both simple and complex instructions */
else if ((SIMPLE == 1) && (COMPLEX == 1))
begin:simple_complex

  fuPkt                               exePacket_S;
  fuPkt                               exePacket_C;
  wbPkt                               wbPacket_S;
  wbPkt                               wbPacket_C;
  
  /* Create a simple and complex packet from exePacket_i. 
   * Invalidate one based on exePacket_i.isSimple */
  Demux demux (
  
      .input_1                            (exePacket_i),
  
      .output_1                           (exePacket_S),
      .output_2                           (exePacket_C)
  );
  
  
  wire [`SIZE_DATA-1:0]                  result_S;
  exeFlgs                                flags_S;
  
  wire [`SIZE_DATA-1:0]                  result_C;
  exeFlgs                                flags_C;
  
  
  Simple_ALU salu (
      .exePacket_i                        (exePacket_S),
      .toggleFlag_o                       (toggleFlag_S),
      .data1_i                            (src1Data),
      .data2_i                            (src2Data),
      .immd_i                             (exePacket_S.immed),
      .inst_i                             (exePacket_S.inst),
      .wbPacket_o                         (wbPacket_S)
  );
  
  
  // 08/27/2013 RBRC Imported DW based complex ALU from 3dIC 
  // This has a multicycle complex ALU and is great
  // for achieving high frequencies.
  Complex_ALU #(
      .DEPTH  (`FU1_LATENCY)
  )
      calu (
  
      .clk                                (clk),
      .reset                              (reset),
      .toggleFlag_o                       (toggleFlag_C),
      .recoverFlag_i                      (recoverFlag_i),
  
      .exePacket_i                        (exePacket_C),
      .data1_i                            (src1Data),
      .data2_i                            (src2Data),
      .immd_i                             (exePacket_C.immed),
      .inst_i                             (exePacket_C.inst),
      .wbPacket_o                         (wbPacket_C)
  );
  
  
  /* Send the valid packet to writeback */
  Mux mux (
  
      .input_1                            (wbPacket_S),
      .input_2                            (wbPacket_C),
  
      .output_1                           (wbPacket_o)
  );
  
  assign toggleFlag_o = toggleFlag_S | toggleFlag_C;
  
  assign fpExcptPacket_o = 64'h0;	//Changes: Mohit (Assigned 0 when no FP_ALU)
end


/* This pipe only handles simple instructions */
else if (SIMPLE == 1)
begin:simple

  wire [`SIZE_DATA-1:0]                  result;
  exeFlgs                                flags;
  
  
  Simple_ALU salu (
      .exePacket_i                        (exePacket_i),
      .toggleFlag_o                       (toggleFlag_S),
      .data1_i                            (src1Data),
      .data2_i                            (src2Data),
      .immd_i                             (exePacket_i.immed),
      .inst_i                             (exePacket_i.inst),
      .wbPacket_o                         (wbPacket_o)
  );
  
  assign toggleFlag_o = toggleFlag_S;
  assign fpExcptPacket_o = 64'h0;	//Changes: Mohit (Assigned 0 when no FP_ALU)
end


/* This pipe only handles complex instructions */
else if (COMPLEX == 1)
begin:complex

  wire [`SIZE_DATA-1:0]                  result;
  exeFlgs                                flags;
  
  
  // 08/27/2013 RBRC Imported DW based complex ALU from 3dIC 
  // This has a multicycle complex ALU and is great
  // for achieving high frequencies.
  Complex_ALU #(
      .DEPTH  (`FU1_LATENCY)
  )
      calu (
  
      .clk                                (clk),
      .reset                              (reset),
      .toggleFlag_o                       (toggleFlag_C),
      .recoverFlag_i                      (recoverFlag_i),
  
      .exePacket_i                        (exePacket_i),
      .data1_i                            (src1Data),
      .data2_i                            (src2Data),
      .immd_i                             (exePacket_i.immed),
      .inst_i                             (exePacket_i.inst),
      .wbPacket_o                         (wbPacket_o)
  );
  
  assign toggleFlag_o = toggleFlag_C;
  assign fpExcptPacket_o = 64'h0;	//Changes: Mohit (Assigned 0 when no FP_ALU)
end
endgenerate


endmodule
