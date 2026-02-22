module layer_one (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [2:0]  state,

    input  wire [783:0]  pixels,      // 28x28
    input  wire [71:0]   weights,     // 3x3x8

    output reg  [1567:0] layer_one_out, // 14x14x8
    output reg           done
);

    localparam s_LAYER_1 = 3'b010;

    // Counters
    reg [4:0] row;
    reg [4:0] col;
    reg [3:0] weight_num;

    // Threshold ROM (constant)
    function [3:0] threshold;
        input [3:0] w;
        begin
            case (w)
                0: threshold = 4'd6;
                1: threshold = 4'd5;
                2: threshold = 4'd5;
                3: threshold = 4'd6;
                4: threshold = 4'd8;
                5: threshold = 4'd8;
                6: threshold = 4'd8;
                7: threshold = 4'd6;
                default: threshold = 4'd6;
            endcase
        end
    endfunction

    // -------------------------
    // Index helpers
    // -------------------------

    function [9:0] pix_idx;
        input [4:0] r;
        input [4:0] c;
        begin
            pix_idx = r * 28 + c;
        end
    endfunction

    function [6:0] wt_idx;
        input [1:0] r;
        input [1:0] c;
        input [3:0] w;
        begin
            wt_idx = w*9 + r*3 + c;
        end
    endfunction

    function [10:0] out_idx;
        input [3:0] w;
        input [4:0] r;
        input [4:0] c;
        begin
            out_idx = w*196 + r*14 + c;
        end
    endfunction

    // -------------------------
    // Count ones (popcount 9-bit)
    // -------------------------

    function [3:0] popcount9;
        input [8:0] val;
        integer i;
        begin
            popcount9 = 0;
            for (i=0; i<9; i=i+1)
                popcount9 = popcount9 + val[i];
        end
    endfunction

    // -------------------------
    // Convolution (combinational)
    // -------------------------

    function [8:0] conv;
        input [4:0] r;
        input [4:0] c;
        input [3:0] w;

        reg p[0:8];
        integer i;
        begin
            // 3x3 neighborhood
            p[0] = (r==0  || c==0 ) ? 0 : pixels[pix_idx(r-1,c-1)];
            p[1] = (r==0)            ? 0 : pixels[pix_idx(r-1,c)];
            p[2] = (r==0  || c==27) ? 0 : pixels[pix_idx(r-1,c+1)];

            p[3] = (c==0)            ? 0 : pixels[pix_idx(r,c-1)];
            p[4] = pixels[pix_idx(r,c)];
            p[5] = (c==27)           ? 0 : pixels[pix_idx(r,c+1)];

            p[6] = (r==27 || c==0 ) ? 0 : pixels[pix_idx(r+1,c-1)];
            p[7] = (r==27)           ? 0 : pixels[pix_idx(r+1,c)];
            p[8] = (r==27 || c==27) ? 0 : pixels[pix_idx(r+1,c+1)];

            for (i=0; i<9; i=i+1)
                conv[i] = ~(p[i] ^ weights[w*9 + i]);
        end
    endfunction

    // -------------------------
    // Sequential control + write
    // -------------------------

    reg [8:0] c00, c01, c10, c11;
    reg [3:0] max_count;
    reg result_bit;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row <= 0;
            col <= 0;
            weight_num <= 0;
            done <= 0;
            layer_one_out <= 0;
        end
        else begin
            if (state == s_LAYER_1) begin

                // Compute 2x2 block (stride=2)
                c00 <= conv(row<<1,     col<<1,     weight_num);
                c01 <= conv(row<<1,     (col<<1)+1, weight_num);
                c10 <= conv((row<<1)+1, col<<1,     weight_num);
                c11 <= conv((row<<1)+1, (col<<1)+1, weight_num);

                // Max pooling on popcount
                max_count <= popcount9(c00);

                if (popcount9(c01) > max_count)
                    max_count <= popcount9(c01);
                if (popcount9(c10) > max_count)
                    max_count <= popcount9(c10);
                if (popcount9(c11) > max_count)
                    max_count <= popcount9(c11);

                result_bit <= (max_count >= threshold(weight_num));

                layer_one_out[out_idx(weight_num,row,col)] <= result_bit;

                // Counters
                if (col < 13)
                    col <= col + 1;
                else begin
                    col <= 0;
                    if (row < 13)
                        row <= row + 1;
                    else begin
                        row <= 0;
                        if (weight_num < 7)
                            weight_num <= weight_num + 1;
                        else
                            done <= 1;
                    end
                end
            end
        end
    end

endmodule