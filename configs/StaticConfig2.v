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

`include "configs/CommonConfig.vh"

//`define CLKPERIOD 1.14
//`define CLKPERIOD 1.71 //3X
`define CLKPERIOD 2.66 //3x0.58
//`define CLKPERIOD 10.00 //6x0.58
//`define CLKPERIOD 0.56//6x0.58


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
`define COMMIT_WIDTH            2
`define COMMIT_WIDTH_LOG        1

`define COMMIT_TWO_WIDE
//`define COMMIT_THREE_WIDE
//`define COMMIT_FOUR_WIDE
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

/* Control which execution pipes can execute simple instructions.
 * Starting at the MSB and going toward the LSB, set a bit for each
 * pipe that supports simple instructions. Bits 0 and 1 must not be set. */
`define SIMPLE_VECT 'b100
/* `define TWO_SIMPLE */
/* `define THREE_SIMPLE */
/* `define FOUR_SIMPLE */
/* `define FIVE_SIMPLE */
/* `define SIX_SIMPLE */

/* Control which execution pipes can execute complex instructions.
 * Starting at bit 2 and going toward the MSB, set a bit for each
 * pipe that supports complex instructions */
`define COMPLEX_VECT 'b100
/* `define TWO_COMPLEX */
/* `define THREE_COMPLEX */
/* `define FOUR_COMPLEX */
/* `define FIVE_COMPLEX */
/* `define SIX_COMPLEX */


// Instruction queue size should be greater
// than 2*FETCH_WIDTH (decode width)
`define INST_QUEUE              32
`define INST_QUEUE_LOG          5

`define SIZE_ACTIVELIST         128
`define SIZE_ACTIVELIST_LOG     8

`define SIZE_PHYSICAL_TABLE     128
`define SIZE_PHYSICAL_LOG       8

`define SIZE_ISSUEQ             32
`define SIZE_ISSUEQ_LOG         5

/* This enables round robin priority of issue queue chunks*/
//`define RR_ISSUE_PARTITION
//`define RR_ISSUE_TWO_PARTS
//`define RR_ISSUE_THREE_PARTS
//`define RR_ISSUE_FOUR_PARTS

/* These enable strict age based ordering in issue queue*/
//`define AGE_BASED_ORDERING
//`define AGE_BASED_ORDERING_LANE0
//`define AGE_BASED_ORDERING_LANE1
//`define AGE_BASED_ORDERING_LANE2
//`define AGE_BASED_ORDERING_LANE3
//`define AGE_BASED_ORDERING_LANE4

`define SIZE_LSQ                16
`define SIZE_LSQ_LOG            4

`define SIZE_RAS                16
`define SIZE_RAS_LOG            4

`define SIZE_CTI_QUEUE          32
`define SIZE_CTI_LOG            5

`define SIZE_FREE_LIST          (`SIZE_PHYSICAL_TABLE-`SIZE_RMT) // 30
`define SIZE_FREE_LIST_LOG      7

