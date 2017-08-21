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

export "DPI-C" function get_csr_from_rtl;
export "DPI-C" task set_csr_in_rtl;
export "DPI-C" task end_rtl_simulation;
export "DPI-C" task flush_caches_in_rtl;

task end_rtl_simulation;
        ipc = $itor(COMMIT_COUNT)/$itor(CYCLE_COUNT);

        $display("\n\nSimulation Complete\n");
        // Before the simulator is terminated, print all the stats:
        $display("Fetch1-Stall          %5d",fetch1_stall   );  
        $display("Ctiq-Stall            %5d",ctiq_stall     );
        $display("InstBuff-Stall        %5d",instBuf_stall  ); 
        $display("FreeList-Stall        %5d",freelist_stall );
        $display("SMT-Stall             %5d",smt_stall      );
        $display("Backend-Stall         %5d",backend_stall  );
        $display("LDQ-Stall             %5d",ldq_stall      );
        $display("STQ-Stall             %5d",stq_stall      );
        $display("IQ-Stall              %5d",iq_stall       );
        $display("ROB-Stall             %5d",rob_stall      );

        $display("stat_num_corr         %5d", stat_num_corr);
        $display("stat_num_pred         %5d", stat_num_pred);
        $display("stat_num_cond_corr    %5d", stat_num_cond_corr);
        $display("stat_num_cond_pred    %5d", stat_num_cond_pred);
        $display("stat_num_return_corr  %5d", stat_num_return_corr);
        $display("stat_num_return_pred  %5d", stat_num_return_pred);
        $display("");

        ib_avg    = ib_count/(CYCLE_COUNT-10.0);
        fl_avg    = fl_count/(CYCLE_COUNT-10.0);
        iq_avg    = iq_count/(CYCLE_COUNT-10.0);
        ldq_avg   = ldq_count/(CYCLE_COUNT-10.0);
        stq_avg   = stq_count/(CYCLE_COUNT-10.0);
        al_avg    = al_count/(CYCLE_COUNT-10.0);

        $write("IB-avg                 %2.2f\n", ib_avg); 
        $write("FL-avg                 %2.2f\n", fl_avg); 
        $write("IQ-avg                 %2.2f\n", iq_avg); 
        $write("LDQ-avg                %2.2f\n", ldq_avg); 
        $write("STQ-avg                %2.2f\n", stq_avg); 
        $write("AL-avg                 %2.2f\n", al_avg); 

        $display("IPC                    %2.2f",ipc                  );                   
        $display("Cycle Count           %5d"  ,CYCLE_COUNT          );
        $display("Commit Count          %5d"  ,COMMIT_COUNT         );           
        $display("BTB-Miss              %5d"  ,btb_miss             );
        $display("BTB-Miss-Rtn          %5d"  ,btb_miss_rtn         );
        $display("Br-Count              %5d"  ,br_count             );
        $display("Br-Mispredict         %5d"  ,br_mispredict_count  );
        $display("Ld Count              %5d"  ,ld_count             );
        $display("Ld Violation          %5d"  ,load_violation_count );

        `ifdef DUMP_STATS
          ib_avg    = ib_count/(CYCLE_COUNT-10.0);
          fl_avg    = fl_count/(CYCLE_COUNT-10.0);
          iq_avg    = iq_count/(CYCLE_COUNT-10.0);
          ldq_avg   = ldq_count/(CYCLE_COUNT-10.0);
          stq_avg   = stq_count/(CYCLE_COUNT-10.0);
          al_avg    = al_count/(CYCLE_COUNT-10.0);

          $fwrite(fd_stats, "%d, ", CYCLE_COUNT); 
          $fwrite(fd_stats, "%d, ", COMMIT_COUNT); 

          $fwrite(fd_stats, "%2.3f, ", ib_avg); 
          $fwrite(fd_stats, "%2.3f, ", fl_avg); 
          $fwrite(fd_stats, "%2.3f, ", iq_avg); 
          $fwrite(fd_stats, "%2.4f, ", ldq_avg); 
          $fwrite(fd_stats, "%2.4f, ", stq_avg); 
          $fwrite(fd_stats, "%2.3f, ", al_avg); 

          $fwrite(fd_stats, "%d, ", fetch1_stall); 
          $fwrite(fd_stats, "%d, ", ctiq_stall); 
          $fwrite(fd_stats, "%d, ", instBuf_stall); 
          $fwrite(fd_stats, "%d, ", freelist_stall); 
          $fwrite(fd_stats, "%d, ", backend_stall); 
          $fwrite(fd_stats, "%d, ", ldq_stall); 
          $fwrite(fd_stats, "%d, ", stq_stall); 
          $fwrite(fd_stats, "%d, ", iq_stall); 
          $fwrite(fd_stats, "%d, ", rob_stall); 

          $fwrite(fd_stats, "%d, ", btb_miss); 
          $fwrite(fd_stats, "%d, ", btb_miss_rtn); 
          $fwrite(fd_stats, "%d, ", br_count); 
          $fwrite(fd_stats, "%d, ", br_mispredict_count); 
          $fwrite(fd_stats, "%d, ", load_violation_count); 

          $fwrite(fd_stats, "%d, ", stat_num_corr);
          $fwrite(fd_stats, "%d, ", stat_num_pred);
          $fwrite(fd_stats, "%d, ", stat_num_cond_corr);
          $fwrite(fd_stats, "%d, ", stat_num_cond_pred);
          $fwrite(fd_stats, "%d, ", stat_num_return_corr);
          $fwrite(fd_stats, "%d, ", stat_num_return_pred);

          $fwrite(fd_stats, "%d, ", commit_1); 
          $fwrite(fd_stats, "%d, ", commit_2); 
          $fwrite(fd_stats, "%d, ", commit_3); 
          $fwrite(fd_stats, "%d\n", commit_4); 
        `endif
        
        close_log_files();

        // Dump performance counters
        `ifdef PERF_MON
          read_perf_mon();
        `endif  

        $display("");
        $finish;
endtask

task take_interrupt();
  longint sr;
  int irqs;
  longint nextPC;
  longint exceptingPC;

  exceptingPC = dataAl[0].pc; 

  //sr = get_pcr(`CSR_STATUS);
  sr = get_csr_from_rtl(`CSR_STATUS);

  //irqs = ((sr & `SR_IP) >> `SR_IP_SHIFT) & (sr >> `SR_IM_SHIFT);
  irqs = coreTop.supregisterfile.interrupts;

  //if (!irqs || !(sr & `SR_EI))
  if (coreTop.supregisterfile.interruptPending_o)
  begin

    // This is a priority decoder that finds the cause of the highest
    // priority interrupt.
    for (int i = 0; i < 64 ; i++)
    begin
      if ((irqs >> i) & 1)
      begin
        take_trap((1 << ((sr & `SR_S64) ? 63 : 31)) + i,exceptingPC);
        break;
      end
    end
  end
  //return 1;

endtask

task take_trap(longint trap_cause,longint trap_pc);
  longint sr;
  longint badvaddr;
  int     checkPassed;
  int     htifRet;

  //TODO: Using function call rather than direct read
  //badvaddr = coreTop.supregisterfile.csr_badvaddr_next;
  badvaddr = get_csr_from_rtl(`CSR_BADVADDR);

  if (loggingOn)
    $display("Exception %d 0x%16x 0x%16x",trap_cause,trap_pc,badvaddr);

  //sr = get_pcr(`CSR_STATUS);
  sr = get_csr_from_rtl(`CSR_STATUS);
  // switch to supervisor, set previous supervisor bit, disable interrupts
  set_csr_in_rtl(`CSR_STATUS,(((sr & ~`SR_EI) | `SR_S) & ~`SR_PS & ~`SR_PEI) |
                              ((sr & `SR_S) ? `SR_PS : 0) |
                              ((sr & `SR_EI) ? `SR_PEI : 0));

  set_pcr(`CSR_STATUS, (((sr & ~`SR_EI) | `SR_S) & ~`SR_PS & ~`SR_PEI) |
                        ((sr & `SR_S) ? `SR_PS : 0) |
                        ((sr & `SR_EI) ? `SR_PEI : 0));

  //set_pcr(LOAD_RESERVATION, 64'hffffffffffffffff);
  set_csr_in_rtl(`CSR_CAUSE, trap_cause);
  set_pcr(`CSR_CAUSE, trap_cause);

  set_csr_in_rtl(`CSR_EPC, trap_pc);
  set_pcr(`CSR_EPC,trap_pc);

  // Set badvaddr if mem trap
  if(trap_cause == `CAUSE_MISALIGNED_FETCH ||
     trap_cause == `CAUSE_FAULT_FETCH ||
     trap_cause == `CAUSE_MISALIGNED_LOAD ||
     trap_cause == `CAUSE_MISALIGNED_STORE ||
     trap_cause == `CAUSE_FAULT_LOAD ||
     trap_cause == `CAUSE_FAULT_STORE )
    set_pcr(`CSR_BADVADDR,badvaddr); 

  // Call checkinstruction to pop the excepting instruction
  // from the debug buffer.
  checkPassed = checkInstruction(CYCLE_COUNT,COMMIT_COUNT,trap_pc,0,0,0);
  instRetired += 1;
  set_pcr(12'h506,get_pcr(12'h506)+1); // Increment inst count in DPI
  if(instRetired == INTERLEAVE || idleCycles == INTERLEAVE)
  begin
    instRetired = 0;
    htif_tick(htifRet);
  end

  //return get_csr_from_rtl(`CSR_EVEC);
endtask

function longint get_csr_from_rtl(int which_csr);
  static int CSR_STATUS_MASK  = (64'h00000000ffffffff & ~`SR_EA & ~`SR_ZERO);
  case(which_csr[11:0])

    `CSR_FFLAGS   :get_csr_from_rtl = coreTop.supregisterfile.csr_fflags    ; 
    `CSR_FRM      :get_csr_from_rtl = coreTop.supregisterfile.csr_frm       ; 
    `CSR_FCSR     :get_csr_from_rtl = coreTop.supregisterfile.csr_fcsr      ; 
    //`CSR_STATS    :get_csr_from_rtl = coreTop.supregisterfile.csr_stats     ; 
    `CSR_SUP0     :get_csr_from_rtl = coreTop.supregisterfile.csr_sup0      ; 
    `CSR_SUP1     :get_csr_from_rtl = coreTop.supregisterfile.csr_sup1      ; 
    `CSR_EPC      :get_csr_from_rtl = coreTop.supregisterfile.csr_epc_next       ; 
    `CSR_BADVADDR :get_csr_from_rtl = coreTop.supregisterfile.csr_badvaddr_next  ; 
    `CSR_PTBR     :get_csr_from_rtl = coreTop.supregisterfile.csr_ptbr      ; 
    `CSR_ASID     :get_csr_from_rtl = coreTop.supregisterfile.csr_asid      ; 
    `CSR_COUNT    :get_csr_from_rtl = coreTop.supregisterfile.csr_count_next; 
    `CSR_COMPARE  :get_csr_from_rtl = coreTop.supregisterfile.csr_compare   ; 
    `CSR_EVEC     :get_csr_from_rtl = coreTop.supregisterfile.csr_evec      ; 
    `CSR_CAUSE    :get_csr_from_rtl = coreTop.supregisterfile.csr_cause_next     ; 
    `CSR_STATUS   :get_csr_from_rtl = coreTop.supregisterfile.csr_status_next    ; 
    `CSR_HARTID   :get_csr_from_rtl = coreTop.supregisterfile.csr_hartid    ; 
    `CSR_IMPL     :get_csr_from_rtl = coreTop.supregisterfile.csr_impl      ; 
    `CSR_FATC     :get_csr_from_rtl = coreTop.supregisterfile.csr_fatc      ; 
    `CSR_SEND_IPI :get_csr_from_rtl = coreTop.supregisterfile.csr_send_ipi  ; 
    `CSR_CLEAR_IPI:get_csr_from_rtl = coreTop.supregisterfile.csr_clear_ipi ; 
    //`CSR_RESET    :get_csr_from_rtl = coreTop.supregisterfile.csr_reset     ; 
    `CSR_TOHOST   :get_csr_from_rtl = coreTop.supregisterfile.csr_tohost    ; 
    `CSR_FROMHOST :get_csr_from_rtl = coreTop.supregisterfile.csr_fromhost  ; 
    `CSR_CYCLE    :get_csr_from_rtl = coreTop.supregisterfile.csr_count_next; 
    `CSR_TIME     :get_csr_from_rtl = coreTop.supregisterfile.csr_count_next; 
    `CSR_INSTRET  :get_csr_from_rtl = coreTop.supregisterfile.csr_count_next; 
    //`CSR_CYCLEH   :get_csr_from_rtl = coreTop.supregisterfile.csr_cycleh    ; 
    //`CSR_TIMEH    :get_csr_from_rtl = coreTop.supregisterfile.csr_timeh     ; 
    //`CSR_INSTRETH :get_csr_from_rtl = coreTop.supregisterfile.csr_instreth  ; 
    default       :$stop();
  endcase

  // If however a new value is about to be written to the CSR, return that value instead.
  if(coreTop.supregisterfile.commitReg_i & (coreTop.supregisterfile.regWrAddrCommit == which_csr))
    case(which_csr[11:0])
      `CSR_STATUS: get_csr_from_rtl = ((coreTop.supregisterfile.regWrDataCommit & ~`SR_IP) | 
                                       (coreTop.supregisterfile.csr_status & `SR_IP)) & CSR_STATUS_MASK;
      default    : get_csr_from_rtl = coreTop.supregisterfile.regWrDataCommit;
    endcase

endfunction

task set_csr_in_rtl(int which_csr,longint val);

  #(CLKPERIOD/10);
  if (loggingOn)
    $display("Cycle: %11d Commit: %11d Setting RTL CSR 0x%x -> 0x%16x",CYCLE_COUNT,COMMIT_COUNT,which_csr,val);

  case(which_csr[11:0])
    `CSR_FFLAGS   :coreTop.supregisterfile.csr_fflags    = val; 
    `CSR_FRM      :coreTop.supregisterfile.csr_frm       = val; 
    `CSR_FCSR     :coreTop.supregisterfile.csr_fcsr      = val; 
    //`CSR_STATS    :coreTop.supregisterfile.csr_stats     = val; 
    `CSR_SUP0     :coreTop.supregisterfile.csr_sup0      = val; 
    `CSR_SUP1     :coreTop.supregisterfile.csr_sup1      = val; 
    `CSR_EPC      :coreTop.supregisterfile.csr_epc       = val; 
    `CSR_BADVADDR :coreTop.supregisterfile.csr_badvaddr  = val; 
    `CSR_PTBR     :coreTop.supregisterfile.csr_ptbr      = val; 
    `CSR_ASID     :coreTop.supregisterfile.csr_asid      = val; 
    `CSR_COUNT    :coreTop.supregisterfile.csr_count     = val; 
    `CSR_COMPARE  :coreTop.supregisterfile.csr_compare   = val; 
    `CSR_EVEC     :coreTop.supregisterfile.csr_evec      = val; 
    `CSR_CAUSE    :coreTop.supregisterfile.csr_cause     = val; 
    `CSR_STATUS   :coreTop.supregisterfile.csr_status    = val; 
    `CSR_HARTID   :coreTop.supregisterfile.csr_hartid    = val; 
    `CSR_IMPL     :coreTop.supregisterfile.csr_impl      = val; 
    `CSR_FATC     :coreTop.supregisterfile.csr_fatc      = val; 
    `CSR_SEND_IPI :coreTop.supregisterfile.csr_send_ipi  = val; 
    `CSR_CLEAR_IPI:coreTop.supregisterfile.csr_clear_ipi = val; 
    //`CSR_RESET    :coreTop.supregisterfile.csr_reset     = val; 
    `CSR_TOHOST   :coreTop.supregisterfile.csr_tohost    = val; 
    `CSR_FROMHOST :coreTop.supregisterfile.csr_fromhost  = val; 
    `CSR_CYCLE    :coreTop.supregisterfile.csr_cycle     = val; 
    `CSR_TIME     :coreTop.supregisterfile.csr_time      = val; 
    `CSR_INSTRET  :coreTop.supregisterfile.csr_instret   = val; 
    //`CSR_CYCLEH   :coreTop.supregisterfile.csr_cycleh    = val; 
    //`CSR_TIMEH    :coreTop.supregisterfile.csr_timeh     = val; 
    //`CSR_INSTRETH :coreTop.supregisterfile.csr_instreth  = val; 
    default       :$stop();
  endcase

endtask

task flush_caches_in_rtl();
  if (loggingOn)
    $display("Cycle: %11d Commit: %11d Flushing Caches",CYCLE_COUNT,COMMIT_COUNT);

  dcFlush = 1'b1;
endtask

task open_log_files;
  fd_fetch1   = $fopen("results/fetch1.txt","w");
  fd_fetch2   = $fopen("results/fetch2.txt","w");
  fd_decode   = $fopen("results/decode.txt","w");
  fd_ibuff    = $fopen("results/instBuf.txt","w");
  fd_rename   = $fopen("results/rename.txt","w");
  fd_dispatch = $fopen("results/dispatch.txt","w");
  fd_select   = $fopen("results/select.txt","w");
  fd_issueq   = $fopen("results/issueq.txt","w");
  fd_regread  = $fopen("results/regread.txt","w");
  fd_prf      = $fopen("results/PhyRegFile.txt","w");
  fd_exe      = $fopen("results/exe.txt","w");
  fd_alist    = $fopen("results/activeList.txt","w");
  fd_lsu      = $fopen("results/lsu.txt","w");
  fd_wback    = $fopen("results/writebk.txt","w");
  fd_stats    = $fopen("results/statistics.txt","w");
  fd_coretop  = $fopen("results/coretop.txt","w");
  fd_bhr      = $fopen("results/bhr.txt","w");
  fd_specbhr  = $fopen("results/specBHR.txt","w");
endtask

task close_log_files;
  $fclose(fd_fetch1   );
  $fclose(fd_fetch2   );
  $fclose(fd_decode   );
  $fclose(fd_ibuff    );
  $fclose(fd_rename   );
  $fclose(fd_dispatch );
  $fclose(fd_select   );
  $fclose(fd_issueq   );
  $fclose(fd_regread  );
  $fclose(fd_prf      );
  $fclose(fd_exe      );
  $fclose(fd_alist    );
  $fclose(fd_lsu      );
  $fclose(fd_wback    );
  $fclose(fd_stats    );
  $fclose(fd_coretop);
  $fclose(fd_bhr      );
  $fclose(fd_specbhr  );
endtask


task copyRF;

    integer i;
    logic [`SIZE_DATA-1:0] written_value;
    reg rfCopyDone;
    rfCopyDone = 0;

    @(negedge clk)
    begin
`ifdef DYNAMIC_CONFIG          
        for (i = 0; i < 32; i++)
        begin
            coreTop.registerfile.PhyRegFile.ram_partitioned_no_decode.INST_LOOP[0].ram_instance_no_decode.ram[i] = LOGICAL_REG[i];
            //coreTop.registerfile.PhyRegFile_byte0.ram_partitioned_no_decode.INST_LOOP[0].ram_instance_no_decode.ram[i] = LOGICAL_REG[i][7:0];
            //coreTop.registerfile.PhyRegFile_byte1.ram_partitioned_no_decode.INST_LOOP[0].ram_instance_no_decode.ram[i] = LOGICAL_REG[i][15:8];
            //coreTop.registerfile.PhyRegFile_byte2.ram_partitioned_no_decode.INST_LOOP[0].ram_instance_no_decode.ram[i] = LOGICAL_REG[i][23:16];
            //coreTop.registerfile.PhyRegFile_byte3.ram_partitioned_no_decode.INST_LOOP[0].ram_instance_no_decode.ram[i] = LOGICAL_REG[i][31:24];
            //coreTop.registerfile.PhyRegFile_byte4.ram_partitioned_no_decode.INST_LOOP[0].ram_instance_no_decode.ram[i] = LOGICAL_REG[i][39:32];
            //coreTop.registerfile.PhyRegFile_byte5.ram_partitioned_no_decode.INST_LOOP[0].ram_instance_no_decode.ram[i] = LOGICAL_REG[i][47:40];
            //coreTop.registerfile.PhyRegFile_byte6.ram_partitioned_no_decode.INST_LOOP[0].ram_instance_no_decode.ram[i] = LOGICAL_REG[i][55:48];
            //coreTop.registerfile.PhyRegFile_byte7.ram_partitioned_no_decode.INST_LOOP[0].ram_instance_no_decode.ram[i] = LOGICAL_REG[i][63:56];
        end
        for (i = 32; i < `SIZE_RMT; i++)
        begin
            coreTop.registerfile.PhyRegFile.ram_partitioned_no_decode.INST_LOOP[1].ram_instance_no_decode.ram[i-32] = LOGICAL_REG[i];
            //coreTop.registerfile.PhyRegFile_byte0.ram_partitioned_no_decode.INST_LOOP[1].ram_instance_no_decode.ram[i-32] = LOGICAL_REG[i][7:0];
            //coreTop.registerfile.PhyRegFile_byte1.ram_partitioned_no_decode.INST_LOOP[1].ram_instance_no_decode.ram[i-32] = LOGICAL_REG[i][15:8];
            //coreTop.registerfile.PhyRegFile_byte2.ram_partitioned_no_decode.INST_LOOP[1].ram_instance_no_decode.ram[i-32] = LOGICAL_REG[i][23:16];
            //coreTop.registerfile.PhyRegFile_byte3.ram_partitioned_no_decode.INST_LOOP[1].ram_instance_no_decode.ram[i-32] = LOGICAL_REG[i][31:24];
            //coreTop.registerfile.PhyRegFile_byte4.ram_partitioned_no_decode.INST_LOOP[1].ram_instance_no_decode.ram[i-32] = LOGICAL_REG[i][39:32];
            //coreTop.registerfile.PhyRegFile_byte5.ram_partitioned_no_decode.INST_LOOP[1].ram_instance_no_decode.ram[i-32] = LOGICAL_REG[i][47:40];
            //coreTop.registerfile.PhyRegFile_byte6.ram_partitioned_no_decode.INST_LOOP[1].ram_instance_no_decode.ram[i-32] = LOGICAL_REG[i][55:48];
            //coreTop.registerfile.PhyRegFile_byte7.ram_partitioned_no_decode.INST_LOOP[1].ram_instance_no_decode.ram[i-32] = LOGICAL_REG[i][63:56];
        end
`else
        for (i = 0; i < `SIZE_RMT; i++)
        begin
            coreTop.registerfile.PhyRegFile.ram[i] = LOGICAL_REG[i];
            written_value = coreTop.registerfile.PhyRegFile.ram[i];
            //coreTop.registerfile.PhyRegFile_byte0.ram[i] = LOGICAL_REG[i][7:0];
            //coreTop.registerfile.PhyRegFile_byte1.ram[i] = LOGICAL_REG[i][15:8];
            //coreTop.registerfile.PhyRegFile_byte2.ram[i] = LOGICAL_REG[i][23:16];
            //coreTop.registerfile.PhyRegFile_byte3.ram[i] = LOGICAL_REG[i][31:24];
            //coreTop.registerfile.PhyRegFile_byte4.ram[i] = LOGICAL_REG[i][39:32];
            //coreTop.registerfile.PhyRegFile_byte5.ram[i] = LOGICAL_REG[i][47:40];
            //coreTop.registerfile.PhyRegFile_byte6.ram[i] = LOGICAL_REG[i][55:48];
            //coreTop.registerfile.PhyRegFile_byte7.ram[i] = LOGICAL_REG[i][63:56];

            //written_value = {coreTop.registerfile.PhyRegFile_byte7.ram[i],
            //                 coreTop.registerfile.PhyRegFile_byte6.ram[i],
            //                 coreTop.registerfile.PhyRegFile_byte5.ram[i],
            //                 coreTop.registerfile.PhyRegFile_byte4.ram[i],
            //                 coreTop.registerfile.PhyRegFile_byte3.ram[i],
            //                 coreTop.registerfile.PhyRegFile_byte2.ram[i],
            //                 coreTop.registerfile.PhyRegFile_byte1.ram[i],
            //                 coreTop.registerfile.PhyRegFile_byte0.ram[i]};
            if (loggingOn)
              $display("Copied to physical register %d -> [%16x] -> (%16x)", i, LOGICAL_REG[i], written_value);
        end
`endif

    rfCopyDone = 1;
    end

  wait(rfCopyDone == 1);
endtask

task copyCSR;

  reg csrCopyDone;
  csrCopyDone = 0;

  @(negedge clk)
  begin
    set_csr_in_rtl(`CSR_FFLAGS   , get_pcr(`CSR_FFLAGS   )); 
    set_csr_in_rtl(`CSR_FRM      , get_pcr(`CSR_FRM      ));
    set_csr_in_rtl(`CSR_FCSR     , get_pcr(`CSR_FCSR     ));
    //set_csr_in_rtl(`CSR_STATS    , get_pcr(`CSR_STATS    ));
    set_csr_in_rtl(`CSR_SUP0     , get_pcr(`CSR_SUP0     ));
    set_csr_in_rtl(`CSR_SUP1     , get_pcr(`CSR_SUP1     ));
    set_csr_in_rtl(`CSR_EPC      , get_pcr(`CSR_EPC      ));
    set_csr_in_rtl(`CSR_BADVADDR , get_pcr(`CSR_BADVADDR ));
    set_csr_in_rtl(`CSR_PTBR     , get_pcr(`CSR_PTBR     ));
    set_csr_in_rtl(`CSR_ASID     , get_pcr(`CSR_ASID     ));
    set_csr_in_rtl(`CSR_COUNT    , get_pcr(`CSR_COUNT    ));
    set_csr_in_rtl(`CSR_COMPARE  , get_pcr(`CSR_COMPARE  ));
    set_csr_in_rtl(`CSR_EVEC     , get_pcr(`CSR_EVEC     ));
    set_csr_in_rtl(`CSR_CAUSE    , get_pcr(`CSR_CAUSE    ));
    set_csr_in_rtl(`CSR_STATUS   , get_pcr(`CSR_STATUS   ));
    set_csr_in_rtl(`CSR_HARTID   , get_pcr(`CSR_HARTID   ));
    set_csr_in_rtl(`CSR_IMPL     , get_pcr(`CSR_IMPL     ));
    set_csr_in_rtl(`CSR_FATC     , get_pcr(`CSR_FATC     ));
    set_csr_in_rtl(`CSR_SEND_IPI , get_pcr(`CSR_SEND_IPI ));
    set_csr_in_rtl(`CSR_CLEAR_IPI, get_pcr(`CSR_CLEAR_IPI));
    //set_csr_in_rtl(`CSR_RESET    , get_pcr(`CSR_RESET    ));
    set_csr_in_rtl(`CSR_TOHOST   , get_pcr(`CSR_TOHOST   ));
    set_csr_in_rtl(`CSR_FROMHOST , get_pcr(`CSR_FROMHOST ));
    set_csr_in_rtl(`CSR_CYCLE    , get_pcr(`CSR_CYCLE    ));
    set_csr_in_rtl(`CSR_TIME     , get_pcr(`CSR_TIME     ));
    set_csr_in_rtl(`CSR_INSTRET  , get_pcr(`CSR_INSTRET  ));
    //set_csr_in_rtl(`CSR_CYCLEH   , get_pcr(`CSR_CYCLEH   ));
    //set_csr_in_rtl(`CSR_TIMEH    , get_pcr(`CSR_TIMEH    ));
    //set_csr_in_rtl(`CSR_INSTRETH , get_pcr(`CSR_INSTRETH ));
    csrCopyDone = 1;
  end
  
  wait(csrCopyDone == 1);
endtask

function reg check_csr_with_dpi;
  reg pass;

  pass = 1;

  //pass = pass & get_csr_from_rtl(`CSR_FFLAGS   )  ==  get_pcr(`CSR_FFLAGS   ); 
  //pass = pass & get_csr_from_rtl(`CSR_FRM      )  ==  get_pcr(`CSR_FRM      );
  //pass = pass & get_csr_from_rtl(`CSR_FCSR     )  ==  get_pcr(`CSR_FCSR     );
  ////pass = pass & get_csr_from_rtl(`CSR_STATS    )  ==  get_pcr(`CSR_STATS    );
  //pass = pass & get_csr_from_rtl(`CSR_SUP0     )  ==  get_pcr(`CSR_SUP0     );
  //pass = pass & get_csr_from_rtl(`CSR_SUP1     )  ==  get_pcr(`CSR_SUP1     );
  //pass = pass & get_csr_from_rtl(`CSR_EPC      )  ==  get_pcr(`CSR_EPC      );
  pass = pass & get_csr_from_rtl(`CSR_BADVADDR )  ==  get_pcr(`CSR_BADVADDR );
  pass = pass & get_csr_from_rtl(`CSR_PTBR     )  ==  get_pcr(`CSR_PTBR     );
  //pass = pass & get_csr_from_rtl(`CSR_ASID     )  ==  get_pcr(`CSR_ASID     );
  pass = pass & get_csr_from_rtl(`CSR_COUNT    )  ==  get_pcr(`CSR_COUNT    );
  //pass = pass & get_csr_from_rtl(`CSR_COMPARE  )  ==  get_pcr(`CSR_COMPARE  );
  pass = pass & get_csr_from_rtl(`CSR_EVEC     )  ==  get_pcr(`CSR_EVEC     );
  pass = pass & get_csr_from_rtl(`CSR_CAUSE    )  ==  get_pcr(`CSR_CAUSE    );
  pass = pass & get_csr_from_rtl(`CSR_STATUS   )  ==  get_pcr(`CSR_STATUS   );
  //pass = pass & get_csr_from_rtl(`CSR_HARTID   )  ==  get_pcr(`CSR_HARTID   );
  //pass = pass & get_csr_from_rtl(`CSR_IMPL     )  ==  get_pcr(`CSR_IMPL     );
  //pass = pass & get_csr_from_rtl(`CSR_FATC     )  ==  get_pcr(`CSR_FATC     );
  //pass = pass & get_csr_from_rtl(`CSR_SEND_IPI )  ==  get_pcr(`CSR_SEND_IPI );
  //pass = pass & get_csr_from_rtl(`CSR_CLEAR_IPI)  ==  get_pcr(`CSR_CLEAR_IPI);
  ////pass = pass & get_csr_from_rtl(`CSR_RESET    )  ==  get_pcr(`CSR_RESET    );
  //pass = pass & get_csr_from_rtl(`CSR_TOHOST   )  ==  get_pcr(`CSR_TOHOST   );
  //pass = pass & get_csr_from_rtl(`CSR_FROMHOST )  ==  get_pcr(`CSR_FROMHOST );
  //pass = pass & get_csr_from_rtl(`CSR_CYCLE    )  ==  get_pcr(`CSR_CYCLE    );
  //pass = pass & get_csr_from_rtl(`CSR_TIME     )  ==  get_pcr(`CSR_TIME     );
  //pass = pass & get_csr_from_rtl(`CSR_INSTRET  )  ==  get_pcr(`CSR_INSTRET  );
  ////pass = pass & get_csr_from_rtl(`CSR_CYCLEH   )  ==   get_pcr(`CSR_CYCLEH   );
  ////pass = pass & get_csr_from_rtl(`CSR_TIMEH    )  ==   get_pcr(`CSR_TIMEH    );
  ////pass = pass & get_csr_from_rtl(`CSR_INSTRETH )  ==   get_pcr(`CSR_INSTRETH );
  
  if(~pass)
  begin
    dump_csrs();
  end
  check_csr_with_dpi = pass;
endfunction

function void dump_csrs;

  $write("FFLAGS: %h -> %h ",get_csr_from_rtl(`CSR_FFLAGS   ),get_pcr(`CSR_FFLAGS   )); 
  $write("FRM   : %h -> %h ",get_csr_from_rtl(`CSR_FRM      ),get_pcr(`CSR_FRM      ));
  $write("FCSR  : %h -> %h ",get_csr_from_rtl(`CSR_FCSR     ),get_pcr(`CSR_FCSR     ));
  $write("\n");
  //$write("FFLAGS: %h -> %h ",get_csr_from_rtl(`CSR_STATS      ),get_pcr(`CSR_STATS    ));
  $write("SUP0  : %h -> %h ",get_csr_from_rtl(`CSR_SUP0     ),get_pcr(`CSR_SUP0     ));
  $write("SUP1  : %h -> %h ",get_csr_from_rtl(`CSR_SUP1     ),get_pcr(`CSR_SUP1     ));
  $write("EPC   : %h -> %h ",get_csr_from_rtl(`CSR_EPC      ),get_pcr(`CSR_EPC      ));
  $write("\n");
  $write("BADVAD: %h -> %h ",get_csr_from_rtl(`CSR_BADVADDR ),get_pcr(`CSR_BADVADDR ));
  $write("PTBR  : %h -> %h ",get_csr_from_rtl(`CSR_PTBR     ),get_pcr(`CSR_PTBR     ));
  $write("ASID  : %h -> %h ",get_csr_from_rtl(`CSR_ASID     ),get_pcr(`CSR_ASID     ));
  $write("\n");
  $write("COUNT : %h -> %h ",get_csr_from_rtl(`CSR_COUNT    ),get_pcr(`CSR_COUNT    ));
  $write("COMPAR: %h -> %h ",get_csr_from_rtl(`CSR_COMPARE  ),get_pcr(`CSR_COMPARE  ));
  $write("EVEC  : %h -> %h ",get_csr_from_rtl(`CSR_EVEC     ),get_pcr(`CSR_EVEC     ));
  $write("\n");
  $write("CAUSE : %h -> %h ",get_csr_from_rtl(`CSR_CAUSE    ),get_pcr(`CSR_CAUSE    ));
  $write("STATUS: %h -> %h ",get_csr_from_rtl(`CSR_STATUS   ),get_pcr(`CSR_STATUS   ));
  $write("HARTID: %h -> %h ",get_csr_from_rtl(`CSR_HARTID   ),get_pcr(`CSR_HARTID   ));
  $write("\n");
  $write("IMPL  : %h -> %h ",get_csr_from_rtl(`CSR_IMPL     ),get_pcr(`CSR_IMPL     ));
  $write("FATC  : %h -> %h ",get_csr_from_rtl(`CSR_FATC     ),get_pcr(`CSR_FATC     ));
  $write("SEND_I: %h -> %h ",get_csr_from_rtl(`CSR_SEND_IPI ),get_pcr(`CSR_SEND_IPI ));
  $write("\n");
  $write("CLEAR_: %h -> %h ",get_csr_from_rtl(`CSR_CLEAR_IPI),get_pcr(`CSR_CLEAR_IPI));
  //$write("FFLAGS: %h -> %h ",get_csr_from_rtl(`CSR_RESET    ),get_pcr(`CSR_RESET    ));
  $write("TOHOST: %h -> %h ",get_csr_from_rtl(`CSR_TOHOST   ),get_pcr(`CSR_TOHOST   ));
  $write("FROMHO: %h -> %h ",get_csr_from_rtl(`CSR_FROMHOST ),get_pcr(`CSR_FROMHOST ));
  $write("\n");
  //$write("CYCLE : 0x%h -> 0x%h ",get_csr_from_rtl(`CSR_CYCLE    ),get_pcr(`CSR_CYCLE    ));
  //$write("TIME  : 0x%h -> 0x%h ",get_csr_from_rtl(`CSR_TIME     ),get_pcr(`CSR_TIME     ));
  //$write("INSTRE: 0x%h -> 0x%h ",get_csr_from_rtl(`CSR_INSTRET  ),get_pcr(`CSR_INSTRET  ));
  //$write("FFLAGS: 0x%h -> 0x%h ",get_csr_from_rtl(`CSR_CYCLEH   ),get_pcr(`CSR_CYCLEH   ));
  //$write("FFLAGS: 0x%h -> 0x%h ",get_csr_from_rtl(`CSR_TIMEH    ),get_pcr(`CSR_TIMEH    ));
  //$write("FFLAGS: 0x%h -> 0x%h ",get_csr_from_rtl(`CSR_INSTRETH ),get_pcr(`CSR_INSTRETH ));
  
endfunction


//task copySimRF;
//
//    int i;
//
//    begin
//        for (i = 0; i < `SIZE_RMT; i++)
//        begin
//            PHYSICAL_REG[i] = LOGICAL_REG[i];
//        end
//
//        for (i = `SIZE_RMT; i < `SIZE_PHYSICAL_TABLE; i++)
//        begin
//            PHYSICAL_REG[i] = 0;
//        end
//    end
//endtask
//
//task init_registers;
//    integer i;
//    reg  [31:0] opcode;
//    reg  [7:0]  dest;
//    reg  [7:0]  src1;
//    reg  [7:0]  src2;
//    reg  [15:0] immed;
//    reg  [25:0] target; 
//
//    begin
//        for (i = 1; i < 34; i = i + 1)
//        begin
//            opcode  = {24'h0, `LUI};
//            dest    = i;
//            immed   = LOGICAL_REG[i][31:16];
//            `WRITE_WORD(opcode, (32'h0000_0000 + 16*(i-1)));
//            `WRITE_WORD({8'h0, dest, immed}, (32'h0000_0000 + 16*(i-1)+4));
//
//            opcode  = {24'h0, `ORI};
//            dest    = i;
//            src1    = i;
//            immed   = LOGICAL_REG[i][15:0];
//            `WRITE_WORD(opcode, (32'h0000_0000 + 16*(i-1)+8)); 
//            `WRITE_WORD({src1, dest, immed}, (32'h0000_0000 + 16*(i-1)+12)); 
//            /* $display("@%d[%08x]", i, LOGICAL_REG[i]); */
//            PHYSICAL_REG[i] = LOGICAL_REG[i];
//        end
//
//        // return from subroutine
//        opcode  = {24'h0, `RET};
//        target  = `GET_ARCH_PC >> 2;
//        `WRITE_WORD(opcode, (32'h0000_0000 + 16*(i-1))); 
//        `WRITE_WORD({6'h0, target}, (32'h0000_0000 + 16*(i-1)+4)); 
//
//        // skip two instructions per register plus 1 for jump
//        skip_instructions = 2*33 + 1;
//    end
//endtask
//
//`ifdef SCRATCH_PAD
//  task load_scratch;
//   integer  ram_index;
//   integer  offset;
//   
//   for(ram_index = 0; ram_index < `DEBUG_INST_RAM_DEPTH ; ram_index++ )
//   //for(ram_index = 0; ram_index < 2 ; ram_index++ )
//    begin
//    for(offset =0; offset < 5 ; offset ++)
//    begin
//      instScratchAddr   = {offset[2:0],ram_index[7:0]};
//      instScratchWrEn   = 1;   
//      instScratchWrData = ram_index[7:0]^offset[7:0];
//      #(CLKPERIOD);
//    end
//    end
//  endtask
//  
//  //task to load the INSTRUCTION scratch pad with the microbenchmark
//  task load_kernel_scratch;
//   integer  ram_index;
//   integer  offset;
//   integer  data_file; 
//   integer  scan_file; 
//   reg [`DEBUG_INST_RAM_WIDTH-1:0] kernel_line;
//  
//   data_file = $fopen("kernel.dat","r");
//  
//   for(ram_index = 0; ram_index < `DEBUG_INST_RAM_DEPTH ; ram_index++ )
//    begin
//    scan_file = $fscanf(data_file, "%10x\n",kernel_line);
//    for(offset = 0; offset < 5 ; offset ++)
//    begin
//      instScratchAddr   = {offset[2:0],ram_index[7:0]};
//      instScratchWrEn   = 1;   
//      instScratchWrData = kernel_line[8*(offset+1)-1-:8];
//      #(CLKPERIOD);
//    end
//    end
//  endtask
//  
//  //task to read the INSTRUCTION scratch pad
//  task read_scratch;
//   integer ram_index;
//   integer offset;
//  for(ram_index = 0; ram_index < `DEBUG_INST_RAM_DEPTH ; ram_index++ )
//    begin
//    for(offset =0; offset < 5 ; offset ++)
//    begin
//      instScratchAddr   = {offset[2:0],ram_index[7:0]};   
//      #(CLKPERIOD);
//      if(instScratchRdData != (ram_index[7:0]^offset[7:0]))
//      begin
//        $display("READ MISMATCH at %x index %d byte\n",ram_index,offset);
//        $display("Read %x , expected %x\n",instScratchRdData,ram_index[7:0]^offset[7:0]);
//      end
//    end
//   end
//  endtask
//  
//  task read_kernel_scratch;
//   integer  ram_index;
//   integer  offset;
//   integer  data_file; 
//   integer  scan_file; 
//   reg [`DEBUG_INST_RAM_WIDTH-1:0] kernel_line;
//  
//   data_file = $fopen("kernel.dat","r");
//  for(ram_index = 0; ram_index < `DEBUG_INST_RAM_DEPTH ; ram_index++ )
//    begin
//    scan_file = $fscanf(data_file, "%10x\n",kernel_line);
//    for(offset =0; offset < 5 ; offset ++)
//    begin
//      instScratchAddr   = {offset[2:0],ram_index[7:0]};   
//      #(CLKPERIOD);
//      if(instScratchRdData != kernel_line[8*(offset+1)-1-:8])
//      begin
//        $display("READ MISMATCH at %x index %d byte\n",ram_index,offset);
//        $display("Read %x , expected %x\n",instScratchRdData,kernel_line[8*(offset+1)-1-:8]);
//      end
//    end
//   end
//  
//  endtask
//
//task load_data_scratch;
//  integer  ram_index;
//  integer  offset;
//  integer  data_file; 
//  integer  scan_file; 
//  reg [`DEBUG_DATA_RAM_WIDTH-1:0] data_line;
//
//  data_file = $fopen("memout.dat","r");
//
//  for(ram_index = 0; ram_index < `DEBUG_DATA_RAM_DEPTH ; ram_index++ )
//  begin
//    scan_file = $fscanf(data_file, "%8x\n",data_line);
//    for(offset = 0; offset < 3 ; offset ++)
//    begin
//      dataScratchAddr   = {offset[1:0],ram_index[7:0]};
//      dataScratchWrEn   = 1;   
//      dataScratchWrData = data_line[8*(offset+1)-1-:8];
//      #(CLKPERIOD);
//    end
//  end
//endtask
//
//task read_data_scratch;
//  integer  ram_index;
//  integer  offset;
//  integer  data_file; 
//  integer  scan_file; 
//  reg [`DEBUG_DATA_RAM_WIDTH-1:0] data_line;
//
//  data_file = $fopen("memout.dat","r");
//  for(ram_index = 0; ram_index < `DEBUG_DATA_RAM_DEPTH ; ram_index++ )
//    begin
//    scan_file = $fscanf(data_file, "%8x\n",data_line);
//    for(offset =0; offset < 3 ; offset ++)
//    begin
//      dataScratchAddr   = {offset[1:0],ram_index[7:0]};   
//      #(CLKPERIOD);
//      //if(dataScratchRdData != data_line[8*(offset+1)-1-:8])
//      if(dataScratchRdData != data_line[8*(offset+1)-1-:8])
//      begin
//        $display("READ MISMATCH at %x index %d byte\n",ram_index,offset);
//        $display("Read %x , expected %x\n",dataScratchRdData,data_line[8*(offset+1)-1-:8]);
//      end
//    end
//  end
//endtask
//
//`endif // SCRATCH_PAD
//
////task to load the PRF from checkpoint
//task load_checkpoint_PRF;
//  integer  ram_index;
//  integer  offset;
//
//  for(ram_index = 0; ram_index < `SIZE_PHYSICAL_TABLE ; ram_index++)
//    begin
//    for(offset = 0; offset < 4 ; offset++)
//    begin
//      debugPRFAddr      = {offset[`SIZE_DATA_BYTE_OFFSET-1:0],ram_index[`SIZE_PHYSICAL_LOG-1:0]};
//      debugPRFWrEn      = 1;   
//      debugPRFWrData    = offset+ram_index;
//      #(2*CLKPERIOD);
//    end
//    end
//  debugPRFWrEn      = 0;
//endtask
//
////task to read the PRF byte by byte
//task read_checkpoint_PRF;
//  integer  ram_index;
//  integer  offset;
//
//  for(ram_index = 0; ram_index < `SIZE_PHYSICAL_TABLE ; ram_index++)
//  begin
//    for(offset = 3; offset >= 0 ; offset--)
//    begin
//      debugPRFAddr      = {offset[`SIZE_DATA_BYTE_OFFSET-1:0],ram_index[`SIZE_PHYSICAL_LOG-1:0]};
//      //debugPRFWrEn      = 1;  
//      #(2*CLKPERIOD);
//      if(debugPRFRdData      != offset+ram_index)
//      begin
//        $display("READ MISMATCH at %x index %d byte\n",ram_index,offset);
//        $display("Read %x , expected %x\n",debugPRFRdData,offset+ram_index);
//      end
//    end
//  end
//endtask
//
////task to read the ARF byte by byte
//task read_ARF;
//  integer  ram_index;
//  integer  offset;
//  reg  [7:0]      captureRF[3:0]; 
//
//  for(ram_index = 0; ram_index < `SIZE_RMT ; ram_index++)
//    begin
//    for(offset = 3; offset >= 0 ; offset--)
//    begin
//      debugPRFAddr      = {offset[`SIZE_DATA_BYTE_OFFSET-1:0],ram_index[`SIZE_PHYSICAL_LOG-1:0]};
//      //debugPRFWrEn      = 1;  
//      #(2*CLKPERIOD);
//      captureRF[offset] = debugPRFRdData;
//      if(offset == 0)
//      $display("read %x%x%x%x\n",captureRF[3],captureRF[2],captureRF[1],captureRF[0]);
//    end
//  end
//endtask
//
//
//`ifdef PERF_MON
//
//task read_perf_mon;
//  integer  index;
//  
//  perfMonRegRun        = 1'b1;
//  #(1000*CLKPERIOD)
//  perfMonRegRun        = 1'b0;
//  #CLKPERIOD;
//  for(index = 8'h00; index < 8'h05 ; index++ )
//  begin
//    perfMonRegAddr       = index[7:0];
//    #CLKPERIOD;
//  end
//  for(index = 8'h10; index < 8'h12 ; index++ )
//  begin
//    perfMonRegAddr       = index[7:0];
//    #CLKPERIOD;
//  end
//  for(index = 8'h20; index < 8'h21 ; index++ )
//  begin
//    perfMonRegAddr       = index[7:0];
//    #CLKPERIOD;
//  end
//  for(index = 8'h30; index < 8'h32 ; index++ )
//  begin
//    perfMonRegAddr       = index[7:0];
//    #CLKPERIOD;
//  end
//  for(index = 8'h40; index < 8'h49 ; index++ )
//  begin
//    perfMonRegAddr       = index[7:0];
//    #CLKPERIOD;
//  end
//  for(index = 8'h50; index < 8'h55 ; index++ )
//  begin
//    perfMonRegAddr       = index[7:0];
//    #CLKPERIOD;
//  end
// 
//  perfMonRegRun        = 1'b1;
//  perfMonRegClr        = 1'b1;  //clearPerfMon = 1
//    perfMonRegAddr       = 8'h00;
//    #CLKPERIOD;
//  
//  perfMonRegClr        = 1'b0;  //clearPerfMon = 0
//    #CLKPERIOD;
//  perfMonRegRun        = 1'b0;
//  
//  for(index = 8'h00; index < 8'h05 ; index++ )
//  begin
//    perfMonRegAddr       = index[7:0];
//    #CLKPERIOD;
//  end
//  
//  for(index = 8'h10; index < 8'h20 ; index++ )
//  begin
//    perfMonRegAddr       = index[7:0];
//    #CLKPERIOD;
//  end
//   
//  perfMonRegGlobalClr  = 1'b1;  //Global clearPerfMon = 1
//  #CLKPERIOD;
//  for(index = 8'h00; index < 8'h05 ; index++ )
//  begin
//    perfMonRegAddr       = index[7:0];
//    #CLKPERIOD;
//  end
//  for(index = 8'h10; index < 8'h12 ; index++ )
//  begin
//    perfMonRegAddr       = index[7:0];
//    #CLKPERIOD;
//  end
//  for(index = 8'h20; index < 8'h21 ; index++ )
//  begin
//    perfMonRegAddr       = index[7:0];
//    #CLKPERIOD;
//  end
//  for(index = 8'h30; index < 8'h32 ; index++ )
//  begin
//    perfMonRegAddr       = index[7:0];
//    #CLKPERIOD;
//  end
//  for(index = 8'h40; index < 8'h49 ; index++ )
//  begin
//    perfMonRegAddr       = index[7:0];
//    #CLKPERIOD;
//  end
//  for(index = 8'h50; index < 8'h55 ; index++ )
//  begin
//    perfMonRegAddr       = index[7:0];
//    #CLKPERIOD;
//  end
//endtask
//`endif

task print_heartbeat;


  if(resetDone & coreResetDone)
  begin
    if ((CYCLE_COUNT % STAT_PRINT_INTERVAL) == 0)
    begin
        ipc = $itor(COMMIT_COUNT)/$itor(CYCLE_COUNT);
        if (((COMMIT_COUNT - last_commit_cnt) == 0) & resetDone & coreResetDone)
        begin
            $display("Cycle Count:%d Commit Count:%d IPC:%2.2f BTB-Miss:%d BTB-Miss-Rtn:%d  Br-Count:%d Br-Mispredict:%d Violation: %0d",
                     CYCLE_COUNT,
                     COMMIT_COUNT,
                     ipc,
                     btb_miss,
                     btb_miss_rtn,
                     br_count,
                     br_mispredict_count,
                     load_violation_count);

            $display("ERROR: instruction committing has stalled (Cycle: %0d, Commit: %0d, PC: %x", CYCLE_COUNT, COMMIT_COUNT, commitPC[0] );
            // Dump performance counters
            `ifdef PERF_MON
              read_perf_mon();
            `endif  

            $finish;
        end

        $display("Cycle: %d Commit: %d IPC:%2.2f BTB-Miss: %0d  BTB-Miss-Rtn: %0d  Br-Count: %0d  Br-Mispredict: %0d Violation: %0d",
                 CYCLE_COUNT,
                 COMMIT_COUNT,
                 ipc,
                 btb_miss,
                 btb_miss_rtn,
                 br_count,
                 br_mispredict_count,
                 load_violation_count);

        
        `ifdef DUMP_STATS
            ib_avg    = ib_count/(CYCLE_COUNT-10.0);
            fl_avg    = fl_count/(CYCLE_COUNT-10.0);
            iq_avg    = iq_count/(CYCLE_COUNT-10.0);
            ldq_avg   = ldq_count/(CYCLE_COUNT-10.0);
            stq_avg   = stq_count/(CYCLE_COUNT-10.0);
            al_avg    = al_count/(CYCLE_COUNT-10.0);
    
            $fwrite(fd_stats, "%d, ", CYCLE_COUNT); 
            $fwrite(fd_stats, "%d, ", COMMIT_COUNT); 
    
            $fwrite(fd_stats, "%2.3f, ", ib_avg); 
            $fwrite(fd_stats, "%2.3f, ", fl_avg); 
            $fwrite(fd_stats, "%2.3f, ", iq_avg); 
            $fwrite(fd_stats, "%2.4f, ", ldq_avg); 
            $fwrite(fd_stats, "%2.4f, ", stq_avg); 
            $fwrite(fd_stats, "%2.3f, ", al_avg); 
    
            $fwrite(fd_stats, "%d, ", fetch1_stall); 
            $fwrite(fd_stats, "%d, ", ctiq_stall); 
            $fwrite(fd_stats, "%d, ", instBuf_stall); 
            $fwrite(fd_stats, "%d, ", freelist_stall); 
            $fwrite(fd_stats, "%d, ", backend_stall); 
            $fwrite(fd_stats, "%d, ", ldq_stall); 
            $fwrite(fd_stats, "%d, ", stq_stall); 
            $fwrite(fd_stats, "%d, ", iq_stall); 
            $fwrite(fd_stats, "%d, ", rob_stall); 
    
            $fwrite(fd_stats, "%d, ", btb_miss); 
            $fwrite(fd_stats, "%d, ", btb_miss_rtn); 
            $fwrite(fd_stats, "%d, ", br_count); 
            $fwrite(fd_stats, "%d, ", br_mispredict_count); 
            $fwrite(fd_stats, "%d, ", load_violation_count); 
    
            $fwrite(fd_stats, "%d, ", stat_num_corr);
            $fwrite(fd_stats, "%d, ", stat_num_pred);
            $fwrite(fd_stats, "%d, ", stat_num_cond_corr);
            $fwrite(fd_stats, "%d, ", stat_num_cond_pred);
            $fwrite(fd_stats, "%d, ", stat_num_return_corr);
            $fwrite(fd_stats, "%d, ", stat_num_return_pred);
    
            $fwrite(fd_stats, "%d, ", commit_1); 
            $fwrite(fd_stats, "%d, ", commit_2); 
            $fwrite(fd_stats, "%d, ", commit_3); 
            $fwrite(fd_stats, "%d\n", commit_4); 
        `endif

        last_commit_cnt = COMMIT_COUNT;
    end


    if(loggingOn)
    begin
      //if (((COMMIT_COUNT - prev_commit_point) >= IPC_PRINT_INTERVAL) & (CYCLE_COUNT > 0) & (COMMIT_COUNT != prev_commit_point))
      if (((COMMIT_COUNT - prev_commit_point) >= IPC_PRINT_INTERVAL) & (CYCLE_COUNT > 0))
      begin
          phase_mispredicts = br_mispredict_count - prev_br_misp_point; 
          phase_mispred = 100*$itor(phase_mispredicts)/$itor(br_count - prev_branch_point);
          phase_mpki    = $itor(phase_mispredicts)/$itor(IPC_PRINT_INTERVAL/1000);
          phase_ipc = $itor(IPC_PRINT_INTERVAL)/$itor(CYCLE_COUNT-last_cycle_cnt);

          $display("Cycle: %d Commit: %d PC: 0x%x Phase IPC:%2.2f Mispred:%2.2f MPKI:%2.2f",
                   CYCLE_COUNT,
                   COMMIT_COUNT,
                   commitPC[0],
                   phase_ipc,
                   phase_mispred,
                   phase_mpki);

          last_cycle_cnt      = CYCLE_COUNT;
          prev_commit_point   = prev_commit_point + IPC_PRINT_INTERVAL;
          prev_branch_point   = br_count;
          prev_br_misp_point  = br_mispredict_count;
      end
    end
  end //if reset Done
endtask    

exeFlgs                         ctrlExeFlags;
wbPkt                           wbPacket        [0:`ISSUE_WIDTH-1];
fuPkt                           exePacket       [0:`ISSUE_WIDTH-1];

/* Following maintains all the performance related counters. */
task update_stats;
  
   int i;

   exePacket[0]       = coreTop.exePipe0.execute.exePacket_i;
   wbPacket[0]        = coreTop.lsu.wbPacket_o;  // Writeback for MEM happens from LSU

  `ifdef ISSUE_TWO_WIDE
   exePacket[1]       = coreTop.exePipe1.execute.exePacket_i;
   wbPacket[1]        = coreTop.exePipe1.execute.wbPacket_o;
   `endif

  `ifdef ISSUE_THREE_WIDE
   exePacket[2]       = coreTop.exePipe2.execute.exePacket_i;
   wbPacket[2]        = coreTop.exePipe2.execute.wbPacket_o;
   `endif

  `ifdef ISSUE_FOUR_WIDE
   exePacket[3]       = coreTop.exePipe3.execute.exePacket_i;
   wbPacket[3]        = coreTop.exePipe3.execute.wbPacket_o;
  `endif
  
   ctrlExeFlags       = wbPacket[1].flags;
  
  
  if (resetDone & coreResetDone)
  begin
      CYCLE_COUNT       = CYCLE_COUNT    + 1;
      COMMIT_COUNT      = COMMIT_COUNT   + totalCommit;
      fetch1_stall      = fetch1_stall   + coreTop.fs1.stall_i;
      ctiq_stall        = ctiq_stall     + coreTop.fs2.ctiQueueFull_o;
      instBuf_stall     = instBuf_stall  + coreTop.instBuf.instBufferFull_o;
      freelist_stall    = freelist_stall + coreTop.rename.freeListEmpty_o;
      backend_stall     = backend_stall  + coreTop.dispatch.backEndFull_o;
    `ifdef PERF_MON
      ldq_stall         = ldq_stall      + coreTop.dispatch.loadStall_o;
      stq_stall         = stq_stall      + coreTop.dispatch.storeStall_o;
      iq_stall          = iq_stall       + coreTop.dispatch.iqStall_o;
      rob_stall         = rob_stall      + coreTop.dispatch.alStall_o;
    `endif
  
      btb_miss          = btb_miss       + (~coreTop.fs1.stall_i & coreTop.fs1.fs2RecoverFlag_i);
      btb_miss_rtn      = btb_miss_rtn   + (~coreTop.fs1.stall_i &
                                             coreTop.fs1.fs2MissedReturn_i &
                                             coreTop.fs1.fs2RecoverFlag_i);
      for (i = 0; i < `COMMIT_WIDTH; i++)
      begin
          br_count        = br_count       + ((totalCommit >= (i+1)) & ctrlAl[i][5]);
          ld_count        = ld_count       + coreTop.activeList.commitLoad_o[i];
      end
  
      br_mispredict_count =  br_mispredict_count + ctrlAl[i][0] && commitReady[i] & ~coreTop.activeList.stallStCommit_i;
  
      load_violation_count = load_violation_count + violateBit[0] && commitReady[i] & ~coreTop.activeList.stallStCommit_i;
  
    `ifdef PERF_MON
      ib_count  = ib_count  + coreTop.instBuf.instCount_o;
      fl_count  = fl_count  + coreTop.rename.specfreelist.freeListCnt_o;
    `endif
      iq_count  = iq_count  + coreTop.issueq.cntInstIssueQ_o;
      ldq_count = ldq_count + coreTop.lsu.ldqCount_o;
      stq_count = stq_count + coreTop.lsu.stqCount_o;
      al_count  = al_count  + coreTop.activeList.activeListCnt_o;
      
      commit_1  = commit_1  + ((totalCommit == 1) ? 1'h1: 1'h0);
      commit_2  = commit_2  + ((totalCommit == 2) ? 1'h1: 1'h0);
      commit_3  = commit_3  + ((totalCommit == 3) ? 1'h1: 1'h0);
      commit_4  = commit_4  + ((totalCommit == 4) ? 1'h1: 1'h0);


      // cti stats ////////////////////////////////
      if (exePacket[1].valid)
      begin
          stat_num_pred++;
          
          if (!ctrlExeFlags.mispredict)
              stat_num_corr++;
          else
              stat_num_recover++;
      
          if (exePacket[1].ctrlType == `COND_BRANCH)
          begin
              stat_num_cond_pred++;
      
              if (!ctrlExeFlags.mispredict)
                  stat_num_cond_corr++;
          end
          
          if (exePacket[1].ctrlType == `RETURN)
          begin
              stat_num_return_pred++;
      
              if (!ctrlExeFlags.mispredict)
                  stat_num_return_corr++;
          end
      end
    end

    if (COMMIT_COUNT >= SIM_STOP_COMMIT_COUNT)
      end_rtl_simulation();

endtask


