module layer_two (
    input logic clk, rst_n,
    input logic [2:0] state, // Top level input

    input logic [13:0][13:0][7:0] pixels,   // layer_one_out
    input logic [2:0][2:0][7:0]   weights,  // same weight format, new values

    output reg [3:0][6:0][6:0] layer_two_out,
    output reg done
);

    localparam s_IDLE = 3'b000, s_LOAD = 3'b001, s_LAYER_1 = 3'b010, s_LAYER_2 = 3'b011, s_LAYER_3 = 3'b100;

    logic [3:0] row, col;       // 0–6 for 7x7 output
    logic [3:0] weight_num;     // 0–7 for 8 filters

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            row        <= 0;
            col        <= 0;
            done       <= 0;
            weight_num <= 0;
        end
        else begin
            if (state == s_LAYER_2) begin
                if (weight_num < 4) begin
                    if (col < 6) begin
                        col <= col + 1;
                    end else begin
                        if (row < 6) begin
                            row <= row + 1;
                            col <= 0;
                        end else begin
                            row        <= 0;
                            col        <= 0;
                            weight_num <= weight_num + 1;
                        end
                    end
                end else begin
                    done <= 1;
                end
            end
        end
    end

    // Per-filter thresholds (72-bit popcount space):
    // Filter 0: 41, Filter 1: 42, Filter 2: 35, Filter 3: 37
    function logic [6:0] get_threshold;
        input logic [3:0] wt_num;
        begin
            case (wt_num)
                4'd0:    get_threshold = 7'd41;
                4'd1:    get_threshold = 7'd42;
                4'd2:    get_threshold = 7'd35;
                4'd3:    get_threshold = 7'd37;
                default: get_threshold = 7'd41;
            endcase
        end
    endfunction

    // convolution + batch norm + max pooling
    // Input is 14x14, pool 2x2 → 7x7 output
    // Each conv result is 72 bits (9 positions × 8 channels)
    always_comb begin
        layer_two_out[weight_num][row][col] =
            (($countones(conv(row << 1,       col << 1,       pixels, weights, weight_num)) >= get_threshold(weight_num)) |
             ($countones(conv(row << 1,       (col << 1) + 1, pixels, weights, weight_num)) >= get_threshold(weight_num)) |
             ($countones(conv((row << 1) + 1, col << 1,       pixels, weights, weight_num)) >= get_threshold(weight_num)) |
             ($countones(conv((row << 1) + 1, (col << 1) + 1, pixels, weights, weight_num)) >= get_threshold(weight_num)));
    end


    // conv function: 3x3 XNOR over 8-channel binary feature map
    // Returns 72-bit vector (9 positions × 8 channels of XNOR matches)
    function logic [71:0] conv;
        input logic [3:0] r, c;                   // position in 14x14 input
        input logic [13:0][13:0][7:0] pix;
        input logic [2:0][2:0][7:0]   wts;
        input logic [3:0] wt_num;

        logic [7:0] top_left, top_mid, top_right;
        logic [7:0] mid_left, mid_mid, mid_right;
        logic [7:0] bot_left, bot_mid, bot_right;

        begin
            // Zero-pad at boundaries of 14x14 input (indices 0–13)
            top_left  = (r == 0 || c == 0)  ? 8'b0 : pix[r-1][c-1];
            top_mid   = (r == 0)            ? 8'b0 : pix[r-1][c];
            top_right = (r == 0 || c == 13) ? 8'b0 : pix[r-1][c+1];

            mid_left  = (c == 0)  ? 8'b0 : pix[r][c-1];
            mid_mid   = pix[r][c];
            mid_right = (c == 13) ? 8'b0 : pix[r][c+1];

            bot_left  = (r == 13 || c == 0)  ? 8'b0 : pix[r+1][c-1];
            bot_mid   = (r == 13)            ? 8'b0 : pix[r+1][c];
            bot_right = (r == 13 || c == 13) ? 8'b0 : pix[r+1][c+1];

            // XNOR each 8-channel pixel against the weight bit for this filter
            conv = {
                ~(top_left  ^ {8{wts[0][0][wt_num]}}),
                ~(top_mid   ^ {8{wts[0][1][wt_num]}}),
                ~(top_right ^ {8{wts[0][2][wt_num]}}),
                ~(mid_left  ^ {8{wts[1][0][wt_num]}}),
                ~(mid_mid   ^ {8{wts[1][1][wt_num]}}),
                ~(mid_right ^ {8{wts[1][2][wt_num]}}),
                ~(bot_left  ^ {8{wts[2][0][wt_num]}}),
                ~(bot_mid   ^ {8{wts[2][1][wt_num]}}),
                ~(bot_right ^ {8{wts[2][2][wt_num]}})
            };
        end

    endfunction

endmodule