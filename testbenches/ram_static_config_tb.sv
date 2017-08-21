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

module simulate();

	parameter DEPTH = 128;
	parameter INDEX = 7;
	parameter WIDTH = 32;
  parameter NUM_WR_PORTS = 8;
  parameter NUM_RD_PORTS = 16;
  parameter WR_PORTS_LOG = 3;
  parameter RESET_VAL = `RAM_RESET_ZERO; //RAM_RESET_SEQ or RAM_RESET_ZERO
  parameter SEQ_START = 0;      // valid only when RESET_VAL = "SEQ"

  reg [NUM_WR_PORTS-1:0]       writePortGated;
  reg [NUM_RD_PORTS-1:0]       readPortGated;

	reg [NUM_RD_PORTS-1:0][INDEX-1:0]       addr_i;
	wire [NUM_RD_PORTS-1:0][WIDTH-1:0]      data_o;

	reg [NUM_WR_PORTS-1:0][INDEX-1:0]       addrWr_i;
	reg [NUM_WR_PORTS-1:0][WIDTH-1:0]       dataWr_i;

	reg [NUM_WR_PORTS-1:0]       wrEn_i;

	reg                          clk;
	reg                          reset;
  wire                         ramReady;

  // This is the golden model RAM used to verify the read values
  reg [WIDTH-1:0] checker_ram[DEPTH-1:0];
  int iterationCount;
  reg wrongDataFlag;

  initial
  begin
    $dumpfile("waves.vcd");
    $dumpvars(0,dut);
    $dumplimit(600000000);
    $dumpon;
  end

  initial
  begin
    clk = 1'b0;
    iterationCount = 0;
    wrongDataFlag = 1'b0;
    reset = 1'b1;
    writePortGated = 8'b00000000;
    readPortGated  = 16'b0000000000000000;
    wrEn_i  = {NUM_WR_PORTS{1'b0}};
    if(RESET_VAL == `RAM_RESET_SEQ)
    begin
      int k;
      for(k=0; k < DEPTH; k++)
        checker_ram[k] <= SEQ_START+k;
    end
    else if(RESET_VAL == `RAM_RESET_ZERO)
    begin
      int l;
      for(l=0; l < DEPTH; l++)
        checker_ram[l] <= 0;
    end
    #100 reset = 1'b0;
    #2000000;
    $finish();
    $dumpflush;
  end

  always #10 clk = ~clk;

  // Testbench logic
  always @(posedge clk)
  begin
    int i;
    int j;
    for(i = 0; i < NUM_WR_PORTS; i++)
    begin
      addrWr_i[i] <= $random;
      dataWr_i[i] <= $random;
      wrEn_i[i]   <= $random;
      //writePortGated[i] <= $random;
    end

    for(j = 0; j < NUM_RD_PORTS; j++)
    begin
      addr_i[j] <= $random;
      //readPortGated[i] <= $random;
    end
    if(~reset & ramReady)
      $display("\n------------- Iteration %d ---------\n",iterationCount);
  end

  // The generate ensures generation of priority logic when port numbers are the same
  genvar i;
  generate
    for(i = 0; i < NUM_WR_PORTS; i++)
    always_ff @(posedge clk)
    begin
      if(~reset & ramReady)
      begin
        begin
          if(wrEn_i[i] & ~writePortGated[i])
          begin
            checker_ram[addrWr_i[i]] <= dataWr_i[i];
            $display("\nData written: wrPort: %X addr: %X data %X",i,addrWr_i[i],dataWr_i[i]);
          end
        end
      end
    end
  endgenerate

  always @(posedge clk)
  begin
    if(~reset & ramReady)
    begin
      int i;
      for(i = 0; i < NUM_RD_PORTS; i++)
      begin
        if(~readPortGated[i])
        begin
          if(data_o[i] == checker_ram[addr_i[i]])
            $display("\nCorrect data read: addr: %X Read: %X  Expected: %X",addr_i[i],data_o[i],checker_ram[addr_i[i]]);
          else
          begin
            wrongDataFlag = 1'b1;
            $display("\nWrong data read: addr: %X Read: %X  Expected: %X",addr_i[i],data_o[i],checker_ram[addr_i[i]]);
          end
        end
      end
      if(wrongDataFlag)
        $stop;

      iterationCount++;
    end
  end


  RAM_STATIC_CONFIG #(
  	/* Parameters */
`ifndef POWER_SIM    
  	.DEPTH(DEPTH),
  	.INDEX(INDEX),
  	.WIDTH(WIDTH),
    .NUM_WR_PORTS(NUM_WR_PORTS),
    .NUM_RD_PORTS(NUM_RD_PORTS),
    .WR_PORTS_LOG(WR_PORTS_LOG),
    .RESET_VAL(RESET_VAL),
    .SEQ_START(SEQ_START),
    .LATCH_BASED_RAM(1)
`endif    
  ) dut
  (
  
    .writePortGated_i(writePortGated),
    .readPortGated_i(readPortGated),
    .ramGated_i(1'b0),
  
  	.addr_i(addr_i),
  	.data_o(data_o),
  
  	.addrWr_i(addrWr_i),
  	.dataWr_i(dataWr_i),
  
  	.wrEn_i(wrEn_i),
  
  	.clk(clk),
  	.reset(reset),
    .ramReady_o(ramReady)
  );

endmodule 
