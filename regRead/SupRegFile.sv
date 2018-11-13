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


module SupRegFile (

	input                               clk,
	input                               reset,
  input                               flush_i,

  input        [`CSR_WIDTH_LOG-1:0]   regWrAddr_i,  
  input        [`CSR_WIDTH-1:0]       regWrData_i,
  input                               regWrEn_i,
  input                               commitReg_i,

  input        [`CSR_WIDTH_LOG-1:0]   regRdAddr_i,  
  input                               regRdEn_i,
  output logic [`CSR_WIDTH-1:0]       regRdData_o,

  input        [`COMMIT_WIDTH_LOG:0]  totalCommit_i,
  input                               exceptionFlag_i,
  input        [`SIZE_PC-1:0]         exceptionPC_i,
  input        [`EXCEPTION_CAUSE_LOG-1:0]  exceptionCause_i,
  input        [`SIZE_VIRT_ADDR-1:0]  stCommitAddr_i,
  input        [`SIZE_VIRT_ADDR-1:0]  ldCommitAddr_i,
  input                               sretFlag_i,

  output logic                        atomicRdVioFlag_o,
  output logic                        interruptPending_o,
  output       [`CSR_WIDTH-1:0]       csr_epc_o,
  output       [`CSR_WIDTH-1:0]       csr_evec_o
	);

//`define SR_S              64'h0000000000000001
//`define SR_PS             64'h0000000000000002
//`define SR_EI             64'h0000000000000004
//`define SR_PEI            64'h0000000000000008
//`define SR_EF             64'h0000000000000010
//`define SR_U64            64'h0000000000000020
//`define SR_S64            64'h0000000000000040
//`define SR_VM             64'h0000000000000080
//`define SR_EA             64'h0000000000000100
//`define SR_IM             64'h0000000000FF0000
//`define SR_IP             64'h00000000FF000000
//`define SR_IM_SHIFT       16
//`define SR_IP_SHIFT       24
//localparam SR_ZERO   =         ~(`SR_S|`SR_PS|`SR_EI|`SR_PEI|`SR_EF|`SR_U64|`SR_S64|`SR_VM|`SR_EA|`SR_IM|`SR_IP);

//`define IRQ_COP           2
//`define IRQ_IPI           5
//`define IRQ_HOST          6
//`define IRQ_TIMER         7
//
//`define IMPL_SPIKE        1
//`define IMPL_ROCKET       2

//// page table entry (PTE) fields
//`define PTE_V             64'h0000000000000001 // Entry is a page Table descriptor
//`define PTE_T             64'h0000000000000002 // Entry is a page Table, not a terminal node
//`define PTE_G             64'h0000000000000004 // Global
//`define PTE_UR            64'h0000000000000008 // User Write permission
//`define PTE_UW            64'h0000000000000010 // User Read permission
//`define PTE_UX            64'h0000000000000020 // User eXecute permission
//`define PTE_SR            64'h0000000000000040 // Supervisor Read permission
//`define PTE_SW            64'h0000000000000080 // Supervisor Write permission
//`define PTE_SX            64'h0000000000000100 // Supervisor eXecute permission
//`define PTE_PERM          (`PTE_SR | `PTE_SW | `PTE_SX | `PTE_UR | `PTE_UW | `PTE_UX)
//
//`define RISCV_PGLEVELS      3
//`define RISCV_PGSHIFT       13
//`define RISCV_PGLEVEL_BITS  10
//`define RISCV_PGSIZE        (1 << `RISCV_PGSHIFT)
//
//
//localparam [`CSR_WIDTH-1:0] CSR_STATUS_MASK  = (64'h00000000ffffffff & ~`SR_EA & ~`SR_ZERO);
//`define CSR_FFLAGS_MASK   64'h00000000ffffffff
//`define CSR_FRM_MASK      64'h00000000ffffffff
//`define CSR_COMPARE_MASK  64'h00000000ffffffff



logic rv64;
logic [`CSR_WIDTH-1:0]  csr_fflags; 
logic [`CSR_WIDTH-1:0]  csr_frm; 
logic [`CSR_WIDTH-1:0]  csr_fcsr;
logic [`CSR_WIDTH-1:0]  csr_stats;
logic [`CSR_WIDTH-1:0]  csr_sup0; 
logic [`CSR_WIDTH-1:0]  csr_sup1; 
logic [`CSR_WIDTH-1:0]  csr_epc; 
logic [`CSR_WIDTH-1:0]  csr_badvaddr; 
logic [`CSR_WIDTH-1:0]  csr_ptbr; 
logic [`CSR_WIDTH-1:0]  csr_asid; 
logic [`CSR_WIDTH-1:0]  csr_count;
logic [`CSR_WIDTH-1:0]  csr_compare;
logic [`CSR_WIDTH-1:0]  csr_evec; 
logic [`CSR_WIDTH-1:0]  csr_cause;
logic [`CSR_WIDTH-1:0]  csr_status; 
logic [`CSR_WIDTH-1:0]  csr_hartid; 
logic [`CSR_WIDTH-1:0]  csr_impl; 
logic [`CSR_WIDTH-1:0]  csr_fatc; 
logic [`CSR_WIDTH-1:0]  csr_send_ipi; 
logic [`CSR_WIDTH-1:0]  csr_clear_ipi;
logic [`CSR_WIDTH-1:0]  csr_reset; 
logic [`CSR_WIDTH-1:0]  csr_tohost;
logic [`CSR_WIDTH-1:0]  csr_fromhost; 
logic [`CSR_WIDTH-1:0]  csr_cycle;
logic [`CSR_WIDTH-1:0]  csr_time; 
logic [`CSR_WIDTH-1:0]  csr_instret;
logic [`CSR_WIDTH-1:0]  csr_cycleh;
logic [`CSR_WIDTH-1:0]  csr_timeh; 
logic [`CSR_WIDTH-1:0]  csr_instreth;

logic                        wr_csr_fflags    ;
logic                        wr_csr_frm       ;
logic                        wr_csr_fcsr      ;
logic                        wr_csr_stats     ;
logic                        wr_csr_sup0      ;
logic                        wr_csr_sup1      ;
logic                        wr_csr_epc       ;
logic                        wr_csr_badvaddr  ;
logic                        wr_csr_ptbr      ;
logic                        wr_csr_asid      ;
logic                        wr_csr_count     ;
logic                        wr_csr_compare   ;
logic                        wr_csr_evec      ;
logic                        wr_csr_cause     ;
logic                        wr_csr_status    ;
logic                        wr_csr_hartid    ;
logic                        wr_csr_impl      ;
logic                        wr_csr_fatc      ;
logic                        wr_csr_send_ipi  ;
logic                        wr_csr_clear_ipi ;
logic                        wr_csr_reset     ;
logic                        wr_csr_tohost    ;
logic                        wr_csr_fromhost  ;
logic                        wr_csr_cycle     ;
logic                        wr_csr_time      ;
logic                        wr_csr_instret   ;
logic                        wr_csr_cycleh    ;
logic                        wr_csr_timeh     ;
logic                        wr_csr_instreth  ;

logic [`CSR_WIDTH-1:0]  csr_epc_next; 
logic [`CSR_WIDTH-1:0]  csr_badvaddr_next; 
logic [`CSR_WIDTH-1:0]  csr_count_next; 
logic [`CSR_WIDTH-1:0]  csr_cause_next; 
logic [`CSR_WIDTH-1:0]  csr_status_next; 
logic [`CSR_WIDTH-1:0]  irq_vector_next; 
logic [`CSR_WIDTH-1:0]  set_irq_vector; 
logic [`CSR_WIDTH-1:0]  clear_irq_vector; 

logic                        regRdChkptValid;
logic [`CSR_WIDTH_LOG-1:0]    regRdAddrChkpt;  
logic [`CSR_WIDTH-1:0]  regRdDataChkpt;
logic [`CSR_WIDTH_LOG-1:0]    regWrAddrCommit;  
logic [`CSR_WIDTH-1:0]  regWrDataCommit;
logic                        atomicRdVioFlag;
logic [7:0]                  interrupts;

assign rv64 = (csr_status & `SR_S) ? (csr_status & `SR_S64) : (csr_status & `SR_U64);
assign interrupts = ((csr_status & `SR_IP) >> `SR_IP_SHIFT) & (csr_status >> `SR_IM_SHIFT);
assign interruptPending_o = (|interrupts) & (|(csr_status & `SR_EI)); //If interrupt enabled and interrupts pending

assign csr_evec_o = csr_evec;
assign csr_epc_o  = csr_epc;

// Checkpoint the CSR address and Data read
// by a CSR instruction to verify the atomic
// execution of the CSR instruction. The logic
// continuously checks for a difference in the
// value read by CSR instruction and the current
// value of the CSR. If it finds a difference, it 
// asserts a signal to indicate non-atomic read.
// This signal is used by the retire logic to raise
// an exception and reexecute the CSR if atomicity has
// been violated.
always_ff @(posedge clk or posedge reset)
begin
  if(reset)
  begin
    regRdChkptValid   <=  1'b0;
  end
  else if(regRdEn_i)
  begin
    regRdAddrChkpt <=  regRdAddr_i;
    regRdDataChkpt <=  regRdData_o;
    regRdChkptValid   <=  1'b1;
  end
  else if(flush_i | commitReg_i)
  begin
    regRdChkptValid   <=  1'b0;
  end
end


// Hold the CSR writes in a temporary register until the
// CSR write instruction commits. The architecture guarantees
// that only on CSR will be dispatched to the backend at any 
// given time making renaming of CSR registers unnecessary. Even
// with this guarantee, CSR writes still remain a problem since
// branch mispredicts or other exceptions might squash the CSR
// instruction after it has completed and waiting in the ActiveList
// to be committed. Hence, the effect of the CSR write can not be
// made permanent until it commits. This way, we can provide and
// illusion of atomic execution of the CSR instruction. No instruction
// prior to the CSR instruction commit will see the effect of the CSR
// instruction and all instructions after the CSR instruction commit will
// see the effect immediately. Note that the instructions after
// the CSR instruction will not be dispatched until the CSR instruction
// has committed.
always_ff @(posedge clk)
begin
  if(regWrEn_i)
  begin
    regWrAddrCommit <=  regWrAddr_i;
    regWrDataCommit <=  regWrData_i;
  end
end

logic [`CSR_WIDTH-1:0] status_val;

// Register Write operation
always_comb
begin
  wr_csr_fflags    =  1'b0;
  wr_csr_frm       =  1'b0;
  wr_csr_fcsr      =  1'b0;
  wr_csr_stats     =  1'b0;
  wr_csr_sup0      =  1'b0;
  wr_csr_sup1      =  1'b0;
  wr_csr_epc       =  1'b0;
  wr_csr_badvaddr  =  1'b0;
  wr_csr_ptbr      =  1'b0;
  wr_csr_asid      =  1'b0;
  wr_csr_count     =  1'b0;
  wr_csr_compare   =  1'b0;
  wr_csr_evec      =  1'b0;
  wr_csr_cause     =  1'b0;
  wr_csr_status    =  1'b0;
  wr_csr_hartid    =  1'b0;
  wr_csr_impl      =  1'b0;
  wr_csr_fatc      =  1'b0;
  wr_csr_send_ipi  =  1'b0;
  wr_csr_clear_ipi =  1'b0;
  wr_csr_reset     =  1'b0;
  wr_csr_tohost    =  1'b0;
  wr_csr_fromhost  =  1'b0;
  wr_csr_cycle     =  1'b0;
  wr_csr_time      =  1'b0;
  wr_csr_instret   =  1'b0;
  wr_csr_cycleh    =  1'b0;
  wr_csr_timeh     =  1'b0;
  wr_csr_instreth  =  1'b0;
  clear_irq_vector =  64'b0;

  // Write the register when the CSR instruction commits
  if(commitReg_i)
  begin
    case(regWrAddrCommit)
      12'h001:wr_csr_fflags    = 1'b1; 
      12'h002:wr_csr_frm       = 1'b1; 
      12'h003:wr_csr_fcsr      = 1'b1; 
      12'h0c0:wr_csr_stats     = 1'b1; 
      12'h500:wr_csr_sup0      = 1'b1; 
      12'h501:wr_csr_sup1      = 1'b1; 
      12'h502:wr_csr_epc       = 1'b1; 
      12'h503:wr_csr_badvaddr  = 1'b1; 
      12'h504:wr_csr_ptbr      = 1'b1; 
      12'h505:wr_csr_asid      = 1'b1; 
      12'h506:wr_csr_count     = 1'b1; 
      12'h507:wr_csr_compare   = 1'b1; 
      12'h508:wr_csr_evec      = 1'b1; 
      12'h509:wr_csr_cause     = 1'b1; 
      12'h50a:wr_csr_status    = 1'b1; 
      12'h50b:wr_csr_hartid    = 1'b1; 
      12'h50c:wr_csr_impl      = 1'b1; 
      12'h50d:wr_csr_fatc      = 1'b1; 
      12'h50e:wr_csr_send_ipi  = 1'b1; 
      12'h50f:wr_csr_clear_ipi = 1'b1; 
      12'h51d:wr_csr_reset     = 1'b1; 
      12'h51e:wr_csr_tohost    = 1'b1; 
      12'h51f:begin
        wr_csr_fromhost    = 1'b1; 
        clear_irq_vector[`IRQ_HOST+`SR_IP_SHIFT]   = 1'b1;
      end
      12'hc00:wr_csr_cycle     = 1'b1; 
      12'hc01:wr_csr_time      = 1'b1; 
      12'hc02:wr_csr_instret   = 1'b1; 
      12'hc80:wr_csr_cycleh    = 1'b1; 
      12'hc81:wr_csr_timeh     = 1'b1; 
      12'hc82:wr_csr_instreth  = 1'b1; 
    endcase
  end
end

// Register Write operation
always_ff @(posedge clk or posedge reset)
begin
  if(reset)
  begin
    csr_fflags    <=  `CSR_WIDTH'b0;
    csr_frm       <=  `CSR_WIDTH'b0;
    csr_fcsr      <=  `CSR_WIDTH'b0;
    csr_stats     <=  `CSR_WIDTH'b0;
    csr_sup0      <=  `CSR_WIDTH'b0;
    csr_sup1      <=  `CSR_WIDTH'b0;
    csr_epc       <=  `CSR_WIDTH'b0;
    csr_badvaddr  <=  `CSR_WIDTH'b0;
    csr_ptbr      <=  `CSR_WIDTH'b0;
    csr_asid      <=  `CSR_WIDTH'b0;
    csr_count     <=  `CSR_WIDTH'b0;
    csr_compare   <=  `CSR_WIDTH'b0;
    csr_evec      <=  `CSR_WIDTH'b0;
    csr_cause     <=  `CSR_WIDTH'b0;
    csr_status    <=  (`SR_S | `SR_S64 | `SR_U64);
    csr_hartid    <=  `CSR_WIDTH'b0;
    csr_impl      <=  `CSR_WIDTH'b0;
    csr_fatc      <=  `CSR_WIDTH'b0;
    csr_send_ipi  <=  `CSR_WIDTH'b0;
    csr_clear_ipi <=  `CSR_WIDTH'b0;
    csr_reset     <=  `CSR_WIDTH'b0;
    csr_tohost    <=  `CSR_WIDTH'b0;
    csr_fromhost  <=  `CSR_WIDTH'b0;
    csr_cycle     <=  `CSR_WIDTH'b0;
    csr_time      <=  `CSR_WIDTH'b0;
    csr_instret   <=  `CSR_WIDTH'b0;
    csr_cycleh    <=  `CSR_WIDTH'b0;
    csr_timeh     <=  `CSR_WIDTH'b0;
    csr_instreth  <=  `CSR_WIDTH'b0;
  end
  // Write the register when the CSR instruction commits
  else
  begin
    csr_fflags    <=  wr_csr_fflags    ? regWrDataCommit & `CSR_FFLAGS_MASK : csr_fflags;
    csr_frm       <=  wr_csr_frm       ? regWrDataCommit & `CSR_FRM_MASK : csr_frm;
    csr_fcsr      <=  wr_csr_fcsr      ? regWrDataCommit : csr_fcsr;
    csr_stats     <=  wr_csr_stats     ? regWrDataCommit : csr_stats; 
    csr_sup0      <=  wr_csr_sup0      ? regWrDataCommit : csr_sup0; 
    csr_sup1      <=  wr_csr_sup1      ? regWrDataCommit : csr_sup1; 
    csr_epc       <=  wr_csr_epc       ? regWrDataCommit : csr_epc_next; 
    csr_badvaddr  <=  wr_csr_badvaddr  ? regWrDataCommit : csr_badvaddr_next;
    csr_ptbr      <=  wr_csr_ptbr      ? regWrDataCommit : csr_ptbr; 
    csr_asid      <=  wr_csr_asid      ? regWrDataCommit : csr_asid;
    csr_count     <=  wr_csr_count     ? regWrDataCommit : csr_count_next;
    csr_compare   <=  wr_csr_compare   ? regWrDataCommit & `CSR_COMPARE_MASK : csr_compare; 
    csr_evec      <=  wr_csr_evec      ? regWrDataCommit : csr_evec; 
    csr_cause     <=  wr_csr_cause     ? regWrDataCommit : csr_cause_next;  
    csr_status    <=  wr_csr_status    ? ((regWrDataCommit & ~`SR_IP) | (csr_status & `SR_IP)) & `CSR_STATUS_MASK : csr_status_next;
    csr_hartid    <=  wr_csr_hartid    ? regWrDataCommit : csr_hartid;   
    csr_impl      <=  wr_csr_impl      ? regWrDataCommit : csr_impl;   
    csr_fatc      <=  wr_csr_fatc      ? regWrDataCommit : csr_fatc;   
    csr_send_ipi  <=  wr_csr_send_ipi  ? regWrDataCommit : csr_send_ipi;   
    csr_clear_ipi <=  wr_csr_clear_ipi ? regWrDataCommit : csr_clear_ipi;
    csr_reset     <=  wr_csr_reset     ? regWrDataCommit : csr_reset;
    csr_tohost    <=  wr_csr_tohost    ? regWrDataCommit : csr_tohost;
    csr_fromhost  <=  wr_csr_fromhost  ? regWrDataCommit : csr_fromhost;
    csr_cycle     <=  wr_csr_cycle     ? regWrDataCommit : csr_count_next; //csr_cycle;
    csr_time      <=  wr_csr_time      ? regWrDataCommit : csr_count_next; //csr_time;
    csr_instret   <=  wr_csr_instret   ? regWrDataCommit : csr_count_next; //csr_instret;
    csr_cycleh    <=  wr_csr_cycleh    ? regWrDataCommit : csr_cycleh;
    csr_timeh     <=  wr_csr_timeh     ? regWrDataCommit : csr_timeh;
    csr_instreth  <=  wr_csr_instreth  ? regWrDataCommit : csr_instreth;
  end
end

assign set_irq_vector  = 0;

assign csr_epc_next       = exceptionFlag_i ? exceptionPC_i    : csr_epc;
assign csr_count_next     = csr_count + totalCommit_i + exceptionFlag_i;
assign csr_cause_next     = exceptionFlag_i ? exceptionCause_i : csr_cause;

always_comb
begin
  if(sretFlag_i)
  begin
    csr_status_next    = (csr_status & ~(`SR_S | `SR_EI)) | 
                         ((csr_status & `SR_PS) ? `SR_S : 64'b0) |
                         ((csr_status & `SR_PEI) ? `SR_EI : 64'b0);
  end
  else
  begin
    irq_vector_next    = set_irq_vector | (~clear_irq_vector & csr_status & `SR_IP);
    csr_status_next    = (csr_status & ~`SR_IP) | irq_vector_next;
  end
end

always_comb
begin
  csr_badvaddr_next = csr_badvaddr;
  if(exceptionFlag_i)
  begin
    case(exceptionCause_i)
      `CAUSE_MISALIGNED_FETCH: csr_badvaddr_next = exceptionPC_i;
      `CAUSE_FAULT_FETCH     : csr_badvaddr_next = exceptionPC_i;
      `CAUSE_MISALIGNED_LOAD : csr_badvaddr_next = ldCommitAddr_i;
      `CAUSE_MISALIGNED_STORE: csr_badvaddr_next = stCommitAddr_i;
      `CAUSE_FAULT_LOAD      : csr_badvaddr_next = ldCommitAddr_i;
      `CAUSE_FAULT_STORE     : csr_badvaddr_next = stCommitAddr_i;
      default                : csr_badvaddr_next = csr_badvaddr; 
    endcase
  end
end

// Register Read operation
always_comb
begin
  case(regRdAddr_i)
    12'h001:regRdData_o   =  csr_fflags    ;
    12'h002:regRdData_o   =  csr_frm       ;
    12'h003:regRdData_o   =  csr_fcsr      ;
    12'h0c0:regRdData_o   =  csr_stats     ; 
    12'h500:regRdData_o   =  csr_sup0      ; 
    12'h501:regRdData_o   =  csr_sup1      ; 
    12'h502:regRdData_o   =  csr_epc       ; 
    12'h503:regRdData_o   =  csr_badvaddr  ; 
    12'h504:regRdData_o   =  csr_ptbr      ; 
    12'h505:regRdData_o   =  csr_asid      ; 
    12'h506:regRdData_o   =  csr_count     ; 
    12'h507:regRdData_o   =  csr_compare   ; 
    12'h508:regRdData_o   =  csr_evec      ; 
    12'h509:regRdData_o   =  csr_cause     ;  
    12'h50a:regRdData_o   =  csr_status    ;   
    12'h50b:regRdData_o   =  csr_hartid    ;   
    12'h50c:regRdData_o   =  csr_impl      ;   
    12'h50d:regRdData_o   =  csr_fatc      ;   
    12'h50e:regRdData_o   =  csr_send_ipi  ;   
    12'h50f:regRdData_o   =  csr_clear_ipi ;
    12'h51d:regRdData_o   =  csr_reset     ;
    12'h51e:regRdData_o   =  csr_tohost    ;
    12'h51f:regRdData_o   =  csr_fromhost  ;
    12'hc00:regRdData_o   =  csr_cycle     ;
    12'hc01:regRdData_o   =  csr_time      ;
    12'hc02:regRdData_o   =  csr_instret   ;
    12'hc80:regRdData_o   =  csr_cycleh    ;
    12'hc81:regRdData_o   =  csr_timeh     ;
    12'hc82:regRdData_o   =  csr_instreth  ;
    default:regRdData_o   =  `CSR_WIDTH'bx;
  endcase  
end

// Atomicity Violation Check
always_comb
begin
  case(regRdAddrChkpt)
    12'h001:atomicRdVioFlag = (regRdDataChkpt   !=  csr_fflags    );
    12'h002:atomicRdVioFlag = (regRdDataChkpt   !=  csr_frm       );
    12'h003:atomicRdVioFlag = (regRdDataChkpt   !=  csr_fcsr      );
    12'h0c0:atomicRdVioFlag = (regRdDataChkpt   !=  csr_stats     ); 
    12'h500:atomicRdVioFlag = (regRdDataChkpt   !=  csr_sup0      ); 
    12'h501:atomicRdVioFlag = (regRdDataChkpt   !=  csr_sup1      ); 
    12'h502:atomicRdVioFlag = (regRdDataChkpt   !=  csr_epc       ); 
    12'h503:atomicRdVioFlag = (regRdDataChkpt   !=  csr_badvaddr  ); 
    12'h504:atomicRdVioFlag = (regRdDataChkpt   !=  csr_ptbr      ); 
    12'h505:atomicRdVioFlag = (regRdDataChkpt   !=  csr_asid      ); 
    12'h506:atomicRdVioFlag = (regRdDataChkpt   !=  csr_count     ); 
    12'h507:atomicRdVioFlag = (regRdDataChkpt   !=  csr_compare   ); 
    12'h508:atomicRdVioFlag = (regRdDataChkpt   !=  csr_evec      ); 
    12'h509:atomicRdVioFlag = (regRdDataChkpt   !=  csr_cause     );  
    12'h50a:atomicRdVioFlag = (regRdDataChkpt   !=  csr_status    );   
    12'h50b:atomicRdVioFlag = (regRdDataChkpt   !=  csr_hartid    );   
    12'h50c:atomicRdVioFlag = (regRdDataChkpt   !=  csr_impl      );   
    12'h50d:atomicRdVioFlag = (regRdDataChkpt   !=  csr_fatc      );   
    12'h50e:atomicRdVioFlag = (regRdDataChkpt   !=  csr_send_ipi  );   
    12'h50f:atomicRdVioFlag = (regRdDataChkpt   !=  csr_clear_ipi );
    12'h51d:atomicRdVioFlag = (regRdDataChkpt   !=  csr_reset     );
    12'h51e:atomicRdVioFlag = (regRdDataChkpt   !=  csr_tohost    );
    12'h51f:atomicRdVioFlag = (regRdDataChkpt   !=  csr_fromhost  );
    12'hc00:atomicRdVioFlag = (regRdDataChkpt   !=  csr_cycle     );
    12'hc01:atomicRdVioFlag = (regRdDataChkpt   !=  csr_time      );
    12'hc02:atomicRdVioFlag = (regRdDataChkpt   !=  csr_instret   );
    12'hc80:atomicRdVioFlag = (regRdDataChkpt   !=  csr_cycleh    );
    12'hc81:atomicRdVioFlag = (regRdDataChkpt   !=  csr_timeh     );
    12'hc82:atomicRdVioFlag = (regRdDataChkpt   !=  csr_instreth  );
    default:atomicRdVioFlag = 1'b0;
  endcase  
end

assign atomicRdVioFlag_o = atomicRdVioFlag & regRdChkptValid;

endmodule

