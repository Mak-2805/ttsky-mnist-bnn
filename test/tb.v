`default_nettype none
`timescale 1ns / 1ps

/* Testbench for tt_um_mnist_bnn top-level module.
   Exposes the TinyTapeout interface signals for cocotb.
   ui_in[0] = mode, ui_in[1] = pixel_in, ui_in[2] = weight_in
   uo_out[3:0] = answer digit (0-9)
*/
module tb ();

  // Dump signals to FST file (view with gtkwave or surfer)
  initial begin
    $dumpfile("tb.fst");
    $dumpvars(0, tb);
    #1;
  end

  // TinyTapeout interface signals
  reg        clk;
  reg        rst_n;
  reg  [7:0] ui_in;
  reg  [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  tt_um_mnist_bnn user_project (
`ifdef GL_TEST
      .VPWR   (VPWR),
      .VGND   (VGND),
`endif
      .ui_in  (ui_in),
      .uo_out (uo_out),
      .uio_in (uio_in),
      .uio_out(uio_out),
      .uio_oe (uio_oe),
      .ena    (1'b1),
      .clk    (clk),
      .rst_n  (rst_n)
  );

endmodule
