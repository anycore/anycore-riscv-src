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


`include "DW_asymfifoctl_s2_sf.v"
`include "DW_ram_r_w_s_dff.v"

module asym_fifo_2c #(
    parameter data_in_width     = 8,
    parameter data_out_width    = 8,
    parameter depth             = 16,
    parameter depth_log         = 4,
    parameter push_ae_lvl       = 1, // push almost empty
    parameter push_af_lvl       = 15, // push almost full
    parameter pop_ae_lvl        = 1, // pop almost empty
    parameter pop_af_lvl        = 15, // pop almost full
    parameter err_mode          = 0,  // 0=latched, 1=unlatched
    parameter push_sync         = 1,  // 1=single reg, 2=double, 3=triple
    parameter pop_sync          = 1,  // 1=single reg, 2=double, 3=triple
    parameter rst_mode          = 0,  // 0=async, 1=sync
    parameter byte_order        = 0   // 0=byte 0 is MSB, 1=byte 0 is LSB
) (
    input                       clk_push,       // input clk for push
    input                       clk_pop,        // input clk for pop
    input                       rst_n,          // reset, active low

    input                       flush_n,        // flush partial word, active low

    input                       push_req_n,     // push request, active low
    input  [data_in_width-1:0]  data_i,         // data to push

    input                       pop_req_n,      // pop request, active low
    output [data_out_width-1:0] data_o,         // data to pop
    
    // status flags, synchronous to clk_push ///////////////////
    output                      push_empty_o,   // empty
    output                      push_ae_o,      // almost empty
    output                      push_hf_o,      // half full
    output                      push_af_o,      // almost full
    output                      push_full_o,    // very full
    output                      ram_full_o,     // full
    output                      part_wd_o,      // partial word in input buffer
    output                      push_error_o,   // overrun

    // status flags, synchronous to clk_pop ////////////////////
    output                      pop_empty_o,    // empty
    output                      pop_ae_o,       // almost empty
    output                      pop_hf_o,       // half full
    output                      pop_af_o,       // almost full
    output                      pop_full_o,     // full
    output                      pop_error_o     // underrun
);


localparam data_width   = data_in_width > data_out_width ?
                          data_in_width :
                          data_out_width;

// ctrl <--> ram signals
wire [depth_log-1  : 0] rd_addr;
wire [data_width-1 : 0] rd_data;
wire [depth_log-1  : 0] wr_addr;
wire [data_width-1 : 0] wr_data;
wire                    we_n;
     

// instance of DW_asymfifoctl_s2_sf
DW_asymfifoctl_s2_sf #(
    .data_in_width      (data_in_width), 
    .data_out_width     (data_out_width), 
    .depth              (depth), 
    .push_ae_lvl        (push_ae_lvl),
    .push_af_lvl        (push_af_lvl), 
    .pop_ae_lvl         (pop_ae_lvl), 
    .pop_af_lvl         (pop_af_lvl), 
    .err_mode           (err_mode),
    .push_sync          (push_sync), 
    .pop_sync           (pop_sync), 
    .rst_mode           (rst_mode), 
    .byte_order         (byte_order)
)
    fifo_ctrl (
    
    .clk_push           (clk_push),
    .clk_pop            (clk_pop),
    .rst_n              (rst_n),

    .flush_n            (flush_n),

    .push_req_n         (push_req_n),
    .data_in            (data_i),
    
    .pop_req_n          (pop_req_n),
    .data_out           (data_o), 
    
    // status flags, synchronous to clk_push
    .push_empty         (push_empty_o),
    .push_ae            (push_ae_o),
    .push_hf            (push_hf_o),
    .push_af            (push_af_o),
    .push_full          (push_full_o),
    .ram_full           (ram_full_o),
    .part_wd            (part_wd_o),
    .push_error         (push_error_o),
    
    // status flags, synchronous to clk_pop
    .pop_empty          (pop_empty_o),
    .pop_ae             (pop_ae_o),
    .pop_hf             (pop_hf_o),
    .pop_af             (pop_af_o),
    .pop_full           (pop_full_o),
    .pop_error          (pop_error_o),
    
    // ctrl <--> ram interface
    .rd_addr            (rd_addr),
    .rd_data            (rd_data),
    .wr_addr            (wr_addr),
    .wr_data            (wr_data),
    .we_n               (we_n)
);


// Instance of DW_ram_r_w_s_dff
DW_ram_r_w_s_dff #(
    .data_width         (data_width), 
    .depth              (depth), 
    .rst_mode           (rst_mode)
)
    fifo_ram (
        
    .clk                (clk_push),
    .rst_n              (rst_n),
    .cs_n               (1'h0),

    // ctrl <--> ram interface
    .rd_addr            (rd_addr),
    .data_out           (rd_data),
    .wr_addr            (wr_addr),
    .data_in            (wr_data),
    .wr_n               (we_n)
);
/*
DW_ram_r_w_2c_dff #(
    .width              (data_width), 
    .depth              (depth), 
    .addr_width         (depth_log), 
    .mem_mode           (mem_mode)
    .rst_mode           (rst_mode)

)
  fifo_ram (
	clk_w,		// Write clock input
	rst_w_n,	// write domain active low asynch. reset
	init_w_n,	// write domain active low synch. reset
	en_w_n,		// acive low write enable
	addr_w,		// Write address input
	data_w,		// Write data input

	clk_r,		// Read clock input
	rst_r_n,	// read domain active low asynch. reset
	init_r_n,	// read domain active low synch. reset
	en_r_n,		// acive low read enable
	addr_r,		// Read address input
	data_r_a,	// Read data arrival status output
	data_r		// Read data output
);
*/
endmodule
