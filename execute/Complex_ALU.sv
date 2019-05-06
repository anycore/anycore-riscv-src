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
 1. result_o contains the result of the arithmetic operation.
 2. flags_o has following fields:
    (.) Executed  :"bit-2"
    (.) Exception :"bit-1"
    (.) Mispredict:"bit-0"

***************************************************************************/

module Complex_ALU #(
    parameter DEPTH                     = 6
)(
    input                               clk,
    input                               reset,
    output                              toggleFlag_o, 
    input                               recoverFlag_i,

    input  fuPkt                        exePacket_i,

    input  [`SIZE_DATA-1:0]             data1_i,
    input  [`SIZE_DATA-1:0]             data2_i,
    input  [`SIZE_IMMEDIATE-1:0]        immd_i,
    input  [`SIZE_INSTRUCTION-1:0]      inst_i,

    output wbPkt                        wbPacket_o
);


wire signed [`SIZE_DATA-1:0]        data1_s;
wire signed [`SIZE_DATA-1:0]        data2_s;
/* reg         [`SIZE_DATA-1:0]        result; */
/* logic       [`SIZE_DATA-1:0]        shiftResultOut; */
logic       [`SIZE_DATA-1:0]        signedProduct_l;
logic       [`SIZE_DATA-1:0]        signedProduct_h;
logic       [`SIZE_DATA-1:0]        unsignedProduct_l;
logic       [`SIZE_DATA-1:0]        unsignedProduct_h;
logic       [`SIZE_DATA-1:0]        signedQuotient;
logic       [`SIZE_DATA-1:0]        signedRemainder;
logic       [`SIZE_DATA-1:0]        unsignedQuotient;
logic       [`SIZE_DATA-1:0]        unsignedRemainder;
logic       [`SIZE_DATA-1:0]        divisor;
exeFlgs                             flags;
exeFlgs                             shiftFlagsOut;
logic [3:0]                         resultType;
logic [3:0]                         resultTypeShifted;
logic                               fuEnabled;

logic                               toggleFlag;

localparam SIGNED_PRODUCT_L     = 4'h0;
localparam SIGNED_PRODUCT_H     = 4'h1;
localparam UNSIGNED_PRODUCT_L   = 4'h2;
localparam UNSIGNED_PRODUCT_H   = 4'h3;
localparam SIGNED_QUOTIENT      = 4'h4;
localparam SIGNED_REMAINDER     = 4'h5;
localparam UNSIGNED_QUOTIENT    = 4'h6;
localparam UNSIGNED_REMAINDER   = 4'h7;
localparam TOGGLE               = 4'h8;
localparam SIGNED_EXT_PRODUCT_L = 4'h9;	//Changes: Mohit (MULW)
localparam SIGNED_EXT_QUOTIENT      = 4'ha; //Changes: Mohit (DIVW)
localparam SIGNED_EXT_REMAINDER     = 4'hb; //Changes: Mohit (REMW)
localparam UNSIGNED_EXT_QUOTIENT    = 4'hc; //Changes: Mohit (DIVUW)
localparam UNSIGNED_EXT_REMAINDER   = 4'hd; //Changes: Mohit (REMUW)


// exePacket_i after (DEPTH-1) cycles
fuPkt                            shiftPacketOut;

// shift register for invalidating packets in the packet shift register during a
// recovery
logic [DEPTH:0]                     recoverFlag_reg;

always_ff @(posedge clk)
begin
    if (reset)
    begin
        recoverFlag_reg     <= 0;
    end
    else if (recoverFlag_i)
    begin
        recoverFlag_reg     <= {(DEPTH+1){1'h1}};
    end
    else
    begin
        recoverFlag_reg     <= recoverFlag_reg << 1;
    end
end

assign data1_s     = data1_i;
assign data2_s     = data2_i;

/* always_ff @(posedge clk) */
/* begin */
/*     if (wbPacket_o.valid) */
/*     begin */
/*         case (resultTypeShifted) */
/*             SIGNED_PRODUCT_L: begin */
/*                 $display("[%0d] SIGNED_PRODUCT_L   (PC: %08x destData: %08x signedProduct_l: %08x)", */ 
/*                     simulate.CYCLE_COUNT, */
/*                     shiftPacketOut.pc, */
/*                     wbPacket_o.destData, */
/*                     signedProduct_l); */
/*             end */
/*             SIGNED_PRODUCT_H: begin */ 
/*                 $display("[%0d] SIGNED_PRODUCT_H   (PC: %08x destData: %08x signedProduct_h: %08x)", */ 
/*                     simulate.CYCLE_COUNT, */
/*                     shiftPacketOut.pc, */
/*                     wbPacket_o.destData, */
/*                     signedProduct_h); */
/*             end */
/*             UNSIGNED_PRODUCT_L: begin */ 
/*                 $display("[%0d] UNSIGNED_PRODUCT_L (PC: %08x destData: %08x unsignedProduct_l: %08x)", */ 
/*                     simulate.CYCLE_COUNT, */
/*                     shiftPacketOut.pc, */
/*                     wbPacket_o.destData, */
/*                     unsignedProduct_l); */
/*             end */
/*             UNSIGNED_PRODUCT_H: begin */ 
/*                 $display("[%0d] UNSIGNED_PRODUCT_H (PC: %08x destData: %08x unsignedProduct_h: %08x)", */ 
/*                     simulate.CYCLE_COUNT, */
/*                     shiftPacketOut.pc, */
/*                     wbPacket_o.destData, */
/*                     unsignedProduct_h); */
/*             end */
/*             SIGNED_QUOTIENT: begin */    
/*                 $display("[%0d] SIGNED_QUOTIENT    (PC: %08x destData: %08x signedQuotient: %08x)", */ 
/*                     simulate.CYCLE_COUNT, */
/*                     shiftPacketOut.pc, */
/*                     wbPacket_o.destData, */
/*                     signedQuotient); */
/*             end */
/*             SIGNED_REMAINDER: begin */   
/*                 $display("[%0d] SIGNED_REMAINDER   (PC: %08x destData: %08x signedRemainder: %08x)", */ 
/*                     simulate.CYCLE_COUNT, */
/*                     shiftPacketOut.pc, */
/*                     wbPacket_o.destData, */
/*                     signedRemainder); */
/*             end */
/*             UNSIGNED_QUOTIENT: begin */  
/*                 $display("[%0d] UNSIGNED_QUOTIENT  (PC: %08x destData: %08x unsignedQuotient: %08x)", */ 
/*                     simulate.CYCLE_COUNT, */
/*                     shiftPacketOut.pc, */
/*                     wbPacket_o.destData, */
/*                     unsignedQuotient); */
/*             end */
/*             UNSIGNED_REMAINDER: begin */ 
/*                 $display("[%0d] UNSIGNED_REMAINDER (PC: %08x destData: %08x unsignedRemainder: %08x)", */ 
/*                     simulate.CYCLE_COUNT, */
/*                     shiftPacketOut.pc, */
/*                     wbPacket_o.destData, */
/*                     unsignedRemainder); */
/*             end */
/*         endcase */
/*     end */
/* end */

// prevent packets in the shift reg during a recovery from begin valid
always_comb
begin
    if (recoverFlag_reg[DEPTH])
    begin
        wbPacket_o          = 0;
    end
    else
    begin
        wbPacket_o          = 0;
        wbPacket_o.seqNo    = shiftPacketOut.seqNo;
        wbPacket_o.pc       = shiftPacketOut.pc;
        wbPacket_o.logDest  = shiftPacketOut.logDest;
        wbPacket_o.phyDest  = shiftPacketOut.phyDest;
        wbPacket_o.alID     = shiftPacketOut.alID;
        wbPacket_o.flags    = shiftFlagsOut;
        wbPacket_o.valid    = shiftPacketOut.valid;
        case (resultTypeShifted)
            SIGNED_PRODUCT_L:   wbPacket_o.destData = signedProduct_l;
            SIGNED_PRODUCT_H:   wbPacket_o.destData = signedProduct_h;
            UNSIGNED_PRODUCT_L: wbPacket_o.destData = unsignedProduct_l;
            UNSIGNED_PRODUCT_H: wbPacket_o.destData = unsignedProduct_h;
            SIGNED_QUOTIENT:    wbPacket_o.destData = signedQuotient;
            SIGNED_REMAINDER:   wbPacket_o.destData = signedRemainder;
            UNSIGNED_QUOTIENT:  wbPacket_o.destData = unsignedQuotient;
            UNSIGNED_REMAINDER: wbPacket_o.destData = unsignedRemainder;
            TOGGLE            : wbPacket_o.destData = 0;
            SIGNED_EXT_PRODUCT_L:   wbPacket_o.destData = {{32{signedProduct_l[31]}},signedProduct_l[31:0]};	// Result: MULW
            SIGNED_EXT_QUOTIENT:    wbPacket_o.destData = {{32{signedQuotient[31]}},signedQuotient[31:0]};	// Result: DIVW
            SIGNED_EXT_REMAINDER:   wbPacket_o.destData = {{32{signedRemainder[31]}},signedRemainder[31:0]};    // Result: REMW
            UNSIGNED_EXT_QUOTIENT:  wbPacket_o.destData = {{32{1'b0}},unsignedQuotient[31:0]};			// Result: DIVUW
            UNSIGNED_EXT_REMAINDER: wbPacket_o.destData = {{32{1'b0}},unsignedRemainder[31:0]};			// Result: REMUW
            default           : wbPacket_o.destData = 0;
        endcase
    end
end

logic reset_n;

assign reset_n = ~reset;

//Changes: Mohit (Modified data values for RV64 instruction)
reg [`SIZE_DATA-1:0]	data1;
reg [`SIZE_DATA-1:0]	data2;

always_comb
begin:ALU_OPERATION
    reg signed  [`SIZE_DATA-1:0]              result1_s;
    reg signed  [`SIZE_DATA-1:0]              result2_s;
    reg         [`SIZE_DATA-1:0]              result1;
    reg         [`SIZE_DATA-1:0]              result2;
    reg         [`SIZE_OPCODE_P-1:0]          opcode;
    reg         [`FUNCT3_HI-`FUNCT3_LO:0]     fn3;
    reg         [`FUNCT7_HI-`FUNCT7_LO:0]     fn7;

    //sign extend immediate to 64 bits
    opcode          = exePacket_i.inst[`SIZE_OPCODE_P-1:0];
    fn3             = exePacket_i.inst[`FUNCT3_HI:`FUNCT3_LO];
    fn7             = exePacket_i.inst[`FUNCT7_HI:`FUNCT7_LO];
    result1         = 0;
    result2         = 0;
    result1_s       = 0;
    result2_s       = 0;
    flags           = 0;

    data1 = data1_i;	//Changes: Mohit //Default: data1
    data2 = data2_i;	//Changes: Mohit //Default: data2

    /* result          = 0; */
    flags           = 0;
    resultType      = 4'h0;
    divisor         = `SIZE_DATA'h1;
    toggleFlag      = 1'b0;
    fuEnabled       = 1'b0;

    case (opcode)
        `OP_OP:
         begin
            case (fn7)
                `FN7_MUL_DIV:
                 begin
                   fuEnabled = 1'b1;
                   case (fn3) 
                        `FN3_MUL:
                         begin
                            flags.executed          = 1'h1;
                            flags.destValid         = exePacket_i.phyDestValid;
                            resultType              = SIGNED_PRODUCT_L;
                         end

                        `FN3_MULH:
                         begin
                            flags.executed          = 1'h1;
                            flags.destValid         = exePacket_i.phyDestValid;
                            resultType              = SIGNED_PRODUCT_H;
                         end

                        `FN3_MULHSU:  //TODO: Not Correct implementation
                         begin
                            flags.executed          = 1'h1;
                            flags.destValid         = exePacket_i.phyDestValid;
                            resultType              = UNSIGNED_PRODUCT_H;
                         end

                        `FN3_MULHU:  //TODO: Not Correct implementation
                         begin
                            flags.executed          = 1'h1;
                            flags.destValid         = exePacket_i.phyDestValid;
                            resultType              = UNSIGNED_PRODUCT_H;
                         end

                        `FN3_DIV:
                         begin
                            // Rangeen on June 26 - Check for divide by 0 and raise exception while returning 
                            // non X value. This exception may not ever reach the top of active list as there
                            // may be a recovery. This has been seen with vortex and four wide core.
                            // CAUTION: All comparisons and assings must be signed otherwise the 
                            // expression will be treated as unsigned and the result will be wrong.
                            /* {result2_s,result1_s}   = (data2_s == 32'sh0) ? 64'sh0 : (data1_s / data2_s); */
                            flags.exception         = (data2_s == 0) ? 1'b1 : 1'b0;
                            /* result                  = result1_s; */
                            flags.executed          = 1'h1;
                            flags.destValid         = exePacket_i.phyDestValid;
                            resultType              = SIGNED_QUOTIENT;
                            divisor                 = data2_i;
                         end
       
                         `FN3_DIVU:
                         begin
                            // Rangeen on June 26 - Check for divide by 0 and raise exception while returning 
                            // non X value. This exception may not ever reach the top of active list as there
                            // may be a recovery. This has been seen with vortex and four wide core.
                            /* {result2,result1}       = (data2_i == 0) ? 64'b0 : (data1_i / data2_i); */
                            flags.exception         = (data2_i == 0) ? 1'b1 : 1'b0;
                            /* result                  = result1; */
                            flags.executed          = 1'h1;
                            flags.destValid         = exePacket_i.phyDestValid;
                            resultType              = UNSIGNED_QUOTIENT;
                            divisor                 = data2_i;
                         end

                        `FN3_REM:
                        begin
                        // Rangeen on June 26 - Check for divide by 0 and raise exception while returning 
                        // non X value. This exception may not ever reach the top of active list as there
                        // may be a recovery. This has been seen with vortex and four wide core.
                        // CAUTION: All comparisons and assings must be signed otherwise the 
                        // expression will be treated as unsigned and the result will be wrong.
                            /* {result1_s,result2_s}   = (data2_s == 32'sh0) ? 64'sh0 : (data1_s % data2_s); */
                            //{result1_s,result2_s}     = (data1_s % data2_s);
                            flags.exception         = (data2_s == 0) ? 1'b1 : 1'b0;
                            /* result                  = result2_s; */
                            flags.executed          = 1'h1;
                            flags.destValid         = exePacket_i.phyDestValid;
                            resultType              = SIGNED_REMAINDER;
                            divisor                 = data2_i;
                        end
        
                        `FN3_REMU:
                        begin
                        // Rangeen on June 26 - CHeck for divide by 0 and raise exception while returning 
                        // non X value. This exception may not ever reach the top of active list as there
                        // may be a recovery. This has been seen with vortex and four wide core.
                            /* {result1,result2}       = (data2_i == 0) ? 64'b0 : (data1_i % data2_i); */
                            flags.exception         = (data2_i == 0) ? 1'b1 : 1'b0;
                            /* result                  = result2; */
                            flags.executed          = 1'h1;
                            flags.destValid         = exePacket_i.phyDestValid;
                            resultType              = UNSIGNED_REMAINDER;
                            divisor                 = data2_i;
                        end
                    endcase //case (fn3)
                  end
                endcase // case (fn7)
	   
           //`OP_SYSTEM:
           // begin 
           //     case (fn3)
           //     `SCALL:
           //       begin
           //           /* result                  = 0; */
           //           flags.executed          = 1'h1;
           //           flags.exception         = 1'h1;
           //       end

           //       `TOGGLE_C:
           //       begin
           //           flags.executed          = 1'h1;
           //           flags.destValid         = exePacket_i.phyDestValid;
           //           resultType              = TOGGLE;
           //           toggleFlag              = 1'b1;
           //       end
           // end
        end

        /*------------------------------------------------Changes: Mohit--------------------------------------------------*/
        `OP_OP_32: begin
		case(fn7)
		   `FN7_MUL_DIV: begin
			fuEnabled = 1'b1;
			case(fn3)
				`FN3_MUL: begin
					data1 = {{32{1'b0}},data1_i[31:0]}; //Sign-extended lower 32-bit value
					data2 = {{32{1'b0}},data2_i[31:0]}; //Sign-extended lower 32-bit value
					flags.executed          = 1'h1;
                            		flags.destValid         = exePacket_i.phyDestValid;
                            		resultType              = SIGNED_EXT_PRODUCT_L;	
				 end
				`FN3_DIV: begin
					flags.exception         = (data2_s[30:0] == 0) ? 1'b1 : 1'b0;	//Divide by zero check
                            		flags.executed          = 1'h1;
                            		flags.destValid         = exePacket_i.phyDestValid;
                            		resultType              = SIGNED_EXT_QUOTIENT;
					data1			= {{32{data1_i[31]}},data1_i[31:0]}; //Sign-extended lower 32 bit value
                            		divisor			= {{32{1'b0}},data2_i[31:0]};
				end	
				`FN3_DIVU: begin
					flags.exception         = (data2_i[30:0] == 0) ? 1'b1 : 1'b0; //Divide by zero check
                            		flags.executed          = 1'h1;
                            		flags.destValid         = exePacket_i.phyDestValid;
                            		resultType              = UNSIGNED_EXT_QUOTIENT;
					data1			= {{32{data1_i[31]}},data1_i[31:0]}; //Sign-extended lower 32-bit value
                            		divisor                 = {{32{1'b0}},data2_i[31:0]};
				end
				`FN3_REM: begin
					flags.exception         = (data2_s[30:0] == 0) ? 1'b1 : 1'b0; //Divide by zero check
                            		flags.executed          = 1'h1;
                            		flags.destValid         = exePacket_i.phyDestValid;
                            		resultType              = SIGNED_EXT_REMAINDER;
                            		data1			= {{32{data1_i[31]}},data1_i[31:0]}; //Sign-extended lower 32-bit value
                            		divisor                 = {{32{1'b0}},data2_i[31:0]};
				end
				`FN3_REMU: begin
					flags.exception         = (data2_i[30:0] == 0) ? 1'b1 : 1'b0; //Divide by zero check
                            		flags.executed          = 1'h1;
                            		flags.destValid         = exePacket_i.phyDestValid;
                            		resultType              = UNSIGNED_EXT_REMAINDER;
					data1			= {{32{data1_i[31]}},data1_i[31:0]};
                            		divisor                 = {{32{1'b0}},data2_i[31:0]};
				end
			endcase	
		   end
		endcase
	 end
	/*----------------------------------------------------------------------------------------------------------------------------*/
    endcase // case (opcode)
end //always_comb

`ifdef USE_DESIGNWARE

// Instance of DW03_pipe_reg
DW03_pipe_reg #(
    .depth          (DEPTH-1),  // num registers
    .width          (`FU_PKT_SIZE)
)
    packetShifter ( 
    
    .clk            (clk), 
    .A              (exePacket_i), 
    .B              (shiftPacketOut) 
);

/* DW03_pipe_reg #( */
/*     .depth          (DEPTH-1),  // num registers */
/*     .width          (32) */
/* ) */
/*     resultShifter ( */ 
    
/*     .clk            (clk), */ 
/*     .A              (result), */ 
/*     .B              (shiftResultOut) */ 
/* ); */

DW03_pipe_reg #(
    .depth          (DEPTH-1),  // num registers
    .width          (1)
)
    toggleShifter ( 
    
    .clk            (clk), 
    .A              (toggleFlag), 
    .B              (toggleFlag_o) 
);

DW03_pipe_reg #(
    .depth          (DEPTH-1),  // num registers
    .width          (8)
)
    flagShifter ( 
    
    .clk            (clk), 
    .A              (flags), 
    .B              (shiftFlagsOut) 
);

DW03_pipe_reg #(
    .depth          (DEPTH-1),  // num registers
    .width          (4)
)
    resultTypeShifter ( 
    
    .clk            (clk), 
    .A              (resultType), 
    .B              (resultTypeShifted) 
);

// Instance of DW_mult_pipe
DW_mult_pipe #(
    .a_width        (`SIZE_DATA), 
    .b_width        (`SIZE_DATA), 
    .num_stages     (DEPTH),    // num registers - 1
    .stall_mode     (0),        // 0:non-stallable 1:stallable
    .rst_mode       (2)         // 0:none 1:asynch 2:synch 
)
    signedMultiplier (
    
    .clk            (clk),
    .rst_n          (reset_n),
    .en             (fuEnabled),
    .tc             (1'h1),     // 0:unsigned 1:signed,
    .a              (data1),	//Changes: Mohit (Changed from data1_s to data1)
    .b              (data2),	//Changes: Mohit (Changed from data2_s to data2)
    .product        ({signedProduct_h, signedProduct_l}) 
);

// Instance of DW_mult_pipe
DW_mult_pipe #(
    .a_width        (`SIZE_DATA), 
    .b_width        (`SIZE_DATA), 
    .num_stages     (DEPTH),    // num registers - 1
    .stall_mode     (0),        // 0:non-stallable 1:stallable
    .rst_mode       (2)         // 0:none 1:asynch 2:synch 
)
    unsignedMultiplier (
    
    .clk            (clk),
    .rst_n          (reset_n),
    .en             (fuEnabled),
    .tc             (1'h0),     // 0:unsigned 1:signed,
    .a              (data1),	//Changes: Mohit (Changed from data1_s to data1)
    .b              (data2),	//Changes: Mohit (Changed from data2_s to data2)
    .product        ({unsignedProduct_h, unsignedProduct_l}) 
);


/* // Instance of DW_div_pipe */
DW_div_pipe #(
    .a_width        (`SIZE_DATA),
    .b_width        (`SIZE_DATA),
    .tc_mode        (1),        // 0:unsigned 1:signed
    .rem_mode       (1),        // 0:modulus 1:remainder
    .num_stages     (DEPTH),    // num registers - 1
    .stall_mode     (0),        // 0:non-stallable 1:stallable
    .rst_mode       (2)         // 0:none 1:asynch 2:synch 
)
    signedDivider (
    
    .clk            (clk),
    .rst_n          (reset_n),
    .en             (fuEnabled),
    .a              (data1),	//Changes: Mohit (Changed from data1_s to data1)
    .b              (divisor),
    .quotient       (signedQuotient),
    .remainder      (signedRemainder),
    .divide_by_0    () 
);

/* // Instance of DW_div_pipe */
DW_div_pipe #(
    .a_width        (`SIZE_DATA),
    .b_width        (`SIZE_DATA),
    .tc_mode        (0),        // 0:unsigned 1:signed
    .rem_mode       (1),        // 0:modulus 1:remainder
    .num_stages     (DEPTH),    // num registers - 1
    .stall_mode     (0),        // 0:non-stallable 1:stallable
    .rst_mode       (2)         // 0:none 1:asynch 2:synch 
)
    unsignedDivider (
    
    .clk            (clk),
    .rst_n          (reset_n),
    .en             (fuEnabled),
    .a              (data1),	//Changes: Mohit (Changed from data1_s to data1)
    .b              (divisor),
    .quotient       (unsignedQuotient),
    .remainder      (unsignedRemainder),
    .divide_by_0    () 
);

`endif

endmodule
