`timescale 1ns / 1ps

// Rewritten to use shift registers for all storage.
//
// The original design used variable-index writes (e.g. pixels[row*28+col]),
// which Yosys must implement as a multiply-add address followed by a 784-way
// enable decoder — extremely expensive in synthesis memory.
//
// Since loading is always sequential (serial bits in raster/sequential order),
// shift registers are functionally identical: bit k loaded on cycle k ends up
// at position k in the final register, matching the original addressing.
//
// Loading order (unchanged from original):
//   pixels:   784 bits, raster order,         via d_in_p  (parallel with weights1)
//   weights1:  72 bits, sequential,            via d_in_w
//   weights2: 288 bits, sequential after w1,   via d_in_w
//   weights3: 1960 bits, sequential after w2,  via d_in_w

module registers(
    input clk,
    input reset_n,
    input logic [2:0] state,
    input d_in_p,
    input d_in_w,
    output logic [783:0] pixels,
    output logic [71:0] weights1,
    output logic [287:0] weights2,
    output logic [1959:0] weights3,
    output logic load_done
);

    localparam s_LOAD = 3'b001;

    wire sync_out_pixel  = d_in_p;
    wire sync_out_weight = d_in_w;

    // -----------------------------------------------------------------------
    // Pixel shift register (784 bits).
    // New bit enters at MSB, existing bits shift right.
    // After 784 cycles: pixels[k] = k-th pixel sent (raster order row*28+col).
    // -----------------------------------------------------------------------
    logic [9:0] pixel_cnt;
    logic       pic_done;

    always @(posedge clk) begin
        if (!reset_n) begin
            pixels    <= 'd0;
            pixel_cnt <= 10'd0;
            pic_done  <= 1'b0;
        end else if (state == s_LOAD && ~pic_done) begin
            pixels <= {sync_out_pixel, pixels[783:1]};
            if (pixel_cnt < 783) begin
                pixel_cnt <= pixel_cnt + 1;
            end else begin
                pic_done <= 1'b1;
            end
        end
    end

    // -----------------------------------------------------------------------
    // weights1 shift register (72 bits). Loads in parallel with pixels.
    // After 72 cycles: weights1[k] = k-th weight bit sent.
    // -----------------------------------------------------------------------
    logic [6:0] w1_cnt;
    logic       w_done;

    always @(posedge clk) begin
        if (!reset_n) begin
            weights1 <= 'd0;
            w1_cnt   <= 7'd0;
            w_done   <= 1'b0;
        end else if (state == s_LOAD && ~w_done) begin
            weights1 <= {sync_out_weight, weights1[71:1]};
            if (w1_cnt < 71) begin
                w1_cnt <= w1_cnt + 1;
            end else begin
                w_done <= 1'b1;
            end
        end
    end

    // -----------------------------------------------------------------------
    // weights2 shift register (288 bits). Loads after weights1 is done.
    // After 288 cycles: weights2[k] = k-th weight2 bit sent.
    // -----------------------------------------------------------------------
    logic [8:0] w2_cnt;
    logic       w_done1;

    always @(posedge clk) begin
        if (!reset_n) begin
            weights2 <= 'd0;
            w2_cnt   <= 9'd0;
            w_done1  <= 1'b0;
        end else if (state == s_LOAD && w_done && ~w_done1) begin
            weights2 <= {sync_out_weight, weights2[287:1]};
            if (w2_cnt < 287) begin
                w2_cnt <= w2_cnt + 1;
            end else begin
                w_done1 <= 1'b1;
            end
        end
    end

    // -----------------------------------------------------------------------
    // weights3 shift register (1960 bits). Loads after weights2 is done.
    // After 1960 cycles: weights3[k] = k-th weight3 bit sent.
    // -----------------------------------------------------------------------
    logic [10:0] w3_cnt;
    logic        w_done3;

    always @(posedge clk) begin
        if (!reset_n) begin
            weights3 <= 'd0;
            w3_cnt   <= 11'd0;
            w_done3  <= 1'b0;
        end else if (state == s_LOAD && w_done && w_done1 && ~w_done3) begin
            weights3 <= {sync_out_weight, weights3[1959:1]};
            if (w3_cnt < 1959) begin
                w3_cnt <= w3_cnt + 1;
            end else begin
                w_done3 <= 1'b1;
            end
        end
    end

    assign load_done = (pic_done && w_done && w_done1 && w_done3) ? 1'b1 : 1'b0;

endmodule
