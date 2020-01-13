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

`timescale 1ns/1ps

`define CLKPERIOD 10.00

`define SRAM_DATA_WIDTH 8

//* Select Block Size
`define SIZE_SELECT_BLOCK       8

`define SIZE_RMT                64
`define SIZE_RMT_LOG            6

//* Default values for various sizes*//

//* Fetch Width
`define FETCH_WIDTH             1
`define FETCH_WIDTH_LOG         1

//`define FETCH_TWO_WIDE
//`define FETCH_THREE_WIDE
//`define FETCH_FOUR_WIDE
//`define FETCH_FIVE_WIDE
//`define FETCH_SIX_WIDE
//`define FETCH_SEVEN_WIDE
//`define FETCH_EIGHT_WIDE

//* Dispatch Width
`define DISPATCH_WIDTH          1
`define DISPATCH_WIDTH_LOG      1

//`define DISPATCH_TWO_WIDE
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
`define COMMIT_WIDTH            1
`define COMMIT_WIDTH_LOG        1

//`define COMMIT_TWO_WIDE
//`define COMMIT_THREE_WIDE
//`define COMMIT_FOUR_WIDE

// By default, synthesize with Designware components
`define USE_DESIGNWARE


/* Default configuration for ExecutionPipe_SC.
 * By default it has simple, complex and floationg pooint
 * ALUs in it. Per lane configuration below overrides this
 * default behavior in AnyCore*/
`define PIPE_HAS_SIMPLE 1
`define PIPE_HAS_COMPLEX 1
`define PIPE_HAS_FP 1

/* Control which execution pipes can execute simple instructions.
 * Starting at the MSB and going toward the LSB, set a bit for each
 * pipe that supports simple instructions. Bits 0 and 1 must not be set. */
`define SIMPLE_VECT 'b0100
/* `define TWO_SIMPLE */
/* `define THREE_SIMPLE */
/* `define FOUR_SIMPLE */
/* `define FIVE_SIMPLE */
/* `define SIX_SIMPLE */

/* Control which execution pipes can execute complex instructions.
 * Starting at bit 2 and going toward the MSB, set a bit for each
 * pipe that supports complex instructions */
`define COMPLEX_VECT 'b0100
/* `define TWO_COMPLEX */
/* `define THREE_COMPLEX */
/* `define FOUR_COMPLEX */
/* `define FIVE_COMPLEX */
/* `define SIX_COMPLEX */

/* Control which execution pipes can execute floating point instructions.
 * Starting at bit 2 and going toward the MSB, set a bit for each
 * pipe that supports floating point instructions */
`define FP_VECT 'b0100
/* `define TWO_FP */
/* `define THREE_FP */
/* `define FOUR_FP */
/* `define FIVE_FP */
/* `define SIX_FP */

// NOTE: Instruction queue size should be greater
// than 2*FETCH_WIDTH (decode width)
`define INST_QUEUE              32
`define INST_QUEUE_LOG          5

`define SIZE_ACTIVELIST         192
`define SIZE_ACTIVELIST_LOG     8

`define SIZE_PHYSICAL_TABLE     (`SIZE_ACTIVELIST + 64)
`define SIZE_PHYSICAL_LOG       (`SIZE_ACTIVELIST_LOG+1)

`define SIZE_ISSUEQ             64
`define SIZE_ISSUEQ_LOG         6

`define SIZE_LSQ                64
`define SIZE_LSQ_LOG            6

`define SIZE_RAS                16
`define SIZE_RAS_LOG            4

`define SIZE_CTI_QUEUE          32
`define SIZE_CTI_LOG            5

`define SIZE_FREE_LIST          (`SIZE_ACTIVELIST) // 30
`define SIZE_FREE_LIST_LOG      (`SIZE_ACTIVELIST_LOG)

`define SIZE_BTB                1024*(1<<`FETCH_WIDTH_LOG) // Num BTB lanes is power of 2
`define SIZE_BTB_LOG            (10+`FETCH_WIDTH_LOG)

`define SIZE_CNT_TABLE          1024*(1<<`FETCH_WIDTH_LOG) // Num BTB lanes is power of 2
`define SIZE_CNT_TBL_LOG        (10+`FETCH_WIDTH_LOG)

`define SIZE_LD_VIOLATION_PRED     256 
`define SIZE_LD_VIOLATION_PRED_LOG 8

//* Default sizes end here *//

//* comment following line, if load violation predictor is not required.
`define ENABLE_LD_VIOLATION_PRED
//`define LDVIO_PRED_PERIODIC_FLUSH
`define LD_STALL_AT_ISSUE

// Enable this only if there are no caches and no load violation predictor
//`ifndef ENABLE_LD_VIOLATION_PRED
 // `define LD_SPECULATIVELY_WAKES_DEPENDENT
  `define REPLAY_TWO_DEEP
//`endif

//`define EXEC_WIDTH `ISSUE_WIDTH 
`define STRUCT_PARTS 4        // The number of partitions for reconfigurable structures
`define STRUCT_PARTS_LOG 2    
`define NUM_PARTS_IQ 4        // The number of partitions for reconfigurable structures
`define NUM_PARTS_IQ_LOG 2    
`define NUM_PARTS_AL 6        // The number of partitions for reconfigurable structures
`define NUM_PARTS_AL_LOG 3    
`define NUM_PARTS_RF 8        // The number of partitions for register file RAMs
`define NUM_PARTS_RF_LOG 3    
`define NUM_PARTS_FL 6
`define NUM_PARTS_FL_LOG 3
`define STRUCT_PARTS_LSQ 4        // The number of partitions for register file RAMs
`define STRUCT_PARTS_LSQ_LOG 2    
`define PIPEREG_CLK_GATE 0


`define N_ARCH_REGS            64
`define N_REPAIR_PACKETS       1 //(2*`COMMIT_WIDTH) 
`define N_REPAIR_CYCLES        (`N_ARCH_REGS + `N_REPAIR_PACKETS - 1)/`N_REPAIR_PACKETS // Note: the integer part of this expression is ceil(N_ARCH_REGS/N_REPAIR_PACKETS)

`define SIZE_PC                 64
`define SIZE_INSTRUCTION        32
`define SIZE_INSTRUCTION_BYTE   3'h4
`define SIZE_INST_BYTE_OFFSET   2

`define SIZE_DATA               64
`define SIZE_DATA_BYTE		      8
`define SIZE_DATA_BYTE_OFFSET   3
`define SIZE_VIRT_ADDR          64

`define SIZE_PREDICTION_CNT     2

`define BRANCH_TYPE_LOG         2
`define RETURN                  2'h0  // Return
`define CALL                    2'h1  // Call Direct/Indirect
`define JUMP_TYPE               2'h2  // Jump Direct/Indirect
`define COND_BRANCH             2'h3  // Conditional Branch

`define INST_TYPES_LOG          3
`define MEMORY_TYPE             3'b000
`define CONTROL_TYPE            3'b001
`define SIMPLE_TYPE             3'b010
`define COMPLEX_TYPE            3'b011
`define FP_TYPE                 3'b100

`define LDST_TYPES_LOG          2
`define LDST_BYTE               2'b00     // Load Byte
`define LDST_HALF_WORD          2'b01     // Load half word = 2 bytes
`define LDST_WORD               2'b10     // Load word = 4 bytes
`define LDST_DOUBLE_WORD        2'b11     // Load double word = 8 bytes = SIZE_DATA


`define INSTRUCTION_TYPE0       2'b00     // Simple ALU
`define INSTRUCTION_TYPE1       2'b01     // Complex ALU (for MULTIPLY & DIVIDE)
`define INSTRUCTION_TYPE2       2'b10     // CONTROL Instructions
`define INSTRUCTION_TYPE3       2'b11     // LOAD/STORE Address Generator
`define FU0                     2'b00     // Simple ALU
`define FU1                     2'b01     // Complex ALU (for MULTIPLY & DIVIDE)
`define FU2                     2'b10     // ALU for CONTROL Instructions
`define FU3                     2'b11     // LOAD/STORE Address Generator
`define FU0_LATENCY             1
`define FU1_LATENCY             20
`define FU2_LATENCY             1
`define FU3_LATENCY             2


//`define LATCH_BASED_RAM 0

//`define SCRATCH_PAD
`define INST_CACHE
`define DATA_CACHE


`ifdef SCRATCH_PAD
  `define DEBUG_INST_RAM_WIDTH 32 //RISCV 
  `define DEBUG_INST_RAM_WIDTH_LOG 5
  `define DEBUG_INST_RAM_DEPTH 256
  `define DEBUG_INST_RAM_LOG   8
  `define DEBUG_DATA_RAM_WIDTH 64
  `define DEBUG_DATA_RAM_WIDTH_LOG 6
  `define DEBUG_DATA_RAM_DEPTH 256
  `define DEBUG_DATA_RAM_LOG   8
`endif

`ifdef INST_CACHE
  `define ICACHE_INST_BYTE_OFFSET_LOG 2 // Byte offsets in individual instructions which are 4 byte long in RISCV
  `define ICACHE_INSTS_IN_LINE 4*(2**`FETCH_WIDTH_LOG)  // At least 4 times the number of fetch lanes
  `define ICACHE_INSTS_IN_LINE_LOG (`FETCH_WIDTH_LOG+2)  // log2(ICACHE_INSTS_IN_LINE)
  `define ICACHE_BITS_IN_LINE (`ICACHE_INSTS_IN_LINE*`SIZE_INSTRUCTION)  //In bits
  `define ICACHE_BYTES_IN_LINE (`ICACHE_BITS_IN_LINE/8) 
  `define ICACHE_BYTES_IN_LINE_LOG (`ICACHE_INSTS_IN_LINE_LOG + `ICACHE_INST_BYTE_OFFSET_LOG) //log2(ICACHE_BYTES_IN_LINE)
  `define ICACHE_NUM_LINES 64 //128
  `define ICACHE_NUM_LINES_LOG 6 //7
  `define ICACHE_OFFSET_BITS  `ICACHE_INSTS_IN_LINE_LOG
  `define ICACHE_INDEX_BITS   `ICACHE_NUM_LINES_LOG
  `define ICACHE_TAG_BITS     (`SIZE_PC - `ICACHE_INDEX_BITS - `ICACHE_OFFSET_BITS - `ICACHE_INST_BYTE_OFFSET_LOG)
  `define ICACHE_BLOCK_ADDR_BITS  (`SIZE_PC - `ICACHE_OFFSET_BITS - `ICACHE_INST_BYTE_OFFSET_LOG) // Cache block address 
  `define ICACHE_PC_PKT_BITS    8
  `define ICACHE_INST_PKT_BITS  8
`endif

`ifdef DATA_CACHE
  `define DCACHE_WORD_BYTE_OFFSET_LOG `SIZE_DATA_BYTE_OFFSET     // Byte offsets in a data word which is 8 byte long in RISCV
//  `define DCACHE_WORDS_IN_LINE 8            // 8 double words - basically 8*8 bytes = 64 bytes
//  `define DCACHE_WORDS_IN_LINE_LOG 3        // log2(DCACHE_WORDS_IN_LINE)
  `define DCACHE_WORDS_IN_LINE 2            // 8 double words - basically 8*8 bytes = 64 bytes
  `define DCACHE_WORDS_IN_LINE_LOG 1        // log2(DCACHE_WORDS_IN_LINE)
  `define DCACHE_BITS_IN_LINE (`DCACHE_WORDS_IN_LINE*`SIZE_DATA)  //In bits , using 64 for word size 
  `define DCACHE_BYTES_IN_LINE (`DCACHE_WORDS_IN_LINE*8) //Each word is 8 bytes in RISCV
  `define DCACHE_BYTES_IN_LINE_LOG (`DCACHE_WORDS_IN_LINE_LOG + `DCACHE_WORD_BYTE_OFFSET_LOG)
  `define DCACHE_NUM_LINES 128
  `define DCACHE_NUM_LINES_LOG 7
  `define DCACHE_OFFSET_BITS  `DCACHE_WORDS_IN_LINE_LOG
  `define DCACHE_INDEX_BITS   `DCACHE_NUM_LINES_LOG
  `define DCACHE_TAG_BITS     (`SIZE_PC - `DCACHE_INDEX_BITS - `DCACHE_OFFSET_BITS - `DCACHE_WORD_BYTE_OFFSET_LOG)
  `define DCACHE_BLOCK_ADDR_BITS (`SIZE_PC - `DCACHE_OFFSET_BITS - `DCACHE_WORD_BYTE_OFFSET_LOG) // Determines the size of cache line adddresses 
  `define DCACHE_ST_ADDR_BITS (`SIZE_PC - `DCACHE_WORD_BYTE_OFFSET_LOG) // Determines the size of cache line adddresses 
  `define DCACHE_SIZE_STB   8
  `define DCACHE_SIZE_STB_LOG   3
  `define DCACHE_LD_ADDR_PKT_BITS 8
  `define DCACHE_LD_DATA_PKT_BITS 8
  `define DCACHE_ST_PKT_BITS      8
`endif

// Register interface parameters (for CHIP mode)
`define REG_DATA_WIDTH 8

//`define PERF_MON

//`define PROCESS_45_NM
`define CLK_GATE_CELL_FG TLATNCAX2TF
`define CLK_GATE_CELL_UL TLATNCAX8TF

