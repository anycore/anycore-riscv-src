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


`timescale 1ns/1ps

//`define PRINT_EN

//`define DUMP_STATS

module simulate();

//* Stop Simulation when COMMIT_COUNT >= SIM_STOP_COUNT
`ifdef SCRATCH_EN
  parameter SIM_STOP_COUNT      = 100;
`else
  `ifdef POWER_SIM
    parameter SIM_STOP_COUNT      = 10_000;
  `else
    parameter SIM_STOP_COUNT      = 100_000;
  `endif
`endif

//* Print when (COMMIT_COUNT >= COMMIT_PRINT_COUNT) && (CYCLE_COUNT >= CYCLE_PRINT_COUNT)
parameter COMMIT_PRINT_COUNT  = 0;
parameter CYCLE_PRINT_COUNT   = 0;

`ifdef POWER_SIM
  parameter STAT_PRINT_COUNT    = 100;
`else
  parameter STAT_PRINT_COUNT    = 10_000;
`endif

parameter CLKPERIOD           =  `CLKPERIOD; // Defined in config file (ex. StaticConfig1.sv)
//parameter CLKPERIOD           =  3.84; // For slowed down versions of fixed configurations
`ifdef SCRATCH_EN
  parameter INST_SCRATCH_ENABLED = 1;
  parameter DATA_SCRATCH_ENABLED = 1;
`else
  parameter INST_SCRATCH_ENABLED = 0;
  parameter DATA_SCRATCH_ENABLED = 0;
`endif

`ifdef INST_CACHE
  parameter INST_CACHE_BYPASS = 0;
`else
  parameter INST_CACHE_BYPASS = 1;
`endif

`ifdef DATA_CACHE
  parameter DATA_CACHE_BYPASS = 0;
`else
  parameter DATA_CACHE_BYPASS = 1;
`endif


reg clk;
reg reset;

`ifdef PERF_MON
  reg [`REG_DATA_WIDTH-1:0] perfMonRegAddr; 
  reg [31:0]                perfMonRegData; 
  reg                       perfMonRegRun ;
  reg                       perfMonRegClr ;
  reg                       perfMonRegGlobalClr ;
`endif

`ifdef DYNAMIC_CONFIG
reg [3:0] configID;
reg [15:0] randomWait;
`endif

//reg beginConsolidation_reg;
//reg clearPerfMon; // this will trigger the performance counters

initial
begin
  $shm_open("waves.shm");
  $shm_probe(simulate, "ACM");
  //$dumpfile("waves.vcd");
  //$dumpvars(0,coreTop);
  //$dumplimit(600000000);
end


// Following defines the clk for the simulation.
always #(CLKPERIOD/2.0) 
begin
  clk = ~clk;
end


reg  [`SIZE_DATA-1:0]              LOGICAL_REG [`SIZE_RMT-1:0];
reg  [`SIZE_DATA-1:0]              PHYSICAL_REG [`SIZE_PHYSICAL_TABLE-1:0];
reg  [`SIZE_PC-1:0]                startPC;
reg                                resetFetch;
reg                                verifyCommits;
reg                                cacheModeOverride; //If 1 -> Forces caches to operate in CACHE mode

`ifdef DYNAMIC_CONFIG
  // Power management signals
  reg                                stallFetch;
  reg  [`FETCH_WIDTH-1:0]            fetchLaneActive;
  reg  [`DISPATCH_WIDTH-1:0]         dispatchLaneActive;
  reg  [`ISSUE_WIDTH-1:0]            issueLaneActive;
  reg  [`EXEC_WIDTH-1:0]             execLaneActive;
  reg  [`EXEC_WIDTH-1:0]             saluLaneActive;
  reg  [`EXEC_WIDTH-1:0]             caluLaneActive;
  reg  [`COMMIT_WIDTH-1:0]           commitLaneActive;
  reg  [`NUM_PARTS_RF-1:0]           rfPartitionActive;
  reg  [`NUM_PARTS_RF-1:0]           alPartitionActive;
  reg  [`STRUCT_PARTS_LSQ-1:0]       lsqPartitionActive;
  reg  [`STRUCT_PARTS-1:0]           iqPartitionActive;
  reg  [`STRUCT_PARTS-1:0]           ibuffPartitionActive;
  reg                                reconfigureCore;
`endif

`ifdef SCRATCH_PAD
  reg [`DEBUG_INST_RAM_LOG+`DEBUG_INST_RAM_WIDTH_LOG-1:0]  instScratchAddr;
  reg [7:0]                       instScratchWrData;  
  reg                             instScratchWrEn; 
  reg [`DEBUG_DATA_RAM_LOG+`DEBUG_DATA_RAM_WIDTH_LOG-1:0] dataScratchAddr;
  reg [7:0]                       dataScratchWrData;  
  reg                             dataScratchWrEn;  
  reg [7:0]                       instScratchRdData;  
  reg [7:0]                       dataScratchRdData;  
  reg                             instScratchPadEn = INST_SCRATCH_ENABLED;
  reg                             dataScratchPadEn = DATA_SCRATCH_ENABLED;
`endif

  logic                           instCacheBypass = INST_CACHE_BYPASS;
  logic                           icScratchModeEn;
`ifdef INST_CACHE
  logic [`ICACHE_BLOCK_ADDR_BITS-1:0]ic2memReqAddr;     // memory read address
  logic                           ic2memReqValid;     // memory read enable
  logic [`ICACHE_TAG_BITS-1:0]    mem2icTag;          // tag of the incoming data
  logic [`ICACHE_INDEX_BITS-1:0]  mem2icIndex;        // index of the incoming data
  logic [`ICACHE_BITS_IN_LINE-1:0]   mem2icData;         // requested data
  logic                           mem2icRespValid;    // requested data is ready
`endif  

  logic                              dataCacheBypass = DATA_CACHE_BYPASS;
  logic                              dcScratchModeEn;
`ifdef DATA_CACHE
  logic [`DCACHE_BLOCK_ADDR_BITS-1:0]  dc2memLdAddr;  // memory read address
  logic                              dc2memLdValid; // memory read enable
  logic [`DCACHE_TAG_BITS-1:0]       mem2dcLdTag;       // tag of the incoming datadetermine
  logic [`DCACHE_INDEX_BITS-1:0]     mem2dcLdIndex;     // index of the incoming data
  logic [`DCACHE_BITS_IN_LINE-1:0]      mem2dcLdData;      // requested data
  logic                              mem2dcLdValid;     // indicates the requested data is ready
  logic [`DCACHE_ST_ADDR_BITS-1:0]   dc2memStAddr;  // memory read address
  logic [`SIZE_DATA-1:0]             dc2memStData;  // memory read address
  logic [3:0]                        dc2memStByteEn;  // memory read address
  logic                              dc2memStValid; // memory read enable
  logic                              mem2dcStComplete;
`endif

initial 
begin:INIT_TB
  int i;

  reset                = 1'b0;
  resetFetch           = 1'b0;
  verifyCommits        = 1'b0;
`ifdef DYNAMIC_CONFIG
  stallFetch           = 1'b0;
  reconfigureCore      = 1'b0;
`endif

`define USE_SDF
  `ifdef USE_SDF
//    `ifdef PNR_SIM
//        $sdf_annotate("../../PNR/out/pr_top_routed.sdf",coreTop);
//    `else
        $sdf_annotate({"./Core_OOO.sdf"},coreTop);
//    `endif
  `endif

  if(!INST_SCRATCH_ENABLED)
  begin
    $initialize_sim();
    $copyMemory();
  end

  $display("");
  $display("");
  $display("**********   ******   ********     *******    ********   ******   ****         ******   ********  ");
  $display("*        *  *      *  *       *   *      *   *       *  *      *  *  *        *      *  *       * ");
  $display("*  ******* *   **   * *  ***   * *   *****  *   ****** *   **   * *  *       *   **   * *  ***   *");
  $display("*  *       *  *  *  * *  *  *  * *  *       *  *       *  *  *  * *  *       *  *  *  * *  *  *  *");
  $display("*  *****   *  ****  * *  ***   * *   ****   *  *       *  ****  * *  *       *  ****  * *  ***   *");
  $display("*      *   *        * *       *   *      *  *  *       *        * *  *       *        * *       * ");
  $display("*  *****   *  ****  * *  ***   *   ****   * *  *       *  ****  * *  *       *  ****  * *  ***   *");
  $display("*  *       *  *  *  * *  *  *  *       *  * *  *       *  *  *  * *  *       *  *  *  * *  *  *  *");
  $display("*  *       *  *  *  * *  ***   *  *****   * *   ****** *  *  *  * *  ******* *  *  *  * *  *  *  *");
  $display("*  *       *  *  *  * *       *   *      *   *       * *  *  *  * *        * *  *  *  * *  *  *  *");
  $display("****       ****  **** ********    *******     ******** ****  **** ********** ****  **** ****  ****");
  $display("");
  $display("AnyCore Copyright (c) 2007-2012 by Niket K. Choudhary, Brandon H. Dwiel, and Eric Rotenberg.");
  $display("All Rights Reserved.");
  $display("");
  $display("");

  if(!INST_SCRATCH_ENABLED)
  begin
    for (i = 0; i < `SIZE_RMT-2; i = i + 1)
    begin
      LOGICAL_REG[i]               = $getArchRegValue(i);
    end

    LOGICAL_REG[32]                = $getArchRegValue(65);
    LOGICAL_REG[33]                = $getArchRegValue(64);

    init_registers();
    $funcsimRunahead();
  end

  clk                            = 0;

  `ifdef INST_CACHE
    // Initialize the caches to SCRATCH mode
    // NOTE: This is not required in AnyCore_Chip mode as 
    // they initialize to SCRATCH mode by default
    icScratchModeEn       = 1'b1;
  `endif
  `ifdef DATA_CACHE
    dcScratchModeEn       = 1'b1;
  `endif  

  // Assert reset
  #(15*CLKPERIOD) 
  reset                 = 1;
  
  `ifdef PERF_MON
    perfMonRegAddr      = 8'h00;
    perfMonRegClr       = 1'b0;
    perfMonRegRun       = 1'b0;
    perfMonRegGlobalClr = 1'b0;
  `endif

  // Release reset asynchronously to make sure it works
  #(10*CLKPERIOD-4) 
  $dumpon;
  reset                 = 0;
  #4;

  `ifdef INST_CACHE
  
    // Let the core run in BIST mode for a while before reconfiguring and loading benchmarks/microkernel
    #(1000*CLKPERIOD)
  
    stallFetch            = 1'b1;
    #(500*CLKPERIOD)  //Enough time to drain pipeline
    //Reset fetch to start fetching from PC 0x0000 (to load checkpoint and benchmark)
    resetFetch            = 1'b1;
    #(200*CLKPERIOD)  //Enough time to drain pipeline

  `else // If in perfect cache mode

    resetFetch            = 1'b0;
    verifyCommits         = 1'b1;
  `ifdef DYNAMIC_CONFIG
    stallFetch            = 1'b0;
    reconfigureCore       = 1'b0;
  `endif

  `endif

  // If in microbenchmark mode, load the kernel and data into scratch pads (or caches)
  if(INST_SCRATCH_ENABLED)
  begin
    // Stall the fetch before loading microbenchmark
  `ifdef DYNAMIC_CONFIG
    #CLKPERIOD
    stallFetch           = 1'b1;  
    #(2*CLKPERIOD)
  `endif

    //$readmemh("kernel.dat",coreTop.fs1.l1icache.ic.ram);
    //$readmemh("data.dat",coreTop.lsu.datapath.ldx_path.L1dCache.dc.ram); 
    //for (i = 0; i < 256; i = i + 1)
    //begin
    //    $display("@%d: %08x", i, coreTop.lsu.datapath.ldx_path.L1dCache.dc.ram[i]);
    //end
    `ifdef SCRATCH_PAD
		  load_kernel_scratch();
		  instScratchWrEn   = 0;   
		  read_kernel_scratch();
		  
		  load_data_scratch();
		  dataScratchWrEn   = 0;   
		  read_data_scratch();
    `endif

    //Unstall the fetch once loading is complete loading microbenchmark
    #(2*CLKPERIOD)
  `ifdef DYNAMIC_CONFIG
    stallFetch           = 1'b0;  
  `endif
    resetFetch           = 1'b0;
    //TODO: Wait for pipeline to be empty
    verifyCommits        = 1'b1;
  end
  // If not in microbenchmark mode, change the cache mode else let it run un SCRATCH mode
  else 
  begin
    `ifdef INST_CACHE

      icScratchModeEn      = 1'b0;
      dcScratchModeEn      = 1'b0;
      #(2*CLKPERIOD)
      //TODO: Wait for pipeline to be empty
      verifyCommits        = 1'b1;
      stallFetch           = 1'b0;
      resetFetch           = 1'b0;
      #(2*CLKPERIOD)
      // If not in microbenchmark mode, let the core run in CACHE mode for a while with actual 
      // benchmark before reconfiguring
      #(1000*CLKPERIOD)
      //Change mode of the caches
      dcScratchModeEn      = 1'b0; // Dummy statement to avoid error. Doesn't really do anything

    `endif
  end


//load_checkpoint_PRF();
//read_checkpoint_PRF();
  
`ifdef DYNAMIC_CONFIG


  // Stall the fetch before reconfiguring
  // TODO: Test that it works without this as well
  #CLKPERIOD
  stallFetch           = 1'b1;  
  #(10*CLKPERIOD)

  fetchLaneActive  =       `FETCH_LANE_ACTIVE     ; 
  dispatchLaneActive  =    `DISPATCH_LANE_ACTIVE  ; 
  issueLaneActive  =       `ISSUE_LANE_ACTIVE     ; 
  execLaneActive  =        `EXEC_LANE_ACTIVE      ; 
  saluLaneActive  =        `SALU_LANE_ACTIVE      ;
  caluLaneActive  =        `CALU_LANE_ACTIVE      ;
  commitLaneActive  =      `COMMIT_LANE_ACTIVE    ; 
  rfPartitionActive  =     `RF_PARTITION_ACTIVE   ; 
  alPartitionActive  =     `AL_PARTITION_ACTIVE   ; 
  lsqPartitionActive  =    `LSQ_PARTITION_ACTIVE  ; 
  iqPartitionActive  =     `IQ_PARTITION_ACTIVE   ; 
  ibuffPartitionActive  =  `IBUFF_PARTITION_ACTIVE;

  reconfigureCore           = 1'b1;



  #(3*CLKPERIOD)
  reconfigureCore      = 1'b0;
  #CLKPERIOD
  stallFetch           = 1'b0;


  while(1)
  begin
    for (configID = 1 ; configID <= 6 ; configID++)
    begin
      //#(10000*CLKPERIOD);
      randomWait = configID*($random()%100)+1000;
      #(randomWait*CLKPERIOD);
      reconfigure(configID);
      $display("*           Reconfiguring at =  %d              *\n",randomWait);
    end
    for (configID = 6 ; configID >= 1 ; configID--)
    begin
      //#(10000*CLKPERIOD);
      randomWait = configID*($random()%100)+1000;
      #(randomWait*CLKPERIOD);
      reconfigure(configID);
      $display("*           Reconfiguring at =  %d              *\n",randomWait);
    end
  end


`endif 

`ifdef PERF_MON
  read_perf_mon();
`endif  

end


reg  [`SIZE_PC-1:0]                instPC [0:`FETCH_WIDTH-1];
reg  [`SIZE_INSTRUCTION-1:0]       inst   [0:`FETCH_WIDTH-1];

wire [`SIZE_PC-1:0]                ldAddr;
wire [`SIZE_DATA-1:0]              ldData;
wire                               ldEn;

wire [`SIZE_PC-1:0]                stAddr;
wire [`SIZE_DATA-1:0]              stData;
wire [3:0]                         stEn;

reg [`SIZE_DATA_BYTE_OFFSET+`SIZE_PHYSICAL_LOG-1:0] debugPRFAddr  ;
reg [`SRAM_DATA_WIDTH-1:0] 			   debugPRFWrData;             
reg 					                     debugPRFWrEn  = 1'b0;
reg [`SRAM_DATA_WIDTH-1:0] 			   debugPRFRdData;

reg [`SIZE_PC*`FETCH_WIDTH-1:0] instPC_o;
reg [`SIZE_INSTRUCTION*`FETCH_WIDTH-1:0] inst_i;

always @(*)
begin
  int i;
  for(i = 0; i < `FETCH_WIDTH; i++)
  begin
    instPC[i] = instPC_o[(`SIZE_PC*(`FETCH_WIDTH-i)-1) -: `SIZE_PC];
    inst_i[(`SIZE_INSTRUCTION*(`FETCH_WIDTH-i)-1) -: `SIZE_INSTRUCTION] = inst[i];
  end
end


Core_OOO coreTop(

    .clk                                 (clk),
    .reset                               (reset),
    .resetFetch_i                        (resetFetch), 
    .toggleFlag_o                        (toggleFlag),

`ifdef SCRATCH_PAD
    .instScratchAddr_i                  (instScratchAddr),
    .instScratchWrData_i                (instScratchWrData),
    .instScratchWrEn_i                  (instScratchWrEn),
    .instScratchRdData_o                (instScratchRdData),
    .dataScratchAddr_i                  (dataScratchAddr),
    .dataScratchWrData_i                (dataScratchWrData),
    .dataScratchWrEn_i                  (dataScratchWrEn),
    .dataScratchRdData_o                (dataScratchRdData),
    .instScratchPadEn_i                 (instScratchPadEn),
    .dataScratchPadEn_i                 (dataScratchPadEn),
`endif

`ifdef INST_CACHE
    .ic2memReqAddr_o                    (ic2memReqAddr     ),    // memory read address
    .ic2memReqValid_o                   (ic2memReqValid    ),    // memory read enable
    .mem2icTag_i                        (mem2icTag         ),    // tag of the incoming data
    .mem2icIndex_i                      (mem2icIndex       ),    // index of the incoming data
    .mem2icData_i                       (mem2icData        ),    // requested data
    .mem2icRespValid_i                  (mem2icRespValid   ),    // requested data is ready
    .instCacheBypass_i                  (instCacheBypass   ),
    .icScratchModeEn_i                  (icScratchModeEn   ),

    .icScratchWrAddr_i                   ($random%1024),
    .icScratchWrEn_i                     (1'b0),
    .icScratchWrData_i                   (8'bxxxx),
    .icScratchRdData_o                   (),
`endif  

`ifdef DATA_CACHE
    .dc2memLdAddr_o                     (dc2memLdAddr     ), // memory read address
    .dc2memLdValid_o                    (dc2memLdValid    ), // memory read enable
                                                           
    .mem2dcLdTag_i                      (mem2dcLdTag      ), // tag of the incoming datadetermine
    .mem2dcLdIndex_i                    (mem2dcLdIndex    ), // index of the incoming data
    .mem2dcLdData_i                     (mem2dcLdData     ), // requested data
    .mem2dcLdValid_i                    (mem2dcLdValid    ), // indicates the requested data is ready
                                                           
    .dc2memStAddr_o                     (dc2memStAddr     ), // memory read address
    .dc2memStData_o                     (dc2memStData     ), // memory read address
    .dc2memStByteEn_o                   (dc2memStByteEn   ), // memory read address
    .dc2memStValid_o                    (dc2memStValid    ), // memory read enable
                                                           
    .mem2dcStComplete_i                 (mem2dcStComplete ),
    .mem2dcStStall_i                    (1'b0),
    .dataCacheBypass_i                  (dataCacheBypass  ),
    .dcScratchModeEn_i                  (dcScratchModeEn  ),

    .dcScratchWrAddr_i                   ($random%1024),
    .dcScratchWrEn_i                     (1'b0),
    .dcScratchWrData_i                   (8'bxxxx),
    .dcScratchRdData_o                   (),
`endif    

`ifdef DYNAMIC_CONFIG
    .stallFetch_i                        (stallFetch), 
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
    .reconfigureCore_i                   (reconfigureCore),
    .reconfigDone_o                      (reconfigDone),
`endif
`ifdef PERF_MON
    .perfMonRegAddr_i                    (perfMonRegAddr),
    .perfMonRegData_o                    (perfMonRegData),
    .perfMonRegRun_i                     (perfMonRegRun),
    .perfMonRegClr_i                     (perfMonRegClr),
    .perfMonRegGlobalClr_i               (perfMonRegGlobalClr),
`endif

    .startPC_i                           (startPC),

    .instPC_o                            (instPC_o),
    .fetchReq_o                          (instReq), //Useful in case of CHIP simulations
    .fetchRecoverFlag_o                  (), //Useful in case of CHIP simulations
    .inst_i                              (inst_i),
    .instValid_i                         (instCacheBypass ? 1'b1 : 1'bx), //Constant in case of unit simulation, not in case of CHIP simulation

    .ldAddr_o                            (ldAddr),
    .ldData_i                            (ldData),
    .ldDataValid_i                       (ldEn), //Loopback
    .ldEn_o                              (ldEn),

    .stAddr_o                            (stAddr),
    .stData_o                            (stData),
    .stEn_o                              (stEn),

    .debugPRFAddr_i                      (debugPRFAddr),
    .debugPRFWrData_i                    (debugPRFWrData),             
    .debugPRFWrEn_i                      (debugPRFWrEn),
    .debugPRFRdData_o                    (debugPRFRdData),

    .debugAMTAddr_i                      ('b0),

    /* Initialize the PRF from top */
    .dbAddr_i                            ({`SIZE_PHYSICAL_LOG{1'b0}}),
    .dbData_i                            ({`SIZE_DATA{1'b0}}),
    .dbWe_i                              (1'b0)

 );

memory_hier mem (
    .icClk                               (clk),
    .dcClk                               (clk),
    .reset                               (reset),

    .icPC_i                              (instPC),
    .icInstReq_i                         (instReq & (INST_SCRATCH_ENABLED ? 1'b0 : 1'b1)), //Mask requests to prevent crash
    .icInst_o                            (inst),

  `ifdef INST_CACHE
    .ic2memReqAddr_i                     (ic2memReqAddr),
    .ic2memReqValid_i                    (ic2memReqValid),
    .mem2icTag_o                         (mem2icTag), 
    .mem2icIndex_o                       (mem2icIndex),     
    .mem2icData_o                        (mem2icData),      
    .mem2icRespValid_o                   (mem2icRespValid), 
  `endif

  `ifdef DATA_CACHE
    .dc2memLdAddr_i                      (dc2memLdAddr     ), // memory read address
    .dc2memLdValid_i                     (dc2memLdValid    ), // memory read enable
                                                            
    .mem2dcLdTag_o                       (mem2dcLdTag      ), // tag of the incoming datadetermine
    .mem2dcLdIndex_o                     (mem2dcLdIndex    ), // index of the incoming data
    .mem2dcLdData_o                      (mem2dcLdData     ), // requested data
    .mem2dcLdValid_o                     (mem2dcLdValid    ), // indicates the requested data is ready
                                                            
    .dc2memStAddr_i                      (dc2memStAddr     ), // memory read address
    .dc2memStData_i                      (dc2memStData     ), // memory read address
    .dc2memStByteEn_i                    (dc2memStByteEn   ), // memory read address
    .dc2memStValid_i                     (dc2memStValid    ), // memory read enable
                                                            
    .mem2dcStComplete_o                  (mem2dcStComplete ),
  `endif    
  
    .ldAddr_i                            (ldAddr),
    .ldData_o                            (ldData),
    .ldEn_i                              (ldEn & (DATA_SCRATCH_ENABLED ? 1'b0 : 1'b1)), //Mask En to prevent crash

    .stAddr_i                            (stAddr),
    .stData_i                            (stData),
    .stEn_i                              (stEn & {4{DATA_SCRATCH_ENABLED ? 1'b0 : 1'b1}}) //Mask En to prevent crash
);

integer CYCLE_COUNT;
integer COMMIT_COUNT;

/*
always @(posedge clk)
begin:HANDLE_EXCEPTION
  int i;
  reg [`SIZE_PC-1:0] TRAP_PC;

  // Following code handles the SYSCALL (trap).
  if (coreTop.activeList.n131 && (|coreTop.activeList.alCount))
  begin

    // Functional simulator is stalled waiting to execute the trap.
    // Signal it to proceed with the trap.
    //

    TRAP_PC = coreTop.activeList.commitPC[0];

    $display("TRAP (Cycle: %0d PC: %08x Code: %0d)\n",
             CYCLE_COUNT,
             TRAP_PC,
             $getArchRegValue(2));

    if ($getArchRegValue(2) == 1)
    begin
        $display("SS_SYS_exit encountered. Exiting the simulation");
        $finish;
    end

    $handleTrap();

    // The memory state of the timing simulator is now stale.
    // Copy values from the functional simulator.
    
    $copyMemory();

    // Registers of the timing simulator are now stale.
    // Copy values from the functional simulator.
    
    for (i = 0; i < `SIZE_RMT - 2; i++) 
    begin
      LOGICAL_REG[i]  = $getArchRegValue(i);
    end

    LOGICAL_REG[32]   = $getArchRegValue(65);
    LOGICAL_REG[33]   = $getArchRegValue(64);

    // Functional simulator is waiting to resume after the trap.
    // Signal it to resume.
    
    $resumeTrap();

    $getRetireInstPC(1,CYCLE_COUNT,TRAP_PC,0,0,0);
    init_registers;
  end

    // After the SYSCALL is handled by the functional simulator, architectural
    // values from functional simulator should be copied to the Register File.
  
  if (coreTop.activeList.exceptionFlag_reg) 
  begin
    $display("CYCLE:%d Exception is High\n", CYCLE_COUNT);
    // init_registers;
    // copyRF; 
    // copySimRF;
  end
end
*/

reg [3:0]                    totalCommit;
wire    PRINT;
assign  PRINT = (COMMIT_COUNT >= COMMIT_PRINT_COUNT) && (CYCLE_COUNT > CYCLE_PRINT_COUNT);

integer last_commit_cnt;
integer load_violation_count;
integer br_count;
integer br_mispredict_count;
integer ld_count;
integer btb_miss;
integer btb_miss_rtn;
integer fetch1_stall;
integer ctiq_stall;
integer instBuf_stall;
integer freelist_stall;
integer smt_stall;
integer backend_stall;
integer rob_stall;
integer iq_stall;
integer ldq_stall;
integer stq_stall;

// cti stats ////////////////////
`define     stat_num_corr           coreTop.exePipe1.execute.stat_num_corr
`define     stat_num_pred           coreTop.exePipe1.execute.stat_num_pred
`define     stat_num_cond_corr      coreTop.exePipe1.execute.stat_num_cond_corr
`define     stat_num_cond_pred      coreTop.exePipe1.execute.stat_num_cond_pred
`define     stat_num_return_corr    coreTop.exePipe1.execute.stat_num_return_corr
`define     stat_num_return_pred    coreTop.exePipe1.execute.stat_num_return_pred
/////////////////////////////////

int     ib_count;
int     fl_count;
int     iq_count;
int     ldq_count;
int     stq_count;
int     al_count;

int     commit_1;
int     commit_2;
int     commit_3;
int     commit_4;

real    ib_avg;
real    fl_avg;
real    iq_avg;
real    ldq_avg;
real    stq_avg;
real    al_avg;

real    ipc;

integer fd0;
integer fd1;
integer fd2;
integer fd3;
integer fd4;
integer fd5;
integer fd6;
integer fd7;
integer fd8;
integer fd9;
integer fd10;
integer fd11;
integer fd12;
integer fd13;
integer fd14;
integer fd16;
integer fd17;
integer fd18;
integer fd19;
integer fd20;
integer fd21;
integer fd22;
integer fd23;

initial
begin
    CYCLE_COUNT          = 0;
    COMMIT_COUNT         = 0;
    load_violation_count = 0;
    br_count             = 0;
    br_mispredict_count  = 0;
    ld_count             = 0;
    btb_miss             = 0;
    btb_miss_rtn         = 0;
    fetch1_stall         = 0;
    ctiq_stall           = 0;
    instBuf_stall        = 0;
    freelist_stall       = 0;
    smt_stall            = 0;
    backend_stall        = 0;
    rob_stall            = 0;
    iq_stall             = 0;
    ldq_stall            = 0;
    stq_stall            = 0;
    last_commit_cnt      = 0;

    ib_count             = 0;
    fl_count             = 0;
    iq_count             = 0;
    ldq_count            = 0;
    stq_count            = 0;
    al_count             = 0;

    commit_1             = 0;
    commit_2             = 0;
    commit_3             = 0;
    commit_4             = 0;

    fd9         = $fopen("results/fetch1.txt","w");
    fd14        = $fopen("results/fetch2.txt","w");
    fd2         = $fopen("results/decode.txt","w");
    fd1         = $fopen("results/instBuf.txt","w");
    fd0         = $fopen("results/rename.txt","w");
    fd3         = $fopen("results/dispatch.txt","w");
    fd4         = $fopen("results/select.txt","w");
    fd5         = $fopen("results/issueq.txt","w");
    fd6         = $fopen("results/regread.txt","w");
    fd23        = $fopen("results/PhyRegFile.txt","w");
    fd13        = $fopen("results/exe.txt","w");
    fd7         = $fopen("results/activeList.txt","w");
    fd10        = $fopen("results/lsu.txt","w");
    fd8         = $fopen("results/writebk.txt","w");

    fd16        = $fopen("results/statistics.txt","w");
    fd17        = $fopen("results/coretop.txt","w");

`ifdef DUMP_STATS
    $fwrite(fd16, "CYCLE, "); 
    $fwrite(fd16, "COMMIT, "); 

    $fwrite(fd16, "IB-avg, "); 
    $fwrite(fd16, "FL-avg, "); 
    $fwrite(fd16, "IQ-avg, "); 
    $fwrite(fd16, "LDQ-avg, "); 
    $fwrite(fd16, "STQ-avg, "); 
    $fwrite(fd16, "AL-avg, "); 

    $fwrite(fd16, "FS1-stall, ");
    $fwrite(fd16, "CTI-stall, ");
    $fwrite(fd16, "IB-stall, ");
    $fwrite(fd16, "FL-stall, ");
    $fwrite(fd16, "BE-stall, ");
    $fwrite(fd16, "LDQ-stall, ");
    $fwrite(fd16, "STQ-stall, ");
    $fwrite(fd16, "IQ-stall, ");
    $fwrite(fd16, "AL-stall, ");

    $fwrite(fd16, "BTB-Miss, ");
    $fwrite(fd16, "Miss-Rtn, ");
    $fwrite(fd16, "BR-Count, ");
    $fwrite(fd16, "Mis-Cnt, ");
    $fwrite(fd16, "LdVio-Cnt, ");

    $fwrite(fd16, "stat_num_corr, ");
    $fwrite(fd16, "stat_num_pred, ");
    $fwrite(fd16, "stat_num_cond_corr, ");
    $fwrite(fd16, "stat_num_cond_pred, ");
    $fwrite(fd16, "stat_num_return_corr, ");
    $fwrite(fd16, "stat_num_return_pred, ");

    $fwrite(fd16, "Commit_1, ");
    $fwrite(fd16, "Commit_2, ");
    $fwrite(fd16, "Commit_3, ");
    $fwrite(fd16, "Commit_4\n");
`endif
end


always @(posedge clk)
begin: HEARTBEAT
    
    CYCLE_COUNT = CYCLE_COUNT + 1;

    COMMIT_COUNT = COMMIT_COUNT + totalCommit;

    if ((CYCLE_COUNT % STAT_PRINT_COUNT) == 0)
    begin
        if (((COMMIT_COUNT - last_commit_cnt) == 0) & verifyCommits) // Check for stalls only once benchmark has started 
        begin
            $display("Cycle Count:%d Commit Count:%d  BTB-Miss:%d BTB-Miss-Rtn:%d  Br-Count:%d Br-Mispredict:%d",
                     CYCLE_COUNT,
                     COMMIT_COUNT,
                     btb_miss,
                     btb_miss_rtn,
                     br_count,
                     br_mispredict_count);

            $display("ERROR: instruction committing has stalled (Cycle: %0d, Commit: %0d", CYCLE_COUNT, COMMIT_COUNT);
            $finish;
            //$dumpflush;
        end

        $display("Cycle: %d Commit: %d  BTB-Miss: %0d  BTB-Miss-Rtn: %0d  Br-Count: %0d  Br-Mispredict: %0d",
                 CYCLE_COUNT,
                 COMMIT_COUNT,
                 btb_miss,
                 btb_miss_rtn,
                 br_count,
                 br_mispredict_count);

        
`ifdef DUMP_STATS
        ib_avg    = ib_count/(CYCLE_COUNT-10.0);
        fl_avg    = fl_count/(CYCLE_COUNT-10.0);
        iq_avg    = iq_count/(CYCLE_COUNT-10.0);
        ldq_avg   = ldq_count/(CYCLE_COUNT-10.0);
        stq_avg   = stq_count/(CYCLE_COUNT-10.0);
        al_avg    = al_count/(CYCLE_COUNT-10.0);

        $fwrite(fd16, "%d, ", CYCLE_COUNT); 
        $fwrite(fd16, "%d, ", COMMIT_COUNT); 

        $fwrite(fd16, "%2.3f, ", ib_avg); 
        $fwrite(fd16, "%2.3f, ", fl_avg); 
        $fwrite(fd16, "%2.3f, ", iq_avg); 
        $fwrite(fd16, "%2.4f, ", ldq_avg); 
        $fwrite(fd16, "%2.4f, ", stq_avg); 
        $fwrite(fd16, "%2.3f, ", al_avg); 

        $fwrite(fd16, "%d, ", fetch1_stall); 
        $fwrite(fd16, "%d, ", ctiq_stall); 
        $fwrite(fd16, "%d, ", instBuf_stall); 
        $fwrite(fd16, "%d, ", freelist_stall); 
        $fwrite(fd16, "%d, ", backend_stall); 
        $fwrite(fd16, "%d, ", ldq_stall); 
        $fwrite(fd16, "%d, ", stq_stall); 
        $fwrite(fd16, "%d, ", iq_stall); 
        $fwrite(fd16, "%d, ", rob_stall); 

        $fwrite(fd16, "%d, ", btb_miss); 
        $fwrite(fd16, "%d, ", btb_miss_rtn); 
        $fwrite(fd16, "%d, ", br_count); 
        $fwrite(fd16, "%d, ", br_mispredict_count); 
        $fwrite(fd16, "%d, ", load_violation_count); 

        $fwrite(fd16, "%d, ", `stat_num_corr);
        $fwrite(fd16, "%d, ", `stat_num_pred);
        $fwrite(fd16, "%d, ", `stat_num_cond_corr);
        $fwrite(fd16, "%d, ", `stat_num_cond_pred);
        $fwrite(fd16, "%d, ", `stat_num_return_corr);
        $fwrite(fd16, "%d, ", `stat_num_return_pred);

        $fwrite(fd16, "%d, ", commit_1); 
        $fwrite(fd16, "%d, ", commit_2); 
        $fwrite(fd16, "%d, ", commit_3); 
        $fwrite(fd16, "%d\n", commit_4); 
`endif

        last_commit_cnt = COMMIT_COUNT;
    end
end
/*
fuPkt                           exePacket      [0:`ISSUE_WIDTH-1];

always_comb
begin

    exePacket[0]      = coreTop.exePipe0.exePacket;
    exePacket[1]      = coreTop.exePipe1.exePacket;
    exePacket[2]      = coreTop.exePipe2.exePacket;
`ifdef ISSUE_FOUR_WIDE
    exePacket[3]      = coreTop.exePipe3.exePacket;
`endif
end
*/

/* Following maintains all the performance related counters. */
/*
always @(posedge clk)
begin: UPDATE_STATS
    int i;

    if (CYCLE_COUNT > 10)
    begin
        fetch1_stall      = fetch1_stall   + coreTop.fs1.stall_i;
        ctiq_stall        = ctiq_stall     + coreTop.fs2.ctiQueueFull;
        instBuf_stall     = instBuf_stall  + coreTop.instBuf.instBufferFull;
        freelist_stall    = freelist_stall + coreTop.rename.freeListEmpty;
        backend_stall     = backend_stall  + coreTop.dispatch.stall;
        ldq_stall         = ldq_stall      + coreTop.dispatch.loadStall;
        stq_stall         = stq_stall      + coreTop.dispatch.storeStall;
        iq_stall          = iq_stall       + coreTop.dispatch.iqStall;
        rob_stall         = rob_stall      + coreTop.dispatch.alStall;

        btb_miss          = btb_miss       + (~coreTop.fs1.stall_i & coreTop.fs1.fs2RecoverFlag_i);
        btb_miss_rtn      = btb_miss_rtn   + (~coreTop.fs1.stall_i &
                                               coreTop.fs1.fs2MissedReturn_i &
                                               coreTop.fs1.fs2RecoverFlag_i);
        for (i = 0; i < `COMMIT_WIDTH; i++)
        begin
            br_count        = br_count       + ((coreTop.activeList.totalCommit >= (i+1)) & coreTop.activeList.ctrlAl[i][5]);
            ld_count        = ld_count       + coreTop.activeList.commitLoad_o[i];
        end

        br_mispredict_count =  br_mispredict_count + coreTop.activeList.mispredFlag_reg;

        load_violation_count = load_violation_count + coreTop.activeList.violateFlag_reg;

        ib_count  = ib_count  + coreTop.instBuf.instCount;
        fl_count  = fl_count  + coreTop.rename.specfreelist.freeListCnt;
        iq_count  = iq_count  + coreTop.cntInstIssueQ;
        ldq_count = ldq_count + coreTop.ldqCount;
        stq_count = stq_count + coreTop.stqCount;
        al_count  = al_count  + coreTop.activeListCnt;
        
        commit_1  = commit_1  + ((coreTop.activeList.totalCommit == 1) ? 1'h1: 1'h0);
        commit_2  = commit_2  + ((coreTop.activeList.totalCommit == 2) ? 1'h1: 1'h0);
        commit_3  = commit_3  + ((coreTop.activeList.totalCommit == 3) ? 1'h1: 1'h0);
        commit_4  = commit_4  + ((coreTop.activeList.totalCommit == 4) ? 1'h1: 1'h0);

    end
end
*/
always @(posedge clk)
begin: END_SIMULATION

    if (COMMIT_COUNT >= SIM_STOP_COUNT)
    //if (CYCLE_COUNT >= SIM_STOP_COUNT)
//      $stop;
      
    begin
        ipc = $itor(COMMIT_COUNT)/$itor(CYCLE_COUNT);

/*
        // Before the simulator is terminated, print all the stats:
        $display(" Fetch1-Stall:%d \n Ctiq-Stall:%d \n InstBuff-Stall:%d \n FreeList-Stall:%d \n SMT-Stall:%d \n Backend-Stall:%d \n LDQ-Stall:%d \n STQ-Stall:%d \n IQ-Stall:%d \n ROB-Stall:%d\n",
        fetch1_stall,
        ctiq_stall,
        instBuf_stall,
        freelist_stall,
        smt_stall,
        backend_stall,
        ldq_stall,
        stq_stall,
        iq_stall,
        rob_stall);

        $display("stat_num_corr        %d", `stat_num_corr);
        $display("stat_num_pred        %d", `stat_num_pred);
        $display("stat_num_cond_corr   %d", `stat_num_cond_corr);
        $display("stat_num_cond_pred   %d", `stat_num_cond_pred);
        $display("stat_num_return_corr %d", `stat_num_return_corr);
        $display("stat_num_return_pred %d", `stat_num_return_pred);
        $display("");

        ib_avg    = ib_count/(CYCLE_COUNT-10.0);
        fl_avg    = fl_count/(CYCLE_COUNT-10.0);
        iq_avg    = iq_count/(CYCLE_COUNT-10.0);
        ldq_avg   = ldq_count/(CYCLE_COUNT-10.0);
        stq_avg   = stq_count/(CYCLE_COUNT-10.0);
        al_avg    = al_count/(CYCLE_COUNT-10.0);

        $write(" IB-avg: %2.1f\n", ib_avg); 
        $write(" FL-avg: %2.1f\n", fl_avg); 
        $write(" IQ-avg: %2.1f\n", iq_avg); 
        $write(" LDQ-avg: %2.1f\n", ldq_avg); 
        $write(" STQ-avg: %2.1f\n", stq_avg); 
        $write(" AL-avg: %2.1f\n", al_avg); 
      */
        $display("Cycle Count:%d Commit Count:%d    IPC:%2.2f     BTB-Miss:%d BTB-Miss-Rtn:%d  Br-Count:%d Br-Mispredict:%d Ld Count:%d Ld Violation:%d",
        CYCLE_COUNT,
        COMMIT_COUNT,
        ipc,
        btb_miss,
        btb_miss_rtn,
        br_count,
        br_mispredict_count,
        ld_count,
        load_violation_count);
      /*
        `ifdef DUMP_STATS
        ib_avg    = ib_count/(CYCLE_COUNT-10.0);
        fl_avg    = fl_count/(CYCLE_COUNT-10.0);
        iq_avg    = iq_count/(CYCLE_COUNT-10.0);
        ldq_avg   = ldq_count/(CYCLE_COUNT-10.0);
        stq_avg   = stq_count/(CYCLE_COUNT-10.0);
        al_avg    = al_count/(CYCLE_COUNT-10.0);

        $fwrite(fd16, "%d, ", CYCLE_COUNT); 
        $fwrite(fd16, "%d, ", COMMIT_COUNT); 

        $fwrite(fd16, "%2.3f, ", ib_avg); 
        $fwrite(fd16, "%2.3f, ", fl_avg); 
        $fwrite(fd16, "%2.3f, ", iq_avg); 
        $fwrite(fd16, "%2.4f, ", ldq_avg); 
        $fwrite(fd16, "%2.4f, ", stq_avg); 
        $fwrite(fd16, "%2.3f, ", al_avg); 

        $fwrite(fd16, "%d, ", fetch1_stall); 
        $fwrite(fd16, "%d, ", ctiq_stall); 
        $fwrite(fd16, "%d, ", instBuf_stall); 
        $fwrite(fd16, "%d, ", freelist_stall); 
        $fwrite(fd16, "%d, ", backend_stall); 
        $fwrite(fd16, "%d, ", ldq_stall); 
        $fwrite(fd16, "%d, ", stq_stall); 
        $fwrite(fd16, "%d, ", iq_stall); 
        $fwrite(fd16, "%d, ", rob_stall); 

        $fwrite(fd16, "%d, ", btb_miss); 
        $fwrite(fd16, "%d, ", btb_miss_rtn); 
        $fwrite(fd16, "%d, ", br_count); 
        $fwrite(fd16, "%d, ", br_mispredict_count); 
        $fwrite(fd16, "%d, ", load_violation_count); 

        $fwrite(fd16, "%d, ", `stat_num_corr);
        $fwrite(fd16, "%d, ", `stat_num_pred);
        $fwrite(fd16, "%d, ", `stat_num_cond_corr);
        $fwrite(fd16, "%d, ", `stat_num_cond_pred);
        $fwrite(fd16, "%d, ", `stat_num_return_corr);
        $fwrite(fd16, "%d, ", `stat_num_return_pred);

        $fwrite(fd16, "%d, ", commit_1); 
        $fwrite(fd16, "%d, ", commit_2); 
        $fwrite(fd16, "%d, ", commit_3); 
        $fwrite(fd16, "%d\n", commit_4); 
        `endif

        $fclose(fd0);
        $fclose(fd1);
        $fclose(fd2);
        $fclose(fd3);
        $fclose(fd4);
        $fclose(fd5);
        $fclose(fd6);
        $fclose(fd7);
        $fclose(fd8);
        $fclose(fd9);
        $fclose(fd10);
        $fclose(fd11);
        $fclose(fd12);
        $fclose(fd13);
        $fclose(fd14);
        $fclose(fd16);
        $fclose(fd17);
        $fclose(fd18);
        $fclose(fd19);
        $fclose(fd20);
        $fclose(fd21);
        $fclose(fd22);
        $fclose(fd23);

        //`endif
*/      
        $finish;
    end
  //$dumpflush;
end

`ifdef PRINT_EN

/*  Prints fetch1 stage related latches in a file every cycle. */
always @(posedge clk)
begin : Core_OOO
    int i;

  if (PRINT)
  begin
        $fwrite(fd9, "------------------------------------------------------\n");
        $fwrite(fd9, "Cycle: %0d  Commit: %0d\n\n",CYCLE_COUNT, COMMIT_COUNT);

`ifdef DYNAMIC_CONFIG
        $fwrite(fd9, "stallFetch: %b\n\n", coreTop.stallFetch);
`endif        

  end
end
`endif



`ifdef PRINT_EN
btbDataPkt                           btbData       [0:`FETCH_WIDTH-1];

always_comb
begin
    int i;
    for (i = 0; i < `FETCH_WIDTH; i++)
    begin
        btbData[i]  = coreTop.fs1.btb.btbData[i];
    end
end

/*  Prints fetch1 stage related latches in a file every cycle. */
always @(posedge clk)
begin : FETCH1
    int i;

  if (PRINT)
  begin
        $fwrite(fd9, "------------------------------------------------------\n");
        $fwrite(fd9, "Cycle: %0d  Commit: %0d\n\n",CYCLE_COUNT, COMMIT_COUNT);

        $fwrite(fd9, "stall_i: %b\n\n", coreTop.fs1.stall_i);

        $fwrite(fd9, "               -- Next PC --\n\n");
        
        $fwrite(fd9, "PC:             %08x\n",
                coreTop.fs1.PC);

        $fwrite(fd9, "recoverPC_i:    %08x recoverFlag_i: %b mispredFlag_reg: %b violateFlag_reg: %b\n",
                coreTop.fs1.recoverPC_i,
                coreTop.fs1.recoverFlag_i,
                coreTop.activeList.mispredFlag_reg,
                coreTop.activeList.violateFlag_reg);

        $fwrite(fd9, "exceptionPC_i:  %08x exceptionFlag_i: %b\n",
                coreTop.fs1.exceptionPC_i,
                coreTop.fs1.exceptionFlag_i);

        $fwrite(fd9, "fs2RecoverPC_i: %08x fs2RecoverFlag_i: %b\n",
                coreTop.fs1.fs2RecoverPC_i,
                coreTop.fs1.fs2RecoverFlag_i);

        $fwrite(fd9, "nextPC:         %08x\n\n",
                coreTop.fs1.nextPC);

        $fwrite(fd9, "takenVect:  %04b\n",
                coreTop.fs1.takenVect);

        $fwrite(fd9, "addrRAS:    %08x\n\n",
                coreTop.fs1.addrRAS);

        $fwrite(fd9, "               -- BTB --\n\n");
        
        $fwrite(fd9, "\nbtbData       ");
        for (i = 0; i < `FETCH_WIDTH; i++)
            $fwrite(fd9, "     [%1d] ", i);

        $fwrite(fd9, "\ntag           ");
        for (i = 0; i < `FETCH_WIDTH; i++)
            $fwrite(fd9, "%08x ", btbData[i].tag);

        $fwrite(fd9, "\ntakenPC       ");
        for (i = 0; i < `FETCH_WIDTH; i++)
            $fwrite(fd9, "%08x ", btbData[i].takenPC);

        $fwrite(fd9, "\nctrlType      ");
        for (i = 0; i < `FETCH_WIDTH; i++)
            $fwrite(fd9, "%08x ", btbData[i].ctrlType);

        $fwrite(fd9, "\nvalid         ");
        for (i = 0; i < `FETCH_WIDTH; i++)
            $fwrite(fd9, "%08x ", btbData[i].valid);

        $fwrite(fd9, "\n\nupdatePC_i:     %08x\n",
                coreTop.fs1.updatePC_i);

        $fwrite(fd9, "updateNPC_i:    %08x\n",
                coreTop.fs1.updateNPC_i);

        $fwrite(fd9, "updateBrType_i: %x\n",
                coreTop.fs1.updateBrType_i);

        $fwrite(fd9, "updateDir_i:    %b\n",
                coreTop.fs1.updateDir_i);

        $fwrite(fd9, "updateEn_i:     %b\n\n",
                coreTop.fs1.updateEn_i);


        $fwrite(fd9, "               -- BP --\n\n");
        
        $fwrite(fd9, "predDir:    %04b\n",
                coreTop.fs1.predDir);

        $fwrite(fd9, "instOffset[0]:    %x\n",
                coreTop.fs1.bp.instOffset[0]);

        $fwrite(fd9, "rdAddr         ");
        for (i = 0; i < `FETCH_WIDTH; i++)
            $fwrite(fd9, "%x ", coreTop.fs1.bp.rdAddr[i]);

        $fwrite(fd9, "\nrdData         ");
        for (i = 0; i < `FETCH_WIDTH; i++)
            $fwrite(fd9, "%x ", coreTop.fs1.bp.rdData[i]);

        $fwrite(fd9, "\npredCounter    ");
        for (i = 0; i < `FETCH_WIDTH; i++)
            $fwrite(fd9, "%x ", coreTop.fs1.bp.predCounter[i]);

        $fwrite(fd9, "\n\nwrAddr:        %x\n",
                coreTop.fs1.bp.wrAddr);

        $fwrite(fd9, "\nwrData:        %x\n",
                coreTop.fs1.bp.wrData);

        $fwrite(fd9, "\nwrEn         ");
        for (i = 0; i < `FETCH_WIDTH; i++)
            $fwrite(fd9, "%x ", coreTop.fs1.bp.wrEn[i]);


        $fwrite(fd9, "\n\n               -- RAS --\n\n");
        
        $fwrite(fd9, "pushAddr:   %08x\n",
                coreTop.fs1.pushAddr);

        $fwrite(fd9, "pushRAS:   %b  popRAS: %b\n",
                coreTop.fs1.pushRAS,
                coreTop.fs1.popRAS);

        $fwrite(fd9, "\n\n");

        if (coreTop.instBufferFull)
            $fwrite(fd9, "instBufferFull:%b\n",
                    coreTop.instBufferFull);

    if (coreTop.ctiQueueFull)
      $fwrite(fd9, "ctiQueueFull:%b\n",
              coreTop.ctiQueueFull);

    if (coreTop.fs1.recoverFlag_i)

    if(coreTop.fs1.ras.pop_i)
      $fwrite(fd9, "BTB hit for Rtr instr, spec_tos:%d, Pop Addr: %x",
              coreTop.fs1.ras.spec_tos,
              coreTop.fs1.ras.addrRAS_o);

    if (coreTop.fs1.ras.push_i)
      $fwrite(fd9, "BTB hit for CALL instr, Push Addr: %x",
              coreTop.fs1.ras.pushAddr_i);

    $fwrite(fd9, "RAS POP Addr:%x\n",
            coreTop.fs1.ras.addrRAS_o);

    if (coreTop.fs1.fs2RecoverFlag_i)
      $fwrite(fd9, "Fetch-2 fix BTB miss (target addr): %h\n",
              coreTop.fs1.fs2RecoverPC_i);

        $fwrite(fd9, "\n\n\n");
  end
end
`endif


`ifdef PRINT_EN
/* Prints fetch2/Ctrl Queue related latches in a file every cycle. */
always_ff @(posedge clk) 
begin : FETCH2
    int i;

  if (PRINT)
  begin
        $fwrite(fd14, "------------------------------------------------------\n");
        $fwrite(fd14, "Cycle: %0d  Commit: %0d\n\n\n",CYCLE_COUNT, COMMIT_COUNT);

    if (coreTop.fs2.ctiQueue.stall_i)
    begin
      $fwrite(fd14, "Fetch2 is stalled ....\n");
    end

    if (coreTop.fs2.ctiQueueFull_o)
    begin
      $fwrite(fd14, "CTI Queue is full ....\n");
    end

    $fwrite(fd14, "\n");

    $fwrite(fd14, "Control vector:%b fs1Ready:%b\n",
            coreTop.fs2.ctiQueue.ctrlVect_i,
            coreTop.fs2.ctiQueue.fs1Ready_i);


    $fwrite(fd14, "\n");

    $fwrite(fd14, "ctiq Tag0:%d ",
            coreTop.fs2.ctiQueue.ctiID_o[0]);

`ifdef FETCH_TWO_WIDE
    $fwrite(fd14, "ctiq Tag1:%d ",
            coreTop.fs2.ctiQueue.ctiID_o[1]);
`endif

`ifdef FETCH_THREE_WIDE
    $fwrite(fd14, "ctiq Tag2:%d ",
            coreTop.fs2.ctiQueue.ctiID_o[2]);
`endif

`ifdef FETCH_FOUR_WIDE
    $fwrite(fd14, "ctiq Tag3:%d ",
            coreTop.fs2.ctiQueue.ctiID_o[3]);
`endif

`ifdef FETCH_FIVE_WIDE
    $fwrite(fd14, "ctiq Tag4:%d ",
            coreTop.fs2.ctiQueue.ctiID_o[4]);
`endif

`ifdef FETCH_SIX_WIDE
    $fwrite(fd14, "ctiq Tag5:%d ",
            coreTop.fs2.ctiQueue.ctiID_o[5]);
`endif

`ifdef FETCH_SEVEN_WIDE
    $fwrite(fd14, "ctiq Tag6:%d ",
            coreTop.fs2.ctiQueue.ctiID_o[6]);
`endif

`ifdef FETCH_EIGHT_WIDE
    $fwrite(fd14, "ctiq Tag7:%d ",
            coreTop.fs2.ctiQueue.ctiID_o[7]);
`endif

        $fwrite(fd14, "\nupdateCounter_i:   %x\n",
                coreTop.fs1.bp.updateCounter_i);

        $fwrite(fd14, "\ncti.headPtr:       %x\n",
                coreTop.fs2.ctiQueue.headPtr);

        $fwrite(fd14, "\nctiq.ctiID            ");
        for (i = 0; i < `FETCH_WIDTH; i++)
            $fwrite(fd14, "%x ", coreTop.fs2.ctiQueue.ctiID[i]);

        $fwrite(fd14, "\nctiq.predCounter_i    ");
        for (i = 0; i < `FETCH_WIDTH; i++)
            $fwrite(fd14, "%x ", coreTop.fs2.ctiQueue.predCounter_i[i]);

        $fwrite(fd14, "\nctiq.ctrlVect_i       ");
        for (i = 0; i < `FETCH_WIDTH; i++)
            $fwrite(fd14, "%x ", coreTop.fs2.ctiQueue.ctrlVect_i[i]);

    $fwrite(fd14, "\n\n");

    if (coreTop.fs2.ctiQueue.exeCtrlValid_i) begin
      $fwrite(fd14, "\nwriting back a control instruction.....\n");

      $fwrite(fd14,"ctiq index:%d target addr:%h br outcome:%b\n\n",
              coreTop.fs2.ctiQueue.exeCtiID_i,
              coreTop.fs2.ctiQueue.exeCtrlNPC_i,
              coreTop.fs2.ctiQueue.exeCtrlDir_i);
    end

    if (coreTop.fs2.ctiQueue.recoverFlag_i)
    begin
      $fwrite(fd14, "Recovery Flag is High....\n\n");
    end

    if (coreTop.fs2.ctiQueue.updateEn_o)
    begin
      $fwrite(fd14, "\nupdating the BTB and BPB.....\n");

      $fwrite(fd14, "updatePC:%h updateNPC: %h updateCtrlType:%b updateDir:%b\n\n",
              coreTop.fs2.ctiQueue.updatePC_o,
              coreTop.fs2.ctiQueue.updateNPC_o,
              coreTop.fs2.ctiQueue.updateCtrlType_o,
              coreTop.fs2.updateDir_o);
    end

    $fwrite(fd14, "ctiq=> headptr:%d tailptr:%d commitPtr:%d instcount:%d commitCnt:%d\n",
            coreTop.fs2.ctiQueue.headPtr,
            coreTop.fs2.ctiQueue.tailPtr,
            coreTop.fs2.ctiQueue.commitPtr,
            coreTop.fs2.ctiQueue.ctrlCount,
            coreTop.fs2.ctiQueue.commitCnt);

    $fwrite(fd14, "\n");
  end
end



/*  Prints decode stage related latches in a file every cycle. */
decPkt                     decPacket [0:`FETCH_WIDTH-1];
renPkt                     ibPacket [0:2*`FETCH_WIDTH-1];

always_comb
begin
    int i;
    for (i = 0; i < `FETCH_WIDTH; i++)
    begin
        decPacket[i]    = coreTop.decPacket_l1[i];
        ibPacket[2*i]   = coreTop.ibPacket[2*i];
        ibPacket[2*i+1] = coreTop.ibPacket[2*i+1];
    end
end

always_ff @(posedge clk)
begin : DECODE
    int i;

    if (PRINT)
    begin
        $fwrite(fd2, "------------------------------------------------------\n");
        $fwrite(fd2, "Cycle: %0d  Commit: %0d\n\n\n",CYCLE_COUNT, COMMIT_COUNT);

        $fwrite(fd2, "fs2Ready_i: %b\n", coreTop.decode.fs2Ready_i);

        $fwrite(fd2, "\n               -- decPackets --\n");
        
        $fwrite(fd2, "\ndecPacket_i   ");
        for (i = 0; i < `FETCH_WIDTH; i++)
            $fwrite(fd2, "     [%1d] ", i);

        $fwrite(fd2, "\npc:           ");
        for (i = 0; i < `FETCH_WIDTH; i++)
            $fwrite(fd2, "%08x ", decPacket[i].pc);

        $fwrite(fd2, "\nctrlType:     ");
        for (i = 0; i < `FETCH_WIDTH; i++)
            $fwrite(fd2, "      %2x ", decPacket[i].ctrlType);

        $fwrite(fd2, "\nctiID:        ");
        for (i = 0; i < `FETCH_WIDTH; i++)
            $fwrite(fd2, "      %2x ", decPacket[i].ctiID);

        $fwrite(fd2, "\npredNPC:      ");
        for (i = 0; i < `FETCH_WIDTH; i++)
            $fwrite(fd2, "%08x ", decPacket[i].predNPC);

        $fwrite(fd2, "\npredDir:      ");
        for (i = 0; i < `FETCH_WIDTH; i++)
            $fwrite(fd2, "       %1x ", decPacket[i].predDir);

        $fwrite(fd2, "\nvalid:        ");
        for (i = 0; i < `FETCH_WIDTH; i++)
            $fwrite(fd2, "       %1x ", decPacket[i].valid);


        $fwrite(fd2, "\n\n               -- ibPackets --\n");
        
        $fwrite(fd2, "\nibPacket_o    ");
        for (i = 0; i < 2*`FETCH_WIDTH; i++)
            $fwrite(fd2, "     [%1d] ", i);

        $fwrite(fd2, "\npc:           ");
        for (i = 0; i < 2*`FETCH_WIDTH; i++)
            $fwrite(fd2, "%08x ", ibPacket[i].pc);

        $fwrite(fd2, "\nopcode:       ");
        for (i = 0; i < 2*`FETCH_WIDTH; i++)
            $fwrite(fd2, "      %2x ",  ibPacket[i].opcode);

        $fwrite(fd2, "\nlogDest (V):  ");
        for (i = 0; i < 2*`FETCH_WIDTH; i++)
            $fwrite(fd2, "  %2x (%d) ", ibPacket[i].logDest, ibPacket[i].logDestValid);

        $fwrite(fd2, "\nlogSrc1 (V):  ");
        for (i = 0; i < 2*`FETCH_WIDTH; i++)
            $fwrite(fd2, "  %2x (%d) ", ibPacket[i].logSrc1, ibPacket[i].logSrc1Valid);

        $fwrite(fd2, "\nlogSrc2 (V):  ");
        for (i = 0; i < 2*`FETCH_WIDTH; i++)
            $fwrite(fd2, "  %2x (%d) ", ibPacket[i].logSrc2, ibPacket[i].logSrc2Valid);

        $fwrite(fd2, "\nimmed (V):    ");
        for (i = 0; i < 2*`FETCH_WIDTH; i++)
            $fwrite(fd2, "%04x (%d) ", ibPacket[i].immed, ibPacket[i].immedValid);

        $fwrite(fd2, "\nisLoad:       ");
        for (i = 0; i < 2*`FETCH_WIDTH; i++)
            $fwrite(fd2, "       %1x ", ibPacket[i].isLoad);

        $fwrite(fd2, "\nisStore:      ");
        for (i = 0; i < 2*`FETCH_WIDTH; i++)
            $fwrite(fd2, "       %1x ", ibPacket[i].isStore);

        $fwrite(fd2, "\nldstSize:     ");
        for (i = 0; i < 2*`FETCH_WIDTH; i++)
            $fwrite(fd2, "       %1x ", ibPacket[i].ldstSize);

        $fwrite(fd2, "\nctrlType:     ");
        for (i = 0; i < 2*`FETCH_WIDTH; i++)
            $fwrite(fd2, "      %2x ", ibPacket[i].ctrlType);

        $fwrite(fd2, "\nctiID:        ");
        for (i = 0; i < 2*`FETCH_WIDTH; i++)
            $fwrite(fd2, "      %2x ", ibPacket[i].ctiID);

        $fwrite(fd2, "\npredNPC:      ");
        for (i = 0; i < 2*`FETCH_WIDTH; i++)
            $fwrite(fd2, "%08x ", ibPacket[i].predNPC);

        $fwrite(fd2, "\npredDir:      ");
        for (i = 0; i < 2*`FETCH_WIDTH; i++)
            $fwrite(fd2, "       %1x ", ibPacket[i].predDir);

        $fwrite(fd2, "\nvalid:        ");
        for (i = 0; i < 2*`FETCH_WIDTH; i++)
            $fwrite(fd2, "       %1x ", ibPacket[i].valid);

        $fwrite(fd2, "\n\n\n");

    end
end


/*  Prints Instruction Buffer stage related latches in a file every cycle. */
always @(posedge clk)
begin:INSTBUF

  if (PRINT)
  begin
        $fwrite(fd1, "------------------------------------------------------\n");
        $fwrite(fd1, "Cycle: %0d  Commit: %0d\n\n\n",CYCLE_COUNT, COMMIT_COUNT);

    $fwrite(fd1, "Inst Buffer Full:%b freelistEmpty:%b stallFrontEnd:%b\n",
            coreTop.instBuf.stallFetch_i,
            coreTop.freeListEmpty,
            coreTop.stallfrontEnd);

    $fwrite(fd1, "\n");

    $fwrite(fd1, "Decode Ready=%b\n",
            coreTop.instBuf.decodeReady_i);

    $fwrite(fd1, "instbuffer head=%d instbuffer tail=%d inst count=%d\n",
            coreTop.instBuf.headPtr,
            coreTop.instBuf.tailPtr,
            coreTop.instBuf.instCount);

    $fwrite(fd1, "instBufferReady_o:%b\n",
            coreTop.instBuf.instBufferReady_o);

    if (coreTop.recoverFlag)
      $fwrite(fd1, "recoverFlag_i is High\n");

    if (coreTop.instBuf.flush_i)
      $fwrite(fd1, "flush_i is High\n");

    if (coreTop.instBuf.instCount > `INST_QUEUE)
    begin
      $fwrite(fd1, "Instruction Buffer overflow\n");
      $display("\n** Cycle: %d Instruction Buffer Overflow **\n",CYCLE_COUNT);
    end

    $fwrite(fd1,"\n");
  end
end


/*  Prints rename stage related latches in a file every cycle. */
disPkt                     disPacket [0:`DISPATCH_WIDTH-1];
phys_reg                   freedPhyReg [0:`COMMIT_WIDTH-1];

always_comb
begin
    int i;
    for (i = 0; i < `DISPATCH_WIDTH; i++)
    begin
        disPacket[i]    = coreTop.disPacket[i];
        freedPhyReg[i]  = coreTop.rename.specfreelist.freedPhyReg_i[i];
    end
end

always @(posedge clk)
begin:RENAME
    int i;

  if (PRINT)
  begin
        $fwrite(fd0, "------------------------------------------------------\n");
        $fwrite(fd0, "Cycle: %0d  Commit: %0d\n\n\n",CYCLE_COUNT, COMMIT_COUNT);

        $fwrite(fd0, "Decode Ready: %b\n",
                coreTop.rename.decodeReady_i);
                /* coreTop.rename.branchCount_i); */

    $fwrite(fd0, "freeListEmpty: %b\n",
            coreTop.rename.freeListEmpty);

        /* disPacket_o */
        $fwrite(fd0, "disPacket_o   ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd0, "     [%1d] ", i);

        $fwrite(fd0, "\npc:           ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd0, "%08x ", disPacket[i].pc);

        $fwrite(fd0, "\nopcode:       ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd0, "      %2x ",  disPacket[i].opcode);

        $fwrite(fd0, "\nfu:           ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd0, "       %1x ", disPacket[i].fu);

        $fwrite(fd0, "\nlogDest:      ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd0, "      %2x ", disPacket[i].logDest);

        $fwrite(fd0, "\nphyDest (V):  ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd0, "  %2x (%d) ", disPacket[i].phyDest, disPacket[i].phyDestValid);

        $fwrite(fd0, "\nphySrc1 (V):  ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd0, "  %2x (%d) ", disPacket[i].phySrc1, disPacket[i].phySrc1Valid);

        $fwrite(fd0, "\nphySrc2 (V):  ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd0, "  %2x (%d) ", disPacket[i].phySrc2, disPacket[i].phySrc2Valid);

        $fwrite(fd0, "\nimmed (V):    ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd0, "%04x (%d) ", disPacket[i].immed, disPacket[i].immedValid);

        $fwrite(fd0, "\nisLoad:       ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd0, "       %1x ", disPacket[i].isLoad);

        $fwrite(fd0, "\nisStore:      ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd0, "       %1x ", disPacket[i].isStore);

        $fwrite(fd0, "\nldstSize:     ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd0, "       %1x ", disPacket[i].ldstSize);

        $fwrite(fd0, "\nctiID:        ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd0, "      %2x ", disPacket[i].ctiID);

        $fwrite(fd0, "\npredNPC:      ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd0, "%08x ", disPacket[i].predNPC);

        $fwrite(fd0, "\npredDir:      ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd0, "       %1x ", disPacket[i].predDir);

        $fwrite(fd0, "\n\nrename ready:%b\n\n", coreTop.rename.renameReady_o);

        $fwrite(fd0, "               -- Free List (Popped) --\n\n");

        $fwrite(fd0, "freeListHead: %x\n", coreTop.rename.specfreelist.freeListHead);
        $fwrite(fd0, "freeListTail: %x\n", coreTop.rename.specfreelist.freeListTail);
        $fwrite(fd0, "freeListCnt: d%d\n", coreTop.rename.specfreelist.freeListCnt);
        $fwrite(fd0, "pushNumber: d%d\n", coreTop.rename.specfreelist.pushNumber);
        
        $fwrite(fd0, "\nrdAddr:       ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd0, "      %2x ", coreTop.rename.specfreelist.readAddr[i]);

        $fwrite(fd0, "\nfreePhyReg:   ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd0, "      %2x ", coreTop.rename.specfreelist.freePhyReg[i]);

        $fwrite(fd0, "\n\n\n               -- Free List (Pushed) --\n\n");

        $fwrite(fd0, "\nfreedPhyReg (V): ");
        for (i = 0; i < `COMMIT_WIDTH; i++)
            $fwrite(fd0, "      %2x ", freedPhyReg[i].reg_id, freedPhyReg[i].valid);

    $fwrite(fd0,"\n\n\n");
  end
end
`endif


`ifdef PRINT_EN
/* Prints dispatch related signals and latch value. */
disPkt                           disPacket_l1 [0:`DISPATCH_WIDTH-1];
iqPkt                            iqPacket  [0:`DISPATCH_WIDTH-1];
alPkt                            alPacket  [0:`DISPATCH_WIDTH-1];
lsqPkt                           lsqPacket [0:`DISPATCH_WIDTH-1];

always_comb
begin
    int i;
    for (i = 0; i < `DISPATCH_WIDTH; i++)
    begin
        disPacket_l1[i]               = coreTop.disPacket_l1[i];
        iqPacket[i]                = coreTop.iqPacket[i];
        alPacket[i]                = coreTop.alPacket[i];
        lsqPacket[i]               = coreTop.lsqPacket[i];
    end
end

always_ff @(posedge clk)
begin:DISPATCH
    int i;

    if (PRINT)
    begin
        $fwrite(fd3, "----------------------------------------------------------------------\n");
        $fwrite(fd3, "Cycle: %d Commit Count: %d\n\n", CYCLE_COUNT, COMMIT_COUNT);

        /* disPacket_i */
        $fwrite(fd3, "disPacket_i   ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd3, "     [%1d] ", i);

        $fwrite(fd3, "\npc:           ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd3, "%08x ", disPacket_l1[i].pc);

        $fwrite(fd3, "\nopcode:       ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd3, "      %2x ",  disPacket_l1[i].opcode);

        $fwrite(fd3, "\nfu:           ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd3, "       %1x ", disPacket_l1[i].fu);

        $fwrite(fd3, "\nlogDest:      ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd3, "      %2x ", disPacket_l1[i].logDest);

        $fwrite(fd3, "\nphyDest (V):  ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd3, "  %2x (%d) ", disPacket_l1[i].phyDest, disPacket_l1[i].phyDestValid);

        $fwrite(fd3, "\nphySrc1 (V):  ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd3, "  %2x (%d) ", disPacket_l1[i].phySrc1, disPacket_l1[i].phySrc1Valid);

        $fwrite(fd3, "\nphySrc2 (V):  ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd3, "  %2x (%d) ", disPacket_l1[i].phySrc2, disPacket_l1[i].phySrc2Valid);

        $fwrite(fd3, "\nimmed (V):    ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd3, "%04x (%d) ", disPacket_l1[i].immed, disPacket_l1[i].immedValid);

        $fwrite(fd3, "\nisLoad:       ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd3, "       %1x ", disPacket_l1[i].isLoad);

        $fwrite(fd3, "\nisStore:      ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd3, "       %1x ", disPacket_l1[i].isStore);

        $fwrite(fd3, "\nldstSize:     ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd3, "       %1x ", disPacket_l1[i].ldstSize);

        $fwrite(fd3, "\nctiID:        ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd3, "      %2x ", disPacket_l1[i].ctiID);

        $fwrite(fd3, "\npredNPC:      ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd3, "%08x ", disPacket_l1[i].predNPC);

        $fwrite(fd3, "\npredDir:      ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd3, "       %1x ", disPacket_l1[i].predDir);

        /* iqPacket_o */
        $fwrite(fd3, "\n\niqPacket_o    ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd3, "     [%1d] ", i);

        $fwrite(fd3, "\npc:           ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd3, "%08x ", iqPacket[i].pc);

        $fwrite(fd3, "\nopcode:       ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd3, "      %2x ",  iqPacket[i].opcode);

        $fwrite(fd3, "\nfu:           ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd3, "       %1x ", iqPacket[i].fu);

        $fwrite(fd3, "\nphyDest (V):  ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd3, "  %2x (%d) ", iqPacket[i].phyDest, iqPacket[i].phyDestValid);

        $fwrite(fd3, "\nphySrc1 (V):  ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd3, "  %2x (%d) ", iqPacket[i].phySrc1, iqPacket[i].phySrc1Valid);

        $fwrite(fd3, "\nphySrc2 (V):  ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd3, "  %2x (%d) ", iqPacket[i].phySrc2, iqPacket[i].phySrc2Valid);

        $fwrite(fd3, "\nimmed (V):    ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd3, "%04x (%d) ", iqPacket[i].immed, iqPacket[i].immedValid);

        $fwrite(fd3, "\nisLoad:       ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd3, "       %1x ", iqPacket[i].isLoad);

        $fwrite(fd3, "\nisStore:      ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd3, "       %1x ", iqPacket[i].isStore);

        $fwrite(fd3, "\nldstSize:     ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd3, "       %1x ", iqPacket[i].ldstSize);

        $fwrite(fd3, "\nctiID:        ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd3, "      %2x ", iqPacket[i].ctiID);

        $fwrite(fd3, "\npredNPC:      ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd3, "%08x ", iqPacket[i].predNPC);

        $fwrite(fd3, "\npredDir:      ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd3, "       %1x ", iqPacket[i].predDir);


    $fwrite(fd3, "\n\nloadCnt: d%d storeCnt: d%d\n",
            coreTop.dispatch.loadCnt,
            coreTop.dispatch.storeCnt);

    $fwrite(fd3, "backendReady_o: %b\n",
            coreTop.dispatch.backEndReady_o);

    if (coreTop.dispatch.loadStall)       $fwrite(fd3,"LDQ Stall\n");
    if (coreTop.dispatch.storeStall)      $fwrite(fd3,"STQ Stall\n");
    if (coreTop.dispatch.iqStall)         $fwrite(fd3,"IQ Stall: IQ Cnt:%d\n",
                                                    coreTop.dispatch.issueQueueCnt_i);
    if (coreTop.dispatch.alStall)         $fwrite(fd3,"Active List Stall\n");
    if (~coreTop.dispatch.renameReady_i)  $fwrite(fd3,"renameReady_i Stall\n");


`ifdef ENABLE_LD_VIOLATION_PRED
    $fwrite(fd3, "predictLdViolation: %b\n",
            coreTop.dispatch.predLoadVio);

    if (coreTop.dispatch.ldVioPred.loadViolation_i && coreTop.dispatch.ldVioPred.recoverFlag_i)
    begin
      $fwrite(fd3, "Update Load Violation Predictor\n");

      $fwrite(fd3, "PC:0x%x Addr:0x%x Tag:0x%x\n",
              coreTop.dispatch.ldVioPred.recoverPC_i,
              coreTop.dispatch.ldVioPred.predAddr0wr,
              coreTop.dispatch.ldVioPred.predTag0wr);
    end
`endif
    $fwrite(fd3,"\n",);
  end
end
`endif


`ifdef PRINT_EN
phys_reg                        phyDest  [0:`DISPATCH_WIDTH-1];
iqEntryPkt                      iqFreeEntry [0:`DISPATCH_WIDTH-1];

iqEntryPkt                      iqFreedEntry   [0:`ISSUE_WIDTH-1];
iqEntryPkt                      iqGrantedEntry [0:`ISSUE_WIDTH-1];
payloadPkt                      rrPacket       [0:`ISSUE_WIDTH-1];

always_comb
begin
    int i;
    for (i = 0; i < `DISPATCH_WIDTH; i++)
    begin
        phyDest[i]     = coreTop.phyDest[i];
        iqFreeEntry[i] = coreTop.issueq.freeEntry[i];
    end

    for (i = 0; i < `ISSUE_WIDTH; i++)
    begin
        iqFreedEntry[i] = coreTop.issueq.freedEntry[i];
        iqGrantedEntry[i] = coreTop.issueq.grantedEntry[i];
        rrPacket[i]     = coreTop.rrPacket[i];
    end
end

/* Prints issue queue related signals and latch values. */
always_ff @(posedge clk)
begin: ISSUEQ
  int i;

    if (PRINT)
    begin
        $fwrite(fd5, "------------------------------------------------------\n");
        $fwrite(fd5, "Cycle: %0d  Commit: %0d\n\n\n",CYCLE_COUNT, COMMIT_COUNT);

`ifdef DYNAMIC_CONFIG
        $fwrite(fd7, "dispatchLaneActive_i: %x\n",
        coreTop.issueq.dispatchLaneActive_i);

        $fwrite(fd7, "issueLaneActive_i: %x\n",
        coreTop.issueq.issueLaneActive_i);
`endif        

        $fwrite(fd5, "               -- Dispatched Instructions --\n\n");
        
        $fwrite(fd5, "backEndReady_i:          %b\n", coreTop.issueq.backEndReady_i);

        /* iqPacket_i */
        $fwrite(fd5, "iqPacket_i        ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd5, "     [%1d] ", i);

        $fwrite(fd5, "\npc:               ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd5, "%08x ", iqPacket[i].pc);

        $fwrite(fd5, "\nopcode:           ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd5, "      %2x ",  iqPacket[i].opcode);

        $fwrite(fd5, "\nfu:               ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd5, "       %1x ", iqPacket[i].fu);

        $fwrite(fd5, "\nphyDest (V):      ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd5, "  %2x (%d) ", iqPacket[i].phyDest, iqPacket[i].phyDestValid);

        $fwrite(fd5, "\nphySrc1 (V):      ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd5, "  %2x (%d) ", iqPacket[i].phySrc1, iqPacket[i].phySrc1Valid);

        $fwrite(fd5, "\nphySrc2 (V):      ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd5, "  %2x (%d) ", iqPacket[i].phySrc2, iqPacket[i].phySrc2Valid);

        $fwrite(fd5, "\nimmed (V):        ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd5, "%04x (%d) ", iqPacket[i].immed, iqPacket[i].immedValid);

        $fwrite(fd5, "\nisLoad:           ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd5, "       %1x ", iqPacket[i].isLoad);

        $fwrite(fd5, "\nisStore:          ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd5, "       %1x ", iqPacket[i].isStore);

        $fwrite(fd5, "\nldstSize:         ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd5, "       %1x ", iqPacket[i].ldstSize);

        $fwrite(fd5, "\nctiID:            ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd5, "      %2x ", iqPacket[i].ctiID);

        $fwrite(fd5, "\npredNPC:          ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd5, "%08x ", iqPacket[i].predNPC);

        $fwrite(fd5, "\npredDir:          ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd5, "       %1x ", iqPacket[i].predDir);

        $fwrite(fd5, "\nfreeEntry:        ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd5, "     d%2d ", iqFreeEntry[i].id);

        $fwrite(fd5, "\nlsqID:            ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd5, "      %2x ", coreTop.lsqID[i]);

        $fwrite(fd5, "\nalID:             ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd5, "      %2x ", coreTop.alID[i]);

        /* phyDest_i */
        $fwrite(fd5, "\n\nphyDest_i         ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd5, "     [%1d] ", i);

        $fwrite(fd5, "\nreg_id (V):       ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd5, "  %2x (%1x) ", phyDest[i].reg_id, phyDest[i].valid);

        $fwrite(fd5, "\nnewSrc1Ready:     ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd5, "       %b ", coreTop.issueq.newSrc1Ready[i]);
 
        $fwrite(fd5, "\nnewSrc2Ready:     ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd5, "       %b ", coreTop.issueq.newSrc2Ready[i]);

        $fwrite(fd5, "\nrsrTag:        ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
        begin
            $fwrite(fd5, "       %b ",coreTop.issueq.rsrTag[i]);
        end 

        $fwrite(fd5, "\nrsrTag_t:    ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
        begin
            `ifndef DYNAMIC_CONFIG
              $fwrite(fd5, "       %b ",fab_chip.coreTop.issueq.rsr.rsrTag_o[i]);
            `else
            `endif
        end
 
        $fwrite(fd5, "\nISsimple_t:    ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
        begin
            $fwrite(fd5, "       %b ",coreTop.issueq.ISsimple_t[i]);
        end


        /* IQ Freelist */

        $fwrite(fd5, "\n\n               -- IQ Freelist --\n\n");

        $fwrite(fd5, "issueQCount: d%d headPtr: d%d tailPtr: d%d\n",
                coreTop.issueq.issueQfreelist.issueQCount,
                coreTop.issueq.issueQfreelist.headPtr,
                coreTop.issueq.issueQfreelist.tailPtr);


        /* Wakeup */

        $fwrite(fd5, "\n\n               -- Wakeup --\n\n");

        $fwrite(fd5, "phyRegValidVect: %b\n\n", coreTop.issueq.phyRegValidVect);
        
        $fwrite(fd5, "rsrTag (V):      ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
        begin
            $fwrite(fd5, "%2x (%b) ",
                    coreTop.issueq.rsrTag[i][`SIZE_PHYSICAL_LOG:1],
                    coreTop.issueq.rsrTag[i][0]);
        end

        //$fwrite(fd5, "\n\niqValidVect:     %b\n", fab_chip.coreTop.issueq.iqValidVect);
        $fwrite(fd5, "src1MatchVect:   %b\n",     fab_chip.coreTop.issueq.src1MatchVect);
        //$fwrite(fd5, "src1Valid_t1:    %b\n",     fab_chip.coreTop.issueq.src1Valid_t1);
        //$fwrite(fd5, "src1ValidVect:   %b\n",     fab_chip.coreTop.issueq.src1ValidVect);

        //$fwrite(fd5, "\n\niqValidVect:     %b\n", fab_chip.coreTop.issueq.iqValidVect);
        $fwrite(fd5, "src2MatchVect:   %b\n",     fab_chip.coreTop.issueq.src2MatchVect);
        //$fwrite(fd5, "src2Valid_t1:    %b\n",     fab_chip.coreTop.issueq.src2Valid_t1);
        //$fwrite(fd5, "src2ValidVect:   %b\n",     fab_chip.coreTop.issueq.src2ValidVect);


        /* Select */

        $fwrite(fd5, "\n\n               -- Select --\n\n");

        //$fwrite(fd5, "iqValidVect:     %b\n", fab_chip.coreTop.issueq.iqValidVect);
        //$fwrite(fd5, "src1ValidVect:   %b\n", fab_chip.coreTop.issueq.src1ValidVect);
        //$fwrite(fd5, "src2ValidVect:   %b\n", fab_chip.coreTop.issueq.src2ValidVect);
        $fwrite(fd5, "reqVect:         %b\n", fab_chip.coreTop.issueq.reqVect);
        `ifndef DYNAMIC_CONFIG
          $fwrite(fd5, "reqVectFU0:      %b\n", fab_chip.coreTop.issueq.reqVectFU0);
          $fwrite(fd5, "reqVectFU1:      %b\n", fab_chip.coreTop.issueq.reqVectFU1);
          $fwrite(fd5, "reqVectFU2:      %b\n", fab_chip.coreTop.issueq.reqVectFU2);
          `ifdef ISSUE_FOUR_WIDE
            $fwrite(fd5, "reqVectFU3:      %b\n", fab_chip.coreTop.issueq.reqVectFU3);
          `endif
          `ifdef ISSUE_FIVE_WIDE
            $fwrite(fd5, "reqVectFU4:      %b\n", fab_chip.coreTop.issueq.reqVectFU4);
          `endif
        `else
        `endif

        //$fwrite(fd5, "grantedVect:     %b\n", fab_chip.coreTop.issueq.grantedVect);

        /* rrPacket_o */
        $fwrite(fd5, "\nrrPacket_o        ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd5, "     [%1d] ", i);

        $fwrite(fd5, "\npc:               ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd5, "%08x ", rrPacket[i].pc);

        $fwrite(fd5, "\nopcode:           ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd5, "      %2x ",  rrPacket[i].opcode);

        $fwrite(fd5, "\nphyDest:          ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd5, "      %2x ", rrPacket[i].phyDest);

        $fwrite(fd5, "\nphySrc1:          ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd5, "      %2x ", rrPacket[i].phySrc1);

        $fwrite(fd5, "\nphySrc2:          ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd5, "      %2x ", rrPacket[i].phySrc2);

        $fwrite(fd5, "\nimmed:            ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd5, "    %04x ", rrPacket[i].immed);

        $fwrite(fd5, "\nlsqID:            ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd5, "      %2x ", rrPacket[i].lsqID);

        $fwrite(fd5, "\nalID:             ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd5, "      %2x ", rrPacket[i].alID);

        $fwrite(fd5, "\nldstSize:         ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd5, "       %1x ", rrPacket[i].ldstSize);

        $fwrite(fd5, "\nctiID:            ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd5, "      %2x ", rrPacket[i].ctiID);

        $fwrite(fd5, "\npredNPC:          ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd5, "%08x ", rrPacket[i].predNPC);

        $fwrite(fd5, "\npredDir:          ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd5, "       %1x ", rrPacket[i].predDir);

        $fwrite(fd5, "\ngrantedEntry (V): ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd5, "  %2x (%1d) ", iqGrantedEntry[i].id, iqGrantedEntry[i].valid);

        $fwrite(fd5,"\n\n");

        //$fwrite(fd5, "freedVect:       %b\n", fab_chip.coreTop.issueq.freedVect);
        $fwrite(fd5, "freedEntry (V): ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd5, "  %2x (%1d) ", iqFreedEntry[i].id, iqFreedEntry[i].valid);
        
        $fwrite(fd5,"\n");
        /* for (i = 0;i< `NO_OF_COMPLEX; i++) */
        /* $fwrite(fd5,"issue_simple[%x] : %b    ",i,coreTop.issueq.issue_simple[i]); */    
/*
        $fwrite(fd5,"\n\n");
        $fwrite(fd5,"RSR1 (V) :");
        for (i = 0;i < `FU1_LATENCY;i++)
            $fwrite(fd5,"   %2x (%1d) ",coreTop.issueq.rsr.RSR_CALU1[i],coreTop.issueq.rsr.RSR_CALU_VALID1[i]);
        $fwrite(fd5,"\n\n");
        
        $fwrite(fd5,"RSR2 (V) :");
        for (i = 0;i < `FU1_LATENCY;i++)
            $fwrite(fd5,"   %2x (%1d) ",coreTop.issueq.rsr.RSR_CALU2[i],coreTop.issueq.rsr.RSR_CALU_VALID2[i]);
*/
        $fwrite(fd5,"\n\n\n");
    end
end
`endif /* PRINT_EN */


`ifdef PRINT_EN
payloadPkt                      rrPacket_l1    [0:`ISSUE_WIDTH-1];
bypassPkt                       bypassPacket   [0:`ISSUE_WIDTH-1];
/* fuPkt                           exePacket      [0:`ISSUE_WIDTH-1]; */

always_comb
begin
    int i;
    for (i = 0; i < `ISSUE_WIDTH; i++)
    begin
        rrPacket_l1[i]  = coreTop.rrPacket_l1[i];
        bypassPacket[i] = coreTop.bypassPacket[i];
    end
end

/* Prints register read related signals and latch value. */
always_ff @(posedge clk)
begin : REG_READ
    int i;

    if (PRINT)
    begin

        $fwrite(fd6, "------------------------------------------------------\n");
        $fwrite(fd6, "Cycle: %0d  Commit: %0d\n\n",CYCLE_COUNT, COMMIT_COUNT);

        $fwrite(fd6, "               -- rrPacket_i --\n");

        /* rrPacket_i */
        $fwrite(fd6, "\nrrPacket_i        ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd6, "     [%1d] ", i);

        $fwrite(fd6, "\npc:               ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd6, "%08x ", rrPacket_l1[i].pc);

        $fwrite(fd6, "\nopcode:           ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd6, "      %2x ",  rrPacket_l1[i].opcode);

        $fwrite(fd6, "\nphyDest:          ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd6, "      %2x ", rrPacket_l1[i].phyDest);

        $fwrite(fd6, "\nphySrc1:          ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd6, "      %2x ", rrPacket_l1[i].phySrc1);

        $fwrite(fd6, "\nphySrc2:          ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd6, "      %2x ", rrPacket_l1[i].phySrc2);

        $fwrite(fd6, "\nimmed:            ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd6, "    %04x ", rrPacket_l1[i].immed);

        $fwrite(fd6, "\nlsqID:            ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd6, "      %2x ", rrPacket_l1[i].lsqID);

        $fwrite(fd6, "\nalID:             ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd6, "      %2x ", rrPacket_l1[i].alID);

        /* $fwrite(fd6, "\nldstSize:         "); */
        /* for (i = 0; i < `ISSUE_WIDTH; i++) */
        /*     $fwrite(fd6, "       %1x ", rrPacket_l1[i].ldstSize); */

        $fwrite(fd6, "\nctiID:            ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd6, "      %2x ", rrPacket_l1[i].ctiID);

        $fwrite(fd6, "\npredNPC:          ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd6, "%08x ", rrPacket_l1[i].predNPC);

        $fwrite(fd6, "\npredDir:          ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd6, "       %1x ", rrPacket_l1[i].predDir);

        $fwrite(fd6, "\nvalid:            ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd6, "       %1x ", rrPacket_l1[i].valid);


        $fwrite(fd6, "\n\n               -- bypassPacket_i --\n");

        /* rrPacket_i */
        $fwrite(fd6, "\nbypassPacket_i    ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd6, "     [%1d] ", i);

        $fwrite(fd6, "\ntag:              ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd6, "      %2x ", bypassPacket[i].tag);

        $fwrite(fd6, "\ndata:             ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd6, "%08x ",  bypassPacket[i].data);

        $fwrite(fd6, "\nvalid:            ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd6, "       %1x ", bypassPacket[i].valid);


        $fwrite(fd6, "\n\n               -- exePacket_o --\n");

        /* rrPacket_i */
        $fwrite(fd6, "\nexePacket_o       ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd6, "     [%1d] ", i);

        $fwrite(fd6, "\npc:               ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd6, "%08x ", exePacket[i].pc);

        $fwrite(fd6, "\nopcode:           ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd6, "      %2x ",  exePacket[i].opcode);

        $fwrite(fd6, "\nphyDest:          ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd6, "      %2x ", exePacket[i].phyDest);

        $fwrite(fd6, "\nphySrc1:          ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd6, "      %2x ", exePacket[i].phySrc1);

        $fwrite(fd6, "\nsrc1Data:         ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd6, "%08x ", exePacket[i].src1Data);

        $fwrite(fd6, "\nphySrc2:          ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd6, "      %2x ", exePacket[i].phySrc2);

        $fwrite(fd6, "\nsrc2Data:         ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd6, "%08x ", exePacket[i].src2Data);

        $fwrite(fd6, "\nimmed:            ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd6, "    %04x ", exePacket[i].immed);

        $fwrite(fd6, "\nlsqID:            ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd6, "      %2x ", exePacket[i].lsqID);

        $fwrite(fd6, "\nalID:             ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd6, "      %2x ", exePacket[i].alID);

        /* $fwrite(fd6, "\nldstSize:         "); */
        /* for (i = 0; i < `ISSUE_WIDTH; i++) */
        /*     $fwrite(fd6, "       %1x ", exePacket[i].ldstSize); */

        $fwrite(fd6, "\nctiID:            ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd6, "      %2x ", exePacket[i].ctiID);

        $fwrite(fd6, "\npredNPC:          ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd6, "%08x ", exePacket[i].predNPC);

        $fwrite(fd6, "\npredDir:          ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd6, "       %1x ", exePacket[i].predDir);

        $fwrite(fd6, "\nvalid:            ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd6, "       %1x ", exePacket[i].valid);

        $fwrite(fd6, "\n\n\n");

    end
end
`endif // PRINT_EN


`ifdef PRINT_EN
reg  [`SIZE_PHYSICAL_LOG-1:0]               src1Addr_byte0 [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]               src1Addr_byte1 [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]               src1Addr_byte2 [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]               src1Addr_byte3 [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]               src2Addr_byte0 [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]               src2Addr_byte1 [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]               src2Addr_byte2 [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]               src2Addr_byte3 [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]               destAddr_byte0 [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]               destAddr_byte1 [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]               destAddr_byte2 [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]               destAddr_byte3 [0:`ISSUE_WIDTH-1];

always_comb
begin
    int i, j;
    for (i = 0; i < `ISSUE_WIDTH; i++)
    begin
        for (j = 0; j < `SIZE_PHYSICAL_TABLE; j++)
        begin
            if (coreTop.registerfile.src1Addr_byte0[i][j])
            begin
                src1Addr_byte0[i]              = j;
            end

            if (coreTop.registerfile.src1Addr_byte1[i][j])
            begin
                src1Addr_byte1[i]              = j;
            end

            if (coreTop.registerfile.src1Addr_byte2[i][j])
            begin
                src1Addr_byte2[i]              = j;
            end

            if (coreTop.registerfile.src1Addr_byte3[i][j])
            begin
                src1Addr_byte3[i]              = j;
            end


            if (coreTop.registerfile.src2Addr_byte0[i][j])
            begin
                src2Addr_byte0[i]              = j;
            end

            if (coreTop.registerfile.src2Addr_byte1[i][j])
            begin
                src2Addr_byte1[i]              = j;
            end

            if (coreTop.registerfile.src2Addr_byte2[i][j])
            begin
                src2Addr_byte2[i]              = j;
            end

            if (coreTop.registerfile.src2Addr_byte3[i][j])
            begin
                src2Addr_byte3[i]              = j;
            end


            if (coreTop.registerfile.destAddr_byte0[i][j])
            begin
                destAddr_byte0[i]              = j;
            end

            if (coreTop.registerfile.destAddr_byte1[i][j])
            begin
                destAddr_byte1[i]              = j;
            end

            if (coreTop.registerfile.destAddr_byte2[i][j])
            begin
                destAddr_byte2[i]              = j;
            end

            if (coreTop.registerfile.destAddr_byte3[i][j])
            begin
                destAddr_byte3[i]              = j;
            end
        end
    end
end


/* Prints register read related signals and latch value. */
always_ff @(posedge clk)
begin : PHY_REG_FILE
    int i;

    if (PRINT)
    begin

        $fwrite(fd23, "------------------------------------------------------\n");
        $fwrite(fd23, "Cycle: %0d  Commit: %0d\n\n",CYCLE_COUNT, COMMIT_COUNT);

        $fwrite(fd23, "               -- Read --\n");

        /* Read */
        $fwrite(fd23, "\n                  ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd23, "     [%1d] ", i);

        $fwrite(fd23, "\nsrc1Addr_byte0:   ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd23, "      %02x ", src1Addr_byte0[i]);

        $fwrite(fd23, "\nsrc1Data_byte0:   ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd23, "      %02x ", coreTop.registerfile.src1Data_byte0_o[i]);

        $fwrite(fd23, "\n\nsrc1Addr_byte1:   ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd23, "      %02x ", src1Addr_byte1[i]);

        $fwrite(fd23, "\nsrc1Data_byte1:   ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd23, "      %02x ", coreTop.registerfile.src1Data_byte1_o[i]);

        $fwrite(fd23, "\n\nsrc1Addr_byte2:   ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd23, "      %02x ", src1Addr_byte2[i]);

        $fwrite(fd23, "\nsrc1Data_byte2:   ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd23, "      %02x ", coreTop.registerfile.src1Data_byte2_o[i]);

        $fwrite(fd23, "\n\nsrc1Addr_byte3:   ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd23, "      %02x ", src1Addr_byte3[i]);

        $fwrite(fd23, "\nsrc1Data_byte3:   ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd23, "      %02x ", coreTop.registerfile.src1Data_byte3_o[i]);


        $fwrite(fd23, "\n\nsrc2Addr_byte0:   ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd23, "      %02x ", src2Addr_byte0[i]);

        $fwrite(fd23, "\nsrc2Data_byte0:   ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd23, "      %02x ", coreTop.registerfile.src2Data_byte0_o[i]);

        $fwrite(fd23, "\n\nsrc2Addr_byte1:   ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd23, "      %02x ", src2Addr_byte1[i]);

        $fwrite(fd23, "\nsrc2Data_byte1:   ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd23, "      %02x ", coreTop.registerfile.src2Data_byte1_o[i]);

        $fwrite(fd23, "\n\nsrc2Addr_byte2:   ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd23, "      %02x ", src2Addr_byte2[i]);

        $fwrite(fd23, "\nsrc2Data_byte2:   ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd23, "      %02x ", coreTop.registerfile.src2Data_byte2_o[i]);

        $fwrite(fd23, "\n\nsrc2Addr_byte3:   ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd23, "      %02x ", src2Addr_byte3[i]);

        $fwrite(fd23, "\nsrc2Data_byte3:   ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd23, "      %02x ", coreTop.registerfile.src2Data_byte3_o[i]);

        $fwrite(fd23, "\n\n\n               -- Write --\n");

        /* Write */
        $fwrite(fd23, "\n                  ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd23, "     [%1d] ", i);

        $fwrite(fd23, "\ndestAddr_byte0:   ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd23, "      %02x ", destAddr_byte0[i]);

        $fwrite(fd23, "\ndestData_byte0:   ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd23, "      %02x ", coreTop.registerfile.destData_byte0[i]);

        $fwrite(fd23, "\ndestWe_byte0:     ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd23, "       %1x ", coreTop.registerfile.destWe_byte0[i]);

        $fwrite(fd23, "\n\ndestAddr_byte1:   ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd23, "      %02x ", destAddr_byte1[i]);

        $fwrite(fd23, "\ndestData_byte1:   ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd23, "      %02x ", coreTop.registerfile.destData_byte1[i]);

        $fwrite(fd23, "\ndestWe_byte1:     ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd23, "       %1x ", coreTop.registerfile.destWe_byte1[i]);

        $fwrite(fd23, "\n\ndestAddr_byte2:   ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd23, "      %02x ", destAddr_byte2[i]);

        $fwrite(fd23, "\ndestData_byte2:   ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd23, "      %02x ", coreTop.registerfile.destData_byte2[i]);

        $fwrite(fd23, "\ndestWe_byte2:     ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd23, "       %1x ", coreTop.registerfile.destWe_byte2[i]);

        $fwrite(fd23, "\n\ndestAddr_byte3:   ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd23, "      %02x ", destAddr_byte3[i]);

        $fwrite(fd23, "\ndestData_byte3:   ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd23, "      %02x ", coreTop.registerfile.destData_byte3[i]);

        $fwrite(fd23, "\ndestWe_byte3:     ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd23, "       %1x ", coreTop.registerfile.destWe_byte3[i]);

        $fwrite(fd23, "\n\n\n");

    end
end
`endif // PRINT_EN


`ifdef PRINT_EN
/* Prints functional units */
fuPkt                           exePacket_l1   [0:`ISSUE_WIDTH-1];
wbPkt                           wbPacket       [0:`ISSUE_WIDTH-1];
reg  [31:0]                     src1Data       [0:`ISSUE_WIDTH-1];
reg  [31:0]                     src2Data       [0:`ISSUE_WIDTH-1];

always_comb
begin
    int i;

    exePacket_l1[0]   = coreTop.exePipe0.exePacket_l1;
    wbPacket[0]       = coreTop.wbPacket;
    src1Data[0]       = coreTop.exePipe0.execute.src1Data;
    src2Data[0]       = coreTop.exePipe0.execute.src2Data;

    exePacket_l1[1]   = coreTop.exePipe1.exePacket_l1;
    wbPacket[1]       = coreTop.exePipe1.wbPacket;
    src1Data[1]       = coreTop.exePipe1.execute.src1Data;
    src2Data[1]       = coreTop.exePipe1.execute.src2Data;

    exePacket_l1[2]   = coreTop.exePipe2.exePacket_l1;
    wbPacket[2]       = coreTop.exePipe2.wbPacket;
    src1Data[2]       = coreTop.exePipe2.execute.src1Data;
    src2Data[2]       = coreTop.exePipe2.execute.src2Data;


`ifdef ISSUE_FOUR_WIDE
    exePacket_l1[3]   = coreTop.exePipe3.exePacket_l1;
    wbPacket[3]       = coreTop.exePipe3.wbPacket;
    src1Data[3]       = coreTop.exePipe3.execute.src1Data;
    src2Data[3]       = coreTop.exePipe3.execute.src2Data;
`endif

`ifdef ISSUE_FIVE_WIDE
    exePacket_l1[4]   = coreTop.exePipe4.exePacket_l1;
    wbPacket[4]       = coreTop.exePipe4.wbPacket;
    src1Data[4]       = coreTop.exePipe4.execute.src1Data;
    src2Data[4]       = coreTop.exePipe4.execute.src2Data;
`endif

`ifdef ISSUE_SIX_WIDE
    exePacket_l1[5]   = coreTop.exePipe5.exePacket_l1;
    wbPacket[5]       = coreTop.exePipe5.wbPacket;
    src1Data[5]       = coreTop.exePipe5.execute.src1Data;
    src2Data[5]       = coreTop.exePipe5.execute.src2Data;
`endif

`ifdef ISSUE_SEVEN_WIDE
    exePacket_l1[6]   = coreTop.exePipe6.exePacket_l1;
    wbPacket[6]       = coreTop.exePipe6.wbPacket;
    src1Data[6]       = coreTop.exePipe6.execute.src1Data;
    src2Data[6]       = coreTop.exePipe6.execute.src2Data;
`endif

end


always_ff @(posedge clk)
begin : EXE
    int i;

    if (PRINT)
    begin

        $fwrite(fd13, "------------------------------------------------------\n");
        $fwrite(fd13, "Cycle: %0d  Commit: %0d\n\n", CYCLE_COUNT, COMMIT_COUNT);


        $fwrite(fd13, "               -- exePacket_i --\n");

        /* exePacket_l1_i */
        $fwrite(fd13, "\nexePacket_i       ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd13, "     [%1d] ", i);

        $fwrite(fd13, "\npc:               ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd13, "%08x ", exePacket_l1[i].pc);

        $fwrite(fd13, "\nopcode:           ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd13, "      %2x ",  exePacket_l1[i].opcode);

        $fwrite(fd13, "\nphyDest:          ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd13, "      %2x ", exePacket_l1[i].phyDest);

        $fwrite(fd13, "\nphySrc1:          ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd13, "      %2x ", exePacket_l1[i].phySrc1);

        $fwrite(fd13, "\nsrc1Data:         ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd13, "%08x ", exePacket_l1[i].src1Data);

        $fwrite(fd13, "\nphySrc2:          ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd13, "      %2x ", exePacket_l1[i].phySrc2);

        $fwrite(fd13, "\nsrc2Data:         ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd13, "%08x ", exePacket_l1[i].src2Data);

        $fwrite(fd13, "\nimmed:            ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd13, "    %04x ", exePacket_l1[i].immed);

        $fwrite(fd13, "\nlsqID:            ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd13, "      %2x ", exePacket_l1[i].lsqID);

        $fwrite(fd13, "\nalID:             ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd13, "      %2x ", exePacket_l1[i].alID);

        $fwrite(fd13, "\nctiID:            ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd13, "      %2x ", exePacket_l1[i].ctiID);

        $fwrite(fd13, "\npredNPC:          ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd13, "%08x ", exePacket_l1[i].predNPC);

        $fwrite(fd13, "\npredDir:          ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd13, "       %1x ", exePacket_l1[i].predDir);

        $fwrite(fd13, "\nvalid:            ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd13, "       %1x ", exePacket_l1[i].valid);


        $fwrite(fd13, "\n\n               -- bypassPacket_i --\n");

        /* rrPacket_i */
        $fwrite(fd13, "\nbypassPacket_i    ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd13, "     [%1d] ", i);

        $fwrite(fd13, "\ntag:              ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd13, "      %2x ", bypassPacket[i].tag);

        $fwrite(fd13, "\ndata:             ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd13, "%8x ",  bypassPacket[i].data);

        $fwrite(fd13, "\nvalid:            ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd13, "       %1x ", bypassPacket[i].valid);


        $fwrite(fd13, "\n\nsrc1Data:         ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd13, "%08x ", src1Data[i]);

        $fwrite(fd13, "\nsrc2Data:         ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd13, "%08x ", src2Data[i]);


        $fwrite(fd13, "\n\n               -- wbPacket_o --\n");

        /* wbPacket_i */
        $fwrite(fd13, "\nwbPacket_i        ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd13, "     [%1d] ", i);

        $fwrite(fd13, "\npc:               ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd13, "%08x ", wbPacket[i].pc);

        $fwrite(fd13, "\nflags:            ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd13, "      %2x ",  wbPacket[i].flags);

        $fwrite(fd13, "\nphyDest:          ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd13, "      %2x ", wbPacket[i].phyDest);

        $fwrite(fd13, "\ndestData:         ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd13, "%08x ", wbPacket[i].destData);

        $fwrite(fd13, "\nalID:             ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd13, "      %2x ", wbPacket[i].alID);

        $fwrite(fd13, "\nnextPC:           ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd13, "%08x ", wbPacket[i].nextPC);

        $fwrite(fd13, "\nctrlType:         ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd13, "      %2x ", wbPacket[i].ctrlType);

        $fwrite(fd13, "\nctrlDir:          ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd13, "       %x ", wbPacket[i].ctrlDir);

        $fwrite(fd13, "\nctiID:            ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd13, "      %2x ", wbPacket[i].ctiID);

        $fwrite(fd13, "\npredDir:          ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd13, "       %1x ", wbPacket[i].predDir);

        $fwrite(fd13, "\nvalid:            ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd13, "       %1x ", wbPacket[i].valid);

        $fwrite(fd13, "\n\n\n");

    end
end
`endif // PRINT_EN


`ifdef PRINT_EN
/* Prints load-store related signals and latch value. */

memPkt                         memPacket;
memPkt                         replayPacket;

wbPkt                          lsuWbPacket;
ldVioPkt                       ldVioPacket;

always_comb
begin
    memPacket      = fab_chip.coreTop.memPacket;
    replayPacket   = fab_chip.coreTop.lsu.datapath.replayPacket;
    lsuWbPacket    = fab_chip.coreTop.wbPacket;
    ldVioPacket    = fab_chip.coreTop.ldVioPacket;
end


always @(posedge clk)
begin:LSU
    reg [`SIZE_LSQ_LOG-1:0]               lastMatch;
  reg [2+`SIZE_PC+`SIZE_RMT_LOG+2*`SIZE_PHYSICAL_LOG:0] val;
  int i;

  if (PRINT)
  begin
        $fwrite(fd10, "------------------------------------------------------\n");
        $fwrite(fd10, "Cycle: %0d  Commit: %0d\n\n\n",CYCLE_COUNT, COMMIT_COUNT);

        $fwrite(fd10, "               -- Dispatched Instructions --\n\n");
        
        $fwrite(fd10, "ldqHead_i:      %x\n", coreTop.lsu.datapath.stx_path.ldqHead_i);
        $fwrite(fd10, "ldqTail_i:      %x\n", coreTop.lsu.datapath.stx_path.ldqTail_i);
        $fwrite(fd10, "stqHead_i:      %x\n", coreTop.lsu.datapath.ldx_path.stqHead_i);
        $fwrite(fd10, "stqTail_i:      %x\n", coreTop.lsu.datapath.ldx_path.stqTail_i);
        $fwrite(fd10, "backEndReady_i: %b\n", coreTop.lsu.backEndReady_i);
        $fwrite(fd10, "recoverFlag_i : %b\n", coreTop.lsu.recoverFlag_i);

        /* lsqPacket_i */
        $fwrite(fd10, "lsqPacket_i       ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd10, "     [%1d] ", i);

        $fwrite(fd10, "\npredLoadVio:      ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd10, "       %1x ", lsqPacket[i].predLoadVio);

        $fwrite(fd10, "\nisLoad:           ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd10, "       %1x ", lsqPacket[i].isLoad);

        $fwrite(fd10, "\nisStore:          ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd10, "       %1x ", lsqPacket[i].isStore);

        $fwrite(fd10, "\nlsqID:            ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd10, "      %2x ", coreTop.lsqID[i]);

        $fwrite(fd10, "\nldqID:            ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd10, "      %2x ", coreTop.lsu.ldqID[i]);

        $fwrite(fd10, "\nstqID:            ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd10, "      %2x ", coreTop.lsu.stqID[i]);

        $fwrite(fd10, "\nnextLd:            ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd10, "      %x ", coreTop.lsu.datapath.nextLdIndex_i[i]);

        $fwrite(fd10, "\nlastSt:            ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd10, "      %x ", coreTop.lsu.datapath.lastStIndex_i[i]);

        $fwrite(fd10, "\n\n\n               -- Executed Instructions --\n\n");
        
        /* memPacket_i */
        $fwrite(fd10, "memPacket_i       ");
        for (i = 0; i < 1; i++)
            $fwrite(fd10, "     [%1d] ", i);

        $fwrite(fd10, "\nPC:            ");
        for (i = 0; i < 1; i++)
            $fwrite(fd10, "      %x  ", memPacket.pc);

        $fwrite(fd10, "\nflags:            ");
        for (i = 0; i < 1; i++)
            $fwrite(fd10, "      %2x ", memPacket.flags);

        $fwrite(fd10, "\nldstSize:         ");
        for (i = 0; i < 1; i++)
            $fwrite(fd10, "       %1x ", memPacket.ldstSize);

        $fwrite(fd10, "\nphyDest:          ");
        for (i = 0; i < 1; i++)
            $fwrite(fd10, "      %2x ", memPacket.phyDest);

        $fwrite(fd10, "\naddress:          ");
        for (i = 0; i < 1; i++)
            $fwrite(fd10, "%08x ",     memPacket.address);

        $fwrite(fd10, "\nsrc2Data:         ");
        for (i = 0; i < 1; i++)
            $fwrite(fd10, "%08x ",     memPacket.src2Data);

        $fwrite(fd10, "\nlsqID:            ");
        for (i = 0; i < 1; i++)
            $fwrite(fd10, "      %2x ", memPacket.lsqID);

        $fwrite(fd10, "\nalID:             ");
        for (i = 0; i < 1; i++)
            $fwrite(fd10, "      %2x ", memPacket.alID);

        $fwrite(fd10, "\nvalid:            ");
        for (i = 0; i < 1; i++)
            $fwrite(fd10, "       %1x ", memPacket.valid);

        /* replayPacket_i */
        $fwrite(fd10, "\n\nreplayPacket       ");
        for (i = 0; i < 1; i++)
            $fwrite(fd10, "     [%1d] ", i);

        $fwrite(fd10, "\nPC:            ");
        for (i = 0; i < 1; i++)
            $fwrite(fd10, "      %x  ", replayPacket.pc);

        $fwrite(fd10, "\nflags:            ");
        for (i = 0; i < 1; i++)
            $fwrite(fd10, "      %2x ", replayPacket.flags);

        $fwrite(fd10, "\nldstSize:         ");
        for (i = 0; i < 1; i++)
            $fwrite(fd10, "       %1x ", replayPacket.ldstSize);

        $fwrite(fd10, "\nphyDest:          ");
        for (i = 0; i < 1; i++)
            $fwrite(fd10, "      %2x ", replayPacket.phyDest);

        $fwrite(fd10, "\naddress:          ");
        for (i = 0; i < 1; i++)
            $fwrite(fd10, "%08x ",     replayPacket.address);

        $fwrite(fd10, "\nsrc2Data:         ");
        for (i = 0; i < 1; i++)
            $fwrite(fd10, "%08x ",     replayPacket.src2Data);

        $fwrite(fd10, "\nlsqID:            ");
        for (i = 0; i < 1; i++)
            $fwrite(fd10, "      %2x ", replayPacket.lsqID);

        $fwrite(fd10, "\nalID:             ");
        for (i = 0; i < 1; i++)
            $fwrite(fd10, "      %2x ", replayPacket.alID);

        $fwrite(fd10, "\nvalid:            ");
        for (i = 0; i < 1; i++)
            $fwrite(fd10, "       %1x ", replayPacket.valid);

        $fwrite(fd10, "\n\n\nlastSt:            ");
        for (i = 0; i < 1; i++)
            $fwrite(fd10, "       %x ", coreTop.lsu.datapath.ldx_path.LD_DISAMBIGUATION.lastSt);

        /* lsuWbPacket_o */
        $fwrite(fd10, "\n\nlsuWbPacket_o        ");
        for (i = 0; i < 1; i++)
            $fwrite(fd10, "     [%1d] ", i);

        $fwrite(fd10, "\npc:               ");
        for (i = 0; i < 1; i++)
            $fwrite(fd10, "%08x ", lsuWbPacket.pc);

        $fwrite(fd10, "\nflags:            ");
        for (i = 0; i < 1; i++)
            $fwrite(fd10, "      %2x ", lsuWbPacket.flags);

        $fwrite(fd10, "\nphyDest:          ");
        for (i = 0; i < 1; i++)
            $fwrite(fd10, "      %2x ", lsuWbPacket.phyDest);

        $fwrite(fd10, "\ndestData:         ");
        for (i = 0; i < 1; i++)
            $fwrite(fd10, "%08x ",     lsuWbPacket.destData);

        $fwrite(fd10, "\nalID:             ");
        for (i = 0; i < 1; i++)
            $fwrite(fd10, "      %2x ", lsuWbPacket.alID);

        $fwrite(fd10, "\nvalid:            ");
        for (i = 0; i < 1; i++)
            $fwrite(fd10, "       %1x ", lsuWbPacket.valid);


        $fwrite(fd10, "\n\n\n               -- LD Disambiguation (LDX) --\n\n");

        $fwrite(fd10, "stqCount_i:  %x\n",
                fab_chip.coreTop.lsu.datapath.ldx_path.stqCount_i);

        $fwrite(fd10, "stqAddrValid:  %b\n",
                coreTop.lsu.datapath.ldx_path.stqAddrValid);

        $fwrite(fd10, "stqValid:  %b\n",
                coreTop.lsu.control.stqValid);

        $fwrite(fd10, "vulnerableStVector_t1:  %b\n",
                coreTop.lsu.datapath.ldx_path.LD_DISAMBIGUATION.vulnerableStVector_t1);

        $fwrite(fd10, "vulnerableStVector_t2:  %b\n",
                coreTop.lsu.datapath.ldx_path.LD_DISAMBIGUATION.vulnerableStVector_t2);

        $fwrite(fd10, "vulnerableStVector:     %b\n",
                fab_chip.coreTop.lsu.datapath.ldx_path.LD_DISAMBIGUATION.vulnerableStVector);

`ifndef DYNAMIC_CONFIG                
        $fwrite(fd10, "addr1MatchVector:       %b\n",
                fab_chip.coreTop.lsu.datapath.ldx_path.LD_DISAMBIGUATION.addr1MatchVector);

        $fwrite(fd10, "addr2MatchVector:       %b\n",
                fab_chip.coreTop.lsu.datapath.ldx_path.LD_DISAMBIGUATION.addr2MatchVector);
`else                
        $fwrite(fd10, "addr1MatchVector:       %b\n",
                coreTop.lsu.datapath.ldx_path.LD_DISAMBIGUATION.addr1MatchVector);

        $fwrite(fd10, "addr2MatchVector:       %b\n",
                fab_chip.coreTop.lsu.datapath.ldx_path.addr2MatchVector);
`endif

        $fwrite(fd10, "sizeMismatchVector:     %b\n",
                coreTop.lsu.datapath.ldx_path.LD_DISAMBIGUATION.sizeMismatchVector);

        $fwrite(fd10, "forwardVector1:         %b\n",
                coreTop.lsu.datapath.ldx_path.LD_DISAMBIGUATION.forwardVector1);

        $fwrite(fd10, "forwardVector2:         %b\n\n",
                coreTop.lsu.datapath.ldx_path.LD_DISAMBIGUATION.forwardVector2);


`ifndef DYNAMIC_CONFIG        
        lastMatch = fab_chip.coreTop.lsu.datapath.ldx_path.LD_DISAMBIGUATION.lastMatch;
`else
        lastMatch = fab_chip.coreTop.lsu.datapath.ldx_path.lastMatch;
`endif
        $fwrite(fd10, "stqHit:         %b\n", fab_chip.coreTop.lsu.datapath.ldx_path.stqHit);
        $fwrite(fd10, "lastMatch:      %x\n", lastMatch);
        $fwrite(fd10, "partialStMatch: %b\n", coreTop.lsu.datapath.ldx_path.partialStMatch);
        $fwrite(fd10, "disambigStall:  %b\n\n", coreTop.lsu.datapath.ldx_path.LD_DISAMBIGUATION.disambigStall);

        $fwrite(fd10, "loadDataValid_o: %b\n", fab_chip.coreTop.lsu.datapath.ldx_path.loadDataValid_o);
        $fwrite(fd10, "dcacheData:  %08x\n", fab_chip.coreTop.lsu.datapath.ldx_path.dcacheData);
`ifndef DYNAMIC_CONFIG        
        $fwrite(fd10, "stqData[%d]: %08x\n", lastMatch, fab_chip.coreTop.lsu.datapath.ldx_path.stqData[lastMatch]);
`else        
        $fwrite(fd10, "stqData[%d]: %08x\n", lastMatch, fab_chip.coreTop.lsu.datapath.ldx_path.stqHitData);
`endif
        $fwrite(fd10, "loadData_t:  %08x\n", fab_chip.coreTop.lsu.datapath.ldx_path.loadData_t);
        $fwrite(fd10, "loadData_o:  %08x\n", fab_chip.coreTop.lsu.datapath.ldx_path.loadData_o);
        

        $fwrite(fd10, "\n\n\n               -- LD Violation (STX) --\n\n");

        $fwrite(fd10, "ldqAddrValid:           %b\n",
                coreTop.lsu.datapath.stx_path.ldqAddrValid);

        $fwrite(fd10, "ldqWriteBack:           %b\n",
                coreTop.lsu.datapath.stx_path.ldqWriteBack);

        $fwrite(fd10, "vulnerableLdVector_t1:  %b\n",
                coreTop.lsu.datapath.stx_path.LD_VIOLATION.vulnerableLdVector_t1);

        $fwrite(fd10, "vulnerableLdVector_t2:  %b\n",
                coreTop.lsu.datapath.stx_path.LD_VIOLATION.vulnerableLdVector_t2);

        $fwrite(fd10, "vulnerableLdVector_t3:  %b\n",
                coreTop.lsu.datapath.stx_path.LD_VIOLATION.vulnerableLdVector_t3);

        $fwrite(fd10, "vulnerableLdVector_t4:  %b\n",
                coreTop.lsu.datapath.stx_path.LD_VIOLATION.vulnerableLdVector_t4);

        $fwrite(fd10, "matchVector_st:         %b\n",
                coreTop.lsu.datapath.stx_path.LD_VIOLATION.matchVector_st);

`ifndef DYNAMIC_CONFIG
        $fwrite(fd10, "matchVector_st1:        %b\n",
                fab_chip.coreTop.lsu.datapath.stx_path.LD_VIOLATION.matchVector_st1);
`else                
        $fwrite(fd10, "matchVector_st1:        %b\n",
                fab_chip.coreTop.lsu.datapath.stx_path.matchVector_st1);
`endif

        $fwrite(fd10, "matchVector_st2:        %b\n",
                coreTop.lsu.datapath.stx_path.LD_VIOLATION.matchVector_st2);

        $fwrite(fd10, "matchVector_st3:        %b\n",
                coreTop.lsu.datapath.stx_path.LD_VIOLATION.matchVector_st3);

        $fwrite(fd10, "violateVector:          %b\n",
                coreTop.lsu.datapath.stx_path.LD_VIOLATION.violateVector);


        $fwrite(fd10, "nextLoad:       %x\n", fab_chip.coreTop.lsu.datapath.stx_path.LD_VIOLATION.nextLoad);
`ifndef DYNAMIC_CONFIG
        $fwrite(fd10, "firstMatch:     %x\n", fab_chip.coreTop.lsu.datapath.stx_path.LD_VIOLATION.firstMatch);
`else                
        $fwrite(fd10, "firstMatch:     %x\n", fab_chip.coreTop.lsu.datapath.stx_path.firstMatch);
`endif
        $fwrite(fd10, "agenLdqMatch:   %b\n", fab_chip.coreTop.lsu.datapath.stx_path.LD_VIOLATION.agenLdqMatch);
        $fwrite(fd10, "violateLdValid: %x\n", fab_chip.coreTop.lsu.datapath.stx_path.violateLdValid);
        $fwrite(fd10, "violateLdALid:  %x\n", fab_chip.coreTop.lsu.datapath.stx_path.violateLdALid);
        
        $fwrite(fd10, "\n\n\n               -- Committed Instructions --\n\n");
        
        $fwrite(fd10, "stqHead_i:   %d\n", coreTop.lsu.datapath.ldx_path.stqHead_i);
        $fwrite(fd10, "commitSt_i:  %x\n", coreTop.lsu.datapath.ldx_path.commitSt_i);
        $fwrite(fd10, "stCommitAddr:  %x\n", coreTop.lsu.datapath.ldx_path.stCommitAddr);
        $fwrite(fd10, "stCommitData:  %x\n", coreTop.lsu.datapath.ldx_path.stCommitData);
        $fwrite(fd10, "commitStCount:  %x", coreTop.lsu.control.commitStCount);
        $fwrite(fd10, "commitStIndex: ");
        for (i = 0; i < 4; i++)
        begin
          $fwrite(fd10, "  %x", coreTop.lsu.control.commitStIndex[i]);
        end

        for (i = 0; i < `SIZE_LSQ; i++)
        begin
`ifndef DYNAMIC_CONFIG          
            $fwrite(fd10, "stqAddr[%0d]: %08x\n", i, {fab_chip.coreTop.lsu.datapath.ldx_path.stqAddr1[i],
                                                      fab_chip.coreTop.lsu.datapath.ldx_path.stqAddr2[i]});
`endif                                                      
        end
        
        for (i = 0; i < `SIZE_LSQ; i++)
        begin
`ifndef DYNAMIC_CONFIG          
            $fwrite(fd10, "stqData[%0d]: %08x\n", i, fab_chip.coreTop.lsu.datapath.ldx_path.stqData[i]);
`endif
        end

    $fwrite(fd10, "commitLoad_i:  %b\n",
              coreTop.lsu.commitLoad_i);

    $fwrite(fd10, "commitStore_i: %b\n",
              coreTop.lsu.commitStore_i);

    $fwrite(fd10,"\n\n");
  end
end
`endif // 0



`ifdef PRINT_EN
ctrlPkt                         ctrlPacket [0:`ISSUE_WIDTH-1];
commitPkt                       amtPacket [0:`COMMIT_WIDTH-1];

always_comb
begin
    int i;
    for (i = 0; i < `ISSUE_WIDTH; i++)
    begin
        ctrlPacket[i]   = coreTop.ctrlPacket[i];
    end

    for (i = 0; i < `COMMIT_WIDTH; i++)
    begin
        amtPacket[i]   = coreTop.amtPacket[i];
    end
end

always_ff @(posedge clk)
begin: ACTIVE_LIST
    int i;

    if (PRINT)
    begin
        $fwrite(fd7, "------------------------------------------------------\n");
        $fwrite(fd7, "Cycle: %0d  Commit: %0d\n\n\n",CYCLE_COUNT, COMMIT_COUNT);

`ifdef DYNAMIC_CONFIG
        $fwrite(fd7, "dispatchLaneActive_i: %x\n",
        coreTop.activeList.dispatchLaneActive_i);

        $fwrite(fd7, "issueLaneActive_i: %x\n",
        coreTop.activeList.issueLaneActive_i);
`endif        

        $fwrite(fd7, "totalCommit: d%d\n",
        coreTop.activeList.totalCommit);

        $fwrite(fd7, "alCount: d%d\n",
        coreTop.activeList.alCount);

        $fwrite(fd7, "headPtr: %x tailPtr: %x\n",
        coreTop.activeList.headPtr,
        coreTop.activeList.tailPtr);

        $fwrite(fd7, "backEndReady_i: %b\n\n",
        coreTop.activeList.backEndReady_i);

        $fwrite(fd7, "               -- Dispatched Instructions --\n\n");
        
        /* alPacket_i */
        $fwrite(fd7, "\nalPacket_i    ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd7, "     [%1d] ", i);

        $fwrite(fd7, "\npc:           ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd7, "%08x ", alPacket[i].pc);

        $fwrite(fd7, "\nlogDest:      ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd7, "      %2x ", alPacket[i].logDest);

        $fwrite(fd7, "\nphyDest (V):  ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd7, "  %2x (%d) ", alPacket[i].phyDest, alPacket[i].phyDestValid);

        $fwrite(fd7, "\nisLoad:       ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd7, "       %1x ", alPacket[i].isLoad);

        $fwrite(fd7, "\nisStore:      ");
        for (i = 0; i < `DISPATCH_WIDTH; i++)
            $fwrite(fd7, "       %1x ", alPacket[i].isStore);

        $fwrite(fd7, "\n\n\n               -- Executed Instructions --\n");

        $fwrite(fd7, "\nctrlPacket_i      ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd7, "     [%1d] ", i);

        $fwrite(fd7, "\nnextPC:           ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd7, "%08x ", ctrlPacket[i].nextPC);

        $fwrite(fd7, "\nalID:             ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd7, "      %2x ", ctrlPacket[i].alID);

        $fwrite(fd7, "\nflags:            ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd7, "      %2x ", ctrlPacket[i].flags);

        $fwrite(fd7, "\nvalid:            ");
        for (i = 0; i < `ISSUE_WIDTH; i++)
            $fwrite(fd7, "       %1x ", ctrlPacket[i].valid);
        
        
        $fwrite(fd7, "\n\n\n               -- Committing Instructions --\n\n");
        
        $fwrite(fd7, "              ");
        for (i = 0; i < `COMMIT_WIDTH; i++)
            $fwrite(fd7, "     [%1d] ", i);

        $fwrite(fd7, "\nmispredFlag:  "); 
        for (i = 0; i < `COMMIT_WIDTH; i++)
            $fwrite(fd7, "       %b ", coreTop.activeList.mispredFlag[i]);

        $fwrite(fd7, "\nviolateFlag:  ");
        for (i = 0; i < `COMMIT_WIDTH; i++)
            $fwrite(fd7, "       %b ", coreTop.activeList.violateFlag[i]);
        
        $fwrite(fd7, "\nexceptionFlag:");
        for (i = 0; i < `COMMIT_WIDTH; i++)
            $fwrite(fd7, "       %b ", coreTop.activeList.exceptionFlag[i]);

        $fwrite(fd7, "\n\ncommitReady:  ");
        for (i = 0; i < `COMMIT_WIDTH; i++)
            $fwrite(fd7, "       %b ", coreTop.activeList.commitReady[i]);

        $fwrite(fd7, "\ncommitVector: ");
        for (i = 0; i < `COMMIT_WIDTH; i++)
            $fwrite(fd7, "       %b ", coreTop.activeList.commitVector[i]);


        $fwrite(fd7, "\n\namtPacket_o   ");
        for (i = 0; i < `COMMIT_WIDTH; i++)
            $fwrite(fd7, "     [%1d] ", i);

        $fwrite(fd7, "\nlogDest:      ");
        for (i = 0; i < `COMMIT_WIDTH; i++)
            $fwrite(fd7, "      %2x ", amtPacket[i].logDest);

        $fwrite(fd7, "\nphyDest:      ");
        for (i = 0; i < `COMMIT_WIDTH; i++)
            $fwrite(fd7, "      %2x ", amtPacket[i].phyDest);

        $fwrite(fd7, "\nvalid:        ");
        for (i = 0; i < `COMMIT_WIDTH; i++)
            $fwrite(fd7, "       %1x ", amtPacket[i].valid);

        $fwrite(fd7, "\npc:           ");
        for (i = 0; i < `COMMIT_WIDTH; i++)
            $fwrite(fd7, "%08x ", coreTop.activeList.commitPC[i]);

        $fwrite(fd7, "\n\ncommitStore:  ");
        for (i = 0; i < `COMMIT_WIDTH; i++)
            $fwrite(fd7, "       %1x ", coreTop.activeList.commitStore_o[i]);

        $fwrite(fd7, "\ncommitLoad:   ");
        for (i = 0; i < `COMMIT_WIDTH; i++)
            $fwrite(fd7, "       %1x ", coreTop.activeList.commitLoad_o[i]);

        $fwrite(fd7, "\ncommitCti:    ");
        for (i = 0; i < `COMMIT_WIDTH; i++)
            $fwrite(fd7, "       %1x ", coreTop.activeList.commitCti_o[i]);

        $fwrite(fd7,"\n\n");

        
        if (coreTop.activeList.violateFlag_reg)
        begin
            $fwrite(fd7, "violateFlag_reg: %d recoverPC_o: %h\n",
            coreTop.activeList.violateFlag_reg,
            coreTop.activeList.recoverPC_o);
        end

        if (coreTop.activeList.mispredFlag_reg)
        begin
            $fwrite(fd7,"mispredFlag_reg: %d recoverPC_o: %h\n",
            coreTop.activeList.mispredFlag_reg,
            coreTop.activeList.recoverPC_o);
        end

        if (coreTop.activeList.exceptionFlag_reg)
        begin
            $fwrite(fd7,"exceptionFlag_reg: %d exceptionPC_o: %h\n",
            coreTop.activeList.exceptionFlag_reg,
            coreTop.activeList.exceptionPC_o);
        end

        $fwrite(fd7,"\n");
    end
end

`endif



fs2Pkt  [0:`FETCH_WIDTH-1]                   fs2Packet;
fs2Pkt  [0:`FETCH_WIDTH-1]                   fs2Packet_l1;

assign        fs2Packet     = coreTop.fs1fs2.fs2Packet_i;
//assign        fs2Packet_l1  = coreTop.fs1fs2.fs2Packet_o;

decPkt  [0:`FETCH_WIDTH-1]                   decPacket;
decPkt  [0:`FETCH_WIDTH-1]                   decPacket_l1;
renPkt  [0:2*`FETCH_WIDTH-1]                 ibPacket;

assign        decPacket     = coreTop.fs2dec.decPacket_i;
//assign        decPacket_l1  = coreTop.fs2dec.decPacket_o;
assign        ibPacket      = coreTop.decode.ibPacket_o;

renPkt  [0:`DISPATCH_WIDTH-1]                renPacket;
renPkt  [0:`DISPATCH_WIDTH-1]                renPacket_l1;

assign        renPacket     = coreTop.instBufRen.renPacket_i;
assign        renPacket_l1  = coreTop.instBufRen.renPacket_o;


disPkt  [0:`DISPATCH_WIDTH-1]                     disPacket_l1;
iqPkt   [0:`DISPATCH_WIDTH-1]                     iqPacket;
alPkt   [0:`DISPATCH_WIDTH-1]                     alPacket;
lsqPkt  [0:`DISPATCH_WIDTH-1]                     lsqPacket;

//assign        disPacket_l1                = coreTop.renDis.disPacket_o;
assign        iqPacket                    = coreTop.dispatch.iqPacket_o;
assign        alPacket                    = coreTop.dispatch.alPacket_o;
assign        lsqPacket                   = coreTop.lsu.lsqPacket_i;

iqEntryPkt    [0:`ISSUE_WIDTH-1]              iqGrantedEntry;
iqEntryPkt    [0:`ISSUE_WIDTH-1]              iqFreedEntry  ;
iqEntryPkt    [0:`DISPATCH_WIDTH-1]           iqFreeEntry   ;

assign        iqGrantedEntry                = coreTop.issueq.issueQfreelist.grantedEntry_i;
assign        iqFreedEntry                  = coreTop.issueq.issueQfreelist.freedEntry_o;
assign        iqFreeEntry                   = coreTop.issueq.issueQfreelist.freeEntry_o;

payloadPkt                                    iqPldWrPacket [0:`DISPATCH_WIDTH-1];
  assign        iqPldWrPacket[0] = coreTop.issueq.payloadRAM.data0wr_i;
`ifdef DISPATCH_TWO_WIDE
  assign        iqPldWrPacket[1] = coreTop.issueq.payloadRAM.data1wr_i;
`endif
`ifdef DISPATCH_THREE_WIDE
  assign        iqPldWrPacket[2] = coreTop.issueq.payloadRAM.data2wr_i;
`endif
`ifdef DISPATCH_FOUR_WIDE
  assign        iqPldWrPacket[3] = coreTop.issueq.payloadRAM.data3wr_i;
`endif
`ifdef DISPATCH_FIVE_WIDE
  assign        iqPldWrPacket[4] = coreTop.issueq.payloadRAM.data4wr_i;
`endif
`ifdef DISPATCH_SIX_WIDE
  assign        iqPldWrPacket[5] = coreTop.issueq.payloadRAM.data5wr_i;
`endif
`ifdef DISPATCH_SEVEN_WIDE
  assign        iqPldWrPacket[6] = coreTop.issueq.payloadRAM.data6wr_i;
`endif
`ifdef DISPATCH_EIGHT_WIDE
  assign        iqPldWrPacket[7] = coreTop.issueq.payloadRAM.data7wr_i;
`endif


payloadPkt                                    iqPldRdPacket [0:`ISSUE_WIDTH-1];
  assign        iqPldRdPacket[0] = coreTop.issueq.payloadRAM.data0_o;
`ifdef ISSUE_TWO_WIDE
  assign        iqPldRdPacket[1] = coreTop.issueq.payloadRAM.data1_o;
`endif
`ifdef ISSUE_THREE_WIDE
  assign        iqPldRdPacket[2] = coreTop.issueq.payloadRAM.data2_o;
`endif
`ifdef ISSUE_FOUR_WIDE
  assign        iqPldRdPacket[3] = coreTop.issueq.payloadRAM.data3_o;
`endif
`ifdef ISSUE_FIVE_WIDE
  assign        iqPldRdPacket[4] = coreTop.issueq.payloadRAM.data4_o;
`endif
`ifdef ISSUE_SIX_WIDE
  assign        iqPldRdPacket[5] = coreTop.issueq.payloadRAM.data5_o;
`endif
`ifdef ISSUE_SEVEN_WIDE
  assign        iqPldRdPacket[6] = coreTop.issueq.payloadRAM.data6_o;
`endif
`ifdef ISSUE_EIGHT_WIDE
  assign        iqPldRdPacket[7] = coreTop.issueq.payloadRAM.data7_o;
`endif


payloadPkt  [0:`ISSUE_WIDTH-1]                    rrPacket_l1;
bypassPkt   [0:`ISSUE_WIDTH-1]                    bypassPacket;

assign        rrPacket_l1                 = coreTop.iq_regread.rrPacket_o;
assign        bypassPacket                = coreTop.registerfile.bypassPacket_i;

fuPkt                           exePacket      [0:`ISSUE_WIDTH-1];
fuPkt                           exePacket_s    [0:`ISSUE_WIDTH-1];
fuPkt                           exePacket_c    [0:`ISSUE_WIDTH-1];


assign    exePacket[0]      = coreTop.exePipe0.execute.exePacket_i;
assign    exePacket[1]      = coreTop.exePipe1.execute.exePacket_i;
assign    exePacket[2]      = coreTop.exePipe2.execute.exePacket_i;
//assign    exePacket_s[2]    = coreTop.exePipe2.execute.simple_complex.salu.exePacket_i;
//assign    exePacket_c[2]    = coreTop.exePipe2.execute.simple_complex.calu.exePacket_i;

`ifdef ISSUE_FOUR_WIDE
assign    exePacket[3]      = coreTop.exePipe3.execute.exePacket_i;
//assign    exePacket_s[3]    = coreTop.exePipe2.execute.simple_complex.salu.exePacket_i;
//assign    exePacket_c[3]    = coreTop.exePipe2.execute.simple_complex.calu.exePacket_i;
`endif
`ifdef ISSUE_FIVE_WIDE
assign    exePacket[4]      = coreTop.exePipe4.execute.exePacket_i;
`endif
`ifdef ISSUE_SIX_WIDE
assign    exePacket[5]      = coreTop.exePipe5.execute.exePacket_i;
`endif


memPkt                         memPacket;

wbPkt                          lsuWbPacket;
ldVioPkt                       ldVioPacket;

assign    memPacket         = coreTop.exePipe0.memPacket_o;
assign    lsuWbPacket       = coreTop.lsu.wbPacket_o;
assign    ldVioPacket       = coreTop.lsu.ldVioPacket_o;

ctrlPkt     [0:`ISSUE_WIDTH-1]                     ctrlPacket;
commitPkt   [0:`COMMIT_WIDTH-1]                    amtPacket;

assign       ctrlPacket     = coreTop.activeList.ctrlPacket_i;
assign       amtPacket      = coreTop.activeList.amtPacket_o;



alPkt                               dataAl          [0:`COMMIT_WIDTH-1];
wire [`SIZE_EXE_FLAGS-1:0]         ctrlAl          [0:`COMMIT_WIDTH-1];
wire [`COMMIT_WIDTH-1:0]            commitReady;
wire                                violateBit  [0:`COMMIT_WIDTH-1];
reg  [`SIZE_ACTIVELIST_LOG-1:0]     headAddr [0:`COMMIT_WIDTH-1];
reg  [`SIZE_ACTIVELIST_LOG-1:0]     tailAddr [0:`COMMIT_WIDTH-1];

assign dataAl[0] = coreTop.activeList.activeList.data0_o;
assign ctrlAl[0] = coreTop.activeList.ctrlActiveList.data0_o;
assign commitReady[0] = coreTop.activeList.executedActiveList.data0_o;
assign violateBit[0] = coreTop.activeList.ldViolateVector.data0_o;
assign headAddr[0] = coreTop.activeList.activeList.addr0_i;
assign tailAddr[0] = coreTop.activeList.activeList.addr0wr_i;

`ifdef COMMIT_TWO_WIDE
assign dataAl[1] = coreTop.activeList.activeList.data1_o;
assign ctrlAl[1] = coreTop.activeList.ctrlActiveList.data1_o;
assign commitReady[1] = coreTop.activeList.executedActiveList.data1_o;
assign violateBit[1] = coreTop.activeList.ldViolateVector.data1_o;
assign headAddr[1] = coreTop.activeList.activeList.addr1_i;
assign tailAddr[1] = coreTop.activeList.activeList.addr1wr_i;
`endif

`ifdef COMMIT_THREE_WIDE
assign dataAl[2] = coreTop.activeList.activeList.data2_o;
assign ctrlAl[2] = coreTop.activeList.ctrlActiveList.data2_o;
assign commitReady[2] = coreTop.activeList.executedActiveList.data2_o;
assign violateBit[2] = coreTop.activeList.ldViolateVector.data2_o;
assign headAddr[2] = coreTop.activeList.activeList.addr2_i;
assign tailAddr[2] = coreTop.activeList.activeList.addr2wr_i;
`endif

`ifdef COMMIT_FOUR_WIDE
assign dataAl[3] = coreTop.activeList.activeList.data3_o;
assign ctrlAl[3] = coreTop.activeList.ctrlActiveList.data3_o;
assign commitReady[3] = coreTop.activeList.executedActiveList.data3_o;
assign violateBit[3] = coreTop.activeList.ldViolateVector.data3_o;
assign headAddr[3] = coreTop.activeList.activeList.addr3_i;
assign tailAddr[3] = coreTop.activeList.activeList.addr3wr_i;
`endif

reg                                 violateFlag [0:`COMMIT_WIDTH-1];
reg                                 mispredFlag [0:`COMMIT_WIDTH-1];
reg                                 exceptionFlag  [0:`COMMIT_WIDTH-1];

always_comb
begin
	int i;
	for (i = 0; i < `COMMIT_WIDTH; i = i + 1)
	begin
	/* The violate flag is used to mark a load violation.
	 * An instruction with the violate bit set waits until it reaches 
	 * the head of the AL and then causes a recovery without committing. */
		violateFlag[i]    = violateBit[i] && commitReady[i];

	/* The mispredict flag is used to mark a misprediction.
	 * An instruction with the mispredict bit set commits only at 
	 * the head of the AL. */
		mispredFlag[i]    = ctrlAl[i][0] && commitReady[i];

	/* The exception flag is used to mark the system call. 
	 * An instruction with the exception bit set waits until it reaches 
	 * the head of the AL before committing. After it has committed, 
	 * a recovery occurs and the system call is handled. */
		exceptionFlag[i]  = ctrlAl[i][1] && commitReady[i];
	end
	violateFlag[0]    = (violateBit[0] && commitReady[0]) || 
        (violateBit[1] && commitReady[0] && commitReady[1] && ctrlAl[0][3]);
end


always_ff @(posedge clk)
begin : UPDATE_PHYSICAL_REG
    int i;
    for (i = 0; i < `ISSUE_WIDTH; i++)
    begin
        if (bypassPacket[i].valid)
        begin
            PHYSICAL_REG[bypassPacket[i].tag] <= bypassPacket[i].data;
        end
    end
end

integer skip_instructions = 69;
always_comb
begin:COMMIT
	int i;
	reg [`COMMIT_WIDTH-1:0]        commitVector_f;
  reg [`COMMIT_WIDTH-1:0]        commitFission;
  reg [`SIZE_ACTIVELIST_LOG:0]   alCount;
  reg [`COMMIT_WIDTH-1:0]        commitVector;
  reg [`COMMIT_WIDTH-1:0]        commitVector_t1;

  alCount = coreTop.activeList.activeListCnt_o;

	totalCommit          = 0;

	for (i = 0; i < `COMMIT_WIDTH; i = i + 1) 
	begin
		commitFission[i]  = ctrlAl[i][3] && commitReady[i];
	end


	commitVector_f[0] = (alCount > 0) & commitReady[0] & ~violateFlag[0]    & ~exceptionFlag[0];

	for (i = 1; i < `COMMIT_WIDTH; i = i + 1) 
	begin
		commitVector_f[i] = (alCount > i) & commitReady[i] & ~mispredFlag[i] & ~mispredFlag[0] &
		                     ~violateFlag[i] & ~exceptionFlag[i];
	end

	/* Retire the fission instructions together */
	for (i = 0; i < `COMMIT_WIDTH-1; i = i + 1) 
	begin
		if (commitFission[i])
		begin
			commitVector[i] = commitVector_f[i] & commitVector_f[i+1] ;
		end
		else
		begin
			commitVector[i] = commitVector_f[i];
		end
	end

	if (commitFission[`COMMIT_WIDTH-1])
	begin
		commitVector[`COMMIT_WIDTH-1] = 1'b0;
	end
	else
	begin
		commitVector[`COMMIT_WIDTH-1] = commitVector_f[`COMMIT_WIDTH-1];
	end


  // Although the COMMIT_READY ram read port for a particular
  // RAM is already gated and the ready bit will 0 for an inactive
  // lane, it is better to put this mask here in case the RAMs are
  // power gated and logic levels are not guaranteed.
`ifdef DYNAMIC_CONFIG
  commitVector = commitVector & commitLaneActive;
`endif

	commitVector_t1               = 4'h0;

  // May 19th - Rewritten the logic to make it per lane
  // RBRC
  // Extending to 4 bits
  casez ({{4-`COMMIT_WIDTH{1'b0}},commitVector})
    4'b0000:  begin
    end
    4'b??01:  begin
      commitVector_t1 = 4'h1;
      totalCommit     = 1;
    end
`ifdef COMMIT_TWO_WIDE
    4'b?011:  begin
      commitVector_t1 = 4'h3;
      totalCommit     = 2;
    end
`endif    
`ifdef COMMIT_THREE_WIDE
    4'b0111:  begin
      commitVector_t1 = 4'h7;
      totalCommit     = 3;
    end
`endif    
`ifdef COMMIT_FOUR_WIDE
    4'b1111:  begin
      commitVector_t1 = 4'hf;
      totalCommit     = 4;
    end
`endif    
    default: begin
      commitVector_t1 = 4'h0;
      totalCommit     = 0;
    end
  endcase
end



//`ifdef VERIFY_COMMIT
always @(posedge clk)
begin: VERIFY_INSTRUCTIONS
    reg [`SIZE_PC-1:0]           PC           [`COMMIT_WIDTH-1:0];
    reg [`SIZE_RMT_LOG-1:0]      logDest      [`COMMIT_WIDTH-1:0];
    reg [`SIZE_PHYSICAL_LOG-1:0] phyDest      [`COMMIT_WIDTH-1:0];
    reg [`SIZE_DATA-1:0]         result       [`COMMIT_WIDTH-1:0];
    reg                          isBranch     [`COMMIT_WIDTH-1:0];
    reg                          isMispredict [`COMMIT_WIDTH-1:0];
    reg                          eChecker     [`COMMIT_WIDTH-1:0];
    reg                          isFission    [`COMMIT_WIDTH-1:0];
    reg [`SIZE_PC-1:0]           lastCommitPC;
    int i;


    for (i = 0; i < `COMMIT_WIDTH; i++)
    begin
        PC[i]           = dataAl[i].pc;
        logDest[i]      = dataAl[i].logDest;
        phyDest[i]      = dataAl[i].phyDest;
        result[i]       = PHYSICAL_REG[phyDest[i]];
  
        eChecker[i]     = (totalCommit >= (i+1)) ? 1'h1 : 1'h0;
        isFission[i]    = ctrlAl[i][3] & commitReady[i];
        isBranch[i]     = ctrlAl[i][5];

        isMispredict[i] = ctrlAl[i][0] & ctrlAl[i][5];
    end

    if (eChecker[0] && (skip_instructions != 0) && verifyCommits)
    begin
        skip_instructions = skip_instructions - totalCommit;
    end

    else if(verifyCommits)
    begin

        if (lastCommitPC == PC[0] && eChecker[0])
        begin
            lastCommitPC = PC[0];
        end

        else
        begin
            if (eChecker[0]) lastCommitPC = PC[0];

            $getRetireInstPCNetSim(eChecker[0],CYCLE_COUNT,PC[0],logDest[0],result[0],isFission[0],0);
        end

    `ifdef COMMIT_TWO_WIDE
        if (lastCommitPC == PC[1] && eChecker[1])
        begin
            lastCommitPC = PC[1];
        end

        else
        begin
            if(eChecker[1]) lastCommitPC = PC[1];

            $getRetireInstPCNetSim(eChecker[1],CYCLE_COUNT,PC[1],logDest[1],result[1],isFission[1],1);
        end
    `endif

    `ifdef COMMIT_THREE_WIDE
        if (lastCommitPC == PC[2] && eChecker[2])
        begin
            lastCommitPC = PC[2];
        end

        else
        begin
            if(eChecker[2]) lastCommitPC = PC[2];

            $getRetireInstPCNetSim(eChecker[2],CYCLE_COUNT,PC[2],logDest[2],result[2],isFission[2],1);
        end
    `endif

    `ifdef COMMIT_FOUR_WIDE
        if (lastCommitPC == PC[3] && eChecker[3])
        begin
            lastCommitPC = PC[3];
        end

        else
        begin
            if(eChecker[3]) lastCommitPC = PC[3];

            $getRetireInstPCNetSim(eChecker[3],CYCLE_COUNT,PC[3],logDest[3],result[3],isFission[3],1);
        end
    `endif
    end
end
//`endif

task copyRF;

    integer i;

    begin
        for (i = 0; i < 34; i++)
        begin
            //coreTop.registerfile.PhyRegFile_byte0.ram[i] = LOGICAL_REG[i][7:0];
            //coreTop.registerfile.PhyRegFile_byte1.ram[i] = LOGICAL_REG[i][15:8];
            //coreTop.registerfile.PhyRegFile_byte2.ram[i] = LOGICAL_REG[i][23:16];
            //coreTop.registerfile.PhyRegFile_byte3.ram[i] = LOGICAL_REG[i][31:24];
        end

    end
endtask

task copySimRF;

    int i;

    begin
        for (i = 0; i < 34; i++)
        begin
            PHYSICAL_REG[i] = LOGICAL_REG[i];
        end

        for (i = 34; i < `SIZE_PHYSICAL_TABLE; i++)
        begin
            PHYSICAL_REG[i] = 0;
        end
    end
endtask

task init_registers;
    integer i;
    reg  [31:0] opcode;
    reg  [7:0]  dest;
    reg  [7:0]  src1;
    reg  [7:0]  src2;
    reg  [15:0] immed;
    reg  [25:0] target; 

    begin
        for (i = 1; i < 34; i = i + 1)
        begin
            opcode  = {24'h0, `LUI};
            dest    = i;
            immed   = LOGICAL_REG[i][31:16];
            `WRITE_WORD(opcode, (32'h0000_0000 + 16*(i-1)));
            `WRITE_WORD({8'h0, dest, immed}, (32'h0000_0000 + 16*(i-1)+4));
            $display("LUI = Opcode: %x dest: %x immed: %x addr: %x",opcode,dest,immed,(32'h0000_0000 + 16*(i-1)));

            opcode  = {24'h0, `ORI};
            dest    = i;
            src1    = i;
            immed   = LOGICAL_REG[i][15:0];
            `WRITE_WORD(opcode, (32'h0000_0000 + 16*(i-1)+8)); 
            `WRITE_WORD({src1, dest, immed}, (32'h0000_0000 + 16*(i-1)+12)); 
            /* $display("@%d[%08x]", i, LOGICAL_REG[i]); */
            PHYSICAL_REG[i] = LOGICAL_REG[i];
            $display("ORI = Opcode: %x dest: %x src1: %x immed: %x addr: %x",opcode,dest,src1,immed,(32'h0000_0000 + 16*(i-1)+2));
        end

        // return from subroutine
        opcode  = {24'h0, `RET};
        target  = `GET_ARCH_PC >> 2;
        `WRITE_WORD(opcode, (32'h0000_0000 + 16*(i-1))); 
        `WRITE_WORD({6'h0, target}, (32'h0000_0000 + 16*(i-1)+4)); 

        // skip two instructions per register plus 1 for jump
        skip_instructions = 2*33 + 1;
    end
endtask

`ifdef SCRATCH_PAD
  task load_scratch;
   integer  ram_index;
   integer  offset;
   
   for(ram_index = 0; ram_index < `DEBUG_INST_RAM_DEPTH ; ram_index++ )
   //for(ram_index = 0; ram_index < 2 ; ram_index++ )
    begin
    for(offset =0; offset < 5 ; offset ++)
    begin
      instScratchAddr   = {offset[2:0],ram_index[7:0]};
      instScratchWrEn   = 1;   
      instScratchWrData = ram_index[7:0]^offset[7:0];
      #(CLKPERIOD);
    end
    end
  endtask
  
  //task to load the INSTRUCTION scratch pad with the microbenchmark
  task load_kernel_scratch;
   integer  ram_index;
   integer  offset;
   integer  data_file; 
   integer  scan_file; 
   reg [`DEBUG_INST_RAM_WIDTH-1:0] kernel_line;
  
   data_file = $fopen("kernel.dat","r");
  
   for(ram_index = 0; ram_index < `DEBUG_INST_RAM_DEPTH ; ram_index++ )
    begin
    scan_file = $fscanf(data_file, "%10x\n",kernel_line);
    for(offset = 0; offset < 5 ; offset ++)
    begin
      instScratchAddr   = {offset[2:0],ram_index[7:0]};
      instScratchWrEn   = 1;   
      instScratchWrData = kernel_line[8*(offset+1)-1-:8];
      #(CLKPERIOD);
    end
    end
  endtask
  
  //task to read the INSTRUCTION scratch pad
  task read_scratch;
   integer ram_index;
   integer offset;
  for(ram_index = 0; ram_index < `DEBUG_INST_RAM_DEPTH ; ram_index++ )
    begin
    for(offset =0; offset < 5 ; offset ++)
    begin
      instScratchAddr   = {offset[2:0],ram_index[7:0]};   
      #(CLKPERIOD);
      if(instScratchRdData != (ram_index[7:0]^offset[7:0]))
      begin
        $display("READ MISMATCH at %x index %d byte\n",ram_index,offset);
        $display("Read %x , expected %x\n",instScratchRdData,ram_index[7:0]^offset[7:0]);
      end
    end
   end
  endtask
  
  task read_kernel_scratch;
   integer  ram_index;
   integer  offset;
   integer  data_file; 
   integer  scan_file; 
   reg [`DEBUG_INST_RAM_WIDTH-1:0] kernel_line;
  
   data_file = $fopen("kernel.dat","r");
  for(ram_index = 0; ram_index < `DEBUG_INST_RAM_DEPTH ; ram_index++ )
    begin
    scan_file = $fscanf(data_file, "%10x\n",kernel_line);
    for(offset =0; offset < 5 ; offset ++)
    begin
      instScratchAddr   = {offset[2:0],ram_index[7:0]};   
      #(CLKPERIOD);
      if(instScratchRdData != kernel_line[8*(offset+1)-1-:8])
      begin
        $display("READ MISMATCH at %x index %d byte\n",ram_index,offset);
        $display("Read %x , expected %x\n",instScratchRdData,kernel_line[8*(offset+1)-1-:8]);
      end
    end
   end
  
  endtask
`endif // SCRATCH_PAD

//task to load the PRF from checkpoint
task load_checkpoint_PRF;
 integer  ram_index;
 integer  offset;

for(ram_index = 0; ram_index < `SIZE_PHYSICAL_TABLE ; ram_index++)
  begin
  for(offset = 0; offset < 4 ; offset++)
  begin
    debugPRFAddr      = {offset[`SIZE_DATA_BYTE_OFFSET-1:0],ram_index[`SIZE_PHYSICAL_LOG-1:0]};
    debugPRFWrEn      = 1;   
    debugPRFWrData    = offset+ram_index;
    #(2*CLKPERIOD);
  end
  end
debugPRFWrEn      = 0;
endtask

//task to read the PRF byte by byte
task read_checkpoint_PRF;
 integer  ram_index;
 integer  offset;

for(ram_index = 0; ram_index < `SIZE_PHYSICAL_TABLE ; ram_index++)
begin
  for(offset = 3; offset >= 0 ; offset--)
  begin
    debugPRFAddr      = {offset[`SIZE_DATA_BYTE_OFFSET-1:0],ram_index[`SIZE_PHYSICAL_LOG-1:0]};
    //debugPRFWrEn      = 1;  
    #(2*CLKPERIOD);
    if(debugPRFRdData      != offset+ram_index)
    begin
      $display("READ MISMATCH at %x index %d byte\n",ram_index,offset);
      $display("Read %x , expected %x\n",debugPRFRdData,offset+ram_index);
    end
  end
end
endtask

//task to read the ARF byte by byte
task read_ARF;
 integer  ram_index;
 integer  offset;
 reg  [7:0]      captureRF[3:0]; 

for(ram_index = 0; ram_index < `SIZE_RMT ; ram_index++)
  begin
  for(offset = 3; offset >= 0 ; offset--)
  begin
    debugPRFAddr      = {offset[`SIZE_DATA_BYTE_OFFSET-1:0],ram_index[`SIZE_PHYSICAL_LOG-1:0]};
    //debugPRFWrEn      = 1;  
    #(2*CLKPERIOD);
    captureRF[offset] = debugPRFRdData;
    if(offset == 0)
    $display("read %x%x%x%x\n",captureRF[3],captureRF[2],captureRF[1],captureRF[0]);
  end
end
endtask

`ifdef SCRATCH_PAD
task load_data_scratch;
 integer  ram_index;
 integer  offset;
 integer  data_file; 
 integer  scan_file; 
 reg [`DEBUG_DATA_RAM_WIDTH-1:0] data_line;

 data_file = $fopen("data.dat","r");

 for(ram_index = 0; ram_index < `DEBUG_DATA_RAM_DEPTH ; ram_index++ )
  begin
  scan_file = $fscanf(data_file, "%8x\n",data_line);
  for(offset = 0; offset < 3 ; offset ++)
  begin
    dataScratchAddr   = {offset[1:0],ram_index[7:0]};
    dataScratchWrEn   = 1;   
    dataScratchWrData = data_line[8*(offset+1)-1-:8];
    #(CLKPERIOD);
  end
  end
endtask

task read_data_scratch;
 integer  ram_index;
 integer  offset;
 integer  data_file; 
 integer  scan_file; 
 reg [`DEBUG_DATA_RAM_WIDTH-1:0] data_line;

 data_file = $fopen("data.dat","r");
for(ram_index = 0; ram_index < `DEBUG_DATA_RAM_DEPTH ; ram_index++ )
  begin
  scan_file = $fscanf(data_file, "%8x\n",data_line);
  for(offset =0; offset < 3 ; offset ++)
  begin
    dataScratchAddr   = {offset[1:0],ram_index[7:0]};   
    #(CLKPERIOD);
    //if(dataScratchRdData != data_line[8*(offset+1)-1-:8])
    if(dataScratchRdData != data_line[8*(offset+1)-1-:8])
    begin
      $display("READ MISMATCH at %x index %d byte\n",ram_index,offset);
      $display("Read %x , expected %x\n",dataScratchRdData,data_line[8*(offset+1)-1-:8]);
    end
  end
 end
endtask

`endif // SCRATCH_PAD



`ifdef PERF_MON

task read_perf_mon;
  integer  index;
  
  perfMonRegRun        = 1'b1;
  #(1000*CLKPERIOD)
  perfMonRegRun        = 1'b0;
  #CLKPERIOD;
  for(index = 8'h00; index < 8'h05 ; index++ )
  begin
    perfMonRegAddr       = index[7:0];
    #CLKPERIOD;
  end
  for(index = 8'h10; index < 8'h12 ; index++ )
  begin
    perfMonRegAddr       = index[7:0];
    #CLKPERIOD;
  end
  for(index = 8'h20; index < 8'h21 ; index++ )
  begin
    perfMonRegAddr       = index[7:0];
    #CLKPERIOD;
  end
  for(index = 8'h30; index < 8'h32 ; index++ )
  begin
    perfMonRegAddr       = index[7:0];
    #CLKPERIOD;
  end
  for(index = 8'h40; index < 8'h49 ; index++ )
  begin
    perfMonRegAddr       = index[7:0];
    #CLKPERIOD;
  end
  for(index = 8'h50; index < 8'h55 ; index++ )
  begin
    perfMonRegAddr       = index[7:0];
    #CLKPERIOD;
  end
 
  perfMonRegRun        = 1'b1;
  perfMonRegClr        = 1'b1;  //clearPerfMon = 1
    perfMonRegAddr       = 8'h00;
    #CLKPERIOD;
  
  perfMonRegClr        = 1'b0;  //clearPerfMon = 0
    #CLKPERIOD;
  perfMonRegRun        = 1'b0;
  
  for(index = 8'h00; index < 8'h05 ; index++ )
  begin
    perfMonRegAddr       = index[7:0];
    #CLKPERIOD;
  end
  
  for(index = 8'h10; index < 8'h20 ; index++ )
  begin
    perfMonRegAddr       = index[7:0];
    #CLKPERIOD;
  end
   
  perfMonRegGlobalClr  = 1'b1;  //Global clearPerfMon = 1
  #CLKPERIOD;
  for(index = 8'h00; index < 8'h05 ; index++ )
  begin
    perfMonRegAddr       = index[7:0];
    #CLKPERIOD;
  end
  for(index = 8'h10; index < 8'h12 ; index++ )
  begin
    perfMonRegAddr       = index[7:0];
    #CLKPERIOD;
  end
  for(index = 8'h20; index < 8'h21 ; index++ )
  begin
    perfMonRegAddr       = index[7:0];
    #CLKPERIOD;
  end
  for(index = 8'h30; index < 8'h32 ; index++ )
  begin
    perfMonRegAddr       = index[7:0];
    #CLKPERIOD;
  end
  for(index = 8'h40; index < 8'h49 ; index++ )
  begin
    perfMonRegAddr       = index[7:0];
    #CLKPERIOD;
  end
  for(index = 8'h50; index < 8'h55 ; index++ )
  begin
    perfMonRegAddr       = index[7:0];
    #CLKPERIOD;
  end
endtask
`endif

//initial
//begin
////beginConsolidation_reg = 1'b0;
////#(2000*CLKPERIOD);
////stallFetch = 1'b1;
////#(10*CLKPERIOD);
////beginConsolidation_reg = 1'b1;
////#CLKPERIOD;
////beginConsolidation_reg = 1'b0;
//////#(100*CLKPERIOD);
//wait (coreTop.consolidationDone);
//read_ARF();
//end

//assign coreTop.beginConsolidation = beginConsolidation_reg;

task reconfigure;
input [3:0] configID;
begin
  stallFetch                     = 1'b0;
$display("********************************************************\n");
$display("*           Reconfiguring to config =  %d              *\n",configID);
$display("********************************************************\n");
case(configID)
1:
  begin
  fetchLaneActive  =       {{`FETCH_WIDTH-1{1'b0}},1'b1};      
  dispatchLaneActive  =    {{`DISPATCH_WIDTH-1{1'b0}},1'b1};   
  issueLaneActive  =       {{`ISSUE_WIDTH-3{1'b0}},3'b111};    
  execLaneActive  =        {{`EXEC_WIDTH-3{1'b0}},3'b111};     
  saluLaneActive  =        {{`EXEC_WIDTH-3{1'b0}},3'b100};     
  caluLaneActive  =        {{`EXEC_WIDTH-3{1'b0}},3'b100};     
  commitLaneActive  =      {{`COMMIT_WIDTH-1{1'b0}},1'b1};     
  rfPartitionActive  =     {{`NUM_PARTS_RF-3{1'b0}},3'b111};   
  alPartitionActive  =     {{`NUM_PARTS_RF-3{1'b0}},3'b111};   
  lsqPartitionActive  =    {{`STRUCT_PARTS_LSQ-2{1'b0}},2'b11};
  iqPartitionActive  =     {{`STRUCT_PARTS-2{1'b0}},2'b11};    
  ibuffPartitionActive  =  {{`STRUCT_PARTS-2{1'b0}},2'b11};    
  end
2:
  begin
  fetchLaneActive  =       {{`FETCH_WIDTH-1{1'b0}},1'b1};     
  dispatchLaneActive  =    {{`DISPATCH_WIDTH-1{1'b0}},1'b1};  
  issueLaneActive  =       {{`ISSUE_WIDTH-3{1'b0}},3'b111};   
  execLaneActive  =        {{`EXEC_WIDTH-3{1'b0}},3'b111};    
  saluLaneActive  =        {{`EXEC_WIDTH-3{1'b0}},3'b100};    
  caluLaneActive  =        {{`EXEC_WIDTH-3{1'b0}},3'b100};    
  commitLaneActive  =      {{`COMMIT_WIDTH-1{1'b0}},1'b1};    
  rfPartitionActive  =     {{`NUM_PARTS_RF-2{1'b0}},2'b11};   
  alPartitionActive  =     {{`NUM_PARTS_RF-2{1'b0}},2'b11};   
  lsqPartitionActive  =    {{`STRUCT_PARTS_LSQ-1{1'b0}},1'b1};
  iqPartitionActive  =     {{`STRUCT_PARTS-1{1'b0}},1'b1};    
  ibuffPartitionActive  =  {{`STRUCT_PARTS-2{2'b0}},2'b11};   
  end
3:
  begin
  fetchLaneActive  =        {{`FETCH_WIDTH-2{1'b0}},2'b11};     
  dispatchLaneActive  =     {{`DISPATCH_WIDTH-2{1'b0}},2'b11};  
  issueLaneActive  =        {{`ISSUE_WIDTH-4{1'b0}},4'b1111};   
  execLaneActive  =         {{`EXEC_WIDTH-4{1'b0}},4'b1111};    
  saluLaneActive  =         {{`EXEC_WIDTH-4{1'b0}},4'b1100};    
  caluLaneActive  =         {{`EXEC_WIDTH-4{1'b0}},4'b0100};    
  commitLaneActive  =       {{`COMMIT_WIDTH-2{1'b0}},2'b11};    
  rfPartitionActive  =      {{`NUM_PARTS_RF-3{1'b0}},3'b111};   
  alPartitionActive  =      {{`NUM_PARTS_RF-3{1'b0}},3'b111};   
  lsqPartitionActive  =     {{`STRUCT_PARTS_LSQ-2{1'b0}},2'b11};
  iqPartitionActive  =      {{`STRUCT_PARTS-3{1'b0}},3'b111};   
  ibuffPartitionActive  =   {{`STRUCT_PARTS-3{1'b0}},3'b111};   
  end
4:
  begin
  fetchLaneActive  =       {{`FETCH_WIDTH-2{1'b0}},2'b11};    
  dispatchLaneActive  =    {{`DISPATCH_WIDTH-2{1'b0}},2'b11}; 
  issueLaneActive  =       {{`ISSUE_WIDTH-4{1'b0}},4'b1111};  
  execLaneActive  =        {{`EXEC_WIDTH-4{1'b0}},4'b1111};   
  saluLaneActive  =        {{`EXEC_WIDTH-4{1'b0}},4'b1100};   
  caluLaneActive  =        {{`EXEC_WIDTH-4{1'b0}},4'b0100};   
  commitLaneActive  =      {{`COMMIT_WIDTH-2{1'b0}},2'b11};   
  rfPartitionActive  =     {{`NUM_PARTS_RF-2{1'b0}},2'b11};   
  alPartitionActive  =     {{`NUM_PARTS_RF-2{1'b0}},2'b11};   
  lsqPartitionActive  =    {{`STRUCT_PARTS_LSQ-1{1'b0}},1'b1};
  iqPartitionActive  =     {{`STRUCT_PARTS-3{1'b0}},3'b111};  
  ibuffPartitionActive  =  {{`STRUCT_PARTS-3{1'b0}},3'b111};  
  end
5:
  begin
  fetchLaneActive  =       {`FETCH_WIDTH{1'b1}};     
  dispatchLaneActive  =    {`DISPATCH_WIDTH{1'b1}};  
  issueLaneActive  =       {`ISSUE_WIDTH{1'b1}};     
  execLaneActive  =        {`EXEC_WIDTH{1'b1}};      
  saluLaneActive  =        {5'b11100};               
  caluLaneActive  =        {5'b00100};               
  commitLaneActive  =      {`COMMIT_WIDTH{1'b1}};    
  rfPartitionActive  =     {`NUM_PARTS_RF{1'b1}};    
  alPartitionActive  =     {`NUM_PARTS_RF{1'b1}};    
  lsqPartitionActive  =    {`STRUCT_PARTS_LSQ{1'b1}};
  iqPartitionActive  =     {`STRUCT_PARTS{1'b1}};    
  ibuffPartitionActive  =  {`STRUCT_PARTS{1'b1}};    
  end
6:
  begin
  fetchLaneActive  =       {`FETCH_WIDTH{1'b1}};              
  dispatchLaneActive  =    {`DISPATCH_WIDTH{1'b1}};           
  issueLaneActive  =       {`ISSUE_WIDTH{1'b1}};              
  execLaneActive  =        {`EXEC_WIDTH{1'b1}};               
  saluLaneActive  =        {5'b11100};                        
  caluLaneActive  =        {5'b00100};                        
  commitLaneActive  =      {`COMMIT_WIDTH{1'b1}};             
  rfPartitionActive  =     {{`NUM_PARTS_RF-3{1'b0}},3'b111};  
  alPartitionActive  =     {{`NUM_PARTS_RF-3{1'b0}},3'b111};  
  lsqPartitionActive  =    {{`STRUCT_PARTS_LSQ-1{1'b0}},1'b1};
  iqPartitionActive  =     {{`STRUCT_PARTS-3{1'b0}},3'b111};  
  ibuffPartitionActive  =  {`STRUCT_PARTS{1'b1}};             
  end
endcase

  reconfigureCore           = 1'b1;

  #(3*CLKPERIOD-4)
  reconfigureCore      = 1'b0;
  #CLKPERIOD
  stallFetch           = 1'b0;
end
endtask

endmodule

module ANTENNATF(
  input A
  );
endmodule
