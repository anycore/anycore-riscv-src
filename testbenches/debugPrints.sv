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

/*  Prints top level related latches in a file every cycle. */
task coretop_debug_print;
  int i;

  $fwrite(fd_coretop, "------------------------------------------------------\n");
  $fwrite(fd_coretop, "Cycle: %0d  Commit: %0d\n\n",CYCLE_COUNT, COMMIT_COUNT);

`ifdef DYNAMIC_CONFIG
  $fwrite(fd_coretop, "stallFetch: %b\n\n", coreTop.stallFetch_i);
  $fwrite(fd_coretop, "resetFetch: %b\n\n", coreTop.resetFetch_i);
`endif        

endtask



btbDataPkt                           btbData       [0:`FETCH_WIDTH-1];
  
/*  Prints fetch1 stage related latches in a file every cycle. */
task fetch1_debug_print;
  int i;
  for (i = 0; i < `FETCH_WIDTH; i++)
  begin
      btbData[i]  = coreTop.fs1.btb.btbData[i];
  end


  $fwrite(fd_fetch1, "------------------------------------------------------\n");
  $fwrite(fd_fetch1, "Cycle: %0d  Commit: %0d\n\n",CYCLE_COUNT, COMMIT_COUNT);

  $fwrite(fd_fetch1, "stall_i: %b\n\n", coreTop.fs1.stall_i);

  $fwrite(fd_fetch1, "               -- Next PC --\n\n");
  
  $fwrite(fd_fetch1, "PC:             %08x\n",
          coreTop.fs1.PC);

  $fwrite(fd_fetch1, "recoverPC_i:    %08x recoverFlag_i: %b mispredFlag_reg: %b violateFlag_reg: %b\n",
          coreTop.fs1.recoverPC_i,
          coreTop.fs1.recoverFlag_i,
          coreTop.activeList.mispredFlag_reg,
          coreTop.activeList.violateFlag_reg);

  $fwrite(fd_fetch1, "exceptionPC_i:  %08x exceptionFlag_i: %b\n",
          coreTop.fs1.exceptionPC_i,
          coreTop.fs1.exceptionFlag_i);

  $fwrite(fd_fetch1, "fs2RecoverPC_i: %08x fs2RecoverFlag_i: %b\n",
          coreTop.fs1.fs2RecoverPC_i,
          coreTop.fs1.fs2RecoverFlag_i);

  $fwrite(fd_fetch1, "nextPC:         %08x\n\n",
          coreTop.fs1.nextPC);

  $fwrite(fd_fetch1, "takenVect:  %04b\n",
          coreTop.fs1.takenVect);

  $fwrite(fd_fetch1, "addrRAS:    %08x\n\n",
          coreTop.fs1.addrRAS);

  $fwrite(fd_fetch1, "               -- BTB --\n\n");
  
  $fwrite(fd_fetch1, "\nbtbData       ");
  for (i = 0; i < `FETCH_WIDTH; i++)
      $fwrite(fd_fetch1, "     [%1d] ", i);

  $fwrite(fd_fetch1, "\ntag           ");
  for (i = 0; i < `FETCH_WIDTH; i++)
      $fwrite(fd_fetch1, "%08x ", btbData[i].tag);

  $fwrite(fd_fetch1, "\ntakenPC       ");
  for (i = 0; i < `FETCH_WIDTH; i++)
      $fwrite(fd_fetch1, "%08x ", btbData[i].takenPC);

  $fwrite(fd_fetch1, "\nctrlType      ");
  for (i = 0; i < `FETCH_WIDTH; i++)
      $fwrite(fd_fetch1, "%08x ", btbData[i].ctrlType);

  $fwrite(fd_fetch1, "\nvalid         ");
  for (i = 0; i < `FETCH_WIDTH; i++)
      $fwrite(fd_fetch1, "%08x ", btbData[i].valid);

  $fwrite(fd_fetch1, "\n\nupdatePC_i:     %08x\n",
          coreTop.fs1.updatePC_i);

  $fwrite(fd_fetch1, "updateNPC_i:    %08x\n",
          coreTop.fs1.updateNPC_i);

  $fwrite(fd_fetch1, "updateBrType_i: %x\n",
          coreTop.fs1.updateBrType_i);

  $fwrite(fd_fetch1, "updateDir_i:    %b\n",
          coreTop.fs1.updateDir_i);

  $fwrite(fd_fetch1, "updateEn_i:     %b\n\n",
          coreTop.fs1.updateEn_i);


  $fwrite(fd_fetch1, "               -- BP --\n\n");
  
  $fwrite(fd_fetch1, "predDir:    %04b\n",
          coreTop.fs1.predDir);

  $fwrite(fd_fetch1, "instOffset[0]:    %x\n",
          coreTop.fs1.bp.instOffset[0]);

  $fwrite(fd_fetch1, "rdAddr         ");
  for (i = 0; i < `FETCH_WIDTH; i++)
      $fwrite(fd_fetch1, "%x ", coreTop.fs1.bp.rdAddr[i]);

  $fwrite(fd_fetch1, "\nrdData         ");
  for (i = 0; i < `FETCH_WIDTH; i++)
      $fwrite(fd_fetch1, "%x ", coreTop.fs1.bp.rdData[i]);

  $fwrite(fd_fetch1, "\npredCounter    ");
  for (i = 0; i < `FETCH_WIDTH; i++)
      $fwrite(fd_fetch1, "%x ", coreTop.fs1.bp.predCounter[i]);

  $fwrite(fd_fetch1, "\n\nwrAddr:        %x\n",
          coreTop.fs1.bp.wrAddr);

  $fwrite(fd_fetch1, "\nwrData:        %x\n",
          coreTop.fs1.bp.wrData);

  $fwrite(fd_fetch1, "\nwrEn         ");
  for (i = 0; i < `FETCH_WIDTH; i++)
      $fwrite(fd_fetch1, "%x ", coreTop.fs1.bp.wrEn[i]);


  $fwrite(fd_fetch1, "\n\n               -- RAS --\n\n");
  
  $fwrite(fd_fetch1, "pushAddr:   %08x\n",
          coreTop.fs1.pushAddr);

  $fwrite(fd_fetch1, "pushRAS:   %b  popRAS: %b\n",
          coreTop.fs1.pushRAS,
          coreTop.fs1.popRAS);

  $fwrite(fd_fetch1, "\n\n");

  if (coreTop.instBufferFull)
      $fwrite(fd_fetch1, "instBufferFull:%b\n",
              coreTop.instBufferFull);
  
  if (coreTop.ctiQueueFull)
    $fwrite(fd_fetch1, "ctiQueueFull:%b\n",
            coreTop.ctiQueueFull);

  if (coreTop.fs1.recoverFlag_i)

  if(coreTop.fs1.ras.pop_i)
    $fwrite(fd_fetch1, "BTB hit for Rtr instr, spec_tos:%d, Pop Addr: %x",
            coreTop.fs1.ras.spec_tos,
            coreTop.fs1.ras.addrRAS_o);

  if (coreTop.fs1.ras.push_i)
    $fwrite(fd_fetch1, "BTB hit for CALL instr, Push Addr: %x",
            coreTop.fs1.ras.pushAddr_i);

  $fwrite(fd_fetch1, "RAS POP Addr:%x\n",
          coreTop.fs1.ras.addrRAS_o);

  if (coreTop.fs1.fs2RecoverFlag_i)
    $fwrite(fd_fetch1, "Fetch-2 fix BTB miss (target addr): %h\n",
                coreTop.fs1.fs2RecoverPC_i);
  
  $fwrite(fd_fetch1, "\n\n\n");

endtask


/* Prints fetch2/Ctrl Queue related latches in a file every cycle. */
task fetch2_debug_print; 
  int i;

  $fwrite(fd_fetch2, "------------------------------------------------------\n");
  $fwrite(fd_fetch2, "Cycle: %0d  Commit: %0d\n\n\n",CYCLE_COUNT, COMMIT_COUNT);

  if (coreTop.fs2.ctiQueue.stall_i)
  begin
    $fwrite(fd_fetch2, "Fetch2 is stalled ....\n");
  end

  if (coreTop.fs2.ctiQueueFull_o)
  begin
    $fwrite(fd_fetch2, "CTI Queue is full ....\n");
  end

  $fwrite(fd_fetch2, "\n");

  $fwrite(fd_fetch2, "Control vector:%b fs1Ready:%b\n",
          coreTop.fs2.ctiQueue.ctrlVect_i,
          coreTop.fs2.ctiQueue.fs1Ready_i);


  $fwrite(fd_fetch2, "\n");

  $fwrite(fd_fetch2, "ctiq Tag0:%d ",
          coreTop.fs2.ctiQueue.ctiID_o[0]);

`ifdef FETCH_TWO_WIDE
    $fwrite(fd_fetch2, "ctiq Tag1:%d ",
            coreTop.fs2.ctiQueue.ctiID_o[1]);
`endif

`ifdef FETCH_THREE_WIDE
    $fwrite(fd_fetch2, "ctiq Tag2:%d ",
            coreTop.fs2.ctiQueue.ctiID_o[2]);
`endif

`ifdef FETCH_FOUR_WIDE
    $fwrite(fd_fetch2, "ctiq Tag3:%d ",
            coreTop.fs2.ctiQueue.ctiID_o[3]);
`endif

`ifdef FETCH_FIVE_WIDE
    $fwrite(fd_fetch2, "ctiq Tag4:%d ",
            coreTop.fs2.ctiQueue.ctiID_o[4]);
`endif

`ifdef FETCH_SIX_WIDE
    $fwrite(fd_fetch2, "ctiq Tag5:%d ",
            coreTop.fs2.ctiQueue.ctiID_o[5]);
`endif

`ifdef FETCH_SEVEN_WIDE
    $fwrite(fd_fetch2, "ctiq Tag6:%d ",
            coreTop.fs2.ctiQueue.ctiID_o[6]);
`endif

`ifdef FETCH_EIGHT_WIDE
    $fwrite(fd_fetch2, "ctiq Tag7:%d ",
            coreTop.fs2.ctiQueue.ctiID_o[7]);
`endif

  $fwrite(fd_fetch2, "\nupdateCounter_i:   %x\n",
          coreTop.fs1.bp.updateCounter_i);

  $fwrite(fd_fetch2, "\ncti.headPtr:       %x\n",
          coreTop.fs2.ctiQueue.headPtr);

  $fwrite(fd_fetch2, "\nctiq.ctiID            ");
  for (i = 0; i < `FETCH_WIDTH; i++)
      $fwrite(fd_fetch2, "%x ", coreTop.fs2.ctiQueue.ctiID[i]);

  $fwrite(fd_fetch2, "\nctiq.predCounter_i    ");
  for (i = 0; i < `FETCH_WIDTH; i++)
      $fwrite(fd_fetch2, "%x ", coreTop.fs2.ctiQueue.predCounter_i[i]);

  $fwrite(fd_fetch2, "\nctiq.ctrlVect_i       ");
  for (i = 0; i < `FETCH_WIDTH; i++)
      $fwrite(fd_fetch2, "%x ", coreTop.fs2.ctiQueue.ctrlVect_i[i]);

  $fwrite(fd_fetch2, "\n\n");

  if (coreTop.fs2.ctiQueue.exeCtrlValid_i) begin
      $fwrite(fd_fetch2, "\nwriting back a control instruction.....\n");

      $fwrite(fd_fetch2,"ctiq index:%d target addr:%h br outcome:%b\n\n",
              coreTop.fs2.ctiQueue.exeCtiID_i,
              coreTop.fs2.ctiQueue.exeCtrlNPC_i,
              coreTop.fs2.ctiQueue.exeCtrlDir_i);
  end

  if (coreTop.fs2.ctiQueue.recoverFlag_i)
  begin
    $fwrite(fd_fetch2, "Recovery Flag is High....\n\n");
  end

  if (coreTop.fs2.ctiQueue.updateEn_o)
  begin
    $fwrite(fd_fetch2, "\nupdating the BTB and BPB.....\n");

    $fwrite(fd_fetch2, "updatePC:%h updateNPC: %h updateCtrlType:%b updateDir:%b\n\n",
            coreTop.fs2.ctiQueue.updatePC_o,
            coreTop.fs2.ctiQueue.updateNPC_o,
            coreTop.fs2.ctiQueue.updateCtrlType_o,
            coreTop.fs2.updateDir_o);
  end

  $fwrite(fd_fetch2, "ctiq=> headptr:%d tailptr:%d commitPtr:%d instcount:%d commitCnt:%d\n",
          coreTop.fs2.ctiQueue.headPtr,
          coreTop.fs2.ctiQueue.tailPtr,
          coreTop.fs2.ctiQueue.commitPtr,
          coreTop.fs2.ctiQueue.ctrlCount,
          coreTop.fs2.ctiQueue.commitCnt);

  $fwrite(fd_fetch2, "\n");
endtask



/*  Prints decode stage related latches in a file every cycle. */
decPkt                     decPacket [0:`FETCH_WIDTH-1];
renPkt                     ibPacket [0:2*`FETCH_WIDTH-1];

task decode_debug_print;
    int i;
    for (i = 0; i < `FETCH_WIDTH; i++)
    begin
        decPacket[i]    = coreTop.decPacket_l1[i];
        ibPacket[2*i]   = coreTop.ibPacket[2*i];
        ibPacket[2*i+1] = coreTop.ibPacket[2*i+1];
    end

    $fwrite(fd_decode, "------------------------------------------------------\n");
    $fwrite(fd_decode, "Cycle: %0d  Commit: %0d\n\n\n",CYCLE_COUNT, COMMIT_COUNT);

    $fwrite(fd_decode, "fs2Ready_i: %b\n", coreTop.decode.fs2Ready_i);

    $fwrite(fd_decode, "\n               -- decPackets --\n");
    
    $fwrite(fd_decode, "\ndecPacket_i   ");
    for (i = 0; i < `FETCH_WIDTH; i++)
        $fwrite(fd_decode, "     [%1d] ", i);

    $fwrite(fd_decode, "\npc:           ");
    for (i = 0; i < `FETCH_WIDTH; i++)
        $fwrite(fd_decode, "%08x ", decPacket[i].pc);

    $fwrite(fd_decode, "\nctrlType:     ");
    for (i = 0; i < `FETCH_WIDTH; i++)
        $fwrite(fd_decode, "      %2x ", decPacket[i].ctrlType);

    $fwrite(fd_decode, "\nctiID:        ");
    for (i = 0; i < `FETCH_WIDTH; i++)
        $fwrite(fd_decode, "      %2x ", decPacket[i].ctiID);

    $fwrite(fd_decode, "\npredNPC:      ");
    for (i = 0; i < `FETCH_WIDTH; i++)
        $fwrite(fd_decode, "%08x ", decPacket[i].predNPC);

    $fwrite(fd_decode, "\npredDir:      ");
    for (i = 0; i < `FETCH_WIDTH; i++)
        $fwrite(fd_decode, "       %1x ", decPacket[i].predDir);

    $fwrite(fd_decode, "\nvalid:        ");
    for (i = 0; i < `FETCH_WIDTH; i++)
        $fwrite(fd_decode, "       %1x ", decPacket[i].valid);


    $fwrite(fd_decode, "\n\n               -- ibPackets --\n");
    
    $fwrite(fd_decode, "\nibPacket_o    ");
    for (i = 0; i < 2*`FETCH_WIDTH; i++)
        $fwrite(fd_decode, "     [%1d] ", i);

    $fwrite(fd_decode, "\npc:           ");
    for (i = 0; i < 2*`FETCH_WIDTH; i++)
        $fwrite(fd_decode, "%08x ", ibPacket[i].pc);

    $fwrite(fd_decode, "\ninst:       ");
    for (i = 0; i < 2*`FETCH_WIDTH; i++)
        $fwrite(fd_decode, "      %2x ",  ibPacket[i].inst);

    $fwrite(fd_decode, "\nfu:           ");
    for (i = 0; i < 2*`FETCH_WIDTH; i++)
        $fwrite(fd_decode, "      %2x ",  ibPacket[i].fu);

    $fwrite(fd_decode, "\nlogDest (V):  ");
    for (i = 0; i < 2*`FETCH_WIDTH; i++)
        $fwrite(fd_decode, "  %2x (%d) ", ibPacket[i].logDest, ibPacket[i].logDestValid);

    $fwrite(fd_decode, "\nlogSrc1 (V):  ");
    for (i = 0; i < 2*`FETCH_WIDTH; i++)
        $fwrite(fd_decode, "  %2x (%d) ", ibPacket[i].logSrc1, ibPacket[i].logSrc1Valid);

    $fwrite(fd_decode, "\nlogSrc2 (V):  ");
    for (i = 0; i < 2*`FETCH_WIDTH; i++)
        $fwrite(fd_decode, "  %2x (%d) ", ibPacket[i].logSrc2, ibPacket[i].logSrc2Valid);

    $fwrite(fd_decode, "\nimmed (V):    ");
    for (i = 0; i < 2*`FETCH_WIDTH; i++)
        $fwrite(fd_decode, "%04x (%d) ", ibPacket[i].immed, ibPacket[i].immedValid);

    $fwrite(fd_decode, "\nisLoad:       ");
    for (i = 0; i < 2*`FETCH_WIDTH; i++)
        $fwrite(fd_decode, "       %1x ", ibPacket[i].isLoad);

    $fwrite(fd_decode, "\nisStore:      ");
    for (i = 0; i < 2*`FETCH_WIDTH; i++)
        $fwrite(fd_decode, "       %1x ", ibPacket[i].isStore);

    $fwrite(fd_decode, "\nldstSize:     ");
    for (i = 0; i < 2*`FETCH_WIDTH; i++)
        $fwrite(fd_decode, "       %1x ", ibPacket[i].ldstSize);

    $fwrite(fd_decode, "\nctrlType:     ");
    for (i = 0; i < 2*`FETCH_WIDTH; i++)
        $fwrite(fd_decode, "      %2x ", ibPacket[i].ctrlType);

    $fwrite(fd_decode, "\nctiID:        ");
    for (i = 0; i < 2*`FETCH_WIDTH; i++)
        $fwrite(fd_decode, "      %2x ", ibPacket[i].ctiID);

    $fwrite(fd_decode, "\npredNPC:      ");
    for (i = 0; i < 2*`FETCH_WIDTH; i++)
        $fwrite(fd_decode, "%08x ", ibPacket[i].predNPC);

    $fwrite(fd_decode, "\npredDir:      ");
    for (i = 0; i < 2*`FETCH_WIDTH; i++)
        $fwrite(fd_decode, "       %1x ", ibPacket[i].predDir);

    $fwrite(fd_decode, "\nvalid:        ");
    for (i = 0; i < 2*`FETCH_WIDTH; i++)
        $fwrite(fd_decode, "       %1x ", ibPacket[i].valid);

    $fwrite(fd_decode, "\n\n\n");

endtask


/*  Prints Instruction Buffer stage related latches in a file every cycle. */
task ibuff_debug_print;
    $fwrite(fd_ibuff, "------------------------------------------------------\n");
    $fwrite(fd_ibuff, "Cycle: %0d  Commit: %0d\n\n\n",CYCLE_COUNT, COMMIT_COUNT);

    $fwrite(fd_ibuff, "Inst Buffer Full:%b freelistEmpty:%b backEndFull:%b\n",
            coreTop.instBuf.instBufferFull,
            coreTop.freeListEmpty,
            coreTop.backEndFull);

    $fwrite(fd_ibuff, "\n");

    $fwrite(fd_ibuff, "Decode Ready=%b\n",
            coreTop.instBuf.decodeReady_i);

    $fwrite(fd_ibuff, "instbuffer head=%d instbuffer tail=%d inst count=%d\n",
            coreTop.instBuf.headPtr,
            coreTop.instBuf.tailPtr,
            coreTop.instBuf.instCount);

    $fwrite(fd_ibuff, "instBufferReady_o:%b\n",
            coreTop.instBuf.instBufferReady_o);

    if (coreTop.recoverFlag)
      $fwrite(fd_ibuff, "recoverFlag_i is High\n");

    if (coreTop.instBuf.flush_i)
      $fwrite(fd_ibuff, "flush_i is High\n");

    if (coreTop.instBuf.instCount > `INST_QUEUE)
    begin
      $fwrite(fd_ibuff, "Instruction Buffer overflow\n");
      $display("\n** Cycle: %d Instruction Buffer Overflow **\n",CYCLE_COUNT);
    end

    $fwrite(fd_ibuff,"\n");
endtask


disPkt                     disPacket [0:`DISPATCH_WIDTH-1];
phys_reg                   freedPhyReg [0:`COMMIT_WIDTH-1];

/*  Prints rename stage related latches in a file every cycle. */
task rename_debug_print;
    int i;
    for (i = 0; i < `DISPATCH_WIDTH; i++)
    begin
        disPacket[i]    = coreTop.disPacket[i];
        freedPhyReg[i]  = coreTop.rename.specfreelist.freedPhyReg_i[i];
    end

    $fwrite(fd_rename, "------------------------------------------------------\n");
    $fwrite(fd_rename, "Cycle: %0d  Commit: %0d\n\n\n",CYCLE_COUNT, COMMIT_COUNT);

    $fwrite(fd_rename, "Decode Ready: %b\n",
            coreTop.rename.instBufferReady_i);
            /* coreTop.rename.branchCount_i); */

    $fwrite(fd_rename, "freeListEmpty: %b\n",
            coreTop.rename.freeListEmpty);

    /* disPacket_o */
    $fwrite(fd_rename, "disPacket_o   ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_rename, "     [%1d] ", i);

    $fwrite(fd_rename, "\npc:           ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_rename, "%08x ", disPacket[i].pc);

    $fwrite(fd_rename, "\ninst:       ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_rename, "      %2x ",  disPacket[i].inst);

    $fwrite(fd_rename, "\nfu:           ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_rename, "       %1x ", disPacket[i].fu);

    $fwrite(fd_rename, "\nlogDest:      ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_rename, "      %2x ", disPacket[i].logDest);

    $fwrite(fd_rename, "\nphyDest (V):  ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_rename, "  %2x (%d) ", disPacket[i].phyDest, disPacket[i].phyDestValid);

    $fwrite(fd_rename, "\nphySrc1 (V):  ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_rename, "  %2x (%d) ", disPacket[i].phySrc1, disPacket[i].phySrc1Valid);

    $fwrite(fd_rename, "\nphySrc2 (V):  ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_rename, "  %2x (%d) ", disPacket[i].phySrc2, disPacket[i].phySrc2Valid);

    $fwrite(fd_rename, "\nimmed (V):    ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_rename, "%04x (%d) ", disPacket[i].immed, disPacket[i].immedValid);

    $fwrite(fd_rename, "\nisLoad:       ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_rename, "       %1x ", disPacket[i].isLoad);

    $fwrite(fd_rename, "\nisStore:      ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_rename, "       %1x ", disPacket[i].isStore);

    $fwrite(fd_rename, "\nldstSize:     ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_rename, "       %1x ", disPacket[i].ldstSize);

    $fwrite(fd_rename, "\nctiID:        ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_rename, "      %2x ", disPacket[i].ctiID);

    $fwrite(fd_rename, "\npredNPC:      ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_rename, "%08x ", disPacket[i].predNPC);

    $fwrite(fd_rename, "\npredDir:      ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_rename, "       %1x ", disPacket[i].predDir);

    $fwrite(fd_rename, "\n\nrename ready:%b\n\n", coreTop.rename.renameReady_o);

    $fwrite(fd_rename, "               -- Free List (Popped) --\n\n");

    $fwrite(fd_rename, "freeListHead: %x\n", coreTop.rename.specfreelist.freeListHead);
    $fwrite(fd_rename, "freeListTail: %x\n", coreTop.rename.specfreelist.freeListTail);
    $fwrite(fd_rename, "freeListCnt: d%d\n", coreTop.rename.specfreelist.freeListCnt);
    $fwrite(fd_rename, "pushNumber: d%d\n", coreTop.rename.specfreelist.pushNumber);
    
    $fwrite(fd_rename, "\nrdAddr:       ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_rename, "      %2x ", coreTop.rename.specfreelist.readAddr[i]);

    $fwrite(fd_rename, "\nfreePhyReg:   ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_rename, "      %2x ", coreTop.rename.specfreelist.freePhyReg[i]);

    $fwrite(fd_rename, "\n\n\n               -- Free List (Pushed) --\n\n");

    $fwrite(fd_rename, "\nfreedPhyReg (V): ");
    for (i = 0; i < `COMMIT_WIDTH; i++)
        $fwrite(fd_rename, "      %2x ", freedPhyReg[i].reg_id, freedPhyReg[i].valid);

    $fwrite(fd_rename,"\n\n\n");
endtask


disPkt                           disPacket_l1 [0:`DISPATCH_WIDTH-1];
iqPkt                            iqPacket  [0:`DISPATCH_WIDTH-1];
//alPkt                            alPacket  [0:`DISPATCH_WIDTH-1];
lsqPkt                           lsqPacket [0:`DISPATCH_WIDTH-1];

/* Prints dispatch related signals and latch value. */
task dispatch_debug_print;
    int i;
    for (i = 0; i < `DISPATCH_WIDTH; i++)
    begin
        disPacket_l1[i]               = coreTop.disPacket_l1[i];
        iqPacket[i]                = coreTop.iqPacket[i];
        alPacket[i]                = coreTop.alPacket[i];
        lsqPacket[i]               = coreTop.lsqPacket[i];
    end

    $fwrite(fd_dispatch, "----------------------------------------------------------------------\n");
    $fwrite(fd_dispatch, "Cycle: %d Commit Count: %d\n\n", CYCLE_COUNT, COMMIT_COUNT);

    /* disPacket_i */
    $fwrite(fd_dispatch, "disPacket_i   ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_dispatch, "     [%1d] ", i);

    $fwrite(fd_dispatch, "\npc:           ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_dispatch, "%08x ", disPacket_l1[i].pc);

    $fwrite(fd_dispatch, "\ninst:       ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_dispatch, "      %2x ",  disPacket_l1[i].inst);

    $fwrite(fd_dispatch, "\nfu:           ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_dispatch, "       %1x ", disPacket_l1[i].fu);

    $fwrite(fd_dispatch, "\nlogDest:      ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_dispatch, "      %2x ", disPacket_l1[i].logDest);

    $fwrite(fd_dispatch, "\nphyDest (V):  ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_dispatch, "  %2x (%d) ", disPacket_l1[i].phyDest, disPacket_l1[i].phyDestValid);

    $fwrite(fd_dispatch, "\nphySrc1 (V):  ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_dispatch, "  %2x (%d) ", disPacket_l1[i].phySrc1, disPacket_l1[i].phySrc1Valid);

    $fwrite(fd_dispatch, "\nphySrc2 (V):  ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_dispatch, "  %2x (%d) ", disPacket_l1[i].phySrc2, disPacket_l1[i].phySrc2Valid);

    $fwrite(fd_dispatch, "\nimmed (V):    ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_dispatch, "%04x (%d) ", disPacket_l1[i].immed, disPacket_l1[i].immedValid);

    $fwrite(fd_dispatch, "\nisLoad:       ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_dispatch, "       %1x ", disPacket_l1[i].isLoad);

    $fwrite(fd_dispatch, "\nisStore:      ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_dispatch, "       %1x ", disPacket_l1[i].isStore);

    $fwrite(fd_dispatch, "\nldstSize:     ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_dispatch, "       %1x ", disPacket_l1[i].ldstSize);

    $fwrite(fd_dispatch, "\nctiID:        ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_dispatch, "      %2x ", disPacket_l1[i].ctiID);

    $fwrite(fd_dispatch, "\npredNPC:      ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_dispatch, "%08x ", disPacket_l1[i].predNPC);

    $fwrite(fd_dispatch, "\npredDir:      ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_dispatch, "       %1x ", disPacket_l1[i].predDir);

    /* iqPacket_o */
    $fwrite(fd_dispatch, "\n\niqPacket_o    ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_dispatch, "     [%1d] ", i);

    $fwrite(fd_dispatch, "\npc:           ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_dispatch, "%08x ", iqPacket[i].pc);

    $fwrite(fd_dispatch, "\ninst:       ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_dispatch, "      %2x ",  iqPacket[i].inst);

    $fwrite(fd_dispatch, "\nfu:           ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_dispatch, "       %1x ", iqPacket[i].fu);

    $fwrite(fd_dispatch, "\nphyDest (V):  ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_dispatch, "  %2x (%d) ", iqPacket[i].phyDest, iqPacket[i].phyDestValid);

    $fwrite(fd_dispatch, "\nphySrc1 (V):  ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_dispatch, "  %2x (%d) ", iqPacket[i].phySrc1, iqPacket[i].phySrc1Valid);

    $fwrite(fd_dispatch, "\nphySrc2 (V):  ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_dispatch, "  %2x (%d) ", iqPacket[i].phySrc2, iqPacket[i].phySrc2Valid);

    $fwrite(fd_dispatch, "\nimmed (V):    ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_dispatch, "%04x (%d) ", iqPacket[i].immed, iqPacket[i].immedValid);

    $fwrite(fd_dispatch, "\nisLoad:       ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_dispatch, "       %1x ", iqPacket[i].isLoad);

    $fwrite(fd_dispatch, "\nisStore:      ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_dispatch, "       %1x ", iqPacket[i].isStore);

    $fwrite(fd_dispatch, "\nldstSize:     ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_dispatch, "       %1x ", iqPacket[i].ldstSize);

    $fwrite(fd_dispatch, "\nctiID:        ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_dispatch, "      %2x ", iqPacket[i].ctiID);

    $fwrite(fd_dispatch, "\npredNPC:      ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_dispatch, "%08x ", iqPacket[i].predNPC);

    $fwrite(fd_dispatch, "\npredDir:      ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_dispatch, "       %1x ", iqPacket[i].predDir);


    $fwrite(fd_dispatch, "\n\nloadCnt: d%d storeCnt: d%d\n",
            coreTop.dispatch.loadCnt,
            coreTop.dispatch.storeCnt);

    $fwrite(fd_dispatch, "backendReady_o: %b\n",
            coreTop.dispatch.dispatchReady_o);

    if (coreTop.dispatch.loadStall)       $fwrite(fd_dispatch,"LDQ Stall\n");
    if (coreTop.dispatch.storeStall)      $fwrite(fd_dispatch,"STQ Stall\n");
    if (coreTop.dispatch.iqStall)         $fwrite(fd_dispatch,"IQ Stall: IQ Cnt:%d\n",
                                                    coreTop.dispatch.issueQueueCnt_i);
    if (coreTop.dispatch.alStall)         $fwrite(fd_dispatch,"Active List Stall\n");
    if (~coreTop.dispatch.renameReady_i)  $fwrite(fd_dispatch,"renameReady_i Stall\n");


  `ifdef ENABLE_LD_VIOLATION_PRED
    $fwrite(fd_dispatch, "predictLdViolation: %b\n",
            coreTop.dispatch.predLoadVio);

    if (coreTop.dispatch.ldVioPred.loadViolation_i && coreTop.dispatch.ldVioPred.recoverFlag_i)
    begin
      $fwrite(fd_dispatch, "Update Load Violation Predictor\n");

      $fwrite(fd_dispatch, "PC:0x%x Addr:0x%x Tag:0x%x\n",
              coreTop.dispatch.ldVioPred.recoverPC_i,
              coreTop.dispatch.ldVioPred.predAddr0wr,
              coreTop.dispatch.ldVioPred.predTag0wr);
    end
  `endif
    $fwrite(fd_dispatch,"\n",);
endtask


phys_reg                        phyDest  [0:`DISPATCH_WIDTH-1];
iqEntryPkt                      iqFreeEntry [0:`DISPATCH_WIDTH-1];

iqEntryPkt                      iqFreedEntry   [0:`ISSUE_WIDTH-1];
iqEntryPkt                      iqGrantedEntry [0:`ISSUE_WIDTH-1];
payloadPkt                      rrPacket       [0:`ISSUE_WIDTH-1];

/* Prints issue queue related signals and latch values. */
task issueq_debug_print;
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

    $fwrite(fd_issueq, "------------------------------------------------------\n");
    $fwrite(fd_issueq, "Cycle: %0d  Commit: %0d\n\n\n",CYCLE_COUNT, COMMIT_COUNT);

  `ifdef DYNAMIC_CONFIG
    $fwrite(fd_alist, "dispatchLaneActive_i: %x\n",
    coreTop.issueq.dispatchLaneActive_i);

    $fwrite(fd_alist, "issueLaneActive_i: %x\n",
    coreTop.issueq.issueLaneActive_i);
  `endif        

    $fwrite(fd_issueq, "               -- Dispatched Instructions --\n\n");
    
    $fwrite(fd_issueq, "dispatchReady_i:          %b\n", coreTop.issueq.dispatchReady_i);

    /* iqPacket_i */
    $fwrite(fd_issueq, "iqPacket_i        ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_issueq, "     [%1d] ", i);

    $fwrite(fd_issueq, "\nseqNo:            ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_issueq, "%08x ", iqPacket[i].seqNo);

    $fwrite(fd_issueq, "\npc:               ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_issueq, "%08x ", iqPacket[i].pc);

    $fwrite(fd_issueq, "\ninst:           ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_issueq, "      %2x ",  iqPacket[i].inst);

    $fwrite(fd_issueq, "\nfu:               ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_issueq, "       %1x ", iqPacket[i].fu);

    $fwrite(fd_issueq, "\nphyDest (V):      ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_issueq, "  %2x (%d) ", iqPacket[i].phyDest, iqPacket[i].phyDestValid);

    $fwrite(fd_issueq, "\nphySrc1 (V):      ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_issueq, "  %2x (%d) ", iqPacket[i].phySrc1, iqPacket[i].phySrc1Valid);

    $fwrite(fd_issueq, "\nphySrc2 (V):      ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_issueq, "  %2x (%d) ", iqPacket[i].phySrc2, iqPacket[i].phySrc2Valid);

    $fwrite(fd_issueq, "\nimmed (V):        ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_issueq, "%04x (%d) ", iqPacket[i].immed, iqPacket[i].immedValid);

    $fwrite(fd_issueq, "\nisLoad:           ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_issueq, "       %1x ", iqPacket[i].isLoad);

    $fwrite(fd_issueq, "\nisStore:          ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_issueq, "       %1x ", iqPacket[i].isStore);

    $fwrite(fd_issueq, "\nldstSize:         ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_issueq, "       %1x ", iqPacket[i].ldstSize);

    $fwrite(fd_issueq, "\nctiID:            ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_issueq, "      %2x ", iqPacket[i].ctiID);

    $fwrite(fd_issueq, "\npredNPC:          ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_issueq, "%08x ", iqPacket[i].predNPC);

    $fwrite(fd_issueq, "\npredDir:          ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_issueq, "       %1x ", iqPacket[i].predDir);

    $fwrite(fd_issueq, "\nfreeEntry:        ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_issueq, "     d%2d ", iqFreeEntry[i].id);

    $fwrite(fd_issueq, "\nlsqID:            ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_issueq, "      %2x ", coreTop.lsqID[i]);

    $fwrite(fd_issueq, "\nalID:             ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_issueq, "      %2x ", coreTop.alID[i]);

    /* phyDest_i */
    $fwrite(fd_issueq, "\n\nphyDest_i         ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_issueq, "     [%1d] ", i);

    $fwrite(fd_issueq, "\nreg_id (V):       ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_issueq, "  %2x (%1x) ", phyDest[i].reg_id, phyDest[i].valid);

    $fwrite(fd_issueq, "\ndispatchedSrc1Ready:     ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_issueq, "       %b ", coreTop.issueq.dispatchedSrc1Ready[i]);
 
    $fwrite(fd_issueq, "\ndispatchedSrc2Ready:     ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_issueq, "       %b ", coreTop.issueq.dispatchedSrc2Ready[i]);

    $fwrite(fd_issueq, "\nrsrTag:        ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
    begin
        $fwrite(fd_issueq, "       %b ",coreTop.issueq.rsrTag[i]);
    end 

    $fwrite(fd_issueq, "\nrsrTag_t:    ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
    begin
        `ifndef DYNAMIC_CONFIG
          $fwrite(fd_issueq, "       %b ",coreTop.issueq.rsrTag_t[i]);
        `else
        `endif
    end
 
    $fwrite(fd_issueq, "\nISsimple_t:    ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
    begin
        $fwrite(fd_issueq, "       %b ",coreTop.issueq.ISsimple_t[i]);
    end


    /* IQ Freelist */

    $fwrite(fd_issueq, "\n\n               -- IQ Freelist --\n\n");

    $fwrite(fd_issueq, "issueQCount: d%d headPtr: d%d tailPtr: d%d\n",
            coreTop.issueq.issueQfreelist.issueQCount,
            coreTop.issueq.issueQfreelist.headPtr,
            coreTop.issueq.issueQfreelist.tailPtr);


    /* Wakeup */

    $fwrite(fd_issueq, "\n\n               -- Wakeup --\n\n");

    $fwrite(fd_issueq, "phyRegValidVect: %b\n\n", coreTop.issueq.phyRegValidVect);
    
    $fwrite(fd_issueq, "rsrTag (V):      ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
    begin
        $fwrite(fd_issueq, "%2x (%b) ",
                coreTop.issueq.rsrTag[i][`SIZE_PHYSICAL_LOG:1],
                coreTop.issueq.rsrTag[i][0]);
    end

    //$fwrite(fd_issueq, "\n\niqValidVect:     %b\n", coreTop.issueq.iqValidVect);
    $fwrite(fd_issueq, "src1MatchVect:   %b\n",     coreTop.issueq.src1MatchVect);
    //$fwrite(fd_issueq, "src1Valid_t1:    %b\n",     coreTop.issueq.src1Valid_t1);
    //$fwrite(fd_issueq, "src1ValidVect:   %b\n",     coreTop.issueq.src1ValidVect);

    //$fwrite(fd_issueq, "\n\niqValidVect:     %b\n", coreTop.issueq.iqValidVect);
    $fwrite(fd_issueq, "src2MatchVect:   %b\n",     coreTop.issueq.src2MatchVect);
    //$fwrite(fd_issueq, "src2Valid_t1:    %b\n",     coreTop.issueq.src2Valid_t1);
    //$fwrite(fd_issueq, "src2ValidVect:   %b\n",     coreTop.issueq.src2ValidVect);


    /* Select */

    $fwrite(fd_issueq, "\n\n               -- Select --\n\n");

    //$fwrite(fd_issueq, "iqValidVect:     %b\n", coreTop.issueq.iqValidVect);
    //$fwrite(fd_issueq, "src1ValidVect:   %b\n", coreTop.issueq.src1ValidVect);
    //$fwrite(fd_issueq, "src2ValidVect:   %b\n", coreTop.issueq.src2ValidVect);
    $fwrite(fd_issueq, "reqVect:         %b\n", coreTop.issueq.reqVect);
    `ifndef DYNAMIC_CONFIG
      $fwrite(fd_issueq, "reqVectFU0:      %b\n", coreTop.issueq.reqVectFU0);
      $fwrite(fd_issueq, "reqVectFU1:      %b\n", coreTop.issueq.reqVectFU1);
      $fwrite(fd_issueq, "reqVectFU2:      %b\n", coreTop.issueq.reqVectFU2);
      `ifdef ISSUE_FOUR_WIDE
        $fwrite(fd_issueq, "reqVectFU3:      %b\n", coreTop.issueq.reqVectFU3);
      `endif
      `ifdef ISSUE_FIVE_WIDE
        $fwrite(fd_issueq, "reqVectFU4:      %b\n", coreTop.issueq.reqVectFU4);
      `endif
    `else
    `endif

    //$fwrite(fd_issueq, "grantedVect:     %b\n", coreTop.issueq.grantedVect);

    /* rrPacket_o */
    $fwrite(fd_issueq, "\nrrPacket_o        ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_issueq, "     [%1d] ", i);

    $fwrite(fd_issueq, "\nseqNo:            ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_issueq, "%08x ", rrPacket[i].seqNo);

    $fwrite(fd_issueq, "\npc:               ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_issueq, "%08x ", rrPacket[i].pc);

    $fwrite(fd_issueq, "\ninst:           ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_issueq, "      %2x ",  rrPacket[i].inst);

    $fwrite(fd_issueq, "\nphyDest:          ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_issueq, "      %2x ", rrPacket[i].phyDest);

    $fwrite(fd_issueq, "\nphySrc1:          ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_issueq, "      %2x ", rrPacket[i].phySrc1);

    $fwrite(fd_issueq, "\nphySrc2:          ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_issueq, "      %2x ", rrPacket[i].phySrc2);

    $fwrite(fd_issueq, "\nimmed:            ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_issueq, "    %04x ", rrPacket[i].immed);

    $fwrite(fd_issueq, "\nlsqID:            ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_issueq, "      %2x ", rrPacket[i].lsqID);

    $fwrite(fd_issueq, "\nalID:             ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_issueq, "      %2x ", rrPacket[i].alID);

    $fwrite(fd_issueq, "\nldstSize:         ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_issueq, "       %1x ", rrPacket[i].ldstSize);

    $fwrite(fd_issueq, "\nctiID:            ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_issueq, "      %2x ", rrPacket[i].ctiID);

    $fwrite(fd_issueq, "\npredNPC:          ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_issueq, "%08x ", rrPacket[i].predNPC);

    $fwrite(fd_issueq, "\npredDir:          ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_issueq, "       %1x ", rrPacket[i].predDir);

    $fwrite(fd_issueq, "\ngrantedEntry (V): ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_issueq, "  %2x (%1d) ", iqGrantedEntry[i].id, iqGrantedEntry[i].valid);

    $fwrite(fd_issueq,"\n\n");

    //$fwrite(fd_issueq, "freedVect:       %b\n", coreTop.issueq.freedVect);
    $fwrite(fd_issueq, "freedEntry (V): ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_issueq, "  %2x (%1d) ", iqFreedEntry[i].id, iqFreedEntry[i].valid);
    
    $fwrite(fd_issueq,"\n");
    /* for (i = 0;i< `NO_OF_COMPLEX; i++) */
    /* $fwrite(fd_issueq,"issue_simple[%x] : %b    ",i,coreTop.issueq.issue_simple[i]); */    
/*
    $fwrite(fd_issueq,"\n\n");
    $fwrite(fd_issueq,"RSR1 (V) :");
    for (i = 0;i < `FU1_LATENCY;i++)
        $fwrite(fd_issueq,"   %2x (%1d) ",coreTop.issueq.rsr.RSR_CALU1[i],coreTop.issueq.rsr.RSR_CALU_VALID1[i]);
    $fwrite(fd_issueq,"\n\n");
    
    $fwrite(fd_issueq,"RSR2 (V) :");
    for (i = 0;i < `FU1_LATENCY;i++)
        $fwrite(fd_issueq,"   %2x (%1d) ",coreTop.issueq.rsr.RSR_CALU2[i],coreTop.issueq.rsr.RSR_CALU_VALID2[i]);
*/
    $fwrite(fd_issueq,"\n\n\n");
endtask


payloadPkt                      rrPacket_l1    [0:`ISSUE_WIDTH-1];
/* fuPkt                           exePacket      [0:`ISSUE_WIDTH-1]; */

/* Prints register read related signals and latch value. */
task regread_debug_print;
    int i;
    for (i = 0; i < `ISSUE_WIDTH; i++)
    begin
        rrPacket_l1[i]  = coreTop.rrPacket_l1[i];
    end

    $fwrite(fd_regread, "------------------------------------------------------\n");
    $fwrite(fd_regread, "Cycle: %0d  Commit: %0d\n\n",CYCLE_COUNT, COMMIT_COUNT);

    $fwrite(fd_regread, "               -- rrPacket_i --\n");

    /* rrPacket_i */
    $fwrite(fd_regread, "\nrrPacket_i        ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_regread, "     [%1d] ", i);

    $fwrite(fd_regread, "\npc:               ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_regread, "%08x ", rrPacket_l1[i].pc);

    $fwrite(fd_regread, "\ninst:           ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_regread, "      %2x ",  rrPacket_l1[i].inst);

    $fwrite(fd_regread, "\nphyDest:          ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_regread, "      %2x ", rrPacket_l1[i].phyDest);

    $fwrite(fd_regread, "\nphySrc1:          ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_regread, "      %2x ", rrPacket_l1[i].phySrc1);

    $fwrite(fd_regread, "\nphySrc2:          ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_regread, "      %2x ", rrPacket_l1[i].phySrc2);

    $fwrite(fd_regread, "\nimmed:            ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_regread, "    %04x ", rrPacket_l1[i].immed);

    $fwrite(fd_regread, "\nlsqID:            ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_regread, "      %2x ", rrPacket_l1[i].lsqID);

    $fwrite(fd_regread, "\nalID:             ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_regread, "      %2x ", rrPacket_l1[i].alID);

    /* $fwrite(fd_regread, "\nldstSize:         "); */
    /* for (i = 0; i < `ISSUE_WIDTH; i++) */
    /*     $fwrite(fd_regread, "       %1x ", rrPacket_l1[i].ldstSize); */

    $fwrite(fd_regread, "\nctiID:            ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_regread, "      %2x ", rrPacket_l1[i].ctiID);

    $fwrite(fd_regread, "\npredNPC:          ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_regread, "%08x ", rrPacket_l1[i].predNPC);

    $fwrite(fd_regread, "\npredDir:          ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_regread, "       %1x ", rrPacket_l1[i].predDir);

    $fwrite(fd_regread, "\nvalid:            ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_regread, "       %1x ", rrPacket_l1[i].valid);


    $fwrite(fd_regread, "\n\n               -- bypassPacket_i --\n");

    /* rrPacket_i */
    $fwrite(fd_regread, "\nbypassPacket_i    ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_regread, "     [%1d] ", i);

    $fwrite(fd_regread, "\ntag:              ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_regread, "      %2x ", bypassPacket[i].tag);

    $fwrite(fd_regread, "\ndata:             ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_regread, "%08x ",  bypassPacket[i].data);

    $fwrite(fd_regread, "\nvalid:            ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_regread, "       %1x ", bypassPacket[i].valid);


    $fwrite(fd_regread, "\n\n               -- exePacket_o --\n");

    /* rrPacket_i */
    $fwrite(fd_regread, "\nexePacket_o       ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_regread, "     [%1d] ", i);

    $fwrite(fd_regread, "\npc:               ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_regread, "%08x ", exePacket[i].pc);

    $fwrite(fd_regread, "\ninst:           ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_regread, "      %2x ",  exePacket[i].inst);

    $fwrite(fd_regread, "\nphyDest:          ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_regread, "      %2x ", exePacket[i].phyDest);

    $fwrite(fd_regread, "\nphySrc1:          ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_regread, "      %2x ", exePacket[i].phySrc1);

    $fwrite(fd_regread, "\nsrc1Data:         ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_regread, "%08x ", exePacket[i].src1Data);

    $fwrite(fd_regread, "\nphySrc2:          ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_regread, "      %2x ", exePacket[i].phySrc2);

    $fwrite(fd_regread, "\nsrc2Data:         ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_regread, "%08x ", exePacket[i].src2Data);

    $fwrite(fd_regread, "\nimmed:            ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_regread, "    %04x ", exePacket[i].immed);

    $fwrite(fd_regread, "\nlsqID:            ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_regread, "      %2x ", exePacket[i].lsqID);

    $fwrite(fd_regread, "\nalID:             ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_regread, "      %2x ", exePacket[i].alID);

    /* $fwrite(fd_regread, "\nldstSize:         "); */
    /* for (i = 0; i < `ISSUE_WIDTH; i++) */
    /*     $fwrite(fd_regread, "       %1x ", exePacket[i].ldstSize); */

    $fwrite(fd_regread, "\nctiID:            ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_regread, "      %2x ", exePacket[i].ctiID);

    $fwrite(fd_regread, "\npredNPC:          ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_regread, "%08x ", exePacket[i].predNPC);

    $fwrite(fd_regread, "\npredDir:          ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_regread, "       %1x ", exePacket[i].predDir);

    $fwrite(fd_regread, "\nvalid:            ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_regread, "       %1x ", exePacket[i].valid);

    $fwrite(fd_regread, "\n\n\n");

endtask


reg  [`SIZE_PHYSICAL_LOG-1:0]               src1Addr [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]               src2Addr [0:`ISSUE_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]               destAddr [0:`ISSUE_WIDTH-1];
//reg  [`SIZE_PHYSICAL_LOG-1:0]               src1Addr_byte0 [0:`ISSUE_WIDTH-1];
//reg  [`SIZE_PHYSICAL_LOG-1:0]               src1Addr_byte1 [0:`ISSUE_WIDTH-1];
//reg  [`SIZE_PHYSICAL_LOG-1:0]               src1Addr_byte2 [0:`ISSUE_WIDTH-1];
//reg  [`SIZE_PHYSICAL_LOG-1:0]               src1Addr_byte3 [0:`ISSUE_WIDTH-1];
//reg  [`SIZE_PHYSICAL_LOG-1:0]               src2Addr_byte0 [0:`ISSUE_WIDTH-1];
//reg  [`SIZE_PHYSICAL_LOG-1:0]               src2Addr_byte1 [0:`ISSUE_WIDTH-1];
//reg  [`SIZE_PHYSICAL_LOG-1:0]               src2Addr_byte2 [0:`ISSUE_WIDTH-1];
//reg  [`SIZE_PHYSICAL_LOG-1:0]               src2Addr_byte3 [0:`ISSUE_WIDTH-1];
//reg  [`SIZE_PHYSICAL_LOG-1:0]               destAddr_byte0 [0:`ISSUE_WIDTH-1];
//reg  [`SIZE_PHYSICAL_LOG-1:0]               destAddr_byte1 [0:`ISSUE_WIDTH-1];
//reg  [`SIZE_PHYSICAL_LOG-1:0]               destAddr_byte2 [0:`ISSUE_WIDTH-1];
//reg  [`SIZE_PHYSICAL_LOG-1:0]               destAddr_byte3 [0:`ISSUE_WIDTH-1];

/* Prints register read related signals and latch value. */
task prf_debug_print;
    int i, j;
    for (i = 0; i < `ISSUE_WIDTH; i++)
    begin
        for (j = 0; j < `SIZE_PHYSICAL_TABLE; j++)
        begin
            if (coreTop.registerfile.phySrc1_i[i][j])
            begin
                src1Addr[i]              = j;
            end

            if (coreTop.registerfile.phySrc2_i[i][j])
            begin
                src2Addr[i]              = j;
            end

            if (coreTop.registerfile.destAddr[i][j])
            begin
                destAddr[i]              = j;
            end

            //if (coreTop.registerfile.src1Addr_byte0[i][j])
            //begin
            //    src1Addr_byte0[i]              = j;
            //end

            //if (coreTop.registerfile.src1Addr_byte1[i][j])
            //begin
            //    src1Addr_byte1[i]              = j;
            //end

            //if (coreTop.registerfile.src1Addr_byte2[i][j])
            //begin
            //    src1Addr_byte2[i]              = j;
            //end

            //if (coreTop.registerfile.src1Addr_byte3[i][j])
            //begin
            //    src1Addr_byte3[i]              = j;
            //end


            //if (coreTop.registerfile.src2Addr_byte0[i][j])
            //begin
            //    src2Addr_byte0[i]              = j;
            //end

            //if (coreTop.registerfile.src2Addr_byte1[i][j])
            //begin
            //    src2Addr_byte1[i]              = j;
            //end

            //if (coreTop.registerfile.src2Addr_byte2[i][j])
            //begin
            //    src2Addr_byte2[i]              = j;
            //end

            //if (coreTop.registerfile.src2Addr_byte3[i][j])
            //begin
            //    src2Addr_byte3[i]              = j;
            //end


            //if (coreTop.registerfile.destAddr_byte0[i][j])
            //begin
            //    destAddr_byte0[i]              = j;
            //end

            //if (coreTop.registerfile.destAddr_byte1[i][j])
            //begin
            //    destAddr_byte1[i]              = j;
            //end

            //if (coreTop.registerfile.destAddr_byte2[i][j])
            //begin
            //    destAddr_byte2[i]              = j;
            //end

            //if (coreTop.registerfile.destAddr_byte3[i][j])
            //begin
            //    destAddr_byte3[i]              = j;
            //end
        end
    end


    $fwrite(fd_prf, "------------------------------------------------------\n");
    $fwrite(fd_prf, "Cycle: %0d  Commit: %0d\n\n",CYCLE_COUNT, COMMIT_COUNT);

    $fwrite(fd_prf, "               -- Read --\n");

    /* Read */
    $fwrite(fd_prf, "\n                  ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_prf, "     [%1d] ", i);

    $fwrite(fd_prf, "\nsrc1Addr:   ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_prf, "      %02x ", src1Addr[i]);

    $fwrite(fd_prf, "\nsrc1Data:   ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_prf, "      %02x ", coreTop.registerfile.src1Data_o[i]);

    $fwrite(fd_prf, "\nsrc2Addr:   ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_prf, "      %02x ", src2Addr[i]);

    $fwrite(fd_prf, "\nsrc2Data:   ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_prf, "      %02x ", coreTop.registerfile.src2Data_o[i]);

    //$fwrite(fd_prf, "\nsrc1Addr_byte0:   ");
    //for (i = 0; i < `ISSUE_WIDTH; i++)
    //    $fwrite(fd_prf, "      %02x ", src1Addr_byte0[i]);

    //$fwrite(fd_prf, "\nsrc1Data_byte0:   ");
    //for (i = 0; i < `ISSUE_WIDTH; i++)
    //    $fwrite(fd_prf, "      %02x ", coreTop.registerfile.src1Data_byte0_o[i]);

    //$fwrite(fd_prf, "\n\nsrc1Addr_byte1:   ");
    //for (i = 0; i < `ISSUE_WIDTH; i++)
    //    $fwrite(fd_prf, "      %02x ", src1Addr_byte1[i]);

    //$fwrite(fd_prf, "\nsrc1Data_byte1:   ");
    //for (i = 0; i < `ISSUE_WIDTH; i++)
    //    $fwrite(fd_prf, "      %02x ", coreTop.registerfile.src1Data_byte1_o[i]);

    //$fwrite(fd_prf, "\n\nsrc1Addr_byte2:   ");
    //for (i = 0; i < `ISSUE_WIDTH; i++)
    //    $fwrite(fd_prf, "      %02x ", src1Addr_byte2[i]);

    //$fwrite(fd_prf, "\nsrc1Data_byte2:   ");
    //for (i = 0; i < `ISSUE_WIDTH; i++)
    //    $fwrite(fd_prf, "      %02x ", coreTop.registerfile.src1Data_byte2_o[i]);

    //$fwrite(fd_prf, "\n\nsrc1Addr_byte3:   ");
    //for (i = 0; i < `ISSUE_WIDTH; i++)
    //    $fwrite(fd_prf, "      %02x ", src1Addr_byte3[i]);

    //$fwrite(fd_prf, "\nsrc1Data_byte3:   ");
    //for (i = 0; i < `ISSUE_WIDTH; i++)
    //    $fwrite(fd_prf, "      %02x ", coreTop.registerfile.src1Data_byte3_o[i]);


    //$fwrite(fd_prf, "\n\nsrc2Addr_byte0:   ");
    //for (i = 0; i < `ISSUE_WIDTH; i++)
    //    $fwrite(fd_prf, "      %02x ", src2Addr_byte0[i]);

    //$fwrite(fd_prf, "\nsrc2Data_byte0:   ");
    //for (i = 0; i < `ISSUE_WIDTH; i++)
    //    $fwrite(fd_prf, "      %02x ", coreTop.registerfile.src2Data_byte0_o[i]);

    //$fwrite(fd_prf, "\n\nsrc2Addr_byte1:   ");
    //for (i = 0; i < `ISSUE_WIDTH; i++)
    //    $fwrite(fd_prf, "      %02x ", src2Addr_byte1[i]);

    //$fwrite(fd_prf, "\nsrc2Data_byte1:   ");
    //for (i = 0; i < `ISSUE_WIDTH; i++)
    //    $fwrite(fd_prf, "      %02x ", coreTop.registerfile.src2Data_byte1_o[i]);

    //$fwrite(fd_prf, "\n\nsrc2Addr_byte2:   ");
    //for (i = 0; i < `ISSUE_WIDTH; i++)
    //    $fwrite(fd_prf, "      %02x ", src2Addr_byte2[i]);

    //$fwrite(fd_prf, "\nsrc2Data_byte2:   ");
    //for (i = 0; i < `ISSUE_WIDTH; i++)
    //    $fwrite(fd_prf, "      %02x ", coreTop.registerfile.src2Data_byte2_o[i]);

    //$fwrite(fd_prf, "\n\nsrc2Addr_byte3:   ");
    //for (i = 0; i < `ISSUE_WIDTH; i++)
    //    $fwrite(fd_prf, "      %02x ", src2Addr_byte3[i]);

    //$fwrite(fd_prf, "\nsrc2Data_byte3:   ");
    //for (i = 0; i < `ISSUE_WIDTH; i++)
    //    $fwrite(fd_prf, "      %02x ", coreTop.registerfile.src2Data_byte3_o[i]);

    $fwrite(fd_prf, "\n\n\n               -- Write --\n");

    /* Write */
    $fwrite(fd_prf, "\n                  ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_prf, "     [%1d] ", i);

    $fwrite(fd_prf, "\ndestAddr:   ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_prf, "      %02x ", destAddr[i]);

    $fwrite(fd_prf, "\ndestData:   ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_prf, "      %02x ", coreTop.registerfile.destData[i]);

    //$fwrite(fd_prf, "\ndestAddr_byte0:   ");
    //for (i = 0; i < `ISSUE_WIDTH; i++)
    //    $fwrite(fd_prf, "      %02x ", destAddr_byte0[i]);

    //$fwrite(fd_prf, "\ndestData_byte0:   ");
    //for (i = 0; i < `ISSUE_WIDTH; i++)
    //    $fwrite(fd_prf, "      %02x ", coreTop.registerfile.destData_byte0[i]);

    //$fwrite(fd_prf, "\ndestWe_byte0:     ");
    //for (i = 0; i < `ISSUE_WIDTH; i++)
    //    $fwrite(fd_prf, "       %1x ", coreTop.registerfile.destWe_byte0[i]);

    //$fwrite(fd_prf, "\n\ndestAddr_byte1:   ");
    //for (i = 0; i < `ISSUE_WIDTH; i++)
    //    $fwrite(fd_prf, "      %02x ", destAddr_byte1[i]);

    //$fwrite(fd_prf, "\ndestData_byte1:   ");
    //for (i = 0; i < `ISSUE_WIDTH; i++)
    //    $fwrite(fd_prf, "      %02x ", coreTop.registerfile.destData_byte1[i]);

    //$fwrite(fd_prf, "\ndestWe_byte1:     ");
    //for (i = 0; i < `ISSUE_WIDTH; i++)
    //    $fwrite(fd_prf, "       %1x ", coreTop.registerfile.destWe_byte1[i]);

    //$fwrite(fd_prf, "\n\ndestAddr_byte2:   ");
    //for (i = 0; i < `ISSUE_WIDTH; i++)
    //    $fwrite(fd_prf, "      %02x ", destAddr_byte2[i]);

    //$fwrite(fd_prf, "\ndestData_byte2:   ");
    //for (i = 0; i < `ISSUE_WIDTH; i++)
    //    $fwrite(fd_prf, "      %02x ", coreTop.registerfile.destData_byte2[i]);

    //$fwrite(fd_prf, "\ndestWe_byte2:     ");
    //for (i = 0; i < `ISSUE_WIDTH; i++)
    //    $fwrite(fd_prf, "       %1x ", coreTop.registerfile.destWe_byte2[i]);

    //$fwrite(fd_prf, "\n\ndestAddr_byte3:   ");
    //for (i = 0; i < `ISSUE_WIDTH; i++)
    //    $fwrite(fd_prf, "      %02x ", destAddr_byte3[i]);

    //$fwrite(fd_prf, "\ndestData_byte3:   ");
    //for (i = 0; i < `ISSUE_WIDTH; i++)
    //    $fwrite(fd_prf, "      %02x ", coreTop.registerfile.destData_byte3[i]);

    //$fwrite(fd_prf, "\ndestWe_byte3:     ");
    //for (i = 0; i < `ISSUE_WIDTH; i++)
    //    $fwrite(fd_prf, "       %1x ", coreTop.registerfile.destWe_byte3[i]);

    $fwrite(fd_prf, "\n\n\n");

endtask


fuPkt                           exePacket_l1   [0:`ISSUE_WIDTH-1];
//wbPkt                           wbPacket       [0:`ISSUE_WIDTH-1];
reg  [31:0]                     src1Data       [0:`ISSUE_WIDTH-1];
reg  [31:0]                     src2Data       [0:`ISSUE_WIDTH-1];

/* Prints functional units */
task exe_debug_print;
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


    $fwrite(fd_exe, "------------------------------------------------------\n");
    $fwrite(fd_exe, "Cycle: %0d  Commit: %0d\n\n", CYCLE_COUNT, COMMIT_COUNT);


    $fwrite(fd_exe, "               -- exePacket_i --\n");

    /* exePacket_l1_i */
    $fwrite(fd_exe, "\nexePacket_i       ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_exe, "     [%1d] ", i);

    $fwrite(fd_exe, "\npc:               ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_exe, "%08x ", exePacket_l1[i].pc);

    $fwrite(fd_exe, "\ninst:           ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_exe, "      %2x ",  exePacket_l1[i].inst);

    $fwrite(fd_exe, "\nphyDest:          ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_exe, "      %2x ", exePacket_l1[i].phyDest);

    $fwrite(fd_exe, "\nphySrc1:          ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_exe, "      %2x ", exePacket_l1[i].phySrc1);

    $fwrite(fd_exe, "\nsrc1Data:         ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_exe, "%08x ", exePacket_l1[i].src1Data);

    $fwrite(fd_exe, "\nphySrc2:          ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_exe, "      %2x ", exePacket_l1[i].phySrc2);

    $fwrite(fd_exe, "\nsrc2Data:         ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_exe, "%08x ", exePacket_l1[i].src2Data);

    $fwrite(fd_exe, "\nimmed:            ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_exe, "    %04x ", exePacket_l1[i].immed);

    $fwrite(fd_exe, "\nlsqID:            ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_exe, "      %2x ", exePacket_l1[i].lsqID);

    $fwrite(fd_exe, "\nalID:             ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_exe, "      %2x ", exePacket_l1[i].alID);

    $fwrite(fd_exe, "\nctiID:            ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_exe, "      %2x ", exePacket_l1[i].ctiID);

    $fwrite(fd_exe, "\npredNPC:          ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_exe, "%08x ", exePacket_l1[i].predNPC);

    $fwrite(fd_exe, "\npredDir:          ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_exe, "       %1x ", exePacket_l1[i].predDir);

    $fwrite(fd_exe, "\nvalid:            ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_exe, "       %1x ", exePacket_l1[i].valid);


    $fwrite(fd_exe, "\n\n               -- bypassPacket_i --\n");

    /* rrPacket_i */
    $fwrite(fd_exe, "\nbypassPacket_i    ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_exe, "     [%1d] ", i);

    $fwrite(fd_exe, "\ntag:              ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_exe, "      %2x ", bypassPacket[i].tag);

    $fwrite(fd_exe, "\ndata:             ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_exe, "%8x ",  bypassPacket[i].data);

    $fwrite(fd_exe, "\nvalid:            ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_exe, "       %1x ", bypassPacket[i].valid);


    $fwrite(fd_exe, "\n\nsrc1Data:         ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_exe, "%08x ", src1Data[i]);

    $fwrite(fd_exe, "\nsrc2Data:         ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_exe, "%08x ", src2Data[i]);


    $fwrite(fd_exe, "\n\n               -- wbPacket_o --\n");

    /* wbPacket_i */
    $fwrite(fd_exe, "\nwbPacket_i        ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_exe, "     [%1d] ", i);

    $fwrite(fd_exe, "\npc:               ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_exe, "%08x ", wbPacket[i].pc);

    $fwrite(fd_exe, "\nflags:            ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_exe, "      %2x ",  wbPacket[i].flags);

    $fwrite(fd_exe, "\nphyDest:          ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_exe, "      %2x ", wbPacket[i].phyDest);

    $fwrite(fd_exe, "\ndestData:         ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_exe, "%08x ", wbPacket[i].destData);

    $fwrite(fd_exe, "\nalID:             ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_exe, "      %2x ", wbPacket[i].alID);

    $fwrite(fd_exe, "\nnextPC:           ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_exe, "%08x ", wbPacket[i].nextPC);

    $fwrite(fd_exe, "\nctrlType:         ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_exe, "      %2x ", wbPacket[i].ctrlType);

    $fwrite(fd_exe, "\nctrlDir:          ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_exe, "       %x ", wbPacket[i].ctrlDir);

    $fwrite(fd_exe, "\nctiID:            ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_exe, "      %2x ", wbPacket[i].ctiID);

    $fwrite(fd_exe, "\npredDir:          ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_exe, "       %1x ", wbPacket[i].predDir);

    $fwrite(fd_exe, "\nvalid:            ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_exe, "       %1x ", wbPacket[i].valid);

    $fwrite(fd_exe, "\n\n\n");

endtask



memPkt                         memPacket;
memPkt                         replayPacket;

wbPkt                          lsuWbPacket;
ldVioPkt                       ldVioPacket;

/* Prints load-store related signals and latch value. */
task lsu_debug_print;
    int i;
    logic [`SIZE_LSQ_LOG-1:0]               lastMatch;
    logic [2+`SIZE_PC+`SIZE_RMT_LOG+2*`SIZE_PHYSICAL_LOG:0] val;
    memPacket      = coreTop.memPacket;
    replayPacket   = coreTop.lsu.datapath.replayPacket;
    lsuWbPacket    = coreTop.wbPacket;
    ldVioPacket    = coreTop.ldVioPacket;


    $fwrite(fd_lsu, "------------------------------------------------------\n");
    $fwrite(fd_lsu, "Cycle: %0d  Commit: %0d\n\n\n",CYCLE_COUNT, COMMIT_COUNT);

    $fwrite(fd_lsu, "               -- Dispatched Instructions --\n\n");
    
    $fwrite(fd_lsu, "ldqHead_i:      %x\n", coreTop.lsu.datapath.stx_path.ldqHead_i);
    $fwrite(fd_lsu, "ldqTail_i:      %x\n", coreTop.lsu.datapath.stx_path.ldqTail_i);
    $fwrite(fd_lsu, "stqHead_i:      %x\n", coreTop.lsu.datapath.ldx_path.stqHead_i);
    $fwrite(fd_lsu, "stqTail_i:      %x\n", coreTop.lsu.datapath.ldx_path.stqTail_i);
    $fwrite(fd_lsu, "dispatchReady_i: %b\n", coreTop.lsu.dispatchReady_i);
    $fwrite(fd_lsu, "recoverFlag_i : %b\n", coreTop.lsu.recoverFlag_i);

    /* lsqPacket_i */
    $fwrite(fd_lsu, "lsqPacket_i       ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_lsu, "     [%1d] ", i);

    $fwrite(fd_lsu, "\npredLoadVio:      ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_lsu, "       %1x ", lsqPacket[i].predLoadVio);

    $fwrite(fd_lsu, "\nisLoad:           ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_lsu, "       %1x ", lsqPacket[i].isLoad);

    $fwrite(fd_lsu, "\nisStore:          ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_lsu, "       %1x ", lsqPacket[i].isStore);

    $fwrite(fd_lsu, "\nlsqID:            ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_lsu, "      %2x ", coreTop.lsqID[i]);

    $fwrite(fd_lsu, "\nldqID:            ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_lsu, "      %2x ", coreTop.lsu.ldqID[i]);

    $fwrite(fd_lsu, "\nstqID:            ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_lsu, "      %2x ", coreTop.lsu.stqID[i]);

    $fwrite(fd_lsu, "\nnextLd:            ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_lsu, "      %x ", coreTop.lsu.datapath.nextLdIndex_i[i]);

    $fwrite(fd_lsu, "\nlastSt:            ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_lsu, "      %x ", coreTop.lsu.datapath.lastStIndex_i[i]);

    $fwrite(fd_lsu, "\n\n\n               -- Executed Instructions --\n\n");
    
    /* memPacket_i */
    $fwrite(fd_lsu, "memPacket_i       ");
    for (i = 0; i < 1; i++)
        $fwrite(fd_lsu, "     [%1d] ", i);

    $fwrite(fd_lsu, "\nPC:            ");
    for (i = 0; i < 1; i++)
        $fwrite(fd_lsu, "      %x  ", memPacket.pc);

    $fwrite(fd_lsu, "\nflags:            ");
    for (i = 0; i < 1; i++)
        $fwrite(fd_lsu, "      %2x ", memPacket.flags);

    $fwrite(fd_lsu, "\nldstSize:         ");
    for (i = 0; i < 1; i++)
        $fwrite(fd_lsu, "       %1x ", memPacket.ldstSize);

    $fwrite(fd_lsu, "\nphyDest:          ");
    for (i = 0; i < 1; i++)
        $fwrite(fd_lsu, "      %2x ", memPacket.phyDest);

    $fwrite(fd_lsu, "\naddress:          ");
    for (i = 0; i < 1; i++)
        $fwrite(fd_lsu, "%08x ",     memPacket.address);

    $fwrite(fd_lsu, "\nsrc2Data:         ");
    for (i = 0; i < 1; i++)
        $fwrite(fd_lsu, "%08x ",     memPacket.src2Data);

    $fwrite(fd_lsu, "\nlsqID:            ");
    for (i = 0; i < 1; i++)
        $fwrite(fd_lsu, "      %2x ", memPacket.lsqID);

    $fwrite(fd_lsu, "\nalID:             ");
    for (i = 0; i < 1; i++)
        $fwrite(fd_lsu, "      %2x ", memPacket.alID);

    $fwrite(fd_lsu, "\nvalid:            ");
    for (i = 0; i < 1; i++)
        $fwrite(fd_lsu, "       %1x ", memPacket.valid);

    /* replayPacket_i */
    $fwrite(fd_lsu, "\n\nreplayPacket       ");
    for (i = 0; i < 1; i++)
        $fwrite(fd_lsu, "     [%1d] ", i);

    $fwrite(fd_lsu, "\nPC:            ");
    for (i = 0; i < 1; i++)
        $fwrite(fd_lsu, "      %x  ", replayPacket.pc);

    $fwrite(fd_lsu, "\nflags:            ");
    for (i = 0; i < 1; i++)
        $fwrite(fd_lsu, "      %2x ", replayPacket.flags);

    $fwrite(fd_lsu, "\nldstSize:         ");
    for (i = 0; i < 1; i++)
        $fwrite(fd_lsu, "       %1x ", replayPacket.ldstSize);

    $fwrite(fd_lsu, "\nphyDest:          ");
    for (i = 0; i < 1; i++)
        $fwrite(fd_lsu, "      %2x ", replayPacket.phyDest);

    $fwrite(fd_lsu, "\naddress:          ");
    for (i = 0; i < 1; i++)
        $fwrite(fd_lsu, "%08x ",     replayPacket.address);

    $fwrite(fd_lsu, "\nsrc2Data:         ");
    for (i = 0; i < 1; i++)
        $fwrite(fd_lsu, "%08x ",     replayPacket.src2Data);

    $fwrite(fd_lsu, "\nlsqID:            ");
    for (i = 0; i < 1; i++)
        $fwrite(fd_lsu, "      %2x ", replayPacket.lsqID);

    $fwrite(fd_lsu, "\nalID:             ");
    for (i = 0; i < 1; i++)
        $fwrite(fd_lsu, "      %2x ", replayPacket.alID);

    $fwrite(fd_lsu, "\nvalid:            ");
    for (i = 0; i < 1; i++)
        $fwrite(fd_lsu, "       %1x ", replayPacket.valid);

    $fwrite(fd_lsu, "\n\n\nlastSt:            ");
    for (i = 0; i < 1; i++)
        $fwrite(fd_lsu, "       %x ", coreTop.lsu.datapath.ldx_path.LD_DISAMBIGUATION.lastSt);


    /* lsuWbPacket_o */
    $fwrite(fd_lsu, "\n\nlsuWbPacket_o        ");
    for (i = 0; i < 1; i++)
        $fwrite(fd_lsu, "     [%1d] ", i);

    $fwrite(fd_lsu, "\npc:               ");
    for (i = 0; i < 1; i++)
        $fwrite(fd_lsu, "%08x ", lsuWbPacket.pc);

    $fwrite(fd_lsu, "\nflags:            ");
    for (i = 0; i < 1; i++)
        $fwrite(fd_lsu, "      %2x ", lsuWbPacket.flags);

    $fwrite(fd_lsu, "\nphyDest:          ");
    for (i = 0; i < 1; i++)
        $fwrite(fd_lsu, "      %2x ", lsuWbPacket.phyDest);

    $fwrite(fd_lsu, "\ndestData:         ");
    for (i = 0; i < 1; i++)
        $fwrite(fd_lsu, "%08x ",     lsuWbPacket.destData);

    $fwrite(fd_lsu, "\nalID:             ");
    for (i = 0; i < 1; i++)
        $fwrite(fd_lsu, "      %2x ", lsuWbPacket.alID);

    $fwrite(fd_lsu, "\nvalid:            ");
    for (i = 0; i < 1; i++)
        $fwrite(fd_lsu, "       %1x ", lsuWbPacket.valid);


    $fwrite(fd_lsu, "\n\n\n               -- LD Disambiguation (LDX) --\n\n");

    $fwrite(fd_lsu, "stqCount_i:  %x\n",
            coreTop.lsu.datapath.ldx_path.stqCount_i);

    $fwrite(fd_lsu, "stqAddrValid:  %b\n",
            coreTop.lsu.datapath.ldx_path.stqAddrValid);

    $fwrite(fd_lsu, "stqValid:  %b\n",
            coreTop.lsu.control.stqValid);

    $fwrite(fd_lsu, "vulnerableStVector_t1:  %b\n",
            coreTop.lsu.datapath.ldx_path.LD_DISAMBIGUATION.vulnerableStVector_t1);

    $fwrite(fd_lsu, "vulnerableStVector_t2:  %b\n",
            coreTop.lsu.datapath.ldx_path.LD_DISAMBIGUATION.vulnerableStVector_t2);

    $fwrite(fd_lsu, "vulnerableStVector:     %b\n",
            coreTop.lsu.datapath.ldx_path.LD_DISAMBIGUATION.vulnerableStVector);

//  `ifndef DYNAMIC_CONFIG                
//    $fwrite(fd_lsu, "addr1MatchVector:       %b\n",
//            coreTop.lsu.datapath.ldx_path.LD_DISAMBIGUATION.addr1MatchVector);
//
//    $fwrite(fd_lsu, "addr2MatchVector:       %b\n",
//            coreTop.lsu.datapath.ldx_path.LD_DISAMBIGUATION.addr2MatchVector);
//  `else                
    $fwrite(fd_lsu, "addr1MatchVector:       %b\n",
            coreTop.lsu.datapath.ldx_path.addr1MatchVector);

    $fwrite(fd_lsu, "addr2MatchVector:       %b\n",
            coreTop.lsu.datapath.ldx_path.addr2MatchVector);
//  `endif

    //$fwrite(fd_lsu, "sizeMismatchVector:     %b\n",
    //        coreTop.lsu.datapath.ldx_path.LD_DISAMBIGUATION.sizeMismatchVector);

    $fwrite(fd_lsu, "forwardVector1:         %b\n",
            coreTop.lsu.datapath.ldx_path.LD_DISAMBIGUATION.forwardVector1);

    $fwrite(fd_lsu, "forwardVector2:         %b\n\n",
            coreTop.lsu.datapath.ldx_path.LD_DISAMBIGUATION.forwardVector2);


//  `ifndef DYNAMIC_CONFIG        
//    lastMatch = coreTop.lsu.datapath.ldx_path.LD_DISAMBIGUATION.lastMatch;
//  `else
    lastMatch = coreTop.lsu.datapath.ldx_path.lastMatch;
//  `endif
    $fwrite(fd_lsu, "stqHit:         %b\n", coreTop.lsu.datapath.ldx_path.stqHit);
    $fwrite(fd_lsu, "lastMatch:      %x\n", lastMatch);
    $fwrite(fd_lsu, "partialStMatch: %b\n", coreTop.lsu.datapath.ldx_path.partialStMatch);
    $fwrite(fd_lsu, "disambigStall:  %b\n\n", coreTop.lsu.datapath.ldx_path.LD_DISAMBIGUATION.disambigStall);
    $fwrite(fd_lsu, "loadDataValid_o: %b\n", coreTop.lsu.datapath.ldx_path.loadDataValid_o);
    $fwrite(fd_lsu, "dcacheData:  %08x\n", coreTop.lsu.datapath.ldx_path.dcacheData);
//  `ifndef DYNAMIC_CONFIG        
//    $fwrite(fd_lsu, "stqData[%d]: %08x\n", lastMatch, coreTop.lsu.datapath.ldx_path.stqData[lastMatch]);
//  `else        
    $fwrite(fd_lsu, "stqData[%d]: %08x\n", lastMatch, coreTop.lsu.datapath.ldx_path.stqHitData);
//  `endif
    $fwrite(fd_lsu, "loadData_t:  %08x\n", coreTop.lsu.datapath.ldx_path.loadData_t);
    $fwrite(fd_lsu, "loadData_o:  %08x\n", coreTop.lsu.datapath.ldx_path.loadData_o);
        

    $fwrite(fd_lsu, "\n\n\n               -- LD Violation (STX) --\n\n");

    $fwrite(fd_lsu, "ldqAddrValid:           %b\n",
            coreTop.lsu.datapath.stx_path.ldqAddrValid);

    $fwrite(fd_lsu, "ldqWriteBack:           %b\n",
            coreTop.lsu.datapath.stx_path.ldqWriteBack);

    $fwrite(fd_lsu, "vulnerableLdVector_t1:  %b\n",
            coreTop.lsu.datapath.stx_path.LD_VIOLATION.vulnerableLdVector_t1);

    $fwrite(fd_lsu, "vulnerableLdVector_t2:  %b\n",
            coreTop.lsu.datapath.stx_path.LD_VIOLATION.vulnerableLdVector_t2);

    $fwrite(fd_lsu, "vulnerableLdVector_t3:  %b\n",
            coreTop.lsu.datapath.stx_path.LD_VIOLATION.vulnerableLdVector_t3);

    $fwrite(fd_lsu, "vulnerableLdVector_t4:  %b\n",
            coreTop.lsu.datapath.stx_path.LD_VIOLATION.vulnerableLdVector_t4);

    $fwrite(fd_lsu, "matchVector_st:         %b\n",
            coreTop.lsu.datapath.stx_path.LD_VIOLATION.matchVector_st);

//  `ifndef DYNAMIC_CONFIG
//    $fwrite(fd_lsu, "matchVector_st1:        %b\n",
//                coreTop.lsu.datapath.stx_path.LD_VIOLATION.matchVector_st1);
//  `else                
    $fwrite(fd_lsu, "matchVector_st1:        %b\n",
                coreTop.lsu.datapath.stx_path.matchVector_st1);
//  `endif

    //$fwrite(fd_lsu, "matchVector_st2:        %b\n",
    //        coreTop.lsu.datapath.stx_path.LD_VIOLATION.matchVector_st2);

    //$fwrite(fd_lsu, "matchVector_st3:        %b\n",
    //        coreTop.lsu.datapath.stx_path.LD_VIOLATION.matchVector_st3);

    $fwrite(fd_lsu, "violateVector:          %b\n",
            coreTop.lsu.datapath.stx_path.LD_VIOLATION.violateVector);


    //$fwrite(fd_lsu, "nextLoad:       %x\n", coreTop.lsu.datapath.stx_path.LD_VIOLATION.nextLoad);
//  `ifndef DYNAMIC_CONFIG
//    $fwrite(fd_lsu, "firstMatch:     %x\n", coreTop.lsu.datapath.stx_path.LD_VIOLATION.firstMatch);
//  `else                
    $fwrite(fd_lsu, "firstMatch:     %x\n", coreTop.lsu.datapath.stx_path.firstMatch);
//  `endif
    $fwrite(fd_lsu, "agenLdqMatch:   %b\n", coreTop.lsu.datapath.stx_path.LD_VIOLATION.agenLdqMatch);
    $fwrite(fd_lsu, "violateLdValid: %x\n", coreTop.lsu.datapath.stx_path.violateLdValid);
    $fwrite(fd_lsu, "violateLdALid:  %x\n", coreTop.lsu.datapath.stx_path.violateLdALid);
    
    $fwrite(fd_lsu, "\n\n\n               -- Committed Instructions --\n\n");
    
    $fwrite(fd_lsu, "stqHead_i:   %d\n", coreTop.lsu.datapath.ldx_path.stqHead_i);
    $fwrite(fd_lsu, "commitSt_i:  %x\n", coreTop.lsu.datapath.ldx_path.commitSt_i);
    $fwrite(fd_lsu, "stCommitAddr:  %x\n", coreTop.lsu.datapath.ldx_path.stCommitAddr);
    $fwrite(fd_lsu, "stCommitData:  %x\n", coreTop.lsu.datapath.ldx_path.stCommitData);
    $fwrite(fd_lsu, "commitStCount:  %x", coreTop.lsu.control.commitStCount);
    $fwrite(fd_lsu, "commitStIndex: ");
    for (i = 0; i < 4; i++)
    begin
      $fwrite(fd_lsu, "  %x", coreTop.lsu.control.commitStIndex[i]);
    end

//    for (i = 0; i < `SIZE_LSQ; i++)
//    begin
//    `ifndef DYNAMIC_CONFIG          
//      $fwrite(fd_lsu, "stqAddr[%0d]: %08x\n", i, {coreTop.lsu.datapath.ldx_path.stqAddr1[i],
//                                                      coreTop.lsu.datapath.ldx_path.stqAddr2[i]});
//    `endif                                                      
//    end
        
//    for (i = 0; i < `SIZE_LSQ; i++)
//    begin
//    `ifndef DYNAMIC_CONFIG          
//      $fwrite(fd_lsu, "stqData[%0d]: %08x\n", i, coreTop.lsu.datapath.ldx_path.stqData[i]);
//    `endif
//    end

    $fwrite(fd_lsu, "commitLoad_i:  %b\n",
              coreTop.lsu.commitLoad_i);

    $fwrite(fd_lsu, "commitStore_i: %b\n",
              coreTop.lsu.commitStore_i);

    $fwrite(fd_lsu,"\n\n");
endtask



//ctrlPkt                         ctrlPacket [0:`ISSUE_WIDTH-1];
commitPkt                       amtPacket [0:`COMMIT_WIDTH-1];

/* Prints active list/retire related signals and latch value. */
task alist_debug_print;
    int i;
    for (i = 0; i < `ISSUE_WIDTH; i++)
    begin
        ctrlPacket[i]   = coreTop.ctrlPacket[i];
    end

    for (i = 0; i < `COMMIT_WIDTH; i++)
    begin
        amtPacket[i]   = coreTop.amtPacket[i];
    end

    $fwrite(fd_alist, "------------------------------------------------------\n");
    $fwrite(fd_alist, "Cycle: %0d  Commit: %0d\n\n\n",CYCLE_COUNT, COMMIT_COUNT);

  `ifdef DYNAMIC_CONFIG
    $fwrite(fd_alist, "dispatchLaneActive_i: %x\n",
    coreTop.activeList.dispatchLaneActive_i);

    $fwrite(fd_alist, "issueLaneActive_i: %x\n",
    coreTop.activeList.issueLaneActive_i);
  `endif        

    $fwrite(fd_alist, "totalCommit: d%d\n",
    coreTop.activeList.totalCommit);

    $fwrite(fd_alist, "alCount: d%d\n",
    coreTop.activeList.alCount);

    $fwrite(fd_alist, "headPtr: %x tailPtr: %x\n",
    coreTop.activeList.headPtr,
    coreTop.activeList.tailPtr);

    $fwrite(fd_alist, "dispatchReady_i: %b\n\n",
    coreTop.activeList.dispatchReady_i);

    $fwrite(fd_alist, "               -- Dispatched Instructions --\n\n");
    
    /* alPacket_i */
    $fwrite(fd_alist, "\nalPacket_i    ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_alist, "     [%1d] ", i);

    $fwrite(fd_alist, "\npc:           ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_alist, "%08x ", alPacket[i].pc);

    $fwrite(fd_alist, "\nlogDest:      ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_alist, "      %2x ", alPacket[i].logDest);

    $fwrite(fd_alist, "\nphyDest (V):  ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_alist, "  %2x (%d) ", alPacket[i].phyDest, alPacket[i].phyDestValid);

    $fwrite(fd_alist, "\nisLoad:       ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_alist, "       %1x ", alPacket[i].isLoad);

    $fwrite(fd_alist, "\nisStore:      ");
    for (i = 0; i < `DISPATCH_WIDTH; i++)
        $fwrite(fd_alist, "       %1x ", alPacket[i].isStore);

    $fwrite(fd_alist, "\n\n\n               -- Executed Instructions --\n");

    $fwrite(fd_alist, "\nctrlPacket_i      ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_alist, "     [%1d] ", i);

    $fwrite(fd_alist, "\nnextPC:           ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_alist, "%08x ", ctrlPacket[i].nextPC);

    $fwrite(fd_alist, "\nalID:             ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_alist, "      %2x ", ctrlPacket[i].alID);

    $fwrite(fd_alist, "\nflags:            ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_alist, "      %2x ", ctrlPacket[i].flags);

    $fwrite(fd_alist, "\nvalid:            ");
    for (i = 0; i < `ISSUE_WIDTH; i++)
        $fwrite(fd_alist, "       %1x ", ctrlPacket[i].valid);
    
    
    $fwrite(fd_alist, "\n\n\n               -- Committing Instructions --\n\n");
    
    $fwrite(fd_alist, "              ");
    for (i = 0; i < `COMMIT_WIDTH; i++)
        $fwrite(fd_alist, "     [%1d] ", i);

    $fwrite(fd_alist, "\nmispredFlag:  "); 
    for (i = 0; i < `COMMIT_WIDTH; i++)
        $fwrite(fd_alist, "       %b ", coreTop.activeList.mispredFlag[i]);

    $fwrite(fd_alist, "\nviolateFlag:  ");
    for (i = 0; i < `COMMIT_WIDTH; i++)
        $fwrite(fd_alist, "       %b ", coreTop.activeList.violateFlag[i]);
    
    $fwrite(fd_alist, "\nexceptionFlag:");
    for (i = 0; i < `COMMIT_WIDTH; i++)
        $fwrite(fd_alist, "       %b ", coreTop.activeList.exceptionFlag[i]);

    $fwrite(fd_alist, "\n\ncommitReady:  ");
    for (i = 0; i < `COMMIT_WIDTH; i++)
        $fwrite(fd_alist, "       %b ", coreTop.activeList.commitReady[i]);

    $fwrite(fd_alist, "\ncommitVector: ");
    for (i = 0; i < `COMMIT_WIDTH; i++)
        $fwrite(fd_alist, "       %b ", coreTop.activeList.commitVector[i]);


    $fwrite(fd_alist, "\n\namtPacket_o   ");
    for (i = 0; i < `COMMIT_WIDTH; i++)
        $fwrite(fd_alist, "     [%1d] ", i);

    $fwrite(fd_alist, "\nlogDest:      ");
    for (i = 0; i < `COMMIT_WIDTH; i++)
        $fwrite(fd_alist, "      %2x ", amtPacket[i].logDest);

    $fwrite(fd_alist, "\nphyDest:      ");
    for (i = 0; i < `COMMIT_WIDTH; i++)
        $fwrite(fd_alist, "      %2x ", amtPacket[i].phyDest);

    $fwrite(fd_alist, "\nvalid:        ");
    for (i = 0; i < `COMMIT_WIDTH; i++)
        $fwrite(fd_alist, "       %1x ", amtPacket[i].valid);

    $fwrite(fd_alist, "\npc:           ");
    for (i = 0; i < `COMMIT_WIDTH; i++)
        $fwrite(fd_alist, "%08x ", coreTop.activeList.commitPC[i]);

    $fwrite(fd_alist, "\n\ncommitStore:  ");
    for (i = 0; i < `COMMIT_WIDTH; i++)
        $fwrite(fd_alist, "       %1x ", coreTop.activeList.commitStore_o[i]);

    $fwrite(fd_alist, "\ncommitLoad:   ");
    for (i = 0; i < `COMMIT_WIDTH; i++)
        $fwrite(fd_alist, "       %1x ", coreTop.activeList.commitLoad_o[i]);

    $fwrite(fd_alist, "\ncommitCti:    ");
    for (i = 0; i < `COMMIT_WIDTH; i++)
        $fwrite(fd_alist, "       %1x ", coreTop.activeList.commitCti_o[i]);

    $fwrite(fd_alist,"\n\n");

    
    if (coreTop.activeList.violateFlag_reg)
    begin
        $fwrite(fd_alist, "violateFlag_reg: %d recoverPC_o: %h\n",
        coreTop.activeList.violateFlag_reg,
        coreTop.activeList.recoverPC_o);
    end

    if (coreTop.activeList.mispredFlag_reg)
    begin
        $fwrite(fd_alist,"mispredFlag_reg: %d recoverPC_o: %h\n",
        coreTop.activeList.mispredFlag_reg,
        coreTop.activeList.recoverPC_o);
    end

    if (coreTop.activeList.exceptionFlag_reg)
    begin
        $fwrite(fd_alist,"exceptionFlag_reg: %d exceptionPC_o: %h\n",
        coreTop.activeList.exceptionFlag_reg,
        coreTop.activeList.exceptionPC_o);
    end

    $fwrite(fd_alist,"\n");
    
endtask

