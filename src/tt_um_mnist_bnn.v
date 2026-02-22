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

  // Output wiring
  logic [3:0] answer_w;
  assign uo_out  = {4'b0, answer_w};  // bits[3:0]=answer, bits[7:4]=0
  assign uio_out = 'd0;
  assign uio_oe  = 'd0;

  // Synchronous reset
  logic synchronous_reset;
  reset_pipe reset_in (
    .clk(clk),
    .async_in_rst(rst_n),
    .sync_out_rst(synchronous_reset)
  );

  // FSM
  logic load_done, layer1_done, layer2_done, layer3_done;
  logic [2:0] state;

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
    
  // Memory/register arrays
  reg [783:0] pixels;
  reg [71:0] weights1;
  reg [287:0] weights2;
  reg [1959:0] weights3;

  // Registered layer outputs
  reg [1567:0] layer_1_out_reg;
  reg [195:0] layer_2_out_reg;

  // Registers module
  registers u0 (
    .clk(clk),
    .reset_n(synchronous_reset),
    .state(state),
    .d_in_p(ui_in[1]),
    .d_in_w(ui_in[2]),
    .pixels(pixels),
    .weights1(weights1),
    .weights2(weights2),
    .weights3(weights3),
    .load_done(load_done)
  );

  // Layer 1
  wire [1567:0] layer_1_comb;
  layer_one u1(
    .clk(clk),
    .rst_n(synchronous_reset),
    .state(state),
    .pixels(pixels),
    .weights(weights1),
    .layer_one_out(layer_1_comb),
    .done(layer1_done)
  );

  // Register the output of layer 1
  always @(posedge clk or negedge synchronous_reset) begin
      if (!synchronous_reset)
          layer_1_out_reg <= 0;
      else if (state == 3'b010) // s_LAYER_1
          layer_1_out_reg <= layer_1_comb;
  end

  // Layer 2
  wire [195:0] layer_2_comb;
  layer_two u2(
    .clk(clk),
    .rst_n(synchronous_reset),
    .state(state),
    .pixels(layer_1_out_reg),
    .weights(weights2),
    .layer_two_out(layer_2_comb),
    .done(layer2_done)
  );

  // Register the output of layer 2
  always @(posedge clk or negedge synchronous_reset) begin
      if (!synchronous_reset)
          layer_2_out_reg <= 0;
      else if (state == 3'b011) // s_LAYER_2
          layer_2_out_reg <= layer_2_comb;
  end

  // Layer 3 / Final layer
  final_layer_sequential u3 (
      .clock(clk),
      .reset_n(synchronous_reset),
      .state(state),
      .data_in(layer_2_out_reg),
      .weights_in(weights3),
      .answer(answer_w),
      .layer_3_done(layer3_done)
  );

  // Avoid warnings
  wire _unused = &{ena, ui_in[7:3], 1'b0};

endmodule