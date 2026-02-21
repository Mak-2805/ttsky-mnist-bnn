// Rewritten for Icarus Verilog 10.2 / Verilog-2001 compatibility.
// Replaces SystemVerilog-only features from the original:
//   always_ff / always_comb  -> always @(posedge clk) / always @(*)
//   logic                    -> reg / wire
//   typedef enum (state_t)   -> [2:0] + localparam
//   packed multi-dim arrays  -> flat 1-D arrays
//   $countones               -> count_ones72 function
//
// Flat array encoding (matches layer_one.sv conventions):
//   pixels        [1567:0]  (row*14 + col)*8 + ch          (14x14x8 bits)
//   weights       [287:0]   wt_num*72 + (row*3+col)*8 + ch (4x3x3x8 bits)
//   layer_two_out [195:0]   wn*49 + row*7 + col            (4x7x7 bits)
//
// Sequential max-pool: pool_cnt (0-3) cycles through the 4 positions of
// the 2x2 pool window one per clock, accumulating the OR result.
// This replaces the previous 4-simultaneous-conv approach which created
// too large a combinational mux tree for synthesis.

module layer_two (
    input wire clk, rst_n,
    input wire [2:0] state,

    input wire [1567:0] pixels,    // layer_one_out: 14x14 pixels, 8 channels each
    input wire [287:0]  weights,   // 4 filters of 3x3x8 binary weights

    output reg [195:0] layer_two_out,  // 4 filters of 7x7 binary output
    output reg done
);

    localparam [2:0] s_LAYER_2 = 3'b011;

    reg [3:0] row, col;
    reg [3:0] weight_num;
    reg [1:0] pool_cnt;  // 0-3: which 2x2 pool position is being computed
    reg       pool_acc;  // running OR across the 4 pool positions

    // -----------------------------------------------------------------------
    // Per-filter batch-norm thresholds (72-bit popcount space):
    //   Filter 0: 41,  Filter 1: 42,  Filter 2: 35,  Filter 3: 37
    // -----------------------------------------------------------------------
    function [6:0] get_threshold;
        input [3:0] wt_num;
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

    // -----------------------------------------------------------------------
    // Extract an 8-bit pixel from the flat array at position (r, c)
    // Encoding: pixels[(r*14 + c)*8 + ch] for ch in 0..7
    // -----------------------------------------------------------------------
    function [7:0] get_pixel;
        input [3:0] r, c;
        integer base, i;
        reg [7:0] result;
        begin
            base   = r * 14 + c;
            result = 8'b0;
            for (i = 0; i < 8; i = i + 1)
                result[i] = pixels[base * 8 + i];
            get_pixel = result;
        end
    endfunction

    // -----------------------------------------------------------------------
    // Count the number of 1-bits in a 72-bit value (replaces $countones)
    // -----------------------------------------------------------------------
    function [6:0] count_ones72;
        input [71:0] val;
        integer i;
        reg [6:0] cnt;
        begin
            cnt = 7'b0;
            for (i = 0; i < 72; i = i + 1)
                cnt = cnt + val[i];
            count_ones72 = cnt;
        end
    endfunction

    // -----------------------------------------------------------------------
    // Flat index into layer_two_out: wn*49 + r*7 + c
    // -----------------------------------------------------------------------
    function [7:0] out_idx;
        input [3:0] wn, r, c;
        integer tmp;
        begin
            tmp     = wn * 49 + r * 7 + c;
            out_idx = tmp[7:0];
        end
    endfunction

    // -----------------------------------------------------------------------
    // 3x3 XNOR convolution over the 8-channel binary feature map.
    // Returns 72 bits: 9 kernel positions x 8 channels of XNOR matches.
    // Accesses module-level 'pixels' and 'weights' directly.
    //
    // Weight slice for filter wt_num at kernel position (kr, kc):
    //   weights[wt_num*72 + (kr*3+kc)*8 +: 8]  (one bit per input channel)
    // -----------------------------------------------------------------------
    function [71:0] conv;
        input [3:0] r, c;
        input [3:0] wt_num;

        reg [7:0] tl, tm, tr;
        reg [7:0] ml, mm, mr;
        reg [7:0] bl, bm, br;
        integer   wn;

        begin
            wn = wt_num;

            // Zero-pad at boundaries of the 14x14 input (valid indices 0-13)
            tl = (r == 0 || c == 0)  ? 8'b0 : get_pixel(r-1, c-1);
            tm = (r == 0)            ? 8'b0 : get_pixel(r-1, c);
            tr = (r == 0 || c == 13) ? 8'b0 : get_pixel(r-1, c+1);

            ml = (c == 0)            ? 8'b0 : get_pixel(r, c-1);
            mm =                               get_pixel(r, c);
            mr = (c == 13)           ? 8'b0 : get_pixel(r, c+1);

            bl = (r == 13 || c == 0)  ? 8'b0 : get_pixel(r+1, c-1);
            bm = (r == 13)            ? 8'b0 : get_pixel(r+1, c);
            br = (r == 13 || c == 13) ? 8'b0 : get_pixel(r+1, c+1);

            // XNOR each 8-channel pixel against its 8-bit weight slice for filter wn.
            // Each channel has its own independent weight bit.
            conv = {
                ~(tl ^ weights[wn*72 +  0 +: 8]),   // kernel[0][0]
                ~(tm ^ weights[wn*72 +  8 +: 8]),   // kernel[0][1]
                ~(tr ^ weights[wn*72 + 16 +: 8]),   // kernel[0][2]
                ~(ml ^ weights[wn*72 + 24 +: 8]),   // kernel[1][0]
                ~(mm ^ weights[wn*72 + 32 +: 8]),   // kernel[1][1]
                ~(mr ^ weights[wn*72 + 40 +: 8]),   // kernel[1][2]
                ~(bl ^ weights[wn*72 + 48 +: 8]),   // kernel[2][0]
                ~(bm ^ weights[wn*72 + 56 +: 8]),   // kernel[2][1]
                ~(br ^ weights[wn*72 + 64 +: 8])    // kernel[2][2]
            };
        end
    endfunction

    // -----------------------------------------------------------------------
    // Combinational: ONE conv per cycle, selected by pool_cnt.
    // pool_cnt[1] selects the row offset (0 or 1) within the 2x2 pool window.
    // pool_cnt[0] selects the col offset (0 or 1).
    // -----------------------------------------------------------------------
    reg [3:0] pool_r, pool_c;
    reg [71:0] cr;
    reg [6:0]  thresh;
    reg        out_bit;

    always @(*) begin
        pool_r  = pool_cnt[1] ? ((row << 1) + 1) : (row << 1);
        pool_c  = pool_cnt[0] ? ((col << 1) + 1) : (col << 1);
        thresh  = get_threshold(weight_num);
        cr      = conv(pool_r, pool_c, weight_num);
        out_bit = (count_ones72(cr) > thresh);
    end

    // -----------------------------------------------------------------------
    // Sequential state machine: iterate through 4 filters x 7x7 output grid.
    // Each output pixel takes 4 cycles (one per 2x2 pool position).
    // -----------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            row           <= 4'b0;
            col           <= 4'b0;
            done          <= 1'b0;
            weight_num    <= 4'b0;
            layer_two_out <= 0;
            pool_cnt      <= 2'b0;
            pool_acc      <= 1'b0;
        end
        else begin
            if (state == s_LAYER_2) begin
                if (weight_num < 4) begin
                    if (pool_cnt < 3) begin
                        // Accumulate max-pool: OR in this position's result
                        pool_acc <= pool_acc | out_bit;
                        pool_cnt <= pool_cnt + 1;
                    end else begin
                        // Last pool position: write final result and advance
                        layer_two_out[out_idx(weight_num, row, col)] <= pool_acc | out_bit;
                        pool_cnt <= 2'b0;
                        pool_acc <= 1'b0;
                        if (col < 6) begin
                            col <= col + 1;
                        end else begin
                            if (row < 6) begin
                                row <= row + 1;
                                col <= 4'b0;
                            end else begin
                                row        <= 4'b0;
                                col        <= 4'b0;
                                weight_num <= weight_num + 1;
                            end
                        end
                    end
                end else begin
                    done <= 1'b1;
                end
            end
        end
    end

endmodule
