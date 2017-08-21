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

module Depacketizer #(
    parameter PAYLOAD_WIDTH = 128,
    parameter PACKET_WIDTH  = 16,
    parameter ID            = 0,
    parameter DEPTH         = 16,
    parameter DEPTH_LOG     = 4,
    parameter N_PKTS_BITS   = 4, // must be the maximum number of bits used by any packetizer/depacketizer
    parameter INST_NAME     = "Depacketizer"
) (
    input                       reset,

    // packet inputs ///////////////////////////
    input                       clk_packet,
    output                      packet_af_o,
    input  [PACKET_WIDTH-1:0]   packet_i,

    // payload outputs /////////////////////////
    input                       clk_payload,
    output [PAYLOAD_WIDTH-1:0]  payload_o,
    output                      payload_valid_o,
    output                      packet_received_o
);

// PAYLOAD_WIDTH / PACKET_WIDTH must be an integer
initial 
begin
    if ((PAYLOAD_WIDTH % PACKET_WIDTH) != 0)
    begin
        $display("ERROR (%s): PAYLOAD_WIDTH must be a multiple of PACKET_WIDTH",INST_NAME);
        $finish;
    end
end

localparam N_PKTS       = PAYLOAD_WIDTH / PACKET_WIDTH;
localparam N_PKTS_LOG   = clog2(N_PKTS+1);


//////////////////////////////////////////////////
// push the packet into the deserializing fifo 
//////////////////////////////////////////////////

wire                            push_req_n;
wire                            push_af;
reg  [N_PKTS_LOG:0]             packet_num;

// parse the header packet 
wire [N_PKTS_LOG:0]             packet_n_pkts;
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
            $display("ERROR (%s): process_packet && (packet_n_pkts != N_PKTS)",INST_NAME);
        end
`endif
    end
end


// push packets 1 through N_PKTS. Packet 0 is always header packet
assign push_req_n   = ~(process_packet_reg & (packet_num != 0));



//////////////////////////////////////////////////
// create the payload from the data packets
//////////////////////////////////////////////////

wire                            pop_empty;

assign payload_valid_o  = ~pop_empty;
assign packet_received_o= ~pop_empty; // TODO: This needs to be synced to the packet clk if different clks are used
assign packet_af_o      = push_af;



// dual-clock, asymmetric fifo ///////////////////
asym_fifo_2c #(
    .data_in_width      (PACKET_WIDTH),
    .data_out_width     (PAYLOAD_WIDTH),
    .depth              (DEPTH),
    .depth_log          (DEPTH_LOG),
    .push_ae_lvl        (1),    // push almost empty
    .push_af_lvl        (1),    // push almost full   =  (DEPTH-af_lvl) is used as the level internally
    .pop_ae_lvl         (1),    // pop almost empty
    .pop_af_lvl         (1),    // pop almost full
    .err_mode           (0),    // 0=latched, 1=unlatched
    .push_sync          (1),    // 1=single reg, 2=double, 3=triple
    .pop_sync           (1),    // 1=single reg, 2=double, 3=triple
    .rst_mode           (0),    // 0=async, 1=sync
    .byte_order         (1)     // 0=byte 0 is MSB, 1=byte 0 is LSB
) 
    serializing_fifo (

    .clk_push           (clk_packet),   // input clk for push
    .clk_pop            (clk_payload),  // input clk for pop
    .rst_n              (~reset),       // reset, active low

    .flush_n            (1'h1),         // flush partial word, active low

    .push_req_n         (push_req_n),   // push request, active low
    .data_i             (packet_i),     // data to push

    .pop_req_n          (pop_empty),    // pop request, active low
    .data_o             (payload_o),    // data to pop (FWFT)
    
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
