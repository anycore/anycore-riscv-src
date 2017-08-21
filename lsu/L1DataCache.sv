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


module L1DataCache(
	input                               clk,
	input                               reset,
	input                               recoverFlag_i,
	input                               rdEn_i,

`ifdef SCRATCH_PAD  
  input                               dataScratchPadEn_i,
`endif  

`ifdef DATA_CACHE
  input                               dataCacheBypass_i,
  input                               dcScratchModeEn_i,

  // cache-to-memory interface for Loads
  output [`DCACHE_BLOCK_ADDR_BITS-1:0]  dc2memLdAddr_o,  // memory read address
  output reg                          dc2memLdValid_o, // memory read enable

  // memory-to-cache interface for Loads
  input  [`DCACHE_TAG_BITS-1:0]       mem2dcLdTag_i,       // tag of the incoming datadetermine
  input  [`DCACHE_INDEX_BITS-1:0]     mem2dcLdIndex_i,     // index of the incoming data
  input  [`DCACHE_BITS_IN_LINE-1:0]      mem2dcLdData_i,      // requested data
  input                               mem2dcLdValid_i,     // indicates the requested data is ready

  // cache-to-memory interface for stores
  output [`DCACHE_ST_ADDR_BITS-1:0]   dc2memStAddr_o,  // memory read address
  output [`SIZE_DATA-1:0]             dc2memStData_o,  // memory read address
  output [`SIZE_DATA_BYTE-1:0]        dc2memStByteEn_o,  // memory read address
  output reg                          dc2memStValid_o, // memory read enable

  // memory-to-cache interface for stores
  input                               mem2dcStComplete_i,
  input                               mem2dcStStall_i,

  output                              stallStCommit_o,

  input [`DCACHE_INDEX_BITS+`DCACHE_BYTES_IN_LINE_LOG-1:0]  dcScratchWrAddr_i,
  input                                                     dcScratchWrEn_i,
  input [7:0]                                               dcScratchWrData_i,
  output [7:0]                                              dcScratchRdData_o,

  input                               dcFlush_i,
  output                              dcFlushDone_o,
`endif

  output                              ldMiss_o,
  output                              stMiss_o,

	input   [`SIZE_VIRT_ADDR-1:0]     rdAddr_i,
	input   [`LDST_TYPES_LOG-1:0]       ldSize_i,
	input                               ldSign_i,

	input                               wrEn_i,
	input   [`SIZE_VIRT_ADDR-1:0]     wrAddr_i,
	input   [`SIZE_DATA-1:0]            wrData_i,
	input   [`LDST_TYPES_LOG-1:0]       stSize_i,

	output                              rdHit_o,
	output  [`SIZE_DATA-1:0]            rdData_o,
	output                              wrHit_o,

	/* To memory */
	output  [`SIZE_PC-1:0]              ldAddr_o,
	input   [`SIZE_DATA-1:0]            ldData_i,
  input                               ldDataValid_i,
	output                              ldEn_o,

`ifdef SCRATCH_PAD
  input  [`DEBUG_DATA_RAM_LOG+`DEBUG_DATA_RAM_WIDTH_LOG-1:0]  dataScratchAddr_i ,
  input  [7:0]                        dataScratchWrData_i ,
  input                               dataScratchWrEn_i   ,
  output [7:0]                        dataScratchRdData_o ,
`endif

	output  [`SIZE_PC-1:0]              stAddr_o,
	output  [`SIZE_DATA-1:0]            stData_o,
	output  [7:0]                       stEn_o,  // LOG_SIZE_DATA - 1 = 7

	output  [1:0]                       ldStSize_o
);


reg  [`SIZE_DATA-1:0]                  rdData;

reg  [`SIZE_DATA-1:0]                  stData;
reg  [7:0]                             stEn; // LOG_SIZE_DATA - 1 = 7


  
`ifdef DATA_CACHE

  logic  [`SIZE_DATA-1:0]                  rdDataCache;
  logic   rdHitCache;
  logic   wrHitCache;

  DCache_controller dcache (

    .clk(clk),
    .reset(reset),      
    .dcScratchModeEn_i(dcScratchModeEn_i),
    
    .ldEn_i(rdEn_i),
    .ldAddr_i(rdAddr_i),
    .ldSize_i(ldSize_i),
    .ldSign_i(ldSign_i),
    .ldData_o(rdDataCache),
    .ldHit_o(rdHitCache),
    .ldDataValid_o(),
    
    .stEn_i(wrEn_i),
    .stAddr_i(wrAddr_i),
    .stSize_i(stSize_i),
    .stData_i(wrData_i), 
    //.stByteEn_i(stEn), 
    .stHit_o(wrHitCache),
    
    .ldMiss_o(ldMiss_o),
    .stMiss_o(stMiss_o),

    .dc2memLdAddr_o    (dc2memLdAddr_o     ), // memory read address
    .dc2memLdValid_o   (dc2memLdValid_o    ), // memory read enable
                                          
    .mem2dcLdTag_i     (mem2dcLdTag_i      ), // tag of the incoming datadetermine
    .mem2dcLdIndex_i   (mem2dcLdIndex_i    ), // index of the incoming data
    .mem2dcLdData_i    (mem2dcLdData_i     ), // requested data
    .mem2dcLdValid_i   (mem2dcLdValid_i    ), // indicates the requested data is ready
                                          
    .dc2memStAddr_o    (dc2memStAddr_o     ), // memory read address
    .dc2memStData_o    (dc2memStData_o     ), // memory read address
    .dc2memStByteEn_o  (dc2memStByteEn_o   ), // memory read address
    .dc2memStValid_o   (dc2memStValid_o    ), // memory read enable
                                          
    .mem2dcStComplete_i(mem2dcStComplete_i ),
    .mem2dcStStall_i   (mem2dcStStall_i ),
    

    .dcScratchWrAddr_i (dcScratchWrAddr_i),
    .dcScratchWrEn_i   (dcScratchWrEn_i  ),
    .dcScratchWrData_i (dcScratchWrData_i),
    .dcScratchRdData_o (dcScratchRdData_o),

    .dcFlush_i         (dcFlush_i),
    .dcFlushDone_o     (dcFlushDone_o),

    .stallStCommit_o   (stallStCommit_o)

  );

    // When Scratch Pad is enabled, it is the default source and destination
    assign rdData_o                      = dataCacheBypass_i ? rdData : rdDataCache ;

    /* To memory */
    assign ldEn_o                        = rdEn_i & dataCacheBypass_i;
    assign stEn_o                        = stEn & {8{dataCacheBypass_i}};
    
    /* Back to pipeline */
    assign rdHit_o                       = dataCacheBypass_i ? 1'b1 : rdHitCache;
    assign wrHit_o                       = dataCacheBypass_i ? 1'b1 : wrHitCache;

`else

    /* To memory */
    assign rdData_o                      = rdData;
    assign ldEn_o                        = rdEn_i;
    assign stEn_o                        = stEn;
  
    /* Back to pipeline */
    assign rdHit_o                       = 1'h1;
    assign wrHit_o                       = 1'h1;
`endif



/* The following code is used in multiple modes and hence is not gated by any `ifdef
   This section rotates and aligns the data according to the type of access used*/

/* To memory */
assign ldAddr_o                      = {1'h0, rdAddr_i[63:3], 3'h0};

assign stAddr_o                      = {1'h0, wrAddr_i[63:3], 3'h0};
assign stData_o                      = stData;


/*  Following calls DPI related to load and store interfaces with functional
 *  simulator. */
//  Following load data is used only when both D-Cache and D-Scratch are disabled.

always_comb
begin:MEM_ACCESS

	rdData            = 0;

	stData            = 0;
	stEn              = 0;

	if (rdEn_i)
	begin
		case (ldSize_i)
			`LDST_BYTE:
			begin

				rdData = (ldData_i >> {rdAddr_i[2:0], 3'h0}) & 64'h0000_0000_0000_00FF;
        // Sign extend appropriately if load is signed
        if(ldSign_i)
          rdData = {{56{rdData[7]}},rdData[7:0]};
			end

			`LDST_HALF_WORD:
			begin
				rdData = (ldData_i >> {rdAddr_i[2:1], 4'h0}) & 64'h0000_0000_0000_FFFF;
        // Sign extend appropriately if load is signed
        if(ldSign_i)
          rdData = {{48{rdData[15]}},rdData[15:0]};
			end

			`LDST_WORD:
			begin
				rdData = (ldData_i >> {rdAddr_i[2], 5'h0}) & 64'h0000_0000_FFFF_FFFF;
        // Sign extend appropriately if load is signed
        if(ldSign_i)
          rdData = {{32{rdData[31]}},rdData[31:0]};
			end
      
			`LDST_DOUBLE_WORD:
			begin
				rdData = ldData_i;
			end
      
      // RBRC: Added default to avoid synthesis smulation mismatch
      default:
      begin
        rdData = 64'hbaadbeefdeadbeef;
      end
		endcase
	end


	if (wrEn_i)
	begin
		case (stSize_i)

			`LDST_BYTE:
			begin
				/* Shift the least-significant byte to the correct byte offset */
				stData = wrData_i << {wrAddr_i[2:0], 3'h0}; //TODO modify code like in LDST_WORD case, easier to read and understand
				stEn   = 8'h1 << wrAddr_i[2:0];
			end

			`LDST_HALF_WORD:
			begin
				stData = wrData_i << {wrAddr_i[2:1], 4'h0};
				stEn   = 8'h3 << {wrAddr_i[2:1], 1'h0};
			end

			`LDST_WORD:
			begin
				stData = wrAddr_i[2] ? {wrData_i[31:0],32'b0} : {32'b0,wrData_i[31:0]};
				stEn   = wrAddr_i[2] ? 8'hF0 : 8'h0F;
			end

			`LDST_DOUBLE_WORD:
			begin
				stData = wrData_i;
				stEn   = 8'hFF;
			end

      // RBRC: Added default to avoid synthesis smulation mismatch
      default:
      begin
        stData = 32'hdeadbeef;
        stEn   = 4'h0;
      end
		endcase
	end
end


endmodule
