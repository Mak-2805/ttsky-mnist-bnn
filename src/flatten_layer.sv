module flatten_layer #(parameter NUM_INPUTS = 196) (
    input logic clock,
	input logic reset,
	input logic [NUM_INPUTS-1:0] data_in,
	input logic [NUM_INPUTS-1:0] weights_in [9:0],
	output logic [3:0] answer
);

    final_layer_combinational (
	    .clock(clock),
	    .reset(reset),
	    .data_in(data_in),
	    .weights_in(weights_in),
	    .answer(answer)
	);

    final_layer_sequential (
	    .clock(clock),
	    .reset(reset),
	    .data_in(data_in),
	    .weights_in(weights_in),
	    .answer(answer)
	);

endmodule