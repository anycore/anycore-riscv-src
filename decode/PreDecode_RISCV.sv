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


module PreDecode_RISCV(

    input  fs2Pkt                    fs2Packet_i,

`ifdef DYNAMIC_CONFIG
    input                            laneActive_i,
`endif
    output                           ctrlInst_o,
    output [`SIZE_PC-1:0]            predNPC_o,
    output [`BRANCH_TYPE_LOG-1:0]        ctrlType_o,
    output                           condBranch_o
    );

logic [`SIZE_OPCODE_P-1:0]         opcode;
logic [`SIZE_RS-1:0]               rs1;
logic [`SIZE_RD-1:0]               rd;

logic immed_SB_12;
logic immed_SB_11;
logic immed_UJ_20;
logic immed_UJ_11;
logic [5:0] immed_10_to_5;
logic [7:0] immed_19_to_12;
logic [3:0] immed_UJ_4_to_1;
logic [3:0] immed_SB_4_to_1;
wire  [`SIZE_DATA-1:0] sign_ex_immed_UJ;
wire  [`SIZE_DATA-1:0] sign_ex_immed_SB;

/* wires and regs definition for combinational logic. */
reg  [`BRANCH_TYPE_LOG-1:0]            ctrlType;
reg  [`SIZE_PC-1:0]                predNPC;
reg                                ctrlInst;

assign ctrlInst_o = ctrlInst;
assign predNPC_o    = predNPC;
assign ctrlType_o   = ctrlType;
assign condBranch_o = (ctrlType == `COND_BRANCH);

/* Extract pieces from the instructions.  */
assign opcode         = fs2Packet_i.inst[`SIZE_OPCODE_P-1:0];

//Control Transfer instructions use I, SB and UJ type immediates. Wires below are
//used to etract the immediate value.

assign immed_SB_12    = fs2Packet_i.inst[`SIZE_INSTRUCTION-1];
assign immed_SB_11    = fs2Packet_i.inst[7];
assign immed_SB_4_to_1   = fs2Packet_i.inst[11:8];

assign immed_UJ_20    = fs2Packet_i.inst[`SIZE_INSTRUCTION-1];
assign immed_UJ_11    = fs2Packet_i.inst[20];
assign immed_UJ_4_to_1   = fs2Packet_i.inst[24:21];
// These immed-fields are always at the same bit-positions for I, SB and UJ. Extracting for later use.

assign immed_10_to_5  = fs2Packet_i.inst[30:25];
assign immed_19_to_12 = fs2Packet_i.inst[19:12];

assign sign_ex_immed_SB = {{52{immed_SB_12}},immed_SB_11,immed_10_to_5,immed_SB_4_to_1,1'b0};
assign sign_ex_immed_UJ = {{44{immed_UJ_20}},immed_19_to_12,immed_UJ_11,immed_10_to_5,immed_UJ_4_to_1,1'b0};

assign rs1       = fs2Packet_i.inst[19:15];
assign rd        = fs2Packet_i.inst[11:7];

always_comb
begin : PRE_DECODE_FOR_CTRL

    predNPC    = 0;
    ctrlType   = 0;
    ctrlInst = 1'b0;

    case(opcode)

        `OP_JAL:
        begin
            predNPC    = (fs2Packet_i.pc + sign_ex_immed_UJ);
            if(rd == `REG_RETURN_ADDRESS)
                ctrlType   = `CALL;
            else 
                ctrlType   = `JUMP_TYPE;

            //ctrlInst   = 1'b1;
            // valid already considers fetchLaneActive and flows from Fetch1.
            // Should be taken care of by isolation cell. This redundant logic
            // is to make sure this works even in case of clock gated design.
            ctrlInst   = fs2Packet_i.valid;
        end

        `OP_JALR:
        begin
            predNPC    = fs2Packet_i.takenPC; //Indirect Jump, target can't be computed here
            if(rd == `REG_RETURN_ADDRESS)
                ctrlType   = `CALL; 
            else if ((rd == `REG_ZERO) && (rs1 == `REG_RETURN_ADDRESS))
                ctrlType   = `RETURN; 
            else 
                ctrlType   = `JUMP_TYPE;

            //ctrlInst   = 1'b1;
            // valid already considers fetchLaneActive and flows from Fetch1.
            // Should be taken care of by isolation cell. This redundant logic
            // is to make sure this works even in case of clock gated design.
            ctrlInst   = fs2Packet_i.valid;
        end

        `OP_BRANCH:
        begin
            if (fs2Packet_i.predDir)
            begin
                predNPC  = fs2Packet_i.pc + sign_ex_immed_SB;
            end
            else
            begin
                predNPC  = fs2Packet_i.pc + 4;
            end

            ctrlType   = `COND_BRANCH;

            //ctrlInst   = 1'b1;
            // valid already considers fetchLaneActive and flows from Fetch1.
            // Should be taken care of by isolation cell. This redundant logic
            // is to make sure this works even in case of clock gated design.
            ctrlInst   = fs2Packet_i.valid;
        end

    endcase
end

endmodule
