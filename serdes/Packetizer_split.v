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

module Packetizer_split#(
    parameter PAYLOAD_WIDTH = 128,
    parameter PACKET_WIDTH  = 16,
    parameter ID            = 0,
    parameter DEPTH         = 16,
    parameter DEPTH_LOG     = 4,
    parameter N_PKTS_BITS   = 4 // must be the maximum number of bits used by any packetizer/depacketizer
) (
    input                       reset,

    // payload inputs //////////////////////////
    input                       clk_payload,
    input                       payload_req_i,
    input  [PAYLOAD_WIDTH-1:0]  payload_i,
    output                      payload_grant_o,

    // packet outputs //////////////////////////
    input                       clk_packet,
    output                      packet_req_o,
    output                      lock_o,
    output [PACKET_WIDTH-1:0]   packet_o,
    input                       packet_grant_i
);

// PAYLOAD_WIDTH / PACKET_WIDTH must be an integer
initial 
begin
    if ((PAYLOAD_WIDTH % PACKET_WIDTH) != 0)
    begin
        $display("ERROR (Packetizer_wide): PAYLOAD_WIDTH must be a multiple of PACKET_WIDTH");
        $finish;
    end
end

localparam PAYLOAD_WIDTH_DIV2   = PAYLOAD_WIDTH / 2;
localparam PACKET_WIDTH_DIV2    = PACKET_WIDTH / 2;
localparam N_PKTS               = PAYLOAD_WIDTH_DIV2 / PACKET_WIDTH_DIV2;


//////////////////////////////////////////////////
// push the payload into the serializing fifo 
//////////////////////////////////////////////////

wire                            push_req_n;
wire                            push_af_hi;
wire                            push_af_lo;
wire                            payload_grant;
reg                             payload_grant_d1;
reg                             payload_grant_d2;

// notify the payload requester that the payload
// has been pushed onto the fifo.
assign payload_grant    = payload_req_i & ~push_af_lo & ~payload_grant_d1 & ~payload_grant_d2;

// delay the grant signal for two cycles. this is to match what
// the dcache expects.
always @(posedge clk_payload)
begin
    payload_grant_d1    <= payload_grant;
    payload_grant_d2    <= payload_grant_d1;
end

assign payload_grant_o  = payload_grant_d2;

// push at the same time as the payload is granted.
assign push_req_n       = ~payload_grant;


//////////////////////////////////////////////////
// create data packets from the payload 
//////////////////////////////////////////////////

wire                            pop_req_n;
wire                            pop_empty_hi;
wire                            pop_empty_lo;
reg  [PACKET_WIDTH-1:0]         packet;
wire [PACKET_WIDTH-1:0]         data_packet;
wire [PACKET_WIDTH-1:0]         header_packet;
reg  [N_PKTS_BITS-1:0]          packet_num;


// maintain a counter for the number of packets to send
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

    else if (packet_grant_i)
    begin
        packet_num  <= N_PKTS;
    end
end

// pop while packet_num != 0 and grant is high 
assign pop_req_n    = ~((packet_num != 0) & packet_grant_i);

// send the header followed by data
always @(*)
begin
    if (~packet_grant_i)
        packet      = 0;
    else if (packet_num == 0)
        packet      = header_packet;
    else
        packet      = data_packet;
end            

assign packet_o     = packet;

// deassert packet_req one cycle before the transaction is complete
assign packet_req_o = ~pop_empty_lo & (packet_num != 1);
assign lock_o       = ~pop_empty_lo & (packet_num != 1);


// header packet
wire [N_PKTS_BITS-1:0]          n_pkts;
wire                            id;

assign n_pkts           = N_PKTS;
assign id               = ID;
assign header_packet    = {32'h0, n_pkts, id, 1'h1};

`ifdef SIM
always @(posedge clk_packet)
begin
    if (pop_empty_lo != pop_empty_hi)
        $display("[%0t] ERROR (Packetizer_wide): pop_empty_lo != pop_empty_hi", $time);
end

always @(posedge clk_payload)
begin
    if (push_af_lo != push_af_hi)
        $display("[%0t] ERROR (Packetizer_wide): push_af_lo != push_af_hi", $time);
end
`endif


// dual-clock, asymmetric fifo ///////////////////
asym_fifo_2c #(
    .data_in_width      (PAYLOAD_WIDTH_DIV2),
    .data_out_width     (PACKET_WIDTH_DIV2),
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
    serializing_fifo_lo (

    .clk_push           (clk_payload),  // input clk for push
    .clk_pop            (clk_packet),   // input clk for pop
    .rst_n              (~reset),       // reset, active low

    .flush_n            (1'h1),         // flush partial word, active low

    .push_req_n         (push_req_n),   // push request, active low
    .data_i             (payload_i[PAYLOAD_WIDTH_DIV2-1:0]),    // data to push

    .pop_req_n          (pop_req_n),    // pop request, active low
    .data_o             (data_packet[PACKET_WIDTH_DIV2-1:0]),  // data to pop (FWFT)
    
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
    .data_in_width      (PAYLOAD_WIDTH_DIV2),
    .data_out_width     (PACKET_WIDTH_DIV2),
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
    serializing_fifo_hi (

    .clk_push           (clk_payload),  // input clk for push
    .clk_pop            (clk_packet),   // input clk for pop
    .rst_n              (~reset),       // reset, active low

    .flush_n            (1'h1),         // flush partial word, active low

    .push_req_n         (push_req_n),   // push request, active low
    .data_i             (payload_i[PAYLOAD_WIDTH-1:PAYLOAD_WIDTH_DIV2]),    // data to push

    .pop_req_n          (pop_req_n),    // pop request, active low
    .data_o             (data_packet[PACKET_WIDTH-1:PACKET_WIDTH_DIV2]),  // data to pop (FWFT)
    
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
    
