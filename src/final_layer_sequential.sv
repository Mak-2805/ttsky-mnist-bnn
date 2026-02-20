module final_layer_sequential #(parameter NUM_INPUTS = 196) (
	input logic clock,
	input logic reset,
	input logic [NUM_INPUTS-1:0] data_in,
	input logic [NUM_INPUTS-1:0] weights_in [9:0],
	output logic [3:0] answer
	);
	logic [7:0] popcount [9:0];

	// DOT PRODUCT LOGIC
	always_ff @(posedge clock or negedge reset) begin
		if (!reset) begin
			for (int i = 0; i < 10; i++) begin
				popcount[i] <= 8'd0;
			end
		end else begin
			for (int neuron = 0; neuron < 10; neuron++) begin
				popcount[neuron] <= $countones(weights_in[neuron] ^~ data_in);
			end
		end
	end
	
	// COMPARATOR LOGIC
	
	logic [7:0] round_1_val [4:0]; logic [3:0] round_1_idx [4:0];
	logic [7:0] round_2_val [1:0]; logic [3:0] round_2_idx [1:0];
	logic [7:0] round_3_val; logic [3:0] round_3_idx;
	
	always_comb begin
		// First round
		for (int i = 0; i < 5; i++) begin
			if (popcount[i*2] >= popcount[i*2+1]) begin
				round_1_val[i] = popcount[i*2];
				round_1_idx[i] = i*2;
			end else begin
				round_1_val[i] = popcount[i*2+1];
				round_1_idx[i] = i*2+1;
			end
		end
		
		// Second round (round_1_val[4] gets passthrough to end)
		for (int i = 0; i < 2; i++) begin
			if (round_1_val[i*2] >= round_1_val[i*2+1]) begin
				round_2_val[i] = round_1_val[i*2];
				round_2_idx[i] = round_1_idx[i*2];
			end else begin
				round_2_val[i] = round_1_val[i*2+1];
				round_2_idx[i] = round_1_idx[i*2+1];
			end
		end
		
		// Third round (round_1_val[4] gets passthrough to end)
		if (round_2_val[0] >= round_2_val[1]) begin
			round_3_val = round_2_val[0];
			round_3_idx = round_2_idx[0];
		end else begin
			round_3_val = round_2_val[1];
			round_3_idx = round_2_idx[1];
		end
		
		// Fourth/final round (round_1_val[4] gets passthrough to end)
		if (round_3_val >= round_1_val[4]) begin
			answer = round_3_idx;
		end else begin
			answer = round_1_idx[4];
		end
	end
			
	
endmodule