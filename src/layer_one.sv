typedef enum logic [2:0] {
        s_IDLE    = 3'b000,
        s_LOAD    = 3'b001,
        s_LAYER_1 = 3'b010,
        s_LAYER_2 = 3'b011,
        s_LAYER_3 = 3'b100
    } state_t;

module layer_one (
    input logic clk, rst_n,
    input state_t state, // Top level input

    input logic [27:0] pixels [27:0],
    input logic [2:0][2:0] weights [7:0],

    output reg [13:0] [13:0] layer_one_out [7:0],
    output reg done
);
    
    logic [4:0] row, col;
    logic [3:0] weight_num;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            row <= 0;
            col <= 0;
            done <= 0;
            weight_num <= 0;
        end
        else begin
            if (state == s_LAYER_1) begin
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

    // convolution + normalization + max pooling part
    always_comb begin
        layer_one_out[weight_num][row][col] = 
            (($countones(conv(row << 1, col << 1, pixels, weights, weight_num)) >= 5 + (weights_num & 4'b1)) |
             ($countones(conv(row << 1, (col << 1) + 1, pixels, weights, weight_num)) >= 5 + (weights_num & 4'b1)) |
             ($countones(conv((row << 1) + 1, col << 1, pixels, weights, weight_num)) >= 5 + (weights_num & 4'b1)) |
             ($countones(conv((row << 1) + 1, (col << 1) + 1, pixels, weights, weight_num)) >= 5 + (weights_num & 4'b1)));
    end


    function logic [8:0] conv;
        input logic [4:0] r, c; 
        input logic [27:0] pix [27:0];
        input logic [2:0][2:0] wts [7:0];
        input logic [3:0] wt_num;
        
        logic top_left, top_mid, top_right, mid_left, mid_mid, mid_right, bot_left, bot_mid, bot_right;
        
        begin
            top_left  = (r == 0 && c == 0)  ? 1'b0 : pix[r-1][c-1];
            top_mid   = (r == 0)            ? 1'b0 : pix[r-1][c];
            top_right = (r == 0 && c == 27) ? 1'b0 : pix[r-1][c+1];
            
            mid_left  = (c == 0)  ? 1'b0 : pix[r][c-1];
            mid_mid   = pix[r][c];
            mid_right = (c == 27) ? 1'b0 : pix[r][c+1];
            
            bot_left  = (r == 27 && c == 0)  ? 1'b0 : pix[r+1][c-1];
            bot_mid   = (r == 27)            ? 1'b0 : pix[r+1][c];
            bot_right = (r == 27 && c == 27) ? 1'b0 : pix[r+1][c+1];
            
            conv = {
                ~(top_left  ^ wts[wt_num][0][0]),
                ~(top_mid   ^ wts[wt_num][0][1]),
                ~(top_right ^ wts[wt_num][0][2]),
                ~(mid_left  ^ wts[wt_num][1][0]),
                ~(mid_mid   ^ wts[wt_num][1][1]),
                ~(mid_right ^ wts[wt_num][1][2]),
                ~(bot_left  ^ wts[wt_num][2][0]),
                ~(bot_mid   ^ wts[wt_num][2][1]),
                ~(bot_right ^ wts[wt_num][2][2])
            };
        end

    endfunction

endmodule