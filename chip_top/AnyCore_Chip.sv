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

`timescale 1ns/100ps

module AnyCore_Chip(

	input                            clk,
	input                            reset,
	input                            resetFetch_i,
	input                            cacheModeOverride_i,

  // Operates at ioClk
  input  [5:0]                     regAddr_i,     //64 registers
  input  [`REG_DATA_WIDTH-1:0]     regWrData_i,
  input                            regWrEn_i,
  output logic [`REG_DATA_WIDTH-1:0] regRdData_o,

`ifdef DYNAMIC_CONFIG
  input                            stallFetch_i,
  input                            reconfigureCore_i,
`endif

`ifdef DATA_CACHE
  input                            mem2dcStComplete_i,
`endif

  /* Packet interface for fabrication */
  // Operates at ioClk
`ifdef INST_CACHE
	output  [`ICACHE_PC_PKT_BITS-1:0]         instPC_packet_o,
	input   [`ICACHE_INST_PKT_BITS-1:0]       inst_packet_i,
`endif  

`ifdef DATA_CACHE
	output  [`DCACHE_LD_ADDR_PKT_BITS-1:0]    ldAddr_packet_o,
	input   [`DCACHE_LD_DATA_PKT_BITS-1:0]    ldData_packet_i,
	output  [`DCACHE_ST_PKT_BITS-1:0]         st_packet_o,      // Carries address, data and En
`endif  
  /* Packet interface ends */

  output                           toggleFlag_o


	);


/*****************************Wire Declaration**********************************/



wire [`SIZE_PC-1:0]                ldAddr;
wire [`SIZE_DATA-1:0]              ldData;
wire                               ldEn;

wire [`SIZE_PC-1:0]                stAddr;
wire [`SIZE_DATA-1:0]              stData;
wire [3:0]                         stEn;

reg  [`SIZE_PC-1:0]                instPC[0:`FETCH_WIDTH-1];

assign ldData     = 32'h0;

logic [`SIZE_PC-1:0]  currentInstPC;
assign currentInstPC = instPC[0];

logic [`SIZE_INSTRUCTION-1:0]      inst   [0:`FETCH_WIDTH-1];
logic                              instValid;
logic [2:0]                        cancelCurrentFetch;

assign instValid = 1'b0;
assign cancelCurrentFetch = 3'h0;

`ifdef DYNAMIC_CONFIG
    logic                             stallFetch_sync; 
    logic                             reconfigureCore_sync;
    logic [`FETCH_WIDTH-1:0]          fetchLaneActive;
    logic [`DISPATCH_WIDTH-1:0]       dispatchLaneActive;
    logic [`ISSUE_WIDTH-1:0]          issueLaneActive;         
    logic [`EXEC_WIDTH-1:0]           execLaneActive;
    logic [`EXEC_WIDTH-1:0]           saluLaneActive;
    logic [`EXEC_WIDTH-1:0]           caluLaneActive;
    logic [`COMMIT_WIDTH-1:0]         commitLaneActive;
    logic [`NUM_PARTS_RF-1:0]         rfPartitionActive;
    logic [`NUM_PARTS_RF-1:0]         alPartitionActive;
    logic [`STRUCT_PARTS_LSQ-1:0]     lsqPartitionActive;
    logic [`STRUCT_PARTS-1:0]         iqPartitionActive;
    logic [`STRUCT_PARTS-1:0]         ibuffPartitionActive;
`endif    

`ifdef SCRATCH_PAD
    logic [`DEBUG_INST_RAM_LOG+`DEBUG_INST_RAM_WIDTH_LOG-1:0] instScratchAddr;
    logic [7:0]                       instScratchWrData;  
    logic                             instScratchWrEn ;  
    logic [7:0]                       instScratchRdData;  
    logic [`DEBUG_DATA_RAM_LOG+`DEBUG_DATA_RAM_WIDTH_LOG-1:0] dataScratchAddr;
    logic [7:0]                       dataScratchWrData;
    logic                             dataScratchWrEn;  
    logic [7:0]                       dataScratchRdData; 
    logic [1:0]                       scratchPadEn;
`endif


`ifdef INST_CACHE
    logic                             instCacheBypass;
    logic [`ICACHE_BLOCK_ADDR_BITS-1:0] ic2memReqAddr_o;      // memory read address
    logic                             ic2memReqValid_o;     // memory read enable
    logic [`ICACHE_TAG_BITS-1:0]      mem2icTag_i;          // tag of the incoming data
    logic [`ICACHE_INDEX_BITS-1:0]    mem2icIndex_i;        // index of the incoming data
    logic [`ICACHE_BITS_IN_LINE-1:0]     mem2icData_i;         // requested data
    logic                             mem2icRespValid_i;    // requested data is ready
    logic                             icScratchModeEn;
    logic [`ICACHE_INDEX_BITS+`ICACHE_BYTES_IN_LINE_LOG-1:0]  icScratchWrAddr;
    logic                                                     icScratchWrEn;
    logic [7:0]                                               icScratchWrData;
    logic [7:0]                                               icScratchRdData;
`endif  

`ifdef DATA_CACHE
    logic                             dataCacheBypass;
    logic                             dcScratchModeEn;

    // cache-to-memory interface for Loads
    logic [`DCACHE_BLOCK_ADDR_BITS-1:0] dc2memLdAddr_o;  // memory read address
    logic                             dc2memLdValid_o; // memory read enable

    // memory-to-cache interface for Loads
    logic  [`DCACHE_TAG_BITS-1:0]     mem2dcLdTag_i;       // tag of the incoming datadetermine
    logic  [`DCACHE_INDEX_BITS-1:0]   mem2dcLdIndex_i;     // index of the incoming data
    logic  [`DCACHE_BITS_IN_LINE-1:0]    mem2dcLdData_i;      // requested data
    logic                             mem2dcLdValid_i;     // indicates the requested data is ready

    // cache-to-memory interface for stores
    logic [`DCACHE_ST_ADDR_BITS-1:0]  dc2memStAddr_o;  // memory read address
    logic [`SIZE_DATA-1:0]            dc2memStData_o;  // memory read address
    logic [3:0]                       dc2memStByteEn_o;  // memory read address
    logic                             dc2memStValid_o; // memory read enable

    logic [`DCACHE_INDEX_BITS+`DCACHE_BYTES_IN_LINE_LOG-1:0]  dcScratchWrAddr;
    logic                                                     dcScratchWrEn;
    logic [7:0]                                               dcScratchWrData;
    logic [7:0]                                               dcScratchRdData;
`endif

    logic [`SIZE_PHYSICAL_LOG+`SIZE_DATA_BYTE_OFFSET-1:0]     debugPRFAddr; 
    logic [`SRAM_DATA_WIDTH-1:0]      debugPRFRdData;    
    logic [`SRAM_DATA_WIDTH-1:0]      debugPRFWrData;
    logic                             debugPRFWrEn;

	  logic [`SIZE_RMT_LOG-1:0]         debugAMTAddr;
	  logic [`SIZE_PHYSICAL_LOG-1:0]    debugAMTRdData;

`ifdef PERF_MON
    logic [31:0]                      perfMonRegData;
    logic [`REG_DATA_WIDTH-1:0]       perfMonRegAddr;
    logic                             perfMonRegGlobalClr;
    logic                             perfMonRegClr;
    logic 		                        perfMonRegRun;
`endif

    logic                             reconfigDone;
    logic                             pipeDrained;
    logic                             fetchReq;
    logic                             fetchRecoverFlag;
    logic                             st_push_af;
    logic                             instPC_push_af;
    logic                             instPC_packet_req;
    logic                             inst_depacket_af;
    logic                             ldAddr_push_af;
    logic                             ldAddr_packet_req;
    logic                             ldData_depacket_af;
    logic                             st_packet_req;

logic   coreClk;
logic   ioClk;
logic   resetFetch_sync;
logic   reset_sync;

assign ioClk    = clk;
assign coreClk  = clk;

DebugConfig debCon(
    .ioClk                    (ioClk                  ),
    .coreClk                  (coreClk                ),
    .reset                    (reset                  ),
    .resetFetch_i             (resetFetch_i           ),
    .cacheModeOverride_i      (cacheModeOverride_i    ),
                                                      
    .reset_sync_o             (reset_sync             ),
    .resetFetch_sync_o        (resetFetch_sync        ),
                                                      
    .regAddr_i                (regAddr_i              ), 
    .regWrData_i              (regWrData_i            ),
    .regWrEn_i                (regWrEn_i              ),
    .regRdData_o              (regRdData_o            ),

    .currentInstPC_i          (currentInstPC          ),
                                                        
`ifdef DYNAMIC_CONFIG          
    .stallFetch_i             (stallFetch_i           ), 
    .reconfigureCore_i        (reconfigureCore_i      ),
    .stallFetch_sync_o        (stallFetch_sync        ), 
    .reconfigureCore_sync_o   (reconfigureCore_sync   ),
    .fetchLaneActive_o        (fetchLaneActive        ),
    .dispatchLaneActive_o     (dispatchLaneActive     ),
    .issueLaneActive_o        (issueLaneActive        ),         
    .execLaneActive_o         (execLaneActive         ),
    .saluLaneActive_o         (saluLaneActive         ),
    .caluLaneActive_o         (caluLaneActive         ),
    .commitLaneActive_o       (commitLaneActive       ),
    .rfPartitionActive_o      (rfPartitionActive      ),
    .alPartitionActive_o      (alPartitionActive      ),
    .lsqPartitionActive_o     (lsqPartitionActive     ),
    .iqPartitionActive_o      (iqPartitionActive      ),
    .ibuffPartitionActive_o   (ibuffPartitionActive   ),
    .reconfigDone_i           (reconfigDone           ),
    .pipeDrained_i            (pipeDrained            ),
`endif                         
                                                        
`ifdef SCRATCH_PAD            
    .instScratchAddr_o        (instScratchAddr        ),
    .instScratchWrData_o      (instScratchWrData      ),    
    .instScratchWrEn_o        (instScratchWrEn        ),  
    .instScratchRdData_i      (instScratchRdData      ),  
    .dataScratchAddr_o        (dataScratchAddr        ),
    .dataScratchWrData_o      (dataScratchWrData      ),
    .dataScratchWrEn_o        (dataScratchWrEn        ),  
    .dataScratchRdData_i      (dataScratchRdData      ), 
    .scratchPadEn_o           (scratchPadEn           ),
`endif                       
                                                        
`ifdef INST_CACHE           
    .instCacheBypass_o        (instCacheBypass        ),
    .icScratchModeEn_o        (icScratchModeEn        ),
    .icScratchWrAddr_o        (icScratchWrAddr        ),
    .icScratchWrEn_o          (icScratchWrEn          ),
    .icScratchWrData_o        (icScratchWrData        ),
    .icScratchRdData_i        (icScratchRdData        ),
`endif                     
                                                        
`ifdef DATA_CACHE         
    .dataCacheBypass_o        (dataCacheBypass        ),
    .dcScratchModeEn_o        (dcScratchModeEn        ),
    .dcScratchWrAddr_o        (dcScratchWrAddr        ),
    .dcScratchWrEn_o          (dcScratchWrEn          ),
    .dcScratchWrData_o        (dcScratchWrData        ),
    .dcScratchRdData_i        (dcScratchRdData        ),
`endif                   
                                                        
                                                       
`ifdef PERF_MON         
    .perfMonRegData_i         (perfMonRegData         ),
    .perfMonRegAddr_o         (perfMonRegAddr         ),
    .perfMonRegGlobalClr_o    (perfMonRegGlobalClr    ),
    .perfMonRegClr_o          (perfMonRegClr          ),
    .perfMonRegRun_o          (perfMonRegRun          ),
`endif

    .debugPRFAddr_o           (debugPRFAddr           ), 
    .debugPRFRdData_i         (debugPRFRdData         ),    
    .debugPRFWrData_o         (debugPRFWrData         ),
    .debugPRFWrEn_o           (debugPRFWrEn           ),

	  .debugAMTAddr_o           (debugAMTAddr           ),
	  .debugAMTRdData_i         (debugAMTRdData         )

  );



Core_OOO coreTop(

    .clk                                 (coreClk),
    .reset                               (reset_sync),
    .resetFetch_i                        (resetFetch_sync),
    .toggleFlag_o                        (toggleFlag_o),

`ifdef SCRATCH_PAD
    .instScratchAddr_i                   (instScratchAddr),
    .instScratchWrData_i                 (instScratchWrData),
    .instScratchWrEn_i                   (instScratchWrEn),
    .instScratchRdData_o                 (instScratchRdData),
    .dataScratchAddr_i                   (dataScratchAddr),
    .dataScratchWrData_i                 (dataScratchWrData),
    .dataScratchWrEn_i                   (dataScratchWrEn),
    .dataScratchRdData_o                 (dataScratchRdData),
    .instScratchPadEn_i                  (scratchPadEn[0]),
    .dataScratchPadEn_i                  (scratchPadEn[1]),
`endif

`ifdef DYNAMIC_CONFIG
    .stallFetch_i                        (stallFetch_sync), 
    .reconfigureCore_i                   (reconfigureCore_sync),
    .fetchLaneActive_i                   (fetchLaneActive), 
    .dispatchLaneActive_i                (dispatchLaneActive), 
    .issueLaneActive_i                   (issueLaneActive), 
    .execLaneActive_i                    (issueLaneActive),
    .saluLaneActive_i                    (saluLaneActive),
    .caluLaneActive_i                    (caluLaneActive),
    .commitLaneActive_i                  (commitLaneActive), 
    .rfPartitionActive_i                 (rfPartitionActive),
    .alPartitionActive_i                 (alPartitionActive),
    .lsqPartitionActive_i                (lsqPartitionActive),
    .iqPartitionActive_i                 (iqPartitionActive),
    .ibuffPartitionActive_i              (ibuffPartitionActive),
    .reconfigDone_o                      (reconfigDone),
    .pipeDrained_o                       (pipeDrained),
`endif
`ifdef PERF_MON
    .perfMonRegAddr_i                    (perfMonRegAddr),
    .perfMonRegData_o                    (perfMonRegData),
    .perfMonRegRun_i                     (perfMonRegRun),
    .perfMonRegClr_i                     (perfMonRegClr),
    .perfMonRegGlobalClr_i               (perfMonRegGlobalClr),                    
`endif

    .startPC_i                           (32'b0),

    .instPC_o                            (instPC),
    .fetchReq_o                          (fetchReq),
    .fetchRecoverFlag_o                  (fetchRecoverFlag),
    .inst_i                              (inst),
    .instValid_i                         (instValid & ~(|cancelCurrentFetch)),

    .ldAddr_o                            (ldAddr),
    .ldData_i                            (ldData),
    .ldDataValid_i                       (ldEn),  //Loopback
    .ldEn_o                              (ldEn),

    .stAddr_o                            (stAddr),
    .stData_o                            (stData),
    .stEn_o                              (stEn),

  `ifdef INST_CACHE
    .ic2memReqAddr_o                     (ic2memReqAddr_o  ),      // memory read address
    .ic2memReqValid_o                    (ic2memReqValid_o ),     // memory read enable
    .mem2icTag_i                         (mem2icTag_i      ),          // tag of the incoming data
    .mem2icIndex_i                       (mem2icIndex_i    ),        // index of the incoming data
    .mem2icData_i                        (mem2icData_i     ),         // requested data
    .mem2icRespValid_i                   (mem2icRespValid_i),    // requested data is ready
    .instCacheBypass_i                   (instCacheBypass  ),
    .icScratchModeEn_i                   (icScratchModeEn  ),

    .icScratchWrAddr_i                   (icScratchWrAddr  ),
    .icScratchWrEn_i                     (icScratchWrEn    ),
    .icScratchWrData_i                   (icScratchWrData  ),
    .icScratchRdData_o                   (icScratchRdData  ),
  `endif  

  `ifdef DATA_CACHE
    .dataCacheBypass_i                   (dataCacheBypass    ),
    .dcScratchModeEn_i                   (dcScratchModeEn    ),
  
    .dc2memLdAddr_o                      (dc2memLdAddr_o     ), // memory read address
    .dc2memLdValid_o                     (dc2memLdValid_o    ), // memory read enable
                                                            
    .mem2dcLdTag_i                       (mem2dcLdTag_i      ), // tag of the incoming datadetermine
    .mem2dcLdIndex_i                     (mem2dcLdIndex_i    ), // index of the incoming data
    .mem2dcLdData_i                      (mem2dcLdData_i     ), // requested data
    .mem2dcLdValid_i                     (mem2dcLdValid_i    ), // indicates the requested data is ready
                                                            
    .dc2memStAddr_o                      (dc2memStAddr_o     ), // memory read address
    .dc2memStData_o                      (dc2memStData_o     ), // memory read address
    .dc2memStByteEn_o                    (dc2memStByteEn_o   ), // memory read address
    .dc2memStValid_o                     (dc2memStValid_o    ), // memory read enable
                                                            
    .mem2dcStComplete_i                  (mem2dcStComplete_i ),
    .mem2dcStStall_i                     (st_push_af         ),

    .dcScratchWrAddr_i                   (dcScratchWrAddr    ),
    .dcScratchWrEn_i                     (dcScratchWrEn      ),
    .dcScratchWrData_i                   (dcScratchWrData    ),
    .dcScratchRdData_o                   (dcScratchRdData    ),
  `endif    

    /* Initialize the PRF from top */
    // These are not used
    .dbAddr_i                            ({`SIZE_PHYSICAL_LOG{1'b0}}),
    .dbData_i                            ({`SIZE_DATA{1'b0}}),
    .dbWe_i                              (1'b0),
   
    .debugPRFAddr_i                      (debugPRFAddr       ), 
    .debugPRFRdData_o                    (debugPRFRdData     ),
    .debugPRFWrEn_i                      (debugPRFWrEn       ),
    .debugPRFWrData_i                    (debugPRFWrData     ),

	  .debugAMTAddr_i                      (debugAMTAddr       ),
	  .debugAMTRdData_o                    (debugAMTRdData     )

 );


`ifdef INST_CACHE

  logic [32-`ICACHE_BLOCK_ADDR_BITS-1:0] instPktDummy;
  assign instPktDummy = {(32-`ICACHE_BLOCK_ADDR_BITS){1'b0}};
  
  Packetizer #(
      .PAYLOAD_WIDTH          (32),
      .PACKET_WIDTH           (`ICACHE_PC_PKT_BITS),
      .ID                     (0),  // This should macth the ID of depacketizer in the TB
      .DEPTH                  (4),  // Only one outstanding fetch miss at a time
      .DEPTH_LOG              (2),
      .N_PKTS_BITS            (2),
      .THROTTLE               (0) // Throttling is disabled
  )
      instPC_packetizer (
  
      .reset                  (reset),
  
      .clk_payload            (coreClk),
      .payload_req_i          (ic2memReqValid_o),
      .payload_i              ({instPktDummy,ic2memReqAddr_o}),
      .payload_grant_o        (),
      .push_af_o              (instPC_push_af),
  
      .clk_packet             (ioClk),
      .packet_req_o           (instPC_packet_req),
      .lock_o                 (),
      .packet_o               (instPC_packet_o),
      .packet_grant_i         (instPC_packet_req), // Request is looped back in
      .packet_received_i      (1'b0)
  );
  
  
  
  logic [32-`ICACHE_BLOCK_ADDR_BITS-1:0] instDePktDummy;
  
  Depacketizer_wide #(
      .PAYLOAD_WIDTH      (32+`ICACHE_BITS_IN_LINE),
      .PACKET_WIDTH       (`ICACHE_INST_PKT_BITS),
      .ID                 (1), // This should macth the ID of packetizer in the TB
      .DEPTH              (4), // Only one outstanding fetch miss at a time
      .DEPTH_LOG          (2),
      .N_PKTS_BITS        (2),
      .INST_NAME          ("inst_depkt")
  )
      inst_depacketizer (
  
      .reset              (reset),
  
      .clk_packet         (ioClk),
      .packet_i           (inst_packet_i),
      .packet_af_o        (inst_depacket_af),
  
      .clk_payload        (coreClk),
      .payload_o          ({instDePktDummy,mem2icTag_i,mem2icIndex_i,mem2icData_i}),
      .payload_valid_o    (mem2icRespValid_i),
      .packet_received_o  ()
  );
`endif //ifdef INST_CACHE

`ifdef DATA_CACHE
  logic [32-`DCACHE_BLOCK_ADDR_BITS-1:0] ldPktDummy;
  assign ldPktDummy = {(32-`DCACHE_BLOCK_ADDR_BITS){1'b0}};
  
  Packetizer #(
      .PAYLOAD_WIDTH          (32),
      .PACKET_WIDTH           (`DCACHE_LD_ADDR_PKT_BITS),
      .ID                     (0),  // This should macth the ID of depacketizer in the TB
      .DEPTH                  (4),  // Only one outstanding load miss at a time
      .DEPTH_LOG              (2),
      .N_PKTS_BITS            (2),
      .THROTTLE               (0) // Throttling is disabled
  )
      ldAddr_packetizer (
  
      .reset                  (reset),
  
      .clk_payload            (coreClk),
      .payload_req_i          (dc2memLdValid_o),
      .payload_i              ({ldPktDummy,dc2memLdAddr_o}),
      .payload_grant_o        (),
      .push_af_o              (ldAddr_push_af),
  
      .clk_packet             (ioClk),
      .packet_req_o           (ldAddr_packet_req),
      .lock_o                 (),
      .packet_o               (ldAddr_packet_o),
      .packet_grant_i         (ldAddr_packet_req), // Request is looped back in
      .packet_received_i      (1'b0)
  );
  
  
  
  
  logic [32-`DCACHE_BLOCK_ADDR_BITS-1:0] ldDePktDummy;
  
  Depacketizer #(
      .PAYLOAD_WIDTH      (32+`DCACHE_BITS_IN_LINE),
      .PACKET_WIDTH       (`DCACHE_LD_DATA_PKT_BITS),
      .ID                 (1), // This should macth the ID of packetizer in the TB
      .DEPTH              (4), // Only one outstanding load miss at a time
      .DEPTH_LOG          (2),
      .N_PKTS_BITS        (2),
      .INST_NAME          ("ldData_depkt")
  )
      ldData_depacketizer (
  
      .reset              (reset),
  
      .clk_packet         (ioClk),
      .packet_i           (ldData_packet_i),
      .packet_af_o        (ldData_depacket_af),
  
      .clk_payload        (coreClk),
      .payload_o          ({ldDePktDummy,mem2dcLdTag_i,mem2dcLdIndex_i,mem2dcLdData_i}),
      .payload_valid_o    (mem2dcLdValid_i),
      .packet_received_o  ()
  );
  
  logic [36-`DCACHE_ST_ADDR_BITS-1:0] stPktDummy;
  assign stPktDummy = {(36-`DCACHE_ST_ADDR_BITS){1'b0}};
  
  Packetizer #(
      .PAYLOAD_WIDTH          (4+32+32+4), // Additional 4 bits in MSB is padding to make PAYLOAD_WIDTH%PACKET_WIDTH = 0
      .PACKET_WIDTH           (`DCACHE_ST_PKT_BITS),
      .ID                     (0),  // This should macth the ID of depacketizer in the TB
      .DEPTH                  (2*`DCACHE_SIZE_STB),
      .PUSH_AF_LVL            (4),
      .DEPTH_LOG              (`DCACHE_SIZE_STB_LOG+1),
      .N_PKTS_BITS            (2),
      .THROTTLE               (0) // Throttling is disabled
  )
      st_packetizer (
  
      .reset                  (reset),
  
      .clk_payload            (coreClk),
      .payload_req_i          (dc2memStValid_o),
      .payload_i              ({stPktDummy,dc2memStAddr_o,dc2memStData_o,dc2memStByteEn_o}),
      .payload_grant_o        (),
      .push_af_o              (st_push_af),
  
      .clk_packet             (ioClk),
      .packet_req_o           (st_packet_req),
      .lock_o                 (),
      .packet_o               (st_packet_o),
      .packet_grant_i         (st_packet_req), // Request is looped back in
      .packet_received_i      (1'b0)
  );
`endif


endmodule
