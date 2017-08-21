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

module MMU
(
  input                               clk,
  input  [`SIZE_DATA-1:0]             virtAddress_i,
  input  [`SIZE_DATA_BYTE_OFFSET-1:0] numBytes_i,
  input                               ldAccess_i,
  input                               stAccess_i,
  input                               instAccess_i,
  output reg [7:0]                    exception_o
);

// synopsys translate_off

int memAccessBytes;
int exception;
logic [`SIZE_DATA-1:0]        phyAddress;

always @(*)
begin
  memAccessBytes = numBytes_i;
  exception_o    = exception;
end

always @(negedge clk)
begin
  if(ldAccess_i | stAccess_i | instAccess_i)
  begin
    phyAddress <= virt_to_phys(virtAddress_i, numBytes_i, stAccess_i, instAccess_i, exception);
  end
  else
    exception <= 0;
end

// synopsys translate_on

endmodule

