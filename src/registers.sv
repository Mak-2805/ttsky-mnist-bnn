module registers(
    input  wire        clk,
    input  wire        reset_n,
    input  wire [2:0]  state,
    input  wire        d_in_p,
    input  wire        d_in_w,
    output reg  [783:0] pixels,
    output reg  [71:0]  weights1,
    output reg  [287:0] weights2,
    output reg [1959:0] weights3,
    output wire        load_done
);

    localparam s_LOAD = 3'b001;

    // Temporary wires (pipeline stage bypassed)
    wire sync_out_pixel = d_in_p;
    wire sync_out_weight = d_in_w;

    // -----------------------------
    // Pixel loader (28x28)
    // -----------------------------
    reg [4:0] row, col;
    reg pic_done;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            pixels   <= 0;
            row      <= 0;
            col      <= 0;
            pic_done <= 0;
        end else if ((state == s_LOAD) && !pic_done) begin
            pixels[row*28 + col] <= sync_out_pixel;
            if (col < 27) begin
                col <= col + 1;
            end else begin
                col <= 0;
                if (row < 27) begin
                    row <= row + 1;
                end else begin
                    pic_done <= 1;
                end
            end
        end
    end

    // -----------------------------
    // weights1 loader (3x3x8)
    // -----------------------------
    reg [1:0] bitt, trit;
    reg [2:0] level;
    reg w_done;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            weights1 <= 0;
            bitt     <= 0;
            trit     <= 0;
            level    <= 0;
            w_done   <= 0;
        end else if ((state == s_LOAD) && !w_done) begin
            weights1[trit*24 + bitt*8 + level] <= sync_out_weight;

            if (bitt < 2)
                bitt <= bitt + 1;
            else begin
                bitt <= 0;
                if (trit < 2)
                    trit <= trit + 1;
                else begin
                    trit <= 0;
                    if (level < 7)
                        level <= level + 1;
                    else
                        w_done <= 1;
                end
            end
        end
    end

    // -----------------------------
    // weights2 loader (4x3x3x8)
    // -----------------------------
    reg [1:0] bitt1, trit1, level1;
    reg [2:0] chan1;
    reg w_done1;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            weights2 <= 0;
            bitt1    <= 0;
            trit1    <= 0;
            level1   <= 0;
            chan1    <= 0;
            w_done1  <= 0;
        end else if ((state == s_LOAD) && w_done && !w_done1) begin
            weights2[level1*72 + (trit1*3 + bitt1)*8 + chan1] <= sync_out_weight;

            if (chan1 < 7)
                chan1 <= chan1 + 1;
            else begin
                chan1 <= 0;
                if (bitt1 < 2)
                    bitt1 <= bitt1 + 1;
                else begin
                    bitt1 <= 0;
                    if (trit1 < 2)
                        trit1 <= trit1 + 1;
                    else begin
                        trit1 <= 0;
                        if (level1 < 3)
                            level1 <= level1 + 1;
                        else
                            w_done1 <= 1;
                    end
                end
            end
        end
    end

    // -----------------------------
    // weights3 loader (10x196)
    // -----------------------------
    reg [3:0] neuron_w3;
    reg [7:0] bit_w3;
    reg w_done3;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            weights3  <= 0;
            neuron_w3 <= 0;
            bit_w3    <= 0;
            w_done3   <= 0;
        end else if ((state == s_LOAD) && w_done && w_done1 && !w_done3) begin
            weights3[neuron_w3*196 + bit_w3] <= sync_out_weight;

            if (bit_w3 < 195)
                bit_w3 <= bit_w3 + 1;
            else begin
                bit_w3 <= 0;
                if (neuron_w3 < 9)
                    neuron_w3 <= neuron_w3 + 1;
                else
                    w_done3 <= 1;
            end
        end
    end

    // -----------------------------
    // Load done signal
    // -----------------------------
    assign load_done = pic_done & w_done & w_done1 & w_done3;

endmodule