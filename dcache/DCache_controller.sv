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


module DCache_controller(
    input                               clk,
    input                               reset,
    input                               dcScratchModeEn_i, // Should ideally be disabled by default
    output                              stallStCommit_o,  // Signals LSU to stall committing stores since 
                                                          // store buffer is full

    // processor/cache interface
    input                               ldEn_i,
    input  [`SIZE_PC-1:0]               ldAddr_i,
    input  [`LDST_TYPES_LOG-1:0]        ldSize_i,
    input                               ldSign_i,
    output reg [`SIZE_DATA-1:0]         ldData_o,
    output reg                          ldHit_o,
    output reg                          ldDataValid_o,

    input                               stEn_i,
    input  [`SIZE_PC-1:0]               stAddr_i,
    input  [`LDST_TYPES_LOG-1:0]        stSize_i,
    input  [`SIZE_DATA-1:0]             stData_i, 
    //input  [2**`DCACHE_WORD_BYTE_OFFSET_LOG-1:0]stByteEn_i, 
    output                              stHit_o,

`ifdef DATA_CACHE
    // cache-to-memory interface for Loads
    output [`DCACHE_BLOCK_ADDR_BITS-1:0]dc2memLdAddr_o,  // memory read address
    output reg                          dc2memLdValid_o, // memory read enable

    // memory-to-cache interface for Loads
    input  [`DCACHE_TAG_BITS-1:0]       mem2dcLdTag_i,   // tag of the incoming datadetermine
    input  [`DCACHE_INDEX_BITS-1:0]     mem2dcLdIndex_i, // index of the incoming data
    input  [`DCACHE_BITS_IN_LINE-1:0]   mem2dcLdData_i,  // requested data
    input                               mem2dcLdValid_i, // indicates the requested data is ready

    // cache-to-memory interface for stores
    output [`DCACHE_ST_ADDR_BITS-1:0]   dc2memStAddr_o,  // memory read address
    output [`SIZE_DATA-1:0]             dc2memStData_o,  // memory read address
    output [`SIZE_DATA_BYTE-1:0]        dc2memStByteEn_o,// memory read address
    output reg                          dc2memStValid_o, // memory read enable

    output                              stbEmpty_o,      // Signals that there are no pending stores to be written to next level

    // memory-to-cache interface for stores
    input                               mem2dcStComplete_i,

    input [`DCACHE_INDEX_BITS+`DCACHE_BYTES_IN_LINE_LOG-1:0]  dcScratchWrAddr_i,
    input                                                     dcScratchWrEn_i,
    input [7:0]                                               dcScratchWrData_i,
    output [7:0]                                              dcScratchRdData_o,

    input                               dcFlush_i,
    output reg                          dcFlushDone_o,
`endif    

    output                              ldMiss_o,
    output                              stMiss_o,

    input                               mem2dcStStall_i // Signals data cache to stop writing through stores

);

`ifdef DATA_CACHE

  // breakdown of pc bits
  // 32      24      16       8       0
  //  |-------|-------|-------|-------|
  //           ttttttttttiiiiiiiiioo
  //
  // note: the tag is only 10 bits because the pc will never be higher 
  // than 32'h007fffff for CPU2000 benchmarks
  
  
  ////////////////////////////////////////////////////////////
  // processor/cache interface ///////////////////////////////
  ////////////////////////////////////////////////////////////
  
  
  // SCRATCH Mode related signals - Pipelined once for better timing and fanout
  logic                                 dcScratchModeEn_d1;
  logic [`DCACHE_INDEX_BITS-1:0]        dcScratchWrIndex_d1;
  logic [`DCACHE_BYTES_IN_LINE_LOG-1:0] dcScratchWrByte_d1;
  logic [7:0]                           dcScratchWrData_d1;
  logic                                 dcScratchWrEn_d1;
  logic                                 mem2dcStComplete_d1;
  logic [`DCACHE_BITS_IN_LINE-1:0]      mem2dcLdData_d1;  // requested data

  always_ff @(posedge clk or posedge reset)
  begin
    if(reset)
    begin
      dcScratchModeEn_d1   <=  1'b0;    // Default is SCRATCH mode on reset
      dcScratchWrIndex_d1  <=  {`DCACHE_INDEX_BITS{1'b0}};
      dcScratchWrByte_d1   <=  {`DCACHE_BYTES_IN_LINE_LOG{1'b0}};
      dcScratchWrData_d1   <=  8'h0;
      dcScratchWrEn_d1     <=  1'b0;
      mem2dcStComplete_d1  <=  1'b0;
    end
    else
    begin
      dcScratchModeEn_d1   <=  dcScratchModeEn_i;
      dcScratchWrIndex_d1  <=  dcScratchWrAddr_i[`DCACHE_INDEX_BITS+`DCACHE_BYTES_IN_LINE_LOG-1:`DCACHE_BYTES_IN_LINE_LOG];
      dcScratchWrByte_d1   <=  dcScratchWrAddr_i[`DCACHE_BYTES_IN_LINE_LOG-1:0];
      dcScratchWrData_d1   <=  dcScratchWrData_i;
      dcScratchWrEn_d1     <=  dcScratchWrEn_i  ;
      mem2dcStComplete_d1  <=  mem2dcStComplete_i;
    end
  end
   
  // load pc segments /////////////////////////////////////////////
  logic [`DCACHE_OFFSET_BITS-1:0]    ld_offset;
  logic [`DCACHE_INDEX_BITS-1:0]     ld_index;
  logic [`DCACHE_TAG_BITS-1:0]       ld_tag;
  logic [`DCACHE_OFFSET_BITS-1:0]    ld_offset_reg;
  logic [`DCACHE_INDEX_BITS-1:0]     ld_index_reg;
  logic [`DCACHE_TAG_BITS-1:0]       ld_tag_reg;
  logic                              ldEn_reg;
  logic [`SIZE_DATA-1:0]             ldData;

  // store pc segments /////////////////////////////////////////////
  logic [`DCACHE_OFFSET_BITS-1:0]    st_offset;
  logic [`DCACHE_INDEX_BITS-1:0]     st_index;
  logic [`DCACHE_TAG_BITS-1:0]       st_tag;
  logic [`DCACHE_OFFSET_BITS-1:0]    st_offset_reg;
  logic [`DCACHE_INDEX_BITS-1:0]     st_index_reg;
  logic [`DCACHE_TAG_BITS-1:0]       st_tag_reg;
  logic                              stEn_reg;
  logic                              stEn_reg_d1;
  logic [`SIZE_DATA_BYTE-1:0]        stByteEn;
  logic [`SIZE_DATA_BYTE-1:0]        stByteEn_reg;
  logic [`SIZE_DATA-1:0]             stData;
  logic [`SIZE_DATA-1:0]             stData_reg;
  logic [`DCACHE_OFFSET_BITS-1:0]    stbHeadOffset;
  logic [`DCACHE_INDEX_BITS-1:0]     stbHeadIndex;
  logic [`DCACHE_TAG_BITS-1:0]       stbHeadTag;
  logic [`SIZE_DATA_BYTE-1:0]        stbHeadByteEn;
  logic [`SIZE_DATA-1:0]             stbHeadData;
  logic                              stbPartialHit;

  // the unregistered index is for reading the tag/data array
  assign ld_offset                = ldAddr_i[`DCACHE_OFFSET_BITS+`DCACHE_WORD_BYTE_OFFSET_LOG-1 : `DCACHE_WORD_BYTE_OFFSET_LOG];
  assign ld_index                 = ldAddr_i[`DCACHE_OFFSET_BITS+`DCACHE_INDEX_BITS+`DCACHE_WORD_BYTE_OFFSET_LOG-1 : `DCACHE_OFFSET_BITS+`DCACHE_WORD_BYTE_OFFSET_LOG];
  assign ld_tag                   = ldAddr_i[`SIZE_PC-1 : `DCACHE_OFFSET_BITS+`DCACHE_INDEX_BITS+`DCACHE_WORD_BYTE_OFFSET_LOG];
  
  //TODO: Check for misaligned access for the different sizes
  
  
  // the registered signals are for miss handling
  always_ff @(posedge clk)
  begin
    ld_tag_reg              <= ld_tag;
    ld_index_reg            <= ld_index;
    ld_offset_reg           <= ld_offset;
    ldEn_reg                <= ldEn_i;
  end
  
  // tag, valid and data read from cache /////////////////////
  logic [`DCACHE_TAG_BITS-1:0]    ld_cache_tag;
  logic [`DCACHE_BITS_IN_LINE-1:0]ld_cache_data;
  logic                           ld_cache_valid;
  
  // hit detection logic. hits are detected the cycle after ldEn_i goes high.
  // hit can stay high for multiple cycles if no new request comes (e.g. fetch
  // stalls)
  logic                           ldHit;
  
  
  // Muxing might be needed to account for the differing load sizes
  always_comb
  begin:LD_ALIGN
  
    //ldData_o = 32'hdeadbeef;
    // Consider it as a miss if a partial hit in STB. Being conservative
    // whenever a size mismatch is observed.
    ldDataValid_o = ldHit & ~stbPartialHit; 
    ldHit_o = ldHit & ~stbPartialHit;
  
  	case (ldSize_i)
  		`LDST_BYTE: 
       		begin
			ldData_o = (ldData >> {ldAddr_i[2:0], 3'h0}) & 64'h0000_0000_0000_00FF;
  			if(ldSign_i)
         		 	ldData_o = {{56{ldData_o[7]}},ldData_o[7:0]};
       		end
  		`LDST_HALF_WORD: 
      		begin
			ldData_o = (ldData >> {ldAddr_i[2:1], 4'h0}) & 64'h0000_0000_0000_FFFF;
			if(ldSign_i)
          			ldData_o = {{48{ldData_o[15]}},ldData_o[15:0]};
		end
  
  		`LDST_WORD:
  		begin
			ldData_o = (ldData >> {ldAddr_i[2], 5'h0}) & 64'h0000_0000_FFFF_FFFF;
			 if(ldSign_i)
          			ldData_o = {{32{ldData_o[31]}},ldData_o[31:0]};

		end

		`LDST_DOUBLE_WORD:
			ldData_o = ldData;
  	endcase
  
    // If trying to access heap region
//  	if (ldAddr_i[31])
//  		ldData_o = 32'hdeadbeef;
  end
  
  
  ///////////////////////////////////////////////
  // MSHR / FILL  Logic /////////////////////
  ///////////////////////////////////////////////
  
  logic                               fillValid;
  logic   [`DCACHE_OFFSET_BITS-1:0]   fillOffset;
  logic   [`DCACHE_INDEX_BITS-1:0]    fillIndex;
  logic   [`DCACHE_TAG_BITS-1:0]      fillTag;
  logic   [`DCACHE_BITS_IN_LINE-1:0]  fillData;
  
  // MHSR 0 
  logic                               mshr0Valid;
  logic   [`DCACHE_OFFSET_BITS-1:0]   mshr0Offset;
  logic   [`DCACHE_INDEX_BITS-1:0]    mshr0Index;
  logic   [`DCACHE_TAG_BITS-1:0]      mshr0Tag;
  logic   [`DCACHE_BITS_IN_LINE-1:0]  mshr0StData;    // Holds the store data to be merged with fill data once it is received
  logic   [`DCACHE_BYTES_IN_LINE-1:0] mshr0StByteEn;  // Takes care of partial store validity
  logic   [`DCACHE_BITS_IN_LINE-1:0]  mshr0StData_next;    // Holds the store data to be merged with fill data once it is received
  logic   [`DCACHE_BYTES_IN_LINE-1:0] mshr0StByteEn_next;  // Takes care of partial store validity
  logic   [`DCACHE_OFFSET_BITS-1:0]   mshr0StOffset;  // Holds the offset in the fill line for the store data
  
  // Misc signals
  logic                               miss;
  logic                               miss_d1;
  logic                               miss_d2;
  logic                               miss_pulse;
  logic                               missUnderMiss;
  
  assign miss = ~ldHit;

  assign ldMiss_o = miss & ldEn_i; 
  
  always_ff @(posedge clk or posedge reset)
  begin
    if(reset)
    begin
      miss_d1 <= 1'b0;
      miss_d2 <= 1'b0;
    end
    else
    begin
      miss_d1 <= miss & ldEn_i & (~fillValid | (fillValid & ~(fillTag == ld_tag_reg)));
      //miss_d1 <= miss & ldEn_i & ~fillValid;
      // Clear on a fillValid so that a pulse is generated for a pending miss
      miss_d2 <= miss_d1 & ~fillValid; 
    end
  end
  
  assign miss_pulse = miss_d1 & ~miss_d2;
  //assign miss_pulse = ldEn_i & miss & ~miss_d1;
  
  // send a request the cycle after ldEn_i goes high is hit is low.
  assign dc2memLdAddr_o        = {ld_tag_reg, ld_index_reg};
  // 1) Load only once per read miss and only one miss at a time.
  // 2) Load only is MSHR is not already locked up 
  //    OR a previous miss is completing in this cycle, which makes the MSHR free
  // 3) If MSHR is not free, let the reader replay the read.
  assign dc2memLdValid_o       = miss_pulse &  
                                (~mshr0Valid | 
                                    (fillValid & ~(fillTag == ld_tag_reg)));   // If the line being filled misses again, don't request again 
  
  /* The following block currently implements a single MSHR.
     It can be easily extended to support a fully associative
     file of MSHRs */
  // Staging everything coming from elsewhere for better timing closure (avoid hold violations after clk gating)
  always_ff @(posedge clk or posedge reset)
  begin
    if(reset)
      fillValid       <=  1'b0;
    else
    begin
      // NOTE: SCRATCH MODE
      // Pull fill valid low whenever in scratch mode.
      fillValid       <= ~dcScratchModeEn_d1 & (mem2dcLdValid_i & mshr0Valid & (mshr0Index == mem2dcLdIndex_i) & (mshr0Tag == mem2dcLdTag_i));
      fillIndex       <= mshr0Index;
      fillTag         <= mshr0Tag;
      mem2dcLdData_d1 <=  mem2dcLdData_i;
    end
  end

  always_comb
  begin    
    int i,j;
    // Merge received data with the latest store data byte by byte
    for(i=0;i<`DCACHE_WORDS_IN_LINE;i++)
      for(j=0;j<`SIZE_DATA_BYTE;j++)
        fillData[(i*`SIZE_DATA_BYTE+j)*8 +: 8]  <= mshr0StByteEn_next[i*`SIZE_DATA_BYTE+j] ? mshr0StData_next[(i*`SIZE_DATA_BYTE+j)*8 +:8] : mem2dcLdData_d1[(i*`SIZE_DATA_BYTE+j)*8 +: 8];
        //fillData[(i*`SIZE_DATA_BYTE+j)*8 +: 8]  = mshr0StByteEn[i*`SIZE_DATA_BYTE+j] ? mshr0StData[(i*`SIZE_DATA_BYTE+j)*8 +:8] : mem2dcLdData_i[(i*`SIZE_DATA_BYTE+j)*8 +: 8];
  end



  // For each store being completed, form the line to be merged int MSHR fill data
  // This is the latest architectural state of the cache line
  always_comb
  begin
    int i,j;
    begin
      mshr0StData_next    = mshr0StData;
      mshr0StByteEn_next  = mshr0StByteEn;

      // Merge only if there is a mathing store that is completing
      if(mem2dcStComplete_d1 & mshr0Valid & ({mshr0Tag,mshr0Index} == {stbHeadTag,stbHeadIndex}))
        for(i=0;i < `DCACHE_WORDS_IN_LINE; i++)
        begin
          if(i == stbHeadOffset) // Merge the data for the current completing store
          begin
            for(j=0;j < `SIZE_DATA_BYTE; j++)
              if(stbHeadByteEn[j])
              begin
                mshr0StData_next[(i*`SIZE_DATA_BYTE+j)*8 +: 8]    =  stbHeadData[j*8 +: 8]; //Update store line per byte
                mshr0StByteEn_next[i*`SIZE_DATA_BYTE+j]           =  1'b1;  // Merge the byte enables for the word
              end
          end
        end
    end
  end

  always_ff @(posedge clk or posedge reset)
  begin
    if(reset)
    begin
      mshr0Valid <= 1'b0;
      mshr0Index <= 9'b0;
      mshr0Offset<= 3'b0;
      mshr0Tag   <= 10'b0;
      mshr0StData   <=  {`DCACHE_BITS_IN_LINE{1'b0}};
      mshr0StByteEn <=  {`DCACHE_BYTES_IN_LINE{1'b0}};
    end
    else
    begin
      // Clear on fill valid and set on L2 read request
      case({fillValid,miss_pulse})
        2'b00: begin
          missUnderMiss <= missUnderMiss;
          mshr0Valid <= mshr0Valid;
        end
        2'b01: begin 
          mshr0Valid <= 1'b1; 
          if(mshr0Valid) 
            missUnderMiss <= 1'b1;
          else // if not already handling a miss, record the address
          begin
            mshr0Index  <= ld_index_reg;
            mshr0Offset <= ld_offset_reg;
            mshr0Tag    <= ld_tag_reg;
          end
        end
        2'b10: begin
          missUnderMiss <= 1'b0;
          mshr0Valid <= 1'b0;
        end
        2'b11: begin // If completing a miss handling in the same cycle
          missUnderMiss <= 1'b0;
          mshr0Valid  <= ~(fillTag == ld_tag_reg); // Only if the line being filled is different from the one missed
          mshr0Index  <= ld_index_reg;
          mshr0Offset <= ld_offset_reg;
          mshr0Tag    <= ld_tag_reg;
        end
        default: begin
          missUnderMiss <= 1'b0;
          mshr0Valid  <= mshr0Valid;
          mshr0Index  <= mshr0Index;
          mshr0Offset <= mshr0Offset; 
          mshr0Tag    <= mshr0Tag; 
        end
      endcase

      // Reset these once fill is complete
      if(fillValid)
      begin
        mshr0StData   <=  {`DCACHE_BITS_IN_LINE{1'b0}} ;
        mshr0StByteEn <=  {`DCACHE_BYTES_IN_LINE{1'b0}} ;
      end
      // Check MSHR for a match for every incoming store.
      // If an incoming store matches in the cycle the line is being filled,
      // the value is directly bypassed throught he mshr0StData_next and mshr0StByteEn_next
      // signals. This value need not be recorded in the mshr0StData register.
      else
      begin
        mshr0StData   <=  mshr0StData_next;
        mshr0StByteEn <=  mshr0StByteEn_next;
      end


    end
  end
  
  ////////////////////////////////////////////////////////////

  logic [`DCACHE_TAG_BITS-1:0]      st_cache_tag;
  logic [`DCACHE_BITS_IN_LINE-1:0]  st_cache_data;
  logic                             st_cache_valid;
  logic [`DCACHE_BITS_IN_LINE-1:0]  stbUpdateData;
  
  logic                             stHit;

  // the unregistered index is for reading the tag/data array
  assign st_offset                = stAddr_i[`DCACHE_OFFSET_BITS+`DCACHE_WORD_BYTE_OFFSET_LOG-1 : `DCACHE_WORD_BYTE_OFFSET_LOG];
  assign st_index                 = stAddr_i[`DCACHE_OFFSET_BITS+`DCACHE_INDEX_BITS+`DCACHE_WORD_BYTE_OFFSET_LOG-1 : `DCACHE_OFFSET_BITS+`DCACHE_WORD_BYTE_OFFSET_LOG];
  assign st_tag                   = stAddr_i[`SIZE_PC-1 : `DCACHE_OFFSET_BITS+`DCACHE_INDEX_BITS+`DCACHE_WORD_BYTE_OFFSET_LOG];
  

  always_comb
  begin:ST_ALIGN
  
    stData = 64'hbaddbeefdeadbeef;
    stByteEn   = 8'h0;
  
  	case (stSize_i)
  		`LDST_BYTE:
  		begin
  			/* Shift the least-significant byte to the correct byte offset */
  			stData = stData_i << {stAddr_i[2:0], 3'h0};
  			stByteEn   = 8'h1 << stAddr_i[2:0];
  		end
  
  		`LDST_HALF_WORD:
  		begin
  			stData = stData_i << {stAddr_i[2:1], 4'h0};
  			stByteEn   = 8'h3 << {stAddr_i[2:1], 1'h0};
  		end
  
  		`LDST_WORD:
  		begin
  			stData = stAddr_i[2] ? {stData_i[31:0],32'b0} : {32'b0,stData_i[31:0]};
  			stByteEn   = stAddr_i[2] ? 8'hF0 : 8'h0F;
  		end
  		
  		`LDST_DOUBLE_WORD:
		  begin
		  	stData = stData_i;
		  	stByteEn   = 8'hFF;
		  end
  	endcase
  end
  
  // the registered signals are for miss handling
  always_ff @(posedge clk)
  begin
    st_tag_reg              <= st_tag;
    st_index_reg            <= st_index;
    st_offset_reg           <= st_offset;
    stData_reg              <= stData;
    stEn_reg                <= stEn_i;
    stEn_reg_d1             <= stEn_i;
    stByteEn_reg            <= stByteEn;
  end
  
  // 1) Stores update the cache once the write through to memory is complete
  // 2) Incoming stores check MSHR for match and updates the MSHR data buffer.
  //    If multiple stores happen to the same row, they will update the buffer
  //    in commit order.
  // 3) Partial match in the store buffer is treated as a miss to avoid reading
  //    stale data from cache/memory. Once the store completes, the replay mechanism
  //    makes sure of a future hit.
  
  assign  stHit_o = stHit;

  assign  stMiss_o = ~stHit & mem2dcStComplete_d1;
  
  assign dc2memStAddr_o        = {st_tag_reg, st_index_reg, st_offset_reg};
  assign dc2memStData_o        = stData_reg;
  assign dc2memStByteEn_o      = stByteEn_reg;
  assign dc2memStValid_o       = stEn_reg & (~dcScratchModeEn_d1);
  
  logic [`SIZE_DATA-1:0]           stbData[`DCACHE_SIZE_STB-1:0];
  logic [`SIZE_DATA_BYTE-1:0]      stbByteEn[`DCACHE_SIZE_STB-1:0];
  logic [`SIZE_PC-1:0]             stbAddr[`DCACHE_SIZE_STB-1:0];
  logic [`LDST_TYPES_LOG-1:0]      stbStSize[`DCACHE_SIZE_STB-1:0];
  logic [`DCACHE_SIZE_STB-1:0]     stbValid;
  logic [`DCACHE_SIZE_STB-1:0]     validVectWrap;
  logic [`DCACHE_SIZE_STB-1:0]     validVectNoWrap;
  logic [`DCACHE_SIZE_STB-1:0]     validVect;
  logic [`DCACHE_SIZE_STB-1:0]     stbMatchWordAddr;
  logic [`DCACHE_SIZE_STB-1:0]     stbMatchByteAddr;
  logic [`DCACHE_SIZE_STB-1:0]     stbMatchSize;
  logic [`DCACHE_SIZE_STB-1:0]     stbMatch;
  logic [`DCACHE_SIZE_STB-1:0]     stbMatchPartial;
  logic [`DCACHE_SIZE_STB-1:0]     stbMatch_tmp;
  logic [`DCACHE_SIZE_STB-1:0]     stbMatch_part;
  logic [`DCACHE_SIZE_STB_LOG-1:0] stbHead;
  logic [`DCACHE_SIZE_STB_LOG-1:0] stbHead_next;
  logic [`DCACHE_SIZE_STB_LOG-1:0] stbTail;
  logic [`DCACHE_SIZE_STB_LOG-1:0] stbTail_next;
  logic [`DCACHE_SIZE_STB_LOG-1:0] latestMatch;
  logic [`DCACHE_SIZE_STB_LOG-1:0] latestPartialMatch;
  logic                            stbHit;
  logic [31:0]                     stbHitCount;
  logic                            stbWrapped;
  logic                            stbFull;
  
  assign stbFull = (stbTail == stbHead) & stbValid[stbHead];
  assign stbEmpty_o = (stbTail == stbHead) & ~stbValid[stbHead];
  assign stallStCommit_o = mem2dcStStall_i | stbFull;
  
  always_ff @(posedge clk or posedge reset) 
  begin 

    if(reset)
    begin
      stbHead   <= 0;
      stbTail   <= 0;
      stbValid  <=  0;
    end
    else
    begin
      if(stEn_i)
      begin
        stbData[stbTail]    <= stData; // Store the aligned data
        stbByteEn[stbTail]  <= stByteEn; // Store the aligned data
        stbAddr[stbTail]    <= stAddr_i;
        stbStSize[stbTail]  <= stSize_i;
        stbValid[stbTail]   <= 1'b1;
        stbTail             <= stbTail_next;
      end
  
      // If in SCRATCH mode complete forward store buffer after a couple of cycles
      if(mem2dcStComplete_d1 | (dcScratchModeEn_d1 & stEn_reg_d1))
      begin
        stbHead <= stbHead_next;
        stbValid[stbHead]   <= 1'b0;
      end
    end
  end
  
  always_comb
  begin: STB_PTR_NXT
    stbTail_next = stbTail + 1'b1;
    if(stbTail_next >= `DCACHE_SIZE_STB)
      stbTail_next = 0;
  
    stbHead_next = stbHead + 1'b1;
    if(stbHead_next >= `DCACHE_SIZE_STB)
      stbHead_next = 0;
  end
  
  always_comb
  begin: ST_LD_FWD
    int i,index;
    stbHit = 1'b0; //Default
    stbPartialHit = 1'b0;
    latestMatch = 0; //Default

    // Must have default values otherwise latches might be created
    stbMatch_tmp  = {`DCACHE_SIZE_STB{1'b0}};
    stbMatch_part = {`DCACHE_SIZE_STB{1'b0}};
    stbMatchWordAddr = {`DCACHE_SIZE_STB{1'b0}};
    stbMatchByteAddr = {`DCACHE_SIZE_STB{1'b0}};
    stbMatchSize     = {`DCACHE_SIZE_STB{1'b0}};

    validVectWrap   = {`DCACHE_SIZE_STB{1'b0}};
    validVectNoWrap = {`DCACHE_SIZE_STB{1'b0}};
  
    for(i=0;i<`DCACHE_SIZE_STB;i++)
    begin

      if(ldAddr_i[`SIZE_PC-1:`DCACHE_WORD_BYTE_OFFSET_LOG] == stbAddr[i][`SIZE_PC-1:`DCACHE_WORD_BYTE_OFFSET_LOG])
        stbMatchWordAddr[i] = 1'b1;

      if(ldAddr_i[`DCACHE_WORD_BYTE_OFFSET_LOG-1:0] == stbAddr[i][`DCACHE_WORD_BYTE_OFFSET_LOG-1:0])
        stbMatchByteAddr[i] = 1'b1;

      if(ldSize_i <= stbStSize[i])
        stbMatchSize[i] = 1'b1;

      stbMatch_tmp[i]    = stbMatchWordAddr[i] &  stbMatchByteAddr[i];
      stbMatch_part[i]   = (stbMatchWordAddr[i] & ~stbMatchByteAddr[i]) | (stbMatchWordAddr[i] &  stbMatchByteAddr[i] & ~stbMatchSize[i]);
  
      validVectWrap[i]   = (i < stbHead) | (i > stbTail);
      validVectNoWrap[i] = (i > stbHead) & (i < stbTail);
    end
  
    stbWrapped = 1'b0;
    if(stbTail <= stbHead)
      stbWrapped = 1'b1;
    
    validVect = stbWrapped ? validVectWrap : validVectNoWrap;
    //stbMatch = stbMatch_tmp & validVect;
    stbMatch = stbMatch_tmp & stbValid;
    stbMatchPartial = stbMatch_part & stbValid;
  
    // Priority encoder to find out the latest match
    for(i=0;i<`DCACHE_SIZE_STB;i++)
    begin
      index = stbHead + i; // Begin looking from the STB head onwards
      if(index >= `DCACHE_SIZE_STB) // Wrap the index if bigger than SIZE_STB
        index = index - `DCACHE_SIZE_STB;
  
      if(stbMatch[index])
      begin
        stbHit = 1'b1;
        latestMatch = index;
      end

      if(stbMatchPartial[index])
      begin
        stbPartialHit = 1'b1;
        latestPartialMatch = index;
      end
    end
  
  end
  
  always_ff@ (posedge clk)
  begin
  if(reset)
    stbHitCount = 1'b0; //Default
  else if(stbHit&ldEn_i)
    stbHitCount = stbHitCount + 1;
  end   
  ////////////////////////////////////////////////////////////
  
  
  assign ldData = stbHit ? stbData[latestMatch] : ld_cache_data[ld_offset*`SIZE_DATA +: `SIZE_DATA];
  
  /* Cache data and tag arrays */
  reg [`DCACHE_BITS_IN_LINE-1:0]                      data_array [`DCACHE_NUM_LINES-1:0];
  reg [`DCACHE_TAG_BITS-1:0]                          tag_array [`DCACHE_NUM_LINES-1:0];
  reg [`DCACHE_NUM_LINES-1:0]                         valid_array;
  
  
  always_comb
  begin
    ld_cache_data  = data_array[ld_index];
    ld_cache_tag   = tag_array[ld_index];
    ld_cache_valid = valid_array[ld_index];
  end
  
  always_comb
  begin
    // If hit in store buffer, ignore the cache array hit as STB has latest value.
    // If hit in store buffer, it is a miss if the sizes are not compatible.
    ldHit = 1'b0;
    // NOTE: SCRATCH MODE
    if(dcScratchModeEn_d1)
      ldHit = ldEn_i;
    else
    begin
      if(stbHit)
        ldHit = (ldSize_i <= stbStSize[latestMatch]) & ldEn_i;  // Must indicate ldHit only when there's a valid ldEn
      else
        ldHit = (ld_cache_tag == ld_tag) & ld_cache_valid & ldEn_i; 
    end
  end
  
  
  always_ff @(posedge clk)
  begin
    // No need to update to a line that is being replaced 
    // by a fill.
    if(stHit & ~((stbHeadIndex == fillIndex) & fillValid))
    begin
      data_array[stbHeadIndex]  <=  stbUpdateData;
    end

    // Fill to the same line gets priority over store update
    // as the block being stored to is being overwritten anyway.
    if(fillValid)
    begin
      data_array[fillIndex]   <=  fillData;
      tag_array[fillIndex]    <=  fillTag;
    end
    // Load scratch pad from outside
    else if(dcScratchWrEn_d1 & dcScratchModeEn_d1)
    begin
      data_array[dcScratchWrIndex_d1][(dcScratchWrByte_d1*8) +: 8]  <= dcScratchWrData_d1; 
    end
  end
  
  // Reading the bytes through the SCRATCH interface
  assign dcScratchRdData_o  = data_array[dcScratchWrIndex_d1][(dcScratchWrByte_d1*8) +: 8];


  always_ff @(posedge clk or posedge reset)
  begin
    int i;
    if(reset)
    begin
      for(i = 0; i < `DCACHE_NUM_LINES;i++)
        valid_array[i] <= 1'b0;
    end
    else
      if(dcFlush_i)
      begin
        for(i = 0; i < `DCACHE_NUM_LINES;i++)
          valid_array[i] <= 1'b0;
      end
      else
      begin
        if(fillValid)
          valid_array[fillIndex] <= 1'b1;
      end
  end

  always_ff @(posedge clk)
  begin
    dcFlushDone_o <= dcFlush_i;
  end

  /*Store updating cache line*/

  // NOTE: SCRATCH MODE
  // If in scratch mode, store data is written in the same cycle.
  assign stbHeadOffset                = dcScratchModeEn_d1 ? st_offset : stbAddr[stbHead][`DCACHE_OFFSET_BITS+`DCACHE_WORD_BYTE_OFFSET_LOG-1 : `DCACHE_WORD_BYTE_OFFSET_LOG];
  assign stbHeadIndex                 = dcScratchModeEn_d1 ? st_index  : stbAddr[stbHead][`DCACHE_OFFSET_BITS+`DCACHE_INDEX_BITS+`DCACHE_WORD_BYTE_OFFSET_LOG-1 : `DCACHE_OFFSET_BITS+`DCACHE_WORD_BYTE_OFFSET_LOG];
  assign stbHeadTag                   = dcScratchModeEn_d1 ? st_tag    : stbAddr[stbHead][`SIZE_PC-1 : `DCACHE_OFFSET_BITS+`DCACHE_INDEX_BITS+`DCACHE_WORD_BYTE_OFFSET_LOG];
  assign stbHeadByteEn                = dcScratchModeEn_d1 ? stByteEn  : stbByteEn[stbHead];
  assign stbHeadData                  = dcScratchModeEn_d1 ? stData    : stbData[stbHead];

  always_comb
  begin
    st_cache_data  = data_array[stbHeadIndex];
    st_cache_tag   = tag_array[stbHeadIndex];
    st_cache_valid = valid_array[stbHeadIndex];
  end
  
  // NOTE: SCRATCH MODE
  // If in scratch mode, store hits whenever there is a store to be done.
  assign stHit = dcScratchModeEn_d1 ? stEn_i : (((st_cache_tag == stbHeadTag) & st_cache_valid) & mem2dcStComplete_d1);
 
  always_comb
  begin
      int i,j;
      stbUpdateData = st_cache_data;
      
      // Merge received data with the latest store data byte by byte
      for(i=0;i<`DCACHE_WORDS_IN_LINE;i++)
        if(i == stbHeadOffset)
        begin
          for(j=0;j<`SIZE_DATA_BYTE;j++)
            if(stbHeadByteEn[j])
              stbUpdateData[(i*`SIZE_DATA_BYTE+j)*8 +: 8]  = stbHeadData[j*8 +:8];
        end
  end

`endif

endmodule
