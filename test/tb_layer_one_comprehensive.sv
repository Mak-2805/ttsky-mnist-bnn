`timescale 1ns/1ps

import mnist_bnn_pkg::*;

module tb_layer_one_comprehensive;
    
    logic clock, reset;
    state_t state;
    logic [27:0][27:0] pixels;
    logic [7:0][2:0][2:0] weights;
    logic [7:0][13:0][13:0] layer_one_out;
    logic done;
    logic [7:0][13:0][13:0] expected_out;
    
    integer test_count, error_count, i, j, k;
    integer total_checks, passed_checks, mismatch_count;

    layer_one dut (
        .clk(clock), .rst_n(reset), .state(state),
        .pixels(pixels), .weights(weights),
        .layer_one_out(layer_one_out), .done(done)
    );

    initial begin clock = 0; forever #5 clock = ~clock; end
    initial begin #500000000; $display("TIMEOUT!"); $finish; end

    // GOLDEN REFERENCE MODEL
    function automatic logic [8:0] compute_conv(input integer r_idx, c_idx, k_idx);
        logic [8:0] xnor_res;
        logic p[0:8], w[0:8];
        begin
            p[0] = (r_idx == 0 || c_idx == 0)  ? 1'b0 : pixels[r_idx-1][c_idx-1];
            p[1] = (r_idx == 0)                 ? 1'b0 : pixels[r_idx-1][c_idx];
            p[2] = (r_idx == 0 || c_idx == 27) ? 1'b0 : pixels[r_idx-1][c_idx+1];
            p[3] = (c_idx == 0)  ? 1'b0 : pixels[r_idx][c_idx-1];
            p[4] = pixels[r_idx][c_idx];
            p[5] = (c_idx == 27) ? 1'b0 : pixels[r_idx][c_idx+1];
            p[6] = (r_idx == 27 || c_idx == 0)  ? 1'b0 : pixels[r_idx+1][c_idx-1];
            p[7] = (r_idx == 27)                 ? 1'b0 : pixels[r_idx+1][c_idx];
            p[8] = (r_idx == 27 || c_idx == 27) ? 1'b0 : pixels[r_idx+1][c_idx+1];
            
            w[0] = weights[k_idx][0][0]; w[1] = weights[k_idx][0][1]; w[2] = weights[k_idx][0][2];
            w[3] = weights[k_idx][1][0]; w[4] = weights[k_idx][1][1]; w[5] = weights[k_idx][1][2];
            w[6] = weights[k_idx][2][0]; w[7] = weights[k_idx][2][1]; w[8] = weights[k_idx][2][2];
            
            xnor_res = {~(p[0]^w[0]), ~(p[1]^w[1]), ~(p[2]^w[2]), ~(p[3]^w[3]), ~(p[4]^w[4]),
                        ~(p[5]^w[5]), ~(p[6]^w[6]), ~(p[7]^w[7]), ~(p[8]^w[8])};
            compute_conv = xnor_res;
        end
    endfunction

    function automatic integer count_matches(input logic [8:0] conv_result);
        integer cnt; begin cnt = 0;
            for (int b = 0; b < 9; b++) if (conv_result[b]) cnt++;
            count_matches = cnt;
        end
    endfunction

    function automatic logic apply_threshold(input integer match_count, kernel_idx);
        begin apply_threshold = (match_count >= (5 + (kernel_idx & 1))) ? 1'b1 : 1'b0; end
    endfunction

    task compute_golden_reference;
        integer ro, co, k, pr0, pc0, pr1, pc1, m00, m01, m10, m11;
        logic [8:0] c00, c01, c10, c11; logic a00, a01, a10, a11, pooled;
        begin
            for (k = 0; k < 8; k++) begin
                for (ro = 0; ro < 14; ro++) begin
                    for (co = 0; co < 14; co++) begin
                        pr0 = ro * 2; pc0 = co * 2; pr1 = ro * 2 + 1; pc1 = co * 2 + 1;
                        c00 = compute_conv(pr0, pc0, k); c01 = compute_conv(pr0, pc1, k);
                        c10 = compute_conv(pr1, pc0, k); c11 = compute_conv(pr1, pc1, k);
                        m00 = count_matches(c00); m01 = count_matches(c01);
                        m10 = count_matches(c10); m11 = count_matches(c11);
                        a00 = apply_threshold(m00, k); a01 = apply_threshold(m01, k);
                        a10 = apply_threshold(m10, k); a11 = apply_threshold(m11, k);
                        pooled = a00 | a01 | a10 | a11;
                        expected_out[k][ro][co] = pooled;
                    end
                end
            end
        end
    endtask

    task verify_all_outputs(input string test_name);
        integer k, ro, co;
        begin
            mismatch_count = 0;
            $display("  Verifying all 1,568 outputs (8 kernels � 14�14)...");
            for (k = 0; k < 8; k++) begin
                for (ro = 0; ro < 14; ro++) begin
                    for (co = 0; co < 14; co++) begin
                        total_checks++;
                        if (layer_one_out[k][ro][co] !== expected_out[k][ro][co]) begin
                            if (mismatch_count < 10) 
                                $display("ERROR: [%0d][%0d][%0d] expected:%0d got:%0d", 
                                         k, ro, co, expected_out[k][ro][co], layer_one_out[k][ro][co]);
                            mismatch_count++; error_count++;
                        end else passed_checks++;
                    end
                end
            end
            if (mismatch_count) 
                $display("  *** FAIL: %0d mismatches ***", mismatch_count);
            else 
                $display("  PASS: All 1,568 outputs MATCH!");
        end
    endtask

    task run_verified_test(input string test_name);
        begin
            test_count++;
            $display("\n[TEST %0d] %s", test_count, test_name);
            state = s_IDLE; reset = 0; #20; reset = 1; #10;
            compute_golden_reference();
            state = s_LAYER_1; #10;
            wait(done == 1);
            $display("  Completed at %0t ns", $time);
            verify_all_outputs(test_name);
        end
    endtask

    initial begin
        $display("TEST START - COMPREHENSIVE VALIDATION");
        $display("Checking ALL 1,568 outputs per test\n");
        test_count = 0; error_count = 0; total_checks = 0; passed_checks = 0;
        reset = 0; state = s_IDLE; pixels = '0; weights = '0; expected_out = '0; #10;

        // TEST 1: All zeros
        pixels = '0; weights = '0;
        run_verified_test("All Zeros (Perfect Match)");

        // TEST 2: All ones
        for (i=0; i<28; i++) for (j=0; j<28; j++) pixels[i][j] = 1'b1;
        for (i=0; i<8; i++) for (j=0; j<3; j++) for (k=0; k<3; k++) weights[i][j][k] = 1'b1;
        run_verified_test("All Ones (Perfect Match)");

        // TEST 3: Zeros vs Ones
        pixels = '0;
        for (i=0; i<8; i++) for (j=0; j<3; j++) for (k=0; k<3; k++) weights[i][j][k] = 1'b1;
        run_verified_test("Zeros vs Ones (Complete Mismatch)");

        // TEST 4: Checkerboard
        for (i=0; i<28; i++) for (j=0; j<28; j++) pixels[i][j] = (i+j) % 2;
        for (i=0; i<8; i++) for (j=0; j<3; j++) for (k=0; k<3; k++) weights[i][j][k] = (i+j+k) % 2;
        run_verified_test("Checkerboard Pattern");

        #100;
        $display("\n========================================");
        $display("COMPREHENSIVE TEST SUMMARY:");
        $display("  Tests: %0d", test_count);
        $display("  Total Checks: %0d", total_checks);
        $display("  Passed: %0d", passed_checks);
        $display("  Failed: %0d", error_count);
        $display("========================================");
        if (error_count == 0) begin
            $display("TEST PASSED");
        end else begin
            $display("TEST FAILED");
        end
        $finish;
    end

    initial begin $dumpfile("dumpfile.fst"); $dumpvars(0); end
endmodule
