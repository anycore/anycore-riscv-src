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
 1. result_o contains the result of the arithmetic operation.
 2. flags has following fields:
     (.) Executed  :"bit-2"
     (.) Exception :"bit-1"
     (.) Mispredict:"bit-0"
***************************************************************************/


module Simple_ALU (

    input  fuPkt                     exePacket_i,
    output reg                       toggleFlag_o, 

    input  [`SIZE_DATA-1:0]          data1_i,
    input  [`SIZE_DATA-1:0]          data2_i,
    input  [`SIZE_IMMEDIATE-1:0]     immd_i,
    input  [`SIZE_INSTRUCTION-1:0]   inst_i,

    output wbPkt                     wbPacket_o
    );


reg  [`SIZE_DATA-1:0]               result;
exeFlgs                          flags;


always_comb
begin
    wbPacket_o          = 0;

    wbPacket_o.seqNo    = exePacket_i.seqNo;
    wbPacket_o.flags    = flags;
    wbPacket_o.logDest  = exePacket_i.logDest;
    wbPacket_o.phyDest  = exePacket_i.phyDest;
    wbPacket_o.destData = result;
    wbPacket_o.alID     = exePacket_i.alID;
    wbPacket_o.valid    = exePacket_i.valid;
end

always_comb
begin:ALU_OPERATION
    reg         [`SIZE_DATA-1:0]              sign_ex_immd;
    reg signed  [`SIZE_DATA-1:0]              data_signed1;
    reg         [`SIZE_DATA-1:0]              shift_amt;
    reg         [`SIZE_OPCODE_P-1:0]          opcode;
    reg         [`FUNCT3_HI-`FUNCT3_LO:0]     fn3;
    reg         [`FUNCT7_HI-`FUNCT7_LO:0]     fn7;
    reg         [`SIZE_DATA-1:0]              result_32; // for OP_IMM_32
    
    //sign extend immediate to 64 bits
    sign_ex_immd    = {{(`SIZE_DATA-`SIZE_IMMEDIATE){immd_i[`SIZE_IMMEDIATE-1]}}, immd_i}; 
    shift_amt       = exePacket_i.inst[`SHAMT_HI:`SHAMT_LO];
    opcode          = exePacket_i.inst[`SIZE_OPCODE_P-1:0];
    fn3             = exePacket_i.inst[`FUNCT3_HI:`FUNCT3_LO];
    fn7             = exePacket_i.inst[`FUNCT7_HI:`FUNCT7_LO];
    result          = 0;
    result_32       = 0;
    flags           = 0;
    toggleFlag_o    = 1'b0;

    case (opcode)
        `OP_LUI:
        begin
            result            = sign_ex_immd;
            flags.executed    = 1'h1;
            flags.destValid   = exePacket_i.phyDestValid;
        end

        `OP_AUIPC:
        begin
            result            = exePacket_i.pc + sign_ex_immd;
            flags.executed    = 1'h1;
            flags.destValid   = exePacket_i.phyDestValid;
        end

        `OP_OP:
        begin
        case (fn3)
        
           `FN3_ADD_SUB:
            case (fn7)

                `FN7_ADD:
                 begin
                     result            = data1_i + data2_i;
                     flags.executed    = 1'h1;
                     flags.destValid   = exePacket_i.phyDestValid;
                 end

                `FN7_SUB:
                 begin
                    result             = data1_i - data2_i;
                    flags.executed     = 1'h1;
                    flags.destValid    = 1'h1;
                 end

                 default:
                 begin
                 end
            endcase // case (fn7)
           
           `FN3_SLL:
             begin
                result              = data1_i << data2_i[`SLL_SRL_SRA_SHAMT-1:0];
                flags.executed    = 1'h1;
                flags.destValid   = exePacket_i.phyDestValid;
             end

           `FN3_SLT:
            begin
            case ({data1_i[`SIZE_DATA-1],data2_i[`SIZE_DATA-1]})
                2'b00: result     = (data1_i < data2_i);
                2'b01: result     = 1'b0;
                2'b10: result     = 1'b1;
                2'b11: result     = (data1_i < data2_i);
            endcase

            flags.executed    = 1'h1;
            flags.destValid   = exePacket_i.phyDestValid;
            end
        
           `FN3_SLTU:
            begin
                result              = (data1_i < data2_i);
                flags.executed    = 1'h1;
                flags.destValid   = exePacket_i.phyDestValid;
            end

            `FN3_XOR:
            begin
                result              = data1_i ^ data2_i;
                flags.executed    = 1'h1;
                flags.destValid   = exePacket_i.phyDestValid;
            end

            `FN3_SR:
            begin
            case (fn7)
                `FN7_SRL:
                 begin
                     result              = data1_i >> data2_i[`SLL_SRL_SRA_SHAMT-1:0];
                 end
                 `FN7_SRA:
                 begin
                     data_signed1        = data1_i;
                     result              = data_signed1 >>>data2_i[`SLL_SRL_SRA_SHAMT-1:0];
                 end
            endcase

            flags.executed    = 1'h1;
            flags.destValid   = exePacket_i.phyDestValid;
            end

            `FN3_OR:
            begin
                result              = data1_i | data2_i;
                flags.executed    = 1'h1;
                flags.destValid   = exePacket_i.phyDestValid;
            end
        
            `FN3_AND:
            begin
                result              = data1_i & data2_i;
                flags.executed    = 1'h1;
                flags.destValid   = exePacket_i.phyDestValid;
            end
            
            default:
            begin
            end
        endcase //case (fn3)
        end

        `OP_OP_IMM:
         case (fn3)

            `FN3_ADD_SUB:
             begin
                    result            = data1_i + sign_ex_immd;
                    flags.executed    = 1'h1;
                    flags.destValid   = exePacket_i.phyDestValid;
             end
             
            `FN3_SLT:
             begin
             case ({data1_i[`SIZE_DATA-1], sign_ex_immd[`SIZE_DATA-1]})
                 2'b00: result     = (data1_i < sign_ex_immd);
                 2'b01: result     = 1'b0;
                 2'b10: result     = 1'b1;
                 2'b11: result     = (data1_i < sign_ex_immd);
             endcase

             flags.executed    = 1'h1;
             flags.destValid   = exePacket_i.phyDestValid;
             end
                
            `FN3_SLTU:
             begin
                 result            = (data1_i < sign_ex_immd);
                 flags.executed    = 1'h1;
                 flags.destValid   = exePacket_i.phyDestValid;
             end

            `FN3_XOR:
             begin
                result            = data1_i ^ sign_ex_immd;
                flags.executed    = 1'h1;
                flags.destValid   = exePacket_i.phyDestValid;
             end
            
            `FN3_OR:
             begin
                result            = data1_i | sign_ex_immd;
                flags.executed    = 1'h1;
                flags.destValid   = exePacket_i.phyDestValid;
             end

            `FN3_AND:
             begin
                result            = data1_i & sign_ex_immd;
                flags.executed    = 1'h1;
                flags.destValid   = exePacket_i.phyDestValid;
             end

           `FN3_SLL:
             begin
                result            = data1_i << shift_amt; //RV64 uses 6 bits for IMM shifts
                flags.executed    = 1'h1;
                flags.destValid   = exePacket_i.phyDestValid;
             end
           
           `FN3_SR:
             begin
             case (fn7 & 7'b1111110) //Must mask bit-0 as it is part of shift amount in 64-bit mode
                `FN7_SRL:
                 begin
                    result            = data1_i >> shift_amt; //RV64 uses 6 bits for IMM shifts
                 end
                `FN7_SRA:
                 begin
                    result            = data1_i >>> shift_amt; //RV64 uses 6 bits for IMM shifts
                 end
                 default:
                 begin
                 end
             endcase // case(fn7)
             flags.executed    = 1'h1;
             flags.destValid   = exePacket_i.phyDestValid;
             end

         endcase //case (fn3)

         `OP_OP_IMM_32:
            case(fn3)

                `FN3_ADD_SUB:
                 begin
                            result_32 = data1_i + sign_ex_immd;
                            result    = {{32{result_32[31]}},result_32[31:0]};
                            flags.executed    = 1'h1;
                            flags.destValid   = exePacket_i.phyDestValid;
                 end
                
                `FN3_SLL:
                 begin
                 //TODO: Throw exception if 6th bit of shamt is high
                 result_32         = data1_i << shift_amt; //RV64 uses 5 bits for IMM_32 shifts
                 result            = {{32{result_32[31]}},result_32[31:0]};
                 flags.executed    = 1'h1;
                 flags.destValid   = exePacket_i.phyDestValid;
                 end

                 `FN3_SR:
                  begin
                    case (fn7)
                       `FN7_SRL:
                        begin
                           result_32         = data1_i >> shift_amt; //RV64 uses 5 bits for IMM_32 shifts
                        end
                       `FN7_SRA:
                        begin
                           result_32         = data1_i >>> shift_amt; //RV64 uses 5 bits for IMM_32 shifts
                        end
                        default:
                        begin
                        end
                    endcase // case(fn7)
                  result            = {{32{result_32[31]}},result_32[31:0]};
                  flags.executed    = 1'h1;
                  flags.destValid   = exePacket_i.phyDestValid;
                  end
            endcase //case(fn3)

         `OP_OP_32:
           begin
           
           case(fn3)
            
           `FN3_ADD_SUB:
            case (fn7)

                `FN7_ADD:
                 begin
                     result_32         = data1_i + data2_i;
                     result    = {{32{result_32[31]}},result_32[31:0]};
                     flags.executed    = 1'h1;
                     flags.destValid   = exePacket_i.phyDestValid;
                 end

                `FN7_SUB:
                 begin
                    result_32             = data1_i - data2_i;
                    result    = {{32{result_32[31]}},result_32[31:0]};
                    flags.executed     = 1'h1;
                    flags.destValid    = 1'h1;
                 end

                 default:
                 begin
                 end
            endcase // case (fn7)
           
           `FN3_SLL:
             begin
                result_32         = data1_i << data2_i[`SLL_SRL_SRA_SHAMT-1:0];
                result            = {{32{result_32[31]}},result_32[31:0]};
                flags.executed    = 1'h1;
                flags.destValid   = exePacket_i.phyDestValid;
             end

            `FN3_SR:
            begin
            case (fn7)
                `FN7_SRL:
                 begin
                     result_32              = data1_i >> data2_i[`SLL_SRL_SRA_SHAMT-1:0];
                     result    = {{32{result_32[31]}},result_32[31:0]};
                 end
                 `FN7_SRA:
                 begin
                     data_signed1           = data1_i;
                     result_32              = data_signed1 >>> data2_i[`SLL_SRL_SRA_SHAMT-1:0];
                     result    = {{32{result_32[31]}},result_32[31:0]};
                 end
                 default:
                 begin
                 end
            endcase

            flags.executed    = 1'h1;
            flags.destValid   = exePacket_i.phyDestValid;
            end
          endcase //case (fn3)

     //   `TOGGLE_S:
     //   begin
     //       result              = 0;
     //       flags.executed    = 1'h1;
     //       flags.destValid   = exePacket_i.phyDestValid; // Writes 0 to register 0
     //       toggleFlag_o      = 1'b1;
     //   end
       
     //   `NOP:
     //   begin
     //       flags.executed    = 1'h1;
     //   end
        end
       endcase //case (opcode)
end

endmodule
