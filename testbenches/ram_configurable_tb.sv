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
	parameter WIDTH = 8;
  parameter NUM_WR_PORTS = 8;
  parameter NUM_RD_PORTS = 16;
  parameter WR_PORTS_LOG = 3;
  //parameter RESET_VAL = `RAM_RESET_SEQ; //RAM_RESET_SEQ or RAM_RESET_ZERO
  parameter RESET_VAL = `RAM_RESET_ZERO; //RAM_RESET_SEQ or RAM_RESET_ZERO
  parameter SEQ_START = 34;      // valid only when RESET_VAL = "SEQ"

  localparam WRITE_PORT_GATED = 8'b00000000;
  localparam READ_PORT_GATED = 16'b0000000000000000;

  // The next piece of code implements turning of parts
  // of the RAM
  parameter ACTIVE_INDEX = 5;
  reg [3:0] partitionGated;
  initial
  begin
    partitionGated = 4'b0000;
    case (INDEX-ACTIVE_INDEX)
      'd1: partitionGated = 4'b1100;
      'd2: partitionGated = 4'b1110;
      'd3: partitionGated = 4'b1110;
      'd4: partitionGated = 4'b1110;
      'd5: partitionGated = 4'b1110;
      'd6: partitionGated = 4'b1110;
      'd7: partitionGated = 4'b1110;
      'd8: partitionGated = 4'b1110;
      'd9: partitionGated = 4'b1110;
      default: partitionGated = 4'b0000;
    endcase
  end

`ifdef DUMP_SAIF  
  $read_lib_saif("./Library_fwd.saif");
  $set_toggle_region(simulate.dut); 
  $toggle_start();
`endif

`ifdef POWER_SIM
  initial
  begin
    $dumpfile("waves.vcd");
    $dumpvars(0,dut);
    $dumplimit(600000000);
    $dumpon;
  end
`endif  

  reg [NUM_WR_PORTS-1:0]       writePortGated;
  reg [NUM_RD_PORTS-1:0]       readPortGated;

	reg [NUM_RD_PORTS-1:0][INDEX-1:0]       addr_i;
	wire [NUM_RD_PORTS-1:0][WIDTH-1:0]      data_o;

	reg [NUM_WR_PORTS-1:0][INDEX-1:0]       addrWr_i;
	reg [NUM_WR_PORTS-1:0][WIDTH-1:0]       dataWr_i;

	reg [NUM_WR_PORTS-1:0][INDEX-1:0]       randomWrAddr;
	reg [NUM_RD_PORTS-1:0][INDEX-1:0]       randomRdAddr;


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
    clk = 1'b0;
    iterationCount = 0;
    wrongDataFlag = 1'b0;
    reset = 1'b1;
    writePortGated = WRITE_PORT_GATED;
    readPortGated  = READ_PORT_GATED;
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
    #100  reset = 1'b0;

    #50000;
`ifdef DUMP_SAIF    
    $toggle_stop();
    $toggle_report("RAM_PARTITIONED.saif",1.0e-9,"simulate.dut");
`endif    
    $finish();
`ifdef POWER_SIM    
    $dumpflush;
`endif    
  end

  always @(posedge ramReady)
    $display("--------------Finally RAM is ready -----------------\n");

  always #10 clk = ~clk;

  // Testbench logic
  always @(posedge clk)
  begin
    int i;
    int j;
    for(i = 0; i < NUM_WR_PORTS; i++)
    begin
      randomWrAddr[i] <= $random;
      addrWr_i[i] <= {{INDEX-ACTIVE_INDEX{1'b0}},randomWrAddr[i][ACTIVE_INDEX-1:0]};
      dataWr_i[i] <= $random;
      wrEn_i[i]   <= $random;
      //writePortGated[i] <= $random;
    end

    for(j = 0; j < NUM_RD_PORTS; j++)
    begin
      randomRdAddr[j] <= $random;
      addr_i[j] <= {{INDEX-ACTIVE_INDEX{1'b0}},randomRdAddr[j][ACTIVE_INDEX-1:0]};
      //readPortGated[i] <= $random;
    end


    if(~reset & ramReady)
    begin
      int i;
      $display("\n------------- Iteration %d ---------\n",iterationCount);
      for(i = 0; i < NUM_WR_PORTS; i++)
      begin
        if(wrEn_i[i] & ~writePortGated[i])
        begin
          checker_ram[addrWr_i[i]] <= dataWr_i[i];
          $display("\nData written: wrPort: %X addr: %X data %X",i,addrWr_i[i],dataWr_i[i]);
        end
      end
      iterationCount++;
    end

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
    end

  end


  RAM_CONFIGURABLE #(

`ifndef POWER_SIM    
  	/* Parameters */
  	.DEPTH(DEPTH),
  	.INDEX(INDEX),
  	.WIDTH(WIDTH),
    .NUM_WR_PORTS(NUM_WR_PORTS),
    .NUM_RD_PORTS(NUM_RD_PORTS),
    .WR_PORTS_LOG(WR_PORTS_LOG),
    .USE_RAM_2READ(0),
    .SHARED_DECODE(0), // If this is 1, PARTITIONED_BNO_DECODE will be used
    .USE_PARTITIONED(1),// If this is 1, depending upon SHARED_DECODE, RAM_PARTITIONED will be used
    .USE_FLIP_FLOP(0),
    .NUM_PARTS(`STRUCT_PARTS),
    .NUM_PARTS_LOG(`STRUCT_PARTS_LOG),
    .RESET_VAL(RESET_VAL),
    .SEQ_START(SEQ_START)
`endif    
  ) dut
  (
  
    .writePortGated_i(writePortGated),
    .readPortGated_i(readPortGated),
    .partitionGated_i(partitionGated),
  
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
