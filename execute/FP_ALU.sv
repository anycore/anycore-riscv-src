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
                         flags.executed          = 1'h1;
                         flags.destValid         = exePacket_i.phyDestValid; 
                         end

                        `FN5_FSUB:
                         begin
                         result[31:0]            = Sfsub;
                         flags.executed          = 1'h1;
                         flags.destValid         = exePacket_i.phyDestValid; 
                         end

                        `FN5_FMUL:
                         begin
                         result[31:0]            = Sfmult;
                         flags.executed          = 1'h1;
                         flags.destValid         = exePacket_i.phyDestValid; 
                         end

                        `FN5_FDIV:
                         begin
                         result[31:0]            = Sfdiv;
                         flags.executed          = 1'h1;
                         flags.destValid         = exePacket_i.phyDestValid; 
                         end

                         `FN5_FSQRT:
                         begin
                         result[31:0]            = Sfsqrt;
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
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                                
                                `RS2_FCVT_WU:
                                 begin
                                 result[`SIZE_WORD-1:0]  = Sflt2iU[`SIZE_WORD-1:0]; // converting to 33 and dropping the sign bit
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                                
                                `RS2_FCVT_L:
                                 begin
                                 result                  = Sflt2iL;
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                                
                                `RS2_FCVT_LU:
                                 begin
                                 result                  = Sflt2iLU[`SIZE_LONG-1:0]; // converting to 65 and dropping the sign bit
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
                            case (fn3)
                                `RS2_FCVT_W:
                                 begin
                                 result[31:0]            = Si2flt;
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                                
                                `RS2_FCVT_WU:
                                 begin
                                 result[31:0]            = Si2fltU;
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                                
                                `RS2_FCVT_L:
                                 begin
                                 result                  = Si2fltL;
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                                
                                `RS2_FCVT_LU:
                                 begin
                                 result                  = Si2fltLU;
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
                         flags.executed          = 1'h1;
                         flags.destValid         = exePacket_i.phyDestValid; 
                         end

                        `FN5_FSUB:
                         begin
                         result                  = Dfsub;
                         flags.executed          = 1'h1;
                         flags.destValid         = exePacket_i.phyDestValid; 
                         end

                        `FN5_FMUL:
                         begin
                         result                  = Dfmult;
                         flags.executed          = 1'h1;
                         flags.destValid         = exePacket_i.phyDestValid; 
                         end

                        `FN5_FDIV:
                         begin
                         result                  = Dfdiv;
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
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                                
                                `RS2_FCVT_WU:
                                 begin
                                 result                  = {32'b0,Dflt2iU[`SIZE_SINGLE-1:0]}; // converting to 33 and dropping the sign bit
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                                
                                `RS2_FCVT_L:
                                 begin
                                 result                  = Dflt2iL;
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                                
                                `RS2_FCVT_LU:
                                 begin
                                 result                  = Dflt2iLU[`SIZE_DATA-1:0]; // converting to 65 and dropping the sign bit
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
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                                
                                `RS2_FCVT_WU:
                                 begin
                                 result                  = Di2fltU;
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                                
                                `RS2_FCVT_L:
                                 begin
                                 result                  = Di2fltL;
                                 flags.executed          = 1'h1;
                                 flags.destValid         = exePacket_i.phyDestValid; 
                                 end
                                
                                `RS2_FCVT_LU:
                                 begin
                                 result                  = Di2fltLU;
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
    rm_DW = rm_RISCV; //default

    case(rm_RISCV)
        `RM_RDN :
            rm_DW = `RM_RUP;
        
        `RM_RUP :
            rm_DW = `RM_RDN;

         default:
         begin
            rm_DW = `RM_RUP;
         end
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
    .status(),
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
    .status(),
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
    .status(),
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
    .status(),
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
    .status(),
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
    .status(),
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
    .status(),
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
    .status(),
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
    .status(),
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
    .status(),
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
    .status(),
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
    .status(),
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
    .status(),
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
    .status(),
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
    .status(),
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
    .status(),
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
    .status(),
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
    .status(),
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
    .status(),
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
    .status(),
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
    .status(),
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
    .status(),
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
    .status(),
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
    .status(),
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
    .status(),
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
    .status(),
    .z(Di2fltLU)
);

`endif //USE_DESIGNWARE

endmodule

