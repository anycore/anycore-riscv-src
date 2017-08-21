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

module LDQ_RAM_PARTITIONED #(
	/* Parameters */
  parameter RPORT = 1,
  parameter WPORT = 1,
	parameter DEPTH = `RAM_CONFIG_DEPTH, 
	parameter INDEX = `RAM_CONFIG_INDEX, 
	parameter WIDTH = `RAM_CONFIG_WIDTH 
) (

	input  [INDEX-1:0]       addr0_i,
	output [WIDTH-1:0]       data0_o,
	                         
	input  [INDEX-1:0]       addr1_i,
	output [WIDTH-1:0]       data1_o,
	                         
                           
	input  [INDEX-1:0]       addr0wr_i,
	input  [WIDTH-1:0]       data0wr_i,
	input                    we0_i,
                           
	//input  [INDEX-1:0]       addr1wr_i,
	//input  [WIDTH-1:0]       data1wr_i,
	//input                    we1_i,
                           

  input [`STRUCT_PARTS_LSQ-1:0]    lsqPartitionActive_i,
  output                       stqRamReady_o,

	//input                    reset,
	input                    clk
);


  //wire [1:0]                we;
  //wire [1:0][INDEX-1:0]     addrWr;
  //wire [1:0][WIDTH-1:0]     dataWr;
  logic [0:0]                we;
  logic [0:0][INDEX-1:0]     addrWr;
  logic [0:0][WIDTH-1:0]     dataWr;

  logic [1:0][INDEX-1:0]     addr;
  logic [1:0][WIDTH-1:0]     rdData;

  //wire [1:0]                writePortGated;
  logic [0:0]                writePortGated;
  logic [1:0]                readPortGated;
  logic [`STRUCT_PARTS_LSQ-1:0]  partitionGated;

  assign writePortGated   = 2'b00;
  assign readPortGated    = 2'b00;
  assign partitionGated   = ~lsqPartitionActive_i;


  assign we[0] = we0_i;
  assign addrWr[0] = addr0wr_i;
  assign dataWr[0] = data0wr_i;

  //assign we[1] = we1_i;
  //assign addrWr[1] = addr1wr_i;
  //assign dataWr[1] = data1wr_i;
  

  localparam NUM_RD_PORTS = 2;
  localparam NUM_WR_PORTS = 1; 
  localparam NUM_PARTS = `STRUCT_PARTS_LSQ;
  localparam NUM_PARTS_LOG = `STRUCT_PARTS_LSQ_LOG;

  wire [NUM_RD_PORTS-1:0][WIDTH-1:0] rdDataPartition[NUM_PARTS-1:0];
  wire [NUM_RD_PORTS-1:0][INDEX-NUM_PARTS_LOG-1:0]  addrPartition;
  wire [NUM_WR_PORTS-1:0][INDEX-NUM_PARTS_LOG-1:0]  addrWrPartition;
  wire [NUM_RD_PORTS-1:0][NUM_PARTS_LOG-1:0]  addrPartSelect;
  wire [NUM_WR_PORTS-1:0][NUM_PARTS_LOG-1:0]  addrWrPartSelect;
  wire [NUM_PARTS-1:0]  ramReady;


  genvar rp;
  genvar wp;
  genvar wp1;
  genvar part;
  generate
    for(rp = 0; rp < NUM_RD_PORTS; rp++)
    begin
      if(NUM_PARTS == 1)
      begin
        assign addrPartition[rp]   = addr[rp];
        assign addrPartSelect[rp]  = 1'b0;
      end
      else
      begin
        assign addrPartition[rp]   = addr[rp][INDEX-NUM_PARTS_LOG-1:0];
        assign addrPartSelect[rp]  = addr[rp][INDEX-1:INDEX-NUM_PARTS_LOG];
      end
    end

    for(wp = 0; wp < NUM_WR_PORTS; wp++)
    begin
      if(NUM_PARTS == 1)
      begin
        assign addrWrPartition[wp]   = addrWr[wp];
        assign addrWrPartSelect[wp]  = 1'b0;
      end
      else
      begin
        assign addrWrPartition[wp]   = addrWr[wp][INDEX-NUM_PARTS_LOG-1:0];
        assign addrWrPartSelect[wp]  = addrWr[wp][INDEX-1:INDEX-NUM_PARTS_LOG];
      end
    end

    for(part = 0; part < NUM_PARTS; part++)//For every dispatch lane read port pair
    begin:INST_LOOP
      wire [NUM_WR_PORTS-1:0] writeEnPartition;
      for(wp1 = 0; wp1 < NUM_WR_PORTS; wp1++)//For every dispatch lane write port
      begin
        assign writeEnPartition[wp1]  = (~writePortGated[wp1]) & we[wp1] & |(addrWrPartSelect[wp1] == part);
//        assign writeEnPartition[wp1]  = we[wp1] & |(addrWrPartSelect[wp1] == part);
      end

      LDQ_RAM #(
        .RPORT      (RPORT),
        .WPORT      (WPORT),
      	.DEPTH      (DEPTH/NUM_PARTS),
      	.INDEX      (INDEX-NUM_PARTS_LOG),
      	.WIDTH      (WIDTH)
      	)
      
      	ram_inst (
      
      	.addr0_i    (addrPartition[0]),
      	.data0_o    (rdDataPartition[part][0]),
      
      	.addr1_i    (addrPartition[1]),
      	.data1_o    (rdDataPartition[part][1]),
      
      
      
      	.addr0wr_i  (addrWrPartition[0]),
      	.we0_i      (writeEnPartition[0]),
      	.data0wr_i  (dataWr[0]),
      
      
      	//.reset      (reset),
      	.clk        (clk)
      
    	);

    end //for INSTANCE_LOOP
  endgenerate

  /* Read operation */
  always @(*) 
  begin
    int rp;
    for(rp = 0; rp< NUM_RD_PORTS; rp++)
    begin
      rdData[rp] = rdDataPartition[addrPartSelect[rp]][rp];
    end
  end

endmodule

