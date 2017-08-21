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
 1.
 2. flags_o has following fields:
    (.) Executed  :"bit-2"
    (.) Exception :"bit-1"
    (.) Mispredict:"bit-0"
***************************************************************************/


module Ctrl_ALU (
    input  [`SIZE_DATA-1:0]        data1_i,
    input  [`SIZE_DATA-1:0]        data2_i,
    input  [`SIZE_IMMEDIATE-1:0]   immd_i,
    input  [`SIZE_INSTRUCTION-1:0] inst_i,
    input  [`SIZE_PC-1:0]          predNPC_i,
    input                          predDir_i,
    input  [`SIZE_PC-1:0]          pc_i,
    input                          destValid_i,

    output [`SIZE_PC-1:0]          result_o,
    output [`CSR_WIDTH-1:0]   csrWrData_o,
    output [`CSR_WIDTH_LOG-1:0]     csrWrAddr_o,
    output                         csrWrEn_o,
    output [`SIZE_PC-1:0]          nextPC_o,
    output                         direction_o,
    output exeFlgs                 flags_o
    );



reg  [`SIZE_PC-1:0]              result;
reg  [`CSR_WIDTH-1:0]       csrWrData;
reg  [`CSR_WIDTH_LOG-1:0]         csrWrAddr;
reg                              csrWrEn   ;
reg  [`SIZE_PC-1:0]              nextPC;
reg                              direction;
exeFlgs                          flags;


assign result_o                = result;
assign csrWrData_o             = csrWrData;
assign csrWrAddr_o             = csrWrAddr;
assign csrWrEn_o               = csrWrEn;
assign nextPC_o                = nextPC;
assign direction_o             = direction;
assign flags_o                 = flags;


always_comb
begin:ALU_OPERATION
    reg  [`SIZE_PC-1:0]       pc_p4;
    reg  [`SIZE_PC-1:0]       pc_pImmd;
    reg  [`SIZE_PC-1:0]       data1_pImmd;
    reg  [`SIZE_DATA-1:0]     sign_ex_immd;
    reg  [`SIZE_OPCODE_P-1:0] opcode;
    reg  [`FUNCT3_HI-`FUNCT3_LO:0] fn3;
    reg  [`FUNCT12_HI-`FUNCT12_LO:0] fn12;
    reg  [`RS1_HI-`RS1_LO:0]  rs1;
    reg                       mispredict;
    reg  [`SIZE_DATA-1:0]     data1_or_pc;

    /*Sign-extending immediate field from the exePacket*/

    sign_ex_immd   = {{(`SIZE_DATA-`SIZE_IMMEDIATE){immd_i[`SIZE_IMMEDIATE-1]}}, immd_i};
    
    /*Extracting major opcode */
    opcode      = inst_i[`SIZE_OPCODE_P-1:0]; 
    fn3         = inst_i[`FUNCT3_HI:`FUNCT3_LO]; 
    mispredict  = 1'b0;  //Default to avoid latch RBRC: 07/12/2013
    pc_p4       = pc_i + 4;

    //data1_or_pc = (opcode == `OP_JALR) ? data1_i : pc_i ; //LSB to be ignored for JALR
    //pc_pImmd    = data1_or_pc + sign_ex_immd;
    pc_pImmd    = pc_i + sign_ex_immd;
    data1_pImmd = data1_i + sign_ex_immd;
    fn12        = inst_i[`FUNCT12_HI:`FUNCT12_LO]; 
    rs1         = inst_i[`RS1_HI:`RS1_LO];
     
    result    = 0;
    nextPC    = 0;
    direction = 0;
    flags     = 0;
    csrWrData = 0; 
    csrWrAddr = 0; 
    csrWrEn   = 1'h0; 

    case(opcode)

        `OP_JAL:
        begin
            direction       = 1'h1;
            result          = pc_p4;
            nextPC          = predNPC_i;
            flags.executed  = 1'h1;
            //flags.destValid = (inst_i[11:7] == 5'b0) ? 1'b0 : 1'b1;
            flags.destValid = destValid_i;
            flags.isControl = 1'h1;
        end

        `OP_JALR:
        begin
            direction        = 1'h1;
            result           = pc_p4;
            nextPC           = {data1_pImmd[`SIZE_PC-1:1],1'b0};
            mispredict       = (nextPC != predNPC_i);
            //mispredict       = 1'b0;
            flags.mispredict = mispredict;
            flags.executed   = 1'h1;
            //flags.destValid = (inst_i[11:7] == 5'b0) ? 1'b0 : 1'b1;
            flags.destValid = destValid_i;
            flags.isControl  = 1'h1;
        end

        `OP_BRANCH:
         begin
         case (fn3)

            `FN3_BEQ:
            begin
                direction         = (data1_i == data2_i);
                nextPC            = (direction) ? pc_pImmd : pc_p4;
                mispredict        = (direction != predDir_i);
                flags.mispredict  = mispredict;
                flags.executed    = 1'h1;
                flags.isPredicted = 1'h1;
                flags.isControl   = 1'h1;
            end

            `FN3_BNE:
            begin
                direction         = (data1_i != data2_i);
                nextPC            = (direction) ? pc_pImmd : pc_p4;
                mispredict        = (direction != predDir_i);
                flags.mispredict  = mispredict;
                flags.executed    = 1'h1;
                flags.isPredicted = 1'h1;
                flags.isControl   = 1'h1;
            end

            `FN3_BLT:
            begin
                direction         = ($signed(data1_i) < $signed(data2_i));
                nextPC            = (direction) ? pc_pImmd : pc_p4;
                mispredict        = (direction != predDir_i);
                flags.mispredict  = mispredict;
                flags.executed    = 1'h1;
                flags.isPredicted = 1'h1;
                flags.isControl   = 1'h1;
            end
            
            `FN3_BGE:
            begin
                direction         = ($signed(data1_i) >= $signed(data2_i));
                nextPC            = (direction) ? pc_pImmd : pc_p4;
                mispredict        = (direction != predDir_i);
                flags.mispredict  = mispredict;
                flags.executed    = 1'h1;
                flags.isPredicted = 1'h1;
                flags.isControl   = 1'h1;
            end
            
            
            `FN3_BLTU:
            begin
                direction         = (data1_i < data2_i);
                nextPC            = (direction) ? pc_pImmd : pc_p4;
                mispredict        = (direction != predDir_i);
                flags.mispredict  = mispredict;
                flags.executed    = 1'h1;
                flags.isPredicted = 1'h1;
                flags.isControl   = 1'h1;
            end
            
            `FN3_BGEU:
            begin
                direction         = (data1_i >= data2_i);
                nextPC            = (direction) ? pc_pImmd : pc_p4;
                mispredict        = (direction != predDir_i);
                flags.mispredict  = mispredict;
                flags.executed    = 1'h1;
                flags.isPredicted = 1'h1;
                flags.isControl   = 1'h1;
            end

        endcase // case (fn3)
        end

        `OP_SYSTEM:
        begin 
        case (fn3)

            `FN3_SC_SB:
            begin
            case (fn12)

               //`FN12_SCALL:
               //begin
               //    flags.executed          = 1'h1;
               //    flags.exception         = 1'h1;
               //end

               //`FN12_SBREAK:
               //begin
               //    flags.executed          = 1'h1;
               //    flags.exception         = 1'h1;
               //end

               `FN12_SRET:
               begin
                   flags.executed          = 1'h1;
               end
            endcase
            end

            `FN3_SET:
            begin
            case (fn12)

               `CSR_CYCLE,`CSR_TIME,`CSR_INSTRET,`CSR_FCSR,`CSR_FRM,`CSR_FFLAGS:
               begin
                   result                  = {{(`SIZE_PC-`CSR_WIDTH){1'b0}},data2_i};
                   flags.executed          = 1'h1;
                   flags.destValid         = destValid_i;
               end

               `CSR_CYCLEH,`CSR_TIMEH,`CSR_INSTRETH:
               begin
                   result                  = data2_i[`SIZE_DATA-1:32]; 
                   flags.executed          = 1'h1;
                   flags.destValid         = destValid_i;
               end

                `CSR_FCSR:
               begin
                   result                  = data2_i; 
                   csrWrData               = data1_i; 
                   csrWrAddr               = `CSR_FCSR; 
                   csrWrEn                 = 1'h1; 
                   flags.executed          = 1'h1;
                   flags.destValid         = destValid_i;
               end

               `CSR_FRM:
               begin
                   result                  = data2_i; 
                   csrWrData               = data1_i; 
                   csrWrAddr               = `CSR_FRM; 
                   csrWrEn                 = 1'h1; 
                   flags.executed          = 1'h1;
                   flags.destValid         = destValid_i;
               end

               `CSR_FFLAGS:
               begin
                   result                  = data2_i; 
                   csrWrData               = data1_i; 
                   csrWrAddr               = `CSR_FFLAGS; 
                   csrWrEn                 = 1'h1; 
                   flags.executed          = 1'h1;
                   flags.destValid         = destValid_i;
               end
          
               default:
               begin
                   result                  = {{(`SIZE_PC-`CSR_WIDTH){1'b0}},data2_i}; 
                   csrWrData               = (data2_i | data1_i); 
                   csrWrAddr               = fn12; 
                   csrWrEn                 = 1'h1; 
                   flags.executed          = 1'h1;
                   flags.destValid         = destValid_i;
               end
            endcase
            end
            
            `FN3_CLR:
            begin
              result                  = {{(`SIZE_PC-`CSR_WIDTH){1'b0}},data2_i}; 
              csrWrData               = (data2_i & ~data1_i); 
              csrWrAddr               = fn12; 
              csrWrEn                 = 1'h1; 
              flags.executed          = 1'h1;
              flags.destValid         = destValid_i;
            end

            `FN3_RW:
            begin
              result                  = {{(`SIZE_PC-`CSR_WIDTH){1'b0}},data2_i}; 
              csrWrData               = data1_i; 
              csrWrAddr               = fn12; 
              csrWrEn                 = 1'h1; 
              flags.executed          = 1'h1;
              flags.destValid         = destValid_i;
            end

            //TODO:This is just a placeholder for these instructions. Needs modification in regread to get src2 instead of data2 for IMM type instructions. 
            `FN3_SET_IMM:
            begin
              result                  = {{(`SIZE_PC-`CSR_WIDTH){1'b0}},data2_i}; 
              csrWrData               = (data2_i | rs1); 
              csrWrAddr               = fn12; 
              csrWrEn                 = 1'h1; 
              flags.executed          = 1'h1;
              flags.destValid         = 1'h1;
            end

            `FN3_CLR_IMM:
            begin
              result                  = {{(`SIZE_PC-`CSR_WIDTH){1'b0}},data2_i}; 
              csrWrData               = (data2_i & ~rs1); 
              csrWrAddr               = fn12; 
              csrWrEn                 = 1'h1; 
              flags.executed          = 1'h1;
              flags.destValid         = destValid_i;
            end

            `FN3_RW_IMM:
            begin
              result                  = {{(`SIZE_PC-`CSR_WIDTH){1'b0}},data2_i}; 
              csrWrData               = data1_i; 
              csrWrAddr               = fn12; 
              csrWrEn                 = 1'h1; 
              flags.executed          = 1'h1;
              flags.destValid         = destValid_i;
            end
         endcase
        end

        `OP_MISC_MEM:
        begin 
          flags.executed          = 1'h1;
        end
        // NOTE: Need this default to make the case statement
        // full case and stopping synthesis from screwing up
        // RBRC
        default:
        begin
        end
    endcase
end



endmodule
