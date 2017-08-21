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

module Packetizer #(
    parameter PAYLOAD_WIDTH = 128,
    parameter PACKET_WIDTH  = 16,
    parameter ID            = 0,
    parameter DEPTH         = 16,
    parameter PUSH_AF_LVL   = 2,
    parameter DEPTH_LOG     = 4,
    parameter N_PKTS_BITS   = 4, // must be the maximum number of bits used by any packetizer/depacketizer
    parameter THROTTLE      = 0, // Throttles the issuing of packets to L2 if 1
    parameter THROTTLE_THRESHOLD      = 2  // Maximum number of outstanding requests to L2
) (
    input                       reset,

    // payload inputs //////////////////////////
    input                       clk_payload,
    input                       payload_req_i,
    input  [PAYLOAD_WIDTH-1:0]  payload_i,
    output                      payload_grant_o,
    output                      push_af_o,

    // packet outputs //////////////////////////
    input                       clk_packet,
    output                      packet_req_o,
    output                      lock_o,
    output [PACKET_WIDTH-1:0]   packet_o,
    input                       packet_grant_i,
    input                       packet_received_i
);

// PAYLOAD_WIDTH / PACKET_WIDTH must be an integer
initial 
begin
    if ((PAYLOAD_WIDTH % PACKET_WIDTH) != 0)
    begin
        $display("ERROR (Packetizer): PAYLOAD_WIDTH must be a multiple of PACKET_WIDTH");
        $finish;
    end

    // N_PKTS bits should be sufficient to hold the num_pkt in the header information
    if ((PAYLOAD_WIDTH % PACKET_WIDTH) >= 2**(N_PKTS_BITS-2))
    begin
        $display("ERROR (Packetizer): PACKET_WIDTH must have more bits");
        $finish;
    end
end

localparam N_PKTS       = PAYLOAD_WIDTH / PACKET_WIDTH;
localparam N_PKTS_LOG   = clog2(N_PKTS+1);

//////////////////////////////////////////////////
// push the payload into the serializing fifo 
//////////////////////////////////////////////////

wire                            push_req_n;
wire                            push_af;
wire                            payload_grant;
reg                             payload_grant_d1;
reg                             payload_grant_d2;
reg                             packet_issued;
reg   [3:0]                     num_outstanding_pkts;

// notify the payload requester that the payload
// has been pushed onto the fifo.
assign payload_grant    = payload_req_i & ~push_af; // & ~payload_grant_d1 & ~payload_grant_d2;

// delay the grant signal for two cycles. this is to match what
// the dcache expects.
always @(posedge clk_payload)
begin
    payload_grant_d1    <= payload_grant;
    payload_grant_d2    <= payload_grant_d1;
end

assign payload_grant_o  = payload_grant_d2;
assign push_af_o        = push_af;

// push at the same time as the payload is granted.
assign push_req_n       = ~payload_grant;


//////////////////////////////////////////////////
// create data packets from the payload 
//////////////////////////////////////////////////

wire                            pop_req_n;
wire                            pop_empty;
reg  [PACKET_WIDTH-1:0]         packet;
wire [PACKET_WIDTH-1:0]         data_packet;
wire [PACKET_WIDTH-1:0]         header_packet;
//reg  [N_PKTS_BITS-1:0]          packet_num;
reg  [N_PKTS_LOG:0]             packet_num;


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

// TODO: Ideally this should be a state machine triggered by a single cycle
// of grant and not stopping until all the packets have been sent
/* State Machine Begins */
reg packet_grant_d1;
always @(posedge clk_packet or posedge reset)
begin
  if(reset)
    packet_grant_d1 <=  1'b0;
  else
    packet_grant_d1  <=  packet_grant_i;
end


// pop while packet_num != 0 and grant is high 
//assign pop_req_n    = ~((packet_num != 0) & packet_grant_i);
// pop while packet_num != 0 
assign pop_req_n    = ~(packet_num != 0);

// send the header followed by data
always @(*)
begin
    if (~packet_grant_i & ~packet_grant_d1)
        packet      = 0;
    else if (packet_num == 0)
        packet      = header_packet;
    else
        packet      = data_packet;

    // Raising this flag one cycle ahead so that the counter has time to update
    packet_issued <= packet_grant_i & (packet_num == 1);
end            
/* State Machine Ends*/


// Rangeen - Sep 4
// outstanding packets tracking logic so that a maximum of 2/3 packets are outstanding to the L2
// Only used when THROTTLING is enabled
always @(posedge clk_packet or posedge reset)
begin
  if(reset)
  begin
    num_outstanding_pkts <= 4'b0;
  end
  else
  begin
    if(packet_issued & packet_received_i)
      num_outstanding_pkts <= num_outstanding_pkts;
    else if(packet_issued)
      num_outstanding_pkts <= num_outstanding_pkts + 1;
    else if(packet_received_i)
      num_outstanding_pkts <= num_outstanding_pkts - 1;
  end
end    


assign packet_o     = packet;

// deassert packet_req one cycle before the transaction is complete
// NOTE: Throttle only if THROTTLE is set
assign packet_req_o = ~pop_empty & (packet_num != 1) & ((num_outstanding_pkts < THROTTLE_THRESHOLD) | (THROTTLE == 0));
assign lock_o       = ~pop_empty & (packet_num != 1) & ((num_outstanding_pkts < THROTTLE_THRESHOLD) | (THROTTLE == 0));


// header packet
//wire [N_PKTS_BITS-1:0]          n_pkts;
wire [N_PKTS_LOG:0]             n_pkts;
wire                            id;

assign n_pkts           = N_PKTS;
assign id               = ID;
assign header_packet    = {32'h0, n_pkts, id, 1'h1};


// dual-clock, asymmetric fifo ///////////////////
asym_fifo_2c #(
    .data_in_width      (PAYLOAD_WIDTH),
    .data_out_width     (PACKET_WIDTH),
    .depth              (DEPTH),
    .depth_log          (DEPTH_LOG),
    .push_ae_lvl        (1),    // push almost empty
    .push_af_lvl        (PUSH_AF_LVL),    // push almost full   =  (DEPTH-af_lvl) is used as the level internally
    .pop_ae_lvl         (2),    // pop almost empty
    .pop_af_lvl         (1),    // pop almost full
    .err_mode           (0),    // 0=latched, 1=unlatched
    .push_sync          (1),    // 1=single reg, 2=double, 3=triple
    .pop_sync           (1),    // 1=single reg, 2=double, 3=triple
    .rst_mode           (0),    // 0=async, 1=sync
    .byte_order         (1)     // 0=byte 0 is MSB, 1=byte 0 is LSB
) 
    serializing_fifo (

    .clk_push           (clk_payload),  // input clk for push
    .clk_pop            (clk_packet),   // input clk for pop
    .rst_n              (~reset),       // reset, active low

    .flush_n            (1'h1),         // flush partial word, active low

    .push_req_n         (push_req_n),   // push request, active low
    .data_i             (payload_i),    // data to push

    .pop_req_n          (pop_req_n),    // pop request, active low
    .data_o             (data_packet),  // data to pop (FWFT)
    
    .push_empty_o       (),             // empty
    .push_ae_o          (),             // almost empty
    .push_hf_o          (),             // half full
    .push_af_o          (push_af),      // almost full
    .push_full_o        (),             // very full
    .ram_full_o         (),             // full
    .part_wd_o          (),             // partial word in input buffer
    .push_error_o       (),             // overrun

    .pop_empty_o        (pop_empty),    // empty
    .pop_ae_o           (),             // almost empty
    .pop_hf_o           (),             // half full
    .pop_af_o           (),             // almost full
    .pop_full_o         (),             // full
    .pop_error_o        ()              // underrun
);


function integer clog2;
    input integer value;
    integer tmp;
    integer i;
    begin
        clog2 = 0;
        tmp = value - 1;
        for (i=0; 2**i<tmp; i=i+1)
        begin
            clog2 = i+1;
        end
    end
endfunction

endmodule
    
