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

`define RAM_CONFIG_DEPTH 64
`define RAM_CONFIG_INDEX 6
`define RAM_CONFIG_WIDTH 32
`define RAM_CONFIG_RP 12
`define RAM_CONFIG_WP 6
`define RAM_CONFIG_WP_LOG 3
`define RAM_CONFIG_PARTS 4

`define RAM_RESET_ZERO 0
`define RAM_RESET_SEQ  1

`define RAM_PARTS 4
`define RAM_PARTS_LOG 2

`define LATCH_BASED_RAM 0
