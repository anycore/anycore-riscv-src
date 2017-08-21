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

//* Fetch Width
`define FETCH_WIDTH             1
`define FETCH_WIDTH_LOG         1

//`define FETCH_TWO_WIDE
//`define FETCH_THREE_WIDE
//`define FETCH_FOUR_WIDE

//* Dispatch Width
`define DISPATCH_WIDTH          1
`define DISPATCH_WIDTH_LOG      1

//`define DISPATCH_TWO_WIDE
//`define DISPATCH_THREE_WIDE
//`define DISPATCH_FOUR_WIDE

//* Issue Width
`define ISSUE_WIDTH             3
`define ISSUE_WIDTH_LOG         2 

`define ISSUE_TWO_WIDE
`define ISSUE_THREE_WIDE
//`define ISSUE_FOUR_WIDE
//`define ISSUE_FIVE_WIDE

//* Commit Width
`define COMMIT_WIDTH            1
`define COMMIT_WIDTH_LOG        1

//`define COMMIT_TWO_WIDE
//`define COMMIT_THREE_WIDE
//`define COMMIT_FOUR_WIDE

`define SIZE_ACTIVELIST         96
`define SIZE_ACTIVELIST_LOG     7

`define SIZE_ISSUEQ             16
`define SIZE_ISSUEQ_LOG         4

`define SIZE_LSQ                32
`define SIZE_LSQ_LOG            5


// Does not need change
`define SIZE_PHYSICAL_TABLE     (`SIZE_ACTIVELIST+`SIZE_RMT)
`define SIZE_PHYSICAL_LOG       (`SIZE_ACTIVELIST_LOG+1)

`define SIZE_FREE_LIST          (`SIZE_ACTIVELIST)
`define SIZE_FREE_LIST_LOG      (`SIZE_ACTIVELIST_LOG)

`define PIPE_HAS_FP 0
`define FP_VECT 'b0000

`define PRF_RAM_COMPILED

//`define USE_GSHARE_BPU
//`define PIPELINED_PHT_UPDATE
