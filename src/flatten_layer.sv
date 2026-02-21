// Reset to set answer to 0
// There is a valid answer while the layer_3_done signal is high
// To load a new set of inputs:
// 		1) Ensure reset signal is high
// 		2) Load inputs to data_in and weights_in
//		3) Answer will appear after layer_3_done goes high
//
// SEQUENTIAL VERSION: computes one neuron's popcount per clock cycle
// (10 cycles total) instead of all 10 in parallel, greatly reducing
// combinational logic depth and synthesis memory usage.

module final_layer_sequential #(parameter NUM_INPUTS = 196) (
	input logic clock,
	input logic reset,
	input logic [2:0] state,
	input logic [NUM_INPUTS-1:0] data_in,
	output logic [3:0] answer,
	output logic layer_3_done
	);

	localparam s_IDLE = 3'b000, s_LOAD = 3'b001, s_LAYER_1 = 3'b010, s_LAYER_2 = 3'b011, s_LAYER_3 = 3'b100;

	// Hardcoded weights: 10 neurons x 196 inputs = 1960 bits
	// Encoding: neuron n uses bits [n*196 +: 196]
	localparam [NUM_INPUTS*10-1:0] WEIGHTS3 = 1960'hDD88CE908333B3C085F14AA8CC4400DD80122CDAEEB45DC8784E532638CD44292FC88557C85F5CCD844191CC820276FE0C628CC8C2222017AFE022B0C133FFAACFDDD25735D1BC8C7FC0B9998F26FBF88AEC8462C4D80871338891E7E0019898881E5279F3AF66DDF298377F771F77F7777F042DDF30063767E207777222A1E63125FFFFF70C8A4986802068C80215115667B7A047EFD20EFDDD28D77DD60FFE3FAE817FF200DFDCC68D3137738037DDD7EE7D7BCC8C33093FA38477F3A0CFFE346319A776663671D0E489A0222ADD2A028612A228624A221C72793C437B37B04CEDE77CD02844C83680088EE80120040E367366E6;

	logic [7:0] popcount [9:0];
	logic [3:0] neuron_cnt;  // counts 0..9 then holds at 10 when done

	// DOT PRODUCT LOGIC - one neuron per cycle
	// Combinational: compute XNOR popcount for the current neuron only
	logic [NUM_INPUTS-1:0] cur_weights;
	logic [7:0] cur_popcount;

	always @(*) begin
		cur_weights  = WEIGHTS3[neuron_cnt * NUM_INPUTS +: NUM_INPUTS];
		cur_popcount = 0;
		for (int i = 0; i < NUM_INPUTS; i++) begin
			cur_popcount = cur_popcount + (cur_weights[i] ^~ data_in[i]);
		end
	end

	// Sequential: register one neuron's result per cycle
	always @(posedge clock or negedge reset) begin
		if (!reset) begin
			for (int i = 0; i < 10; i++) begin
				popcount[i] <= 8'd0;
			end
			neuron_cnt <= 4'd0;
		end else if (state != s_LAYER_3) begin
			neuron_cnt <= 4'd0;   // reset counter between inferences
		end else if (neuron_cnt < 10) begin
			popcount[neuron_cnt] <= cur_popcount;
			neuron_cnt <= neuron_cnt + 1;
		end
	end

	assign layer_3_done = (neuron_cnt >= 4'd10);

	// COMPARATOR LOGIC (unchanged)

	logic [7:0] round_1_val [4:0]; logic [3:0] round_1_idx [4:0];
	logic [7:0] round_2_val [1:0]; logic [3:0] round_2_idx [1:0];
	logic [7:0] round_3_val; logic [3:0] round_3_idx;

	always @(*) begin
		answer = 4'd0;  // default to avoid latches

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

		// Third round
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
