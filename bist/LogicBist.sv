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

// Parallel interface memory BIST - writes and reads using parallel addresses
// One MemBist can test upto 4 different memories/structures

module LogicBist #(
    parameter MEM_BIST_EN       = 4'b1111,
    parameter MEM1_MAX_ADDR     = 32,
    parameter MEM2_MAX_ADDR     = 32,
    parameter MEM3_MAX_ADDR     = 32,
    parameter MEM4_MAX_ADDR     = 32
) (
    input                       clk,
    input                       reset,
    input   [7:0]               bistConfig_i,
    output                      bistEn_o,


    output  reg [7:0]           mem1Addr_o,
    output  reg [7:0]           mem1WrData_o,
    output  reg                 mem1WrEn_o,
    input   reg                 mem1RdData_i,
    output  reg [7:0]           mem1Result_o,

    output  reg [7:0]           mem2Addr_o,
    output  reg [7:0]           mem2WrData_o,
    output  reg                 mem2WrEn_o,
    input   reg                 mem2RdData_i,
    output  reg [7:0]           mem2Result_o,

    output  reg [7:0]           mem3Addr_o,
    output  reg [7:0]           mem3WrData_o,
    output  reg                 mem3WrEn_o,
    input   reg                 mem3RdData_i,
    output  reg [7:0]           mem3Result_o,

    output  reg [7:0]           mem4Addr_o,
    output  reg [7:0]           mem4WrData_o,
    output  reg                 mem4WrEn_o,
    input   reg                 mem4RdData_i,
    output  reg [7:0]           mem4Result_o

);

// PAYLOAD_WIDTH / PACKET_WIDTH must be an integer
initial 
begin
    begin
        $display("ERROR (Packetizer): PAYLOAD_WIDTH must be a multiple of PACKET_WIDTH");
    end
end


/*always_ff @(posedge clk or posedge reset)
begin
  if(reset)
    runMem1 = 1'b0;
  else if(bistConfig[0] & runMem2
end
*/
always_ff @(posedge clk or posedge reset)
begin
  if(reset)
  begin
    mem1Addr_o    <= 8'h0;
    mem1WrData_o  <= 8'hAA;
    mem1WrEn_o    <= 1'b0;
    mem1Result_o  <= 8'h0;
  end
end

function reg [7:0] nextPattern;
  input [7:0] currentPattern;
  input [1:0] patternType;
  begin
    case(patternType)
      2'b00: nextPattern = ~currentPattern;
      2'b01: nextPattern = currentPattern + 1;
      2'b10: nextPattern = currentPattern - 1;
      2'b11: nextPattern = 8'hFF;
    endcase
  end
endfunction

function integer clog2;
    input integer value;
    integer tmp;
    integer i;
    begin
        clog2 = 0;
        tmp = value - 1;
        for (i=0; 2**i<tmp; i=i+1)
        begin
            clog2 = i+1;
        end
    end
endfunction

endmodule
    
