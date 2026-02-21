// Reset to set answer to 0
// There is a valid answer while the layer_3_done signal is high
// To load a new set of inputs:
// 		1) Ensure reset signal is high
// 		2) Load inputs to data_in and weights_in
//		3) Answer will appear on next rising clock edge after state enters s_LAYER_3

// FYi ICARUS VERILOG IS OLD VERSION.. CAN'T SUPPORT A LOT OF THE THINGS LIKE ALWAYS_COMB, ALWAYS_FF AND ASSIGNING ARRAYS TO ARRAYS (MANUALLY DONE WITH FOR LOOP IN THIS FILE FOR NEURON POPCOUNT).. CHANGE BACK TO OLD SV CODE IF NEEDED!!

module final_layer_sequential #(parameter NUM_INPUTS = 196) (
	input logic clock,
	input logic reset,
	input logic [2:0] state,
	input logic [NUM_INPUTS-1:0] data_in,
	input logic [NUM_INPUTS*10-1:0] weights_in,
	output logic [3:0] answer,
	output logic layer_3_done
	);

	localparam s_IDLE = 3'b000, s_LOAD = 3'b001, s_LAYER_1 = 3'b010, s_LAYER_2 = 3'b011, s_LAYER_3 = 3'b100;
	logic [7:0] popcount [9:0];
	logic [7:0] next_popcount [9:0];
	logic [NUM_INPUTS-1:0] xnor_result [9:0];

	// DOT PRODUCT LOGIC

	always @(*) begin
		for (int neuron = 0; neuron < 10; neuron++) begin
			xnor_result[neuron] = weights_in[neuron*NUM_INPUTS +: NUM_INPUTS] ^~ data_in;
			next_popcount[neuron] = 0;
			for (int i = 0; i<NUM_INPUTS; i++) begin
				next_popcount[neuron] = next_popcount[neuron] + xnor_result[neuron][i];
			end
		end
	end

	always @(posedge clock or negedge reset) begin
		if (!reset) begin
			for (int i = 0; i < 10; i++) begin
				popcount[i] <= 8'd0;
			end
		end else if (state == s_LAYER_3 && !layer_3_done) begin
			for (int i = 0; i < 10; i++) begin
				popcount[i] <= next_popcount[i];
			end
		end
	end
	
	// COMPARATOR LOGIC
	
	logic [7:0] round_1_val [4:0]; logic [3:0] round_1_idx [4:0];
	logic [7:0] round_2_val [1:0]; logic [3:0] round_2_idx [1:0];
	logic [7:0] round_3_val; logic [3:0] round_3_idx;
	
	always @(*) begin
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

		if (answer != 0 || (answer == 0 && (round_3_val | round_1_val[4] != 0))) begin
			layer_3_done = 1'b1;
		end else begin
			layer_3_done = 1'b0;
		end
	end
			
	
endmodule