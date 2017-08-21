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

//`define WAVES

`define STDIN   32'h8000_0000
`define STDOUT  32'h8000_0001
`define STDERR  32'h8000_0002

module simulate();

  import "DPI-C" context task initializeSim();
  import "DPI-C" function int get_logging_mode();
  import "DPI-C" function longint getArchRegValue(int reg_id);
  import "DPI-C" function longint getArchPC();
  import "DPI-C" function int checkInstruction(longint v_cycle,longint v_commit,longint v_pc, int v_dest, longint v_dest_value, int is_fission );
  //import "DPI-C" function void testing();
  import "DPI-C" function void set_pcr(int which_csr, longint value);
  import "DPI-C" function longint get_pcr(int which_csr);
  import "DPI-C" context task htif_tick(output int htif_return);
  import "DPI-C" function int virt_to_phys(longint virt_addr, int bytes, int store_access, int fetch_access, output int exception);

integer CYCLE_COUNT;
integer COMMIT_COUNT;

// Commit count at which the wave dumping begins
parameter START_DUMP_WAVE_COMMIT_COUNT = 100000;
parameter START_DUMP_WAVE_CYCLE_COUNT  = 90000;

// Commit count at which the wave dumping stops
parameter STOP_DUMP_WAVE_COMMIT_COUNT  = 200_000;
parameter STOP_DUMP_WAVE_CYCLE_COUNT   = 100_000;

//* Stop Simulation when COMMIT_COUNT >= SIM_STOP_COUNT
`ifdef SCRATCH_EN
  parameter SIM_STOP_COMMIT_COUNT      = 10_000;
`else
  parameter SIM_STOP_COMMIT_COUNT      = 10_000_000;
`endif

//* Print when (COMMIT_COUNT >= PRINT_START_COMMIT_COUNT) && (CYCLE_COUNT >= PRINT_START_CYCLE_COUNT)
parameter PRINT_START_COMMIT_COUNT  = 1_000_000;
parameter PRINT_START_CYCLE_COUNT   = 0;

`ifdef GATE_SIM
parameter STAT_PRINT_INTERVAL    = 1000;
parameter IPC_PRINT_INTERVAL     = 10_000;
`else
parameter STAT_PRINT_INTERVAL    = 10_000;
parameter IPC_PRINT_INTERVAL     = 10_000;
`endif

parameter CLKPERIOD           =  `CLKPERIOD;

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
reg resetDone;
int loggingOn;

`ifdef PERF_MON
  reg [`REG_DATA_WIDTH-1:0] perfMonRegAddr; 
  reg [31:0]                perfMonRegData; 
  reg                       perfMonRegRun ;
  reg                       perfMonRegClr ;
  reg                       perfMonRegGlobalClr ;
`endif

//`define WAVES
`ifdef WAVES
  reg dumpWave;
  initial
  begin
    dumpWave = 1'b0;
  end

  always @(*)
    dumpWave = ((COMMIT_COUNT >= START_DUMP_WAVE_COMMIT_COUNT) && (COMMIT_COUNT <= STOP_DUMP_WAVE_COMMIT_COUNT)) |
                ((CYCLE_COUNT >= START_DUMP_WAVE_CYCLE_COUNT ) && (CYCLE_COUNT <= STOP_DUMP_WAVE_CYCLE_COUNT));

  always @(posedge dumpWave)
  begin
    $shm_open("waves.shm");
    $shm_probe(simulate, "ACM");
    //$dumpfile("waves.vcd");
    //$dumpvars(0,coreTop);
    //$dumplimit(600000000);
  end

  always @(negedge dumpWave)
  begin
    $shm_close("waves.shm");
  end
`endif //WAVES


// Following defines the clk for the simulation.
always #(CLKPERIOD/2.0) 
begin
  clk = ~clk;
end


reg  [`SIZE_DATA-1:0]                 LOGICAL_REG [`SIZE_RMT-1:0];
reg  [`SIZE_DATA-1:0]                 PHYSICAL_REG [`SIZE_PHYSICAL_TABLE-1:0];
reg  [`SIZE_PC-1:0]                   startPC;
reg                                   resetFetch;
reg                                   verifyCommits;
reg                                   cacheModeOverride; //If 1 -> Forces caches to operate in CACHE mode
wire                                  coreResetDone;



`ifdef DYNAMIC_CONFIG
  // Power management signals
  reg                                 stallFetch;
  reg  [`FETCH_WIDTH-1:0]             fetchLaneActive;
  reg  [`DISPATCH_WIDTH-1:0]          dispatchLaneActive;
  reg  [`ISSUE_WIDTH-1:0]             issueLaneActive;
  reg  [`EXEC_WIDTH-1:0]              execLaneActive;
  reg  [`EXEC_WIDTH-1:0]              saluLaneActive;
  reg  [`EXEC_WIDTH-1:0]              caluLaneActive;
  reg  [`COMMIT_WIDTH-1:0]            commitLaneActive;
  reg  [`NUM_PARTS_RF-1:0]            rfPartitionActive;
  reg  [`NUM_PARTS_RF-1:0]            alPartitionActive;
  reg  [`STRUCT_PARTS_LSQ-1:0]        lsqPartitionActive;
  reg  [`STRUCT_PARTS-1:0]            iqPartitionActive;
  reg  [`STRUCT_PARTS-1:0]            ibuffPartitionActive;
  reg                                 reconfigureCore;
`endif

`ifdef SCRATCH_PAD
  reg [`DEBUG_INST_RAM_LOG+`DEBUG_INST_RAM_WIDTH_LOG-1:0]  instScratchAddr;
  reg [7:0]                           instScratchWrData;  
  reg                                 instScratchWrEn; 
  reg [`DEBUG_DATA_RAM_LOG+`DEBUG_DATA_RAM_WIDTH_LOG-1:0] dataScratchAddr;
  reg [7:0]                           dataScratchWrData;  
  reg                                 dataScratchWrEn;  
  reg [7:0]                           instScratchRdData;  
  reg [7:0]                           dataScratchRdData;  
  reg                                 instScratchPadEn = INST_SCRATCH_ENABLED;
  reg                                 dataScratchPadEn = DATA_SCRATCH_ENABLED;
`endif

  logic                               dcFlush;
  logic                               dcFlushDone;
  logic                               icFlush;
  logic                               icFlushDone;

  //logic                           instCacheBypass = INST_CACHE_BYPASS;
  logic                               icScratchModeEn;
`ifdef INST_CACHE
  logic [`ICACHE_BLOCK_ADDR_BITS-1:0] ic2memReqAddr;     // memory read address
  logic                               ic2memReqValid;     // memory read enable
  logic [`ICACHE_TAG_BITS-1:0]        mem2icTag;          // tag of the incoming data
  logic [`ICACHE_INDEX_BITS-1:0]      mem2icIndex;        // index of the incoming data
  logic [`ICACHE_BITS_IN_LINE-1:0]    mem2icData;         // requested data
  logic                               mem2icRespValid;    // requested data is ready
`endif  

  logic                               dataCacheBypass = DATA_CACHE_BYPASS;
  logic                               dcScratchModeEn;
`ifdef DATA_CACHE
  logic [`DCACHE_BLOCK_ADDR_BITS-1:0] dc2memLdAddr;  // memory read address
  logic                               dc2memLdValid; // memory read enable
  logic [`DCACHE_TAG_BITS-1:0]        mem2dcLdTag;       // tag of the incoming datadetermine
  logic [`DCACHE_INDEX_BITS-1:0]      mem2dcLdIndex;     // index of the incoming data
  logic [`DCACHE_BITS_IN_LINE-1:0]    mem2dcLdData;      // requested data
  logic                               mem2dcLdValid;     // indicates the requested data is ready
  logic [`DCACHE_ST_ADDR_BITS-1:0]    dc2memStAddr;  // memory read address
  logic [`SIZE_DATA-1:0]              dc2memStData;  // memory read address
  logic [`SIZE_DATA_BYTE-1:0]         dc2memStByteEn;  // memory read address
  logic                               dc2memStValid; // memory read enable
  logic                               mem2dcStComplete;
`endif

int a;

initial
begin
  `ifdef GATE_SIM
    `ifdef USE_SDF
        $sdf_annotate({"./Core_OOO.sdf"},coreTop,,"sdffile.log");
    `endif
  `endif
end


//initial
//begin
//  //force coreTop.activeList.bistAddrWr = 0;
//  wait (resetDone == 1'b1)
//  //release coreTop.activeList.bistAddrWr;
//  coreTop.activeList.bistAddrWr_reg_0_.Q = 1'b0;
//  coreTop.activeList.bistAddrWr_reg_1_.Q = 1'b0;
//  coreTop.activeList.bistAddrWr_reg_2_.Q = 1'b0;
//  coreTop.activeList.bistAddrWr_reg_3_.Q = 1'b0;
//  coreTop.activeList.bistAddrWr_reg_4_.Q = 1'b0;
//  coreTop.activeList.bistAddrWr_reg_5_.Q = 1'b0;
//  coreTop.activeList.bistAddrWr_reg_6_.Q = 1'b0;
//end

initial 
begin:INIT_TB
  int i;

  clk                  = 1'b0;
  reset                = 1'b0;
  resetDone            = 1'b0;
  resetFetch           = 1'b0;
  verifyCommits        = 1'b0;
`ifdef DYNAMIC_CONFIG
  stallFetch           = 1'b0;
  reconfigureCore      = 1'b0;
`endif
  
  dcFlush              = 1'b0;

  if(!INST_SCRATCH_ENABLED)
  begin
    initializeSim();
  end

//  $display("");
//  $display("");
//  $display("**********   ******   ********     *******    ********   ******   ****         ******   ********  ");
//  $display("*        *  *      *  *       *   *      *   *       *  *      *  *  *        *      *  *       * ");
//  $display("*  ******* *   **   * *  ***   * *   *****  *   ****** *   **   * *  *       *   **   * *  ***   *");
//  $display("*  *       *  *  *  * *  *  *  * *  *       *  *       *  *  *  * *  *       *  *  *  * *  *  *  *");
//  $display("*  *****   *  ****  * *  ***   * *   ****   *  *       *  ****  * *  *       *  ****  * *  ***   *");
//  $display("*      *   *        * *       *   *      *  *  *       *        * *  *       *        * *       * ");
//  $display("*  *****   *  ****  * *  ***   *   ****   * *  *       *  ****  * *  *       *  ****  * *  ***   *");
//  $display("*  *       *  *  *  * *  *  *  *       *  * *  *       *  *  *  * *  *       *  *  *  * *  *  *  *");
//  $display("*  *       *  *  *  * *  ***   *  *****   * *   ****** *  *  *  * *  ******* *  *  *  * *  *  *  *");
//  $display("*  *       *  *  *  * *       *   *      *   *       * *  *  *  * *        * *  *  *  * *  *  *  *");
//  $display("****       ****  **** ********    *******     ******** ****  **** ********** ****  **** ****  ****");
//  $display("");
//  $display("AnyCore Copyright (c) 2007-2012 by Niket K. Choudhary, Brandon H. Dwiel, and Eric Rotenberg.");
//  $display("All Rights Reserved.");
//  $display("");
//  $display("");


  $display("");
  $display("");
  $display("                   ###    ##    ## ##    ##  ######   #######  ########  ######## "); 
  $display("                  ## ##   ###   ##  ##  ##  ##    ## ##     ## ##     ## ##       "); 
  $display("                 ##   ##  ####  ##   ####   ##       ##     ## ##     ## ##       "); 
  $display("                ##     ## ## ## ##    ##    ##       ##     ## ########  ######   "); 
  $display("                ######### ##  ####    ##    ##       ##     ## ##   ##   ##       "); 
  $display("                ##     ## ##   ###    ##    ##    ## ##     ## ##    ##  ##       "); 
  $display("                ##     ## ##    ##    ##     ######   #######  ##     ## ######## "); 
  $display("");
  $display("AnyCore Copyright (c) 20011-2016 by Rangeen Basu Roy Chowdhury, Anil K. Kannepalli, and Eric Rotenberg.");
  $display("AnyCore was derived from AnyCore Copyright (c) 2007-2016 by Niket K. Choudhary, Brandon H. Dwiel,");
  $display("                            and Eric Rotenberg. All Rights Reserved.");
  $display("");
  $display("");


  if(!INST_SCRATCH_ENABLED)
  begin
    for (i = 0; i < `SIZE_RMT; i = i + 1)
    begin
      LOGICAL_REG[i]               = getArchRegValue(i);
    end
    startPC = getArchPC(); 
  end


  // Initialize the caches to SCRATCH mode
  // NOTE: This is not required in AnyCore_Chip mode as 
  // they initialize to SCRATCH mode by default
  `ifdef INST_CACHE
    icScratchModeEn       = 1'b0;
  `endif
  `ifdef DATA_CACHE
    dcScratchModeEn       = 1'b0;
  `endif  

  //// Initialize RAMs that need to be initialized
  //for (i = 0; i < `SIZE_PHYSICAL_TABLE; i++)
  //begin
  //  //coreTop.registerfile.PhyRegFile.ram[i] = {WIDTH{1'b0}};
  //  coreTop.registerfile.PhyRegFile.ram[i] = $random;
  //end
  

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
  reset                 = 0;
  resetDone             = 1;
  #4;

  //`ifdef GATE_SIM
  //  #(2000*CLKPERIOD)
  //  $finish();
  //`endif

  // Register values must be copied after the core has completed
  // its reset sequence.
  wait(coreResetDone == 1'b1);
  copyRF();
  copyCSR();

  `ifdef INST_CACHE
  
    // Let the core run in BIST mode for a while before reconfiguring and loading benchmarks/microkernel
    //  #(500*CLKPERIOD)
    
    `ifdef DYNAMIC_CONFIG
      stallFetch            = 1'b1;
      //   #(500*CLKPERIOD)  //Enough time to drain pipeline
      //Reset fetch to start fetching from PC 0x0000 (to load checkpoint and benchmark)
      resetFetch            = 1'b1;
      //    #(200*CLKPERIOD)  //Enough time to drain pipeline
    `endif

  `else // If in perfect cache mode

    //    resetFetch            = 1'b0; TODO moved it after loading scratch to
    //    avoid fetch
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

//    `ifdef SCRATCH_PAD
//		  load_kernel_scratch();
//		  instScratchWrEn   = 0;   
//		  read_kernel_scratch();
//		  
//		  load_data_scratch();
//		  dataScratchWrEn   = 0;   
//		  read_data_scratch();
//    `endif

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
      `ifdef DYNAMIC_CONFIG
        stallFetch           = 1'b0;
        resetFetch           = 1'b0;
      `endif
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

`endif 

`ifdef PERF_MON
  read_perf_mon();
`endif  

end

`ifdef GATE_SIM
reg [`SIZE_PC*`FETCH_WIDTH-1:0]     instPC_gate;
reg [`SIZE_INSTRUCTION*`FETCH_WIDTH-1:0] inst_gate;
`endif


reg  [`SIZE_PC-1:0]                instPC [0:`FETCH_WIDTH-1];
reg  [`SIZE_INSTRUCTION-1:0]       inst   [0:`FETCH_WIDTH-1];
exceptionPkt                       instException;

wire [`SIZE_PC-1:0]                ldAddr;
wire [`SIZE_DATA-1:0]              ldData;
wire                               ldEn;
exceptionPkt                       ldException;

wire [`SIZE_PC-1:0]                stAddr;
wire [`SIZE_DATA-1:0]              stData;
wire [7:0]                         stEn;
exceptionPkt                       stException;

wire [1:0]                         ldStSize;

reg [`SIZE_DATA_BYTE_OFFSET+`SIZE_PHYSICAL_LOG-1:0] debugPRFAddr  ;
reg [`SRAM_DATA_WIDTH-1:0] 			   debugPRFWrData;             
reg 					                     debugPRFWrEn  = 1'b0;
reg [`SRAM_DATA_WIDTH-1:0] 			   debugPRFRdData;

always @(posedge clk)
begin:HANDLE_EXCEPTION
  int i;
  reg [`SIZE_PC-1:0] TRAP_PC;
  int                TRAP_CAUSE;
  if(!INST_SCRATCH_ENABLED) // This is controlled in the testbench
  begin
    // Following code handles the SYSCALL (trap).
    //if (coreTop.activeList.exceptionFlag_o && (|coreTop.activeList.alCount))
    if (coreTop.activeList.exceptionFlag_o)
    begin

      /* Functional simulator is stalled waiting to execute the trap.
       * Signal it to proceed with the trap.
       */

      TRAP_PC     = coreTop.activeList.exceptionPC_o;
      TRAP_CAUSE  = coreTop.activeList.exceptionCause_o;
  
      if(loggingOn)
        $display("TRAP (Cycle: %0d PC: %08x Code: %0d)\n",
                 CYCLE_COUNT,
                 TRAP_PC,
                 TRAP_CAUSE);


      take_trap(TRAP_CAUSE, TRAP_PC);

    end
  end // !INST_SCRATCH_ENABLED
end

wire    PRINT;
assign  PRINT = (COMMIT_COUNT >= PRINT_START_COMMIT_COUNT) && (CYCLE_COUNT > PRINT_START_CYCLE_COUNT);

integer last_commit_cnt;
integer prev_commit_point;
integer phase_mispredicts;
integer fs_commit_count;
integer prev_branch_point;
integer prev_br_misp_point;
integer last_cycle_cnt;
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
integer stat_num_corr;
integer stat_num_pred;
integer stat_num_cond_corr;
integer stat_num_cond_pred;
integer stat_num_return_corr;
integer stat_num_return_pred;
integer stat_num_recover;
      
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
real    phase_ipc;
real    phase_mispred;
real    phase_mpki;

integer fd_fetch1   ;
integer fd_fetch2   ;
integer fd_decode   ;
integer fd_ibuff    ;
integer fd_rename   ;
integer fd_dispatch ;
integer fd_select   ;
integer fd_issueq   ;
integer fd_regread  ;
integer fd_prf      ;
integer fd_exe      ;
integer fd_alist    ;
integer fd_lsu      ;
integer fd_wback    ;
integer fd_stats    ;
integer fd_coretop;
integer fd_bhr      ;
integer fd_specbhr  ;

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
    prev_commit_point    = 0;
    prev_branch_point    = 0;
    prev_br_misp_point   = 0;
    last_cycle_cnt       = 0;

    stat_num_corr        = 0;
    stat_num_pred        = 0;
    stat_num_cond_corr   = 0;
    stat_num_cond_pred   = 0;
    stat_num_return_corr = 0;
    stat_num_return_pred = 0;
    stat_num_recover     = 0;

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

    open_log_files();

`ifdef DUMP_STATS
    $fwrite(fd_stats, "CYCLE, "); 
    $fwrite(fd_stats, "COMMIT, "); 

    $fwrite(fd_stats, "IB-avg, "); 
    $fwrite(fd_stats, "FL-avg, "); 
    $fwrite(fd_stats, "IQ-avg, "); 
    $fwrite(fd_stats, "LDQ-avg, "); 
    $fwrite(fd_stats, "STQ-avg, "); 
    $fwrite(fd_stats, "AL-avg, "); 

    $fwrite(fd_stats, "FS1-stall, ");
    $fwrite(fd_stats, "CTI-stall, ");
    $fwrite(fd_stats, "IB-stall, ");
    $fwrite(fd_stats, "FL-stall, ");
    $fwrite(fd_stats, "BE-stall, ");
    $fwrite(fd_stats, "LDQ-stall, ");
    $fwrite(fd_stats, "STQ-stall, ");
    $fwrite(fd_stats, "IQ-stall, ");
    $fwrite(fd_stats, "AL-stall, ");

    $fwrite(fd_stats, "BTB-Miss, ");
    $fwrite(fd_stats, "Miss-Rtn, ");
    $fwrite(fd_stats, "BR-Count, ");
    $fwrite(fd_stats, "Mis-Cnt, ");
    $fwrite(fd_stats, "LdVio-Cnt, ");

    $fwrite(fd_stats, "stat_num_corr, ");
    $fwrite(fd_stats, "stat_num_pred, ");
    $fwrite(fd_stats, "stat_num_cond_corr, ");
    $fwrite(fd_stats, "stat_num_cond_pred, ");
    $fwrite(fd_stats, "stat_num_return_corr, ");
    $fwrite(fd_stats, "stat_num_return_pred, ");

    $fwrite(fd_stats, "Commit_1, ");
    $fwrite(fd_stats, "Commit_2, ");
    $fwrite(fd_stats, "Commit_3, ");
    $fwrite(fd_stats, "Commit_4\n");
`endif
end

always @(posedge clk)
begin
  update_stats();
  //if(loggingOn)
  //begin
    print_heartbeat();
  //end
    `ifdef PRINT_EN
      if(resetDone & coreResetDone)
      begin
        coretop_debug_print();
        fetch1_debug_print();
        fetch2_debug_print();
        decode_debug_print();
        ibuff_debug_print();
        rename_debug_print();
        dispatch_debug_print();
        issueq_debug_print();
        regread_debug_print();
        prf_debug_print();
        exe_debug_print();
        lsu_debug_print();
        alist_debug_print();
      end
    `endif
  //end
end

bypassPkt   [0:`ISSUE_WIDTH-1]  bypassPacket;

always @(*)
begin
  int i;
  `ifdef GATE_SIM
    bypassPacket = coreTop.registerfile.bypassPacket_i;
  `else
    for (i = 0; i < `ISSUE_WIDTH; i++)
    begin
        bypassPacket[i] = coreTop.registerfile.bypassPacket_i[i];
    end
  `endif
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

integer skip_instructions = 0;
integer idleCycles;
integer instRetired;
integer INTERLEAVE = 50;

initial
begin
  idleCycles  = 0;
  instRetired = 0;
end

alPkt                               dataAl          [0:`COMMIT_WIDTH-1];
exeFlgs                             ctrlAl          [0:`COMMIT_WIDTH-1];
wire                                commitReady     [0:`COMMIT_WIDTH-1];
wire                                violateBit      [0:`COMMIT_WIDTH-1];
reg [`SIZE_PC-1:0]                  commitPC        [0:`COMMIT_WIDTH-1];
reg [`COMMIT_WIDTH_LOG:0]           totalCommit;

assign dataAl[0] = coreTop.activeList.activeList.data0_o;
assign ctrlAl[0] = coreTop.activeList.ctrlActiveList.data0_o;
assign commitReady[0] = coreTop.activeList.executedActiveList.data0_o;
assign violateBit[0] = coreTop.activeList.ldViolateVector.data0_o;

`ifdef COMMIT_TWO_WIDE
assign dataAl[1] = coreTop.activeList.activeList.data1_o;
assign ctrlAl[1] = coreTop.activeList.ctrlActiveList.data1_o;
assign commitReady[1] = coreTop.activeList.executedActiveList.data1_o;
assign violateBit[1] = coreTop.activeList.ldViolateVector.data1_o;
`endif

`ifdef COMMIT_THREE_WIDE
assign dataAl[2] = coreTop.activeList.activeList.data2_o;
assign ctrlAl[2] = coreTop.activeList.ctrlActiveList.data2_o;
assign commitReady[2] = coreTop.activeList.executedActiveList.data2_o;
assign violateBit[2] = coreTop.activeList.ldViolateVector.data2_o;
`endif

`ifdef COMMIT_FOUR_WIDE
assign dataAl[3] = coreTop.activeList.activeList.data3_o;
assign ctrlAl[3] = coreTop.activeList.ctrlActiveList.data3_o;
assign commitReady[3] = coreTop.activeList.executedActiveList.data3_o;
assign violateBit[3] = coreTop.activeList.ldViolateVector.data3_o;
`endif


alPkt                             alPacket  [0:`DISPATCH_WIDTH-1];
alPkt [0:`DISPATCH_WIDTH-1]       alPacketPacked;
ctrlPkt                           ctrlPacket [0:`ISSUE_WIDTH-1];
ctrlPkt [0:`ISSUE_WIDTH-1]        ctrlPacketPacked;


`ifdef GATE_SIM
assign alPacketPacked = coreTop.activeList.alPacket_i;
assign ctrlPacketPacked = coreTop.activeList.ctrlPacket_i;

always @(*)
begin
  int i;
  for(i=0;i<`DISPATCH_WIDTH;i++)
    alPacket[i]                = alPacketPacked[i];

  for(i=0;i<`ISSUE_WIDTH;i++)
    ctrlPacket[i]              = ctrlPacketPacked[i];
end
`else
always @(*)
begin
  int i;
  for(i=0;i<`DISPATCH_WIDTH;i++)
    alPacket[i]     = coreTop.alPacket[i];

  for (i = 0; i < `ISSUE_WIDTH; i++)
    ctrlPacket[i]   = coreTop.ctrlPacket[i];
end
`endif

//`ifdef GATE_SIM
ActiveList_tb al_tb(
//`else
//ActiveList al_tb (
//`endif
	.clk                  (clk),
	.reset                (coreTop.activeList.reset),
  .resetRams_i          (coreTop.activeList.reset),

`ifdef DYNAMIC_CONFIG  
  .dispatchLaneActive_i (coreTop.activeList.dispatchLaneActive_i),
  .issueLaneActive_i    (coreTop.activeList.issueLaneActive_i),
  .commitLaneActive_i   (coreTop.activeList.commitLaneActive_i),
  .alPartitionActive_i  (coreTop.activeList.alPartitionActive_i),
  .squashPipe_i         (1'b0),
`endif  

//`ifdef DATA_CACHE
//  .stallStCommit_i      (stallStCommit),
//`else
  .stallStCommit_i      (1'b0),
//`endif

  // When high, indicates a packet is being dispatched this cycle.
	.dispatchReady_i      (coreTop.activeList.dispatchReady_i),

	.alPacket_i           (alPacket),

	.alHead_o             (),
	.alTail_o             (),
	.alID_o               (),

	//.ctrlPacket_i         (ctrlPacket),

	//.ldVioPacket_i        (coreTop.activeList.ldVioPacket_i),
  //.memExcptPacket_i     (coreTop.activeList.memExcptPacket_i),
  //.disExcptPacket_i     (coreTop.activeList.disExcptPacket_i),
  .csrViolateFlag_i     (coreTop.activeList.csrViolateFlag_i),
  .interruptPending_i   (coreTop.activeList.interruptPending_i),

  .csr_epc_i            (coreTop.activeList.csr_epc_i),
  .csr_evec_i           (coreTop.activeList.csr_evec_i),
  .sretFlag_o           (),

	.activeListCnt_o      (),

	.amtPacket_o          (),
`ifdef PERF_MON
  .commitValid_o        (),
`endif
	.totalCommit_o        (totalCommit),
	.commitStore_o        (),
	.commitLoad_o         (),

	.commitCti_o          (),
	.actualDir_o          (),
	.ctrlType_o           (),

	.commitCsr_o          (),

	.recoverFlag_o        (),
	.recoverPC_o          (),

	.exceptionFlag_o      (),
	.exceptionPC_o        (),
	.exceptionCause_o     (),

	.loadViolation_o      ()
	);


always @(posedge clk)
begin: VERIFY_INSTRUCTIONS
    reg [`SIZE_RMT_LOG-1:0]      logDest      [`COMMIT_WIDTH-1:0];
    reg [`SIZE_PHYSICAL_LOG-1:0] phyDest      [`COMMIT_WIDTH-1:0];
    reg [`SIZE_DATA-1:0]         result       [`COMMIT_WIDTH-1:0];
    reg                          isBranch     [`COMMIT_WIDTH-1:0];
    reg                          isMispredict [`COMMIT_WIDTH-1:0];
    reg                          isCSR        [`COMMIT_WIDTH-1:0];
    reg                          commitValid  [`COMMIT_WIDTH-1:0];
    reg                          phyDestValid [`COMMIT_WIDTH-1:0];
    reg                          isFission    [`COMMIT_WIDTH-1:0];
    reg [`SIZE_PC-1:0]           lastCommitPC;
    int                          checkPassed;
    int                          htifRet;
    int i;

    loggingOn = get_logging_mode();
    checkPassed = 1;

    //totalCommit = coreTop.activeList.totalCommit_o;
    for (i = 0; i < `COMMIT_WIDTH; i++)
    begin
        commitPC[i]     = dataAl[i].pc;
        logDest[i]      = dataAl[i].logDest;
        phyDest[i]      = dataAl[i].phyDest;
        result[i]       = PHYSICAL_REG[phyDest[i]];
  
        commitValid[i]  = (totalCommit >= (i+1)) ? 1'h1 : 1'h0;
        phyDestValid[i] = dataAl[i].phyDestValid;
        isFission[i]    = ctrlAl[i][3] & commitReady[i];
        isBranch[i]     = ctrlAl[i][5];

        isMispredict[i] = ctrlAl[i][0] & ctrlAl[i][5];

        isCSR[i]        = dataAl[i].isCSR;
    end

    //if(coreTop.activeList.totalCommit >= 0)
    if(totalCommit >= 0)
      idleCycles = 0;
    else
      idleCycles += 1;

    if(verifyCommits)
    begin
      // No need to skip instructions when SCRATCH PAD is the active source of instructions.
      // When SCRATCH  PAD is bypassed, skip the required number of instructions.
      if (commitValid[0] && (skip_instructions != 0) && !INST_SCRATCH_ENABLED)
      begin
          //skip_instructions = skip_instructions - coreTop.activeList.totalCommit;
          skip_instructions = skip_instructions - totalCommit;
      end
      else
      begin
          //if (lastCommitPC == commitPC[0] && commitValid[0])
          //begin
          //    lastCommitPC = commitPC[0];
          //end
          //else
          //begin
            for(i = 0; i < `COMMIT_WIDTH; i++)
            begin
              if(!INST_SCRATCH_ENABLED) // Controlled in the testbench
              begin
                if (commitValid[i])
                begin 
                  //if csr instruction and wrEn valid
                  // Commit the CSR write in the DPI simulator before comparing
                  // state and checking the instruction.
                  if(isCSR[i] & coreTop.supregisterfile.commitReg_i)
                  begin
                    set_pcr(coreTop.supregisterfile.regWrAddrCommit,coreTop.supregisterfile.regWrDataCommit);
                  end
                  //// Any CSR instruction that causes state to serialize, should pop
                  //// an extra debug buffer entry
                  //if(isCSR[i] & (coreTop.supregisterfile.regRdAddrChkpt == `CSR_CYCLE) & coreTop.supregisterfile.regRdChkptValid)
                  //begin
                  //  checkPassed = checkInstruction(CYCLE_COUNT,commitPC[i],0,0,0);
                  //  instRetired += 1;
                  //  set_pcr(12'h506,get_pcr(12'h506)+1); // Increment inst count in DPI
                  //  set_csr_in_rtl(`CSR_COUNT,get_csr_from_rtl(`CSR_COUNT)+1);
                  //end
                  // If SRET instruction, set the correct status in DPI sim
                  if(coreTop.supregisterfile.sretFlag_i)
                  begin
                    set_pcr(`CSR_STATUS,coreTop.supregisterfile.csr_status_next);
                  end
                  lastCommitPC = commitPC[i];
                  checkPassed = checkPassed & checkInstruction(CYCLE_COUNT,COMMIT_COUNT,commitPC[i],logDest[i],result[i],isFission[i]);
                  instRetired += 1;
                  set_pcr(12'h506,get_pcr(12'h506)+1); // Increment inst count in DPI
                  // If INTERLEAVE number of insts have been retired or those many idle cycles, 
                  // tick the HTIF to stay consistent with ISA sim.
                  if(instRetired == INTERLEAVE || idleCycles == INTERLEAVE)
                  begin
                    instRetired = 0;
                    htif_tick(htifRet);
                  end
                  else
                  begin
                    // Should not check state in case of an HTIF since the
                    // state is not yet updated in this cycle.
                    checkPassed = checkPassed & check_csr_with_dpi();
                  end
                  

                end
              end
              else
              begin
  	            if (commitValid[i]) 
  	  	          begin	
  	  		          lastCommitPC = commitPC[i];
  	  		          //if (coreTop.activeList.dataAl[i].phyDestValid)
  	  		          if (phyDestValid[i])
                  	begin	
                 	 		//$display("%x R[%d] P[%d] <- 0x%08x", 
                 	 		//  coreTop.activeList.commitPC[i],
  	             		  //  coreTop.activeList.logDest[i],
                     	//  coreTop.activeList.phyDest[i],
  	             		  //  result[i]);
                 	 		$display("%x R[%d] P[%d] <- 0x%08x", 
                 	 		  commitPC[i],
  	             		    logDest[i],
                     	  phyDest[i],
  	             		    result[i]);
                   	end
  	          	    else
               			  //$display("%x",coreTop.activeList.commitPC[0]); 
               			  $display("%x",commitPC[0]); 
  	    	        end
  	          end // INST_SCRATCH_ENABLED
            end // for (coommit_width)
          //end
        end // skip instructions

      if(!checkPassed)
        //#100 $display("Waiting for the end to come!");
	      $stop();

 	  end // verifyCommits
end

`include "taskLib.sv"

`ifdef PRINT_EN
  `include "debugPrints.sv"
`endif

`ifdef GATE_SIM
  `include "gateSimDebug.sv"
`endif

`ifdef GSHARE
  `include "Gshare_Behavioral.sv"
`endif //GSHARE

// Convert from packed to unpacked array
`ifdef GATE_SIM
  always @(*)
  begin
    int i;
    for(i = 0; i < `FETCH_WIDTH; i++)
    begin
      instPC[i] = instPC_gate[(`SIZE_PC*(`FETCH_WIDTH-i)-1) -: `SIZE_PC];
      inst_gate[(`SIZE_INSTRUCTION*(`FETCH_WIDTH-i)-1) -: `SIZE_INSTRUCTION] = inst[i];
    end
  end
`endif

always @(dcFlushDone)
begin
  if(dcFlushDone)
    dcFlush = 1'b0;
end

// Instantiation of the desig under test

Core_OOO coreTop(

    .clk                                (clk),
    .reset                              (reset),
    .resetFetch_i                       (resetFetch), 
    .toggleFlag_o                       (toggleFlag),

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
    //.instCacheBypass_i                  (instCacheBypass   ),
    .icScratchModeEn_i                  (icScratchModeEn   ),

    .icScratchWrAddr_i                  ($random%1024),
    .icScratchWrEn_i                    (1'b0),
    .icScratchWrData_i                  (8'bxxxx),
    .icScratchRdData_o                  (),

    .icFlush_i                          (icFlush),
    .icFlushDone_o                      (icFlushDone),
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

    .dcScratchWrAddr_i                  ($random%1024),
    .dcScratchWrEn_i                    (1'b0),
    .dcScratchWrData_i                  (8'bxxxx),
    .dcScratchRdData_o                  (),

    .dcFlush_i                          (dcFlush),
    .dcFlushDone_o                      (dcFlushDone),
`endif    

`ifdef DYNAMIC_CONFIG
    .stallFetch_i                       (stallFetch), 
    .fetchLaneActive_i                  (fetchLaneActive), 
    .dispatchLaneActive_i               (dispatchLaneActive), 
    .issueLaneActive_i                  (issueLaneActive), 
    .execLaneActive_i                   (issueLaneActive),
    .saluLaneActive_i                   (saluLaneActive),
    .caluLaneActive_i                   (caluLaneActive),
    .commitLaneActive_i                 (commitLaneActive), 
    .rfPartitionActive_i                (rfPartitionActive),
    .alPartitionActive_i                (alPartitionActive),
    .lsqPartitionActive_i               (lsqPartitionActive),
    .iqPartitionActive_i                (iqPartitionActive),
    .ibuffPartitionActive_i             (ibuffPartitionActive),
    .reconfigureCore_i                  (reconfigureCore),
    .reconfigDone_o                     (reconfigDone),
`endif
`ifdef PERF_MON
    .perfMonRegAddr_i                   (perfMonRegAddr),
    .perfMonRegData_o                   (perfMonRegData),
    .perfMonRegRun_i                    (perfMonRegRun),
    .perfMonRegClr_i                    (perfMonRegClr),
    .perfMonRegGlobalClr_i              (perfMonRegGlobalClr),
`endif

    .startPC_i                          (startPC),

  `ifdef GATE_SIM
    .instPC_o                           (instPC_gate),
    .inst_i                             (inst_gate),  // Send Xs to make sure this is not source 
  `else
    .instPC_o                           (instPC),
    .inst_i                             (inst),  // Send Xs to make sure this is not source 
  `endif
    .fetchReq_o                         (instReq), //Useful in case of CHIP simulations
    .fetchRecoverFlag_o                 (), //Useful in case of CHIP simulations
    //.instValid_i                        (instCacheBypass ? 1'b1 : 1'bx), //Constant in case of unit simulation, not in case of CHIP simulation
    .instValid_i                        (1'b1), //Constant in case of unit simulation, not in case of CHIP simulation
    .instException_i                    (instException),

    .ldAddr_o                           (ldAddr),
    .ldData_i                           (ldData),
    .ldDataValid_i                      (ldEn), //Loopback
    .ldEn_o                             (ldEn),
    .ldException_i                      (ldException),

    .stAddr_o                           (stAddr),
    .stData_o                           (stData),
    .stEn_o                             (stEn),
    .stException_i                      (stException),

    .ldStSize_o                         (ldStSize),

    .resetDone_o                        (coreResetDone),

    .debugPRFAddr_i                     (debugPRFAddr),
    .debugPRFWrData_i                   (debugPRFWrData),             
    .debugPRFWrEn_i                     (debugPRFWrEn),
    .debugPRFRdData_o                   (debugPRFRdData),

    .debugAMTAddr_i                     ({`SIZE_RMT_LOG{1'b0}}),

    /* Initialize the PRF from top */
    .dbAddr_i                           ({`SIZE_PHYSICAL_LOG{1'b0}}),
    .dbData_i                           ({`SIZE_DATA{1'b0}}),
    .dbWe_i                             (1'b0)

 );

memory_hier mem (
    .icClk                              (clk),
    .dcClk                              (clk),
    .reset                              (reset),

    .icPC_i                             (instPC),
    .icInstReq_i                        (instReq & (INST_SCRATCH_ENABLED ? 1'b0 : 1'b1)), //Mask requests to prevent crash
    .icInst_o                           (inst),
    .icException_o                      (instException),

  `ifdef INST_CACHE
    .ic2memReqAddr_i                    (ic2memReqAddr),
    .ic2memReqValid_i                   (ic2memReqValid),
    .mem2icTag_o                        (mem2icTag), 
    .mem2icIndex_o                      (mem2icIndex),     
    .mem2icData_o                       (mem2icData),      
    .mem2icRespValid_o                  (mem2icRespValid), 
  `endif

  `ifdef DATA_CACHE
    .dc2memLdAddr_i                     (dc2memLdAddr     ), // memory read address
    .dc2memLdValid_i                    (dc2memLdValid    ), // memory read enable
                                                           
    .mem2dcLdTag_o                      (mem2dcLdTag      ), // tag of the incoming datadetermine
    .mem2dcLdIndex_o                    (mem2dcLdIndex    ), // index of the incoming data
    .mem2dcLdData_o                     (mem2dcLdData     ), // requested data
    .mem2dcLdValid_o                    (mem2dcLdValid    ), // indicates the requested data is ready
                                                           
    .dc2memStAddr_i                     (dc2memStAddr     ), // memory read address
    .dc2memStData_i                     (dc2memStData     ), // memory read address
    .dc2memStByteEn_i                   (dc2memStByteEn   ), // memory read address
    .dc2memStValid_i                    (dc2memStValid    ), // memory read enable
                                                           
    .mem2dcStComplete_o                 (mem2dcStComplete ),
  `endif    
  
    .ldAddr_i                           (ldAddr),
    .ldData_o                           (ldData),
    .ldEn_i                             (ldEn & (DATA_SCRATCH_ENABLED ? 1'b0 : 1'b1)), //Mask En to prevent crash
    .ldException_o                      (ldException),

    .stAddr_i                           (stAddr),
    .stData_i                           (stData),
    .stEn_i                             (stEn & {8{DATA_SCRATCH_ENABLED ? 1'b0 : 1'b1}}), //Mask En to prevent crash
    .stException_o                      (stException),

    .ldStSize_i                         (ldStSize)
);



endmodule

module ANTENNATF(
  input A
  );
endmodule
