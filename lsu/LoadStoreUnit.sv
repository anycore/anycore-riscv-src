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

/*******************************************************************************
 Description of Load-Store Queue implementation:
 1. There is separate LQ and SQ for holding LDs and STs, respectively.

 2. On dispatch LDs and STs are inserted in LQ and SQ, respectively. LD also
    mark SQ entry holding the latest ST prior to it in the program order.

 3. When AGEN spits a LD to LSU, the LD goes to two parallel paths: a) data cache
    access and b) memory disambiguation logic (for ST-to-LD forwarding in case of
    a hit)
    Either of the two paths could be timing critical depending upon sizes of data
    cache and SQ (i.e. propagation delay would be different).

    note: data obtained from SQ has higher priority than data obtained from data
    cache.

 4. Timing path for ST-to-LD forwarding is more involved:
       i) LD broadcasts its address to SQ address-CAM, and in parallel a mask
          vector is generated to indicate which STs matter i.e all STs in SQ
          prior to this LD in program order.
       ii) associative search results in a match-vector which is further ANDed
          with the mask-vector.
       iii) the first hit is found in priority order and if one exists SQ
          data-RAM (using forwarding SQ-entry as address) is accessed to obtain
         data.
       iv) if a ST's address is unknown then it is ignored (hence the LD
          executes speculatively.)

 5. When AGEN spits a ST to LSU, the ST checks for any LD that should
    have waited for it. In case, it finds one then it generates violation flag
    for recovery.
    The logic to find violating LQ-entry is similar (and less complex) to
    ST-to-LD forwarding logic.
*******************************************************************************/

/*******************************************************************************
 Inputs:
 1. clk: Processor clock.
 2. reset: Processor reset signal.
 3. recoverFlag_i: Signal broadcasted by AL on the occurance of a bad-event
    (eg. branch-misprediction, load-violation).
 4. dispatchReady_i: Signal from Dispatch stage; if this signal is high then
    all back-end structures, i.e. AL, IQ, LQ, and SQ, have enough resources for
    instructions being dispatched.
 5. lsqPacket0_i: Dispatched instruction packet for LSU.
 6. commitStore0_i: Commit store signal from AL. It means the ST instruction,
    currently at the head of SQ, is also at the head AL, and it is ready
    to retire (or perform write to D-Cache).
    Note: STs write to memory units at the time of retirement only to maintain
          precise order.
 7. commitLoad0_i: Commit load signal from AL. It means the LD instruction,
    currently at the head of LQ, is also at the head of AL, and it is ready
    to retire.
 8. memPacketValid0_i: Signal from AGEN that the memory address of a LD or ST
    is ready.
 9. memPacket0_i: The packet, from AGEN, either contains a LD or ST instruction.
    The packet contains execution flags, memory address, and other control
    information.

 Outputs:
 1. lsqId0_o: LQ (SQ) entry assigned to the dispatched LD's (ST's)
    instruction packet. This entry act as LD (ST) indetification for LSU
    untill it retires.
 2. ldqCount_o: Current count of LD instructions in LQ.
 3. stqCount_o: Current count of ST instructions in SQ.
 4. lsuPacketValid0_o: Signal from LSU that either a LD or ST is ready for
    write-back.
 5. lsuPacket0_o: Write-back packet from LSU. This packet goes to Write-Back
    stage.
 6. ldViolationPacket_o: Load violation packet from LSU. This packet goes to
    Write-Back stage. If a ST, after its memory address is ready, detects that
    a LD performed write-back prematurely then it creates this packet for
    write-back stage.
*******************************************************************************/

`timescale 1ns/100ps

module LSU (
	input                                 clk,
	input                                 reset,
	input                                 resetRams_i,
	input                                 recoverFlag_i,

`ifdef SCRATCH_PAD  
  input                                 dataScratchPadEn_i,
`endif  

`ifdef DYNAMIC_CONFIG  
  input  [`DISPATCH_WIDTH-1:0]          dispatchLaneActive_i,
  input  [`COMMIT_WIDTH-1:0]            commitLaneActive_i,
  input  [`STRUCT_PARTS_LSQ-1:0]        lsqPartitionActive_i,
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
    input  [`DCACHE_BITS_IN_LINE-1:0]      mem2dcLdData_i,      // requested data
    input                               mem2dcLdValid_i,     // indicates the requested data is ready

    // cache-to-memory interface for stores
    output [`DCACHE_ST_ADDR_BITS-1:0]   dc2memStAddr_o,  // memory read address
    output [`SIZE_DATA-1:0]             dc2memStData_o,  // memory read address
    output [`SIZE_DATA_BYTE-1:0]        dc2memStByteEn_o,  // memory read address
    output reg                          dc2memStValid_o, // memory read enable

    // memory-to-cache interface for stores
    input                               mem2dcStComplete_i,
    input                               mem2dcStStall_i,

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

`ifdef SCRATCH_PAD
  input  [`DEBUG_DATA_RAM_LOG+`DEBUG_DATA_RAM_WIDTH_LOG-1:0]  dataScratchAddr_i   ,
  input  [7:0]                          dataScratchWrData_i ,
  input                                 dataScratchWrEn_i   ,
  output [7:0]                          dataScratchRdData_o ,
`endif
	input                                 dispatchReady_i,

	input  lsqPkt                         lsqPacket_i [0:`DISPATCH_WIDTH-1],
                                        
	output [`SIZE_LSQ_LOG-1:0]            lsqID_o     [0:`DISPATCH_WIDTH-1],
	                                      
	input  [`COMMIT_WIDTH-1:0]            commitLoad_i,
	input  [`COMMIT_WIDTH-1:0]            commitStore_i,
                                        
	input  memPkt                         memPacket_i,
                                        
	output [`SIZE_LSQ_LOG:0]              ldqCount_o,
	output [`SIZE_LSQ_LOG:0]              stqCount_o,

	output wbPkt                          wbPacket_o,
	output ldVioPkt                       ldVioPacket_o,
  output exceptionPkt                   memExcptPacket_o,
  output [`SIZE_VIRT_ADDR-1:0]        stCommitAddr_o,
  output [`SIZE_VIRT_ADDR-1:0]        ldCommitAddr_o,

	/* To memory */
	output [`SIZE_PC-1:0]                 ldAddr_o,
	input  [`SIZE_DATA-1:0]               ldData_i,
  input                                 ldDataValid_i,
	output                                ldEn_o,
  input  exceptionPkt                   ldException_i,

	output [`SIZE_PC-1:0]                 stAddr_o,
	output [`SIZE_DATA-1:0]               stData_o,
	output [7:0]                          stEn_o,
  input  exceptionPkt                   stException_i,

	output [1:0]                          ldStSize_o,

  output                                ldqRamReady_o, 
  output                                stqRamReady_o 
	);

wire [`SIZE_LSQ_LOG-1:0]               ldqHead;
wire [`SIZE_LSQ_LOG-1:0]               ldqHead_t;
wire [`SIZE_LSQ_LOG-1:0]               ldqHeadPlusOne;
wire [`SIZE_LSQ_LOG-1:0]               ldqTail;
wire [`SIZE_LSQ_LOG-1:0]               stqHead;
wire [`SIZE_LSQ_LOG:0]                 stqCount;
wire [`SIZE_LSQ_LOG:0]                 ldqCount;
wire [`COMMIT_WIDTH_LOG:0]             commitLdCount;
wire                                   commitSt;
reg  [`SIZE_LSQ_LOG-1:0]               ldqID [0:`DISPATCH_WIDTH-1];
reg  [`SIZE_LSQ_LOG-1:0]               stqID [0:`DISPATCH_WIDTH-1];
reg  [`SIZE_LSQ_LOG-1:0]               commitLdIndex [0:`COMMIT_WIDTH-1];
                                       
reg  [`SIZE_LSQ_LOG-1:0]               lastStIndex   [0:`DISPATCH_WIDTH-1];
                                       
reg  [`SIZE_LSQ_LOG-1:0]               nextLdIndex   [0:`DISPATCH_WIDTH-1];
                                       
wire [`SIZE_LSQ-1:0]                   stqAddrValid_on_recover;
wire [`SIZE_LSQ_LOG-1:0]               stqTail;


assign stqCount_o                    = stqCount;
assign ldqCount_o                    = ldqCount;

/* Instantiate lsu control and datapath here */

LSUControl control (     
	.clk                                 (clk),
	.reset                               (reset),
	.recoverFlag_i                       (recoverFlag_i),

`ifdef DYNAMIC_CONFIG
  .lsqPartitionActive_i                (lsqPartitionActive_i),
`endif  
                                       
`ifdef DATA_CACHE
  .stallStCommit_i                     (stallStCommit_o),
`endif

	.dispatchReady_i                     (dispatchReady_i),
                                       
	.commitLoad_i                        (commitLoad_i),
	.commitStore_i                       (commitStore_i),
                                       
	.lsqPacket_i                         (lsqPacket_i),
	.lsqID_o                             (lsqID_o),
                                       
	//output to top                      
	.ldqCount_o                          (ldqCount),
                                       
	//output to datapath                 
	.ldqHead_o                           (ldqHead),
	.ldqHead_t_o                         (ldqHead_t),
	.ldqHeadPlusOne_o                    (ldqHeadPlusOne),
	.ldqTail_o                           (ldqTail),
	.stqHead_o                           (stqHead),
	.stqCount_o                          (stqCount),
	.commitLdCount_o                     (commitLdCount),
	.commitSt_o                          (commitSt),
                                       
	.ldqID_o                             (ldqID),
	.stqID_o                             (stqID),
	.commitLdIndex_o                     (commitLdIndex),
	.lastStIndex_o                       (lastStIndex),
                                       
	.nextLdIndex_o                       (nextLdIndex),
                                       
	.stqAddrValid_on_recover             (stqAddrValid_on_recover),
	.stqTail_o                           (stqTail)
	);


LSUDatapath datapath ( 
  //inputs from top
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
  .dispatchLaneActive_i         (dispatchLaneActive_i),
  .commitLaneActive_i           (commitLaneActive_i),
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
  .dc2memStByteEn_o             (dc2memStByteEn_o   ), // memory read address
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
	.dispatchReady_i               (dispatchReady_i),
	
	.lsqPacket_i                  (lsqPacket_i),
	
	.memPacket_i                  (memPacket_i),
                                
	//inputs frm control          
	.ldqHead_i                    (ldqHead),
	.ldqHead_t_i                  (ldqHead_t),
	.ldqHeadPlusOne_i             (ldqHeadPlusOne),
	.ldqTail_i                    (ldqTail),
	.ldqCount_i                   (ldqCount),
	.stqHead_i                    (stqHead),
	.stqCount_i                   (stqCount),
	.commitLdCount_i              (commitLdCount),
	.commitSt_i                   (commitSt),
                                
	.ldqID_i                      (ldqID),
	.stqID_i                      (stqID),
	.commitLdIndex_i              (commitLdIndex),
	.lastStIndex_i                (lastStIndex),
                                
	.nextLdIndex_i                (nextLdIndex),
                                
	.stqAddrValid_on_recover_i    (stqAddrValid_on_recover),
	.stqTail_i                    (stqTail),
                                       
	//outputs to top                     
	.wbPacket_o                   (wbPacket_o),
	.ldVioPacket_o                (ldVioPacket_o),
  .memExcptPacket_o             (memExcptPacket_o),
  .stCommitAddr_o               (stCommitAddr_o),
  .ldCommitAddr_o               (ldCommitAddr_o),

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

  .ldqRamReady_o                (ldqRamReady_o),
  .stqRamReady_o                (stqRamReady_o)
	);

endmodule




