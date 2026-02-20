module final_layer_combinational #(parameter NUM_INPUTS = 196) (
	input logic clock,
	input logic reset,
	input logic [NUM_INPUTS-1:0] data_in,
	input logic [NUM_INPUTS-1:0] weights_in [9:0],
	output logic [3:0] answer
	);
	
	logic [NUM_INPUTS-1:0] dot_product [9:0];
	logic [7:0] popcount [9:0];
	
	always_comb begin
		for (int neuron = 0; neuron < 10; neuron++) begin
				dot_product[neuron] = weights_in[neuron] ^~ data_in;
				popcount[neuron] = $countones(dot_product[neuron]);
		end
		
		answer = 0;
		for (int i = 0; i < 10; i++) begin
			if (popcount[i] > popcount[answer]) begin
				answer = i;
			end
		end
	end	

endmodule