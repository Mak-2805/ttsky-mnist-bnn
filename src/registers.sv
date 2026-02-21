// Pixel-only shift register (weights are now hardcoded in each layer).
//
// Loading: 784 bits, raster order, via d_in_p.
// load_done asserts after all 784 pixel bits have been shifted in.

module registers(
    input clk,
    input reset_n,
    input logic [2:0] state,
    input d_in_p,
    output logic [783:0] pixels,
    output logic load_done
);

    localparam s_LOAD = 3'b001;

    wire sync_out_pixel = d_in_p;

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

    assign load_done = pic_done;

endmodule
