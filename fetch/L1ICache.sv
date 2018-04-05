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

module L1ICache (
  input                                 clk,
	input                                 reset,

	/* Address of the insts to be fetched */
	input      [`SIZE_PC-1:0]             PC_i,
  input                                 fetchReq_i,

  /* Instructions from the cache along with indication of exception */
	output reg [`SIZE_INSTRUCTION-1:0]    inst_o   [0:`FETCH_WIDTH-1],
	output reg [0:`FETCH_WIDTH-1]         instValid_o,
  output exceptionPkt                   instException_o,

`ifdef DYNAMIC_CONFIG
  input  [`FETCH_WIDTH-1:0]             fetchLaneActive_i,
  input                                 stallFetch_i,
`endif

`ifdef SCRATCH_PAD
  input  [`DEBUG_INST_RAM_LOG+`DEBUG_INST_RAM_WIDTH_LOG-1:0]   instScratchAddr_i   ,
  input  [7:0]                          instScratchWrData_i ,
  input                                 instScratchWrEn_i   ,
  output [7:0]                          instScratchRdData_o ,
  input                                 instScratchPadEn_i,
`endif

`ifdef INST_CACHE
  output [`ICACHE_BLOCK_ADDR_BITS-1:0]  ic2memReqAddr_o,      // memory read address
  output                                ic2memReqValid_o,     // memory read enable
  input  [`ICACHE_TAG_BITS-1:0]         mem2icTag_i,          // tag of the incoming data
  input  [`ICACHE_INDEX_BITS-1:0]       mem2icIndex_i,        // index of the incoming data
  input  [`ICACHE_BITS_IN_LINE-1:0]     mem2icData_i,         // requested data
  input                                 mem2icRespValid_i,    // requested data is ready
  input                                 icScratchModeEn_i,    // Should ideally be disabled by default
  input  [`ICACHE_INDEX_BITS+`ICACHE_BYTES_IN_LINE_LOG-1:0]  icScratchWrAddr_i,
  input                                 icScratchWrEn_i,
  input  [7:0]                          icScratchWrData_i,
  output [7:0]                          icScratchRdData_o,
`endif  

  output                                icMiss_o,

  /***  RAW interface acting like a always hit I-Cache. Every access 
        fetched directly from the emulated main memory. This interface 
        is not used when caches are enabled.  ***/

	/* Address of the insts to be fetched sent out to testbench*/
	output reg [`SIZE_PC-1:0]             instPC_o [0:`FETCH_WIDTH-1],
  output reg                            fetchReq_o,

  /* Instructions from the testbench along with indication of exception */
	input      [`SIZE_INSTRUCTION-1:0]    inst_i   [0:`FETCH_WIDTH-1],
	input      [0:`FETCH_WIDTH-1]         instValid_i,
  input      exceptionPkt               instException_i



	);

	logic   [`SIZE_INSTRUCTION-1:0]       inst_dbg   [0:`FETCH_WIDTH-1];
`ifdef INST_FETCH_VPI
	logic   [`SIZE_INSTRUCTION-1:0]       inst_vpi   [0:`FETCH_WIDTH-1];
`endif

//import "DPI-C" function int     getInstruction(longint inst_pc, output int fetch_exception);

//`ifdef SCRATCH_PAD
//
//    wire [`DEBUG_INST_RAM_LOG-1:0]                addr0;
//    wire [`DEBUG_INST_RAM_WIDTH-1:0]              inst0;
//    assign addr0                                  = PC_i[(`DEBUG_INST_RAM_LOG+2)-1:2];
//    assign inst_dbg[0]                            = inst0;
//  
//  `ifdef FETCH_TWO_WIDE
//    wire [`DEBUG_INST_RAM_LOG-1:0]                addr1;
//    wire [`DEBUG_INST_RAM_WIDTH-1:0]              inst1;
//    assign addr1                                  = PC_i[(`DEBUG_INST_RAM_LOG+2)-1:2] + 1;
//    assign inst_dbg[1]                            = inst1;
//  `endif
//  
//  `ifdef FETCH_THREE_WIDE
//    wire [`DEBUG_INST_RAM_LOG-1:0]                addr2;
//    wire [`DEBUG_INST_RAM_WIDTH-1:0]              inst2;
//    assign addr2                                  = PC_i[(`DEBUG_INST_RAM_LOG+2)-1:2] + 2;
//    assign inst_dbg[2]                            = inst2;
//  `endif
//  
//  `ifdef FETCH_FOUR_WIDE
//    wire [`DEBUG_INST_RAM_LOG-1:0]                addr3;
//    wire [`DEBUG_INST_RAM_WIDTH-1:0]              inst3;
//    assign addr3                                  = PC_i[(`DEBUG_INST_RAM_LOG+2)-1:2] + 3;
//    assign inst_dbg[3]                            = inst3;
//  `endif
//  
//  `ifdef FETCH_FIVE_WIDE
//    wire [`DEBUG_INST_RAM_LOG-1:0]                addr4;
//    wire [`DEBUG_INST_RAM_WIDTH-1:0]              inst4;
//    assign addr4                                  = PC_i[(`DEBUG_INST_RAM_LOG+2)-1:2] + 4;
//    assign inst_dbg[4]                            = inst4;
//  `endif
//  
//  `ifdef FETCH_SIX_WIDE
//    wire [`DEBUG_INST_RAM_LOG-1:0]                addr5;
//    wire [`DEBUG_INST_RAM_WIDTH-1:0]              inst5;
//    assign addr5                                  = PC_i[(`DEBUG_INST_RAM_LOG+2)-1:2] + 5;
//    assign inst_dbg[5]                            = inst5;
//  `endif
//  
//  `ifdef FETCH_SEVEN_WIDE
//    wire [`DEBUG_INST_RAM_LOG-1:0]                addr6;
//    wire [`DEBUG_INST_RAM_WIDTH-1:0]              inst6;
//    assign addr6                                  = PC_i[(`DEBUG_INST_RAM_LOG+2)-1:2] + 6;
//    assign inst_dbg[6]                            = inst6;
//  `endif
//  
//  `ifdef FETCH_EIGHT_WIDE
//    wire [`DEBUG_INST_RAM_LOG-1:0]                addr7;
//    wire [`DEBUG_INST_RAM_WIDTH-1:0]              inst7;
//    assign addr7                                  = PC_i[(`DEBUG_INST_RAM_LOG+2)-1:2] + 7;
//    assign inst_dbg[7]                            = inst7;
//  `endif
//  
//  `ifdef INST_FETCH_VPI 
//   wire [`SIZE_PC-1:0] pc4;
//   wire [`SIZE_PC-1:0] pc8;
//   wire [`SIZE_PC-1:0] pc12;
//   wire [`SIZE_PC-1:0] pc16;
//   wire [`SIZE_PC-1:0] pc20;
//   wire [`SIZE_PC-1:0] pc24;
//   wire [`SIZE_PC-1:0] pc28;
//   
//   assign pc4  = PC_i + 4 ; 
//   assign pc8  = PC_i + 8 ; 
//   assign pc12 = PC_i + 12 ; 
//   assign pc16 = PC_i + 16; 
//   assign pc20 = PC_i + 20 ; 
//   assign pc24 = PC_i + 24 ; 
//   assign pc28 = PC_i + 28 ;
//   
//   initial
//   begin
//   int i;
//   //i = $init_opcode_hash();
//   end
//   
//    
//   always_comb
//   begin: INSTRUCTION_FETCH_VPI
//    
////         inst_vpi [0]  = {$read_opcode_hash(PC_i[63:32],PC_i[31:0])};
//
//  `ifdef FETCH_TWO_WIDE
////         inst_vpi [1]  = {$read_opcode_hash(pc4[63:32],pc4[31:0])};
//  `endif
//    
//  `ifdef FETCH_THREE_WIDE
////         inst_vpi [2]  = {$read_opcode_hash(pc8[63:32],pc8[31:0])};
//  `endif
//    
//  `ifdef FETCH_FOUR_WIDE
////         inst_vpi [3]  = {$read_opcode_hash(pc12[63:32],pc12[31:0])};
//  `endif
//    
//  `ifdef FETCH_FIVE_WIDE
////         inst_vpi [4]  = {$read_opcode_hash(pc16[63:32],pc16[31:0])};
//  `endif
//    
//  `ifdef FETCH_SIX_WIDE
////         inst_vpi [5]  = {$read_opcode_hash(pc20[63:32],pc20[31:0])};
//  `endif
//    
//  `ifdef FETCH_SEVEN_WIDE
////         inst_vpi [6]  = {$read_opcode_hash(pc24[63:32],pc24[31:0])};
//  `endif
//    
//  `ifdef FETCH_EIGHT_WIDE
////         inst_vpi [7]  = {$read_opcode_hash(pc28[63:32],pc28[31:0])};
//  `endif
//
//   end 
//    
//  `endif
//    
//    DEBUG_INST_RAM #(
//        .DEPTH                                (`DEBUG_INST_RAM_DEPTH),
//        .INDEX                                (`DEBUG_INST_RAM_LOG),
//        .WIDTH                                (`DEBUG_INST_RAM_WIDTH)
//        ) ic (
//        .clk                                  (clk),
//        .reset                                (reset),
//    
//        .addr0_i                              (addr0),
//        .data0_o                              (inst0),
//    
//  `ifdef FETCH_TWO_WIDE
//        .addr1_i                              (addr1),
//        .data1_o                              (inst1),
//  `endif
//    
//  `ifdef FETCH_THREE_WIDE
//        .addr2_i                              (addr2),
//        .data2_o                              (inst2),
//  `endif
//    
//  `ifdef FETCH_FOUR_WIDE
//        .addr3_i                              (addr3),
//        .data3_o                              (inst3),
//  `endif
//    
//  `ifdef FETCH_FIVE_WIDE
//        .addr4_i                              (addr4),
//        .data4_o                              (inst4),
//  `endif
//    
//  `ifdef FETCH_SIX_WIDE
//        .addr5_i                              (addr5),
//        .data5_o                              (inst5),
//  `endif
//    
//  `ifdef FETCH_SEVEN_WIDE
//        .addr6_i                              (addr6),
//        .data6_o                              (inst6),
//  `endif
//    
//  `ifdef FETCH_EIGHT_WIDE
//        .addr7_i                              (addr7),
//        .data7_o                              (inst7),
//  `endif
//    
//        .instScratchAddr_i                    (instScratchAddr_i),
//        .instScratchWrData_i                  (instScratchWrData_i),
//        .instScratchWrEn_i                    (instScratchWrEn_i),
//        .instScratchRdData_o                  (instScratchRdData_o)
//      );
//
//
//  // When scratch pad is enabled, it is the default source
//  // until the instScratchPadEn_i is changed to 0.
//  always_comb
//  begin
//    if(instScratchPadEn_i)
//    begin
//    `ifdef INST_FETCH_VPI
//      inst_o  = inst_vpi;
//     `else
//      inst_o  = inst_dbg;
//     `endif
//      instValid_o = {`FETCH_WIDTH{1'b1}};
//    end
//    else
//    begin
//      inst_o  = inst_i;
//      instValid_o = instValid_i;
//    end
//  end
//
//`elsif INST_CACHE 
`ifdef INST_CACHE
// Cache mode

  logic [`SIZE_INSTRUCTION-1:0]   inst           [0:`FETCH_WIDTH-1];
  logic [0:`FETCH_WIDTH-1]        instValid;

  ICache_controller #(
      .FETCH_WIDTH            (`FETCH_WIDTH)
  )
      icache (
  
      .clk                    (clk),
      .reset                  (reset),
      .icScratchModeEn_i      (icScratchModeEn_i),

      .mmuException_i         (instException_o.valid),
      .icMiss_o               (icMiss_o),
  
      .fetchReq_i             (fetchReq_i),
      .pc_i                   (PC_i),
      .inst_o                 (inst),
      .instValid_o            (instValid),
      
      .ic2memReqAddr_o        (ic2memReqAddr_o),
      .ic2memReqValid_o       (ic2memReqValid_o),
      
      .icScratchWrAddr_i      (icScratchWrAddr_i),
      .icScratchWrEn_i        (icScratchWrEn_i  ),
      .icScratchWrData_i      (icScratchWrData_i),
      .icScratchRdData_o      (icScratchRdData_o),
  
      .mem2icTag_i            (mem2icTag_i),
      .mem2icIndex_i          (mem2icIndex_i),
      .mem2icData_i           (mem2icData_i),
      .mem2icRespValid_i      (mem2icRespValid_i)
  );

  always_comb
  begin
    int i;
    inst_o  = inst;
    //getInstruction(PC_i, instException_o);
    `ifdef DYNAMIC_CONFIG
      for(i = 0; i < `FETCH_WIDTH; i++)
      begin
        //Use the instValid from the ICACHE
        instValid_o[i] = instValid[i] & fetchLaneActive_i[i];
      end
    `else
      instValid_o = instValid;
    `endif
  end

`else  // No CACHE and No SCRATCH_PAD

  always_comb
  begin
    int i;
    inst_o  = inst_i;
    //instException_o = instException_i;
    `ifdef DYNAMIC_CONFIG
      for(i = 0; i < `FETCH_WIDTH; i++)
        instValid_o[i] = instValid_i[i] & fetchLaneActive_i[i] & ~stallFetch_i & fetchReq_i;
    `else
      instValid_o = instValid_i & {`FETCH_WIDTH{fetchReq_i}};
    `endif
  end

`endif //`ifdef SCRATCH_PAD


always_comb
begin
	int i;

	for (i = 0; i < `FETCH_WIDTH; i = i + 1) 
	begin
		instPC_o[i]    = PC_i + (i * 4); // INSTRUCTION IS 4-byte long
	end
  fetchReq_o  = fetchReq_i;
end

wire [7:0]                    exception;
// MMU in parallel with cache access.
// Need to figure out whether a load/store
// excepts. This is even more critical for stores
// as we must figure out before exposing the store to the
// cache hierarchy.
//MMU mmu
//(
//  .clk            (clk),
//  .virtAddress_i  (PC_i),
//  .numBytes_i     (`SIZE_INSTRUCTION_BYTE),
//  .ldAccess_i     (1'b0),
//  .stAccess_i     (1'b0),
//  .instAccess_i   (fetchReq_i),
//  .exception_o    (exception)
//);

// jbalkind: Not doing this check just now
assign exception = 8'b0;

always_comb
begin
  instException_o                = 0;
  instException_o.exceptionCause = exception;
  instException_o.exception      = (exception == 0) ? 1'b0 : 1'b1;
  instException_o.valid          = (exception == 0) ? 1'b0 : 1'b1;
end

endmodule

