`timescale 1ns / 1ps

module tb_final_layer_sequential;
	parameter NUM_INPUTS = 196;
	logic clock;
	logic reset;
	logic [NUM_INPUTS-1:0] data_in;
	logic [NUM_INPUTS-1:0] weights_in [9:0];
	logic [3:0] answer;

	final_layer_sequential #(.NUM_INPUTS(NUM_INPUTS)) dut (
		.clock(clock),
		.reset(reset),
		.data_in(data_in),
		.weights_in(weights_in),
		.answer(answer)
	);

	initial begin
		clock = 0;
		forever #5 clock = ~clock;
	end

	initial begin
		reset = 0;
		data_in = '0;
		for (int i = 0; i < 10; i++) begin
			weights_in[i] = '0;
		end

		#20 reset = 1;

		$display("--- Starting Tests ---");

		// --- TEST 1 force answer of 4 ---
		// Set all data_in to 1 and all weights of neuron 4 to 1. All other neurons have 0 weights.
		data_in = {NUM_INPUTS{1'b1}};
		for (int i =0; i < 10; i++) begin
			weights_in[i] = {NUM_INPUTS{1'b0}};
		end
		weights_in[4] = {NUM_INPUTS{1'b1}};
		
		@(posedge clock);
		#1;
		$display("Test 1 - Expected: 4 | Got: %0d", answer);

		// --- TEST 2 test tournament comparator ---
		// Set all data_in to 1, weights increase by 1 for each neuron

		data_in = {NUM_INPUTS{1'b1}};
		for (int i = 0; i < 10; i++) begin
			for (int j = 0; j < NUM_INPUTS; j++) begin
				if (j <= i ) begin
					weights_in[i][j] = 1'b1;
				end else begin
					weights_in[i][j] = 1'b0;
				end
			end
		end

		@(posedge clock);
		#5;
		$display("Test 2 - Expected: 9 | Got: %0d", answer);
		$display("--- Tests Completed ---");
		$finish;
	end
endmodule

