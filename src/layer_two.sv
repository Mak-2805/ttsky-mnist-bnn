module layer_two (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [2:0]  state,

    input  wire [1567:0] pixels,
    input  wire [287:0]  weights,

    output reg  [195:0] layer_two_out,
    output reg          done
);

    localparam s_LAYER_2 = 3'b011;

    reg [3:0] row;
    reg [3:0] col;
    reg [1:0] weight_num;  // only 0-3 needed

    // ------------------------------------------------
    // Threshold ROM
    // ------------------------------------------------
    function [6:0] threshold;
        input [1:0] w;
        begin
            case (w)
                2'd0: threshold = 7'd41;
                2'd1: threshold = 7'd42;
                2'd2: threshold = 7'd35;
                2'd3: threshold = 7'd37;
            endcase
        end
    endfunction

    // ------------------------------------------------
    // Pixel extractor
    // ------------------------------------------------
    function [7:0] get_pixel;
        input [3:0] r, c;
        integer base, i;
        reg [7:0] tmp;
        begin
            base = r*14 + c;
            for (i=0;i<8;i=i+1)
                tmp[i] = pixels[base*8 + i];
            get_pixel = tmp;
        end
    endfunction

    // ------------------------------------------------
    // 72-bit popcount
    // ------------------------------------------------
    function [6:0] popcount72;
        input [71:0] val;
        integer i;
        begin
            popcount72 = 0;
            for (i=0;i<72;i=i+1)
                popcount72 = popcount72 + val[i];
        end
    endfunction

    // ------------------------------------------------
    // Convolution (3x3x8 XNOR)
    // ------------------------------------------------
    function [71:0] conv;
        input [3:0] r, c;
        input [1:0] w;

        reg [7:0] px;
        integer kr, kc, idx;
        begin
            idx = 0;
            for (kr=0; kr<3; kr=kr+1) begin
                for (kc=0; kc<3; kc=kc+1) begin

                    if (r+kr==0 || c+kc==0 ||
                        r+kr==14 || c+kc==14)
                        px = 8'b0;
                    else
                        px = get_pixel(r+kr-1, c+kc-1);

                    conv[idx +:8] = ~(px ^ weights[w*72 + idx +:8]);
                    idx = idx + 8;
                end
            end
        end
    endfunction

    // ------------------------------------------------
    // Output index
    // ------------------------------------------------
    function [7:0] out_idx;
        input [1:0] w;
        input [3:0] r, c;
        begin
            out_idx = w*49 + r*7 + c;
        end
    endfunction

    // ------------------------------------------------
    // Sequential execution
    // ------------------------------------------------
    reg [71:0] c00, c01, c10, c11;
    reg [6:0]  max_count;
    reg result;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row <= 0;
            col <= 0;
            weight_num <= 0;
            done <= 0;
            layer_two_out <= 0;
        end
        else begin
            if (state == s_LAYER_2) begin

                // 2x2 window
                c00 <= conv(row<<1,     col<<1,     weight_num);
                c01 <= conv(row<<1,     (col<<1)+1, weight_num);
                c10 <= conv((row<<1)+1, col<<1,     weight_num);
                c11 <= conv((row<<1)+1, (col<<1)+1, weight_num);

                max_count <= popcount72(c00);

                if (popcount72(c01) > max_count)
                    max_count <= popcount72(c01);
                if (popcount72(c10) > max_count)
                    max_count <= popcount72(c10);
                if (popcount72(c11) > max_count)
                    max_count <= popcount72(c11);

                result <= (max_count >= threshold(weight_num));

                layer_two_out[out_idx(weight_num,row,col)] <= result;

                // counters
                if (col < 6)
                    col <= col + 1;
                else begin
                    col <= 0;
                    if (row < 6)
                        row <= row + 1;
                    else begin
                        row <= 0;
                        if (weight_num < 3)
                            weight_num <= weight_num + 1;
                        else
                            done <= 1;
                    end
                end
            end
        end
    end

endmodule