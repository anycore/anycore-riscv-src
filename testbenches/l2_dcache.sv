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


module l2_dcache #(
    parameter MISS_PENALTY = 2
) (
    input                                   clk,
    input                                   reset,

  `ifdef DATA_CACHE
    input      [`SIZE_PC-1:0]                       mem_addr0_i,
    output reg [`DCACHE_BITS_IN_LINE-1:0]      mem_data0_o,
    input                                   mem_re0_i,
    output                                  mem_data_ready0_o,
    output reg [`DCACHE_TAG_BITS-1:0]       mem_tag0_o,
    output reg [`DCACHE_INDEX_BITS-1:0]     mem_index0_o,

    input      [`SIZE_PC-1:0]               mem_wr_addr0_i,
    input                                   mem_we0_i,
  
    input      [`SIZE_DATA-1:0]             mem_wr_data0_i,
    input      [`SIZE_DATA_BYTE-1:0]        mem_wr_byte_en0_i,
    output reg                              mem_wr_done0_o,
  `endif

    input                                   run_i
);

`ifdef DATA_CACHE
 
	/* Store */
  logic [`SIZE_DATA-1:0]                    mem_wr_data0;
  int                                       stException;
  int                                       ldException;

  //always @ (*)
  //begin
  //  if(mem_we0_i)
  //  begin
  //  	mem_wr_data0 = `READ_WORD(mem_wr_addr0_i);
  //    if(mem_wr_addr0_i[31])
  //      $display("Out of range address 0x%08x\n",mem_wr_addr0_i);
  //  end
  //  else
  //    mem_wr_data0 = 32'h0;


	//  if (mem_wr_byte_en0_i[0])
	//  	mem_wr_data0[7:0]                      = mem_wr_data0_i[7:0];

	//  if (mem_wr_byte_en0_i[1])
	//  	mem_wr_data0[15:8]                     = mem_wr_data0_i[15:8];

	//  if (mem_wr_byte_en0_i[2])
	//  	mem_wr_data0[23:16]                    = mem_wr_data0_i[23:16];

	//  if (mem_wr_byte_en0_i[3])
	//  	mem_wr_data0[31:24]                    = mem_wr_data0_i[31:24];
  //end

  always_ff @ (posedge clk)
  begin
    int i;
  	/* Write request */
    if(reset)
      mem_wr_done0_o  <=  1'b0;
  	else if (mem_we0_i)
  	begin
      for(i=0;i<`SIZE_DATA_BYTE;i++)
      begin
        if(mem_wr_byte_en0_i[i])
	        storeByte(simulate.CYCLE_COUNT,(mem_wr_addr0_i + i),(mem_wr_data0_i >>(8*i)),stException);
      end
      mem_wr_done0_o  <=  1'b1;
  	end
    else
      mem_wr_done0_o  <=  1'b0;
  end
  
  `ifdef PRINT
    always @ (posedge clk)
    begin
        if (~reset & mem_we0_i)
        begin
            $fwrite(top.sim_fd, "[%0d] [D$ Write] mem_wr_addr0: 0x%08x ", `CYCLE_COUNT, mem_wr_addr0_i);
            $fwrite(top.sim_fd, "mem_wr_data0: 0x%08x\n", mem_wr_data0_i);
            $fwrite(top.sim_fd, "mem_wr_byte_en0: 0x%b\n", mem_wr_byte_en0_i);
        end
    end
  `endif



  /* Load */
  logic  [`SIZE_PC-1:0]                          dcache_prev_addr;
  logic                                          mem_re0_i_d;
  
  integer i;
  
  initial
  begin
      mem_re0_i_d =  1'b0;
  end
  
  always @ (posedge clk)
  begin
      if (mem_re0_i)
      begin
          dcache_prev_addr                <= mem_addr0_i;
      end
      mem_re0_i_d <=  mem_re0_i;
  end
  
  
  /* D-Cache */
  // Read again whenever there is a new read request 
  // as data might have been changed by stores
  always @ (mem_re0_i_d)
  begin
      for (i = 0; i < `DCACHE_WORDS_IN_LINE; i = i + 1)
      begin
          mem_data0_o[i*`SIZE_DATA +:`SIZE_DATA]             = loadDouble(simulate.CYCLE_COUNT, dcache_prev_addr+i*8, ldException);
      end
  
      mem_tag0_o      = dcache_prev_addr[`SIZE_PC-1 : `DCACHE_OFFSET_BITS+`DCACHE_INDEX_BITS+`DCACHE_WORD_BYTE_OFFSET_LOG];
      mem_index0_o    = dcache_prev_addr[`DCACHE_OFFSET_BITS+`DCACHE_INDEX_BITS+`DCACHE_WORD_BYTE_OFFSET_LOG-1 : `DCACHE_OFFSET_BITS+`DCACHE_WORD_BYTE_OFFSET_LOG];
  end
 
  /* D-Cache Delay */
  reg [MISS_PENALTY-1:0]              dc_delay_cnt = 0;
  
  always @ (posedge clk)
  begin
      if (reset)
      begin
          dc_delay_cnt                       <= 0;
          /* $display("[%0t] reset (dc_delay_cnt: %d)", $time, dc_delay_cnt); */
      end
  
      else if (~run_i)
      begin
          /* $display("[%0t] run (dc_delay_cnt: %d)", $time, dc_delay_cnt); */
      end
  
      else if (mem_re0_i)
      begin
          dc_delay_cnt                       <= 1;
          /* $display("[%0t] mem_re0_i (dc_delay_cnt: %d)", $time, dc_delay_cnt); */
      end
  
      else if (|dc_delay_cnt)
      begin
          dc_delay_cnt                       <= dc_delay_cnt << 1;
          /* $display("[%0t] dc_delay_cnt (dc_delay_cnt: %d)", $time, dc_delay_cnt); */
      end
  end
  
  assign mem_data_ready0_o               = dc_delay_cnt[MISS_PENALTY-1];
  
  
  `ifdef PRINT
    always @ (posedge clk)
    begin
        if (mem_addr0_i != dcache_prev_addr)
        begin
            $fwrite(top.sim_fd, "[%0d] [I$ Read] mem_addr0: 0x%08x ", `CYCLE_COUNT, mem_addr0_i);
            $fwrite(top.sim_fd, "mem_data0: 0x%x\n", mem_data0_o);
        end
    end
  `endif

`endif //`ifdef DATA_CACHE

endmodule


