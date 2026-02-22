module layer_one (
    input wire clk, rst_n,
    input wire [2:0] state, // Top level input

    // Flattened arrays for Verilog-2001 compatibility
    // pixels: 28x28 = 784 bits [783:0]
    input wire [783:0] pixels,
    // weights: 3x3x8 = 72 bits [71:0]
    input wire [71:0] weights,

    // layer_one_out: 14x14x8 = 1568 bits [1567:0]
    output reg [1567:0] layer_one_out,
    output reg done
);
    

    reg [4:0] row, col;
    reg [3:0] weight_num;

    // Helper function to index into flattened pixels array
    // pixels[r][c] -> pixels[r*28 + c]
    function [9:0] pix_idx;
        input [4:0] r, c;
        begin
            pix_idx = (r * 28) + c;
        end
    endfunction

    // Helper function to index into flattened weights array
    // weights[r][c][w] -> weights[r*24 + c*8 + w]
    function [6:0] wt_idx;
        input [1:0] r, c;
        input [3:0] w;
        begin
            wt_idx = (r * 24) + (c * 8) + w;
        end
    endfunction

    // Helper function to index into flattened layer_one_out array
    // layer_one_out[w][r][c] -> layer_one_out[w*196 + r*14 + c]
    function [10:0] out_idx;
        input [3:0] w;
        input [4:0] r, c;
        begin
            out_idx = (w * 196) + (r * 14) + c;
        end
    endfunction

    always @(posedge clk) begin
        if (!rst_n) begin
            row <= 0;
            col <= 0;
            done <= 0;
            weight_num <= 0;
        end
        else begin
            if (state == 3'b010) begin
                if (weight_num < 8) begin
                    if (col < 13) begin
                        col <= col + 1;
                    end else begin
                        if (row < 13) begin
                            row <= row + 1;
                            col <= 0;
                        end else begin
                            row <= 0;
                            col <= 0;
                            weight_num <= weight_num + 1;
                        end
                    end
                end else begin
                    done <= 1;
                end
            end
        end
    end

    // Helper function to count ones in a 9-bit value
    function [3:0] count_ones;
        input [8:0] val;
        integer i;
        begin
            count_ones = 0;
            for (i = 0; i < 9; i = i + 1) begin
                count_ones = count_ones + val[i];
            end
        end
    endfunction

    // convolution + normalization + max pooling part
    reg [8:0] conv_result_00, conv_result_01, conv_result_10, conv_result_11;
    reg [3:0] count_00, count_01, count_10, count_11;
    reg [3:0] threshold;

    always @(*) begin
        threshold = 5 + (weight_num & 4'b1);
        conv_result_00 = conv(row << 1, col << 1, weight_num);
        conv_result_01 = conv(row << 1, (col << 1) + 1, weight_num);
        conv_result_10 = conv((row << 1) + 1, col << 1, weight_num);
        conv_result_11 = conv((row << 1) + 1, (col << 1) + 1, weight_num);

        count_00 = count_ones(conv_result_00);
        count_01 = count_ones(conv_result_01);
        count_10 = count_ones(conv_result_10);
        count_11 = count_ones(conv_result_11);

        layer_one_out[out_idx(weight_num, row, col)] =
            ((count_00 >= threshold) | (count_01 >= threshold) |
             (count_10 >= threshold) | (count_11 >= threshold));
    end


    function [8:0] conv;
        input [4:0] r, c;
        input [3:0] wt_num;

        reg top_left, top_mid, top_right, mid_left, mid_mid, mid_right, bot_left, bot_mid, bot_right;

        begin
            // Extract pixel values with boundary checking
            top_left  = (r == 0 || c == 0)  ? 1'b0 : pixels[pix_idx(r-1, c-1)];
            top_mid   = (r == 0)            ? 1'b0 : pixels[pix_idx(r-1, c)];
            top_right = (r == 0 || c == 27) ? 1'b0 : pixels[pix_idx(r-1, c+1)];

            mid_left  = (c == 0)  ? 1'b0 : pixels[pix_idx(r, c-1)];
            mid_mid   = pixels[pix_idx(r, c)];
            mid_right = (c == 27) ? 1'b0 : pixels[pix_idx(r, c+1)];

            bot_left  = (r == 27 || c == 0)  ? 1'b0 : pixels[pix_idx(r+1, c-1)];
            bot_mid   = (r == 27)            ? 1'b0 : pixels[pix_idx(r+1, c)];
            bot_right = (r == 27 || c == 27) ? 1'b0 : pixels[pix_idx(r+1, c+1)];

            // XNOR operation with weights and pack into 9-bit result
            conv = {
                ~(top_left  ^ weights[wt_idx(0, 0, wt_num)]),
                ~(top_mid   ^ weights[wt_idx(0, 1, wt_num)]),
                ~(top_right ^ weights[wt_idx(0, 2, wt_num)]),
                ~(mid_left  ^ weights[wt_idx(1, 0, wt_num)]),
                ~(mid_mid   ^ weights[wt_idx(1, 1, wt_num)]),
                ~(mid_right ^ weights[wt_idx(1, 2, wt_num)]),
                ~(bot_left  ^ weights[wt_idx(2, 0, wt_num)]),
                ~(bot_mid   ^ weights[wt_idx(2, 1, wt_num)]),
                ~(bot_right ^ weights[wt_idx(2, 2, wt_num)])
            };
        end

    endfunction

endmodule