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

`define SRAM_DATA_WIDTH 8

//* Fetch Width
`define FETCH_WIDTH             2
`define FETCH_WIDTH_LOG         1

`define FETCH_TWO_WIDE
//`define FETCH_THREE_WIDE
//`define FETCH_FOUR_WIDE
//`define FETCH_FIVE_WIDE
//`define FETCH_SIX_WIDE
//`define FETCH_SEVEN_WIDE
//`define FETCH_EIGHT_WIDE

//* Dispatch Width
`define DISPATCH_WIDTH          2
`define DISPATCH_WIDTH_LOG      1

`define DISPATCH_TWO_WIDE
//`define DISPATCH_THREE_WIDE
//`define DISPATCH_FOUR_WIDE
//`define DISPATCH_FIVE_WIDE
//`define DISPATCH_SIX_WIDE
//`define DISPATCH_SEVEN_WIDE
//`define DISPATCH_EIGHT_WIDE

//* Issue Width
`define ISSUE_WIDTH             3
`define ISSUE_WIDTH_LOG         2

`define ISSUE_TWO_WIDE
`define ISSUE_THREE_WIDE
//`define ISSUE_FOUR_WIDE
//`define ISSUE_FIVE_WIDE
//`define ISSUE_SIX_WIDE
//`define ISSUE_SEVEN_WIDE
//`define ISSUE_EIGHT_WIDE

//* Commit Width
`define COMMIT_WIDTH            4
`define COMMIT_WIDTH_LOG        2

`define COMMIT_TWO_WIDE
`define COMMIT_THREE_WIDE
`define COMMIT_FOUR_WIDE
//`define COMMIT_FIVE_WIDE
//`define COMMIT_SIX_WIDE
//`define COMMIT_SEVEN_WIDE
//`define COMMIT_EIGHT_WIDE

//* Register Read Depth
//`define RR_TWO_DEEP
//`define RR_THREE_DEEP
//`define RR_FOUR_DEEP

//* Issue Depth
//`define ISSUE_TWO_DEEP
//`define ISSUE_THREE_DEEP


`define INST_QUEUE              32
`define INST_QUEUE_LOG          5

`define SIZE_ACTIVELIST         128
`define SIZE_ACTIVELIST_LOG     7

`define SIZE_PHYSICAL_TABLE     96
`define SIZE_PHYSICAL_LOG       7

`define SIZE_ISSUEQ             32
`define SIZE_ISSUEQ_LOG         5

//* Select Block Size
`define SIZE_SELECT_BLOCK       8

`define SIZE_LSQ                32
`define SIZE_LSQ_LOG            5

`define SIZE_RAS                8
`define SIZE_RAS_LOG            3

`define SIZE_CTI_QUEUE          16
`define SIZE_CTI_LOG            4

`define SIZE_FREE_LIST          (`SIZE_PHYSICAL_TABLE-`SIZE_RMT)
`define SIZE_FREE_LIST_LOG      6

`define SIZE_RMT                34
`define SIZE_RMT_LOG            6

`define SIZE_BTB                4096
`define SIZE_BTB_LOG            12

`define SIZE_CNT_TABLE          65536
`define SIZE_CNT_TBL_LOG        16

`define SIZE_LD_VIOLATION_PRED     1024
`define SIZE_LD_VIOLATION_PRED_LOG 10


//* comment following line, if load violation predictor is not required.
`define ENABLE_LD_VIOLATION_PRED

`define N_REPAIR_CYCLES         4
`define N_REPAIR_PACKETS        (34 + `N_REPAIR_CYCLES - 1)/`N_REPAIR_CYCLES // Note: this is ceil(34/N_REPAIR_CYCLES)

`ifdef USE_VPI
`define GET_ARCH_PC             $getArchPC()
`define READ_OPCODE(a)          $read_opcode(a)
`define READ_OPERAND(a)         $read_operand(a)
`define READ_SIGNED_BYTE(a)     $readSignedByte(a)
`define READ_UNSIGNED_BYTE(a)   $readUnsignedByte(a)
`define READ_SIGNED_HALF(a)     $readSignedHalf(a)
`define READ_UNSIGNED_HALF(a)   $readUnsignedHalf(a)
`define READ_WORD(a)            $readWord(a)
`define WRITE_BYTE(a,b)         $writeByte(a,b)
`define WRITE_HALF(a,b)         $writeHalf(a,b)
`define WRITE_WORD(a,b)         $writeWord(a,b)

`else
`define GET_ARCH_PC             0
`define READ_OPCODE(a)          $random
`define READ_OPERAND(a)         $random
`define READ_SIGNED_BYTE(a)     $random
`define READ_UNSIGNED_BYTE(a)   $random
`define READ_SIGNED_HALF(a)     $random
`define READ_UNSIGNED_HALF(a)   $random
`define READ_WORD(a)            $random
`define WRITE_BYTE(a,b)         //
`define WRITE_HALF(a,b)         //
`define WRITE_WORD(a,b)         //
`endif


`define SIZE_PC                 32
`define SIZE_INSTRUCTION        64

`define SIZE_BYTE_OFFSET        3
`define SIZE_PREDICTION_CNT     2

`define BRANCH_TYPE_LOG             2

`define RETURN                  2'h0
`define CALL                    2'h1
`define JUMP_TYPE               2'h2
`define COND_BRANCH             2'h3

/*
 * 00 = Return
 * 01 = Call Direct/Indirect
 * 10 = Jump Direct/Indirect
 * 11 = Conditional Branch
*/

`define SIZE_DATA               32
`define INSTRUCTION_TYPES       4
`define INST_TYPES_LOG          2
`define INSTRUCTION_TYPE0       2'b00     // Simple ALU
`define INSTRUCTION_TYPE1       2'b01     // Complex ALU (for MULTIPLY & DIVIDE)
`define INSTRUCTION_TYPE2       2'b10     // CONTROL Instructions
`define INSTRUCTION_TYPE3       2'b11     // LOAD/STORE Address Generator
`define LDST_BYTE               2'b00
`define LDST_HALF_WORD          2'b01
`define LDST_WORD               2'b10
`define LDST_DOUBLE_WORD        2'b11
`define LDST_TYPES_LOG          2

`define SIZE_VIRT_ADDR        32

`define FU0                     2'b00     // Simple ALU
`define FU1                     2'b01     // Complex ALU (for MULTIPLY & DIVIDE)
`define FU2                     2'b10     // ALU for CONTROL Instructions
`define FU3                     2'b11     // LOAD/STORE Address Generator
`define FU0_LATENCY             1
`define FU1_LATENCY             3
`define FU2_LATENCY             1
`define FU3_LATENCY             2

`define SIZE_EXE_FLAGS         8
                                   /*  bit[0]: Mispredict,
                                    *  bit[1]: Exception,
                                    *  bit[2]: Executed,
                                    *  bit[3]: Fission Instruction,
                                    *  bit[4]: Destination Valid,
                                    *  bit[5]: Predicted Control Instruction
                                    *  bit[6]: Load byte/half-word sign
                                    *  bit[7]: Conditional Branch Instruction
                                   */


/* PISA instruction format */
`define SIZE_OPCODE_P           32       // opcode size from original PISA i.e. 32bits
`define SIZE_OPCODE_I           8        // opcode size used for implementation
`define SIZE_IMMEDIATE          16
`define SIZE_TARGET             26
`define SIZE_RS                 8
`define SIZE_RT                 8
`define SIZE_RD                 8
`define SIZE_RU                 8
`define SIZE_SPECIAL_REG        2        // In case of SimpleScalar HI and LO
                                         // are special registers, which stores
                                         // Multiply and Divide result.
`define REG_RA                  31

`ifdef DISPATCH_FIVE_WIDE
`define NUM_RECOVER_PACKETS `COMMIT_WIDTH
`else
`define NUM_RECOVER_PACKETS `DISPATCH_WIDTH
`endif

`define NUM_RECOVER_CYCLES (34 + `NUM_RECOVER_PACKET - 1)/`NUM_RECOVER_PACKET // Note: this is ceil
