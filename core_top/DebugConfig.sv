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

module DebugConfig(
    input                              ioClk,
    input                              coreClk,
    input                              reset,
    input                              resetFetch_i,
	  input                              cacheModeOverride_i,

    output                             reset_sync_o,
    output                             resetFetch_sync_o,

    input  [5:0]                       regAddr_i,     //64 registers
    input  [`REG_DATA_WIDTH-1:0]       regWrData_i,
    input                              regWrEn_i,
    output logic [`REG_DATA_WIDTH-1:0] regRdData_o,

    input   [`SIZE_PC-1:0]             currentInstPC_i,

`ifdef DYNAMIC_CONFIG
    input                              stallFetch_i,
    input                              reconfigureCore_i,
    output                             stallFetch_sync_o, 
    output                             reconfigureCore_sync_o,
    output [`FETCH_WIDTH-1:0]          fetchLaneActive_o,
    output [`DISPATCH_WIDTH-1:0]       dispatchLaneActive_o,
    output [`ISSUE_WIDTH-1:0]          issueLaneActive_o,         
    output [`ISSUE_WIDTH-1:0]           execLaneActive_o,
    output [`ISSUE_WIDTH-1:0]           saluLaneActive_o,
    output [`ISSUE_WIDTH-1:0]           caluLaneActive_o,
    output [`COMMIT_WIDTH-1:0]         commitLaneActive_o,
    output [`NUM_PARTS_RF-1:0]         rfPartitionActive_o,
    output [`NUM_PARTS_AL-1:0]         alPartitionActive_o,
    output [`STRUCT_PARTS_LSQ-1:0]     lsqPartitionActive_o,
    output [`NUM_PARTS_IQ-1:0]         iqPartitionActive_o,
    output [`STRUCT_PARTS-1:0]         ibuffPartitionActive_o,
    input                              reconfigDone_i,
    input                              pipeDrained_i,
`endif

`ifdef SCRATCH_PAD
    output [`DEBUG_INST_RAM_LOG+`DEBUG_INST_RAM_WIDTH_LOG-1:0] instScratchAddr_o,
    output [7:0]                       instScratchWrData_o,  
    output                             instScratchWrEn_o,  
    input  [7:0]                       instScratchRdData_i,  
    output [`DEBUG_DATA_RAM_LOG+`DEBUG_DATA_RAM_WIDTH_LOG-1:0] dataScratchAddr_o,
    output [7:0]                       dataScratchWrData_o,
    output                             dataScratchWrEn_o,  
    input  [7:0]                       dataScratchRdData_i, 
    output [1:0]                       scratchPadEn_o,
`endif

`ifdef INST_CACHE
    output                             instCacheBypass_o,
    output                             icScratchModeEn_o,
    output [`ICACHE_INDEX_BITS+`ICACHE_BYTES_IN_LINE_LOG-1:0] icScratchWrAddr_o,
    output                                                    icScratchWrEn_o,
    output [7:0]                                              icScratchWrData_o,
    input  [7:0]                                              icScratchRdData_i,
`endif

`ifdef DATA_CACHE
    output                             dataCacheBypass_o,
    output                             dcScratchModeEn_o,
    output [`DCACHE_INDEX_BITS+`DCACHE_BYTES_IN_LINE_LOG-1:0] dcScratchWrAddr_o,
    output                                                    dcScratchWrEn_o,
    output [7:0]                                              dcScratchWrData_o,
    input  [7:0]                                              dcScratchRdData_i,
`endif

`ifdef PERF_MON
    input  [31:0]                      perfMonRegData_i,
    output [`REG_DATA_WIDTH-1:0]       perfMonRegAddr_o,
    output                             perfMonRegGlobalClr_o,
    output                             perfMonRegClr_o,
    output 		                         perfMonRegRun_o,
`endif
    output [`SIZE_PHYSICAL_LOG+`SIZE_DATA_BYTE_OFFSET-1:0]     debugPRFAddr_o, 
    input  [7:0]                       debugPRFRdData_i,    
    output [7:0]                       debugPRFWrData_o,
    output                             debugPRFWrEn_o,

	  output [`SIZE_RMT_LOG-1:0]         debugAMTAddr_o,
	  input  [`SIZE_PHYSICAL_LOG-1:0]    debugAMTRdData_i
  );

`define CHIP_ID 8'hAC // Stands for Anycore


    logic  [`SIZE_PC-1:0]             currentInstPC_ioClk;

`ifdef DYNAMIC_CONFIG
    logic [`FETCH_WIDTH-1:0]          fetchLaneActive;
    logic [`DISPATCH_WIDTH-1:0]       dispatchLaneActive;
    logic [`ISSUE_WIDTH-1:0]          issueLaneActive;         
    logic [`ISSUE_WIDTH-1:0]           execLaneActive;
    logic [`ISSUE_WIDTH-1:0]           saluLaneActive;
    logic [`ISSUE_WIDTH-1:0]           caluLaneActive;
    logic [`COMMIT_WIDTH-1:0]         commitLaneActive;
    logic [`NUM_PARTS_RF-1:0]         rfPartitionActive;
    logic [`NUM_PARTS_AL-1:0]         alPartitionActive;
    logic [`STRUCT_PARTS_LSQ-1:0]     lsqPartitionActive;
    logic [`NUM_PARTS_IQ-1:0]         iqPartitionActive;
    logic [`STRUCT_PARTS-1:0]         ibuffPartitionActive;


    logic                             stallFetch_sync1, reconfigureCore_sync1;
    logic                             stallFetch_sync2, reconfigureCore_sync2;
    logic [`FETCH_WIDTH-1:0]          fetchLaneActive_sync;
    logic [`DISPATCH_WIDTH-1:0]       dispatchLaneActive_sync;
    logic [`ISSUE_WIDTH-1:0]          issueLaneActive_sync;         
    logic [`ISSUE_WIDTH-1:0]           execLaneActive_sync;
    logic [`ISSUE_WIDTH-1:0]           saluLaneActive_sync;
    logic [`ISSUE_WIDTH-1:0]           caluLaneActive_sync;
    logic [`COMMIT_WIDTH-1:0]         commitLaneActive_sync;
    logic [`NUM_PARTS_RF-1:0]         rfPartitionActive_sync;
    logic [`NUM_PARTS_AL-1:0]         alPartitionActive_sync;
    logic [`STRUCT_PARTS_LSQ-1:0]     lsqPartitionActive_sync;
    logic [`NUM_PARTS_IQ-1:0]         iqPartitionActive_sync;
    logic [`STRUCT_PARTS-1:0]         ibuffPartitionActive_sync;

    logic                             clearDrainedStatus;
    logic                             pipeDrained_latch;
    logic                             reconfigDone_latch;
`endif


`ifdef SCRATCH_PAD
    logic [`DEBUG_INST_RAM_LOG+`DEBUG_INST_RAM_WIDTH_LOG-1:0] instScratchAddr;
    logic [7:0]                       instScratchWrData;  
    logic                             instScratchWrEn ;  
    logic [`DEBUG_DATA_RAM_LOG+`DEBUG_DATA_RAM_WIDTH_LOG-1:0] dataScratchAddr;
    logic [7:0]                       dataScratchWrData;
    logic                             dataScratchWrEn;  
    logic [`DEBUG_INST_RAM_LOG+`DEBUG_INST_RAM_WIDTH_LOG-1:0]  instScratchAddr_sync;
    logic [7:0]                       instScratchWrData_sync;  
    logic                             instScratchWrEn_sync; 
    logic [`DEBUG_DATA_RAM_LOG+`DEBUG_DATA_RAM_WIDTH_LOG-1:0]  dataScratchAddr_sync;
    logic [7:0]                       dataScratchWrData_sync;  
    logic                             dataScratchWrEn_sync;  
    logic [7:0]                       instScratchRdData_ioClk;
    logic [7:0]                       dataScratchRdData_ioClk;
    logic [1:0]                       scratchPadEn;
    logic [1:0]                       scratchPadEn_sync;
`endif

    logic                              icScratchModeEn;
    logic                              instCacheBypass;
`ifdef INST_CACHE
    logic [`ICACHE_BLOCK_ADDR_BITS-1:0]  ic2memReqAddr_o;      // memory read address
    logic                              ic2memReqValid_o;     // memory read enable
    logic [`ICACHE_TAG_BITS-1:0]       mem2icTag_i;          // tag of the incoming data
    logic [`ICACHE_INDEX_BITS-1:0]     mem2icIndex_i;        // index of the incoming data
    logic [`ICACHE_BITS_IN_LINE-1:0]      mem2icData_i;         // requested data
    logic                              mem2icRespValid_i;    // requested data is ready
    logic                              icScratchModeEn_sync;
    logic                              instCacheBypass_sync;

    logic [`ICACHE_INDEX_BITS+`ICACHE_BYTES_IN_LINE_LOG-1:0] icScratchWrAddr;
    logic                                                    icScratchWrEn;
    logic [7:0]                                              icScratchWrData;
    logic [`ICACHE_INDEX_BITS+`ICACHE_BYTES_IN_LINE_LOG-1:0] icScratchWrAddr_sync;
    logic                                                    icScratchWrEn_sync;
    logic [7:0]                                              icScratchWrData_sync;
    logic [7:0]                                              icScratchRdData_ioClk;
`endif  

    logic                              dcScratchModeEn;
    logic                              dataCacheBypass;
`ifdef DATA_CACHE
    logic                              dcScratchModeEn_sync;
    logic                              dataCacheBypass_sync;

    // cache-to-memory interface for Loads
    logic [`DCACHE_BLOCK_ADDR_BITS-1:0]  dc2memLdAddr_o;  // memory read address
    logic                              dc2memLdValid_o; // memory read enable

    // memory-to-cache interface for Loads
    logic  [`DCACHE_TAG_BITS-1:0]      mem2dcLdTag_i;       // tag of the incoming datadetermine
    logic  [`DCACHE_INDEX_BITS-1:0]    mem2dcLdIndex_i;     // index of the incoming data
    logic  [`DCACHE_BITS_IN_LINE-1:0]     mem2dcLdData_i;      // requested data
    logic                              mem2dcLdValid_i;     // indicates the requested data is ready

    // cache-to-memory interface for stores
    logic [`DCACHE_ST_ADDR_BITS-1:0]   dc2memStAddr_o;  // memory read address
    logic [`SIZE_DATA-1:0]             dc2memStData_o;  // memory read address
    logic [3:0]                        dc2memStByteEn_o;  // memory read address
 
    logic                              dc2memStValid_o; // memory read enable

    logic [`DCACHE_INDEX_BITS+`DCACHE_BYTES_IN_LINE_LOG-1:0] dcScratchWrAddr;
    logic                                                    dcScratchWrEn;
    logic [7:0]                                              dcScratchWrData;
    logic [`DCACHE_INDEX_BITS+`DCACHE_BYTES_IN_LINE_LOG-1:0] dcScratchWrAddr_sync;
    logic                                                    dcScratchWrEn_sync;
    logic [7:0]                                              dcScratchWrData_sync;
    logic [7:0]                                              dcScratchRdData_ioClk;
`endif

    logic [`SIZE_PHYSICAL_LOG+`SIZE_DATA_BYTE_OFFSET-1:0]     debugPRFAddr; 
    logic [7:0]                       debugPRFWrData;
    logic                             debugPRFWrEn;
    logic [`SIZE_PHYSICAL_LOG+`SIZE_DATA_BYTE_OFFSET-1:0]      debugPRFAddr_sync; 
    logic [7:0]                       debugPRFWrData_sync;
    logic                             debugPRFWrEn_sync; 
    logic [7:0]                       debugPRFRdData_ioClk;    

    logic [`SIZE_RMT_LOG-1:0]         debugAMTAddr; 
    logic [`SIZE_RMT_LOG-1:0]         debugAMTAddr_sync; 
    logic [`SIZE_PHYSICAL_LOG-1:0]    debugAMTRdData_ioClk;    


    logic [7:0]                       scratchRegister;

`ifdef PERF_MON
    logic [31:0]                      perfMonRegData_ioClk;
    logic [`REG_DATA_WIDTH-1:0]       perfMonRegAddr;
    logic [`REG_DATA_WIDTH-1:0]       perfMonRegAddr_sync;
    logic                             perfMonRegGlobalClr;
    logic                             perfMonRegGlobalClr_sync;
    logic                             perfMonRegClr;
    logic                             perfMonRegClr_sync;
    logic 		                        perfMonRegRun;
    logic 		                        perfMonRegRun_sync;
`endif

    logic   reset_sync1,reset_sync2;
    logic   resetFetch_sync1,resetFetch_sync2;
    logic   cacheModeOverride_sync1,cacheModeOverride_sync2;

`ifdef DYNAMIC_CONFIG
  assign  stallFetch_sync_o      = stallFetch_sync2         ; 
  assign  reconfigureCore_sync_o = reconfigureCore_sync2    ;
  assign  fetchLaneActive_o      = fetchLaneActive_sync     ;
  assign  dispatchLaneActive_o   = dispatchLaneActive_sync  ;
  assign  issueLaneActive_o      = issueLaneActive_sync     ;         
  assign  execLaneActive_o       = execLaneActive_sync      ;
  assign  saluLaneActive_o       = saluLaneActive_sync      ;
  assign  caluLaneActive_o       = caluLaneActive_sync      ;
  assign  commitLaneActive_o     = commitLaneActive_sync    ;
  assign  rfPartitionActive_o    = rfPartitionActive_sync   ;
  assign  alPartitionActive_o    = alPartitionActive_sync   ;
  assign  lsqPartitionActive_o   = lsqPartitionActive_sync  ;
  assign  iqPartitionActive_o    = iqPartitionActive_sync   ;
  assign  ibuffPartitionActive_o = ibuffPartitionActive_sync;
`endif

`ifdef SCRATCH_PAD
  assign instScratchAddr_o        = instScratchAddr_sync    ;
  assign instScratchWrData_o      = instScratchWrData_sync  ;  
  assign instScratchWrEn_o        = instScratchWrEn_sync   ;  
  assign dataScratchAddr_o        = dataScratchAddr_sync    ;
  assign dataScratchWrData_o      = dataScratchWrData_sync  ;
  assign dataScratchWrEn_o        = dataScratchWrEn_sync    ;  
  assign scratchPadEn_o           = scratchPadEn_sync       ;
`endif

`ifdef INST_CACHE
  // If override 0 -> Mode controlled by register, if 1 -> Mode is CACHE mode
  assign instCacheBypass_o    = instCacheBypass_sync & ~cacheModeOverride_sync2;
  assign icScratchModeEn_o    = icScratchModeEn_sync & ~cacheModeOverride_sync2;
  assign icScratchWrAddr_o    = icScratchWrAddr_sync; 
  assign icScratchWrEn_o      = icScratchWrEn_sync;  
  assign icScratchWrData_o    = icScratchWrData_sync;
`endif  

`ifdef DATA_CACHE
  assign dataCacheBypass_o    = dataCacheBypass_sync & ~cacheModeOverride_sync2;
  assign dcScratchModeEn_o    = dcScratchModeEn_sync & ~cacheModeOverride_sync2;
  assign dcScratchWrAddr_o    = dcScratchWrAddr_sync; 
  assign dcScratchWrEn_o      = dcScratchWrEn_sync;  
  assign dcScratchWrData_o    = dcScratchWrData_sync;
`endif  

  assign debugPRFAddr_o       = debugPRFAddr_sync  ; 
  assign debugPRFWrData_o     = debugPRFWrData_sync;
  assign debugPRFWrEn_o       = debugPRFWrEn_sync  ;

  assign debugAMTAddr_o       = debugAMTAddr_sync  ; 

`ifdef PERF_MON
  assign perfMonRegAddr_o     = perfMonRegAddr_sync     ;
  assign perfMonRegGlobalClr_o= perfMonRegGlobalClr_sync;
  assign perfMonRegClr_o      = perfMonRegClr_sync      ;
  assign perfMonRegRun_o      = perfMonRegRun_sync      ;
`endif

  assign reset_sync_o         = reset_sync2;
  assign resetFetch_sync_o    = resetFetch_sync2;


/* Address mapped registers */
// Register Write operation
always_ff @(posedge ioClk or posedge reset)
begin
  if(reset)
  begin

`ifdef DYNAMIC_CONFIG
    fetchLaneActive       <=  6'b000011; 
    dispatchLaneActive    <=  6'b000011;
    issueLaneActive       <=  6'b000111; // First 3 lanes must be active
    execLaneActive        <=  6'b000111;
    saluLaneActive        <=  6'b000111;
    caluLaneActive        <=  6'b000111;
    commitLaneActive      <=  4'b0011;
    rfPartitionActive     <=  8'b11111111;
    alPartitionActive     <=  8'b11111111;
    lsqPartitionActive    <=  2'b11;
    iqPartitionActive     <=  4'b1111;
    ibuffPartitionActive  <=  4'b1111;
`endif      
`ifdef SCRATCH_PAD
    scratchPadEn          <=  2'b11;      // Enabled by default 
    instScratchAddr       <=  0; 
    instScratchWrData     <=  0; 
    instScratchWrEn       <=  0;
    dataScratchAddr       <=  0;
    dataScratchWrData     <=  0;
    dataScratchWrEn       <=  0;
`endif

    icScratchModeEn       <=  1'b1;   // Initialize in Scratch Mode
    dcScratchModeEn       <=  1'b1;   // Initialize in scratch Mode
    instCacheBypass       <=  1'b0;
    dataCacheBypass       <=  1'b0;

`ifdef PERF_MON
    perfMonRegAddr        <=  0;  
    perfMonRegRun         <=  0;  
    perfMonRegClr         <=  0;  
    perfMonRegGlobalClr   <=  0;  
`endif     
 
    scratchRegister       <=  6'b010101;

`ifdef SCRATCH_PAD
    instScratchWrEn       <=  1'b0;
    dataScratchWrEn       <=  1'b0;
`endif    

    debugPRFAddr          <=  {(`SIZE_PHYSICAL_LOG+`SIZE_DATA_BYTE_OFFSET){1'b0}};
    debugPRFWrEn          <=  1'b0;

    debugAMTAddr          <=  {`SIZE_RMT_LOG{1'b0}};

`ifdef INST_CACHE      
    icScratchWrEn         <=  1'b0;  
`endif      

`ifdef DATA_CACHE
    dcScratchWrEn         <=  1'b0;  
`endif      
  end

  // When write enable is high
  else if(regWrEn_i)
  begin
`ifdef SCRATCH_PAD
    instScratchWrEn       <=  1'b0;
    dataScratchWrEn       <=  1'b0;
`endif    
    debugPRFWrEn          <=  1'b0;

`ifdef INST_CACHE      
    icScratchWrEn         <=  1'b0;  
`endif      

`ifdef DATA_CACHE
    dcScratchWrEn         <=  1'b0;  
`endif      

    case(regAddr_i)
`ifdef DYNAMIC_CONFIG
      6'h01:fetchLaneActive       <=  regWrData_i[5:0]; 
      6'h02:dispatchLaneActive    <=  regWrData_i[5:0];
      6'h03:issueLaneActive       <=  regWrData_i[5:0];
      6'h04:execLaneActive        <=  regWrData_i[5:0];
      6'h05:saluLaneActive        <=  regWrData_i[5:0];
      6'h06:caluLaneActive        <=  regWrData_i[5:0];
      6'h07:commitLaneActive      <=  regWrData_i[3:0];
      6'h08:rfPartitionActive     <=  regWrData_i[7:0];
      6'h09:alPartitionActive     <=  regWrData_i[7:0];
      6'h0A:lsqPartitionActive    <=  regWrData_i[3:0];
      6'h0B:iqPartitionActive     <=  regWrData_i[3:0];
      6'h0C:ibuffPartitionActive  <=  regWrData_i[3:0]; 
`endif //DYNAMIC_CONFIG

      6'h0D:scratchRegister       <=  regWrData_i;

`ifdef SCRATCH_PAD
      6'h0E:scratchPadEn          <=  regWrData_i[1:0]; 
      6'h10:instScratchAddr[7:0]  <=  regWrData_i;
      6'h11:instScratchAddr[`DEBUG_INST_RAM_LOG+`DEBUG_INST_RAM_WIDTH_LOG-1:8]       <=  regWrData_i[`DEBUG_INST_RAM_LOG+`DEBUG_INST_RAM_WIDTH_LOG-9:0];
      6'h12:begin
            instScratchWrData     <=  regWrData_i;
            instScratchWrEn       <=  1'b1;
            end
      6'h13:dataScratchAddr[7:0]  <=  regWrData_i;
      6'h14:dataScratchAddr[`DEBUG_DATA_RAM_LOG+`DEBUG_DATA_RAM_WIDTH_LOG-1:8]       <=  regWrData_i[`DEBUG_DATA_RAM_LOG+`DEBUG_DATA_RAM_WIDTH_LOG-9:0];
      6'h15:begin
            dataScratchWrData     <=  regWrData_i;
            dataScratchWrEn       <=  1'b1;
            end
`endif
      6'h16:debugPRFAddr[7:0]     <= regWrData_i;
      6'h17:debugPRFAddr[`SIZE_PHYSICAL_LOG+`SIZE_DATA_BYTE_OFFSET-1:8]              <= regWrData_i[`SIZE_PHYSICAL_LOG+`SIZE_DATA_BYTE_OFFSET-9:0];
      6'h18:begin
	          debugPRFWrData        <= regWrData_i;
            debugPRFWrEn          <= 1'b1;
            end

`ifdef PERF_MON
      6'h19:perfMonRegAddr        <=  regWrData_i;  
      6'h1A:{perfMonRegGlobalClr, perfMonRegClr, perfMonRegRun} <= regWrData_i[2:0];
`endif      

      6'h1F:{instCacheBypass,dataCacheBypass,icScratchModeEn,dcScratchModeEn}       <=  regWrData_i[3:0];

`ifdef INST_CACHE      
      6'h30:icScratchWrAddr[7:0]  <=  regWrData_i; 
      6'h31:icScratchWrAddr[`ICACHE_INDEX_BITS+`ICACHE_BYTES_IN_LINE_LOG-1:8]       <=  regWrData_i[`ICACHE_INDEX_BITS+`ICACHE_BYTES_IN_LINE_LOG-9:0]; 
      6'h32:begin
            icScratchWrData       <=  regWrData_i;
            icScratchWrEn         <=  1'b1;  
          end
`endif          

`ifdef DATA_CACHE      
      6'h34:dcScratchWrAddr[7:0]  <=  regWrData_i; 
      6'h35:dcScratchWrAddr[`DCACHE_INDEX_BITS+`DCACHE_BYTES_IN_LINE_LOG-1:8]       <=  regWrData_i[`DCACHE_INDEX_BITS+`DCACHE_BYTES_IN_LINE_LOG-9:0]; 
      6'h36:begin
            dcScratchWrData       <=  regWrData_i;
            dcScratchWrEn         <=  1'b1;  
          end
`endif          

      6'h38:debugAMTAddr          <= regWrData_i;

      default:begin
            // If write to undefined address write the scratch registers
            scratchRegister       <=  regWrData_i;
`ifdef SCRATCH_PAD
            instScratchWrEn       <=  1'b0;
            dataScratchWrEn       <=  1'b0;
`endif            
            debugPRFWrEn          <=  1'b0;
`ifdef PERF_MON
            perfMonRegClr         <=  1'b0;  
            perfMonRegGlobalClr   <=  1'b0;  
`endif      
`ifdef INST_CACHE      
            icScratchWrEn         <=  1'b0;  
`endif      
`ifdef DATA_CACHE
            dcScratchWrEn         <=  1'b0;  
`endif      
      end
    endcase
  end

  // When not in reset and write enable not high
  else
  begin
`ifdef SCRATCH_PAD
    instScratchWrEn       <=  1'b0;
    dataScratchWrEn       <=  1'b0;
`endif    
    debugPRFWrEn          <=  1'b0;
`ifdef PERF_MON
    perfMonRegClr         <=  1'b0;  
    perfMonRegGlobalClr   <=  1'b0;  
`endif      
`ifdef INST_CACHE      
    icScratchWrEn         <=  1'b0;  
`endif      
`ifdef DATA_CACHE
    dcScratchWrEn         <=  1'b0;  
`endif      
  end
end

// Register Read operation
always_ff @(posedge ioClk or posedge reset)
begin
`ifdef DYNAMIC_CONFIG
  if(reset)
    clearDrainedStatus      <=  1'b0;
  else
  begin
    clearDrainedStatus      <=  1'b0;
`endif
    case(regAddr_i)
      6'h00:  regRdData_o   <=  `CHIP_ID;
  `ifdef DYNAMIC_CONFIG
      6'h01:  regRdData_o   <=  {2'b00,fetchLaneActive}      ; 
      6'h02:  regRdData_o   <=  {2'b00,dispatchLaneActive}   ;
      6'h03:  regRdData_o   <=  {2'b00,issueLaneActive}      ;
      6'h04:  regRdData_o   <=  {2'b00,execLaneActive}       ;
      6'h05:  regRdData_o   <=  {2'b00,saluLaneActive}       ;
      6'h06:  regRdData_o   <=  {2'b00,caluLaneActive}       ;
      6'h07:  regRdData_o   <=  {4'b00,commitLaneActive};
      6'h08:  regRdData_o   <=  rfPartitionActive;
      6'h09:  regRdData_o   <=  alPartitionActive;
      6'h0A:  regRdData_o   <=  {6'b000,lsqPartitionActive   };
      6'h0B:  regRdData_o   <=  {4'b000,iqPartitionActive    };
      6'h0C:begin
              regRdData_o   <=  {2'b00,pipeDrained_latch,reconfigDone_latch,ibuffPartitionActive };
              clearDrainedStatus  <=  1'b1;
      end
  `endif
      6'h0D:  regRdData_o   <=  scratchRegister; 
  `ifdef SCRATCH_PAD
      6'h0E:  regRdData_o   <=  {4'b00,scratchPadEn }; 
      6'h10:  regRdData_o   <=  instScratchAddr;
      6'h11:  regRdData_o   <=  instScratchRdData_ioClk;
      6'h12:  regRdData_o   <=  instScratchWrData;
      6'h13:  regRdData_o   <=  dataScratchAddr;
      6'h14:  regRdData_o   <=  dataScratchRdData_ioClk;
      6'h15:  regRdData_o   <=  dataScratchWrData;
  `endif
  
      6'h16:  regRdData_o   <=  debugPRFAddr;
      6'h17:  regRdData_o   <=  debugPRFRdData_ioClk;
      6'h18:  regRdData_o   <=  debugPRFWrData;
  
  `ifdef PERF_MON
      6'h19:  regRdData_o   <=  perfMonRegAddr;  
      6'h1A:  regRdData_o   <=  {5'b0,perfMonRegGlobalClr, perfMonRegClr, perfMonRegRun};
      6'h1B:  regRdData_o   <=  perfMonRegData_ioClk[7:0];  
      6'h1C:  regRdData_o   <=  perfMonRegData_ioClk[15:8];  
      6'h1D:  regRdData_o   <=  perfMonRegData_ioClk[23:16];  
      6'h1E:  regRdData_o   <=  perfMonRegData_ioClk[31:24];  
  `endif      
      6'h1F:  regRdData_o   <=  {4'b0,instCacheBypass,dataCacheBypass,icScratchModeEn,dcScratchModeEn};
  
      6'h2A:  regRdData_o   <=  currentInstPC_ioClk[7:0];
      6'h2B:  regRdData_o   <=  currentInstPC_ioClk[15:8];
      6'h2C:  regRdData_o   <=  currentInstPC_ioClk[23:16];
      6'h2D:  regRdData_o   <=  currentInstPC_ioClk[31:24];
  
  `ifdef INST_CACHE
      6'h30:  regRdData_o   <=  icScratchWrAddr[7:0];
      6'h31:  regRdData_o   <=  icScratchWrAddr[`ICACHE_INDEX_BITS+`ICACHE_BYTES_IN_LINE_LOG-1:8];
      6'h32:  regRdData_o   <=  icScratchWrData;
      6'h33:  regRdData_o   <=  icScratchRdData_ioClk;
  `endif
  
  `ifdef DATA_CACHE
      6'h34:  regRdData_o   <=  dcScratchWrAddr[7:0];
      6'h35:  regRdData_o   <=  dcScratchWrAddr[`DCACHE_INDEX_BITS+`DCACHE_BYTES_IN_LINE_LOG-1:8];
      6'h36:  regRdData_o   <=  dcScratchWrData;
      6'h37:  regRdData_o   <=  dcScratchRdData_ioClk;
  `endif
  
      6'h38:  regRdData_o   <=  debugAMTAddr;
      6'h39:  regRdData_o   <=  {{(8-`SIZE_PHYSICAL_LOG){1'b0}},debugAMTRdData_ioClk};
  
      default:begin
              regRdData_o   <=  scratchRegister; 
            `ifdef DYNAMIC_CONFIG
              clearDrainedStatus  <=  1'b0;
            `endif
      end
    endcase
`ifdef DYNAMIC_CONFIG
  end
`endif
end


`ifdef DYNAMIC_CONFIG
  always_ff @(posedge ioClk or posedge reset)
  begin
    if(reset)
    begin
      pipeDrained_latch   <=  1'b0;
      reconfigDone_latch  <=  1'b0;
    end
    else
    begin
      if(clearDrainedStatus)
      begin
        pipeDrained_latch   <=  1'b0;
        reconfigDone_latch  <=  1'b0;
      end
      else
      begin
        if(pipeDrained_i)
          pipeDrained_latch   <=  1'b1;
        if(reconfigDone_i)
          reconfigDone_latch  <=  1'b1;
      end
    end
  end
`endif

/* Synchronize the config signals to coreClk */
always_ff @(posedge coreClk)
begin
`ifdef DYNAMIC_CONFIG
  // Dual syncing direct inputs
  stallFetch_sync1           <= stallFetch_i         ;
  stallFetch_sync2           <= stallFetch_sync1     ;
  reconfigureCore_sync1      <= reconfigureCore_i    ;
  reconfigureCore_sync2      <= reconfigureCore_sync1;

  // Single syncing register outputs
  fetchLaneActive_sync       <= fetchLaneActive      ; 
  dispatchLaneActive_sync    <= dispatchLaneActive   ; 
  issueLaneActive_sync       <= issueLaneActive      ; 
  execLaneActive_sync        <= execLaneActive       ; 
  saluLaneActive_sync        <= saluLaneActive       ; 
  caluLaneActive_sync        <= caluLaneActive       ; 
  commitLaneActive_sync      <= commitLaneActive     ; 
  rfPartitionActive_sync     <= rfPartitionActive    ; 
  alPartitionActive_sync     <= alPartitionActive    ; 
  lsqPartitionActive_sync    <= lsqPartitionActive   ; 
  iqPartitionActive_sync     <= iqPartitionActive    ; 
  ibuffPartitionActive_sync  <= ibuffPartitionActive ;
`endif

`ifdef SCRATCH_PAD
  scratchPadEn_sync          <= scratchPadEn;
  instScratchAddr_sync       <= instScratchAddr      ;
  instScratchWrData_sync     <= instScratchWrData    ;
  instScratchWrEn_sync       <= instScratchWrEn      ; 
  dataScratchAddr_sync       <= dataScratchAddr      ;
  dataScratchWrData_sync     <= dataScratchWrData    ;
  dataScratchWrEn_sync       <= dataScratchWrEn      ; 
`endif

`ifdef INST_CACHE
  icScratchModeEn_sync       <= icScratchModeEn      ;
  instCacheBypass_sync       <= instCacheBypass      ;
  icScratchWrAddr_sync       <= icScratchWrAddr      ; 
  icScratchWrEn_sync         <= icScratchWrEn        ;  
  icScratchWrData_sync       <= icScratchWrData      ;
`endif

`ifdef DATA_CACHE
  dcScratchModeEn_sync       <= dcScratchModeEn      ;
  dataCacheBypass_sync       <= dataCacheBypass      ;
  dcScratchWrAddr_sync       <= dcScratchWrAddr      ; 
  dcScratchWrEn_sync         <= dcScratchWrEn        ;  
  dcScratchWrData_sync       <= dcScratchWrData      ;
`endif

  debugPRFAddr_sync          <= debugPRFAddr         ;
  debugPRFWrData_sync        <= debugPRFWrData       ;
  debugPRFWrEn_sync          <= debugPRFWrEn         ;

  debugAMTAddr_sync          <= debugAMTAddr         ;

`ifdef PERF_MON
  perfMonRegAddr_sync        <= perfMonRegAddr       ;
  perfMonRegRun_sync         <= perfMonRegRun        ;
  perfMonRegClr_sync         <= perfMonRegClr        ;
  perfMonRegGlobalClr_sync   <= perfMonRegGlobalClr  ;
`endif

end

/* Synchronize the debug signals to ioClk */

always_ff @(posedge ioClk)
begin
  currentInstPC_ioClk     <= currentInstPC_i;

`ifdef SCRATCH_PAD  
  instScratchRdData_ioClk <= instScratchRdData_i;
  dataScratchRdData_ioClk <= dataScratchRdData_i;
`endif  

  debugPRFRdData_ioClk    <= debugPRFRdData_i;

  debugAMTRdData_ioClk    <= debugAMTRdData_i;

`ifdef INST_CACHE
  icScratchRdData_ioClk   <= icScratchRdData_i;
`endif  

`ifdef DATA_CACHE
  dcScratchRdData_ioClk   <= dcScratchRdData_i;
`endif

`ifdef PERF_MON
  perfMonRegData_ioClk    <= perfMonRegData_i;
`endif

end


/* Synchronize the reset to coreClk */
always_ff @(posedge coreClk)
begin
  reset_sync1                <= reset;
  reset_sync2                <= reset_sync1;

  resetFetch_sync1           <= resetFetch_i;
  resetFetch_sync2           <= resetFetch_sync1;

  cacheModeOverride_sync1    <= cacheModeOverride_i;
  cacheModeOverride_sync2    <= cacheModeOverride_sync1;
end


endmodule
