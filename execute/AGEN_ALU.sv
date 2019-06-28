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
 1. result_o contains the result of the address calculation operation.
***************************************************************************/


module AGEN_ALU (
	input [`SIZE_DATA-1:0]         data1_i,
	input [`SIZE_DATA-1:0]         data2_i,
	input [`SIZE_IMMEDIATE-1:0]    immd_i,
	input [`SIZE_INSTRUCTION-1:0]  inst_i,

	output [`SIZE_DATA-1:0]        address_o,
	output [`LDST_TYPES_LOG-1:0]   ldstSize_o,
	output exeFlgs                 flags_o
	);


reg [`SIZE_DATA-1:0]       address;
reg [`LDST_TYPES_LOG-1:0]  ldstSize;


assign address_o   = address;
assign ldstSize_o  = ldstSize;


always_comb
begin:ALU_OPERATION
	  reg [`SIZE_DATA-1:0] sign_ex_immd;
    reg [`SIZE_OPCODE_P-1:0] opcode;
    reg [`FUNCT3_HI-`FUNCT3_LO:0] fn3;

    /*Sign-extending immediate field from the exePacket*/

    sign_ex_immd   = {{(`SIZE_DATA-`SIZE_IMMEDIATE){immd_i[`SIZE_IMMEDIATE-1]}}, immd_i};
    opcode      = inst_i[`SIZE_OPCODE_P-1:0]; 

    fn3 = inst_i[`FUNCT3_HI:`FUNCT3_LO];

	  address   = 0;
	  ldstSize  = 0;
	  flags_o   = 0;

	  case(opcode)

		    `OP_LOAD, `OP_LOAD_FP:	//Changes: Mohit (Added FP-LOAD which behaves like a INT-LOAD)
         begin
           case(fn3)
             `FN3_LB:  
	           begin
	           	address             = data1_i + sign_ex_immd;
	           	ldstSize            = `LDST_BYTE;
	           	flags_o.ldSign      = 1'h1;
	           	flags_o.destValid   = 1'h1;
	           end
		
             `FN3_LBU:
	        	 begin
	        	 	address             = data1_i + sign_ex_immd;
	        	 	ldstSize            = `LDST_BYTE;
	        	 	flags_o.destValid   = 1'h1;
	        	 end

		         `FN3_LH:
		         begin
		         	address             = data1_i + sign_ex_immd;
		         	ldstSize            = `LDST_HALF_WORD;
		         	flags_o.ldSign      = 1'h1;
		         	flags_o.destValid   = 1'h1;
		         end

           	 `FN3_LHU:
           	 begin
           	 	address             = data1_i + sign_ex_immd;
           	 	ldstSize            = `LDST_HALF_WORD;
           	 	flags_o.destValid   = 1'h1;
           	 end
           
           	 `FN3_LW:
           	 begin
           	 	address             = data1_i + sign_ex_immd;
           	 	ldstSize            = `LDST_WORD;
		           flags_o.ldSign      = 1'h1;
           	 	flags_o.destValid   = 1'h1;
           	 end

             `FN3_LWU:
           	 begin
           	 	address             = data1_i + sign_ex_immd;
           	 	ldstSize            = `LDST_WORD;
           	 	flags_o.destValid   = 1'h1;
           	 end

             `FN3_LD:
           	 begin
           	 	address             = data1_i + sign_ex_immd;
           	 	ldstSize            = `LDST_DOUBLE_WORD;
		           flags_o.ldSign      = 1'h1;
           	 	flags_o.destValid   = 1'h1;
           	 end
               
             default:
             begin
             end

           endcase //case(fn3)
       end

       `OP_STORE, `OP_STORE_FP:		//Changes: Mohit (Added FP-STORE which behaves like INT-LOAD)
       begin
         case(fn3)
           `FN3_SB:
           begin
			        address   = data1_i + sign_ex_immd;
			        ldstSize  = `LDST_BYTE;
			        flags_o.executed = 1'h1;
           end

           `FN3_SH:
           begin
			        address   = data1_i + sign_ex_immd;
			        ldstSize  = `LDST_HALF_WORD;
			        flags_o.executed = 1'h1;
           end

           `FN3_SW:
           begin
        			address   = data1_i + sign_ex_immd;
        			ldstSize  = `LDST_WORD;
        			flags_o.executed = 1'h1;
           end

           `FN3_SD:
           begin
			        address   = data1_i + sign_ex_immd;
			        ldstSize  = `LDST_DOUBLE_WORD;
			        flags_o.executed = 1'h1;
           end
    
           default:
           begin
           end
         endcase //case(fn3)
       end
    // NOTE: Need this default to make the case statement
    // full case and stopping synthesis from screwing up
    // RBRC
    default:
    begin
    end
    endcase // case (opcode)
end

endmodule
