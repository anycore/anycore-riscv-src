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

module AnyCore_Piton(

	input                            clk,
	input                            rst_n,
    output                           spc_grst_l,

	//input                            resetFetch_i,
	//input                            cacheModeOverride_i,

  // Debug interface - separate address space, read-write from outside
  // or loopback from core pipeline.
  // Operates at ioClk
  input  [5:0]                     regAddr_i,     //64 registers
  input  [`REG_DATA_WIDTH-1:0]     regWrData_i,
  input                            regWrEn_i,
  output logic [`REG_DATA_WIDTH-1:0] regRdData_o,

`ifdef DYNAMIC_CONFIG
  input                            stallFetch_i,
  input                            reconfigureCore_i,
`endif

  output [`ICACHE_BLOCK_ADDR_BITS-1:0] ic2memReqAddr_o, // memory read address
  output                             ic2memReqValid_o,  // memory read enable
  input [`ICACHE_TAG_BITS-1:0]      mem2icTag_i,        // tag of the incoming data
  input [`ICACHE_INDEX_BITS-1:0]    mem2icIndex_i,      // index of the incoming data
  input [`ICACHE_BITS_IN_LINE-1:0]  mem2icData_i,       // requested data
  input                             mem2icRespValid_i,  // requested data is ready

  // cache-to-memory interface for Loads
  output [`DCACHE_BLOCK_ADDR_BITS-1:0] dc2memLdAddr_o,  // memory read address
  output                             dc2memLdValid_o, // memory read enable

  // memory-to-cache interface for Loads
  input [`DCACHE_TAG_BITS-1:0]     mem2dcLdTag_i,       // tag of the incoming datadetermine
  input [`DCACHE_INDEX_BITS-1:0]   mem2dcLdIndex_i,     // index of the incoming data
  input [`DCACHE_BITS_IN_LINE-1:0] mem2dcLdData_i,      // requested data
  input                            mem2dcLdValid_i,     // indicates the requested data is ready

  // cache-to-memory interface for stores
  output [`DCACHE_ST_ADDR_BITS-1:0]  dc2memStAddr_o,  
  output [`SIZE_DATA-1:0]            dc2memStData_o,
  output [2:0]                       dc2memStSize_o,
  output                             dc2memStValid_o,

  input                            mem2dcStComplete_i,
  input                            mem2dcStStall_i,

  input                             anycore_int

	);


/*****************************Wire Declaration**********************************/

wire reset;
reg reset_l;

assign spc_grst_l = rst_n;
assign reset = ~reset_l;

always @ (posedge clk) begin
    if(!rst_n) begin
        reset_l <= 1'b0;
    end
    else if (anycore_int) begin
        reset_l <= 1'b1;
    end
end

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

logic [`SIZE_PC-1:0] prevInstPC;

always @(posedge clk) begin
    prevInstPC <= currentInstPC;
end

always @(posedge clk) begin
    if (prevInstPC != currentInstPC) begin
        $display("currentInstPC changed from 0x%x to 0x%x", prevInstPC, currentInstPC);
    end
end

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

    logic                             icScratchModeEn;
    logic [`ICACHE_INDEX_BITS+`ICACHE_BYTES_IN_LINE_LOG-1:0]  icScratchWrAddr;
    logic                                                     icScratchWrEn;
    logic [7:0]                                               icScratchWrData;
    logic [7:0]                                               icScratchRdData;
`endif  

`ifdef DATA_CACHE
    logic                             dataCacheBypass;
    logic                             dcScratchModeEn;

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
    logic                             instPC_push_af;
    logic                             instPC_packet_req;
    logic                             cpx_depacket_af;
    logic                             pcx_packet_af;
    logic                             ldAddr_packet_req;
    logic                             ldData_depacket_af;
    logic                             st_packet_req;

logic   coreClk;
logic   ioClk;
logic   resetFetch_sync;
logic   reset_sync;

assign ioClk    = clk;
assign coreClk  = clk;
assign reset_sync = reset;

//DebugConfig debCon(
//    .ioClk                    (ioClk                  ),
//    .coreClk                  (coreClk                ),
//    .reset                    (reset                  ),
//    .resetFetch_i             (1'b0),//resetFetch_i           ),
//    .cacheModeOverride_i      (1'b0),//cacheModeOverride_i    ),
//                                                      
//    .reset_sync_o             (reset_sync             ),
//    .resetFetch_sync_o        (resetFetch_sync        ),
//                                                      
//    .regAddr_i                (regAddr_i              ), 
//    .regWrData_i              (regWrData_i            ),
//    .regWrEn_i                (regWrEn_i              ),
//    .regRdData_o              (regRdData_o            ),
//
//    .currentInstPC_i          (currentInstPC          ),
//                                                        
//`ifdef DYNAMIC_CONFIG          
//    .stallFetch_i             (stallFetch_i           ), 
//    .reconfigureCore_i        (reconfigureCore_i      ),
//    .stallFetch_sync_o        (stallFetch_sync        ), 
//    .reconfigureCore_sync_o   (reconfigureCore_sync   ),
//    .fetchLaneActive_o        (fetchLaneActive        ),
//    .dispatchLaneActive_o     (dispatchLaneActive     ),
//    .issueLaneActive_o        (issueLaneActive        ),         
//    .execLaneActive_o         (execLaneActive         ),
//    .saluLaneActive_o         (saluLaneActive         ),
//    .caluLaneActive_o         (caluLaneActive         ),
//    .commitLaneActive_o       (commitLaneActive       ),
//    .rfPartitionActive_o      (rfPartitionActive      ),
//    .alPartitionActive_o      (alPartitionActive      ),
//    .lsqPartitionActive_o     (lsqPartitionActive     ),
//    .iqPartitionActive_o      (iqPartitionActive      ),
//    .ibuffPartitionActive_o   (ibuffPartitionActive   ),
//    .reconfigDone_i           (reconfigDone           ),
//    .pipeDrained_i            (pipeDrained            ),
//`endif                         
//                                                        
//`ifdef SCRATCH_PAD            
//    .instScratchAddr_o        (instScratchAddr        ),
//    .instScratchWrData_o      (instScratchWrData      ),    
//    .instScratchWrEn_o        (instScratchWrEn        ),  
//    .instScratchRdData_i      (instScratchRdData      ),  
//    .dataScratchAddr_o        (dataScratchAddr        ),
//    .dataScratchWrData_o      (dataScratchWrData      ),
//    .dataScratchWrEn_o        (dataScratchWrEn        ),  
//    .dataScratchRdData_i      (dataScratchRdData      ), 
//    .scratchPadEn_o           (scratchPadEn           ),
//`endif                       
//                                                        
//`ifdef INST_CACHE           
//    .instCacheBypass_o        (instCacheBypass        ),
//    .icScratchModeEn_o        (icScratchModeEn        ),
//    .icScratchWrAddr_o        (icScratchWrAddr        ),
//    .icScratchWrEn_o          (icScratchWrEn          ),
//    .icScratchWrData_o        (icScratchWrData        ),
//    .icScratchRdData_i        (icScratchRdData        ),
//`endif                     
//                                                        
//`ifdef DATA_CACHE         
//    .dataCacheBypass_o        (dataCacheBypass        ),
//    .dcScratchModeEn_o        (dcScratchModeEn        ),
//    .dcScratchWrAddr_o        (dcScratchWrAddr        ),
//    .dcScratchWrEn_o          (dcScratchWrEn          ),
//    .dcScratchWrData_o        (dcScratchWrData        ),
//    .dcScratchRdData_i        (dcScratchRdData        ),
//`endif                   
//                                                        
//                                                       
//`ifdef PERF_MON         
//    .perfMonRegData_i         (perfMonRegData         ),
//    .perfMonRegAddr_o         (perfMonRegAddr         ),
//    .perfMonRegGlobalClr_o    (perfMonRegGlobalClr    ),
//    .perfMonRegClr_o          (perfMonRegClr          ),
//    .perfMonRegRun_o          (perfMonRegRun          ),
//`endif
//
//    .debugPRFAddr_o           (debugPRFAddr           ), 
//    .debugPRFRdData_i         (debugPRFRdData         ),    
//    .debugPRFWrData_o         (debugPRFWrData         ),
//    .debugPRFWrEn_o           (debugPRFWrEn           ),
//
//	  .debugAMTAddr_o           (debugAMTAddr           ),
//	  .debugAMTRdData_i         (debugAMTRdData         )
//
//  );

assign icScratchModeEn = 1'b0;
assign icScratchWrEn = 1'b0;
assign icScratchWrAddr = {(`ICACHE_INDEX_BITS+`ICACHE_BYTES_IN_LINE_LOG){1'b0}};
assign icScratchWrData = 8'b0;

assign dcScratchModeEn = 1'b0;
assign dcScratchWrEn = 1'b0;
assign dcScratchWrAddr = {(`DCACHE_INDEX_BITS+`DCACHE_BYTES_IN_LINE_LOG){1'b0}};
assign dcScratchWrData = 8'b0;

assign debugPRFWrEn = 1'b0;
assign debugPRFAddr = {(`SIZE_PHYSICAL_LOG+`SIZE_DATA_BYTE_OFFSET){1'b0}};
assign debugPRFWrData = {`SRAM_DATA_WIDTH{1'b0}};

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

    //.startPC_i                           (64'h0000000080000000),
    //.startPC_i                           (64'h00000000800000b4), //vvad
    .startPC_i                           (64'h00000000800001fc), //masked-filter

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
    //.instCacheBypass_i                   (instCacheBypass  ),
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
    .dc2memStSize_o                      (dc2memStSize_o     ), // memory read address
    .dc2memStValid_o                     (dc2memStValid_o    ), // memory read enable
                                                            
    .mem2dcStComplete_i                  (mem2dcStComplete_i ),
    .mem2dcStStall_i                     (mem2dcStStall_i    ),

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
  
`endif //ifdef INST_CACHE

//`ifdef DATA_CACHE
//  logic [32-`DCACHE_BLOCK_ADDR_BITS-1:0] ldPktDummy;
//  assign ldPktDummy = {(32-`DCACHE_BLOCK_ADDR_BITS){1'b0}};
//  
//  Packetizer_Piton #(
//      .PAYLOAD_WIDTH          (32),
//      .PACKET_WIDTH           (`DCACHE_LD_ADDR_PKT_BITS),
//      .ID                     (0),  // This should macth the ID of depacketizer in the TB
//      .DEPTH                  (4),  // Only one outstanding load miss at a time
//      .DEPTH_LOG              (2),
//      .N_PKTS_BITS            (2),
//      .THROTTLE               (0) // Throttling is disabled
//  )
//      pcx_packetizer (
//  
//      .reset                  (reset),
//  
//      .clk_payload            (coreClk),
//      .ic_req_i               (ic2memReqValid_o),
//      .ic_payload_i           ({instPktDummy,ic2memReqAddr_o}),
//      .dc_ld_req_i            (dc2memLdValid_o),
//      .dc_st_req_i            (dc2memStValid_o),
//      .dc_payload_i           ({dc2memLdAddr_o,dc2memStAddr_o,dc2memStData_o,dc2memStByteEn_o}),
//      .payload_grant_o        (),
//      .push_af_o              (pcx_packet_af),
//  
//      .clk_packet             (ioClk),
//      .packet_req_o           (spc0_pcx_req_pq),
//      .lock_o                 (),
//      .packet_o               (spc0_pcx_data_pa),
//      .packet_grant_i         (ldAddr_packet_req), // Request is looped back in
//      .packet_received_i      (pcx_spc0_grant_px)
//  );
//  
//  
//  
//  
//  logic [32-`DCACHE_BLOCK_ADDR_BITS-1:0] ldDePktDummy;
//  
//  Depacketizer_Piton #(
//      .PAYLOAD_WIDTH      (32+`DCACHE_BITS_IN_LINE),
//      .PACKET_WIDTH       (`DCACHE_LD_DATA_PKT_BITS),
//      .ID                 (1), // This should macth the ID of packetizer in the TB
//      .DEPTH              (4), // Only one outstanding load miss at a time
//      .DEPTH_LOG          (2),
//      .N_PKTS_BITS        (2),
//      .INST_NAME          ("cpx_depkt")
//  )
//      cpx_depacketizer (
//  
//      .reset              (reset),
//  
//      .clk_packet         (ioClk),
//      .cpx_packet_i       (cpx_spc0_data_cx2),
//      .cpx_packet_af_o    (cpx_depacket_af),
//  
//      .clk_payload        (coreClk),
//      .ic_payload_o       ({mem2icTag_i,mem2icIndex_i,mem2icData_i}),
//      .ic_payload_valid_o (mem2icRespValid_i),
//      .dc_payload_o       ({mem2dcLdTag_i,mem2dcLdIndex_i,mem2dcLdData_i}),
//      .dc_payload_valid_o (mem2dcLdValid_i),
//      .cpx_packet_received_o  ()
//  );
//  
//`endif


//ccx_to_cache_bridge
//
//cache_to_ccx_bridge

endmodule
