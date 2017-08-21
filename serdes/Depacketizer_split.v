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

module Depacketizer_split#(
    parameter PAYLOAD_WIDTH = 128,
    parameter PACKET_WIDTH  = 16,
    parameter ID            = 0,
    parameter DEPTH         = 16,
    parameter DEPTH_LOG     = 4,
    parameter N_PKTS_BITS   = 4 // must be the maximum number of bits used by any packetizer/depacketizer
) (
    input                       reset,

    // packet inputs ///////////////////////////
    input                       clk_packet,
    output                      packet_af_o,
    input  [PACKET_WIDTH-1:0]   packet_i,

    // payload outputs /////////////////////////
    input                       clk_payload,
    output [PAYLOAD_WIDTH-1:0]  payload_o,
    output                      payload_valid_o
);

// PAYLOAD_WIDTH / PACKET_WIDTH must be an integer
initial 
begin
    if ((PAYLOAD_WIDTH % PACKET_WIDTH) != 0)
    begin
        $display("ERROR (Depacketizer): PAYLOAD_WIDTH must be a multiple of PACKET_WIDTH");
        $finish;
    end
end

localparam PAYLOAD_WIDTH_DIV2   = PAYLOAD_WIDTH / 2;
localparam PACKET_WIDTH_DIV2    = PACKET_WIDTH / 2;
localparam N_PKTS               = PAYLOAD_WIDTH_DIV2 / PACKET_WIDTH_DIV2;


//////////////////////////////////////////////////
// push the packet into the deserializing fifo 
//////////////////////////////////////////////////

wire                            push_req_n;
wire                            push_af_hi;
wire                            push_af_lo;
reg  [N_PKTS_BITS-1:0]          packet_num;

// parse the header packet 
wire [N_PKTS_BITS-1:0]          packet_n_pkts;
wire                            packet_id;
wire                            packet_valid;

assign {packet_n_pkts, packet_id, packet_valid} = packet_i;


// determine whether to process the packet based on the header.
wire                            process_packet;
reg                             process_packet_reg;

assign process_packet   = packet_valid & (packet_id == ID[0]);

// high if processing the current transaction
always @(posedge clk_packet or posedge reset)
begin
    if (reset)
    begin
        process_packet_reg  <= 1'h0;
    end

    else if (packet_num == 0)
    begin
        process_packet_reg  <= process_packet;
    end
end


// maintain a count of how many packets in the transaction
always @(posedge clk_packet or posedge reset)
begin
    if (reset)
    begin
        packet_num  <= 0;
    end

    else if (packet_num != 0)
    begin
        packet_num  <= packet_num - 1;
    end

    else if (packet_valid)
    begin
        packet_num  <= packet_n_pkts;

        // bad things will happen if packet_n_pkts != N_PKTS
`ifdef SIM
        if (process_packet && (packet_n_pkts != N_PKTS))
        begin
            $display("ERROR (Depacketizer): process_packet && (packet_n_pkts != N_PKTS)");
        end
`endif
    end
end


// push packets 2 through N_PKTS
assign push_req_n   = ~(process_packet_reg & (packet_num != 0));



//////////////////////////////////////////////////
// create the payload from the data packets
//////////////////////////////////////////////////

wire                            pop_empty_hi;
wire                            pop_empty_lo;

assign payload_valid_o  = ~pop_empty_lo;
assign packet_af_o      = push_af_lo;

`ifdef SIM
always @(posedge clk_payload)
begin
    if (pop_empty_lo != pop_empty_hi)
        $display("[%0t] ERROR (Depacketizer_wide): pop_empty_lo != pop_empty_hi", $time);
end

always @(posedge clk_packet)
begin
    if (push_af_lo != push_af_hi)
        $display("[%0t] ERROR (Depacketizer_wide): push_af_lo != push_af_hi", $time);
end
`endif


// dual-clock, asymmetric fifo ///////////////////
asym_fifo_2c #(
    .data_in_width      (PACKET_WIDTH_DIV2),
    .data_out_width     (PAYLOAD_WIDTH_DIV2),
    .depth              (DEPTH),
    .depth_log          (DEPTH_LOG),
    .push_ae_lvl        (1),    // push almost empty
    .push_af_lvl        (1),    // push almost full
    .pop_ae_lvl         (1),    // pop almost empty
    .pop_af_lvl         (1),    // pop almost full
    .err_mode           (0),    // 0=latched, 1=unlatched
    .push_sync          (1),    // 1=single reg, 2=double, 3=triple
    .pop_sync           (1),    // 1=single reg, 2=double, 3=triple
    .rst_mode           (0),    // 0=async, 1=sync
    .byte_order         (1)     // 0=byte 0 is MSB, 1=byte 0 is LSB
) 
    deserializing_fifo_lo (

    .clk_push           (clk_packet),   // input clk for push
    .clk_pop            (clk_payload),  // input clk for pop
    .rst_n              (~reset),       // reset, active low

    .flush_n            (1'h1),         // flush partial word, active low

    .push_req_n         (push_req_n),   // push request, active low
    .data_i             (packet_i[PACKET_WIDTH_DIV2-1:0]),     // data to push

    .pop_req_n          (pop_empty_lo),    // pop request, active low
    .data_o             (payload_o[PAYLOAD_WIDTH_DIV2-1:0]),    // data to pop (FWFT)
    
    .push_empty_o       (),             // empty
    .push_ae_o          (),             // almost empty
    .push_hf_o          (),             // half full
    .push_af_o          (push_af_lo),   // almost full
    .push_full_o        (),             // very full
    .ram_full_o         (),             // full
    .part_wd_o          (),             // partial word in input buffer
    .push_error_o       (),             // overrun

    .pop_empty_o        (pop_empty_lo), // empty
    .pop_ae_o           (),             // almost empty
    .pop_hf_o           (),             // half full
    .pop_af_o           (),             // almost full
    .pop_full_o         (),             // full
    .pop_error_o        ()              // underrun
);


// dual-clock, asymmetric fifo ///////////////////
asym_fifo_2c #(
    .data_in_width      (PACKET_WIDTH_DIV2),
    .data_out_width     (PAYLOAD_WIDTH_DIV2),
    .depth              (DEPTH),
    .depth_log          (DEPTH_LOG),
    .push_ae_lvl        (1),    // push almost empty
    .push_af_lvl        (1),    // push almost full
    .pop_ae_lvl         (1),    // pop almost empty
    .pop_af_lvl         (1),    // pop almost full
    .err_mode           (0),    // 0=latched, 1=unlatched
    .push_sync          (1),    // 1=single reg, 2=double, 3=triple
    .pop_sync           (1),    // 1=single reg, 2=double, 3=triple
    .rst_mode           (0),    // 0=async, 1=sync
    .byte_order         (1)     // 0=byte 0 is MSB, 1=byte 0 is LSB
) 
    deserializing_fifo_hi (

    .clk_push           (clk_packet),   // input clk for push
    .clk_pop            (clk_payload),  // input clk for pop
    .rst_n              (~reset),       // reset, active low

    .flush_n            (1'h1),         // flush partial word, active low

    .push_req_n         (push_req_n),   // push request, active low
    .data_i             (packet_i[PACKET_WIDTH-1:PACKET_WIDTH_DIV2]),     // data to push

    .pop_req_n          (pop_empty_hi),    // pop request, active low
    .data_o             (payload_o[PAYLOAD_WIDTH-1:PAYLOAD_WIDTH_DIV2]),    // data to pop (FWFT)
    
    .push_empty_o       (),             // empty
    .push_ae_o          (),             // almost empty
    .push_hf_o          (),             // half full
    .push_af_o          (push_af_hi),   // almost full
    .push_full_o        (),             // very full
    .ram_full_o         (),             // full
    .part_wd_o          (),             // partial word in input buffer
    .push_error_o       (),             // overrun

    .pop_empty_o        (pop_empty_hi), // empty
    .pop_ae_o           (),             // almost empty
    .pop_hf_o           (),             // half full
    .pop_af_o           (),             // almost full
    .pop_full_o         (),             // full
    .pop_error_o        ()              // underrun
);


endmodule
