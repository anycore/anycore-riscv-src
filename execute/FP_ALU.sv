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

/* Algorithm
 1. result_o contains the result of the floating point operation.
 2. flags has following fields:
    bit[0]: Mispredict,
    bit[1]: Exception,
    bit[2]: Executed,
    bit[3]: Fission Instruction,
    bit[4]: Destination Valid,
    bit[5]: Predicted Control Instruction
    bit[6]: Load byte/half-word sign
    bit[7]: Conditional Branch Instruction

***************************************************************************/


module FP_ALU (
    input  fuPkt                     exePacket_i,
    output reg                       toggleFlag_o, 
    
    input  [`SIZE_DATA-1:0]          data1_i,
    input  [`SIZE_DATA-1:0]          data2_i,
    
    input  [`CSR_WIDTH-1:0]          csr_frm_i,	//Changes: Mohit (Rounding mode register)
    
    output fpexcptPkt                fpExcptPacket_o,	//Changes: Mohit (FP_Exception Packet)

    output wbPkt                     wbPacket_o
    );

exeFlgs                        flags;
reg  [`SIZE_DATA-1:0]          result;
wire [`SIZE_SINGLE-1:0]        Sfadd;    //SfXXX are outputs of SINGLE precision DW modules
wire [`SIZE_SINGLE-1:0]        Sfsub;
wire [`SIZE_SINGLE-1:0]        Sfmult;
wire [`SIZE_SINGLE-1:0]        Sfdiv;
wire [`SIZE_SINGLE-1:0]        Sfsqrt;

wire [`SIZE_WORD-1:0]          Sflt2i;
wire [`SIZE_WORD:0]            Sflt2iU;  // size is `SIZE_WORD+1 so that an unsigned number of SIZE_WORD can be extracted, by discarding the MSB sign bit
wire [`SIZE_LONG-1:0]          Sflt2iL; 
wire [`SIZE_LONG:0]            Sflt2iLU; // size is `SIZE_LONG+1 so that an unsigned number of SIZE_LONG can be extracted, by discarding the MSB sign bit

wire [`SIZE_SINGLE-1:0]        Si2flt;  
wire [`SIZE_SINGLE-1:0]        Si2fltU;
wire [`SIZE_SINGLE-1:0]        Si2fltL;
wire [`SIZE_SINGLE-1:0]        Si2fltLU;
 
wire                           Sfeq;
wire                           Sflt;

wire [`SIZE_DOUBLE-1:0]        Dfadd;   //DfXXX are outputs of DOUBLE precision DW modules
wire [`SIZE_DOUBLE-1:0]        Dfsub;
wire [`SIZE_DOUBLE-1:0]        Dfmult;
wire [`SIZE_DOUBLE-1:0]        Dfdiv;
wire [`SIZE_DOUBLE-1:0]        Dfsqrt;

wire [`SIZE_WORD-1:0]          Dflt2i;
wire [`SIZE_WORD:0]            Dflt2iU;  // size is `SIZE_WORD+1 so that an unsigned number of SIZE_WORD can be extracted, by discarding the MSB sign bit
wire [`SIZE_LONG-1:0]          Dflt2iL; 
wire [`SIZE_LONG:0]            Dflt2iLU; // size is `SIZE_LONG+1 so that an unsigned number of SIZE_LONG can be extracted, by discarding the MSB sign bit

wire [`SIZE_DOUBLE-1:0]        Di2flt;  
wire [`SIZE_DOUBLE-1:0]        Di2fltU;
wire [`SIZE_DOUBLE-1:0]        Di2fltL;  
wire [`SIZE_DOUBLE-1:0]        Di2fltLU;

wire                           Dfeq;
wire                           Dflt;

reg [2:0]   rm_DW;
reg [7:0]   fp_status; //Changes: Mohit (Execution status as evaluated by Designware modules)
reg [4:0]   csr_fflags_temp; //Changes: Mohit (FP_Exception flag values as required by RISCV-ISA)

/*-----------Changes: Mohit----------------*/
wire [7:0]        Sfadd_status;
wire [7:0]        Sfsub_status;
wire [7:0]        Sfmult_status;
wire [7:0]        Sfdiv_status;
wire [7:0]        Sfsqrt_status;

wire [7:0]        Sflt2i_status;
wire [7:0]        Sflt2iU_status;
wire [7:0]        Sflt2iL_status; 
wire [7:0]        Sflt2iLU_status;

wire [7:0]        Si2flt_status; 
wire [7:0]        Si2fltU_status;
wire [7:0]        Si2fltL_status;
wire [7:0]        Si2fltLU_status;
 
wire [7:0]        Dfadd_status; 
wire [7:0]        Dfsub_status;
wire [7:0]        Dfmult_status;
wire [7:0]        Dfdiv_status;
wire [7:0]        Dfsqrt_status;

wire [7:0]        Dflt2i_status;
wire [7:0]        Dflt2iU_status;
wire [7:0]        Dflt2iL_status;
wire [7:0]        Dflt2iLU_status;

wire [7:0]        Di2flt_status; 
wire [7:0]        Di2fltU_status;
wire [7:0]        Di2fltL_status; 
wire [7:0]        Di2fltLU_status;
/*-----------------------------------------*/


always_comb
begin
    wbPacket_o.seqNo    = exePacket_i.seqNo;
    wbPacket_o.pc       = exePacket_i.pc;
    wbPacket_o.flags    = flags;
    wbPacket_o.phyDest  = exePacket_i.phyDest;
    wbPacket_o.destData = result;
    wbPacket_o.alID     = exePacket_i.alID;
    wbPacket_o.seqNo    = exePacket_i.seqNo;
    wbPacket_o.valid    = exePacket_i.valid;
end


/*-------------Changes: Mohit--------------*/
// Due to mismatch in definition between exception status specified 
// by DW modules and RISCV-ISA, it is necessary to explicitly convert 
// the Floating-point status upon execution
always_comb
begin
    csr_fflags_temp = 5'h00;
    case(fp_status)
    8'h00: begin
		csr_fflags_temp = 5'h00; //No exception generated
	   end
    8'h02: begin
		csr_fflags_temp = 5'h08; //Divide by zero
	   end
    8'h04: begin
		csr_fflags_temp = 5'h10; //Invalid operation
	   end
    8'h08: begin
		csr_fflags_temp = 5'h02; //Underflow
	   end
    8'h10: begin
		csr_fflags_temp = 5'h04; //Overflow
	   end
    8'h20: begin
		csr_fflags_temp = 5'h01; //Inexact
	   end
    default: begin
		csr_fflags_temp = 5'h00;
	     end
    endcase
end

always_comb
begin
	 fpExcptPacket_o.fflags = exePacket_i.valid ? {{59{1'b0}},csr_fflags_temp} : 64'h0; //Exception value is passed on
	 fpExcptPacket_o.valid  = exePacket_i.valid; //If floating-point instruction then Exception Packet is valid
	 fpExcptPacket_o.alID   = exePacket_i.alID;  //AL-ID of floating point instruction to write the result during retire
end
/*-----------------------------------------*/

always_comb
begin:FALU_OPERATION

    reg [`SIZE_DATA-1:0]  data1;
    reg [`SIZE_DATA-1:0]  data2;
    
    reg [`SIZE_OPCODE_P-1:0] opcode;
    reg [`FUNCT5_HI-`FUNCT5_LO:0] fn5;
    reg [`FUNCT3_HI-`FUNCT3_LO:0] fn3;
    reg [`FMT_HI-`FMT_LO:0]       fmt;
    reg [`RS2_HI-`RS2_LO:0]       rs2;

    opcode =  exePacket_i.inst[`SIZE_OPCODE_P-1:0];
    fn5    =  exePacket_i.inst[`FUNCT5_HI:`FUNCT5_LO];
    fn3    =  exePacket_i.inst[`FUNCT3_HI:`FUNCT3_LO];
    fmt    =  exePacket_i.inst[`FMT_HI:`FMT_LO];
    rs2    =  exePacket_i.inst[`RS2_HI:`RS2_LO];

    result    = 0;
    flags   = 0;
    fp_status = 0;

    case (opcode)

        `OP_OP_FP:
         begin
            case (fmt)

                `FMT_S:
                 begin
                    case (fn5)

                        `FN5_FADD:
                         begin
                         result[31:0]            = Sfadd;
			 fp_status 		 = Sfadd_status;	//Changes: Mohit (Added support for FP_STATUS for all instruction)
                         flags.executed          = 1'h1;
                         flags.destValid         = exePacket_i.phyDestValid; 
                         end

                        `FN5_FSUB:
                         begin
                         result[31:0]            = Sfsub;
			 fp_status 		 = Sfsub_status;	//Changes: Mohit (Selecting status from correct DW module)
                         flags.executed          = 1'h1;
                         flags.destValid         = exePacket_i.phyDestValid; 
                         end

                        `FN5_FMUL:
                         begin
                         result[31:0]            = Sfmult;
			 fp_status		 = Sfmult_status;	//Changes: Mohit (Selecting status from correct DW module) 
                         flags.executed          = 1'h1;
                         flags.destValid         = exePacket_i.phyDestValid; 
                         end

                        `FN5_FDIV:
                         begin
                         result[31:0]            = Sfdiv;
			 fp_status 		 = Sfdiv_status;	//Changes: Mohit (Selecting status from correct DW module)
                         flags.executed          = 1'h1;
                         flags.destValid         = exePacket_i.phyDestValid; 
                         end

                         `FN5_FSQRT:
                         begin
                         result[31:0]            = Sfsqrt;
			 fp_status		 = Sfsqrt_status;	//Changes: Mohit (Selecting status from correct DW module)
                         flags.executed          = 1'h1;
                         flags.destValid         = exePacket_i.phyDestValid; 
                         end
                            
                         `FN5_FSGNJ:
                         begin
                         case(fn3)
                            `FN3_FSGNJ:
                             begin
                             result[31:0] = (data1_i &~ `UINT32_MIN) | (data2_i & `UINT32_MIN) ;
                             flags.executed          = 1'h1;
                             flags.destValid         = exePacket_i.phyDestValid; 
                             end

                            `FN3_FSGNJN:
                             begin
                             result[31:0] = (data1_i &~ `UINT32_MIN) | (data2_i & `UINT32_MIN) ;
                             flags.executed          = 1'h1;
                             flags.destValid         = exePacket_i.phyDestValid; 
                             end

                            `FN3_FSGNJX:
                             begin
                             result[31:0] = (data1_i ^ (data2_i & `UINT32_MIN)) ;
                             flags.executed          = 1'h1;
                             flags.destValid         = exePacket_i.phyDestValid; 
                             end
                          endcase
                          end

                         `FN5_FMIN_MAX:
                         begin
                            case (fn3)
                                `FN3_FMIN:
                                 begin
                                 result                  = Sflt ? data1_i : data2_i ;
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                                
                                `FN3_FMAX:
                                 begin
                                 result[31:0]            = (!Sflt) ? data1_i : data2_i  ; 
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                            endcase
                          end

                         `FN5_FCVT_FP2I:
                         begin
                           case (rs2) 
                                `RS2_FCVT_W:
                                 begin
                                 result[31:0]            = Sflt2i;
				 fp_status 		 = Sflt2i_status;	//Changes: Mohit (Selecting status from correct DW module) 
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                                
                                `RS2_FCVT_WU:
                                 begin
                                 result[`SIZE_WORD-1:0]  = Sflt2iU[`SIZE_WORD-1:0]; // converting to 33 and dropping the sign bit
                                 fp_status 	   	 = Sflt2iU_status;	//Changes: Mohit (Selecting status from correct DW module)
				 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                                
                                `RS2_FCVT_L:
                                 begin
                                 result                  = Sflt2iL;
				 fp_status 		 = Sflt2iL_status;	//Changes: Mohit (Selecting status from correct DW module)
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                                
                                `RS2_FCVT_LU:
                                 begin
                                 result                  = Sflt2iLU[`SIZE_LONG-1:0]; // converting to 65 and dropping the sign bit
                                 fp_status 		 = Sflt2iLU_status;	//Changes: Mohit (Selecting status from correct DW module)
				 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                           endcase
                           end
                           
                           `FN5_FMV_FP2I:
                            begin
                            case (fn3)
                                `FN3_FMV:
                                 begin
                                 result[31:0]            = data1_i  ; //TODO
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                                 
                                 `FN3_FCLASS:
                                 begin
                                 result[31:0]            = 0  ; //TODO
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                                    
                            endcase
                            end

                            `FN5_FCOMP:
                            begin
                            case (fn3)
                                `FN3_FEQ:
                                 begin
                                 result[31:0]            = Sfeq  ; 
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end

                                `FN3_FLT:
                                 begin
                                 result[31:0]            = Sflt  ; 
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end

                                `FN3_FLE:
                                 begin
                                 result[31:0]            = (Sfeq | Sflt)  ; 
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                            endcase
                            end
                             
                            `FN5_FCVT_I2FP:
                            begin
                            case (rs2)	//Changes: Mohit (Changed case select field from fn3 to rs2)
                                `RS2_FCVT_W:
                                 begin
                                 result[31:0]            = Si2flt;
				 fp_status		 = Si2flt_status;	//Changes: Mohit (Selecting status from correct DW module) 
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                                
                                `RS2_FCVT_WU:
                                 begin
                                 result[31:0]            = Si2fltU;
				 fp_status 		 = Si2fltU_status;	//Changes: Mohit (Selecting status from correct DW module)
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                                
                                `RS2_FCVT_L:
                                 begin
                                 result                  = Si2fltL;
				 fp_status		 = Si2fltL_status;	//Changes: Mohit (Selecting status from correct DW module)
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                                
                                `RS2_FCVT_LU:
                                 begin
                                 result                  = Si2fltLU;
			 	 fp_status 		 = Si2fltLU_status;	//Changes: Mohit (Selecting status from correct DW module)
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                            endcase
                            end    
                            
                             
                           `FN5_FMV_I2FP:
                            begin
                            case (fn3)
                                `FN3_FMV:
                                 begin
                                 result                  = data1_i  ; //TODO
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                             endcase
                             end
                    endcase // case (fn5)
                 end //FMT_S


                `FMT_D:
                 begin
                    case (fn5)

                        `FN5_FADD:
                         begin
                         result                  = Dfadd;
			 fp_status 		 = Dfadd_status;	//Changes: Mohit (Selecting status from correct DW module)
                         flags.executed          = 1'h1;
                         flags.destValid         = exePacket_i.phyDestValid; 
                         end

                        `FN5_FSUB:
                         begin
                         result                  = Dfsub;
			 fp_status 		 = Dfsub_status;	//Changes: Mohit (Selecting status from correct DW module)
                         flags.executed          = 1'h1;
                         flags.destValid         = exePacket_i.phyDestValid; 
                         end

                        `FN5_FMUL:
                         begin
                         result                  = Dfmult;
			 fp_status 		 = Dfmult_status;	//Changes: Mohit (Selecting status from correct DW module)
                         flags.executed          = 1'h1;
                         flags.destValid         = exePacket_i.phyDestValid; 
                         end

                        `FN5_FDIV:
                         begin
                         result                  = Dfdiv;
			 fp_status 		 = Dfdiv_status;	//Changes: Mohit (Selecting status from correct DW module)
                         flags.executed          = 1'h1;
                         flags.destValid         = exePacket_i.phyDestValid; 
                         end

                         `FN5_FSGNJ:
                         begin

                         case(fn3)
                            
                            `FN3_FSGNJ:
                             begin
                             result                  = (data1_i &~ `UINT64_MIN) | (data2_i & `UINT64_MIN) ;
                             flags.executed          = 1'h1;
                             flags.destValid         = exePacket_i.phyDestValid; 
                             end

                            `FN3_FSGNJN:
                             begin
                             result                  = (data1_i &~ `UINT64_MIN) | (data2_i & `UINT64_MIN) ;
                             flags.executed          = 1'h1;
                             flags.destValid         = exePacket_i.phyDestValid; 
                             end

                            `FN3_FSGNJX:
                             begin
                             result                  = (data1_i ^ (data2_i & `UINT64_MIN)) ;
                             flags.executed          = 1'h1;
                             flags.destValid         = exePacket_i.phyDestValid; 
                             end
                          endcase
                          end

                          `FN5_FSQRT:
                          begin
                          result                  = Dfsqrt;
			  fp_status 		  = Dfsqrt_status;	//Changes: Mohit (Selecting status from correct DW module)
                          flags.executed          = 1'h1;
                          flags.destValid         = exePacket_i.phyDestValid; 
                          end
                            
                          `FN5_FMIN_MAX:
                          begin
                            case (fn3)
                                `FN3_FMIN:
                                 begin
                                 result                  = Dflt ? data1_i : data2_i  ;
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                                
                                `FN3_FMAX:
                                 begin
                                 result                  = (!Dflt) ? data1_i : data2_i  ; 
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                            endcase
                          end

                          `FN5_FCVT_FP2I:
                           begin
                           case (rs2) 
                                `RS2_FCVT_W:
                                 begin
                                 result                  = {{32{Dflt2i[31]}},Dflt2i};
				 fp_status		 = Dflt2i_status;	//Changes: Mohit (Selecting status from correct DW module)
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                                
                                `RS2_FCVT_WU:
                                 begin
                                 result                  = {32'b0,Dflt2iU[`SIZE_SINGLE-1:0]}; // converting to 33 and dropping the sign bit
				 fp_status		 = Dflt2iU_status;	//Changes: Mohit (Selecting status from correct DW module)
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                                
                                `RS2_FCVT_L:
                                 begin
                                 result                  = Dflt2iL;
				 fp_status 		 = Dflt2iL_status;	//Changes: Mohit (Selecting status from correct DW module)
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                                
                                `RS2_FCVT_LU:
                                 begin
                                 result                  = Dflt2iLU[`SIZE_DATA-1:0]; // converting to 65 and dropping the sign bit
				 fp_status		 = Dflt2iLU_status;	//Changes: Mohit (Selecting status from correct DW module)
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                           endcase
                           end
                           
                           `FN5_FMV_FP2I:
                            begin
                            case (fn3)
                                `FN3_FMV:
                                 begin
                                 result                  = data1_i  ; //TODO
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                                 
                                 `FN3_FCLASS:
                                 begin
                                 result                  = 0  ; //TODO
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                                    
                            endcase
                            end

                            `FN5_FCOMP:
                            begin
                            case (fn3)
                                `FN3_FEQ:
                                 begin
                                 result                  = Dfeq  ; 
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end

                                `FN3_FLT:
                                 begin
                                 result                  = Dflt ; 
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end

                                `FN3_FLE:
                                 begin
                                 result                  = (Dfeq | Dflt)  ; 
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                            endcase
                            end
                             
                            `FN5_FCVT_I2FP:
                            begin
                            case (fn3)
                                `RS2_FCVT_W:
                                 begin
                                 result                  = Di2flt;
				 fp_status		 = Di2flt_status;	//Changes: Mohit (Selecting status from correct DW module)
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                                
                                `RS2_FCVT_WU:
                                 begin
                                 result                  = Di2fltU;
				 fp_status 		 = Di2fltU_status;	//Changes: Mohit (Selecting status from correct DW module)
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                                
                                `RS2_FCVT_L:
                                 begin
                                 result                  = Di2fltL;
				 fp_status 		 = Di2fltL_status;	//Changes: Mohit (Selecting status from correct DW module)
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                                
                                `RS2_FCVT_LU:
                                 begin
                                 result                  = Di2fltLU;
				 fp_status		 = Di2fltLU_status;	//Changes: Mohit (Selecting status from correct DW module)
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                            endcase
                            end    
                            
                             
                           `FN5_FMV_I2FP:
                            begin
                            case (fn3)
                                `FN3_FMV:
                                 begin
                                 result                  = data1_i  ; //TODO
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                             endcase
                            end
                        endcase // case (fn5)
                   end //FMT_D
            endcase // case (fmt)
        end // OP_OP_FP
    endcase //case (opcode)

end // FALU_OPERATION


/* Handling the mismatch in encoding. Refer RISCV user spec Table 6.1 and
Designware datasheet for DW_fp_add for the difference. */
always_comb
begin
    reg [2:0]   rm_RISCV;

    rm_RISCV = exePacket_i.inst[`RM_HI:`RM_LO];

    if(rm_RISCV == 3'b111) begin //Changes: Mohit (Read value from frm register if the mode is dynamic rounding mode)
	rm_RISCV = csr_frm_i[3:0];
    end

   rm_DW = rm_RISCV; //default

    case(rm_RISCV)
        `RM_RDN :
            rm_DW = `RM_RUP;
        
        `RM_RUP :
            rm_DW = `RM_RDN;

         /*default:
         begin
            rm_DW = `RM_RUP;	//Changes: Mohit
         end*/
    endcase
    rm_DW = exePacket_i.valid ? rm_DW : `RM_RUP;
end

localparam SIZE_DATA_S = (`SIZE_S_SIG + `SIZE_S_EXP + 1);
logic [SIZE_DATA_S-1:0] data1_S;
logic [SIZE_DATA_S-1:0] data2_S;

assign data1_S = data1_i[SIZE_DATA_S-1:0];
assign data2_S = data2_i[SIZE_DATA_S-1:0];

`ifdef USE_DESIGNWARE

// DW instantiations for SINGLE precision FP instructions

DW_fp_add #(
    .sig_width  (`SIZE_S_SIG),
    .exp_width  (`SIZE_S_EXP),
    .ieee_compliance(1) // 1 : for IEEE compliance 
)
fp_add_S(
    .a(data1_S),
    .b(data2_S),
    .rnd(rm_DW),
    .status(Sfadd_status),
    .z(Sfadd)
);

DW_fp_sub #(
    .sig_width  (`SIZE_S_SIG),
    .exp_width  (`SIZE_S_EXP),
    .ieee_compliance(1) // 1 : for IEEE compliance 
)
fp_sub_S(
    .a(data1_S),
    .b(data2_S),
    .rnd(rm_DW),
    .status(Sfsub_status),
    .z(Sfsub)
);

DW_fp_mult #(
    .sig_width  (`SIZE_S_SIG),
    .exp_width  (`SIZE_S_EXP),
    .ieee_compliance(1) // 1 : for IEEE compliance 
)
fp_mult_S(
    .a(data1_S),
    .b(data2_S),
    .rnd(rm_DW),
    .status(Sfmult_status),
    .z(Sfmult)
);

DW_fp_div #(
    .sig_width  (`SIZE_S_SIG),
    .exp_width  (`SIZE_S_EXP),
    .ieee_compliance(1), // 1 : for IEEE compliance 
    .faithful_round(0) // 0 : for the rm to take effect
)
fp_div_S(
    .a(data1_S),
    .b(data2_S),
    .rnd(rm_DW),
    .status(Sfdiv_status),
    .z(Sfdiv)
);

DW_fp_sqrt #(
    .sig_width  (`SIZE_S_SIG),
    .exp_width  (`SIZE_S_EXP),
    .ieee_compliance(1) // 1 : for IEEE compliance 
)
fp_sqrt_S(
    .a(data1_S),
    .rnd(rm_DW),
    .status(Sfsqrt_status),
    .z(Sfsqrt)
);

DW_fp_flt2i #(
    .sig_width  (`SIZE_S_SIG),
    .exp_width  (`SIZE_S_EXP),
    .isize(`SIZE_WORD),
    .ieee_compliance(1) // 1 : for IEEE compliance 
)
fp_flt2i_S(
    .a(data1_S),
    .rnd(rm_DW),
    .status(Sflt2i_status),
    .z(Sflt2i)
);

DW_fp_flt2i #(
    .sig_width  (`SIZE_S_SIG),
    .exp_width  (`SIZE_S_EXP),
    .isize(`SIZE_WORD+1),
    .ieee_compliance(1) // 1 : for IEEE compliance 
)
fp_flt2iU_S(
    .a(data1_S),
    .rnd(rm_DW),
    .status(Sflt2iU_status),
    .z(Sflt2iU)
);

DW_fp_flt2i #(
    .sig_width  (`SIZE_S_SIG),
    .exp_width  (`SIZE_S_EXP),
    .isize(`SIZE_LONG),
    .ieee_compliance(1) // 1 : for IEEE compliance 
)
fp_flt2iL_S(
    .a(data1_S),
    .rnd(rm_DW),
    .status(Sflt2iL_status),
    .z(Sflt2iL)
);

DW_fp_flt2i #(
    .sig_width  (`SIZE_S_SIG),
    .exp_width  (`SIZE_S_EXP),
    .isize(`SIZE_LONG+1),
    .ieee_compliance(1) // 1 : for IEEE compliance 
)
fp_flt2iLU_S(
    .a(data1_S),
    .rnd(rm_DW),
    .status(Sflt2iLU_status),
    .z(Sflt2iLU)
);

DW_fp_cmp #(
    .sig_width  (`SIZE_S_SIG),
    .exp_width  (`SIZE_S_EXP),
    .ieee_compliance(1) // 1 : for IEEE compliance 
)
fp_cmp_S(
    .a(data1_S),
    .b(data2_S),
    .altb(Sflt),
    .aeqb(Sfeq),
    .agtb(),
    .unordered(),
    .z0(),
    .z1(),
    .status0(),
    .status1(),
    .zctr()
);

DW_fp_i2flt #(
    .sig_width  (`SIZE_S_SIG),
    .exp_width  (`SIZE_S_EXP),
    .isize(`SIZE_WORD),
    .isign(1) // 1 : signed 
)
fp_i2flt_S(
    .a(data1_S),
    .rnd(rm_DW),
    .status(Si2flt_status),
    .z(Si2flt)
);

DW_fp_i2flt #(
    .sig_width  (`SIZE_S_SIG),
    .exp_width  (`SIZE_S_EXP),
    .isize(`SIZE_WORD),
    .isign(0) // 0 : unsigned 
)
fp_i2fltU_S(
    .a(data1_S),
    .rnd(rm_DW),
    .status(Si2fltU_status),
    .z(Si2fltU)
);

DW_fp_i2flt #(
    .sig_width  (`SIZE_S_SIG),
    .exp_width  (`SIZE_S_EXP),
    .isize(`SIZE_LONG),
    .isign(1) // 1 : signed 
)
fp_i2fltL_S(
    .a(data1_i),
    .rnd(rm_DW),
    .status(Si2fltL_status),
    .z(Si2fltL)
);

DW_fp_i2flt #(
    .sig_width  (`SIZE_S_SIG),
    .exp_width  (`SIZE_S_EXP),
    .isize(`SIZE_LONG),
    .isign(0) // 0 : unsigned 
)
fp_i2fltLU_S(
    .a(data1_i),
    .rnd(rm_DW),
    .status(Si2fltLU_status),
    .z(Si2fltLU)
);

// DW instantiations for DOUBLE precision FP instructions, sig_width and exp_width parameters change accordingly

DW_fp_add #(
    .sig_width  (`SIZE_D_SIG),
    .exp_width  (`SIZE_D_EXP),
    .ieee_compliance(1) // 1 : for IEEE compliance 
)
fp_add_D(
    .a(data1_i),
    .b(data2_i),
    .rnd(rm_DW),
    .status(Dfadd_status),
    .z(Dfadd)
);

DW_fp_sub #(
    .sig_width  (`SIZE_D_SIG),
    .exp_width  (`SIZE_D_EXP),
    .ieee_compliance(1) // 1 : for IEEE compliance 
)
fp_sub_D(
    .a(data1_i),
    .b(data2_i),
    .rnd(rm_DW),
    .status(Dfsub_status),
    .z(Dfsub)
);

DW_fp_mult #(
    .sig_width  (`SIZE_D_SIG),
    .exp_width  (`SIZE_D_EXP),
    .ieee_compliance(1) // 1 : for IEEE compliance 
)
fp_mult_D(
    .a(data1_i),
    .b(data2_i),
    .rnd(rm_DW),
    .status(Dfmult_status),
    .z(Dfmult)
);

DW_fp_sqrt #(
    .sig_width  (`SIZE_D_SIG),
    .exp_width  (`SIZE_D_EXP),
    .ieee_compliance(1) // 1 : for IEEE compliance 
)
fp_sqrt_D(
    .a(data1_i),
    .rnd(rm_DW),
    .status(Dfsqrt_status),
    .z(Dfsqrt)
);

DW_fp_div #(
    .sig_width  (`SIZE_D_SIG),
    .exp_width  (`SIZE_D_EXP),
    .ieee_compliance(1), // 1 : for IEEE compliance 
    .faithful_round(0) // 0 : for the rm to take effect
)
fp_div_D(
    .a(data1_i),
    .b(data2_i),
    .rnd(rm_DW),
    .status(Dfdiv_status),
    .z(Dfdiv)
);

DW_fp_flt2i #(
    .sig_width  (`SIZE_D_SIG),
    .exp_width  (`SIZE_D_EXP),
    .isize(`SIZE_WORD),
    .ieee_compliance(1) // 1 : for IEEE compliance 
)
fp_flt2i_D(
    .a(data1_i),
    .rnd(rm_DW),
    .status(Dflt2i_status),
    .z(Dflt2i)
);

DW_fp_flt2i #(
    .sig_width  (`SIZE_D_SIG),
    .exp_width  (`SIZE_D_EXP),
    .isize(`SIZE_WORD+1), 
    .ieee_compliance(1) // 1 : for IEEE compliance 
)
fp_flt2iU_D(
    .a(data1_i),
    .rnd(rm_DW),
    .status(Dflt2iU_status),
    .z(Dflt2iU)
);

DW_fp_flt2i #(
    .sig_width  (`SIZE_D_SIG),
    .exp_width  (`SIZE_D_EXP),
    .isize(`SIZE_LONG+1), 
    .ieee_compliance(1) // 1 : for IEEE compliance 
)
fp_flt2iLU_D(
    .a(data1_i),
    .rnd(rm_DW),
    .status(Dflt2iLU_status),
    .z(Dflt2iLU)
);

DW_fp_flt2i #(
    .sig_width  (`SIZE_D_SIG),
    .exp_width  (`SIZE_D_EXP),
    .isize(`SIZE_LONG),
    .ieee_compliance(1) // 1 : for IEEE compliance 
)
fp_flt2iL_D(
    .a(data1_i),
    .rnd(rm_DW),
    .status(Dflt2iL_status),
    .z(Dflt2iL)
);

DW_fp_cmp #(
    .sig_width  (`SIZE_D_SIG),
    .exp_width  (`SIZE_D_EXP),
    .ieee_compliance(1) // 1 : for IEEE compliance 
)
fp_cmp_D(
    .a(data1_i),
    .b(data2_i),
    .altb(Dflt),
    .aeqb(Dfeq),
    .agtb(),
    .unordered(),
    .z0(),
    .z1(),
    .status0(),
    .status1(),
    .zctr()
);

DW_fp_i2flt #(
    .sig_width  (`SIZE_D_SIG),
    .exp_width  (`SIZE_D_EXP),
    .isize(`SIZE_WORD),
    .isign(1) // 1 : signed 
)
fp_i2flt_D(
    .a(data1_i[`SIZE_WORD-1:0]),
    .rnd(rm_DW),
    .status(Di2flt_status),
    .z(Di2flt)
);

DW_fp_i2flt #(
    .sig_width  (`SIZE_D_SIG),
    .exp_width  (`SIZE_D_EXP),
    .isize(`SIZE_WORD),
    .isign(0) // 0 : unsigned 
)
fp_i2fltU_D(
    .a(data1_i[`SIZE_WORD-1:0]),
    .rnd(rm_DW),
    .status(Di2fltU_status),
    .z(Di2fltU)
);

DW_fp_i2flt #(
    .sig_width  (`SIZE_D_SIG),
    .exp_width  (`SIZE_D_EXP),
    .isize(`SIZE_LONG),
    .isign(1) // 1 : signed 
)
fp_i2fltL_D(
    .a(data1_i),
    .rnd(rm_DW),
    .status(Di2fltL_status),
    .z(Di2fltL)
);

DW_fp_i2flt #(
    .sig_width  (`SIZE_D_SIG),
    .exp_width  (`SIZE_D_EXP),
    .isize(`SIZE_LONG),
    .isign(0) // 0 : unsigned 
)
fp_i2fltLU_D(
    .a(data1_i),
    .rnd(rm_DW),
    .status(Di2fltLU_status),
    .z(Di2fltLU)
);

`endif //USE_DESIGNWARE

endmodule

