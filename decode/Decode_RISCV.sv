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


module Decode_RISCV (

`ifdef DYNAMIC_CONFIG
    input                             laneActive_i,
`endif

    input  decPkt                     decPacket_i,

    output renPkt                     ibPacket0_o,
    output renPkt                     ibPacket1_o
    );


/* Wires and regs definition for combinational logic. */
wire [`SIZE_INSTRUCTION-1:0]            instruction;
wire [`SIZE_PC-1:0]                     predNPC;
wire [`FUNCT3_HI-`FUNCT3_LO:0]          instFunct3;
wire [`FUNCT5_HI-`FUNCT5_LO:0]          instFunct5;
wire [`FUNCT7_HI-`FUNCT7_LO:0]          instFunct7;
wire [`FUNCT12_HI-`FUNCT12_LO:0]        instFunct12;

wire [`SIZE_IMMEDIATE-1:0]              I_imm;
wire [`SIZE_IMMEDIATE-1:0]              S_imm;
wire [`SIZE_IMMEDIATE-1:0]              SB_imm;
wire [`SIZE_IMMEDIATE-1:0]              U_imm;
wire [`SIZE_IMMEDIATE-1:0]              UJ_imm;

wire [`SIZE_OPCODE_P-1:0]               opcode;
reg                                     invalidate;

reg                                     valid_0;
reg [`SIZE_OPCODE_P-1:0]                opcode_0;
reg [`SIZE_RMT_LOG:0]                   instLogical1_0;
reg [`SIZE_RMT_LOG:0]                   instLogical2_0;
reg [`SIZE_RMT_LOG:0]                   instDest_0;
reg [`SIZE_IMMEDIATE:0]                 instImmediate_0; // Do not use immed field downstream inst is flowing in the packet, so extract whereer required
// Should be SIZE_TARGET and not SIZE_PC
// Difference should be offset when using instTarget_0
// RBRC: 07/11/2013
reg [`SIZE_PC-1:0]                      instTarget_0; 
reg [`INST_TYPES_LOG-1:0]               instFU_0;
reg [`LDST_TYPES_LOG-1:0]               instldstSize_0;
reg                                     instLoad_0;
reg                                     instStore_0;
reg                                     instCSR_0;
reg                                     instScall_0;
reg                                     instSbreak_0;
reg                                     instSret_0;
reg                                     instSkipIQ_0;
reg [`EXCEPTION_CAUSE_LOG-1:0]               instExceptionCause_0; 
reg                                     instException_0;

always_comb
begin
    ibPacket0_o.seqNo          = decPacket_i.seqNo;
    ibPacket0_o.exceptionCause = decPacket_i.exception ? decPacket_i.exceptionCause : instExceptionCause_0;
    ibPacket0_o.exception      = decPacket_i.exception | instException_0;
    ibPacket0_o.logDest        = instDest_0[`SIZE_RMT_LOG:1]; 
    ibPacket0_o.logDestValid   = instDest_0[0];
    ibPacket0_o.logSrc1        = instLogical1_0[`SIZE_RMT_LOG:1]; 
    ibPacket0_o.logSrc1Valid   = instLogical1_0[0];
    ibPacket0_o.logSrc2        = instLogical2_0[`SIZE_RMT_LOG:1]; 
    ibPacket0_o.logSrc2Valid   = instLogical2_0[0];
    ibPacket0_o.pc             = decPacket_i.pc;
    ibPacket0_o.inst           = decPacket_i.inst;
    ibPacket0_o.fu             = instFU_0;
    ibPacket0_o.immed          = instImmediate_0[`SIZE_IMMEDIATE:1];
    ibPacket0_o.immedValid     = instImmediate_0[0];
    ibPacket0_o.isLoad         = instLoad_0;
    ibPacket0_o.isStore        = instStore_0;
    ibPacket0_o.isCSR          = instCSR_0;
    ibPacket0_o.isScall        = instScall_0;
    ibPacket0_o.isSbreak       = instSbreak_0;
    ibPacket0_o.isSret         = instSret_0;
    ibPacket0_o.skipIQ         = instSkipIQ_0;
    ibPacket0_o.ldstSize       = instldstSize_0;
    ibPacket0_o.ctrlType       = decPacket_i.ctrlType;
    ibPacket0_o.ctiID          = decPacket_i.ctiID;
    ibPacket0_o.predNPC        = instTarget_0; //instTarget_0 is `SIZE_TARGET wide
    ibPacket0_o.predDir        = decPacket_i.predDir;
    ibPacket0_o.valid          = valid_0;
    ibPacket1_o                = 0 ;
end


/* Following extracts instructions from the packet, follows by opcode extraction
 * from the instructions.
 */
assign instruction           = decPacket_i.inst;
assign predNPC               = decPacket_i.predNPC;

assign opcode       = instruction[`SIZE_OPCODE_P-1:0];
assign instFunct3   = instruction[`FUNCT3_HI:`FUNCT3_LO];
assign instFunct5   = instruction[`FUNCT5_HI:`FUNCT5_LO];
assign instFunct7   = instruction[`FUNCT7_HI:`FUNCT7_LO];
assign instFunct12  = instruction[`FUNCT12_HI:`FUNCT12_LO];

/*Assign Immediates as wires here, and use them as needed while  decoding 
  instructions. 
  Note : The immediates are being sign-extended upto only 
  20 bits, the reminder of the sign extension happens in execute, 
  this will minimize packet size. U and UJ type will be shifted  left to
  fill LSB (in UJ) and 12 LSB bits (in U) in the Execute stage. This can
  be done as full instruction will be available in fuPkt, not just major
  opcode.  This will allow shrinking immediate to 20 bit as opposed to 32 */

assign I_imm  = {{21{instruction[31]}},instruction[30:20]};
assign S_imm  = {{21{instruction[31]}},instruction[30:25],instruction[11:7]};
assign SB_imm = {{20{instruction[31]}},instruction[7],instruction[30:25],instruction[11:8],1'b0};
assign U_imm  = {instruction[31:20],instruction[19:12],12'h000};
assign UJ_imm = {instruction[31],instruction[19:12],instruction[20],instruction[30:25],instruction[24:21],1'b0};


/* Following extracts source registers, destination register, immediate field and
 * target address from instruction. Bit-0 of each wire is set to 1 if the field
 * is valid for the corresponding instruction.
 */

always @(*)
begin
  invalidate       = 1'h0;

  valid_0          = decPacket_i.valid;
  opcode_0         = opcode;
  instTarget_0     = 0;
  instFU_0         = 0;
  instLoad_0       = 0;
  instStore_0      = 0;
  instCSR_0        = 0;
  instSkipIQ_0     = 0;
  instScall_0      = 0;
  instSbreak_0     = 0;
  instSret_0       = 0;
  instExceptionCause_0    = 0;
  instException_0    = 0;

  instLogical1_0   = {instruction[`RS1_HI:`RS1_LO],1'b0};
  instLogical2_0   = {instruction[`RS2_HI:`RS2_LO],1'b0};
  instDest_0       = {instruction[`RD_HI:`RD_LO],1'b0};
  instImmediate_0  = 0;

  instldstSize_0 = instruction[`FUNCT3_SIZE_HI:`FUNCT3_SIZE_LO];
  
  case(opcode)

  `OP_JAL: begin
          instDest_0[0]      = 1'b1;
          instTarget_0       = decPacket_i.predNPC;
          instImmediate_0    = {UJ_imm,1'b1};
          instFU_0           = `CONTROL_TYPE;
        end

 `OP_JALR: begin
          instLogical1_0[0]  = 1'b1;
          instDest_0[0]      = 1'b1;
          instTarget_0       = decPacket_i.predNPC;
          instImmediate_0    = {I_imm,1'b1};
          instFU_0           = `CONTROL_TYPE;
        end

 `OP_BRANCH: begin
          instLogical1_0[0]  = 1'b1;
          instLogical2_0[0]  = 1'b1;
          instTarget_0       = decPacket_i.predNPC;
          instImmediate_0    = {SB_imm,1'b1};
          instFU_0           = `CONTROL_TYPE;
        end

 `OP_AUIPC: begin
          instDest_0[0]      = 1'b1;
          instImmediate_0    = {U_imm,1'b1};
          instFU_0           = `SIMPLE_TYPE;
        end

 `OP_LOAD : begin
          instLogical1_0[0]  = 1'b1;
          instDest_0[0]      = 1'b1;
          instImmediate_0    = {I_imm,1'b1};
          instFU_0           = `MEMORY_TYPE;
          instLoad_0         = 1'b1;
        end

 `OP_LOAD_FP : begin
          instLogical1_0[0]  = 1'b1;
          instDest_0[0]      = 1'b1;
          instDest_0[`SIZE_RMT_LOG:1]     = instruction[`RD_HI:`RD_LO] + 32;
          instImmediate_0    = {I_imm,1'b1};
          instFU_0           = `MEMORY_TYPE;
          instLoad_0         = 1'b1;
        end

 `OP_STORE_FP : begin
          instLogical1_0[0]  = 1'b1;
          instLogical2_0[0]  = 1'b1;
          instImmediate_0    = {S_imm,1'b1};
          instFU_0           = `MEMORY_TYPE;
          instLoad_0         = 1'b1;
        end

 `OP_STORE : begin
          instLogical1_0[0]  = 1'b1;
          instLogical2_0[0]  = 1'b1;
          instImmediate_0    = {S_imm,1'b1};
          instFU_0           = `MEMORY_TYPE;
          instStore_0        = 1'b1;
        end

 `OP_OP_IMM: begin
          instLogical1_0[0]  = 1'b1;
          instDest_0[0]      = 1'b1;
          instImmediate_0    = {I_imm,1'b1};
          instFU_0           = `SIMPLE_TYPE;
        end
   
 `OP_OP_IMM_32: begin
          instLogical1_0[0]  = 1'b1;
          instDest_0[0]      = 1'b1;
          instImmediate_0    = {I_imm,1'b1};
          instFU_0           = `SIMPLE_TYPE;
        end

 `OP_OP: begin
          instLogical1_0[0]  = 1'b1;
          instLogical2_0[0]  = 1'b1;
          instDest_0[0]      = 1'b1;
          instFU_0           = `SIMPLE_TYPE;
          if(instFunct7 == `FN7_MUL_DIV)
            instFU_0           = `COMPLEX_TYPE;
        end

 `OP_OP_32: begin
          instLogical1_0[0]  = 1'b1;
          instLogical2_0[0]  = 1'b1;
          instDest_0[0]      = 1'b1;
          instFU_0           = `SIMPLE_TYPE;
          if(instFunct7 == `FN7_MUL_DIV)
            instFU_0           = `COMPLEX_TYPE;
        end

 `OP_LUI: begin
          instDest_0[0]      = 1'b1;
          instImmediate_0    = {U_imm,1'b1}; 
          instFU_0           = `SIMPLE_TYPE;
        end

 `OP_OP_FP: begin
          case (instFunct5)
            `FN5_FADD,    
            `FN5_FSUB,    
            `FN5_FMUL,    
            `FN5_FDIV,
            `FN5_FSGNJ,    
            `FN5_FMIN_MAX:
             begin
                instLogical1_0[`SIZE_RMT_LOG:1] = instruction[`RS1_HI:`RS1_LO] + 32; //Offset for FP reg namespace
                instLogical2_0[`SIZE_RMT_LOG:1] = instruction[`RS2_HI:`RS2_LO] + 32;
                instDest_0[`SIZE_RMT_LOG:1]     = instruction[`RD_HI:`RD_LO] + 32;
                instLogical1_0[0]  = 1'b1;
                instLogical2_0[0]  = 1'b1;
                instDest_0[0]      = 1'b1;
                instFU_0           = `FP_TYPE;
             end

             `FN5_FCOMP:
              begin
                instLogical1_0[`SIZE_RMT_LOG:1] = instruction[`RS1_HI:`RS1_LO] + 32; //Offset for FP reg namespace
                instLogical2_0[`SIZE_RMT_LOG:1] = instruction[`RS2_HI:`RS2_LO] + 32;
                instDest_0[`SIZE_RMT_LOG:1]     = instruction[`RD_HI:`RD_LO] ;
                instLogical1_0[0]  = 1'b1;
                instLogical2_0[0]  = 1'b1;
                instDest_0[0]      = 1'b1;
                instFU_0           = `FP_TYPE;
              end

              `FN5_FSQRT:
              begin
                instLogical1_0[`SIZE_RMT_LOG:1] = instruction[`RS1_HI:`RS1_LO] + 32; //Offset for FP reg namespace
                instDest_0[`SIZE_RMT_LOG:1]     = instruction[`RD_HI:`RD_LO] + 32;
                instLogical1_0[0]  = 1'b1;
                instDest_0[0]      = 1'b1;
                instFU_0           = `FP_TYPE;
              end

             `FN5_FCVT_I2FP,
             `FN5_FMV_I2FP:
              begin
                instLogical1_0[`SIZE_RMT_LOG:1] = instruction[`RS1_HI:`RS1_LO] ; //Offset for FP reg namespace
                instDest_0[`SIZE_RMT_LOG:1]     = instruction[`RD_HI:`RD_LO] + 32;
                instLogical1_0[0]  = 1'b1;
                instDest_0[0]      = 1'b1;
                instFU_0           = `FP_TYPE;
              end

             `FN5_FCVT_FP2I,
             `FN5_FMV_FP2I:
              begin
                instLogical1_0[`SIZE_RMT_LOG:1] = instruction[`RS1_HI:`RS1_LO] + 32 ; //Offset for FP reg namespace
                instDest_0[`SIZE_RMT_LOG:1]     = instruction[`RD_HI:`RD_LO] ;
                instLogical1_0[0]  = 1'b1;
                instDest_0[0]      = 1'b1;
                instFU_0           = `FP_TYPE;
              end
            
          endcase
        end

 `OP_SYSTEM: begin
           instCSR_0        = 1'b1;
           case (instFunct3)

               `FN3_SC_SB:
               begin
                 instFU_0           = `CONTROL_TYPE;
                 //instSkipIQ_0       = 1'b1;
                 case(instFunct12)
                   `FN12_SCALL : begin
                     instScall_0  = 1'b1;
                     instExceptionCause_0    = `CAUSE_SYSCALL;
                     instException_0    = 1'b1;
                   end
                   `FN12_SBREAK: begin
                     instSbreak_0 = 1'b1;
                     instExceptionCause_0    = `CAUSE_BREAKPOINT;
                     instException_0    = 1'b1;
                   end
                   `FN12_SRET  : begin
                     instSret_0   = 1'b1;
                     instCSR_0    = 1'b0; //Do not read or write any CSRs, neither is it dispatched atomically
                   end
                  endcase
               end

               `FN3_RW:
               begin
                 instLogical1_0[0]  = 1'b1;
                 instDest_0[0]      = 1'b1;
                 instFU_0           = `CONTROL_TYPE;
               end

               `FN3_RW_IMM:
               begin
                 instImmediate_0    = {I_imm,1'b1};
                 instDest_0[0]      = 1'b1;
                 instFU_0           = `CONTROL_TYPE;
               end

               `FN3_SET:
               begin
                 instLogical1_0[0]  = 1'b1;
                 instDest_0[0]      = 1'b1;
                 instFU_0           = `CONTROL_TYPE;
               end

               `FN3_SET_IMM:
               begin
                 instImmediate_0    = {I_imm,1'b1};
                 instDest_0[0]      = 1'b1;
                 instFU_0           = `CONTROL_TYPE;
               end

               `FN3_CLR:
               begin
                 instLogical1_0[0]  = 1'b1;
                 instDest_0[0]      = 1'b1;
                 instFU_0           = `CONTROL_TYPE;
               end

               `FN3_CLR_IMM:
               begin
                 instImmediate_0    = {I_imm,1'b1};
                 instDest_0[0]      = 1'b1;
                 instFU_0           = `CONTROL_TYPE;
               end
            endcase
           end

 // FENCE instructions
 `OP_MISC_MEM: begin
           instCSR_0        = 1'b1;
           instFU_0         = `CONTROL_TYPE;
          end

 default: begin
          //valid_0         = 1'h0;
          //$display("\nWARNING: PC:%x Opcode %x Not Found in Decode Unit",decPacket_i.pc,opcode);
         //$finish;
          end
  endcase

// This takes care of logical register 0 (X0) always fixed at 0
// and never being renamed or written to by any instruction.
if(instDest_0[`SIZE_RMT_LOG:1] == 0)
    instDest_0 = 0;
end

endmodule

