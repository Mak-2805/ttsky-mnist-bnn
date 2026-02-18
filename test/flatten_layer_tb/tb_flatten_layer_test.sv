`timescale 1ns / 1ps

module tb_final_layer_sequential;
	parameter NUM_INPUTS = 196;
	logic clock;
	logic reset;
	logic en = 1'b1;
	logic [NUM_INPUTS-1:0] data_in;
	logic [NUM_INPUTS-1:0] weights_in [9:0];
	logic [3:0] answer;
	logic layer_done;
	logic [NUM_INPUTS-1:0] test_images_inputs [0:0];
	logic [3:0] label [0:0];

	final_layer_sequential #(.NUM_INPUTS(NUM_INPUTS)) dut (
		.clock(clock),
		.reset(reset),
		.en(en),
		.data_in(data_in),
		.weights_in(weights_in),
		.answer(answer),
		.layer_3_done(layer_done)
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
		en = 0;
		#15
		en = 1;

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

		// --- Test 3 real data from Python model (image index 2)---

		en = 0;
		#15
		en = 1;

		$readmemb("./current_test_case_values/layer_inputs.mem", test_images_inputs);
		$readmemb("./current_test_case_values/layer_weights.mem", weights_in);
		$readmemb("./current_test_case_values/label.mem", label);
		data_in = test_images_inputs[0];
		// data_in = 196'h44c8c444467b1044ccb744473b444cce14463337644eeec44;

		// weights_in[0] = 196'h6766ce6c70200480177110016c1322140b3ee7b7320decdec;
		// weights_in[1] = 196'h23c9e4e38445246144548614054bb54440591270b8e6c666e;
		// weights_in[2] =	196'he598c62c7ff305cfee21c5fc90cc3133debe77ebbbec01cee;
		// weights_in[3] = 196'hc8cb1633bfb004ffe8175fc7ff06bbeeb14bbbf704bf7e205;
		// weights_in[4] = 196'hede66a88a8401316040161925130efffffa48c6785444eeee;
		// weights_in[5] = 196'h47e6ec600cfbb420feeeefeef8eefeec194fbb66f5cf9e4a;
		// weights_in[6] = 196'h781119198007e78911cc8e101b23462137511fdf64f1999d0;
		// weights_in[7] = 196'h3fe313d8bacea4bbbf355ffcc830d4407f5e8044443133146;
		// weights_in[8] = 196'h307f6e404133898221b33afa13eaa113f49422b31c64ca721;
		// weights_in[9] = 196'he13ba2d775b344801bb00223315528fa103cdccc1097311bb;

		@(posedge clock);
		#5;
		$display("Test 3 - Expected: %0d | Got: %0d", label[0], answer);

		$display("--- Tests Completed ---");
		$stop;
	end
endmodule

