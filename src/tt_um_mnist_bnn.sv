/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_mnist_bnn (
    input  logic [7:0] ui_in,    // Dedicated inputs
    output logic [7:0] uo_out,   // Dedicated outputs
    input  logic [7:0] uio_in,   // IOs: Input path
    output logic [7:0] uio_out,  // IOs: Output path
    output logic [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  logic       ena,      // always 1 when the design is powered, so you can ignore it
    input  logic       clk,      // clock
    input  logic       rst_n     // reset_n - low to reset
);

  // All output pins must be assigned. If not used, assign to 0.
  assign uo_out[7:3]  = 'd0;  // Example: ou_out is the sum of ui_in and uio_in
  assign uio_out = 'd0;
  assign uio_oe  = 'd0;

    // fsm top_fsm ( 
    //       .clk(clk), 
    //       .rst_n(rst_n), 
    //       .mode(ui_in[0]), 
    //       .load_done(ui_in[1]), 
    //       .layer_1_done(ui_in[2]),
    //       .layer_2_done(ui_in[3]),
    //       .layer_3_done(ui_in[4]), 
    //       .state(uo_out[2:0]) 
    //   ); 
    
  logic mode;
  logic load_done, layer1_done, layer2_done, layer3_done;
  logic [2:0] state;

  logic synchronous_reset;

  reset_pipe reset_in (
    .clk(clk),
    .async_in_rst(rst_n),
    .sync_out_rst(synchronous_reset)
  );

  fsm top_fsm ( 
    .clk(clk), 
    .rst_n(synchronous_reset), 
    .mode(ui_in[0]), 
    .load_done(load_done), 
    .layer_1_done(layer1_done),
    .layer_2_done(layer2_done),
    .layer_3_done(layer3_done), 
    .state(state) 
  ); 
    
  //set dimensions
  logic [27:0][27:0] pixels;
  logic [2:0][2:0][7:0] weights;
  logic [13:0][13:0][7:0] layer_1_out;
  logic [3:0][6:0][6:0] layer_2_out;

  logic load = (state == 3'd1) ? 1'b1 : 1'b0;
  registers u0 (
    .clk(clk),
    .reset_n(rst_n),
    .en_wr(load),
    .d_in_p(ui_in[1]),
    .d_in_w(ui_in[2]),
    .pixels(pixels),
    .weights(weights),
    .load_done(load_done)
  );


  //Flop Stage (not trivial)
  //Michael will try to cook this up
  //Might not be necessary between memory fill-up and layer_one
  //Stick to comb stages

  layer_one_try u1(
    .clk(clk),
    .rst_n(synchronous_reset),
    .state(state),
    .pixels(pixels),
    .weights(weights),
    .layer_one_out(layer_1_out),
    .done(layer1_done)
  );

  //Flop Stage (not trivial)
  //Michael will try to cook this up

  layer_two u2(
    .clk(clk),
    .rst_n(synchronous_reset),
    .state(state),
    .pixels(layer_1_out),
    .weights(), //NEW WEIGHTS
    .layer_two_out(layer_2_out),
    .done(layer2_done)
  );

  //Flop Stage (not trivial)
  //Michael will try to cook this up

  flatten_layer u3 (
    .clock(clk),
	  .reset(rst_n),
	  .data_in(layer_2_out),
	  .weights_in(),
	  .answer(uo_out[3:0])
  );

  //Flop Stage (not trivial)
  //Michael will try to cook this up
    
  // List all unused inputs to prevent warnings
  wire _unused = &{ena,ui_in[7:3], 1'b0};

endmodule
