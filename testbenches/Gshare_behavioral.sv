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


  //`define SMALL_GSHARE;
  `define SIZE_BPB 4096
  `ifdef SMALL_GSHARE
    `define SIZE_BPB_LOG 12
  `else
    `define SIZE_BPB_LOG 14
  `endif
  logic [`SIZE_PC-1:0]                gsharePredPC [0:`FETCH_WIDTH-1];
  logic [`SIZE_PC-1:0]                gshareUpdatePC;
  logic [31:0]        branchHistoryReg;
  logic [31:0]        retiredBranchHistoryReg;
  logic [31:0]        specBranchHistoryReg;
  logic [31:0]        specBranchHistoryReg_l1;
  //logic [31:0]        specBranchHistoryReg_prev;
  logic [31:0]        specBranchHistoryReg_next;
  logic [31:0]        specBranchHistoryRegFs2;
  logic [`SIZE_BPB-1:0][1:0] branchCounterTable0;
  `ifndef SMALL_GSHARE
    logic [`SIZE_BPB-1:0][1:0] branchCounterTable1;
    logic [`SIZE_BPB-1:0][1:0] branchCounterTable2;
    logic [`SIZE_BPB-1:0][1:0] branchCounterTable3;
  `endif
  logic [`FETCH_WIDTH_LOG-1:0][1:0]        instrType;
  logic [`SIZE_BPB_LOG-1:0]  gshareIndex_pred;
  logic [1:0]                predCount_pred;
  
  function logic get_gshare_pred;
    input [31:0]  instrPC;
    output[1:0]   predCount;
    logic [`SIZE_BPB_LOG-1:0]  gshareIndex;
    logic         predDir;
    
    gshareIndex = {3'b000,instrPC[31:3]} ^ specBranchHistoryReg_next;
    gshareIndex_pred = gshareIndex;
  `ifdef SMALL_GSHARE
      predCount   = branchCounterTable0[gshareIndex];
  `else
    case(gshareIndex[1:0])
      2'b00: predCount   = branchCounterTable0[gshareIndex[`SIZE_BPB_LOG-1:2]];
      2'b01: predCount   = branchCounterTable1[gshareIndex[`SIZE_BPB_LOG-1:2]];
      2'b10: predCount   = branchCounterTable2[gshareIndex[`SIZE_BPB_LOG-1:2]];
      2'b11: predCount   = branchCounterTable3[gshareIndex[`SIZE_BPB_LOG-1:2]];
    endcase
  `endif
    predCount_pred = predCount;
    predDir     = predCount > 1;
    specBranchHistoryReg_next  = {specBranchHistoryReg_next[30:0],predDir};
    get_gshare_pred = predDir;
  endfunction
  
  task update_gshare;
    input [31:0]  instrPC;
    input         actualDir;
    logic [`SIZE_BPB_LOG-1:0]  gshareIndex;
    logic [1:0]   predCount;
    gshareIndex = {3'b000,instrPC[31:3]} ^ branchHistoryReg;
  `ifdef SMALL_GSHARE
      predCount   = branchCounterTable0[gshareIndex];
  `else
    case(gshareIndex[1:0])
      2'b00: predCount   = branchCounterTable0[gshareIndex[`SIZE_BPB_LOG-1:2]];
      2'b01: predCount   = branchCounterTable1[gshareIndex[`SIZE_BPB_LOG-1:2]];
      2'b10: predCount   = branchCounterTable2[gshareIndex[`SIZE_BPB_LOG-1:2]];
      2'b11: predCount   = branchCounterTable3[gshareIndex[`SIZE_BPB_LOG-1:2]];
    endcase
  `endif
    predCount   = actualDir 
                    ? (predCount < 3 ? predCount + 1 : predCount)
                    : (predCount > 0 ? predCount - 1 : predCount);
  `ifdef SMALL_GSHARE
      branchCounterTable0[gshareIndex] = predCount; 
  `else
    case(gshareIndex[1:0])
      2'b00: branchCounterTable0[gshareIndex[`SIZE_BPB_LOG-1:2]] = predCount; 
      2'b01: branchCounterTable1[gshareIndex[`SIZE_BPB_LOG-1:2]] = predCount;
      2'b10: branchCounterTable2[gshareIndex[`SIZE_BPB_LOG-1:2]] = predCount;
      2'b11: branchCounterTable3[gshareIndex[`SIZE_BPB_LOG-1:2]] = predCount;
    endcase
  `endif
    branchHistoryReg  = {branchHistoryReg[30:0],actualDir};
    `ifdef PRINT_EN
      $fwrite(fd_bhr, "BHR: %X Index: %X  Count %X\n", branchHistoryReg, gshareIndex, predCount); 
    `endif
  endtask
  
  initial
  begin
    int i;
    //specBranchHistoryReg  = 32'b0;
    branchHistoryReg      = 32'b0;
    retiredBranchHistoryReg      = 32'b0;
  
    for(i=0;i<4096;i++)
    begin
      branchCounterTable0[i] = 2'b10;  //Weakly taken  
    `ifndef SMALL_GSHARE
      branchCounterTable1[i] = 2'b10;  //Weakly taken  
      branchCounterTable2[i] = 2'b10;  //Weakly taken  
      branchCounterTable3[i] = 2'b10;  //Weakly taken  
    `endif
    end
  end
  
  logic [`FETCH_WIDTH-1:0]      gsharePred;
  logic [`FETCH_WIDTH-1:0]      gsharePred_l1;
  logic [1:0]                   gsharePredCount[0:`FETCH_WIDTH-1];
  
  fs2Pkt                        instPacket   [0:`FETCH_WIDTH-1];
  logic                         ctrlVect     [0:`FETCH_WIDTH-1];
  logic                         ctrlVect_t   [0:`FETCH_WIDTH-1];
  logic [`BRANCH_TYPE_LOG-1:0]      ctrlType     [0:`FETCH_WIDTH-1];
  
  // LANE: Per lane logic
  always_comb
  begin
    int i;
    for (i = 0; i < `FETCH_WIDTH; i = i + 1)
    begin
      instPacket[i].pc    = instPC[i];
      instPacket[i].inst  = inst[i];
    end
  end
  
  genvar g;
  generate
    for (g = 0; g < `FETCH_WIDTH; g = g + 1)
    begin : preDecode_gen
  
    PreDecode_PISA preDecode(
      .fs2Packet_i    (instPacket[g]),
  
    `ifdef DYNAMIC_CONFIG
      .ctrlInst_o     (ctrlVect_t[g]),
      .laneActive_i   (coreTop.fs1.fetchLaneActive_i[g]), // Used only for power gating internaly
    `else
      .ctrlInst_o     (ctrlVect[g]),
    `endif
      .predNPC_o      (),
      .ctrlType_o     (ctrlType[g])
      );
  
  // Mimic an isolation cell      
  `ifdef DYNAMIC_CONFIG      
    always_comb
    begin
      ctrlVect[g] = coreTop.fs1.fetchLaneActive_i[g] ? ctrlVect_t[g] : 1'b0;
    end
  `endif
    end
  endgenerate
  
  always_ff @(posedge clk or posedge reset)
  begin
    if(reset)
      specBranchHistoryReg  <= 32'b0;
    else
    begin
      //specBranchHistoryReg_prev   <=  specBranchHistoryReg;
  
      if(coreTop.fs1.bp.updateEn_i)
      begin
        gshareUpdatePC  <=  coreTop.updatePC_l1;
        update_gshare(coreTop.updatePC_l1,coreTop.updateDir_l1);
      end
  
      // Recover the history registors if there's a recovery
      if(coreTop.recoverFlag)
        specBranchHistoryReg  <=  retiredBranchHistoryReg;  // Revert to non-speculative history
      else if(coreTop.fs2RecoverFlag)
      begin
        //$display ("Cycle: %d Reloading from FS2 BHR %x original %x \n",CYCLE_COUNT,specBranchHistoryRegFs2,specBranchHistoryReg);
        //specBranchHistoryReg  <=  specBranchHistoryReg; // Hold value, do not update with wrong info
        specBranchHistoryReg  <=  specBranchHistoryRegFs2; // Hold value, do not update with wrong info
      end
      else
        specBranchHistoryReg  <=  specBranchHistoryReg_next; // Update history with current cycles results
    end
  end
  
  
  always @(clk)
  begin
    int i;
    if(~clk)
    begin
      // This is the precise retired state since CTI queue and BPB update might lag
      for(i=0;i<`COMMIT_WIDTH;i++)
      begin
        if(coreTop.activeList.commitCti_o[i] & coreTop.activeList.ctrlAl[i][5])
        begin
          retiredBranchHistoryReg = {retiredBranchHistoryReg[30:0],coreTop.activeList.actualDir_o[i]};
          `ifdef PRINT_EN
            //$fwrite(fd_specbhr, "BHR: %X ActualDir: %b\n", retiredBranchHistoryReg, coreTop.activeList.actualDir_o[i]); 
          `endif
        end
      end
    end
  end
  
  always @(posedge clk)
  begin
    `ifdef PRINT_EN
      $fwrite(fd_specbhr, "BHR: %X specBHR: %X PredDir: %X\n", branchHistoryReg, specBranchHistoryRegFs2, gsharePred_l1); 
    `endif
  
    //gsharePred_l1     <=  gsharePred;
    if(coreTop.recoverFlag)
      specBranchHistoryReg_l1 <= retiredBranchHistoryReg;
    //else if(~coreTop.fs2RecoverFlag & instReq)
    else if(instReq)
    begin
      specBranchHistoryReg_l1 <= specBranchHistoryReg;
      gsharePred_l1     <=  gsharePred;
    end
  end
  
  // Speculative Branch History in FS2 stage
  always @(*)
  begin
    int i;
    if(~coreTop.fs2.stall_i)
    begin
      // Undo the shifts to capture the correct number of shifts i.e shifts only for branches before the taken branch.
      specBranchHistoryRegFs2 = specBranchHistoryReg_l1;
      for(i=0;i < `FETCH_WIDTH;i++)
        // Update the FS2 BHR with valid conditional branches in the bundle upto the first taken conditional branch
        if(coreTop.fs2.ctiQueue.ctrlVect_i[i] & coreTop.fs2.VALIDATE_BTB.condBranchVect[i])
        begin
          specBranchHistoryRegFs2 = {specBranchHistoryRegFs2[30:0],gsharePred_l1[i]};
        end
    end
  end
  
  // Generates the predictions at negative edge of the clock
  always @(clk)
  begin
    int i;
    if(~clk)
    begin
      specBranchHistoryReg_next  =  specBranchHistoryReg;
      for(i=0;i<`FETCH_WIDTH;i++)
      begin
      `ifdef DYNAMIC_CONFIG
        if(instReq & coreTop.fs1.fetchLaneActive_i[i] & (ctrlType[i] == `COND_BRANCH))
      `else
        if(instReq & (ctrlType[i] == `COND_BRANCH))
      `endif
        begin
          gsharePredPC[i] <= instPC[i];
          gsharePred[i] <= get_gshare_pred(instPC[i],gsharePredCount[i]);
        end
        else
        begin
          gsharePred[i] <= 1'b0;
        end
      end
    end
  end
  
  // Force the prediction from the testbench
  always_comb
  begin
    int i;
    for(i=0;i<`FETCH_WIDTH;i++)
    begin
      coreTop.fs1.bp.predDir_o[i]       = gsharePred[i];
      coreTop.fs1.bp.predCounter_o[i]   = gsharePredCount[i];
    end
  end

