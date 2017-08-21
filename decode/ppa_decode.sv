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

module ppa_decode
(

	input                                clk,
	input                                reset,

`ifdef DYNAMIC_CONFIG
  input [`FETCH_WIDTH-1:0]             fetchLaneActive_i,
`endif


	input  decPkt                        decPacket_i [0:`FETCH_WIDTH-1],

	input                                fs2Ready_i,

`ifdef DYNAMIC_CONFIG
	output reg [`FETCH_WIDTH-1:0]        valid_bundle_o,
`endif

	output reg                           fs2Ready_o,


  // Number of ibPacket is twice the number of decPacket because potentially,
  // each instruction can be a complex instruction and can be split into two
  // parts
	output renPkt                       ibPacket_o  [0:2*`FETCH_WIDTH-1],

	output                              decodeReady_o,

  // Some common inputs needed in many stages
  input                               resetFetch_i,
  input                               recoverFlag_i,

  input                               exceptionFlag_i,


  input                               instBufferFull_i,
  input                               ctiQueueFull_i
);

	decPkt                     decPacket_l1 [0:`FETCH_WIDTH-1];
  wire                       fs2Ready_l1; 

  Fetch2Decode fs2dec(
  	.clk                  (clk),
  	.reset                (reset),
  	.flush_i              (recoverFlag_i | exceptionFlag_i | resetFetch_i),
  	.stall_i              (instBufferFull_i),
  
  `ifdef DYNAMIC_CONFIG  
    .laneActive_i         (fetchLaneActive_i),
  	.valid_bundle_o       (valid_bundle_o),
  `endif
  
  	.updatePC_i           ({`SIZE_PC{1'b0}}), 
  	.updateNPC_i          ({`SIZE_PC{1'b0}}), 
  	.updateCtrlType_i     ({`BRANCH_TYPE_LOG{1'b0}}), 
  	.updateDir_i          (1'b0), 
  	.updateCounter_i      (2'b0), 
  	.updateEn_i           (1'b0), 
  
  	.fs2Ready_i           (fs2Ready_i),
  
  	.decPacket_i          (decPacket_i),
  	.decPacket_o          (decPacket_l1),
  
  	.updatePC_o           (),
  	.updateNPC_o          (),
  	.updateCtrlType_o     (),
  	.updateDir_o          (),
  	.updateCounter_o      (),
  	.updateEn_o           (),
  
  	.fs2Ready_o           (fs2Ready_l1)
  	);
  
  
  
   /**********************************************************************************
   * "decode" module decodes the incoming instruction and generate appropriate
   * signals required by the rest of the pipeline stages.
   **********************************************************************************/
  
  // NOTE: Already per lane and can be easily power gated
  Decode decode (
  	.clk                  (clk),
  	.reset                (reset),
  
  `ifdef DYNAMIC_CONFIG  
    .fetchLaneActive_i    (fetchLaneActive_i),
  `endif  
  
  	.fs2Ready_i           (fs2Ready_l1),
  
  	.decPacket_i          (decPacket_l1),
  
  	.ibPacket_o           (ibPacket_o),
  
  	.decodeReady_o        (decodeReady_o)
  	);



endmodule
