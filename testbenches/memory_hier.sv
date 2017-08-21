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


module memory_hier (
	input                                   icClk,
	input                                   dcClk,
	input                                   reset,

	input  [`SIZE_PC-1:0]                   icPC_i   [0:`FETCH_WIDTH-1],
	input                                   icInstReq_i,
	output reg [`SIZE_INSTRUCTION-1:0]      icInst_o [0:`FETCH_WIDTH-1],
  output exceptionPkt                     icException_o,

`ifdef INST_CACHE
  input  [`ICACHE_BLOCK_ADDR_BITS-1:0]    ic2memReqAddr_i,      // memory read address
  input                                   ic2memReqValid_i,     // memory read enable
  output [`ICACHE_TAG_BITS-1:0]           mem2icTag_o,          // tag of the incoming data
  output [`ICACHE_INDEX_BITS-1:0]         mem2icIndex_o,        // index of the incoming data
  output [`ICACHE_BITS_IN_LINE-1:0]       mem2icData_o,         // requested data
  output                                  mem2icRespValid_o,    // requested data is ready
`endif

`ifdef DATA_CACHE
  // cache-to-memory interface for Loads
  input  [`DCACHE_BLOCK_ADDR_BITS-1:0]    dc2memLdAddr_i,  // memory read address
  input                                   dc2memLdValid_i, // memory read enable

  // memory-to-cache interface for Loads
  output [`DCACHE_TAG_BITS-1:0]           mem2dcLdTag_o,       // tag of the incoming datadetermine
  output [`DCACHE_INDEX_BITS-1:0]         mem2dcLdIndex_o,     // index of the incoming data
  output [`DCACHE_BITS_IN_LINE-1:0]       mem2dcLdData_o,      // requested data
  output                                  mem2dcLdValid_o,     // indicates the requested data is ready

  // cache-to-memory interface for stores
  input  [`DCACHE_ST_ADDR_BITS-1:0]       dc2memStAddr_i,  // memory write address
  input  [`SIZE_DATA-1:0]                 dc2memStData_i,  // memory write address
  input  [`SIZE_DATA_BYTE-1:0]            dc2memStByteEn_i,// memory write address
  input                                   dc2memStValid_i, // memory write enable

  // memory-to-cache interface for stores
  output                                  mem2dcStComplete_o,
`endif

	input  [`SIZE_PC-1:0]                   ldAddr_i,
	output reg [`SIZE_DATA-1:0]             ldData_o,
	input                                   ldEn_i,
  output exceptionPkt                     ldException_o,

	input  [`SIZE_PC-1:0]                   stAddr_i,
	input  [`SIZE_DATA-1:0]                 stData_i,
	input  [`SIZE_DATA_BYTE-1:0]            stEn_i,
  output exceptionPkt                     stException_o,

	input  [1:0]                            ldStSize_i
);

int           fetchException;
int           ldException;
int           stException;
int           dumpException;

always_comb
begin
  icException_o                = 0;
  icException_o.exceptionCause = fetchException;
  icException_o.exception      = (fetchException == 0) ? 1'b0 : 1'b1;
  icException_o.valid          = (fetchException == 0) ? 1'b0 : 1'b1;

  ldException_o                = 0;           
  ldException_o.exceptionCause = ldException;
  ldException_o.exception      = (ldException == 0) ? 1'b0 : 1'b1;
  ldException_o.valid          = (ldException == 0) ? 1'b0 : 1'b1;

  stException_o                = 0;           
  stException_o.exceptionCause = stException;
  stException_o.exception      = (stException == 0) ? 1'b0 : 1'b1;
  stException_o.valid          = (stException == 0) ? 1'b0 : 1'b1;
end

import "DPI-C" function int     getInstruction(longint inst_pc, output int fetch_exception);
import "DPI-C" function longint loadDouble    (longint cycle,   longint ld_addr, output int ld_exception);
import "DPI-C" function longint loadWord      (longint ld_addr, output int ld_exception);
import "DPI-C" function longint loadHalf      (longint ld_addr, output int ld_exception);
import "DPI-C" function longint loadByte      (longint ld_addr, output int ld_exception);
import "DPI-C" function void    storeDouble   (longint st_addr, longint st_data, output int st_exception);
import "DPI-C" function void    storeWord     (longint st_addr, longint st_data, output int st_exception);
import "DPI-C" function void    storeHalf     (longint st_addr, longint st_data, output int st_exception);
import "DPI-C" function void    storeByte     (longint cycle,   longint st_addr, longint st_data, output int st_exception);
import "DPI-C" function longint dumpDouble    (longint addr, output int exception);



//`ifndef SCRATCH_PAD
/* I-Cache */
always_ff @(negedge icClk)
//always_comb
begin
	int i;
	for (i = 0; i < `FETCH_WIDTH; i++)
	begin
    if(icInstReq_i)
    begin
  		icInst_o[i]   = getInstruction(icPC_i[i], fetchException);
  		//icInst_o[i]     = {$read_opcode_hash(icPC_i[i])};
  		//icInst_o[i]   = 32'h0000_0013; //NOP  encoded as ADDI x0, x0, 0
  		//icInst_o[i]   = 32'h0010_0093; //NOP  encoded as ADDI x0, x0, 0
    end
	end
end


reg [`SIZE_DATA-1:0]             dumpData;

/* D-Cache */
always_ff @(negedge dcClk)
//always_comb
begin
	/* Load */
	if (~reset & ldEn_i)
	begin
		ldData_o   = loadDouble(simulate.CYCLE_COUNT,ldAddr_i,ldException);
	end

end


always_ff @ (negedge dcClk)
begin
  int i;
	/* Store */
  for(i=0;i<`SIZE_DATA_BYTE;i++)
  begin
    if(~reset & stEn_i[i])
	    storeByte(simulate.CYCLE_COUNT,(stAddr_i+i),(stData_i>>(8*i)),stException);
  end
	//dumpData   = dumpDouble(stAddr_i,dumpException);
end
//`endif

`ifdef INST_CACHE
  l2_icache l2_inst_cache (
      .clk                                (icClk),
      .reset                              (reset),
  
      .run_i                              (1'b1),
  
      .mem_addr0_i                        ({ic2memReqAddr_i, {(`ICACHE_OFFSET_BITS+`ICACHE_INST_BYTE_OFFSET_LOG){1'b0}}}),
      .mem_re0_i                          (ic2memReqValid_i),
  
      .mem_data0_o                        (mem2icData_o),
      .mem_data_ready0_o                  (mem2icRespValid_o),
      .mem_tag0_o                         (mem2icTag_o),
      .mem_index0_o                       (mem2icIndex_o)
  );
`endif

`ifdef DATA_CACHE
  l2_dcache l2_data_cache (
      .clk                                (dcClk),
      .reset                              (reset),
  
      .run_i                              (1'b1),
  
      .mem_addr0_i                        ({dc2memLdAddr_i, {(`DCACHE_OFFSET_BITS+`DCACHE_WORD_BYTE_OFFSET_LOG){1'b0}}}),
      .mem_re0_i                          (dc2memLdValid_i),
  
      .mem_data0_o                        (mem2dcLdData_o),
      .mem_data_ready0_o                  (mem2dcLdValid_o),
      .mem_tag0_o                         (mem2dcLdTag_o),
      .mem_index0_o                       (mem2dcLdIndex_o),


      .mem_wr_addr0_i                     ({dc2memStAddr_i, {`DCACHE_WORD_BYTE_OFFSET_LOG{1'b0}}}),
      .mem_we0_i                          (dc2memStValid_i),
  
      .mem_wr_data0_i                     (dc2memStData_i),
      .mem_wr_byte_en0_i                  (dc2memStByteEn_i),
      .mem_wr_done0_o                     (mem2dcStComplete_o)

  );
`endif
endmodule


