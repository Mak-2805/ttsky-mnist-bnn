
module layer_one (
    input logic clk, rst_n,
    input logic [2:0] state, // Top level input

    input logic [27:0] pixels [27:0],
    input logic [2:0][2:0] weights [7:0],

    output reg [13:0] [13:0] layer_one_out [7:0],
    output reg done
);
    typedef enum logic [2:0] {
        s_IDLE    = 3'b000,
        s_LOAD    = 3'b001,
        s_LAYER_1 = 3'b010,
        s_LAYER_2 = 3'b011,
        s_LAYER_3 = 3'b100
    } state_t;
    
    logic [4:0] row, col;
    logic [3:0] weight_num;

    logic comb0 [7:0], comb1, comb2, comb3;

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
                    if (col < 27) begin
                        col <= col + 1;
                    end else begin
                        if (row < 27) begin
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
    
    logic [8:0] overlap;
    logic i, j;
    

    always_comb begin
            

    end
    /*


    Method 2: Pop Count
    window0 [8:0] = {~(pixels[row-1][col-1] ^ weights[weight_num][row-1][col-1]), ..., ~(pixels[row+1][col+1] ^ weights[weight_num][row+1][col+1])};
    window1 [8:0] = {~(pixels[row-1][col] ^ weights[weight_num][row-1][col]), ..., ~(pixels[row+1][col+2] ^ weights[weight_num][row+1][col+2])};
    window2 [8:0] = {~(pixels[row][col-1] ^ weights[weight_num][row][col-1]), ..., ~(pixels[row+2][col+1] ^ weights[weight_num][row+2][col+1])};
    window3 [8:0] = {~(pixels[row][col] ^ weights[weight_num][row][col]), ..., ~(pixels[row+2][col+2] ^ weights[weight_num][row+2][col+2])};

    assign layer_one_out[weight_num][row][col] = $countones (window0[8:0]) | $countones (window1[8:0]) | $countones (window2[8:0]) | $countones (window3[8:0]);

    Method 2: Adders
    conv_norm_out_0 = ( ~(pixels[row-1][col-1] ^ weights[weight_num][row-1][col-1]) + ... + ~(pixels[row+1][col+1] ^ weights[weight_num][row+1][col+1]) ) >= thresh ? 1 : 0
    conv_norm_out_1 = ( ~(pixels[row-1][col] ^ weights[weight_num][row-1][col]) + ... + ~(pixels[row+1][col+2] ^ weights[weight_num][row+1][col+2]) ) >= thresh ? 1 : 0
    conv_norm_out_2 = ( ~(pixels[row][col-1] ^ weights[weight_num][row][col-1]) + ... + ~(pixels[row+2][col+1] ^ weights[weight_num][row+2][col+1]) ) >= thresh ? 1 : 0
    conv_norm_out_3 = ( ~(pixels[row][col] ^ weights[weight_num][row][col]) + ... + ~(pixels[row+2][col+2] ^ weights[weight_num][row+2][col+2]) ) >= thresh ? 1 : 0

    assign layer_one_out[weight_num][row][col] = conv_norm_out_0 | conv_norm_out_1 | conv_norm_out_2 | conv_norm_out_3;




    Pseudo Code:

    assign layer_

    function [8:0] conv;
        input logic [4:0] row, col;
        input logic [27:0] pixels [27:0];
        input logic [2:0][2:0] weights [7:0];
        input logic [3:0] weight_num;
        begin
        //assign all possible padded areas in the pixel matrix to either 0 or the pixel value
            assign mid_left = col == 0 ? 0 : pixel[row][col-1]
            assign mid_right = col == 27 ? 0 : pixel[row][col+1]
            assign mid_up = row == 0 ? 0 : pixel[row-1][col]
            assign mid_down = row == 27 ? pixel[row+1][col]
            assign top_left =  row == 0 & col == 0 ? 0 : pixel[row-1][col-1]
            assign top_right = row == 0 & col == 27 ? 0 : pixel[row-1][col+1]
            assign bot_left = row == 27 & col == 0 ? 0 : pixel[row+1][col-1]
            assign bot_right = row == 27 & col == 27 ? 0 : pixel[row+1][col+1]

            // Assign the convolution + norm
            conv = {~(mid_left ^ weights[weight_num][row-1][col-1]), ~(mid_right ^ weights[weight_num][row][col+1]), ..., ~(pixels[row][col] ^ weights[weight_num][row][col]), ..., ~(bot_right ^ weights[weight_num][row+1][col+1])};
        end
    endfunction
    
    
    */


endmodule


