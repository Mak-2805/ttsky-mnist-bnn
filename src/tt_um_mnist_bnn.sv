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
logic layer1_done, layer2_done, layer3_done;
    
 fsm top_fsm ( 
     .clk(clk), 
     .rst_n(rst_n), 
     .mode(ui_in[0]), 
     .load_done(ui_in[1]), 
     .layer_1_done(ui_in[2]),
     .layer_2_done(ui_in[3]),
     .layer_3_done(ui_in[4]), 
     .state(uo_out[2:0]) 
 ); 
    

  // List all unused inputs to prevent warnings
  wire _unused = &{ena,ui_in[7:5], 1'b0};

endmodule
