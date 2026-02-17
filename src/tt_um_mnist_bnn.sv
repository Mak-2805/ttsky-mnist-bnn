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

  reset_pipe u0 (
    .clk(clk),
    .async_in_rst(rst_n),
    .sync_out_rst(synchronous_reset),
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
  logic [27:0] pixels [0:27];
  logic [2:0][2:0] weights [0:7];

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
    
  // List all unused inputs to prevent warnings
  wire _unused = &{ena,ui_in[7:3], 1'b0};

endmodule
