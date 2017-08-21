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

`timescale 1ns/1ps

module simulate();

	parameter DEPTH = `RAM_CONFIG_DEPTH;
	parameter INDEX = `RAM_CONFIG_INDEX;
	parameter WIDTH = `RAM_CONFIG_WIDTH;
  parameter RD_PORTS = `RAM_CONFIG_RP;
  parameter WR_PORTS = `RAM_CONFIG_WP;
  parameter RESET_VAL = `RAM_RESET_ZERO; //RAM_RESET_SEQ or RAM_RESET_ZERO
  parameter SEQ_START = 0;      // valid only when RESET_VAL = "SEQ"
  parameter NUM_PARTS = `RAM_CONFIG_PARTS;

  localparam WRITE_PORT_GATED = 8'b00000000;
  localparam READ_PORT_GATED = 16'b0000000000000000;
  real CLKPERIOD = `CLKPERIOD;

  // The next piece of code implements turning of parts
  // of the RAM
  parameter ACTIVE_INDEX = `RAM_CONFIG_ACTIVE_INDEX;
  reg [NUM_PARTS-1:0] partitionGated;
  int                 ACTIVE_DEPTH;
  initial
  begin
    int i;
    partitionGated  = 0;
    ACTIVE_DEPTH    = DEPTH;

    `ifdef RAM_CONFIG_ACTIVE_DEPTH
      ACTIVE_DEPTH  = `RAM_CONFIG_ACTIVE_DEPTH;
      for (i = 0; i < NUM_PARTS; i++)
      begin
        if(ACTIVE_DEPTH < (DEPTH/NUM_PARTS*(i+1)))
          partitionGated[i] = 1'b1;
      end
    `endif
    //`else
      //case (INDEX-ACTIVE_INDEX)
      //  'd0: partitionGated = {(NUM_PARTS){1'b0}}; // None of the partitions gated
      //  'd1: partitionGated = {{(NUM_PARTS/2){1'b1}},{(NUM_PARTS/2){1'b0}}}; //Half the partitions gated
      //  'd2: partitionGated = {{(NUM_PARTS/2+NUM_PARTS/4){1'b1}},{(NUM_PARTS/4){1'b0}}}; //Quarter of the partitions gated
      //  'd3: partitionGated = {{(NUM_PARTS/2+NUM_PARTS/4+NUM_PARTS/8){1'b1}},{(NUM_PARTS/8){1'b0}}}; //One eigth of the partitions gated
      //  default: partitionGated = {(NUM_PARTS){1'b0}}; // None of the partitions gated
      //endcase
    //`endif
  end

  reg [WR_PORTS-1:0]       writePortGated;
  reg [RD_PORTS-1:0]       readPortGated;

	reg [RD_PORTS-1:0][INDEX-1:0]       addr_i;
	wire [RD_PORTS-1:0][WIDTH-1:0]      data_o;

	reg [WR_PORTS-1:0][INDEX-1:0]       addrwr_i;
	reg [WR_PORTS-1:0][WIDTH-1:0]       datawr_i;

	reg [WR_PORTS-1:0][INDEX-1:0]       randomWrAddr;
	reg [RD_PORTS-1:0][INDEX-1:0]       randomRdAddr;


	reg [WR_PORTS-1:0]            wrEn_i;

	reg                           clk;
	reg                           reset;
  reg                           ramReady;

  // This is the golden model RAM used to verify the read values
  reg [WIDTH-1:0] checker_ram[DEPTH-1:0];
  int iterationCount;
  reg wrongDataFlag;

`ifdef DUMP_SAIF  
  $read_lib_saif("./Library_fwd.saif");
  $set_toggle_region(simulate.dut); 
  $toggle_start();
`endif

`ifdef POWER_SIM
  `define WAVES
`endif

`ifdef WAVES
`ifdef POWER_SIM
  always @(posedge ramReady)
`else
  initial
`endif
  begin
    $dumpfile("waves.vcd");
    $dumpvars(0,dut);
    $dumplimit(600000000);
    $dumpon;
  end

  initial
  begin
    $shm_open("waves.shm");
    $shm_probe(simulate, "ACM");
  end
`endif  

`ifdef POWER_SIM
  `ifdef USE_SDF
    initial
    begin
      $sdf_annotate("./RAM.sdf",dut,,"sdffile.log");
    end
  `endif
`endif


  initial
  begin
    $display("Clock Period is %f ns",CLKPERIOD);
    clk             = 1'b0;
    ramReady        = 1'b0;
    iterationCount  = 0;
    wrongDataFlag   = 1'b0;
    reset           = 1'b1;
    writePortGated  = WRITE_PORT_GATED;
    readPortGated   = READ_PORT_GATED;
    wrEn_i          = {WR_PORTS{1'b0}};
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

    // Deassert reset
    #(10*CLKPERIOD)  reset = 1'b0;

    reset_ram();

  `ifdef POWER_SIM
    #(1000*CLKPERIOD);
  `else
    #(5000*CLKPERIOD);
  `endif
    
`ifdef DUMP_SAIF    
    $toggle_stop();
    $toggle_report("RAM_PARTITIONED.saif",1.0e-9,"simulate.dut");
`endif    

`ifdef WAVES    
    $dumpflush;
    $shm_close();
`endif    

    $finish(0);
  end

  always @(posedge ramReady)
    $display("--------------Finally RAM is ready -----------------\n");

  always #(CLKPERIOD/2.0) clk = ~clk;

  // Force all the inputs to be 0
  initial
  begin
    int i;
    int j;
    for(i = 0; i < WR_PORTS; i++)
    begin
      randomWrAddr[i] = $random;
      addrwr_i[i] = 0;
      datawr_i[i] = 0;
      wrEn_i[i]   = 0;
    end

    for(j = 0; j < RD_PORTS; j++)
    begin
      randomRdAddr[j] = $random;
      addr_i[j] = 0;
    end
  end

  // Testbench logic
  always @(posedge clk)
  begin
    int i;
    int j;
    int k;

    if(~reset & ramReady)
    begin
      for(i = 0; i < WR_PORTS; i++)
      begin
        randomWrAddr[i] <= $random;
        //addrwr_i[i] <= {{INDEX-ACTIVE_INDEX{1'b0}},randomWrAddr[i][ACTIVE_INDEX-1:0]} % ACTIVE_DEPTH;
        addrwr_i[i] <= randomWrAddr[i] % ACTIVE_DEPTH;

        // Use a loop to fill the whole data with random, since $random only returns
        // only 32 bits.
        for(k = 0; k < (((WIDTH+31)/32)-1); k++)
          datawr_i[i][32*k +: 32] <= $random;
        datawr_i[i][WIDTH-1 : (((WIDTH+31)/32)-1)*32] <= $random;

        wrEn_i[i]   <= 1'b1;
        //wrEn_i[i]   <= $random;
        //writePortGated[i] <= $random;
      end

      for(j = 0; j < RD_PORTS; j++)
      begin
        randomRdAddr[j] <= $random;
        //addr_i[j] <= {{INDEX-ACTIVE_INDEX{1'b0}},randomRdAddr[j][ACTIVE_INDEX-1:0]} % ACTIVE_DEPTH;
        addr_i[j] <= randomRdAddr[j] % ACTIVE_DEPTH;
        //readPortGated[i] <= $random;
      end
    end


    if(~reset & ramReady)
    begin
      int i;
      $display("\n------------- Iteration %d ---------\n",iterationCount);
      for(i = 0; i < WR_PORTS; i++)
      begin
        //assert(addrwr_i[i] < ACTIVE_DEPTH);
        if(wrEn_i[i] & ~writePortGated[i])
        begin
          checker_ram[addrwr_i[i]] <= datawr_i[i];
          $display("\nData written: wrPort: %X addr: %X data %X",i,addrwr_i[i],datawr_i[i]);
        end
      end
      iterationCount++;
    end

    if(~reset & ramReady)
    begin
      int i;
      for(i = 0; i < RD_PORTS; i++)
      begin
        assert(addr_i[i] < ACTIVE_DEPTH);
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
      begin
        $display("Observed error while reading data");
        $finish();
      end
    end

  end



  `ifdef IQPAYLOAD_RAM
    IQPAYLOAD_RAM_PARTITIONED #(
  `elsif PRF_RAM
    PRF_RAM_PARTITIONED #(
  `endif

`ifndef POWER_SIM    
  	/* Parameters */
    .RPORT(RD_PORTS),
    .WPORT(WR_PORTS),
  	.DEPTH(DEPTH),
  	.INDEX(INDEX),
  	.WIDTH(WIDTH)
`endif    

  ) dut
  (
  
  	  .addr0_i  (addr_i[0]),
  	  .data0_o  (data_o[0]),
 
    `ifdef READ_TWO_WIDE
  	  .addr1_i  (addr_i[1]),
  	  .data1_o  (data_o[1]),
    `endif
  
    `ifdef READ_THREE_WIDE
  	  .addr2_i  (addr_i[2]),
  	  .data2_o  (data_o[2]),
    `endif
 
    `ifdef READ_FOUR_WIDE
  	  .addr3_i  (addr_i[3]),
  	  .data3_o  (data_o[3]),
     `endif
 
    `ifdef READ_FIVE_WIDE
  	  .addr4_i  (addr_i[4]),
  	  .data4_o  (data_o[4]),
    `endif
 
    `ifdef READ_SIX_WIDE
  	  .addr5_i  (addr_i[5]),
  	  .data5_o  (data_o[5]),
    `endif
 
    `ifdef READ_SEVEN_WIDE
  	  .addr6_i  (addr_i[6]),
  	  .data6_o  (data_o[6]),
    `endif
 
    `ifdef READ_EIGHT_WIDE
  	  .addr7_i  (addr_i[7]),
  	  .data7_o  (data_o[7]),
    `endif

    `ifdef READ_NINE_WIDE
  	  .addr8_i(addr_i[8]),
  	  .data8_o(data_o[8]),
    `endif

    `ifdef READ_TEN_WIDE
  	  .addr9_i(addr_i[9]),
  	  .data9_o(data_o[9]),
    `endif

    `ifdef READ_ELEVEN_WIDE
  	  .addr10_i(addr_i[10]),
  	  .data10_o(data_o[10]),
    `endif

    `ifdef READ_TWELVE_WIDE
  	  .addr11_i(addr_i[11]),
  	  .data11_o(data_o[11]),
    `endif

    `ifdef READ_THIRTEEN_WIDE
  	  .addr12_i(addr_i[12]),
  	  .data12_o(data_o[12]),
    `endif

    `ifdef READ_FOURTEEN_WIDE
  	  .addr13_i(addr_i[13]),
  	  .data13_o(data_o[13]),
    `endif

    `ifdef READ_FIFTEEN_WIDE
  	  .addr14_i(addr_i[14]),
  	  .data14_o(data_o[14]),
    `endif

    `ifdef READ_SIXTEEN_WIDE
  	  .addr15_i(addr_i[15]),
  	  .data15_o(data_o[15]),
    `endif
  
   	  .addr0wr_i(addrwr_i[0]),
  	  .data0wr_i(datawr_i[0]),
  	  .we0_i    (wrEn_i[0]),
  
    `ifdef WRITE_TWO_WIDE
  	  .addr1wr_i(addrwr_i[1]),
  	  .data1wr_i(datawr_i[1]),
  	  .we1_i    (wrEn_i[1]),
    `endif
 
    `ifdef WRITE_THREE_WIDE
  	  .addr2wr_i(addrwr_i[2]),
  	  .data2wr_i(datawr_i[2]),
  	  .we2_i    (wrEn_i[2]),
    `endif
 
    `ifdef WRITE_FOUR_WIDE
  	  .addr3wr_i(addrwr_i[3]),
  	  .data3wr_i(datawr_i[3]),
  	  .we3_i    (wrEn_i[3]),
    `endif

    `ifdef WRITE_FIVE_WIDE
  	  .addr4wr_i(addrwr_i[4]),
  	  .data4wr_i(datawr_i[4]),
  	  .we4_i    (wrEn_i[4]),
    `endif
 
    `ifdef WRITE_SIX_WIDE
  	  .addr5wr_i(addrwr_i[5]),
  	  .data5wr_i(datawr_i[5]),
  	  .we5_i    (wrEn_i[5]),
    `endif
 
    `ifdef WRITE_SEVEN_WIDE
  	  .addr6wr_i(addrwr_i[6]),
  	  .data6wr_i(datawr_i[6]),
  	  .we6_i    (wrEn_i[6]),
    `endif
 
    `ifdef WRITE_EIGHT_WIDE
  	  .addr7wr_i(addrwr_i[7]),
  	  .data7wr_i(datawr_i[7]),
  	  .we7_i    (wrEn_i[7]),
    `endif


    `ifdef IQPAYLOAD_RAM
      .issueLaneActive_i    (~readPortGated),
      .dispatchLaneActive_i (~writePortGated),
      .iqPartitionActive_i  (~partitionGated),
    `elsif PRF_RAM
      .execLaneActive_i     (~writePortGated),
      .rfPartitionActive_i  (~partitionGated),
    `endif

  	  .clk(clk)
  );

task reset_ram;
  int i;
  for (i=0;i<DEPTH;i++)
  begin
    wait(clk == 0);
    addrwr_i[0] = i;
    datawr_i[0] = {WIDTH{1'b0}};
    wrEn_i[0]   = 1'b1;
    wait(clk == 1);
    #(CLKPERIOD/10);
  end
    
  wrEn_i[0] = 1'b0;

  #(2*CLKPERIOD);
  ramReady = 1'b1;

endtask

endmodule 
