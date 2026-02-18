`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();

  // Dump the signals to a FST file. You can view it with gtkwave or surfer.
  initial begin
    $dumpfile("tb.fst");
    $dumpvars(0, tb);
    #1;
  end

  // Wire up the inputs and outputs:
  reg clk;
  reg rst_n;
  reg [2:0] state;
  reg [27:0] pixels [27:0];
  reg [2:0][2:0] weights [7:0];
  wire [13:0] [13:0] layer_one_out [7:0];
  wire done;

`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  // Replace tt_um_example with your module name:
  layer_one user_project (

      // Include power ports for the Gate Level test:
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif

      .clk  (clk),    // Dedicated inputs
      .rst_n  (rst_n),   // Dedicated outputs
      .state  (state),   // IOs: Input path
      .pixels (pixels),  // IOs: Output path
      .weights (weights),   // IOs: Enable path (active high: 0=input, 1=output)
      .layer_one_out (layer_one_out),
      .done (done)
  );

endmodule
