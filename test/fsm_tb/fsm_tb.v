`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module fsm_tb ();

  // Dump the signals to a FST file. You can view it with gtkwave or surfer.
  initial begin
    $dumpfile("fsm_tb.fst");
    $dumpvars(0, fsm_tb);
    #1;
  end

  // Wire up the inputs and outputs:
  reg clk;
  reg rst_n;
  reg mode;
  reg load_done;
  reg layer_1_done;
  reg layer_2_done;
  reg layer_3_done;
  wire [2:0] state;
`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  // Replace tt_um_example with your module name:
  fsm user_project (

      // Include power ports for the Gate Level test:
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif

      .clk  (clk),    // Dedicated inputs
      .rst_n  (rst_n),   // Dedicated outputs
      .mode   (mode),   // IOs: Input path
      .load_done   (load_done),  // IOs: Output path
      .layer_1_done   (layer_1_done),  // IOs: Output path
      .layer_2_done   (layer_2_done),  // IOs: Output path
      .layer_3_done   (layer_3_done),  // IOs: Output path
      .state   (state)  // IOs: Output path
  );

endmodule
