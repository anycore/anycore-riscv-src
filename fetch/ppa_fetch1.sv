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


module ppa_fetch1
(

    input                            clk,
    input                            reset,
    input                            resetFetch_i, // Resets everything except Cache

`ifdef SCRATCH_PAD
    input [`DEBUG_INST_RAM_LOG+`DEBUG_INST_RAM_WIDTH_LOG-1:0]   instScratchAddr_i   ,
    input [7:0]                      instScratchWrData_i ,
    input                            instScratchWrEn_i   ,
    output [7:0]                     instScratchRdData_o ,
    input                            instScratchPadEn_i,
`endif     

`ifdef INST_CACHE
    output [`ICACHE_BLOCK_ADDR_BITS-1:0]ic2memReqAddr_o,     // memory read address
    output                           ic2memReqValid_o,     // memory read enable
    input  [`ICACHE_TAG_BITS-1:0]    mem2icTag_i,          // tag of the incoming data
    input  [`ICACHE_INDEX_BITS-1:0]  mem2icIndex_i,        // index of the incoming data
    input  [`ICACHE_BITS_IN_LINE-1:0]   mem2icData_i,         // requested data
    input                            mem2icRespValid_i,    // requested data is ready
    input                            icScratchModeEn_i,    // Should ideally be disabled by default
    input [`ICACHE_INDEX_BITS+`ICACHE_BYTES_IN_LINE_LOG-1:0]  icScratchWrAddr_i,
    input                                                     icScratchWrEn_i,
    input [7:0]                                               icScratchWrData_i,
    output [7:0]                                              icScratchRdData_o,
`endif  

    output                           icMiss_o,

`ifdef DYNAMIC_CONFIG
    input [`FETCH_WIDTH-1:0]         fetchLaneActive_i,
    input                            stallFetch_i,
    input                            reconfigureCore_i,
`endif

    input  [`SIZE_PC-1:0]            startPC_i,


    /* fs2RecoverFlag_i and fs2RecoverPC_i are used to if there has been Branch
     * target misprediction for Direct control instruction (resolved during ID stage). */
    input                            fs2RecoverFlag_i,
    input  [`SIZE_PC-1:0]            fs2RecoverPC_i,
    
    /* fs2MissedCall_i is used only if the BTB missed the Call instruction and the
     * fs2CallPC_i has to be pushed into RAS. */
    input                            fs2MissedCall_i,
    input  [`SIZE_PC-1:0]            fs2CallPC_i,

    /* fs2MissedReturn_i is used only if the BTB missed the Return instruction and the
     * fs2RecoverPC_i has to be popped from RAS. */
    input                            fs2MissedReturn_i,

    /* Send the RAS TOS to FS2. Missed return instructions need their predNPC */
    output [`SIZE_PC-1:0]            addrRAS_o,
    output [1:0]                     predCounter_o [0:`FETCH_WIDTH-1],
    
    output reg                       fetchReq_o,
    output [`SIZE_PC-1:0]            instPC_o [0:`FETCH_WIDTH-1],
    input  [`SIZE_INSTRUCTION-1:0]   inst_i   [0:`FETCH_WIDTH-1],
    input                            instValid_i, //Indicates whether the instruction stream
                                                  // is valid in a particular cycle 

    /* fs1Ready_o indicates the fs2Packets are valid */
    output                           fs1Ready_o,

    /* Packets going to FS2 */
    output fs2Pkt                    fs2Packet_o [0:`FETCH_WIDTH-1],


    /* Ports for feth2Decode register stage */
    input [`SIZE_PC-1:0]             updatePC_i,
    input [`SIZE_PC-1:0]             updateNPC_i,
    input [`BRANCH_TYPE_LOG-1:0]         updateCtrlType_i,
    input                            updateDir_i,
    input [1:0]                      updateCounter_i,
    input                            updateEn_i,



    // Some common inputs needed in many stages
    input                            recoverFlag_i,
    input  [`SIZE_PC-1:0]            recoverPC_i,

    input                            exceptionFlag_i,
    input  [`SIZE_PC-1:0]            exceptionPC_i,


  	input                            instBufferFull_i,
    input                            ctiQueueFull_i
);

  // Wires from Fetch2Decode module
  wire [`SIZE_PC-1:0]               updatePC_l1;
  wire [`SIZE_PC-1:0]               updateNPC_l1;
  wire [`BRANCH_TYPE_LOG-1:0]           updateCtrlType_l1;
  wire                              updateDir_l1;
  wire [1:0]                        updateCounter_l1;
  wire                              updateEn_l1;


  FetchStage1 fs1(
    .clk                  (clk),
    .reset                (reset),
    .resetFetch_i         (resetFetch_i), // Does not reset the cache
  
    .startPC_i            (startPC_i),
  
  `ifdef SCRATCH_PAD
    .instScratchAddr_i    (instScratchAddr_i),
    .instScratchWrData_i  (instScratchWrData_i),
    .instScratchWrEn_i    (instScratchWrEn_i),
    .instScratchRdData_o  (instScratchRdData_o),
    .instScratchPadEn_i   (instScratchPadEn_i),
  `endif
  
  `ifdef INST_CACHE
    .ic2memReqAddr_o      (ic2memReqAddr_o     ),      // memory read address
    .ic2memReqValid_o     (ic2memReqValid_o    ),     // memory read enable
    .mem2icTag_i          (mem2icTag_i         ),          // tag of the incoming data
    .mem2icIndex_i        (mem2icIndex_i       ),        // index of the incoming data
    .mem2icData_i         (mem2icData_i        ),         // requested data
    .mem2icRespValid_i    (mem2icRespValid_i   ),    // requested data is ready
    .instCacheBypass_i    (instCacheBypass_i ),
    .icScratchModeEn_i    (icScratchModeEn_i),
  
    .icScratchWrAddr_i    (icScratchWrAddr_i),
    .icScratchWrEn_i      (icScratchWrEn_i  ),
    .icScratchWrData_i    (icScratchWrData_i),
    .icScratchRdData_o    (icScratchRdData_o),
  `endif  
  
  `ifdef PERF_MON
    .icMiss_o             (icMiss_o),
  `endif
    //TODO: stallFetch might not be needed as
    // it is part of instBufferFull
  `ifdef DYNAMIC_CONFIG  
  	//.stall_i              (instBufferFull | ctiQueueFull | stallFetch),
  	.stall_i              (instBufferFull_i | ctiQueueFull_i),
    .fetchLaneActive_i    (fetchLaneActive_i),
    .stallFetch_i         (stallFetch_i),
    .reconfigureCore_i    (reconfigureCore_i),
  `else
  	.stall_i              (instBufferFull_i | ctiQueueFull_i),
  `endif
  
  	.recoverFlag_i        (recoverFlag_i),
  	.recoverPC_i          (recoverPC_i),
  
  	.exceptionFlag_i      (exceptionFlag_i),
  	.exceptionPC_i        (exceptionPC_i),
  
  	.fs2RecoverFlag_i     (fs2RecoverFlag_i),
  	.fs2MissedCall_i      (fs2MissedCall_i),
  	.fs2CallPC_i          (fs2CallPC_i),
  	.fs2MissedReturn_i    (fs2MissedReturn_i),
  	.fs2RecoverPC_i       (fs2RecoverPC_i),
  
  	.updatePC_i           (updatePC_l1),
  	.updateNPC_i          (updateNPC_l1),
  	.updateBrType_i       (updateCtrlType_l1),
  	.updateDir_i          (updateDir_l1),
  	.updateCounter_i      (updateCounter_l1),
  	.updateEn_i           (updateEn_l1),
  
  	.instPC_o             (instPC_o),
    .fetchReq_o           (fetchReq_o),
  	.inst_i               (inst_i),
    .instValid_i          (instValid_i),
  
  	.fs1Ready_o           (fs1Ready_o),
  	.addrRAS_o            (addrRAS_o),
  	.predCounter_o        (predCounter_o),
  
  	.fs2Packet_o          (fs2Packet_o)
  
  	);


  Fetch2Decode fs2dec(
  	.clk                  (clk),
  	.reset                (reset),
  	.flush_i              (1'b0),
  	.stall_i              (1'b0),

  `ifdef DYNAMIC_CONFIG  
    .laneActive_i         ({`FETCH_WIDTH{1'b0}}),
  	.valid_bundle_o       (),
  `endif

  	.updatePC_i           (updatePC_i),
  	.updateNPC_i          (updateNPC_i),
  	.updateCtrlType_i     (updateCtrlType_i),
  	.updateDir_i          (updateDir_i),
  	.updateCounter_i      (updateCounter_i),
  	.updateEn_i           (updateEn_i),
  
  	.fs2Ready_i           (1'b0),
  
  	.decPacket_i          ({`DEC_PKT_SIZE*`FETCH_WIDTH{1'b0}}),
  	.decPacket_o          (),
  
  	.updatePC_o           (updatePC_l1),
  	.updateNPC_o          (updateNPC_l1),
  	.updateCtrlType_o     (updateCtrlType_l1),
  	.updateDir_o          (updateDir_l1),
  	.updateCounter_o      (updateCounter_l1),
  	.updateEn_o           (updateEn_l1),
  
  	.fs2Ready_o           ()
  	);


endmodule
