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

//`include "structs.svh"

module FetchStage1(

    input                            clk,
    input                            reset,
	  input                            resetRams_i,
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

    /* Control signals for stalling, flushing and reseting the module. */
    input                            stall_i,

    input                            recoverFlag_i,
    input  [`SIZE_PC-1:0]            recoverPC_i,

    input                            exceptionFlag_i,
    input  [`SIZE_PC-1:0]            exceptionPC_i,

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

    /* Update signals are used to update the Branch Predictor and BTB. The update signal comes
     * from CTI Queue in the order of program sequence for the control instructions. */
    input  [`SIZE_PC-1:0]            updatePC_i,
    input  [`SIZE_PC-1:0]            updateNPC_i,
    input  [`BRANCH_TYPE_LOG-1:0]        updateBrType_i,
    input                            updateDir_i,
    input  [1:0]                     updateCounter_i,
    input                            updateEn_i,

    /* Send the RAS TOS to FS2. Missed return instructions need their predNPC */
    output [`SIZE_PC-1:0]            addrRAS_o,
    output [1:0]                     predCounter_o [0:`FETCH_WIDTH-1],

`ifdef USE_GSHARE_BPU    
	  output [`SIZE_CNT_TBL_LOG-1:0]   predIndex_o [0:`FETCH_WIDTH-1],
    input  [`SIZE_CNT_TBL_LOG-1:0]   updateIndex_i,   // Also contains bank information embedded
    input  [`FETCH_WIDTH-1:0]        specBHRCtrlVect_i,
`endif    
    
    output reg                       fetchReq_o,
    output [`SIZE_PC-1:0]            instPC_o [0:`FETCH_WIDTH-1],
    input  [`SIZE_INSTRUCTION-1:0]   inst_i   [0:`FETCH_WIDTH-1],
    input                            instValid_i, //Indicates whether the instruction stream
                                                  // is valid in a particular cycle 
    input  exceptionPkt              instException_i,

    /* fs1Ready_o indicates the fs2Packets are valid */
    output                           fs1Ready_o,

    /* Packets going to FS2 */
    output fs2Pkt                    fs2Packet_o [0:`FETCH_WIDTH-1],
    
    output                           btbRamReady_o,
    output                           bpRamReady_o,
    output                           rasRamReady_o
    );


/* Defining Program Counter register. */
reg  [`SIZE_PC-1:0]         PC;
reg  [`SIZE_PC-1:0]         nextPC;
reg  [`SIZE_PC-1:0]         predNPC;

btbPkt                      btbPacket [0:`FETCH_WIDTH-1];

/* wire and register definition for combinational logic */
wire                        updateBTB;
wire                        updateBPB;

wire  [`FETCH_WIDTH-1:0]    predDir;

reg  [`SIZE_INSTRUCTION-1:0]inst   [0:`FETCH_WIDTH-1];
reg  [0:`FETCH_WIDTH-1]     instValid;
reg  [`SIZE_PC-1:0]         instPC [0:`FETCH_WIDTH-1];
reg                         fetchReq;
exceptionPkt                instException;

reg                         pushRAS;
reg                         popRAS;
reg  [`SIZE_PC-1:0]         pushAddr;
wire [`SIZE_PC-1:0]         addrRAS;

reg [`FETCH_WIDTH_LOG:0] numFetchLaneActive;
always_comb
begin

`ifdef DYNAMIC_CONFIG    
  int i;
  numFetchLaneActive = 0;
  for(i = 0; i < `FETCH_WIDTH; i++)
    numFetchLaneActive = numFetchLaneActive + fetchLaneActive_i[i];
`else
  numFetchLaneActive = `DISPATCH_WIDTH;  // Constant and logic will be optimized
`endif
end


/* updateBPB signal is brach predictor table update enabler. This is 1
 * only if control instruction type is conditional branch.
 * In case of conditional branches, update the BTB only if the direction is
 * Taken.
 * The update signals come from CTI Queue in program order.
 */
assign updateBPB = (updateEn_i & updateBrType_i[0] & updateBrType_i[1]);

// UpdateDir_i can be high for several cycles. Masking
// updateEn_i to make sure that the BTB RAM is written only
// once.
assign updateBTB = updateDir_i & updateEn_i;


// NOTE: Need to power gate the BTB_RAMs inside
// The hit logic is gated by fetchLaneActive 
/* Instantiating Branch prediction and BTB Unit. */
BTB btb(

    .clk                (clk),
  `ifdef DYNAMIC_CONFIG
    .reset              (reset | resetFetch_i | reconfigureCore_i), //Needs to flush as tags across configurations are not unique
  `else
    .reset              (reset | resetFetch_i), //Needs to flush as tags across configurations are not unique
  `endif
  .resetRams_i          (resetRams_i),

    .stall_i            (stall_i),

`ifdef DYNAMIC_CONFIG
    .fetchLaneActive_i  (fetchLaneActive_i),
`endif

    .PC_i               (PC),

    .updateEn_i         (updateBTB),
    .updatePC_i         (updatePC_i),
    .updateBrType_i     (updateBrType_i),
    .updateNPC_i        (updateNPC_i),

    .btbPacket_o        (btbPacket),
    .btbRamReady_o      (btbRamReady_o)
    );

 
`ifndef USE_GSHARE_BPU

// TODO: Add the laneActive logic
BranchPrediction bp (

    .clk                (clk),
    .reset              (reset | resetFetch_i),
    .resetRams_i        (resetRams_i),

`ifdef DYNAMIC_CONFIG
    .fetchLaneActive_i  (fetchLaneActive_i),
`endif

    .PC_i               (PC),

    .updatePC_i         (updatePC_i),
    .updateDir_i        (updateDir_i),
    .updateCounter_i    (updateCounter_i),
    .updateEn_i         (updateBPB),

    .predDir_o          (predDir),
    .predCounter_o      (predCounter_o),
    .bpRamReady_o       (bpRamReady_o)
    );

`else    

BranchPredictionGshare bp (

    .clk                (clk),
    .reset              (reset),

    .PC_i               (PC),
    .inst_i             (inst),

    .recoverFlag_i      (recoverFlag_i),
    .exceptionFlag_i    (exceptionFlag_i),
    .fs2RecoverFlag_i   (fs2RecoverFlag_i),

    .btbPacket_i        (btbPacket),
    .specBHRCtrlVect_i  (specBHRCtrlVect_i),

    .updatePC_i         (updatePC_i),
    .updateIndex_i      (updateIndex_i),
    .updateDir_i        (updateDir_i),
    .updateCounter_i    (updateCounter_i),
    .updateEn_i         (updateBPB),

    .predDir_o          (predDir),
    .predCounter_o      (predCounter_o),
    .predIndex_o        (predIndex_o)
    );

`endif    // USE_GSHARE_BPU


/* Instantiating Return Address Stack (RAS). */
RAS ras(

    .clk                (clk),
    .reset              (reset | resetFetch_i),
    .resetRams_i        (resetRams_i),

    .recoverFlag_i      (recoverFlag_i),
    .exceptionFlag_i    (exceptionFlag_i),

    .stall_i            (stall_i),

    .pc_i               (PC),

    .updateEn_i         (updateEn_i),
    .updatePC_i         (updatePC_i),
    .updateBrType_i     (updateBrType_i),

    .fs2RecoverFlag_i   (fs2RecoverFlag_i),
    .fs2MissedCall_i    (fs2MissedCall_i),
    .fs2CallPC_i        (fs2CallPC_i),
    .fs2MissedReturn_i  (fs2MissedReturn_i),

    .pop_i              (popRAS),
    .push_i             (pushRAS),
    .pushAddr_i         (pushAddr),

    .addrRAS_o          (addrRAS),
    .rasRamReady_o      (rasRamReady_o)
    );



/* Instantiating Level-1 Instruction Cache. */
L1ICache l1icache(
    .clk                (clk),
    .reset              (reset),

    .PC_i               (PC),
    .fetchReq_i         (fetchReq & ~stall_i),

    .inst_o             (inst),
    .instValid_o        (instValid),
    .instException_o    (instException),

`ifdef DYNAMIC_CONFIG
    .fetchLaneActive_i  (fetchLaneActive_i),
    .stallFetch_i       (stallFetch_i),
`endif

`ifdef SCRATCH_PAD
    .instScratchAddr_i    (instScratchAddr_i),
    .instScratchWrData_i  (instScratchWrData_i),
    .instScratchWrEn_i    (instScratchWrEn_i),
    .instScratchRdData_o  (instScratchRdData_o),
    .instScratchPadEn_i   (instScratchPadEn_i),
`endif

`ifdef INST_CACHE
    .ic2memReqAddr_o      (ic2memReqAddr_o     ),     // memory read address
    .ic2memReqValid_o     (ic2memReqValid_o    ),     // memory read enable
    .mem2icTag_i          (mem2icTag_i         ),     // tag of the incoming data
    .mem2icIndex_i        (mem2icIndex_i       ),     // index of the incoming data
    .mem2icData_i         (mem2icData_i        ),     // requested data
    .mem2icRespValid_i    (mem2icRespValid_i   ),     // requested data is ready
    .icScratchModeEn_i    (icScratchModeEn_i),
        
    .icScratchWrAddr_i    (icScratchWrAddr_i),
    .icScratchWrEn_i      (icScratchWrEn_i  ),
    .icScratchWrData_i    (icScratchWrData_i),
    .icScratchRdData_o    (icScratchRdData_o),
    
`endif

    .icMiss_o             (icMiss_o),

    /** Raw interface to the testbench in the absence of caches **/
    .instPC_o             (instPC),
    .fetchReq_o           (fetchReq_o),

    .inst_i               (inst_i),
    .instValid_i          ({`FETCH_WIDTH{instValid_i}}),  // Used only in Cache/Scratch-Pad bypass mode
    .instException_i      (instException_i)
   );


/* Following logic generates the next PC. This is the priority encoder and higher priority
 * is given to any recovery from Next stage or Execute stage. The least priority is given
 * to PC plus 16.
 *
 * If there is BTB hit then the target address comes from BTB for the
 * non-return instruction else comes from the RAS for return instruction.
 */

reg [`FETCH_WIDTH_LOG:0]    numValidInsts;
reg [`FETCH_WIDTH-1:0]      takenVect;

// LANE: Per lane logic
always_comb
begin
    int i;
    reg                      nonCondBranch [`FETCH_WIDTH-1:0];

    for (i = 0; i < `FETCH_WIDTH; i = i + 1)
    begin
        nonCondBranch[i]  = btbPacket[i].ctrlType != `COND_BRANCH;
        // Redirect fetch towards anything that hit in the BTB and is either a non-conditional-branch or predicted taken
        // NOTE: BTB hit already considers fetchLaneActive bit
        // Only predictions for valid instructions in a bundle should be considered.
        takenVect[i]  = instValid[i] & btbPacket[i].hit & (predDir[i] | nonCondBranch[i]);
    end
end

// high when a taken control instruction is detected
logic                       predTaken;

// TODO: This is a priority logic. Upon deconfiguration,
// this will definitely have false paths. Those false paths
// need to be identified and annotated during timing analysis.

always_comb
begin : NEXT_PC

    predTaken     = 1'b0;
    // NOTE: Creates a MUX before nextPC logic in case of DYNAMIC_CONFIG.
    // Next PC must account for cache hit/miss and lies in the critical path.
    predNPC       = PC + `SIZE_INSTRUCTION_BYTE*numValidInsts; // numValidInsts already considers fetchLaneActive

    pushRAS       = 0;
    pushAddr      = PC + `SIZE_INSTRUCTION_BYTE;

    popRAS        = 0;

    // NOTE: If there's a cache miss (no valid instructions), takenVect = 0 because
    // instValid = 0. Hence predNPC = PC.
    casex (takenVect) //synopsys full_case parallel_case

        'b000000000:
        begin
        end

        'bx1:
        begin
            predTaken   = 1'b1;

            if (btbPacket[0].ctrlType == `RETURN)
            begin
                predNPC = addrRAS;
                popRAS  = 1'b1;
            end

            else
            begin
                predNPC = btbPacket[0].takenPC;

                if (btbPacket[0].ctrlType == `CALL)
                begin
                    pushRAS  = 1'b1;
                    pushAddr = PC + `SIZE_INSTRUCTION_BYTE;
                end
            end
        end

`ifdef FETCH_TWO_WIDE
        'bx10:
        begin
            predTaken   = 1'b1;

            if(btbPacket[1].ctrlType == `RETURN)
            begin
                predNPC = addrRAS;
                popRAS  = 1'b1;
            end

            else
            begin
                predNPC = btbPacket[1].takenPC;

                if (btbPacket[1].ctrlType == `CALL)
                begin
                    pushRAS  = 1'b1;
                    pushAddr = PC + 2*`SIZE_INSTRUCTION_BYTE;
                end
            end
        end
`endif

`ifdef FETCH_THREE_WIDE
        'bx100:
        begin
            predTaken   = 1'b1;

            if(btbPacket[2].ctrlType == `RETURN)
            begin
                predNPC = addrRAS;
                popRAS  = 1'b1;
            end

            else
            begin
                predNPC = btbPacket[2].takenPC;

                if (btbPacket[2].ctrlType == `CALL)
                begin
                    pushRAS  = 1'b1;
                    pushAddr = PC + 3*`SIZE_INSTRUCTION_BYTE;
                end
            end
        end
`endif

`ifdef FETCH_FOUR_WIDE
        'bx1000:
        begin
            predTaken   = 1'b1;

            if(btbPacket[3].ctrlType == `RETURN)
            begin
                predNPC = addrRAS;
                popRAS  = 1'b1;
            end
            else
            begin
                predNPC = btbPacket[3].takenPC;

                if (btbPacket[3].ctrlType == `CALL)
                begin
                    pushRAS  = 1'b1;
                    pushAddr = PC + 4*`SIZE_INSTRUCTION_BYTE;
                end
            end
        end
`endif

`ifdef FETCH_FIVE_WIDE
        'bx10000:
        begin
            predTaken   = 1'b1;

            if(btbPacket[4].ctrlType == `RETURN)
            begin
                predNPC = addrRAS;
                popRAS  = 1'b1;
            end

            else
            begin
                predNPC = btbPacket[4].takenPC;

                if (btbPacket[4].ctrlType == `CALL)
                begin
                    pushRAS  = 1'b1;
                    pushAddr = PC + 5*`SIZE_INSTRUCTION_BYTE;
                end
            end
        end
`endif

`ifdef FETCH_SIX_WIDE
        'bx100000:
        begin
            predTaken   = 1'b1;

            if(btbPacket[5].ctrlType == `RETURN)
            begin
                predNPC = addrRAS;
                popRAS  = 1'b1;
            end

            else
            begin
                predNPC = btbPacket[5].takenPC;

                if (btbPacket[5].ctrlType == `CALL)
                begin
                    pushRAS  = 1'b1;
                    pushAddr = PC + 6*`SIZE_INSTRUCTION_BYTE;
                end
            end
        end
`endif

`ifdef FETCH_SEVEN_WIDE
        'bx1000000:
        begin
            predTaken   = 1'b1;

            if(btbPacket[6].ctrlType == `RETURN)
            begin
                predNPC = addrRAS;
                popRAS  = 1'b1;
            end

            else
            begin
                predNPC = btbPacket[6].takenPC;

                if (btbPacket[6].ctrlType == `CALL)
                begin
                    pushRAS  = 1'b1;
                    pushAddr = PC + 7*`SIZE_INSTRUCTION_BYTE;
                end
            end
        end
`endif

`ifdef FETCH_EIGHT_WIDE
        8'b10000000:
        begin
            predTaken   = 1'b1;

            if(btbPacket[7].ctrlType == `RETURN)
            begin
                predNPC = addrRAS;
                popRAS  = 1'b1;
            end

            else
            begin
                predNPC = btbPacket[7].takenPC;

                if (btbPacket[7].ctrlType == `CALL)
                begin
                    pushRAS  = 1'b1;
                    pushAddr = PC + 8*`SIZE_INSTRUCTION_BYTE;
                end
            end
        end
`endif

    endcase
end


// This is used to generate the nextPC
// NOTE: instValid already considers fetchLaneActive in case of DYNAMIC_CONFIG
always_comb
begin
  int i;
  numValidInsts = 0;
  for(i = 0; i<`FETCH_WIDTH; i++)
    numValidInsts = numValidInsts + instValid[i];
end

/* Update the PC to (in decreasing priority):
 * (1) The starting PC of the program
 * (2) The recover PC from a misprediction
 * (3) The PC of an exception
 * (4) Popped PC from a missed return instruction
 * (5) Taken PC from a missed jump instruction
 * (6) nextPC
 * (7) PC
 */
// LANE: Monolithic logic
always_comb
begin
    if (reset)
    begin
        nextPC      = startPC_i;
    end
    else if(resetFetch_i)
    begin
        nextPC      = startPC_i;
    end
    else
    begin

      if (recoverFlag_i)
      begin
          nextPC      = recoverPC_i;
      end

      //else if (exceptionFlag_i)
      //begin
      //    nextPC      = recoverPC_i;
      //    //nextPC      = exceptionPC_i;
      //end

      else if (fs2RecoverFlag_i)
      begin
          if (fs2MissedReturn_i)
          begin
              nextPC    = addrRAS;
          end
          else
          begin
              nextPC    = fs2RecoverPC_i;
          end
      end

      else if (~stall_i)
      begin
        // Predicted NPC accounts for valid instructions, predicted taken branches
        // I-cache miss etc. For example, if there are no valid instructions in a 
        // cycle, predNPC = PC.
        nextPC  = predNPC;
      end

      // If stalled
      else
      begin
          nextPC   = PC;
      end

    end
end

// The Program Counter register - PC
always_ff @(posedge clk or posedge reset)
begin
    if(reset)
    begin
      PC      <= startPC_i;
    end
    else if(resetFetch_i)
    begin
      PC      <= startPC_i;
    end
    else
    begin
      PC      <= nextPC;
    end
end

//TODO: Stop fetching if there is a fetch exception until retire logic
// clears exception.

// Using PC to fetch instruction and PC
// changes in the next cycle of these conditions
// Hence this is a Flip-Flop
//`ifdef INST_CACHE
  always_ff @(posedge clk or posedge reset)
  begin
      if (reset)
          fetchReq      <= 1'h0;
      else if (resetFetch_i)
          fetchReq      <= 1'h0;
  `ifdef DYNAMIC_CONFIG
      else if (stallFetch_i)
          fetchReq      <= 1'h0;
  `endif
      else 
          fetchReq      <= 1'h1;
  end

//`else
//
//  // start a new icache request whenever nextPC changes
//  logic                   firstCycle;
//  
//  always_ff @(posedge clk)
//  begin
//      if (reset)
//          firstCycle      <= 1'h1;
//      else
//          firstCycle      <= 1'h0;
//  end
//
//
//  always_ff @(posedge clk or posedge reset)
//  begin
//      if (reset)
//          fetchReq      <= 1'h0;
//      else if (stallFetch_i)
//          fetchReq      <= 1'h0;
//      else if (firstCycle)
//          fetchReq      <= 1'h1;
//      else if (recoverFlag_i)
//          fetchReq      <= 1'h1;
//      else if (exceptionFlag_i)
//          fetchReq      <= 1'h1;
//      else if (fs2RecoverFlag_i)
//          fetchReq      <= 1'h1;
//      // instValid[0] must be high for predTaken or instValid[1] to be high so
//      // there's no need to test those cases here
//      else if (~stall_i & instValid)
//          fetchReq      <= 1'h1;
//      else
//          fetchReq      <= 1'h0;
//  end
//`endif  

reg [31:0]  seqNo [0:`FETCH_WIDTH-1];
reg [31:0]  nextSeqNo;
/* Used for debugging only. Comment out for synthesis */
`ifdef SIM
  always_ff @(posedge clk)
  begin
    if(reset)
      nextSeqNo <=  32'b0;
    else
      nextSeqNo <=  nextSeqNo + numValidInsts;
  end
  
  always_comb
  begin
    int i;
    seqNo[0] = nextSeqNo;
    for (i = 1; i < `FETCH_WIDTH; i++)
    begin
      `ifdef DYNAMIC_CONFIG
        seqNo[i] = seqNo[i-1] + (instValid[i] & fetchLaneActive_i[i]);
      `else
        seqNo[i] = seqNo[i-1] + instValid[i];
      `endif
    end
  end
`endif

/* FetchStage2 Packets */
// LANE: Per lane logic
always_comb
begin
    int i;

    for (i = 0; i < `FETCH_WIDTH; i++)
    begin
        fs2Packet_o[i].seqNo          = seqNo[i];
        fs2Packet_o[i].exceptionCause = instException.exceptionCause;
        fs2Packet_o[i].exception      = instException.exception;
        fs2Packet_o[i].pc             = instPC[i];
        fs2Packet_o[i].inst           = instValid[i] ? inst[i] : 'b0;
        fs2Packet_o[i].btbHit         = btbPacket[i].hit;
        fs2Packet_o[i].ctrlType       = btbPacket[i].ctrlType;
        fs2Packet_o[i].takenPC        = (btbPacket[i].ctrlType == `RETURN) ? addrRAS : btbPacket[i].takenPC;
        fs2Packet_o[i].predDir        = predDir[i];
        fs2Packet_o[i].valid          = instValid[i];
    end
end


assign instPC_o       = instPC;
// Indicates that no instructions are being fetched and
// the successive stages should not process any data in these
// bundles. instValid[0] is pulled low when stallFetch_i is asserted.
assign fs1Ready_o     = instValid[0]; 
assign addrRAS_o      = addrRAS;


endmodule
