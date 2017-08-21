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

module PerfMon(

    input			     clk,
    input                            reset,

    input  [`REG_DATA_WIDTH-1:0]     perfMonRegAddr_i,
    output reg [31:0]                perfMonRegData_o,
    input                            perfMonRegRun_i,
    input                            perfMonRegClr_i,
    input                            perfMonRegGlobalClr_i,  
    input                            instMiss_i      ,
    input                            loadMiss_i      ,
    input                            storeMiss_i     ,
    input                            l2InstFetchReq_i,
    input                            l2DataFetchReq_i,
    input  [`COMMIT_WIDTH-1:0]       commitStore_i,
    input  [`COMMIT_WIDTH-1:0]       commitLoad_i,    
    input                            recoverFlag_i,
    input                            loadViolation_i,
    input  [`COMMIT_WIDTH-1:0]       totalCommit_i, 
    input  [`INST_QUEUE_LOG:0]       ibCount_i, 
    input  [`SIZE_FREE_LIST_LOG-1:0] flCount_i, 
    input  [`SIZE_ISSUEQ_LOG:0]      iqCount_i, 
    input  [`SIZE_LSQ_LOG:0]         ldqCount_i, 
    input  [`SIZE_LSQ_LOG:0]         stqCount_i, 
    input  [`SIZE_ACTIVELIST_LOG:0]  alCount_i ,
    input                            fetch1_stall_i  ,   
    input                            ctiq_stall_i    ,     
    input                            instBuf_stall_i ,  
    input                            freelist_stall_i, 
    input                            backend_stall_i ,  
    input                            ldq_stall_i     ,      
    input                            stq_stall_i     ,      
    input                            iq_stall_i      ,       
    input                            rob_stall_i     ,
    input  [`FETCH_WIDTH-1:0]        fs1Fs2Valid_i   , 
    input  [`FETCH_WIDTH-1:0]        fs2DecValid_i   ,
    input  [`DISPATCH_WIDTH-1:0]     renDisValid_i   , 
    input  [`DISPATCH_WIDTH-1:0]     instBufRenValid_i,
    input  [`DISPATCH_WIDTH-1:0]     disIqValid_i,
    input  [`ISSUE_WIDTH-1:0]        iqRegReadValid_i,
    input  [`SIZE_LSQ_LOG:0]         iqReqCount_i    ,
    input  [`SIZE_LSQ_LOG:0]         iqIssuedCount_i  
    );

reg [31:0]              totalCycles;

reg [`COMMIT_WIDTH-1:0] next_events_commitStore;
reg [31:0]              events_commitStore;

reg [`COMMIT_WIDTH-1:0] next_events_commitLoad;
reg [31:0]              events_commitLoad;

reg [31:0]              events_totalCommit;
reg [31:0]              events_recoverFlag;
reg [31:0]              events_loadViolation;

reg [31:0]              events_fetch1_stall;
reg [31:0]              events_ctiq_stall;
reg [31:0]              events_instBuf_stall;
reg [31:0]              events_freelist_stall;
reg [31:0]              events_backend_stall;
reg [31:0]              events_ldq_stall;
reg [31:0]              events_stq_stall;
reg [31:0]              events_iq_stall;
reg [31:0]              events_rob_stall;
reg [31:0]              events_instMiss;
reg [31:0]              events_loadMiss;
reg [31:0]              events_storeMiss;
reg [31:0]              events_l2InstFetchReq;
reg [31:0]              events_l2DataFetchReq;
reg [31:0]              events_iqWaitingInst;
reg [31:0]              events_fs1fs2Valid;
reg [31:0]              events_fs2DecValid;
reg [31:0]              events_renDisValid;
reg [31:0]              events_instBufRenValid;
reg [31:0]              events_disIqValid;
reg [31:0]              events_iqRegReadValid;

reg [7:0]               occupancy_commitCount;
reg [7:0]               occupancy_ibCount;
reg [7:0]               occupancy_flCount;
reg [7:0]               occupancy_iqCount;
reg [7:0]               occupancy_ldqCount;
reg [7:0]               occupancy_stqCount;
reg [8:0]               program_status_word;

reg [`FETCH_WIDTH-1:0]     next_events_fs1fs2Valid;
reg [`FETCH_WIDTH-1:0]     next_events_fs2DecValid;
reg [`DISPATCH_WIDTH-1:0]  next_events_renDisValid;
reg [`DISPATCH_WIDTH-1:0]  next_events_instBufRenValid;
reg [`ISSUE_WIDTH-1:0]     next_events_disIqValid;
reg [`ISSUE_WIDTH-1:0]     next_events_iqRegReadValid;

reg [31:0]              perfMonRegData_reg ;
//integer index;

wire [31:0]             totalCyclesPostClr           ;              
wire [31:0]             events_commitStorePostClr    ;
wire [31:0]             events_commitLoadPostClr     ;
wire [31:0]             events_recoverFlagPostClr    ;
wire [31:0]             events_loadViolationPostClr  ;
wire [31:0]             events_totalCommitPostClr    ;
wire [31:0]             events_fetch1_stallPostClr   ; 
wire [31:0]             events_ctiq_stallPostClr     ;
wire [31:0]             events_freelist_stallPostClr ;
wire [31:0]             events_backend_stallPostClr  ;
wire [31:0]             events_ldq_stallPostClr      ;
wire [31:0]             events_stq_stallPostClr      ;
wire [31:0]             events_iq_stallPostClr       ;
wire [31:0]             events_rob_stallPostClr      ;
wire [31:0]             events_instBuf_stallPostClr      ;
wire [31:0]             events_instMiss_PostClr ;
wire [31:0]             events_loadMiss_PostClr ;
wire [31:0]             events_storeMiss_PostClr;
wire [31:0]             events_l2InstFetchReq_PostClr;
wire [31:0]             events_l2DataFetchReq_PostClr;
wire [31:0]             events_iqWaitingInst_PostClr;
wire [31:0]             events_fs1fs2Valid_PostClr;
wire [31:0]             events_fs2DecValid_PostClr;
wire [31:0]             events_renDisValid_PostClr;
wire [31:0]             events_instBufRenValid_PostClr;
wire [31:0]             events_disIqValid_PostClr;
wire [31:0]             events_iqRegReadValid_PostClr;

//////////////////////////////////////////////////////////
// Register Space                                       //
// All registers are addressed from parallel interface  //
//////////////////////////////////////////////////////////
always @ (posedge clk)
begin
 if(reset)
 perfMonRegData_reg <= 32'b0;
 else 
 begin
  case(perfMonRegAddr_i)
    8'h00: perfMonRegData_reg <= totalCycles;
       
    8'h01: perfMonRegData_reg <= events_commitStore;
    8'h02: perfMonRegData_reg <= events_commitLoad;
    8'h03: perfMonRegData_reg <= events_recoverFlag;
    8'h04: perfMonRegData_reg <= events_loadViolation;
    8'h05: perfMonRegData_reg <= events_totalCommit;

    8'h10: perfMonRegData_reg <= {occupancy_ibCount,occupancy_flCount,occupancy_iqCount,occupancy_ldqCount}   ;
    8'h11: perfMonRegData_reg <= {16'b0,occupancy_stqCount,occupancy_commitCount}   ;

    8'h20: perfMonRegData_reg <= {23'b0,program_status_word} ;

    8'h30: perfMonRegData_reg <= events_fs1fs2Valid;
    8'h31: perfMonRegData_reg <= events_fs2DecValid;
    8'h32: perfMonRegData_reg <= events_renDisValid;
    8'h33: perfMonRegData_reg <= events_instBufRenValid;
    8'h34: perfMonRegData_reg <= events_disIqValid ;
    8'h35: perfMonRegData_reg <= events_iqRegReadValid;

    8'h40: perfMonRegData_reg <=  events_fetch1_stall;
    8'h41: perfMonRegData_reg <=  events_ctiq_stall;
    8'h42: perfMonRegData_reg <=  events_instBuf_stall;
    8'h43: perfMonRegData_reg <=  events_freelist_stall;
    8'h44: perfMonRegData_reg <=  events_backend_stall;
    8'h45: perfMonRegData_reg <=  events_ldq_stall;
    8'h46: perfMonRegData_reg <=  events_stq_stall;
    8'h47: perfMonRegData_reg <=  events_iq_stall;
    8'h48: perfMonRegData_reg <=  events_rob_stall;

    8'h50: perfMonRegData_reg <= events_instMiss;
    8'h51: perfMonRegData_reg <= events_loadMiss;
    8'h52: perfMonRegData_reg <= events_storeMiss;
    8'h53: perfMonRegData_reg <= events_l2InstFetchReq;
    8'h54: perfMonRegData_reg <= events_l2DataFetchReq;
    8'h55: perfMonRegData_reg <= events_iqWaitingInst;
    default:perfMonRegData_reg <= 8'h55;
  endcase
 end
end

assign perfMonRegData_o = perfMonRegData_reg; 

always @(posedge clk )
begin
  if(reset)
  begin
    totalCycles             <= 32'h0;
    events_commitStore      <= 32'h0;
    events_commitLoad       <= 32'h0;
    events_recoverFlag      <= 32'h0;
    events_loadViolation    <= 32'h0;
    events_totalCommit      <= 32'h0;
    events_fetch1_stall     <= 32'h0;
    events_ctiq_stall       <= 32'h0;
    events_instBuf_stall    <= 32'h0;
    events_freelist_stall   <= 32'h0;
    events_backend_stall    <= 32'h0;
    events_ldq_stall        <= 32'h0;
    events_stq_stall        <= 32'h0;
    events_iq_stall         <= 32'h0;
    events_rob_stall        <= 32'h0;
    events_instMiss         <= 32'h0;
    events_loadMiss         <= 32'h0;
    events_storeMiss        <= 32'h0;
    events_l2InstFetchReq   <= 32'h0; 
    events_l2DataFetchReq   <= 32'h0; 
    events_iqWaitingInst    <= 32'h0; 
    occupancy_commitCount   <= 8'h0;
    occupancy_ibCount       <= 8'h0;
    occupancy_flCount       <= 8'h0;  
    occupancy_iqCount       <= 8'h0;
    occupancy_ldqCount      <= 8'h0;
    occupancy_stqCount      <= 8'h0;
    program_status_word     <= 9'h0; // making it 16 bit, only LSB 9 are used currently.
    events_fs1fs2Valid      <= 32'h0; 
    events_fs2DecValid      <= 32'h0; 
    events_renDisValid      <= 32'h0; 
    events_instBufRenValid  <= 32'h0; 
    events_disIqValid       <= 32'h0; 
    events_iqRegReadValid   <= 32'h0; 
  end
  else if (perfMonRegGlobalClr_i)           //Global clear has priority over run
  begin
    totalCycles             <= 32'h0;
    events_commitStore      <= 32'h0;
    events_commitLoad       <= 32'h0;
    events_recoverFlag      <= 32'h0;
    events_loadViolation    <= 32'h0;
    events_totalCommit      <= 32'h0;
    events_fetch1_stall     <= 32'h0;
    events_ctiq_stall       <= 32'h0;
    events_instBuf_stall    <= 32'h0;
    events_freelist_stall   <= 32'h0;
    events_backend_stall    <= 32'h0;
    events_ldq_stall        <= 32'h0;
    events_stq_stall        <= 32'h0;
    events_iq_stall         <= 32'h0;
    events_rob_stall        <= 32'h0;
    events_instMiss         <= 32'h0;
    events_loadMiss         <= 32'h0;
    events_storeMiss        <= 32'h0;
    events_l2InstFetchReq   <= 32'h0; 
    events_l2DataFetchReq   <= 32'h0; 
    events_iqWaitingInst    <= 32'h0; 
    occupancy_commitCount   <= 8'h0;
    occupancy_ibCount       <= 8'h0;
    occupancy_flCount       <= 8'h0;  
    occupancy_iqCount       <= 8'h0;
    occupancy_ldqCount      <= 8'h0;
    occupancy_stqCount      <= 8'h0;
    program_status_word     <= 9'h0; // making it 16 bit, only LSB 9 are used currently.
    events_fs1fs2Valid      <= 32'h0; 
    events_fs2DecValid      <= 32'h0; 
    events_renDisValid      <= 32'h0; 
    events_instBufRenValid  <= 32'h0; 
    events_disIqValid       <= 32'h0; 
    events_iqRegReadValid   <= 32'h0; 
  end
  else if(perfMonRegRun_i)
  begin
    totalCycles             <= totalCyclesPostClr          ; 
    events_commitStore      <= events_commitStorePostClr   ;
    events_commitLoad       <= events_commitLoadPostClr    ;
    events_recoverFlag      <= events_recoverFlagPostClr   ;
    events_loadViolation    <= events_loadViolationPostClr   ;
    events_totalCommit      <= events_totalCommitPostClr   ;
    events_fetch1_stall     <= events_fetch1_stallPostClr  ;
    events_ctiq_stall       <= events_ctiq_stallPostClr    ;
    events_instBuf_stall    <= events_instBuf_stallPostClr ;
    events_freelist_stall   <= events_freelist_stallPostClr;
    events_backend_stall    <= events_backend_stallPostClr ;
    events_ldq_stall        <= events_ldq_stallPostClr     ;
    events_stq_stall        <= events_stq_stallPostClr     ;
    events_iq_stall         <= events_iq_stallPostClr      ;
    events_rob_stall        <= events_rob_stallPostClr     ;
    events_instMiss         <= events_instMiss_PostClr     ;
    events_loadMiss         <= events_loadMiss_PostClr     ;
    events_storeMiss        <= events_storeMiss_PostClr    ;
    events_l2InstFetchReq   <= events_l2InstFetchReq_PostClr; 
    events_l2DataFetchReq   <= events_l2DataFetchReq_PostClr; 
    events_iqWaitingInst    <= events_iqWaitingInst_PostClr; 
    occupancy_ibCount       <= ibCount_i    ;
    occupancy_flCount       <= flCount_i    ;
    occupancy_iqCount       <= iqCount_i    ;
    occupancy_ldqCount      <= ldqCount_i   ;
    occupancy_stqCount      <= stqCount_i   ;
    occupancy_commitCount   <= totalCommit_i ;
    program_status_word     <= {fetch1_stall_i,ctiq_stall_i,instBuf_stall_i,freelist_stall_i,backend_stall_i,ldq_stall_i,stq_stall_i,iq_stall_i,rob_stall_i}    ;
    events_fs1fs2Valid       <= events_fs1fs2Valid_PostClr      ;
    events_fs2DecValid       <= events_fs2DecValid_PostClr      ;
    events_renDisValid       <= events_renDisValid_PostClr      ;
    events_instBufRenValid   <= events_instBufRenValid_PostClr  ;
    events_disIqValid        <= events_disIqValid_PostClr       ;  
    events_iqRegReadValid    <= events_iqRegReadValid_PostClr   ;
  end
end

assign totalCyclesPostClr            =  (perfMonRegClr_i && perfMonRegAddr_i == 8'h00) ? 0 : (totalCycles          + 32'b1 );

assign events_commitStorePostClr     =  (perfMonRegClr_i && perfMonRegAddr_i == 8'h01) ? 0 : (events_commitStore   + next_events_commitStore);
assign events_commitLoadPostClr      =  (perfMonRegClr_i && perfMonRegAddr_i == 8'h02) ? 0 : (events_commitLoad    + next_events_commitLoad);
assign events_recoverFlagPostClr     =  (perfMonRegClr_i && perfMonRegAddr_i == 8'h03) ? 0 : (events_recoverFlag   + recoverFlag_i);
assign events_loadViolationPostClr   =  (perfMonRegClr_i && perfMonRegAddr_i == 8'h04) ? 0 : (events_loadViolation + loadViolation_i);
assign events_totalCommitPostClr     =  (perfMonRegClr_i && perfMonRegAddr_i == 8'h05) ? 0 : (events_totalCommit   + totalCommit_i);

assign events_fs1fs2Valid_PostClr      =  (perfMonRegClr_i && perfMonRegAddr_i == 8'h30) ? 0 : (events_fs1fs2Valid     + next_events_fs1fs2Valid);
assign events_fs2DecValid_PostClr      =  (perfMonRegClr_i && perfMonRegAddr_i == 8'h31) ? 0 : (events_fs2DecValid     + next_events_fs2DecValid);
assign events_renDisValid_PostClr      =  (perfMonRegClr_i && perfMonRegAddr_i == 8'h32) ? 0 : (events_renDisValid     + next_events_renDisValid);
assign events_instBufRenValid_PostClr  =  (perfMonRegClr_i && perfMonRegAddr_i == 8'h33) ? 0 : (events_instBufRenValid + next_events_instBufRenValid);
assign events_disIqValid_PostClr       =  (perfMonRegClr_i && perfMonRegAddr_i == 8'h34) ? 0 : (events_disIqValid      + next_events_disIqValid);
assign events_iqRegReadValid_PostClr   =  (perfMonRegClr_i && perfMonRegAddr_i == 8'h35) ? 0 : (events_iqRegReadValid  + next_events_iqRegReadValid);

assign events_fetch1_stallPostClr    =  (perfMonRegClr_i && perfMonRegAddr_i == 8'h40) ? 0 : (events_fetch1_stall   + fetch1_stall_i ); 
assign events_ctiq_stallPostClr      =  (perfMonRegClr_i && perfMonRegAddr_i == 8'h41) ? 0 : (events_ctiq_stall     + ctiq_stall_i ); 
assign events_instBuf_stallPostClr   =  (perfMonRegClr_i && perfMonRegAddr_i == 8'h42) ? 0 : (events_instBuf_stall  + instBuf_stall_i ); 
assign events_freelist_stallPostClr  =  (perfMonRegClr_i && perfMonRegAddr_i == 8'h43) ? 0 : (events_freelist_stall + freelist_stall_i ); 
assign events_backend_stallPostClr   =  (perfMonRegClr_i && perfMonRegAddr_i == 8'h44) ? 0 : (events_backend_stall  + backend_stall_i ); 
assign events_ldq_stallPostClr       =  (perfMonRegClr_i && perfMonRegAddr_i == 8'h45) ? 0 : (events_ldq_stall      + ldq_stall_i ); 
assign events_stq_stallPostClr       =  (perfMonRegClr_i && perfMonRegAddr_i == 8'h46) ? 0 : (events_stq_stall      + stq_stall_i ); 
assign events_iq_stallPostClr        =  (perfMonRegClr_i && perfMonRegAddr_i == 8'h47) ? 0 : (events_iq_stall       + iq_stall_i ); 
assign events_rob_stallPostClr       =  (perfMonRegClr_i && perfMonRegAddr_i == 8'h48) ? 0 : (events_rob_stall      + rob_stall_i ); 
assign events_instMiss_PostClr       =  (perfMonRegClr_i && perfMonRegAddr_i == 8'h50) ? 0 : (events_instMiss       + instMiss_i ); 
assign events_loadMiss_PostClr       =  (perfMonRegClr_i && perfMonRegAddr_i == 8'h51) ? 0 : (events_loadMiss       + loadMiss_i ); 
assign events_storeMiss_PostClr      =  (perfMonRegClr_i && perfMonRegAddr_i == 8'h52) ? 0 : (events_storeMiss      + storeMiss_i ); 
assign events_l2InstFetchReq_PostClr =  (perfMonRegClr_i && perfMonRegAddr_i == 8'h53) ? 0 : (events_l2InstFetchReq + l2InstFetchReq_i ); 
assign events_l2DataFetchReq_PostClr =  (perfMonRegClr_i && perfMonRegAddr_i == 8'h54) ? 0 : (events_l2DataFetchReq + l2DataFetchReq_i ); 
assign events_iqWaitingInst_PostClr  =  (perfMonRegClr_i && perfMonRegAddr_i == 8'h55) ? 0 : (events_iqWaitingInst   + iqReqCount_i-iqIssuedCount_i);

//always @ (commitStore_i or perfMonRegRun_i or perfMonRegGlobalClr_i)
always_comb
begin
int index;
if(perfMonRegGlobalClr_i)
  next_events_commitStore = 0;
else if (perfMonRegRun_i)
begin
  next_events_commitStore = 0;
  for(index = 0 ; index < `COMMIT_WIDTH ; index = index + 1)
    next_events_commitStore = next_events_commitStore + commitStore_i[index];
end
else
  next_events_commitStore = events_commitStore;
end

//always @ (commitLoad_i or perfMonRegRun_i or perfMonRegGlobalClr_i)
always_comb
begin
int index;
  if(perfMonRegGlobalClr_i)
    next_events_commitLoad = 0;
  else if(perfMonRegRun_i)
  begin
    next_events_commitLoad = 0;
    for(index = 0 ; index < `COMMIT_WIDTH ; index = index + 1)
      next_events_commitLoad = next_events_commitLoad + commitLoad_i[index];
  end
  else
    next_events_commitLoad = events_commitLoad;
end

//always @ (fs1Fs2Valid_i or perfMonRegRun_i or perfMonRegGlobalClr_i)
always_comb
begin
int index;
  if(perfMonRegGlobalClr_i)
    next_events_fs1fs2Valid = 0;
  else if(perfMonRegRun_i)
  begin
    next_events_fs1fs2Valid = 0;
    for(index = 0 ; index < `FETCH_WIDTH ; index = index + 1)
      next_events_fs1fs2Valid = next_events_fs1fs2Valid + fs1Fs2Valid_i[index];
  end
  else
    next_events_fs1fs2Valid = events_fs1fs2Valid;
end

//always @ (fs2DecValid_i or perfMonRegRun_i or perfMonRegGlobalClr_i)
always_comb
begin
int index;
  if(perfMonRegGlobalClr_i)
    next_events_fs2DecValid = 0;
  else if (perfMonRegRun_i)
  begin
    next_events_fs2DecValid = 0;
    for(index = 0 ; index < `FETCH_WIDTH ; index = index + 1)
      next_events_fs2DecValid = next_events_fs2DecValid + fs2DecValid_i[index];
  end
  else
    next_events_fs2DecValid = events_fs2DecValid;
end

//always @ (renDisValid_i or perfMonRegRun_i or perfMonRegGlobalClr_i)
always_comb
begin
int index;
  if(perfMonRegGlobalClr_i)
    next_events_renDisValid = 0;
  else if (perfMonRegRun_i)
  begin
    next_events_renDisValid = 0;
    for(index = 0 ; index < `DISPATCH_WIDTH ; index = index + 1)
      next_events_renDisValid = next_events_renDisValid + renDisValid_i[index];
  end
  else
    next_events_renDisValid = events_renDisValid;
end

//always @ (instBufRenValid_i or perfMonRegRun_i  or perfMonRegGlobalClr_i)
always_comb
begin
int index;
  if(perfMonRegGlobalClr_i)
   next_events_instBufRenValid = 0;
  else if (perfMonRegRun_i)
  begin
    next_events_instBufRenValid = 0;
    for(index = 0 ; index < `DISPATCH_WIDTH ; index = index + 1)
      next_events_instBufRenValid = next_events_instBufRenValid + instBufRenValid_i[index];
  end
  else
    next_events_instBufRenValid = events_instBufRenValid;
end

//always @ (disIqValid_i or perfMonRegRun_i or perfMonRegGlobalClr_i)
always_comb
begin
int index;
  if(perfMonRegGlobalClr_i)
    next_events_disIqValid = 0;
  else if (perfMonRegRun_i)
  begin
    next_events_disIqValid = 0;
    for(index = 0 ; index < `DISPATCH_WIDTH ; index = index + 1)
      next_events_disIqValid = next_events_disIqValid + disIqValid_i[index];
  end
  else
      next_events_disIqValid = events_disIqValid ;
end

//always @ (iqRegReadValid_i or perfMonRegRun_i or perfMonRegGlobalClr_i)
always_comb
begin
int index;
  if(perfMonRegGlobalClr_i)
    next_events_iqRegReadValid = 0;
  else if (perfMonRegRun_i)
  begin
    next_events_iqRegReadValid = 0;
    for(index = 0 ; index < `ISSUE_WIDTH ; index = index + 1)
      next_events_iqRegReadValid = next_events_iqRegReadValid + iqRegReadValid_i[index];
  end
  else
    next_events_iqRegReadValid = events_iqRegReadValid;
end
endmodule
