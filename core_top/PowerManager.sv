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

module PowerManager(

    input			                       clk,
    input                            reset,

    input [`FETCH_WIDTH-1:0]         fetchLaneActive_i,
    input [`DISPATCH_WIDTH-1:0]      dispatchLaneActive_i,
    input [`ISSUE_WIDTH-1:0]         issueLaneActive_i,
    input [`ISSUE_WIDTH-1:0]          execLaneActive_i,
    input [`ISSUE_WIDTH-1:0]          saluLaneActive_i,
    input [`ISSUE_WIDTH-1:0]          caluLaneActive_i,
    input [`COMMIT_WIDTH-1:0]        commitLaneActive_i,
    input [`NUM_PARTS_RF-1:0]        rfPartitionActive_i,
    input [`NUM_PARTS_AL-1:0]        alPartitionActive_i,
    input [`STRUCT_PARTS_LSQ-1:0]    lsqPartitionActive_i,
    input [`NUM_PARTS_IQ-1:0]        iqPartitionActive_i,
    input [`STRUCT_PARTS-1:0]        ibuffPartitionActive_i,

    input                            reconfigureCore_i,
    input                            stallFetch_i,
    input [`SIZE_ACTIVELIST_LOG:0]   activeListCnt_i,
    input                            ibuffInsufficientCnt_i,
    input [`FETCH_WIDTH-1:0]         fs1Fs2Valid_i,
    input [`FETCH_WIDTH-1:0]         fs2DecValid_i,
    input [`DISPATCH_WIDTH-1:0]      renDisValid_i,
    input [`DISPATCH_WIDTH-1:0]      instBufRenValid_i,
    input [`DISPATCH_WIDTH-1:0]      disIqValid_i,
    input                            consolidationDone_i,

    output reg [`FETCH_WIDTH-1:0]    fetchLaneActive_o,
    output reg [`DISPATCH_WIDTH-1:0] dispatchLaneActive_o,
    output reg [`ISSUE_WIDTH-1:0]    issueLaneActive_o,
    output reg [`ISSUE_WIDTH-1:0]     execLaneActive_o,
    output reg [`ISSUE_WIDTH-1:0]     saluLaneActive_o,
    output reg [`ISSUE_WIDTH-1:0]     caluLaneActive_o,
    output reg [`COMMIT_WIDTH-1:0]   commitLaneActive_o,
    output reg [`NUM_PARTS_RF-1:0]   rfPartitionActive_o,
    output reg [`NUM_PARTS_AL-1:0]   alPartitionActive_o,
    output reg [`STRUCT_PARTS_LSQ-1:0] lsqPartitionActive_o,
    output reg [`NUM_PARTS_IQ-1:0]   iqPartitionActive_o,
    output reg [`STRUCT_PARTS-1:0]   ibuffPartitionActive_o,

    output reg                       squashPipe_o,
    output reg                       reconfigureFlag_o,
    output reg                       loadNewConfig_o,
    output reg                       drainPipeFlag_o,

    output reg                       beginConsolidation_o,
    output reg                       reconfigDone_o,
    output reg                       pipeDrained_o

    );

  enum {INIT,DRAIN_PIPE,DRAIN_PIPE_BUFFER,BEGIN_CONSOLIDATION,CONSOLIDATE_REG,HALT_IBUFF,LOAD_CONFIG,FINISH} reconfigState,reconfigState_next;
  //localparam  INIT = 0;
  //localparam  DRAIN_PIPE = 1;
  //localparam  BEGIN_CONSOLIDATION = 2;
  //localparam  CONSOLIDATE_REG = 3;
  //localparam  FINISH = 4; 

  localparam  STATE_BITS = clog2(FINISH);

  //logic  [STATE_BITS-1:0] reconfigState;
  //logic  [STATE_BITS-1:0] reconfigState_next;
  logic                   alEmpty;
  logic                   stallFetch;
  logic                   reconfigDone;
  logic                   reconfigureCore_d1;
  logic                   reconfigurePulse;
  logic                   reconfigureFlag;
  logic                   loadConfig;
  logic                   loadConfig_d1;
  logic                   beginConsolidation;
  logic   [1:0]           count;
  logic   [1:0]           count_next;
  logic                   noValidInstInPipe;
  logic                   pipeEmpty;
  logic                   pipeDrained;

  assign reconfigurePulse   = reconfigureCore_i & ~reconfigureCore_d1;
  assign alEmpty            = (activeListCnt_i == 0);
  assign noValidInstInPipe  = ~((|fs1Fs2Valid_i) | (|fs2DecValid_i) | (|instBufRenValid_i) | (|renDisValid_i) | (|disIqValid_i));
  assign pipeEmpty          =  alEmpty & noValidInstInPipe & ibuffInsufficientCnt_i;

  
  always_ff @(posedge clk or posedge reset)
  begin
    if(reset)
    begin
      beginConsolidation_o  <=  1'b0;
      drainPipeFlag_o       <=  1'b0;  // Override using external stallFetch
      reconfigDone_o        <=  1'b0;
      reconfigureCore_d1    <=  1'b0;
      reconfigureFlag_o     <=  1'b0;
      pipeDrained_o         <=  1'b0;
      loadNewConfig_o       <=  1'b0;
    end
    else
    begin
      beginConsolidation_o  <=  beginConsolidation;
      drainPipeFlag_o       <=  stallFetch | stallFetch_i;  // Override using external stallFetch
      //drainPipeFlag_o       <=  stallFetch_i;  // Override using external stallFetch
      reconfigDone_o        <=  reconfigDone;
      reconfigureCore_d1    <=  reconfigureCore_i;
      reconfigureFlag_o     <=  reconfigureFlag;
      pipeDrained_o         <=  pipeDrained;
      loadNewConfig_o       <=  loadConfig;
    end
  end

  always_ff @(posedge clk or posedge reset)
  begin
    if(reset)
    begin
      fetchLaneActive_o       <=  4'b1111;  
      dispatchLaneActive_o    <=  4'b1111;  
      issueLaneActive_o       <=  5'b11111; // First 3 exec pipes must be powered up on reset 
      execLaneActive_o        <=  5'b11111; // First 3 exec pipes must be powered up on reset 
      saluLaneActive_o        <=  5'b11111; // First 3 exec pipes must be powered up on reset 
      caluLaneActive_o        <=  5'b00111; // First 3 exec pipes must be powered up on reset 
      commitLaneActive_o      <=  4'b1111;    
      rfPartitionActive_o     <=  4'b1111;
      alPartitionActive_o     <=  4'b1111;
      lsqPartitionActive_o    <=  2'b11;    
      iqPartitionActive_o     <=  4'b1111;    
      ibuffPartitionActive_o  <=  4'b1111;    
    end
    else if(loadNewConfig_o)
    begin
      fetchLaneActive_o       <=   fetchLaneActive_i     ;
      dispatchLaneActive_o    <=   dispatchLaneActive_i  ;
      issueLaneActive_o       <=   issueLaneActive_i     ;
      execLaneActive_o        <=   execLaneActive_i      ;
      saluLaneActive_o        <=   saluLaneActive_i      ;
      caluLaneActive_o        <=   caluLaneActive_i      ;
      commitLaneActive_o      <=   commitLaneActive_i    ;
      rfPartitionActive_o     <=   rfPartitionActive_i   ;
      alPartitionActive_o     <=   alPartitionActive_i   ;
      lsqPartitionActive_o    <=   lsqPartitionActive_i  ;
      iqPartitionActive_o     <=   iqPartitionActive_i   ;
      ibuffPartitionActive_o  <=   ibuffPartitionActive_i;
    end
  end


  always_ff @(posedge clk or posedge reset)
  begin
    if(reset)
    begin
      reconfigState <=  INIT;
      count         <=  2'b00;
    end
    else
    begin
      reconfigState   <=  reconfigState_next;
      count           <=  count_next;
    end
  end
  
  always_comb
  begin
    reconfigState_next  = reconfigState;
    reconfigureFlag     = 1'b0;
    loadConfig          = 1'b0;
    squashPipe_o        = 1'b0;
    stallFetch          = 1'b0;
    beginConsolidation  = 1'b0;
    reconfigDone        = 1'b0;
    pipeDrained         = 1'b0;
    count_next          = count;
    case(reconfigState)
      INIT:begin
        if(reconfigurePulse)
        begin
          reconfigState_next  = DRAIN_PIPE;
          squashPipe_o        = 1'b1;
        end
      end
      DRAIN_PIPE:begin
        stallFetch            = 1'b1;
        reconfigureFlag       = 1'b0;
        beginConsolidation    = 1'b0;
        reconfigDone          = 1'b0;
        pipeDrained           = 1'b0;
        if(pipeEmpty)
        begin
          reconfigState_next  = DRAIN_PIPE_BUFFER;
        end
      end
      DRAIN_PIPE_BUFFER:begin
        stallFetch            = 1'b1;
        reconfigureFlag       = 1'b0;
        beginConsolidation    = 1'b0;
        reconfigDone          = 1'b0;
        pipeDrained           = 1'b1;
        count_next            = count + 1;
        if(count == 3)
        begin
          reconfigState_next  = BEGIN_CONSOLIDATION;
        end
      end
      BEGIN_CONSOLIDATION:begin
        stallFetch            = 1'b1;
        reconfigureFlag       = 1'b0;
        beginConsolidation    = 1'b1;
        reconfigDone          = 1'b0;
        pipeDrained           = 1'b1;
        reconfigState_next    = CONSOLIDATE_REG;
      end
      CONSOLIDATE_REG:begin
        stallFetch            = 1'b1;
        reconfigureFlag       = 1'b0;
        beginConsolidation    = 1'b0;
        reconfigDone          = 1'b0;
        pipeDrained           = 1'b1;
        if(consolidationDone_i)
        begin
          reconfigState_next  = HALT_IBUFF;
        end
      end
      // Reset RMT, AMT, FreeList and PhyRegValidVect
      HALT_IBUFF:begin
        stallFetch            = 1'b1;
        reconfigureFlag       = 1'b1; //Asserted for 4 cycles
        reconfigDone          = 1'b0;
        pipeDrained           = 1'b1;
        count_next            = count + 1;
        if(count == 3)
        begin
          reconfigState_next    = LOAD_CONFIG;
        end
      end
      // Load the config after resetting everything and quiescing the pipe
      LOAD_CONFIG:begin
        stallFetch            = 1'b1;
        reconfigureFlag       = 1'b1; //Asserted for 4 cycles
        loadConfig            = 1'b1;
        reconfigDone          = 1'b0;
        pipeDrained           = 1'b1;
        count_next            = count + 1;
        if(count == 3)
        begin
          reconfigState_next    = FINISH;
        end
      end
      FINISH:begin
        reconfigureFlag       = 1'b0;
        beginConsolidation    = 1'b0;
        reconfigDone          = 1'b1; //Asserted for 4 cycles
        pipeDrained           = 1'b1;
        count_next            = count + 1;
        if(count == 3)
        begin
          reconfigState_next    = INIT; 
        end
      end
      default:begin
          reconfigState_next  = INIT;
      end
    endcase
  end



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
