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


module l2_icache #(
    parameter MISS_PENALTY = 2
) (
    input                                   clk,
    input                                   reset,

  `ifdef INST_CACHE
    input  [`SIZE_PC-1:0]       mem_addr0_i,
    output reg [`ICACHE_BITS_IN_LINE-1:0]      mem_data0_o,
    input                                   mem_re0_i,
    output                                  mem_data_ready0_o,
    output reg [`ICACHE_TAG_BITS-1:0]       mem_tag0_o,
    output reg [`ICACHE_INDEX_BITS-1:0]     mem_index0_o,
  `endif

    input                                   run_i
);

`ifdef INST_CACHE

  reg  [`SIZE_PC-1:0]                               icache_prev_addr;
  logic                                     mem_re0_i_d;
  int                                       fetchException;
  
  integer i;
  
  initial
  begin
      mem_re0_i_d =  1'b0;
  end
  
  always @ (posedge clk)
  begin
      if (mem_re0_i)
      begin
          icache_prev_addr                <= mem_addr0_i;
      end
      mem_re0_i_d <=  mem_re0_i;
  end
  
  
  /* I-Cache */
  always @ (mem_re0_i_d)
  begin
      for (i = 0; i < `ICACHE_INSTS_IN_LINE; i = i + 1)
      begin
          mem_data0_o[i*`SIZE_INSTRUCTION+`SIZE_INSTRUCTION-1 -: `SIZE_INSTRUCTION] = getInstruction((icache_prev_addr+i*4),fetchException);
      end
  
      mem_tag0_o      = icache_prev_addr[`ICACHE_INDEX_BITS+`ICACHE_OFFSET_BITS+`ICACHE_INST_BYTE_OFFSET_LOG+`ICACHE_TAG_BITS-1 : `ICACHE_INDEX_BITS+`ICACHE_OFFSET_BITS+`ICACHE_INST_BYTE_OFFSET_LOG];
      mem_index0_o    = icache_prev_addr[`ICACHE_OFFSET_BITS+`ICACHE_INST_BYTE_OFFSET_LOG+`ICACHE_INDEX_BITS-1 : `ICACHE_OFFSET_BITS+`ICACHE_INST_BYTE_OFFSET_LOG];
  end

  
  /* I-Cache Delay */
  reg [MISS_PENALTY-1:0]              ic_delay_cnt = 0;
  
  always @ (posedge clk)
  begin
      if (reset)
      begin
          ic_delay_cnt                       <= 0;
          /* $display("[%0t] reset (ic_delay_cnt: %d)", $time, ic_delay_cnt); */
      end
  
      else if (~run_i)
      begin
          /* $display("[%0t] run (ic_delay_cnt: %d)", $time, ic_delay_cnt); */
      end
  
      else if (mem_re0_i)
      begin
          ic_delay_cnt                       <= 1;
          /* $display("[%0t] mem_re0_i (ic_delay_cnt: %d)", $time, ic_delay_cnt); */
      end
  
      else if (|ic_delay_cnt)
      begin
          ic_delay_cnt                       <= ic_delay_cnt << 1;
          /* $display("[%0t] ic_delay_cnt (ic_delay_cnt: %d)", $time, ic_delay_cnt); */
      end
  end
  
  assign mem_data_ready0_o               = ic_delay_cnt[MISS_PENALTY-1];
  
  
  `ifdef PRINT
  always @ (posedge clk)
  begin
      if (mem_addr0_i != icache_prev_addr)
      begin
          $fwrite(top.sim_fd, "[%0d] [I$ Read] mem_addr0: 0x%08x ", `CYCLE_COUNT, mem_addr0_i);
          $fwrite(top.sim_fd, "mem_data0: 0x%x\n", mem_data0_o);
      end
  end
  `endif

`endif //`ifdef INST_CACHE

endmodule


