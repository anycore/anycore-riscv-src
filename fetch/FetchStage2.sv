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

module FetchStage2(

    input                            clk,
    input                            reset,
	  input                            resetRams_i,

    input                            recoverFlag_i,
    input                            exceptionFlag_i,
    input                            stall_i,

`ifdef DYNAMIC_CONFIG
    input [`FETCH_WIDTH-1:0]         fetchLaneActive_i,
`endif

    input                            fs1Ready_i,
    input  [`SIZE_PC-1:0]            addrRAS_i,
    input  [1:0]                     predCounter_i [0:`FETCH_WIDTH-1],

    input  fs2Pkt                    fs2Packet_i [0:`FETCH_WIDTH-1],

    input  [`SIZE_PC-1:0]            exeCtrlPC_i,
    input  [`BRANCH_TYPE_LOG-1:0]        exeCtrlType_i,
    input  [`SIZE_CTI_LOG-1:0]       exeCtiID_i,
    input  [`SIZE_PC-1:0]            exeCtrlNPC_i,
    input                            exeCtrlDir_i,
    input                            exeCtrlValid_i,
    input  [`COMMIT_WIDTH-1:0]       commitCti_i,

    output decPkt                    decPacket_o [0:`FETCH_WIDTH-1],

    output                           fs2RecoverFlag_o,
    output [`SIZE_PC-1:0]            fs2RecoverPC_o,
    output                           fs2MissedReturn_o,
    output                           fs2MissedCall_o,
    output [`SIZE_PC-1:0]            fs2CallPC_o,

    output [`SIZE_PC-1:0]            updatePC_o,
    output [`SIZE_PC-1:0]            updateNPC_o,
    output [`BRANCH_TYPE_LOG-1:0]        updateCtrlType_o,
    output                           updateDir_o,
    output [1:0]                     updateCounter_o,
    output                           updateEn_o,
    output                           fs2Ready_o,

`ifdef USE_GSHARE_BPU
	  input  [`SIZE_CNT_TBL_LOG-1:0]   predIndex_i [0:`FETCH_WIDTH-1],
    output [`SIZE_CNT_TBL_LOG-1:0]   updateIndex_o,
    output reg [`FETCH_WIDTH-1:0]    specBHRCtrlVect_o,
`endif  

    // If CTI Queue is full, further Inst fetching should be stalled
    output                           ctiQueueFull_o,
    output                           ctiqRamReady_o
    );


reg  [`FETCH_WIDTH-1:0]            validVect;
reg  [`FETCH_WIDTH-1:0]            validCtrlVect;

wire                               ctiQueueFull;

reg  [`BRANCH_TYPE_LOG-1:0]            ctrlType     [0:`FETCH_WIDTH-1];
reg                                condBranch   [0:`FETCH_WIDTH-1];
reg  [`SIZE_CTI_LOG-1:0]           ctiID        [0:`FETCH_WIDTH-1];


reg  [`SIZE_PC-1:0]                predNPC      [0:`FETCH_WIDTH-1];
wire [`SIZE_PC-1:0]                predNPC_t    [0:`FETCH_WIDTH-1];
`ifdef DYNAMIC_CONFIG
reg                                ctrlVect     [0:`FETCH_WIDTH-1];
wire                               ctrlVect_t   [0:`FETCH_WIDTH-1];
`else
wire                               ctrlVect     [0:`FETCH_WIDTH-1];
`endif

`ifdef USE_GSHARE_BPU
always_comb
begin
  int i;
  //TODO: Change to ValidCtrlVect but this might have much worse timing
  // There are two ways you can update the branch outcomes in the specBHR
  // 1) Update all branches except RETURN statements
  // 2) Update all branches, even RETURN statements and let the counters
  //    get saturated at always TAKEN
  for(i = 0; i < `FETCH_WIDTH; i++)
    //specBHRCtrlVect_o[i] = ctrlVect[i] & ~(ctrlType[i] == `RETURN);
    specBHRCtrlVect_o[i] = ctrlVect[i] & (ctrlType[i] == `COND_BRANCH);
end    
`endif

/* The CtrlQueue (CTI) is a buffer for control instructions.
 * They are reserved an entry and assigned an ID in FetchStage2.
 * Their PC, NPC, ctrlType and direction are sent from the Writeback stage.
 * When the ActiveList commits a control instruction, its data is popped
 * from the CtrlQueue and updates the BTB/BP. */

CtrlQueue ctiQueue(
    .clk              (clk),
    .reset            (reset),
    .resetRams_i      (resetRams_i),

    .stall_i          (stall_i),
    .recoverFlag_i    (recoverFlag_i),
    .exceptionFlag_i  (exceptionFlag_i),
    .fs1Ready_i       (fs1Ready_i),

    .ctrlVect_i       (validCtrlVect),
    .predCounter_i    (predCounter_i),

    .ctiID_o          (ctiID),

    .exeCtrlPC_i      (exeCtrlPC_i),
    .exeCtrlType_i    (exeCtrlType_i),
    .exeCtiID_i       (exeCtiID_i),
    .exeCtrlNPC_i     (exeCtrlNPC_i),
    .exeCtrlDir_i     (exeCtrlDir_i),
    .exeCtrlValid_i   (exeCtrlValid_i),
    .commitCti_i      (commitCti_i),

    .updatePC_o       (updatePC_o),
    .updateNPC_o      (updateNPC_o),
    .updateCtrlType_o (updateCtrlType_o),
    .updateDir_o      (updateDir_o),
    .updateCounter_o  (updateCounter_o),
    .updateEn_o       (updateEn_o),
`ifdef USE_GSHARE_BPU
	  .predIndex_i      (predIndex_i),
    .updateIndex_o    (updateIndex_o),
`endif  

    .ctiQueueFull_o   (ctiQueueFull),
    .ctiqRamReady_o   (ctiqRamReady_o)
);



  // LANE: Per lane logic
  genvar g;
  generate
  for (g = 0; g < `FETCH_WIDTH; g = g + 1)
  begin : preDecode_gen
  
  PreDecode_RISCV preDecode(
      .fs2Packet_i    (fs2Packet_i[g]),
 
`ifdef DYNAMIC_CONFIG
//      .ctrlInst_o     (ctrlVect_t[g]),
      .laneActive_i   (fetchLaneActive_i[g]), // Used only for power gating internaly
//`else
//      .ctrlInst_o     (ctrlVect[g]),
`endif
      .ctrlInst_o     (ctrlVect[g]),
      .predNPC_o      (predNPC_t[g]),
      .ctrlType_o     (ctrlType[g]),
      .condBranch_o   (condBranch[g])
      );

//// Mimic an isolation cell      
//`ifdef DYNAMIC_CONFIG      
//  always_comb
//  begin
//    ctrlVect[g] = fetchLaneActive_i[g] ? ctrlVect_t[g] : 1'b0;
//  end
//`endif
  
  end
  endgenerate

/* Identify any control instructions missed by the BTB in FetchStage1 and
 * recover accordingly */
reg                           fs2RecoverFlag;
reg                           fs2MissedReturn;
reg                           fs2MissedCall;
reg  [`SIZE_PC-1:0]           fs2RecoverPC;
reg  [`SIZE_PC-1:0]           fs2CallPC;

always_comb
begin : VALIDATE_BTB
    int i;
    reg  [`FETCH_WIDTH-1:0]     branchNT;
    reg  [`FETCH_WIDTH-1:0]     condBranchVect;
    reg  [`FETCH_WIDTH-1:0]     takenVect;


    // LANE: Per Lane logic
    for (i = 0; i < `FETCH_WIDTH; i++)
    begin
        /* predNPC */
        predNPC[i]          = predNPC_t[i];

        /* Vector identifying conditional branches */
        //condBranchVect[i]   = ctrlType[i] == `COND_BRANCH;
        condBranchVect[i]   = condBranch[i];

        /* Vector of taken control instructions (predicted or unconditional) */
        takenVect[i]        = ctrlVect[i] & (fs2Packet_i[i].predDir | ~condBranchVect[i]);

        /* Vector of not-taken conditional branches */
        branchNT[i]         = ctrlVect[i] & ~fs2Packet_i[i].predDir;

        /* Vector of valid instructions (invalidate instructions after a taken) */
        // fs2Packet_i[i].valid already considers fetchLaneActive and flows from Fetch1.
        //`ifdef DYNAMIC_CONFIG   
        //  validVect[i]      = fs2Packet_i[i].valid & fetchLaneActive_i[i];// & {`FETCH_WIDTH{1'h1}};
        //`else
          validVect[i]      = fs2Packet_i[i].valid; //{`FETCH_WIDTH{1'h1}};
        //`endif    

//`endif        

    end


    // LANE: Monolithic piece of logic

    /* recover PC in the case of a BTB miss */
    fs2RecoverPC          = predNPC_t[0];

    /* PC of missed call instruction */
    fs2CallPC             = fs2Packet_i[0].pc;

    /* recover fetch1 because of a BTB miss */
    fs2RecoverFlag        = 1'h0;

    /* Missed return instruction (pop RAS) */
    fs2MissedReturn       = 1'h0;

    /* Missed call instruction (push RAS) */
    fs2MissedCall         = 1'h0;


    /* Vector of valid control instructions */
    validCtrlVect         = branchNT;

    // TODO: This code has repetitions. Separate the
    // priority encoder and MUX logic and make the code 
    // smaller.
    casez ({{(8-`FETCH_WIDTH){1'b0}},takenVect}) //synopsys full_case parallel_case

        8'b00000000:
        begin
        end

        8'b???????1:
        begin
            fs2RecoverPC      = predNPC_t[0];
            fs2CallPC         = fs2Packet_i[0].pc;
            validVect         = 8'b00000001;
            validCtrlVect     = (8'b00000001 | {{8-`FETCH_WIDTH{1'b0}},branchNT}) & 8'b00000001;

            if (~fs2Packet_i[0].btbHit)
            begin
                fs2RecoverFlag  = 1'b1;

                if (ctrlType[0] == `RETURN)
                begin
                    predNPC[0]    = addrRAS_i;
                    fs2MissedReturn         = 1'b1;
                end

                else if (ctrlType[0] == `CALL)
                begin
                    fs2MissedCall = 1'b1;
                end
            end
        end

`ifdef FETCH_TWO_WIDE
        8'b??????10:
        begin
            fs2RecoverPC      = predNPC_t[1];
            fs2CallPC         = fs2Packet_i[1].pc;
            validVect         = 8'b00000011;
            validCtrlVect     = (8'b00000010 | {{8-`FETCH_WIDTH{1'b0}},branchNT}) & 8'b00000011;

            if (~fs2Packet_i[1].btbHit)
            begin
                fs2RecoverFlag  = 1'b1;

                if (ctrlType[1] == `RETURN)
                begin
                    predNPC[1]    = addrRAS_i;
                    fs2MissedReturn     = 1'b1;
                end

                else if (ctrlType[1] == `CALL)
                begin
                    fs2MissedCall = 1'b1;
                end
            end
        end
`endif

`ifdef FETCH_THREE_WIDE
        8'b?????100:
        begin
            fs2RecoverPC      = predNPC_t[2];
            fs2CallPC         = fs2Packet_i[2].pc;
            validVect         = 8'b00000111;
            validCtrlVect     = (8'b00000100 | {{8-`FETCH_WIDTH{1'b0}},branchNT}) & 8'b00000111;

            if (~fs2Packet_i[2].btbHit)
            begin
                fs2RecoverFlag  = 1'b1;

                if (ctrlType[2] == `RETURN)
                begin
                    predNPC[2]    = addrRAS_i;
                    fs2MissedReturn     = 1'b1;
                end

                else if (ctrlType[2] == `CALL)
                begin
                    fs2MissedCall = 1'b1;
                end
            end
        end
`endif

`ifdef FETCH_FOUR_WIDE
        8'b????1000:
        begin
            fs2RecoverPC      = predNPC_t[3];
            fs2CallPC         = fs2Packet_i[3].pc;
            validVect         = 8'b00001111;
            validCtrlVect     = (8'b00001000 | {{8-`FETCH_WIDTH{1'b0}},branchNT}) & 8'b00001111;

            if (~fs2Packet_i[3].btbHit)
            begin
                fs2RecoverFlag  = 1'b1;

                if (ctrlType[3] == `RETURN)
                begin
                    predNPC[3]    = addrRAS_i;
                    fs2MissedReturn     = 1'b1;
                end

                else if (ctrlType[3] == `CALL)
                begin
                    fs2MissedCall = 1'b1;
                end
            end
        end
`endif

`ifdef FETCH_FIVE_WIDE
        8'b???10000:
        begin
            fs2RecoverPC      = predNPC_t[4];
            fs2CallPC         = fs2Packet_i[4].pc;
            validVect         = 8'b00011111;
            validCtrlVect     = (8'b00010000 | {{8-`FETCH_WIDTH{1'b0}},branchNT}) & 8'b00011111;

            if (~fs2Packet_i[4].btbHit)
            begin
                fs2RecoverFlag  = 1'b1;

                if (ctrlType[4] == `RETURN)
                begin
                    predNPC[4]    = addrRAS_i;
                    fs2MissedReturn     = 1'b1;
                end

                else if (ctrlType[4] == `CALL)
                begin
                    fs2MissedCall = 1'b1;
                end
            end
        end
`endif

`ifdef FETCH_SIX_WIDE
        8'b??100000:
        begin
            fs2RecoverPC      = predNPC_t[5];
            fs2CallPC         = fs2Packet_i[5].pc;
            validVect         = 8'b00111111;
            validCtrlVect     = (8'b00100000 | {{8-`FETCH_WIDTH{1'b0}},branchNT}) & 8'b00111111;

            if (~fs2Packet_i[5].btbHit)
            begin
                fs2RecoverFlag  = 1'b1;

                if (ctrlType[5] == `RETURN)
                begin
                    predNPC[5]    = addrRAS_i;
                    fs2MissedReturn     = 1'b1;
                end

                else if (ctrlType[5] == `CALL)
                begin
                    fs2MissedCall = 1'b1;
                end
            end
        end
`endif

`ifdef FETCH_SEVEN_WIDE
        8'b?1000000:
        begin
            fs2RecoverPC      = predNPC_t[6];
            fs2CallPC         = fs2Packet_i[6].pc;
            validVect         = 8'b01111111;
            validCtrlVect     = (8'b01000000 | {{8-`FETCH_WIDTH{1'b0}},branchNT}) & 8'b01111111;

            if (~fs2Packet_i[6].btbHit)
            begin
                fs2RecoverFlag  = 1'b1;

                if (ctrlType[6] == `RETURN)
                begin
                    predNPC[6]    = addrRAS_i;
                    fs2MissedReturn     = 1'b1;
                end

                else if (ctrlType[6] == `CALL)
                begin
                    fs2MissedCall = 1'b1;
                end
            end
        end
`endif

`ifdef FETCH_EIGHT_WIDE
        8'b10000000:
        begin
            fs2RecoverPC      = predNPC_t[7];
            fs2CallPC         = fs2Packet_i[7].pc;
            validVect         = 8'b11111111;
            validCtrlVect     = (8'b10000000 | {{8-`FETCH_WIDTH{1'b0}},branchNT}) & 8'b11111111;

            if (~fs2Packet_i[7].btbHit)
            begin
                fs2RecoverFlag  = 1'b1;

                if (ctrlType[7] == `RETURN)
                begin
                    predNPC[7]    = addrRAS_i;
                    fs2MissedReturn     = 1'b1;
                end

                if (ctrlType[7] == `CALL)
                begin
                    fs2MissedCall = 1'b1;
                end
            end
        end
`endif

    default:begin
    end

    endcase
end

`ifdef SIM
//always_ff @(posedge clk)
//begin
//  if(fs2RecoverFlag_o)
//    $display("BTB Miss at PC: %0x Redirect PC: %0x",fs2CallPC,fs2RecoverPC);
//end
`endif

assign fs2RecoverFlag_o   = fs2RecoverFlag & ~stall_i & ~ctiQueueFull;
assign fs2MissedReturn_o  = fs2MissedReturn;
assign fs2MissedCall_o    = fs2MissedCall;
assign fs2RecoverPC_o     = fs2RecoverPC;
assign fs2CallPC_o        = fs2CallPC;

// LANE: Per Lane assign
always_comb
begin
    int i;
    for (i = 0; i < `FETCH_WIDTH; i++)
    begin
        decPacket_o[i].seqNo          = fs2Packet_i[i].seqNo;
        decPacket_o[i].exceptionCause = fs2Packet_i[i].exceptionCause;
        decPacket_o[i].exception      = fs2Packet_i[i].exception;
        decPacket_o[i].pc             = fs2Packet_i[i].pc;
        decPacket_o[i].inst           = fs2Packet_i[i].inst;
        decPacket_o[i].ctrlType       = ctrlType[i];
        decPacket_o[i].predNPC        = predNPC[i];
        decPacket_o[i].predDir        = fs2Packet_i[i].predDir;
        decPacket_o[i].ctiID          = ctiID[i];
        decPacket_o[i].valid          = validVect[i];
    end
end

assign ctiQueueFull_o     = ctiQueueFull;
assign fs2Ready_o         = fs1Ready_i & ~ctiQueueFull;

endmodule

