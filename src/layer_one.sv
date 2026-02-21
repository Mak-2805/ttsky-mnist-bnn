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

    localparam [2:0] s_IDLE    = 3'b000;
    localparam [2:0] s_LOAD    = 3'b001;
    localparam [2:0] s_LAYER_1 = 3'b010;
    localparam [2:0] s_LAYER_2 = 3'b011;
    localparam [2:0] s_LAYER_3 = 3'b100;

    reg [4:0] row, col;
    reg [3:0] weight_num;
    reg [1:0] pool_cnt;  // 0-3: which 2x2 pool position is being computed
    reg       pool_acc;  // running OR across the 4 pool positions

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

    // Combinational: compute ONE conv per cycle based on pool_cnt.
    // pool_cnt[1] selects the row offset (0 or 1) within the 2x2 pool window.
    // pool_cnt[0] selects the col offset (0 or 1).
    reg [4:0] pool_r, pool_c;
    reg [8:0] conv_result;
    reg [3:0] count_result;
    reg [3:0] threshold;
    reg       out_bit;

    always @(*) begin
        pool_r       = pool_cnt[1] ? ((row << 1) + 1) : (row << 1);
        pool_c       = pool_cnt[0] ? ((col << 1) + 1) : (col << 1);
        threshold    = 5 + (weight_num & 4'b1);
        conv_result  = conv(pool_r, pool_c, weight_num);
        count_result = count_ones(conv_result);
        out_bit      = (count_result > threshold);
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            row           <= 0;
            col           <= 0;
            done          <= 0;
            weight_num    <= 0;
            layer_one_out <= 0;
            pool_cnt      <= 0;
            pool_acc      <= 0;
        end
        else begin
            if (state == s_LAYER_1) begin
                if (weight_num < 8) begin
                    if (pool_cnt < 3) begin
                        // Accumulate max-pool: OR in this position's result
                        pool_acc <= pool_acc | out_bit;
                        pool_cnt <= pool_cnt + 1;
                    end else begin
                        // Last pool position: write final result and advance
                        layer_one_out[out_idx(weight_num, row, col)] <= pool_acc | out_bit;
                        pool_cnt <= 0;
                        pool_acc <= 0;
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
                    end
                end else begin
                    done <= 1;
                end
            end
        end
    end

endmodule
