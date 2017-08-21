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

module PriorityEncoderRR #(
	parameter ENCODER_WIDTH = 32
	)(

  input                       clk,
  input                       reset,
	input  [ENCODER_WIDTH-1:0]  vector_i,
	output [ENCODER_WIDTH-1:0]  vector_o
);

/* Mask to reset all other bits except the first */
reg  [ENCODER_WIDTH-1:0]  mask;

wire [ENCODER_WIDTH-1:0]  vector;

assign vector_o = vector;

/* Mask the input vector so that only the first 1'b1 is seen */
assign vector = vector_i & mask;


`ifdef RR_ISSUE_TWO_PARTS
  reg  [ENCODER_WIDTH/2-1:0]  mask0;
  reg  [ENCODER_WIDTH-1:ENCODER_WIDTH/2]  mask1;
  
  always_comb
  begin: ENCODER_CONSTRUCT0
  	int i;
  	mask0[0] = 1'b1;
  
  	for (i = 1; i < ENCODER_WIDTH/2; i++)
  	begin
  		if (vector_i[i-1])
  		begin
  			mask0[i] = 0;
  		end
  
  		else
  		begin
  			mask0[i] = mask0[i-1];
  		end
  	end
  end
  
  always_comb
  begin: ENCODER_CONSTRUCT1
  	int i;
  	mask1[ENCODER_WIDTH/2] = 1'b1;
  
  	for (i = ENCODER_WIDTH/2+1; i < ENCODER_WIDTH; i++)
  	begin
  		if (vector_i[i-1])
  		begin
  			mask1[i] = 0;
  		end
  
  		else
  		begin
  			mask1[i] = mask1[i-1];
  		end
  	end
  end
  
  //reg   [(ENCODER_WIDT/NUM_PARTS)*(NUM_PARTS-1)-1:0]  mask_t;
  //reg   [ENCODER_WIDTH-(ENCODER_WIDTH/NUM_PARTS)*(NUM_PARTS-1)-1:(ENCODER_WIDTH/NUM_PARTS)*(NUM_PARTS-1)] mask_f;
  //genvar g;
  //generate
  //begin
  //  always_comb
  //  begin: ENCODER_CONSTRUCT
  //  	int i;
  //  	mask_t[(ENCODER_WIDTH/NUM_PARTS)*g] = 1'b1;
  //  
  //  	for (i = (ENCODER_WIDTH/NUM_PARTS)*g+1; i < (ENCODER_WIDTH/NUM_PARTS)*(g+1); i++)
  //  	begin
  //  		if (vector_i[i-1])
  //  		begin
  //  			mask_t[i] = 0;
  //  		end
  //  
  //  		else
  //  		begin
  //  			mask_t[i] = mask_t[i-1];
  //  		end
  //  	end
  //  end
  //end
  //endgenerate
  //
  //always_comb
  //begin: ENCODER_CONSTRUCT_LAST
  //	int i;
  //	mask_f[(ENCODER_WIDTH/NUM_PARTS)*(NUM_PARTS-1)] = 1'b1;
  //
  //	for (i = (ENCODER_WIDTH/NUM_PARTS)*(NUM_PARTS-1)+1; i < ENCODER_WIDTH; i++)
  //	begin
  //		if (vector_i[i-1])
  //		begin
  //			mask_f[i] = 0;
  //		end
  //
  //		else
  //		begin
  //			mask_f[i] = mask_f[i-1];
  //		end
  //	end
  //end
  
  
  
  reg toggle;
  always_ff @(posedge clk or posedge reset)
  begin
    if(reset)
      toggle  <=  1'b0;
    else
      toggle  <=  ~toggle;
  end
  
  always_comb
  begin
    case(toggle)
      1'b0:begin
        mask = |vector_i[ENCODER_WIDTH/2-1:0] ? {{ENCODER_WIDTH/2+1{1'b0}},mask0} : {mask1,{ENCODER_WIDTH/2{1'b0}}};
      end
      1'b1:begin
        mask = |vector_i[ENCODER_WIDTH-1:ENCODER_WIDTH/2] ? {mask1,{ENCODER_WIDTH/2{1'b0}}} : {{ENCODER_WIDTH/2+1{1'b0}},mask0};
      end
    endcase
  end
`elsif RR_ISSUE_THREE_PARTS
  reg  [ENCODER_WIDTH/3-1:0]                    mask0;
  reg  [2*(ENCODER_WIDTH/3)-1:ENCODER_WIDTH/3]  mask1;
  reg  [ENCODER_WIDTH-1:2*(ENCODER_WIDTH/3)]    mask2;
  
  always_comb
  begin: ENCODER_CONSTRUCT0
  	int i;
  	mask0[0] = 1'b1;
  
  	for (i = 1; i < ENCODER_WIDTH/3; i++)
  	begin
  		if (vector_i[i-1])
  		begin
  			mask0[i] = 0;
  		end
  
  		else
  		begin
  			mask0[i] = mask0[i-1];
  		end
  	end
  end
  
  always_comb
  begin: ENCODER_CONSTRUCT1
  	int i;
  	mask1[ENCODER_WIDTH/3] = 1'b1;
  
  	for (i = ENCODER_WIDTH/3+1; i < 2*(ENCODER_WIDTH/3); i++)
  	begin
  		if (vector_i[i-1])
  		begin
  			mask1[i] = 0;
  		end
  
  		else
  		begin
  			mask1[i] = mask1[i-1];
  		end
  	end
  end

  always_comb
  begin: ENCODER_CONSTRUCT2
  	int i;
  	mask2[2*(ENCODER_WIDTH/3)] = 1'b1;
  
  	for (i = 2*(ENCODER_WIDTH/3)+1; i < ENCODER_WIDTH; i++)
  	begin
  		if (vector_i[i-1])
  		begin
  			mask2[i] = 0;
  		end
  
  		else
  		begin
  			mask2[i] = mask2[i-1];
  		end
  	end
  end
 
  reg [2:0] toggle;
  always_ff @(posedge clk or posedge reset)
  begin
    if(reset)
      toggle  <=  3'b001;
    else
      toggle  <=  {toggle[1:0],toggle[2]}; //RSR
  end
  
  always_comb
  begin
    case(toggle)
      3'b001:begin
        mask = |vector_i[ENCODER_WIDTH/3-1:0]                               ? {{ENCODER_WIDTH-ENCODER_WIDTH/3{1'b0}},mask0}             : 
               |vector_i[2*(ENCODER_WIDTH/3)-1:ENCODER_WIDTH/3]             ? {{ENCODER_WIDTH/3{1'b0}},mask1,{ENCODER_WIDTH/3{1'b0}}}   :
                                                                              {mask2,{2*(ENCODER_WIDTH/3){1'b0}}};
      end
      3'b010:begin
        mask = |vector_i[2*(ENCODER_WIDTH/3)-1:ENCODER_WIDTH/3]             ? {{ENCODER_WIDTH/3{1'b0}},mask1,{ENCODER_WIDTH/3{1'b0}}}   :
               |vector_i[ENCODER_WIDTH-1:2*(ENCODER_WIDTH/3)]               ? {mask2,{2*(ENCODER_WIDTH/3){1'b0}}}                       :
                                                                              {{ENCODER_WIDTH-ENCODER_WIDTH/3{1'b0}},mask0}; 
      end
      3'b100:begin
        mask = |vector_i[ENCODER_WIDTH-1:2*(ENCODER_WIDTH/3)]               ? {mask2,{2*(ENCODER_WIDTH/3){1'b0}}}                       :
               |vector_i[ENCODER_WIDTH/3-1:0]                               ? {{ENCODER_WIDTH-ENCODER_WIDTH/3{1'b0}},mask0}             : 
                                                                              {{ENCODER_WIDTH/3{1'b0}},mask1,{ENCODER_WIDTH/3{1'b0}}};
      end
    endcase
  end

`else
  reg  [ENCODER_WIDTH/4-1:0]                                mask0;
  reg  [ENCODER_WIDTH/2-1:ENCODER_WIDTH/4]                  mask1;
  reg  [ENCODER_WIDTH/2+ENCODER_WIDTH/4-1:ENCODER_WIDTH/2]  mask2;
  reg  [ENCODER_WIDTH-1:ENCODER_WIDTH/2+ENCODER_WIDTH/4]    mask3;
  
  always_comb
  begin: ENCODER_CONSTRUCT0
  	int i;
  	mask0[0] = 1'b1;
  
  	for (i = 1; i < ENCODER_WIDTH/4; i++)
  	begin
  		if (vector_i[i-1])
  		begin
  			mask0[i] = 0;
  		end
  
  		else
  		begin
  			mask0[i] = mask0[i-1];
  		end
  	end
  end
  
  always_comb
  begin: ENCODER_CONSTRUCT1
  	int i;
  	mask1[ENCODER_WIDTH/4] = 1'b1;
  
  	for (i = ENCODER_WIDTH/4+1; i < ENCODER_WIDTH/2; i++)
  	begin
  		if (vector_i[i-1])
  		begin
  			mask1[i] = 0;
  		end
  
  		else
  		begin
  			mask1[i] = mask1[i-1];
  		end
  	end
  end

  always_comb
  begin: ENCODER_CONSTRUCT2
  	int i;
  	mask2[ENCODER_WIDTH/2] = 1'b1;
  
  	for (i = ENCODER_WIDTH/2+1; i < ENCODER_WIDTH/2+ENCODER_WIDTH/4; i++)
  	begin
  		if (vector_i[i-1])
  		begin
  			mask2[i] = 0;
  		end
  
  		else
  		begin
  			mask2[i] = mask2[i-1];
  		end
  	end
  end

  always_comb
  begin: ENCODER_CONSTRUCT3
  	int i;
  	mask3[ENCODER_WIDTH/2+ENCODER_WIDTH/4] = 1'b1;
  
  	for (i = ENCODER_WIDTH/2+ENCODER_WIDTH/4+1; i < ENCODER_WIDTH; i++)
  	begin
  		if (vector_i[i-1])
  		begin
  			mask3[i] = 0;
  		end
  
  		else
  		begin
  			mask3[i] = mask3[i-1];
  		end
  	end
  end
  
  
  reg [1:0] toggle;
  always_ff @(posedge clk or posedge reset)
  begin
    if(reset)
      toggle  <=  2'b0;
    else
      toggle  <=  toggle + 1'b1;
  end
  
  always_comb
  begin
    case(toggle)
      2'b00:begin
        mask = |vector_i[ENCODER_WIDTH/4-1:0]                               ? {{ENCODER_WIDTH-ENCODER_WIDTH/4{1'b0}},mask0} : 
               |vector_i[ENCODER_WIDTH/2-1:ENCODER_WIDTH/4]                 ? {{ENCODER_WIDTH/2{1'b0}},mask1,{ENCODER_WIDTH/4{1'b0}}}   :
               |vector_i[ENCODER_WIDTH/2+ENCODER_WIDTH/4-1:ENCODER_WIDTH/2] ? {{ENCODER_WIDTH/4{1'b0}},mask2,{ENCODER_WIDTH/2{1'b0}}}   :
                                                                              {mask3,{ENCODER_WIDTH/2+ENCODER_WIDTH/4{1'b0}}};
      end
      2'b01:begin
        mask = |vector_i[ENCODER_WIDTH/2-1:ENCODER_WIDTH/4]                 ? {{ENCODER_WIDTH/2{1'b0}},mask1,{ENCODER_WIDTH/4{1'b0}}}   :
               |vector_i[ENCODER_WIDTH/2+ENCODER_WIDTH/4-1:ENCODER_WIDTH/2] ? {{ENCODER_WIDTH/4{1'b0}},mask2,{ENCODER_WIDTH/2{1'b0}}}   :
               |vector_i[ENCODER_WIDTH-1:ENCODER_WIDTH/2+ENCODER_WIDTH/4]   ? {mask3,{ENCODER_WIDTH/2+ENCODER_WIDTH/4{1'b0}}}           :
                                                                              {{ENCODER_WIDTH-ENCODER_WIDTH/4{1'b0}},mask0}; 
      end
      2'b10:begin
        mask = |vector_i[ENCODER_WIDTH/2+ENCODER_WIDTH/4-1:ENCODER_WIDTH/2] ? {{ENCODER_WIDTH/4{1'b0}},mask2,{ENCODER_WIDTH/2{1'b0}}}   :
               |vector_i[ENCODER_WIDTH-1:ENCODER_WIDTH/2+ENCODER_WIDTH/4]   ? {mask3,{ENCODER_WIDTH/2+ENCODER_WIDTH/4{1'b0}}}           :
               |vector_i[ENCODER_WIDTH/4-1:0]                               ? {{ENCODER_WIDTH-ENCODER_WIDTH/4{1'b0}},mask0}             : 
                                                                              {{ENCODER_WIDTH/2{1'b0}},mask1,{ENCODER_WIDTH/4{1'b0}}};
      end
      2'b11:begin
        mask = |vector_i[ENCODER_WIDTH-1:ENCODER_WIDTH/2+ENCODER_WIDTH/4]   ? {mask3,{ENCODER_WIDTH/2+ENCODER_WIDTH/4{1'b0}}}           :
               |vector_i[ENCODER_WIDTH/4-1:0]                               ? {{ENCODER_WIDTH-ENCODER_WIDTH/4{1'b0}},mask0}             : 
               |vector_i[ENCODER_WIDTH/2-1:ENCODER_WIDTH/4]                 ? {{ENCODER_WIDTH/2{1'b0}},mask1,{ENCODER_WIDTH/4{1'b0}}}   :
                                                                              {{ENCODER_WIDTH/4{1'b0}},mask2,{ENCODER_WIDTH/2{1'b0}}};
      end
    endcase
  end

`endif

endmodule
