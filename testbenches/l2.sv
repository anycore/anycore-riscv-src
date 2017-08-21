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

module l2 (
    input                                   clk,
    input                                   reset,
    input                                   run_i,

    output                                  mem_core_clk_o,
    /* output reg [127:0]                      mem_core_bus_o, */
    output reg [7:0]                      mem_core_bus_o,

    input                                   core_mem_clk_i,
    /* input  [31:0]                            core_mem_bus_i */
    input  [7:0]                            core_mem_bus_i
);



wire [18:0]                     mem_addr0_i;
wire                            mem_re0_i;

// icache packet->payload
wire [12:0]             dummy1;

Depacketizer #(
    .PAYLOAD_WIDTH      (32),
    /* .PACKET_WIDTH       (32), */
    .PACKET_WIDTH       (8),
    .ID                 (0),
    .DEPTH              (4),
    .DEPTH_LOG          (2),
    .N_PKTS_BITS        (6)
)
    icache_depacketizer (

    .reset              (reset),

    .clk_packet         (core_mem_clk_i),
    .packet_i           (core_mem_bus_i),
    .packet_af_o        (),
    .packet_received_o  (),

    .clk_payload        (clk),
    .payload_o          ({dummy1, mem_addr0_i}),
    .payload_valid_o    (mem_re0_i)
);


wire                                    lsu_l15_valid_i;
wire  [39:0]                            lsu_l15_addr_i;
wire  [25:0]                            lsu_l15_cpkt_i;
wire  [63:0]                            lsu_l15_data_i;
/* wire  [29:0]             dummy2; */
wire  [13:0]             dummy2;


Depacketizer #(
    /* .PAYLOAD_WIDTH      (160), */
    /* .PACKET_WIDTH       (32), */
    .PAYLOAD_WIDTH      (144),
    .PACKET_WIDTH       (8),
    .ID                 (1),
    .DEPTH              (4),
    .DEPTH_LOG          (2),
    .N_PKTS_BITS        (6)
)
    dcache_depacketizer (

    .reset              (reset),

    .clk_packet         (core_mem_clk_i),
    .packet_i           (core_mem_bus_i),
    .packet_af_o        (),
    .packet_received_o  (),

    .clk_payload        (clk),
    .payload_o          ({dummy2, lsu_l15_data_i, lsu_l15_cpkt_i, lsu_l15_addr_i}),
    .payload_valid_o    (lsu_l15_valid_i)
);


// icache payload->packet
wire                            ic_packet_req;
wire                            ic_packet_lock;
/* wire [127:0]                    ic_packet; */
wire [7:0]                      ic_packet;
wire                            ic_packet_grant;

wire [255:0]                    mem_data0_o;
wire                            mem_data_ready0_o;
wire [9:0]                      mem_tag0_o;
wire [8:0]                      mem_index0_o;

Packetizer_wide #(
    /* .PAYLOAD_WIDTH      (384), */
    /* .PACKET_WIDTH       (128), */
    .PAYLOAD_WIDTH      (288),
    .PACKET_WIDTH       (8),
    .ID                 (0),
    .DEPTH              (128),
    .DEPTH_LOG          (7),
    .N_PKTS_BITS        (6)
)
    icache_packetizer (

    .reset              (reset),

    .clk_payload        (clk),
    .payload_req_i      (mem_data_ready0_o),
    /* .payload_i          ({96'h0, 13'h0, mem_data0_o, mem_tag0_o, mem_index0_o}), */
    .payload_i          ({13'h0, mem_data0_o, mem_tag0_o, mem_index0_o}),
    .payload_grant_o    (),

    .clk_packet         (mem_core_clk_o),
    .packet_req_o       (ic_packet_req),
    .lock_o             (ic_packet_lock),
    .packet_o           (ic_packet),
    .packet_grant_i     (ic_packet_grant)
);


// dcache payload->packet
wire [145:0]                    cpx_spc_data_cx_o;
wire                            cpx_spc_data_cx_valid_o;
wire                            dc_packet_req;
wire                            dc_packet_lock;
/* wire [127:0]                    dc_packet; */
wire [7:0]                      dc_packet;
wire                            dc_packet_grant;

Packetizer #(
    /* .PAYLOAD_WIDTH      (256), */
    /* .PACKET_WIDTH       (128), */
    .PAYLOAD_WIDTH      (160),
    .PACKET_WIDTH       (8),
    .ID                 (1),
    .DEPTH              (128),
    .DEPTH_LOG          (7),
    .N_PKTS_BITS        (6),
    .THROTTLE           (0)
)
    dcache_packetizer (

    .reset              (reset),

    .clk_payload        (clk),
    .payload_req_i      (cpx_spc_data_cx_valid_o),
    /* .payload_i          ({96'h0, 14'h0, cpx_spc_data_cx_o}), */
    .payload_i          ({14'h0, cpx_spc_data_cx_o}),
    .payload_grant_o    (),
    .push_af_o          (),

    .clk_packet         (mem_core_clk_o),
    .packet_req_o       (dc_packet_req),
    .lock_o             (dc_packet_lock),
    .packet_o           (dc_packet),
    .packet_grant_i     (dc_packet_grant),
    .packet_received_i  (1'b0)
);



// icache and dcache packet arbiter -- fcfs
DW_arb_fcfs #(
    .n                  (2), // number of clients
    .park_mode          (0), // 0=disable, 1=enable
    .park_index         (0), // park index
    .output_mode        (1)  // 0=no regs, 1=regs 
)

    arbiter (

    .clk                (mem_core_clk_o),
    .rst_n              (~reset),
    .init_n             (~reset),
    .enable             (1'h1),
    .request            ({dc_packet_req, ic_packet_req}),
    .lock               ({dc_packet_lock, ic_packet_lock}),
    .mask               (2'h0),
    .parked             (),
    .granted            (),
    .locked             (),
    .grant              ({dc_packet_grant, ic_packet_grant}),
    .grant_index        () 
);

// give bus ownership based on the grant signals
always @(*)
begin
    if (ic_packet_grant)
        mem_core_bus_o  = ic_packet;
    else if (dc_packet_grant)
        mem_core_bus_o  = dc_packet;
    else
        mem_core_bus_o  = 8'h0;
end

assign mem_core_clk_o   = clk;


l2_icache l2_inst_cache (
    .clk                                (clk),
    .reset                              (reset),

    .run_i                              (run_i),

    .mem_addr0_i                        ({8'h0, mem_addr0_i, 5'h0}),
    .mem_re0_i                          (mem_re0_i),

    .mem_data0_o                        (mem_data0_o),
    .mem_data_ready0_o                  (mem_data_ready0_o),
    .mem_tag0_o                         (mem_tag0_o),
    .mem_index0_o                       (mem_index0_o)
);

l2_dcache l2_data_cache (
    .clk                                (clk),
    .reset                              (reset),

    .l15_lsu_grant_o                    (),    // one packet is released to PCX
    .lsu_l15_valid_i                    (lsu_l15_valid_i),    // LSU requests PCX access
    .lsu_l15_addr_i                     (lsu_l15_addr_i),     // PCX request address
    .lsu_l15_cpkt_i                     (lsu_l15_cpkt_i),     // PCX request control
    .lsu_l15_data_i                     (lsu_l15_data_i),     // PCX request data

    .cpx_spc_data_cx_o                  (cpx_spc_data_cx_o),
    .cpx_spc_data_cx_valid_o            (cpx_spc_data_cx_valid_o)
);

endmodule

