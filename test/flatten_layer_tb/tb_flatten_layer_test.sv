`timescale 1ns / 1ps

module tb_final_layer_sequential;
	parameter NUM_INPUTS = 196;
	logic clock;
	logic reset;
	logic en = 1'b0;
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

		#1 reset = 1;
		#3 en = 1;

		$display("--- Starting Tests ---");

		// --- TEST 1 force answer of 4 ---
		// Set all data_in to 1 and all weights of neuron 4 to 1. All other neurons have 0 weights.
		data_in = {NUM_INPUTS{1'b1}};
		for (int i =0; i < 10; i++) begin
			weights_in[i] = {NUM_INPUTS{1'b0}};
		end
		weights_in[4] = {NUM_INPUTS{1'b1}};
		
		@(posedge layer_done)#1
		$display("Test 1 - Expected: 4 | Got: %0d", answer);

		// --- TEST 2 test tournament comparator ---
		// Set all data_in to 1, weights increase by 1 for each neuron
		// en = 0;
		// #5
		// en = 1;

		reset = 0;
		#1
		reset = 1;

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

		@(posedge layer_done)#1
		$display("Test 2 - Expected: 9 | Got: %0d", answer);

		// --- Test 3 real data from Python model (image index 2)---

		// en = 0;
		// #11
		// en = 1;
		reset = 0;
		#1
		reset = 1;

		$readmemb("./current_test_case_values/layer_inputs.mem", test_images_inputs);
		$readmemb("./current_test_case_values/layer_weights.mem", weights_in);
		$readmemb("./current_test_case_values/label.mem", label);
		data_in = test_images_inputs[0];

		@(posedge layer_done) #3
		$display("Test 3 - Expected: %0d | Got: %0d", label[0], answer);

		// --- Test 4 Verify effect of Enable and Reset
		// Answer should remain without enable
		// Reset signal should be sent low (active low reset) before setting enable
		// Input values should be set before setting enable
		// Answer will appear on next clock cycle after enable set high
		
		en = 0;
		#6
		reset = 0;
		#1
		reset = 1;
		#6
		en = 1;
		#6

		@(posedge layer_done) #3
		$display("Test 4 - Expected: %0d | Got: %0d", label[0], answer);	

		$display("--- Tests Completed ---");
		$stop;
	end
endmodule

