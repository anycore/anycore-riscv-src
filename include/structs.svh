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

`ifndef STRUCTS_SVH
`define STRUCTS_SVH

`ifdef DYNAMIC_CONFIG

  typedef struct packed {
  	logic [`FETCH_WIDTH_LOG+`SIZE_PC-`SIZE_BTB_LOG-4:0]    tag;
  	logic [`SIZE_PC-1:0]                  takenPC;
  	logic [`BRANCH_TYPE_LOG-1:0]          ctrlType;
  	logic                                 valid;
  } btbDataPkt;
  `define SIZE_BTB_DATA (`FETCH_WIDTH_LOG+`SIZE_PC-`SIZE_BTB_LOG-3)+`SIZE_PC+`BRANCH_TYPE_LOG+1

`else

  typedef struct packed {
  	logic [`SIZE_PC-`SIZE_BTB_LOG-4:0]    tag;
  	logic [`SIZE_PC-1:0]                  takenPC;
  	logic [`BRANCH_TYPE_LOG-1:0]          ctrlType;
  	logic                                 valid;
  } btbDataPkt;
  `define SIZE_BTB_DATA (`SIZE_PC-`SIZE_BTB_LOG-3)+`SIZE_PC+`BRANCH_TYPE_LOG+1

`endif



typedef struct packed {
	logic                                 hit;
	logic [`SIZE_PC-1:0]                  takenPC;
	logic [`BRANCH_TYPE_LOG-1:0]          ctrlType;
} btbPkt;

typedef struct packed {
	logic [31:0]                          seqNo;
  logic [`EXCEPTION_CAUSE_LOG-1:0]      exceptionCause;  
  logic                                 exception;  
	logic [`SIZE_PC-1:0]                  pc;
	logic [`SIZE_INSTRUCTION-1:0]         inst;
	logic                                 btbHit;
	logic [`BRANCH_TYPE_LOG-1:0]          ctrlType;
	logic [`SIZE_PC-1:0]                  takenPC;
	logic                                 predDir;
  logic                                 valid;
} fs2Pkt;

`define FS2_PKT_SIZE  (32+`EXCEPTION_CAUSE_LOG+1+`SIZE_PC+`SIZE_INSTRUCTION+1+`BRANCH_TYPE_LOG+`SIZE_PC+1+1)

typedef struct packed {
	logic [31:0]                          seqNo;
  logic [`EXCEPTION_CAUSE_LOG-1:0]      exceptionCause;  
  logic                                 exception;  
	logic [`SIZE_PC-1:0]                  pc;
	logic [`SIZE_INSTRUCTION-1:0]         inst;

	logic [`BRANCH_TYPE_LOG-1:0]          ctrlType;
	logic [`SIZE_PC-1:0]                  predNPC;
	logic                                 predDir;
	logic [`SIZE_CTI_LOG-1:0]             ctiID;

	logic                                 valid;
} decPkt;

`define DEC_PKT_SIZE (32+`EXCEPTION_CAUSE_LOG+1+`SIZE_PC+`SIZE_INSTRUCTION+`BRANCH_TYPE_LOG+`SIZE_PC+1+`SIZE_CTI_LOG+1)

typedef struct packed {
	logic [`SIZE_RMT_LOG-1:0]             reg_id;
	logic                                 valid;
} log_reg;

typedef struct packed {
	logic [`SIZE_PHYSICAL_LOG-1:0]        reg_id;
	logic                                 valid;
} phys_reg;

typedef struct packed {
	logic [31:0]                          seqNo;
	logic [`SIZE_PC-1:0]                  pc;
  logic [`EXCEPTION_CAUSE_LOG-1:0]      exceptionCause;  
  logic                                 exception;  
	logic [`SIZE_INSTRUCTION-1:0]         inst;
	logic [`INST_TYPES_LOG-1:0]          fu;	//Changes: Mohit (Changed from incorrect define ISSUE_WIDTH_LOG to INST_TYPES_LOG )

	logic [`SIZE_RMT_LOG-1:0]             logDest;
	logic                                 logDestValid;

	logic [`SIZE_RMT_LOG-1:0]             logSrc1;
	logic                                 logSrc1Valid;

	logic [`SIZE_RMT_LOG-1:0]             logSrc2;
	logic                                 logSrc2Valid;

	logic [`SIZE_IMMEDIATE-1:0]           immed;
	logic                                 immedValid;

	logic                                 isLoad;
	logic                                 isStore;
	logic [`LDST_TYPES_LOG-1:0]           ldstSize;

	logic                                 isCSR;
	logic                                 isScall;
	logic                                 isSbreak;
	logic                                 isSret;
	logic                                 skipIQ;

	logic [`BRANCH_TYPE_LOG-1:0]          ctrlType;
	logic [`SIZE_CTI_LOG-1:0]             ctiID;
	logic [`SIZE_PC-1:0]                  predNPC;
	logic                                 predDir;

	logic                                 valid;
} renPkt;

`define REN_PKT_SIZE (32+`EXCEPTION_CAUSE_LOG+1+`SIZE_PC+`SIZE_INSTRUCTION+`ISSUE_WIDTH_LOG+3*(`SIZE_RMT_LOG+1)+(`SIZE_IMMEDIATE+1)+1+1+`LDST_TYPES_LOG+5+`BRANCH_TYPE_LOG+`SIZE_CTI_LOG+`SIZE_PC+1+1)

typedef struct packed {
	logic [31:0]                          seqNo;
  logic [`EXCEPTION_CAUSE_LOG-1:0]           exceptionCause;  
  logic                                 exception;  
	logic [`SIZE_PC-1:0]                  pc;
	logic [`SIZE_INSTRUCTION-1:0]         inst;
	logic [`INST_TYPES_LOG-1:0]          fu;	//Changes: Mohit (Changed from incorrect define ISSUE_WIDTH_LOG to INST_TYPES_LOG )

	logic [`SIZE_RMT_LOG-1:0]             logDest;

	logic [`SIZE_PHYSICAL_LOG-1:0]        phyDest;
	logic                                 phyDestValid;

	logic [`SIZE_PHYSICAL_LOG-1:0]        phySrc1;
	logic                                 phySrc1Valid;

	logic [`SIZE_PHYSICAL_LOG-1:0]        phySrc2;
	logic                                 phySrc2Valid;

	logic [`SIZE_IMMEDIATE-1:0]           immed;
	logic                                 immedValid;

	logic                                 isLoad;
	logic                                 isStore;
	logic [`LDST_TYPES_LOG-1:0]           ldstSize;

	logic                                 isCSR;
	logic                                 isScall;
	logic                                 isSbreak;
	logic                                 isSret;
	logic                                 skipIQ;

	logic [`BRANCH_TYPE_LOG-1:0]          ctrlType;
	logic [`SIZE_CTI_LOG-1:0]             ctiID;
	logic [`SIZE_PC-1:0]                  predNPC;
	logic                                 predDir;

  logic                                 valid;
} disPkt;

`define DIS_PKT_SIZE  (32+``EXCEPTION_CAUSE_LOG+1+SIZE_PC+`SIZE_INSTRUCTION+`ISSUE_WIDTH_LOG+`SIZE_RMT_LOG+3*(`SIZE_PHYSICAL_LOG+1)+(`SIZE_IMMEDIATE+1)+1+1`LDST_TYPES_LOG+5+`BRANCH_TYPE_LOG+`SIZE_CTI_LOG+`SIZE_PC+1+1) 

typedef struct packed {
	logic [31:0]                          seqNo;
	logic                                 predLoadVio;

	logic [`SIZE_PC-1:0]                  pc;
	logic [`SIZE_INSTRUCTION-1:0]         inst;
	logic [`ISSUE_WIDTH_LOG-1:0]          fu;

	logic [`SIZE_RMT_LOG-1:0]             logDest;

	logic [`SIZE_PHYSICAL_LOG-1:0]        phyDest;
	logic                                 phyDestValid;

	logic [`SIZE_PHYSICAL_LOG-1:0]        phySrc1;
	logic                                 phySrc1Valid;

	logic [`SIZE_PHYSICAL_LOG-1:0]        phySrc2;
	logic                                 phySrc2Valid;

	logic [`SIZE_IMMEDIATE-1:0]           immed;
	logic                                 immedValid;

	logic [`SIZE_LSQ_LOG-1:0]             lsqID;
	logic [`SIZE_ACTIVELIST_LOG-1:0]      alID;

	logic                                 isLoad;
	logic                                 isStore;
	logic [`LDST_TYPES_LOG-1:0]           ldstSize;

	logic                                 isSimple;
	logic                                 isFP;
	logic                                 isCSR;

	logic [`BRANCH_TYPE_LOG-1:0]          ctrlType;
	logic [`SIZE_CTI_LOG-1:0]             ctiID;
	logic [`SIZE_PC-1:0]                  predNPC;
	logic                                 predDir;

  logic                                 valid;
} iqPkt;

`define IQ_PKT_SIZE  (32+1+`SIZE_PC+`SIZE_INSTRUCTION+`ISSUE_WIDTH_LOG+`SIZE_RMT_LOG+3*(`SIZE_PHYSICAL_LOG+1)+(`SIZE_IMMEDIATE+1)+1`SIZE_LSQ_LOG+`SIZE_ACTIVELIST_LOG+1+1+`LDST_TYPES_LOG+1+`BRANCH_TYPE_LOG+`SIZE_CTI_LOG+`SIZE_PC+1+1) 

typedef struct packed {
	logic [31:0]                          seqNo;
  logic [`EXCEPTION_CAUSE_LOG-1:0]      exceptionCause;  
  logic                                 exception;  
	logic [`SIZE_PC-1:0]                  pc;

	logic [`SIZE_RMT_LOG-1:0]             logDest;

	logic [`SIZE_PHYSICAL_LOG-1:0]        phyDest;
	logic                                 phyDestValid;

	logic                                 isLoad;
	logic                                 isStore;
	logic                                 isCSR;
	logic                                 isScall;
	logic                                 isSbreak;
	logic                                 isSret;
	logic                                 isFP;	//Changes: Mohit(Added isFP flag to alpacket)

  logic                                 valid;
} alPkt;

`define AL_PKT_SIZE (32+`EXCEPTION_CAUSE_LOG+1+`SIZE_PC+`SIZE_RMT_LOG+`SIZE_PHYSICAL_LOG+1+1+1+1+1+1+1+1+1)	//Changes: Mohit(Added isFP flag to alpacket)

typedef struct packed {
	logic [31:0]                          seqNo;
	logic                                 predLoadVio;

	logic                                 isLoad;
	logic                                 isStore;
	logic                                 valid;
} lsqPkt;

typedef struct packed {
	logic [31:0]                          seqNo;
	logic [`SIZE_PC-1:0]                  pc;
	logic [`SIZE_INSTRUCTION-1:0]         inst;

	logic [`SIZE_RMT_LOG-1:0]             logDest;

	logic [`SIZE_PHYSICAL_LOG-1:0]        phyDest;
  logic                                 phyDestValid;

	logic [`SIZE_PHYSICAL_LOG-1:0]        phySrc1;
	logic [`SIZE_PHYSICAL_LOG-1:0]        phySrc2;

	logic [`SIZE_LSQ_LOG-1:0]             lsqID;
	logic [`SIZE_ACTIVELIST_LOG-1:0]      alID;

	logic [`SIZE_IMMEDIATE-1:0]           immed;

	logic [`LDST_TYPES_LOG-1:0]           ldstSize;

	logic                                 isSimple;
	logic                                 isFP;
	logic                                 isCSR;

	logic [`BRANCH_TYPE_LOG-1:0]          ctrlType;
	logic [`SIZE_CTI_LOG-1:0]             ctiID;
	logic [`SIZE_PC-1:0]                  predNPC;
	logic                                 predDir;

	logic                                 valid;
} payloadPkt;

`define PAYLOAD_PKT_SIZE 32+`SIZE_PC+`SIZE_INSTRUCTION+`SIZE_RMT_LOG+1+3*(`SIZE_PHYSICAL_LOG)+`SIZE_LSQ_LOG+`SIZE_ACTIVELIST_LOG+`SIZE_IMMEDIATE+`LDST_TYPES_LOG+1+1+1+`BRANCH_TYPE_LOG+`SIZE_CTI_LOG+`SIZE_PC+1+1


typedef struct packed {
	logic [`SIZE_ISSUEQ_LOG-1:0]          id;
	logic                                 valid;
} iqEntryPkt;


typedef struct packed {
	logic [31:0]                          seqNo;
	logic [`SIZE_PC-1:0]                  pc;
	logic [`SIZE_INSTRUCTION-1:0]         inst;

	logic [`SIZE_RMT_LOG-1:0]             logDest;

	logic [`SIZE_PHYSICAL_LOG-1:0]        phyDest;
  logic                                 phyDestValid;

	logic [`SIZE_PHYSICAL_LOG-1:0]        phySrc1;
	logic [`SIZE_DATA-1:0]                src1Data;

	logic [`SIZE_PHYSICAL_LOG-1:0]        phySrc2;
	logic [`SIZE_DATA-1:0]                src2Data;

	logic [`SIZE_LSQ_LOG-1:0]             lsqID;
	logic [`SIZE_ACTIVELIST_LOG-1:0]      alID;

	logic [`SIZE_IMMEDIATE-1:0]           immed;

	logic                                 isSimple;
	logic                                 isFP;
	logic                                 isCSR;

	logic [`BRANCH_TYPE_LOG-1:0]          ctrlType;
	logic [`SIZE_CTI_LOG-1:0]             ctiID;
	logic [`SIZE_PC-1:0]                  predNPC;
	logic                                 predDir;

	logic                                 valid;
} fuPkt;

`define FU_PKT_SIZE 32+`SIZE_PC+`SIZE_INSTRUCTION+`SIZE_RMT_LOG+1+3*(`SIZE_PHYSICAL_LOG)+2*(`SIZE_DATA)+`SIZE_LSQ_LOG+`SIZE_ACTIVELIST_LOG+`SIZE_IMMEDIATE+1+1+1+`BRANCH_TYPE_LOG+`SIZE_CTI_LOG+`SIZE_PC+1+1

typedef struct packed {
  
	logic [`SIZE_RMT_LOG-1:0]             logDest;
	logic [`SIZE_PHYSICAL_LOG-1:0]        tag;
	logic [63:0]                          data;
	logic                                 valid;
} bypassPkt;


typedef struct packed {
	logic                                 isControl;   /* [7] */
	logic                                 ldSign;      /* [6] */
	logic                                 isPredicted; /* [5] */
	logic                                 destValid;   /* [4] */
	logic                                 isFission;   /* [3] */
	logic                                 executed;    /* [2] */
	logic                                 exception;   /* [1] */
	logic                                 mispredict;  /* [0] */
} exeFlgs;

`define SIZE_EXE_FLAGS 8

typedef struct packed {
	logic [31:0]                          seqNo;
	logic [`SIZE_PC-1:0]                  pc;
	exeFlgs                               flags;

	logic [`SIZE_RMT_LOG-1:0]             logDest;
	logic [`SIZE_PHYSICAL_LOG-1:0]        phyDest;

	logic [`SIZE_DATA-1:0]                destData;

	logic [`SIZE_ACTIVELIST_LOG-1:0]      alID;

  logic [`CSR_WIDTH-1:0]           csrWrData;
  logic [`CSR_WIDTH_LOG-1:0]             csrWrAddr;
  logic                                 csrWrEn;
	logic [`SIZE_PC-1:0]                  nextPC;
	logic [`BRANCH_TYPE_LOG-1:0]              ctrlType;
	logic                                 ctrlDir;
	logic [`SIZE_CTI_LOG-1:0]             ctiID;
	logic                                 predDir;

	logic                                 valid;
} wbPkt;

`define WB_PKT_SIZE   32+`SIZE_PC+`SIZE_EXE_FLAGS+`SIZE_RMT_LOG+`SIZE_PHYSICAL_LOG+`SIZE_DATA+`SIZE_ACTIVELIST_LOG+`CSR_WIDTH+`CSR_WIDTH_LOG+1+`SIZE_PC+`BRANCH_TYPE_LOG+1+1

typedef struct packed {
	logic [31:0]                          seqNo;
	logic [`SIZE_ACTIVELIST_LOG-1:0]      alID;
	logic                                 valid;
} ldVioPkt;

`define LD_VIO_PKT_SIZE 40

typedef struct packed {
	logic [31:0]                          seqNo;
	logic [`SIZE_PC-1:0]                  nextPC;

	logic [`SIZE_ACTIVELIST_LOG-1:0]      alID;

	exeFlgs                               flags;
  logic                                 actualDir;
	logic                                 valid;
} ctrlPkt;

typedef struct packed {
	logic [31:0]                          seqNo;
	logic [`SIZE_PC-1:0]                  pc;
	exeFlgs                               flags;

	logic [`LDST_TYPES_LOG-1:0]           ldstSize;

	logic [`SIZE_PHYSICAL_LOG-1:0]        phyDest;

	logic [`SIZE_DATA-1:0]                address;

	logic [`SIZE_DATA-1:0]                src2Data;

	logic [`SIZE_LSQ_LOG-1:0]             lsqID;
	logic [`SIZE_ACTIVELIST_LOG-1:0]      alID;

	logic                                 valid;
} memPkt;

typedef struct packed {
	logic [31:0]                          seqNo;
	logic [`SIZE_RMT_LOG-1:0]             logDest;
	logic [`SIZE_PHYSICAL_LOG-1:0]        phyDest;
	logic                                 valid;
} commitPkt;

`define COMMIT_PKT_SIZE 46

typedef struct packed {
	logic [`SIZE_RMT_LOG-1:0]             logDest;
	logic [`SIZE_PHYSICAL_LOG-1:0]        phyDest;
} recoverPkt;

typedef struct packed {
	logic [31:0]                          seqNo;
	logic [`SIZE_ACTIVELIST_LOG-1:0]      alID;
  logic [`EXCEPTION_CAUSE_LOG-1:0]      exceptionCause; 
  logic                                 exception;
  logic                                 valid;
} exceptionPkt;


`define EXCEPTION_PKT_SIZE   32+`SIZE_ACTIVELIST_LOG+`EXCEPTION_CAUSE_LOG+1+1


//Changes: Mohit(Definition for fp_exception Packet)
typedef struct packed {
	logic [`SIZE_ACTIVELIST_LOG-1:0]     alID;
	logic [`CSR_WIDTH-1:0]		     fflags;
	logic				     valid;
} fpexcptPkt;

`endif // STRUCTS_SVH

