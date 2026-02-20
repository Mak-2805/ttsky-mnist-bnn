`timescale 1ns/1ps
//
// tb_report_comparison.sv
//
// SystemVerilog equivalent of report_comparison.py:
//   - Reads real MNIST images directly from the packed binary dataset
//   - Loads trained weights and batch-norm thresholds from .mem files
//   - Drives the layer_one DUT for each image (iverilog + vvp, not Python)
//   - Computes a golden software reference (same logic as Python run_layer_one)
//   - Prints a per-kernel pass/fail comparison report with 14x14 grids
//
// Compile (from test/layer_one_tb/):
//   iverilog -g2012 -o tb_report_comparison.vvp \
//            ../../src/layer_one.sv tb_report_comparison.sv
// Run:
//   vvp tb_report_comparison.vvp
// Run with a different image count:
//   vvp tb_report_comparison.vvp +NUM_IMAGES=20

module tb_report_comparison;

    // -----------------------------------------------------------------
    // DUT signals
    // -----------------------------------------------------------------
    logic         clk;
    logic         rst_n;
    logic  [2:0]  state;
    logic [783:0] pixels;
    logic  [71:0] wt_vec;
    logic [1567:0] layer_one_out;
    logic          done;

    // -----------------------------------------------------------------
    // DUT instantiation
    // -----------------------------------------------------------------
    layer_one dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .state        (state),
        .pixels       (pixels),
        .weights      (wt_vec),
        .layer_one_out(layer_one_out),
        .done         (done)
    );

    // -----------------------------------------------------------------
    // 100 MHz clock
    // -----------------------------------------------------------------
    initial clk = 1'b0;
    always  #5  clk = ~clk;

    // -----------------------------------------------------------------
    // Persistent data storage
    // -----------------------------------------------------------------
    // raw_weights[k] is 9 bits; $readmemb puts first char at MSB ([8])
    logic [8:0] raw_weights [0:7];
    // One threshold byte per kernel
    logic [7:0] thresholds  [0:7];
    // Unpacked 3-D weight array: weight_bits[kernel][row][col]
    logic       weight_bits [0:7][0:2][0:2];
    // Current image: pixel_arr[row][col]
    logic       pixel_arr   [0:27][0:27];

    // -----------------------------------------------------------------
    // Module-level scratch variables
    // (declared here so tasks can share them without automatic storage)
    // -----------------------------------------------------------------
    integer img_fd, lbl_fd, frd_ret;
    logic [7:0]    tmp_byte;
    logic [7:0]    label_byte;
    logic [1567:0] golden_out;   // software golden reference result
    logic [1567:0] hw_out;       // captured DUT result
    logic [1567:0] mm_mask;      // mismatch bitmask
    logic          timed_out;
    integer        num_images;
    integer        i, k, r, c;
    integer        byte_idx, bit_idx, px_idx;
    integer        k2, kr, kc, pr2, pc2;
    integer        num_mm, img_errors, total_errors, total_checks;

    // -----------------------------------------------------------------
    // out_idx: matches layer_one.sv out_idx(w,r,c) = w*196 + r*14 + c
    // -----------------------------------------------------------------
    function automatic integer out_idx(
        input integer wn,
        input integer ro,
        input integer co
    );
        return wn * 196 + ro * 14 + co;
    endfunction

    // -----------------------------------------------------------------
    // Task: compute_golden
    //
    // Software implementation of layer_one's conv + threshold + max-pool,
    // matching report_comparison.py::run_layer_one().
    //
    // Reads module-level pixel_arr, weight_bits, thresholds.
    // Writes result into module-level golden_out.
    //
    // Note: threshold source matches the .mem file (alternates 5/6),
    // which is identical to the hardware formula 5 + (weight_num & 1).
    // -----------------------------------------------------------------
    task compute_golden;
        integer gk, gr, gc, gpr, gpc, gkr, gkc;
        integer g_pixr, g_pixc, g_prpos, g_pcpos, g_matches, g_thresh;
        logic   g_pval, g_wval, g_maxval;

        for (gk = 0; gk < 8; gk++) begin
            g_thresh = thresholds[gk];
            for (gr = 0; gr < 14; gr++) begin
                for (gc = 0; gc < 14; gc++) begin
                    g_maxval = 1'b0;
                    // Max-pool over 2x2 sub-window
                    for (gpr = 0; gpr < 2; gpr++) begin
                        for (gpc = 0; gpc < 2; gpc++) begin
                            g_pixr    = gr * 2 + gpr;
                            g_pixc    = gc * 2 + gpc;
                            g_matches = 0;
                            // 3x3 convolution
                            for (gkr = 0; gkr < 3; gkr++) begin
                                for (gkc = 0; gkc < 3; gkc++) begin
                                    g_prpos = g_pixr + gkr - 1;
                                    g_pcpos = g_pixc + gkc - 1;
                                    // Zero-pad outside image bounds
                                    if (g_prpos < 0 || g_prpos >= 28 ||
                                        g_pcpos < 0 || g_pcpos >= 28)
                                        g_pval = 1'b0;
                                    else
                                        g_pval = pixel_arr[g_prpos][g_pcpos];
                                    g_wval = weight_bits[gk][gkr][gkc];
                                    // XNOR: count matches
                                    if (g_pval == g_wval)
                                        g_matches = g_matches + 1;
                                end
                            end
                            if (g_matches >= g_thresh) g_maxval = 1'b1;
                        end
                    end
                    golden_out[out_idx(gk, gr, gc)] = g_maxval;
                end
            end
        end
    endtask

    // -----------------------------------------------------------------
    // Task: run_image
    //
    // Resets DUT, applies state=s_LAYER_1, waits for done (or timeout).
    // pixels and wt_vec must already be loaded before calling.
    // Result is written to module-level hw_out; timed_out set on timeout.
    //
    // Uses a polling while-loop instead of fork/join_any to avoid an
    // iverilog assertion failure with disable fork inside initial blocks.
    // -----------------------------------------------------------------
    task run_image;
        integer wd;
        rst_n     = 1'b0;
        state     = 3'b000;
        timed_out = 1'b0;
        repeat(5) @(posedge clk);
        rst_n = 1'b1;
        repeat(2) @(posedge clk);
        state = 3'b010;
        // Poll for done; give up after 100 000 cycles (~1 ms at 100 MHz)
        wd = 0;
        while (!done && wd < 100_000) begin
            @(posedge clk);
            wd = wd + 1;
        end
        if (!done) begin
            timed_out = 1'b1;
        end else begin
            // One extra edge so layer_one_out combinational output is settled
            @(posedge clk);
            hw_out = layer_one_out;
        end
    endtask

    // -----------------------------------------------------------------
    // Task: print_image
    // Prints module-level pixel_arr as a 28x28 ASCII grid (#=1, ' '=0).
    // -----------------------------------------------------------------
    task print_image;
        integer pi_r, pi_c;
        for (pi_r = 0; pi_r < 28; pi_r++) begin
            $write("  ");
            for (pi_c = 0; pi_c < 28; pi_c++) begin
                if (pixel_arr[pi_r][pi_c]) $write("#");
                else                        $write(" ");
            end
            $display("");
        end
    endtask

    // -----------------------------------------------------------------
    // Task: print_grid
    // Prints a 14x14 slice of a 1568-bit vector for one kernel.
    //   data     - full 1568-bit output vector
    //   kernel   - which of the 8 kernels to print
    //   mm       - mismatch mask (used when show_mm=1)
    //   show_mm  - 1: replace mismatched bits with 'X'
    // -----------------------------------------------------------------
    task print_grid;
        input [1567:0] data;
        input integer  kernel;
        input [1567:0] mm;
        input          show_mm;
        integer pg_r, pg_c;
        for (pg_r = 0; pg_r < 14; pg_r++) begin
            $write("    ");
            for (pg_c = 0; pg_c < 14; pg_c++) begin
                if (show_mm && mm[out_idx(kernel, pg_r, pg_c)])
                    $write("X");
                else if (data[out_idx(kernel, pg_r, pg_c)])
                    $write("#");
                else
                    $write(".");
            end
            $display("");
        end
    endtask

    // =================================================================
    // Main stimulus
    // =================================================================
    initial begin : stimulus

        // -- NUM_IMAGES from +NUM_IMAGES=N or default 5 ---------------
        if (!$value$plusargs("NUM_IMAGES=%d", num_images))
            num_images = 5;

        // -- Load weights and thresholds from .mem files --------------
        $readmemb("../../src/Python311_training/weights/layer_0_weights.mem",
                  raw_weights);
        $readmemb("../../src/Python311_training/weights/layer_1_thresholds.mem",
                  thresholds);

        // Unpack raw_weights[k] (9-bit, MSB=first char) into
        // weight_bits[k][row][col].
        for (k2 = 0; k2 < 8; k2++)
            for (kr = 0; kr < 3; kr++)
                for (kc = 0; kc < 3; kc++)
                    weight_bits[k2][kr][kc] = raw_weights[k2][8 - (kr*3 + kc)];

        // Pack weight_bits into the flat wt_vec expected by the DUT.
        // wt_idx(row,col,wt_num) = row*24 + col*8 + wt_num (layer_one.sv)
        wt_vec = '0;
        for (k2 = 0; k2 < 8; k2++)
            for (kr = 0; kr < 3; kr++)
                for (kc = 0; kc < 3; kc++)
                    wt_vec[kr*24 + kc*8 + k2] = weight_bits[k2][kr][kc];

        // -- Open MNIST binary files ----------------------------------
        img_fd = $fopen(
            "../../src/Python311_training/training_data/mnist_binary_verifying.ubin",
            "rb");
        if (img_fd == 0) begin
            $display("ERROR: cannot open MNIST image file");
            $finish;
        end

        lbl_fd = $fopen(
            "../../src/Python311_training/training_data/mnist_binary_labels_verifying.ubin",
            "rb");
        if (lbl_fd == 0) begin
            $display("ERROR: cannot open MNIST label file");
            $finish;
        end

        // Skip binary headers:
        //   Image file: 4B magic + 4B count + 4B rows + 4B cols = 16 bytes
        //   Label file: 4B magic + 4B count                     =  8 bytes
        for (i = 0; i < 16; i++) frd_ret = $fread(tmp_byte, img_fd);
        for (i = 0; i <  8; i++) frd_ret = $fread(tmp_byte, lbl_fd);

        // -- Report header --------------------------------------------
        $display("======================================================================");
        $display("LAYER ONE: Hardware vs Golden Reference -- Comparison Report");
        $display("======================================================================");
        $display("Weights source : layer_0_weights.mem  (actual trained weights)");
        $display("Threshold src  : layer_1_thresholds.mem  (actual batch-norm thresholds)");
        $display("Image source   : mnist_binary_verifying.ubin  (real MNIST test set)");
        $display("Images tested  : %0d", num_images);
        $display("");

        $write("Kernel thresholds:");
        for (k = 0; k < 8; k++) $write(" %0d", thresholds[k]);
        $display("");

        $display("Kernels (3x3 weights, row-major):");
        for (k = 0; k < 8; k++) begin
            $write("  kernel %0d (threshold=%0d): ", k, thresholds[k]);
            for (kr = 0; kr < 3; kr++)
                for (kc = 0; kc < 3; kc++)
                    $write("%0d", weight_bits[k][kr][kc]);
            $display("");
        end
        $display("");

        total_errors = 0;
        total_checks = 0;

        // =============================================================
        // Per-image loop
        // =============================================================
        for (i = 0; i < num_images; i++) begin

            // -- Read one packed image --------------------------------
            // 28x28 = 784 bits = 98 bytes, stored MSB-first per byte
            // (np.unpackbits() convention: bit 7 of byte 0 = pixel [0][0])
            for (byte_idx = 0; byte_idx < 98; byte_idx++) begin
                frd_ret = $fread(tmp_byte, img_fd);
                for (bit_idx = 0; bit_idx < 8; bit_idx++) begin
                    px_idx = byte_idx * 8 + bit_idx;
                    if (px_idx < 784)
                        pixel_arr[px_idx / 28][px_idx % 28]
                            = tmp_byte[7 - bit_idx];  // MSB = first pixel
                end
            end

            // -- Read one label byte ----------------------------------
            frd_ret = $fread(label_byte, lbl_fd);

            // -- Pack pixel_arr into flat pixels vector ---------------
            // pix_idx(r,c) = r*28+c  (matches layer_one.sv)
            for (pr2 = 0; pr2 < 28; pr2++)
                for (pc2 = 0; pc2 < 28; pc2++)
                    pixels[pr2 * 28 + pc2] = pixel_arr[pr2][pc2];

            // -- Golden reference (pure software) ---------------------
            compute_golden();

            // -- Hardware run -----------------------------------------
            // pixels and wt_vec are already loaded above
            run_image();

            // -- Image banner -----------------------------------------
            $display("======================================================================");
            $display("Image %3d  |  True label: %0d", i, label_byte);
            $display("======================================================================");
            $display("  Input image (28x28):");
            print_image();
            $display("");

            if (timed_out) begin
                $display("  *** TIMEOUT: DUT did not assert done within 100000 cycles ***");
                $display("");
            end else begin
                // -- Per-kernel comparison ----------------------------
                img_errors = 0;
                for (k = 0; k < 8; k++) begin
                    num_mm  = 0;
                    mm_mask = '0;
                    for (r = 0; r < 14; r++)
                        for (c = 0; c < 14; c++)
                            if (golden_out[out_idx(k,r,c)] !== hw_out[out_idx(k,r,c)]) begin
                                mm_mask[out_idx(k,r,c)] = 1'b1;
                                num_mm = num_mm + 1;
                            end

                    img_errors   = img_errors   + num_mm;
                    total_errors = total_errors + num_mm;
                    total_checks = total_checks + 196;

                    if (num_mm == 0)
                        $display("  Kernel %0d (threshold=%0d)  PASS", k, thresholds[k]);
                    else
                        $display("  Kernel %0d (threshold=%0d)  FAIL (%0d mismatches)",
                                 k, thresholds[k], num_mm);

                    if (num_mm > 0) begin
                        $display("  Expected (golden model):");
                        print_grid(golden_out, k, '0, 1'b0);
                        $display("  Hardware output:");
                        print_grid(hw_out,     k, '0, 1'b0);
                        $display("  Difference (X = mismatch):");
                        print_grid(golden_out, k, mm_mask, 1'b1);
                    end else begin
                        $display("  Output (matches golden):");
                        print_grid(golden_out, k, '0, 1'b0);
                    end
                    $display("");
                end

                if (img_errors == 0)
                    $display("  Image %0d result: PASS", i);
                else
                    $display("  Image %0d result: FAIL -- %0d mismatches", i, img_errors);
                $display("");
            end
        end

        // -- Summary --------------------------------------------------
        $display("======================================================================");
        $display("SUMMARY");
        $display("======================================================================");
        $display("  Images tested : %0d", num_images);
        $display("  Total checks  : %0d  (%0d images x 8 kernels x 196 outputs)",
                 total_checks, num_images);
        $display("  Total errors  : %0d", total_errors);
        if (total_errors == 0)
            $display("  Result        : ALL PASS -- hardware matches golden model exactly");
        else
            $display("  Result        : FAIL -- %0d/%0d bits wrong",
                     total_errors, total_checks);
        $display("======================================================================");

        $fclose(img_fd);
        $fclose(lbl_fd);
        $finish;
    end

endmodule
