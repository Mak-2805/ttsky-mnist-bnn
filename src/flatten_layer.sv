module final_layer_sequential #(
    parameter NUM_INPUTS = 196
)(
    input  wire        clock,
    input  wire        reset_n,
    input  wire [2:0]  state,
    input  wire [NUM_INPUTS-1:0] data_in,
    input  wire [NUM_INPUTS*10-1:0] weights_in,

    output reg  [3:0]  answer,
    output reg         layer_3_done
);

    localparam s_LAYER_3 = 3'b100;

    reg [7:0] accumulator;
    reg [7:0] max_value;

    reg [7:0] bit_index;
    reg [3:0] neuron_index;

    wire current_weight;
    wire xnor_bit;

    assign current_weight =
        weights_in[neuron_index*NUM_INPUTS + bit_index];

    assign xnor_bit = ~(current_weight ^ data_in[bit_index]);

    always @(posedge clock or negedge reset_n) begin
        if (!reset_n) begin
            accumulator   <= 0;
            max_value     <= 0;
            answer        <= 0;
            bit_index     <= 0;
            neuron_index  <= 0;
            layer_3_done  <= 0;
        end
        else begin
            if (state == s_LAYER_3 && !layer_3_done) begin

                // Accumulate popcount
                accumulator <= accumulator + xnor_bit;

                if (bit_index < NUM_INPUTS-1) begin
                    bit_index <= bit_index + 1;
                end
                else begin
                    // Finished one neuron

                    if (accumulator > max_value) begin
                        max_value <= accumulator;
                        answer    <= neuron_index;
                    end

                    accumulator <= 0;
                    bit_index   <= 0;

                    if (neuron_index < 9) begin
                        neuron_index <= neuron_index + 1;
                    end
                    else begin
                        layer_3_done <= 1'b1;
                    end
                end
            end
        end
    end

endmodule