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

module SpecFreeList(
	input                             clk,
	input                             reset,
	input                             resetRams_i,

`ifdef DYNAMIC_CONFIG  
  input [`COMMIT_WIDTH-1:0]         commitLaneActive_i,
  input [`DISPATCH_WIDTH-1:0]       dispatchLaneActive_i,
  input [`NUM_PARTS_FL-1:0]         flPartitionActive_i,
//  input                             reconfigureCore_i,
`endif  

	input                             stall_i,

	input                             recoverFlag_i,

	input                             reqPhyReg_i [0:`DISPATCH_WIDTH-1],

	input  phys_reg                   freedPhyReg_i [0:`COMMIT_WIDTH-1],

	output reg [`SIZE_PHYSICAL_LOG-1:0] freePhyReg_o [0:`DISPATCH_WIDTH-1],

`ifdef PERF_MON
	output [`SIZE_FREE_LIST_LOG-1:0]  freeListCnt_o,
`endif

	output reg                        freeListEmpty_o,
  output                            flRamReady_o

	);

reg  [`SIZE_FREE_LIST_LOG-1:0]          freeListHead;
reg  [`SIZE_FREE_LIST_LOG-1:0]          freeListTail;
reg  [`SIZE_FREE_LIST_LOG-1:0]          freeListCnt; // RBRC: Count never equals 2^^SIZE_FREE_LIST_LOG

wire [`COMMIT_WIDTH-1:0]                commitValid;

reg  [3:0]                              popNumber;
reg  [3:0]                              pushNumber;

reg  [`SIZE_FREE_LIST_LOG:0]            freeListCnt_t1;
reg  [`SIZE_FREE_LIST_LOG:0]            freeListCnt_t2;
reg  [`SIZE_FREE_LIST_LOG-1:0]          freeListHead_t;
reg  [`SIZE_FREE_LIST_LOG-1:0]          freeListTail_t;

reg  [`SIZE_FREE_LIST_LOG-1:0]          readAddr        [0:`DISPATCH_WIDTH-1];

wire [`SIZE_PHYSICAL_LOG-1:0]           freePhyReg   [0:`DISPATCH_WIDTH-1];

reg  [`SIZE_FREE_LIST_LOG-1:0]          writeAddr [0:`COMMIT_WIDTH-1];

reg  [`COMMIT_WIDTH-1:0]                writeEn;
reg  [`SIZE_FREE_LIST_LOG-1:0]          addrWr    [0:`COMMIT_WIDTH-1];
reg  [`SIZE_PHYSICAL_LOG-1:0]           dataWr    [0:`COMMIT_WIDTH-1];

reg  [`SIZE_FREE_LIST_LOG-1:0]          readAddrGated   [0:`DISPATCH_WIDTH-1];
reg  [`COMMIT_WIDTH-1:0]                writeEnGated;
reg  [`SIZE_FREE_LIST_LOG-1:0]          addrWrGated     [0:`COMMIT_WIDTH-1];


//// BIST State Machine to Initialize RAM/CAM /////////////

localparam BIST_SIZE_ADDR   = `SIZE_FREE_LIST_LOG;
localparam BIST_SIZE_DATA   = `SIZE_PHYSICAL_LOG;
localparam BIST_NUM_ENTRIES = `SIZE_FREE_LIST;
localparam BIST_RESET_MODE  = 1; //0 -> Fixed value; 1 -> Sequential values
localparam BIST_RESET_VALUE = `SIZE_RMT; // Initialize all entries to this value if RESET_MODE = 0; starting from this value if RESET_MODE = 1

localparam BIST_START = 0;
localparam BIST_RUN   = 1;
localparam BIST_DONE  = 2;

logic                       bistEn;
logic [1:0]                 bistState;
logic [1:0]                 bistNextState;
logic [BIST_SIZE_ADDR-1:0]  bistAddrWr;
logic [BIST_SIZE_ADDR-1:0]  bistNextAddrWr;
logic [BIST_SIZE_DATA-1:0]  bistDataWr;
logic [BIST_SIZE_DATA-1:0]  bistNextDataWr;

assign flRamReady_o = ~bistEn;

always_ff @(posedge clk or posedge resetRams_i)
begin
  if(resetRams_i)
  begin
    bistState       <= BIST_START;
    bistAddrWr      <= 0;
    bistDataWr      <= BIST_RESET_VALUE;
  end
  else
  begin
    bistState       <= bistNextState;
    bistAddrWr      <= bistNextAddrWr;
    bistDataWr      <= bistNextDataWr;
  end
end

always_comb
begin
  bistEn              = 1'b0;
  bistNextState       = bistState;
  bistNextAddrWr      = bistAddrWr;
  bistNextDataWr      = bistDataWr;

  case(bistState)
    BIST_START: begin
      bistNextState   = BIST_RUN;
      bistNextAddrWr  = 0;
    end
    BIST_RUN: begin
      bistEn = 1'b1;
      bistNextAddrWr  = bistAddrWr + 1'b1;
      bistNextDataWr  = (BIST_RESET_MODE == 0) ? bistDataWr : bistDataWr + 1'b1;

      if(bistAddrWr == BIST_NUM_ENTRIES-1)
      begin
        bistNextState = BIST_DONE;
      end
      else
      begin
        bistNextState = BIST_RUN;
      end
    end
    BIST_DONE: begin
      bistNextAddrWr  = 0;
      bistNextDataWr  = BIST_RESET_VALUE;
      bistNextState   = BIST_DONE;
    end
  endcase
end

//////////////////////////////////////////////////////////

`ifdef DYNAMIC_CONFIG
FREELIST_RAM_PARTITIONED #(
`else
FREELIST_RAM #(
`endif
  .RPORT      (`DISPATCH_WIDTH),
  .WPORT      (`COMMIT_WIDTH),
	.DEPTH      (`SIZE_FREE_LIST),
	.INDEX      (`SIZE_FREE_LIST_LOG),
	.WIDTH      (`SIZE_PHYSICAL_LOG)
	)

	freeList (

	.addr0_i    (readAddrGated[0]),
	.data0_o    (freePhyReg[0]),

`ifdef DISPATCH_TWO_WIDE
	.addr1_i    (readAddrGated[1]),
	.data1_o    (freePhyReg[1]),
`endif

`ifdef DISPATCH_THREE_WIDE
	.addr2_i    (readAddrGated[2]),
	.data2_o    (freePhyReg[2]),
`endif

`ifdef DISPATCH_FOUR_WIDE
	.addr3_i    (readAddrGated[3]),
	.data3_o    (freePhyReg[3]),
`endif

`ifdef DISPATCH_FIVE_WIDE
	.addr4_i    (readAddrGated[4]),
	.data4_o    (freePhyReg[4]),
`endif

`ifdef DISPATCH_SIX_WIDE
	.addr5_i    (readAddrGated[5]),
	.data5_o    (freePhyReg[5]),
`endif

`ifdef DISPATCH_SEVEN_WIDE
	.addr6_i    (readAddrGated[6]),
	.data6_o    (freePhyReg[6]),
`endif

`ifdef DISPATCH_EIGHT_WIDE
	.addr7_i    (readAddrGated[7]),
	.data7_o    (freePhyReg[7]),
`endif


	.we0_i      (bistEn ? 1'b1       : writeEnGated[0]),
	.addr0wr_i  (bistEn ? bistAddrWr : addrWrGated[0]),
	.data0wr_i  (bistEn ? bistDataWr : dataWr[0]),

`ifdef COMMIT_TWO_WIDE
	.we1_i      (writeEnGated[1]),
	.addr1wr_i  (addrWrGated[1]),
	.data1wr_i  (dataWr[1]),
`endif

`ifdef COMMIT_THREE_WIDE
	.we2_i      (writeEnGated[2]),
	.addr2wr_i  (addrWrGated[2]),
	.data2wr_i  (dataWr[2]),
`endif

`ifdef COMMIT_FOUR_WIDE
	.we3_i      (writeEnGated[3]),
	.addr3wr_i  (addrWrGated[3]),
	.data3wr_i  (dataWr[3]),
`endif

`ifdef DYNAMIC_CONFIG  
  .commitLaneActive_i (commitLaneActive_i),
  .dispatchLaneActive_i (dispatchLaneActive_i),
  .flPartitionActive_i (flPartitionActive_i),
 // .freeListReady_o (freeListReady_o),
`endif

	.clk        (clk)
	//.reset      (reset)


	);

reg [`DISPATCH_WIDTH_LOG:0] numDispatchLaneActive;
reg  [`SIZE_FREE_LIST_LOG:0]       freeListSize;
always_comb
begin
`ifdef DYNAMIC_CONFIG  

  int i;
  numDispatchLaneActive = 0;

  for(i = 0; i < `DISPATCH_WIDTH; i++)
    numDispatchLaneActive = numDispatchLaneActive + dispatchLaneActive_i[i];

  case(flPartitionActive_i)
    6'b111111:freeListSize =  `SIZE_FREE_LIST;
    6'b011111:freeListSize =  `SIZE_FREE_LIST - ((`SIZE_FREE_LIST/`NUM_PARTS_FL)*1);
    6'b001111:freeListSize =  `SIZE_FREE_LIST - ((`SIZE_FREE_LIST/`NUM_PARTS_FL)*2); 
    6'b000111:freeListSize =  `SIZE_FREE_LIST - ((`SIZE_FREE_LIST/`NUM_PARTS_FL)*3); 
    6'b000011:freeListSize =  `SIZE_FREE_LIST - ((`SIZE_FREE_LIST/`NUM_PARTS_FL)*4); 
    6'b000001:freeListSize =  `SIZE_FREE_LIST - ((`SIZE_FREE_LIST/`NUM_PARTS_FL)*5); 
    default:  freeListSize =  `SIZE_FREE_LIST;
  endcase

`else
  numDispatchLaneActive = `DISPATCH_WIDTH;
  freeListSize = `SIZE_FREE_LIST;
`endif
end

always_comb
begin
	int i;

	if (~freeListEmpty_o)
	begin
		for (i = 0; i < `DISPATCH_WIDTH; i++)
		begin
			freePhyReg_o[i]   = freePhyReg[i];
		end
	end
	
	else
	begin
		for (i = 0; i < `DISPATCH_WIDTH; i++)
		begin
			freePhyReg_o[i]   = 0;
		end
	end
end


/* Wrapping head and tail pointers */
/* TODO: find best style for synthesis */
always_comb
begin : FREE_LIST_READ_ADDR
	int i;
	reg [`SIZE_FREE_LIST_LOG:0]  readAddr_f  [1:`DISPATCH_WIDTH-1];

	readAddr[0]   = freeListHead;

	for (i = 1; i < `DISPATCH_WIDTH; i = i + 1)
	begin

		readAddr_f[i]   = freeListHead + i;

    // freeListSize is constant in case of fixed config
		if(readAddr_f[i] >= freeListSize)
		begin
			readAddr[i] = readAddr_f[i] - freeListSize;
		end

		else
		begin
			readAddr[i] = readAddr_f[i];
		end

	end
end


`ifdef DYNAMIC_CONFIG
  genvar rd;
  generate
	  for (rd = 0; rd < `DISPATCH_WIDTH; rd = rd + 1)
	  begin:CLAMP_RD
        PGIsolationCell #(
          .WIDTH(`SIZE_FREE_LIST_LOG)
        ) rdAddrClamp
        (
          .clampEn(~dispatchLaneActive_i[rd]),
          .signalIn(readAddr[rd]),
          .signalOut(readAddrGated[rd]),
          .clampValue({`SIZE_FREE_LIST_LOG{1'b0}})
        );
    end
  endgenerate
`else
  always_comb
  begin
    int rd;
	  for (rd = 0; rd < `DISPATCH_WIDTH; rd = rd + 1)
	  begin
      readAddrGated[rd]   = readAddr[rd]  ;
    end
  end
`endif

always_comb
begin : FREE_LIST_WRITE_ADDR
	int i;
	reg [`SIZE_FREE_LIST_LOG:0]  writeAddr_f [1:`COMMIT_WIDTH-1];

	writeAddr[0]  = freeListTail;

	for (i = 1; i < `COMMIT_WIDTH; i = i + 1)
	begin

		writeAddr_f[i]   = freeListTail + i;

    // freeListSize is constant in case of fixed config
		if(writeAddr_f[i] >= freeListSize)
		begin
			writeAddr[i] = writeAddr_f[i] - freeListSize;
		end

		else
		begin
			writeAddr[i] = writeAddr_f[i];
		end
	end

end

// RBRC: Changed to numDispatchLaneActive as this was a source of IPC difference
// Was < `DISPATCH_WIDTH
always_comb
begin
  freeListEmpty_o    =  (freeListCnt >= {{(`SIZE_FREE_LIST_LOG-`DISPATCH_WIDTH_LOG-1){1'b0}},numDispatchLaneActive}) ? 0:1;
  //freeListEmpty_o    =  (freeListCnt < `DISPATCH_WIDTH) ? 1:0;
end

assign commitValid[0]     = freedPhyReg_i[0].valid;

`ifdef COMMIT_TWO_WIDE
assign commitValid[1]     = freedPhyReg_i[1].valid;
`endif

`ifdef COMMIT_THREE_WIDE
assign commitValid[2]     = freedPhyReg_i[2].valid;
`endif

`ifdef COMMIT_FOUR_WIDE
assign commitValid[3]     = freedPhyReg_i[3].valid;
`endif

always_comb
begin : UPDATE_HEAD_TAIL_COUNT
	int i;
	reg [`SIZE_FREE_LIST_LOG:0]  freelisthead;
	reg [`SIZE_FREE_LIST_LOG:0]  freelisttail;

	popNumber             = 0;

  // In case of dynamic reconfiguration, the 
  // corresponding reqPhyReq_i will be masked
  // off in the rename module.
	for (i = 0; i < `DISPATCH_WIDTH; i++)
	begin
		popNumber           = popNumber + reqPhyReg_i[i];
	end

	pushNumber            = 0;

	for (i = 0; i < `COMMIT_WIDTH; i++)
	begin
		pushNumber          = pushNumber + freedPhyReg_i[i].valid;
	end

	/* if (~freeListEmpty_o) */
	freeListCnt_t1        = freeListCnt + pushNumber;

	/* else */
	freeListCnt_t2        = freeListCnt_t1 - popNumber;

	freelisthead          = freeListHead + popNumber;

  // freeListSize is constant in case of fixed config
	if(freelisthead >= freeListSize)
		freeListHead_t      = freelisthead - freeListSize;
	else
		freeListHead_t      = freelisthead;

	freelisttail          = freeListTail + pushNumber;

	if(freelisttail >= freeListSize)
		freeListTail_t      = freelisttail - freeListSize;
	else
		freeListTail_t      = freelisttail;
end


always_ff @(posedge clk or posedge reset)
begin
	if (reset)
	begin
    // freeListSize is constant in case of fixed config
		freeListCnt     <= freeListSize;
		freeListHead    <= 0;
	end

//`ifdef DYNAMIC_CONFIG  
//	else if(recoverFlag_i | reconfigureCore_i)
//`else    
	else if(recoverFlag_i)
//`endif
	begin
		freeListCnt     <= freeListSize;
		freeListHead    <= freeListTail;
	end

	else
	begin
		if (stall_i | freeListEmpty_o)
		begin
			freeListHead  <=  freeListHead;
			freeListCnt   <=  freeListCnt_t1;
		end

		else
		begin
			freeListHead  <=  freeListHead_t;
			freeListCnt   <=  freeListCnt_t2;
		end
	end
end


always_comb
begin : CALCULATE_WRITE_ADDR
	int i;

	for (i = 0; i < `COMMIT_WIDTH; i = i + 1)
	begin
		writeEn[i] = 0;
		addrWr[i]  = writeAddr[i];
		dataWr[i]  = 0;
	end

	case ({{4-`COMMIT_WIDTH{1'b0}},commitValid})
    4'h0:
    begin
    end

		4'h1:
		begin
			writeEn    = 4'b0001;
			dataWr[0]  = freedPhyReg_i[0].reg_id;
		end

`ifdef COMMIT_TWO_WIDE
		4'h2:
		begin
			writeEn     = 4'b0001;
			dataWr[0]   =  freedPhyReg_i[1].reg_id;
		end

		4'h3:
		begin
			writeEn     = 4'b0011;
			dataWr[0]   =  freedPhyReg_i[0].reg_id;

			dataWr[1]   =  freedPhyReg_i[1].reg_id;
		end
`endif

`ifdef COMMIT_THREE_WIDE
		4'h4:
		begin
			writeEn     = 4'b0001;
			dataWr[0]   =  freedPhyReg_i[2].reg_id;
		end

		4'h5:
		begin
			writeEn     = 4'b0011;
			dataWr[0]   =  freedPhyReg_i[0].reg_id;

			dataWr[1]   =  freedPhyReg_i[2].reg_id;
		end

		4'h6:
		begin
			writeEn     = 4'b0011;
			dataWr[0]   =  freedPhyReg_i[1].reg_id;

			dataWr[1]   =  freedPhyReg_i[2].reg_id;
		end

		4'h7:
		begin
			writeEn     = 4'b0111;
			dataWr[0]   =  freedPhyReg_i[0].reg_id;

			dataWr[1]   =  freedPhyReg_i[1].reg_id;

			dataWr[2]   =  freedPhyReg_i[2].reg_id;
		end
`endif

`ifdef COMMIT_FOUR_WIDE
		4'h8:
		begin
			writeEn     = 4'b0001;
			dataWr[0]   =  freedPhyReg_i[3].reg_id;
		end

		4'h9:
		begin
			writeEn     = 4'b0011;
			dataWr[0]   =  freedPhyReg_i[0].reg_id;

			dataWr[1]   =  freedPhyReg_i[3].reg_id;
		end

		4'hA:
		begin
			writeEn     = 4'b0011;
			dataWr[0]   =  freedPhyReg_i[1].reg_id;

			dataWr[1]   =  freedPhyReg_i[3].reg_id;
		end

		4'hB:
		begin
			writeEn     = 4'b0111;
			dataWr[0]   =  freedPhyReg_i[0].reg_id;

			dataWr[1]   =  freedPhyReg_i[1].reg_id;

			dataWr[2]   =  freedPhyReg_i[3].reg_id;
		end

		4'hC:
		begin
			writeEn     = 4'b0011;
			dataWr[0]   =  freedPhyReg_i[2].reg_id;

			dataWr[1]   =  freedPhyReg_i[3].reg_id;
		end

		4'hD:
		begin
			writeEn     = 4'b0111;
			dataWr[0]   =  freedPhyReg_i[0].reg_id;

			dataWr[1]   =  freedPhyReg_i[2].reg_id;

			dataWr[2]   =  freedPhyReg_i[3].reg_id;
		end

		4'hE:
		begin
			writeEn     = 4'b0111;
			dataWr[0]   =  freedPhyReg_i[1].reg_id;

			dataWr[1]   =  freedPhyReg_i[2].reg_id;

			dataWr[2]   =  freedPhyReg_i[3].reg_id;
		end

		4'hF:
		begin
			writeEn     = 4'b1111;
			dataWr[0]   =  freedPhyReg_i[0].reg_id;

			dataWr[1]   =  freedPhyReg_i[1].reg_id;

			dataWr[2]   =  freedPhyReg_i[2].reg_id;

			dataWr[3]   =  freedPhyReg_i[3].reg_id;
		end
`endif
    default:
    begin
    end

	endcase
end

`ifdef DYNAMIC_CONFIG
  genvar wr;
  generate
	  for (wr = 0; wr < `COMMIT_WIDTH; wr = wr + 1)
	  begin:CLAMP_WR
        PGIsolationCell #(
          .WIDTH(`SIZE_FREE_LIST_LOG+1)
        ) wrAddrClamp
        (
          .clampEn(~commitLaneActive_i[wr]),
          .signalIn({addrWr[wr],writeEn[wr]}),
          .signalOut({addrWrGated[wr],writeEnGated[wr]}),
          .clampValue({(`SIZE_FREE_LIST_LOG+1){1'b0}})
        );
    end
  endgenerate
`else
  always_comb
  begin
    int wr;
	  for (wr = 0; wr < `COMMIT_WIDTH; wr = wr + 1)
	  begin
      addrWrGated[wr]   = addrWr[wr]  ;
      writeEnGated[wr]  = writeEn[wr] ;
    end
  end
`endif


always_ff @(posedge clk or posedge reset)
begin
	if (reset)
	begin
		freeListTail    <= 0;
	end

	else
	begin
		freeListTail    <= freeListTail_t;
	end
end
`ifdef PERF_MON
assign freeListCnt_o = freeListCnt ;
`endif
endmodule
