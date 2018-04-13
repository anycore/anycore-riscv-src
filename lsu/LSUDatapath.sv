/*************************NORTH CAROLINA STATE UNIVERSITY***********************
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

module LSUDatapath (
	input                               clk,
	input                               reset,
	input                               resetRams_i,
	input                               recoverFlag_i,
	input                               dispatchReady_i,

`ifdef SCRATCH_PAD  
  input                               dataScratchPadEn_i,
  input  [`DEBUG_DATA_RAM_LOG+`DEBUG_DATA_RAM_WIDTH_LOG-1:0]  dataScratchAddr_i   ,
  input  [7:0]                        dataScratchWrData_i ,
  input                               dataScratchWrEn_i   ,
  output [7:0]                        dataScratchRdData_o ,
`endif  

`ifdef DYNAMIC_CONFIG
  input [`STRUCT_PARTS_LSQ-1:0]       lsqPartitionActive_i,
  input [`DISPATCH_WIDTH-1:0]         dispatchLaneActive_i,
  input [`COMMIT_WIDTH-1:0]           commitLaneActive_i,
`endif  

`ifdef DATA_CACHE
  input                               dataCacheBypass_i,
  input                               dcScratchModeEn_i,

  // cache-to-memory interface for Loads
  output [`DCACHE_BLOCK_ADDR_BITS-1:0]  dc2memLdAddr_o,  // memory read address
  output reg                          dc2memLdValid_o, // memory read enable

  // memory-to-cache interface for Loads
  input  [`DCACHE_TAG_BITS-1:0]       mem2dcLdTag_i,       // tag of the incoming datadetermine
  input  [`DCACHE_INDEX_BITS-1:0]     mem2dcLdIndex_i,     // index of the incoming data
  input  [`DCACHE_BITS_IN_LINE-1:0]   mem2dcLdData_i,      // requested data
  input                               mem2dcLdValid_i,     // indicates the requested data is ready

  // cache-to-memory interface for stores
  output [`DCACHE_ST_ADDR_BITS-1:0]   dc2memStAddr_o,  // memory read address
  output [`SIZE_DATA-1:0]             dc2memStData_o,  // memory read address
  output [2:0]                        dc2memStSize_o,  // memory read address
  output reg                          dc2memStValid_o, // memory read enable

  // memory-to-cache interface for stores
  input                               mem2dcStComplete_i,
  input                               mem2dcStStall_i   ,

  output                              stallStCommit_o,

  input [`DCACHE_INDEX_BITS+`DCACHE_BYTES_IN_LINE_LOG-1:0]  dcScratchWrAddr_i,
  input                                                     dcScratchWrEn_i,
  input [7:0]                                               dcScratchWrData_i,
  output [7:0]                                              dcScratchRdData_o,

  input                               dcFlush_i,
  output                              dcFlushDone_o,
`endif

  output                              ldMiss_o,
  output                              stMiss_o,

	/* inputs from dispatch */
	input  lsqPkt                       lsqPacket_i [0:`DISPATCH_WIDTH-1],

	/* inputs from AGEN */
	input  memPkt                       memPacket_i,

	/* inputs from LSUControl */
	input [`SIZE_LSQ_LOG-1:0]           ldqHead_i,
	input [`SIZE_LSQ_LOG-1:0]           ldqHead_t_i,
	input [`SIZE_LSQ_LOG-1:0]           ldqHeadPlusOne_i,
	input [`SIZE_LSQ_LOG-1:0]           ldqTail_i,
	input [`SIZE_LSQ_LOG:0]             ldqCount_i,
	input [`SIZE_LSQ_LOG-1:0]           stqHead_i,
	input [`SIZE_LSQ_LOG:0]             stqCount_i,
	input [`COMMIT_WIDTH_LOG:0]         commitLdCount_i,
	input                               commitSt_i,

	input  [`SIZE_LSQ_LOG-1:0]          ldqID_i         [0:`DISPATCH_WIDTH-1],
	input  [`SIZE_LSQ_LOG-1:0]          stqID_i         [0:`DISPATCH_WIDTH-1],
	input  [`SIZE_LSQ_LOG-1:0]          commitLdIndex_i [0:`COMMIT_WIDTH-1],

	input  [`SIZE_LSQ_LOG-1:0]          lastStIndex_i   [0:`DISPATCH_WIDTH-1],

	input  [`SIZE_LSQ_LOG-1:0]          nextLdIndex_i   [0:`DISPATCH_WIDTH-1],

	input  [`SIZE_LSQ-1:0]              stqAddrValid_on_recover_i,
	input  [`SIZE_LSQ_LOG-1:0]          stqTail_i,

	/* output to writeback stage */
	output wbPkt                        wbPacket_o,
	output ldVioPkt                     ldVioPacket_o,
  output exceptionPkt                 memExcptPacket_o,
  output [`SIZE_VIRT_ADDR-1:0]      stCommitAddr_o,
  output [`SIZE_VIRT_ADDR-1:0]      ldCommitAddr_o,

	/* To memory */
	output  [`SIZE_PC-1:0]              ldAddr_o,
	input   [`SIZE_DATA-1:0]            ldData_i,
  input                               ldDataValid_i,
	output                              ldEn_o,
  input   exceptionPkt                ldException_i,

	output  [`SIZE_PC-1:0]              stAddr_o,
	output  [`SIZE_DATA-1:0]            stData_o,
	output  [7:0]                       stEn_o,
  input   exceptionPkt                stException_i,

	output  [1:0]                       ldStSize_o,

  output                              ldqRamReady_o, 
  output                              stqRamReady_o 
);

//memPkt                                 memPacket;
memPkt                                 ldPacket;
memPkt                                 stPacket;
memPkt                                 replayPacket;
memPkt                                 replayPacket_l1;

ldVioPkt                               ldxVioPacket;
ldVioPkt                               stxVioPacket;

wire [`SIZE_DATA-1:0]                  loadData;
wire                                   loadDataValid;

exeFlgs                                memPacket_i_flags;
exeFlgs                                memPacket_flags;

assign memPacket_i_flags              = memPacket_i.flags;
//assign memPacket_flags                = memPacket.flags;

// Register ReplayPacket once to get better timing
//always_ff @(posedge clk)
//begin
//  replayPacket_l1 <=  replayPacket;
//end
always_comb
begin
  replayPacket_l1 =  replayPacket;
end


/* Choose which packet executes in this cycle. From highest to lowest priority
 *  (1): packet from agen 
 *  (2): replay packet (loads predicted to violate) */
always_comb
begin
  // An incoming load
  // Allow a replay packet to be exposed to the cache only
  // if a memPacket (load or store) is not being exposed to
  // cache in this cycle.
	if (memPacket_i.valid & memPacket_i_flags.destValid)
	begin
		ldPacket          = memPacket_i;
	end
	else if (~memPacket_i.valid & replayPacket_l1.valid)
	begin
		ldPacket          = replayPacket_l1;
	end
	else
	begin
		ldPacket          = 0;
	end
end

always_comb
begin
  // An incoming store
	if (memPacket_i.valid & ~memPacket_i_flags.destValid)
	begin
		stPacket          = memPacket_i;
	end
	else
	begin
		stPacket          = 0;
	end
end

/* Form write back Packet */
// If the packet is a store, send back the writeback packet.
// If the packet is a load, read hit has the highest prority
// followed by load fill bypasses. If the data is from a read hit,
// form writeback packet using memPacket. If the data is from a
// fill bypass, create the writeback packet using info from MHSR.
always_comb
begin
	wbPacket_o                  = 0;
	ldVioPacket_o               = 0;

	//if (~memPacket_flags.destValid) // Is a store
	if (stPacket.valid) // Is a store
	begin
		wbPacket_o.seqNo          = stPacket.seqNo;
		wbPacket_o.flags          = stPacket.flags;
		wbPacket_o.alID           = stPacket.alID;
		wbPacket_o.valid          = stPacket.valid;
                              
		ldVioPacket_o             = stxVioPacket;
	end

	else
	begin
		wbPacket_o.seqNo          = ldPacket.seqNo;
		wbPacket_o.flags          = ldPacket.flags;
		wbPacket_o.flags.executed = 1'h1;
		wbPacket_o.phyDest        = ldPacket.phyDest;
		wbPacket_o.destData       = loadData;
		wbPacket_o.alID           = ldPacket.alID;
		wbPacket_o.valid          = ldPacket.valid && loadDataValid;
                              
		ldVioPacket_o             = ldxVioPacket;
	end
end


STX_path_structured stx_path (
	.clk                          (clk),
	.reset                        (reset),
  .resetRams_i                  (resetRams_i),

  `ifdef DYNAMIC_CONFIG
    .lsqPartitionActive_i       (lsqPartitionActive_i),
    .dispatchLaneActive_i       (dispatchLaneActive_i),
    .commitLaneActive_i         (commitLaneActive_i),
  `endif

	.recoverFlag_i                (recoverFlag_i),
	.dispatchReady_i              (dispatchReady_i),

	.lsqPacket_i                  (lsqPacket_i),

	//.memPacket_i                  (memPacket),
	.ldPacket_i                   (ldPacket),
	.stPacket_i                   (stPacket),

	/* outputs to dp */
	.replayPacket_o               (replayPacket),

	.stxVioPacket_o               (stxVioPacket),
  .ldCommitAddr_o               (ldCommitAddr_o),

	/* inputs from stq */
	.loadDataValid_i              (loadDataValid),

	/* inputs from control */
	.ldqHead_i                    (ldqHead_i),
	.ldqHead_t_i                  (ldqHead_t_i),
	.ldqHeadPlusOne_i             (ldqHeadPlusOne_i),
	.ldqTail_i                    (ldqTail_i),
	.ldqCount_i                   (ldqCount_i),

	.commitLdCount_i              (commitLdCount_i),

	.ldqID_i                      (ldqID_i),
	.stqID_i                      (stqID_i),
	.commitLdIndex_i              (commitLdIndex_i),
	.nextLd_i                     (nextLdIndex_i),
  .ldqRamReady_o                (ldqRamReady_o)
);



LDX_path_structured ldx_path (
	.clk                          (clk),
	.reset                        (reset),
  .resetRams_i                  (resetRams_i),

`ifdef SCRATCH_PAD  
  .dataScratchPadEn_i           (dataScratchPadEn_i),
  .dataScratchAddr_i            (dataScratchAddr_i),
  .dataScratchWrData_i          (dataScratchWrData_i),
  .dataScratchWrEn_i            (dataScratchWrEn_i),
  .dataScratchRdData_o          (dataScratchRdData_o),
`endif  

`ifdef DYNAMIC_CONFIG
  .lsqPartitionActive_i         (lsqPartitionActive_i),
`endif


`ifdef DATA_CACHE
  .dataCacheBypass_i            (dataCacheBypass_i  ),
  .dcScratchModeEn_i            (dcScratchModeEn_i  ),

  .dc2memLdAddr_o               (dc2memLdAddr_o     ), // memory read address
  .dc2memLdValid_o              (dc2memLdValid_o    ), // memory read enable
                                                   
  .mem2dcLdTag_i                (mem2dcLdTag_i      ), // tag of the incoming datadetermine
  .mem2dcLdIndex_i              (mem2dcLdIndex_i    ), // index of the incoming data
  .mem2dcLdData_i               (mem2dcLdData_i     ), // requested data
  .mem2dcLdValid_i              (mem2dcLdValid_i    ), // indicates the requested data is ready
                                                   
  .dc2memStAddr_o               (dc2memStAddr_o     ), // memory read address
  .dc2memStData_o               (dc2memStData_o     ), // memory read address
  .dc2memStSize_o               (dc2memStSize_o     ), // memory read address
  .dc2memStValid_o              (dc2memStValid_o    ), // memory read enable
                                                   
  .mem2dcStComplete_i           (mem2dcStComplete_i ),
  .mem2dcStStall_i              (mem2dcStStall_i    ),

  .stallStCommit_o              (stallStCommit_o    ),

  .dcScratchWrAddr_i            (dcScratchWrAddr_i),
  .dcScratchWrEn_i              (dcScratchWrEn_i  ),
  .dcScratchWrData_i            (dcScratchWrData_i),
  .dcScratchRdData_o            (dcScratchRdData_o),

  .dcFlush_i                    (dcFlush_i),
  .dcFlushDone_o                (dcFlushDone_o),
`endif    

  .ldMiss_o                     (ldMiss_o),
  .stMiss_o                     (stMiss_o),

	.recoverFlag_i                (recoverFlag_i),
	.dispatchReady_i              (dispatchReady_i),

	.lsqPacket_i                  (lsqPacket_i),

	//.memPacket_i                  (memPacket),
	.ldPacket_i                   (ldPacket),
	.stPacket_i                   (stPacket),

	.stqCount_i                   (stqCount_i),
	.commitLdCount_i              (commitLdCount_i),

	.ldxVioPacket_o               (ldxVioPacket),
  .memExcptPacket_o             (memExcptPacket_o),
  .stCommitAddr_o               (stCommitAddr_o),

	.loadDataValid_o              (loadDataValid),
	.loadData_o                   (loadData),

	.commitSt_i                   (commitSt_i),
	.stqHead_i                    (stqHead_i),
	.stqTail_i                    (stqTail_i),
	.stqAddrValid_on_recover_i    (stqAddrValid_on_recover_i),

	.ldqID_i                      (ldqID_i),
	.commitLdIndex_i              (commitLdIndex_i),
	.lastSt_i                     (lastStIndex_i),

	.ldAddr_o                     (ldAddr_o),
	.ldData_i                     (ldData_i),
  .ldDataValid_i                (ldDataValid_i),
	.ldEn_o                       (ldEn_o),
  .ldException_i                (ldException_i),

	.stAddr_o                     (stAddr_o),
	.stData_o                     (stData_o),
	.stEn_o                       (stEn_o),
  .stException_i                (stException_i),

  .ldStSize_o                   (ldStSize_o),
  .stqRamReady_o                (stqRamReady_o)
);


endmodule
