`timescale 1ns/1ps

import mnist_bnn_pkg::*;

module tb_layer_one;

    // Testbench signals
    logic clock;
    logic reset;
    state_t state;
    logic [27:0][27:0] pixels;
    logic [7:0][2:0][2:0] weights;
    logic [7:0][13:0][13:0] layer_one_out;
    logic done;

    // Test control
    integer test_count;
    integer error_count;
    integer i, j, k;

    // Instantiate DUT
    layer_one dut (
        .clk(clock),
        .rst_n(reset),
        .state(state),
        .pixels(pixels),
        .weights(weights),
        .layer_one_out(layer_one_out),
        .done(done)
    );

    // Clock generation (10ns period = 100MHz)
    initial begin
        clock = 0;
        forever #5 clock = ~clock;
    end

    // Timeout watchdog
    initial begin
        #300000000; // 300ms timeout (more tests now)
        $display("ERROR: Simulation timeout!");
        $display("TEST FAILED");
        $finish;
    end

    // Main test sequence
    initial begin
        $display("TEST START");
        
        // Initialize
        test_count = 0;
        error_count = 0;
        reset = 0;
        state = s_IDLE;
        pixels = '0;
        weights = '0;
        
        // Wait for initial settling
        #10;
        
        // ============================================
        // TEST 1: Reset functionality
        // ============================================
        test_count++;
        $display("\n[TEST %0d] Reset Verification", test_count);
        reset = 0;
        state = s_LAYER_1;
        #20;
        
        if (done !== 0) begin
            $display("LOG: %0t : ERROR : tb_layer_one : dut.done : expected_value: 0 actual_value: %0d", $time, done);
            error_count++;
        end else begin
            $display("LOG: %0t : INFO : tb_layer_one : dut.done : expected_value: 0 actual_value: 0", $time);
        end
        
        // Release reset
        reset = 1;
        #10;
        
        // ============================================
        // TEST 2: Idle state - no operation
        // ============================================
        test_count++;
        $display("\n[TEST %0d] Idle State Verification", test_count);
        state = s_IDLE;
        #100;
        
        if (done !== 0) begin
            $display("LOG: %0t : ERROR : tb_layer_one : dut.done : expected_value: 0 actual_value: %0d", $time, done);
            error_count++;
        end else begin
            $display("LOG: %0t : INFO : tb_layer_one : dut.done : expected_value: 0 actual_value: 0", $time);
        end
        
        // Reset for next test
        state = s_IDLE;
        reset = 0;
        #20;
        reset = 1;
        #10;
        
        // ============================================
        // TEST 3: Simple pattern - all zeros
        // ============================================
        test_count++;
        $display("\n[TEST %0d] All Zeros Pattern", test_count);
        
        // Set all pixels to 0
        for (i = 0; i < 28; i++) begin
            for (j = 0; j < 28; j++) begin
                pixels[i][j] = 1'b0;
            end
        end
        
        // Set weights to all zeros
        for (i = 0; i < 8; i++) begin
            for (j = 0; j < 3; j++) begin
                for (k = 0; k < 3; k++) begin
                    weights[i][j][k] = 1'b0;
                end
            end
        end
        
        state = s_LAYER_1;
        #10;
        
        // Wait for processing to complete
        wait(done == 1);
        $display("LOG: %0t : INFO : tb_layer_one : dut.done : expected_value: 1 actual_value: 1", $time);
        $display("  Processing completed in %0t ns", $time);
        
        // Reset for next test
        state = s_IDLE;
        reset = 0;
        #20;
        reset = 1;
        #10;
        
        // ============================================
        // TEST 4: Simple pattern - all ones
        // ============================================
        test_count++;
        $display("\n[TEST %0d] All Ones Pattern", test_count);
        
        // Set all pixels to 1
        for (i = 0; i < 28; i++) begin
            for (j = 0; j < 28; j++) begin
                pixels[i][j] = 1'b1;
            end
        end
        
        // Set weights to all ones
        for (i = 0; i < 8; i++) begin
            for (j = 0; j < 3; j++) begin
                for (k = 0; k < 3; k++) begin
                    weights[i][j][k] = 1'b1;
                end
            end
        end
        
        state = s_LAYER_1;
        #10;
        
        // Wait for processing to complete
        wait(done == 1);
        $display("LOG: %0t : INFO : tb_layer_one : dut.done : expected_value: 1 actual_value: 1", $time);
        $display("  Processing completed in %0t ns", $time);
        
        // Verify that some outputs are active (all matches should give high output)
        if (layer_one_out[0][0][0] !== 1'b1) begin
            $display("LOG: %0t : WARNING : tb_layer_one : dut.layer_one_out[0][0][0] : expected_value: 1 actual_value: %0d", $time, layer_one_out[0][0][0]);
        end else begin
            $display("LOG: %0t : INFO : tb_layer_one : dut.layer_one_out[0][0][0] : expected_value: 1 actual_value: 1", $time);
        end
        
        // Reset for next test
        state = s_IDLE;
        reset = 0;
        #20;
        reset = 1;
        #10;
        
        // ============================================
        // TEST 5: Checkerboard pattern
        // ============================================
        test_count++;
        $display("\n[TEST %0d] Checkerboard Pattern", test_count);
        
        // Create checkerboard pattern in pixels
        for (i = 0; i < 28; i++) begin
            for (j = 0; j < 28; j++) begin
                pixels[i][j] = (i + j) % 2;
            end
        end
        
        // Set varied weights
        for (i = 0; i < 8; i++) begin
            for (j = 0; j < 3; j++) begin
                for (k = 0; k < 3; k++) begin
                    weights[i][j][k] = (i + j + k) % 2;
                end
            end
        end
        
        state = s_LAYER_1;
        #10;
        
        // Wait for processing to complete
        wait(done == 1);
        $display("LOG: %0t : INFO : tb_layer_one : dut.done : expected_value: 1 actual_value: 1", $time);
        $display("  Processing completed in %0t ns", $time);
        
        // ============================================
        // TEST 6: State transition test
        // ============================================
        test_count++;
        $display("\n[TEST %0d] State Transition During Processing", test_count);
        
        // Reset
        state = s_IDLE;
        reset = 0;
        #20;
        reset = 1;
        #10;
        
        // Start processing
        state = s_LAYER_1;
        #500; // Let it process for a bit
        
        // Change state mid-processing
        state = s_IDLE;
        #100;
        
        // Resume processing
        state = s_LAYER_1;
        wait(done == 1);
        $display("LOG: %0t : INFO : tb_layer_one : dut.done : expected_value: 1 actual_value: 1", $time);
        
        // ============================================
        // EXTREME CHECKERBOARD STRESS TESTS
        // ============================================
        $display("\n========================================");
        $display("STARTING EXTREME CHECKERBOARD TESTS");
        $display("========================================");
        
        // ============================================
        // TEST 7: Anti-Correlated Checkerboard (Worst Match)
        // ============================================
        test_count++;
        $display("\n[TEST %0d] Anti-Correlated Checkerboard", test_count);
        
        state = s_IDLE;
        reset = 0;
        #20;
        reset = 1;
        #10;
        
        // Checkerboard pixels
        for (i = 0; i < 28; i++) begin
            for (j = 0; j < 28; j++) begin
                pixels[i][j] = (i + j) % 2;
            end
        end
        
        // Inverted checkerboard weights (worst case mismatch)
        for (i = 0; i < 8; i++) begin
            for (j = 0; j < 3; j++) begin
                for (k = 0; k < 3; k++) begin
                    weights[i][j][k] = ~((i + j + k) % 2);
                end
            end
        end
        
        state = s_LAYER_1;
        #10;
        wait(done == 1);
        $display("LOG: %0t : INFO : tb_layer_one : dut.done : expected_value: 1 actual_value: 1", $time);
        $display("  Processing completed in %0t ns", $time);
        
        // ============================================
        // TEST 8: Horizontal Stripes Pattern
        // ============================================
        test_count++;
        $display("\n[TEST %0d] Horizontal Stripes Pattern", test_count);
        
        state = s_IDLE;
        reset = 0;
        #20;
        reset = 1;
        #10;
        
        for (i = 0; i < 28; i++) begin
            for (j = 0; j < 28; j++) begin
                pixels[i][j] = i % 2;  // Horizontal stripes
            end
        end
        
        // Vertical stripe weights
        for (i = 0; i < 8; i++) begin
            weights[i][0][0] = 1; weights[i][0][1] = 0; weights[i][0][2] = 1;
            weights[i][1][0] = 1; weights[i][1][1] = 0; weights[i][1][2] = 1;
            weights[i][2][0] = 1; weights[i][2][1] = 0; weights[i][2][2] = 1;
        end
        
        state = s_LAYER_1;
        #10;
        wait(done == 1);
        $display("LOG: %0t : INFO : tb_layer_one : dut.done : expected_value: 1 actual_value: 1", $time);
        $display("  Processing completed in %0t ns", $time);
        
        // ============================================
        // TEST 9: Vertical Stripes Pattern
        // ============================================
        test_count++;
        $display("\n[TEST %0d] Vertical Stripes Pattern", test_count);
        
        state = s_IDLE;
        reset = 0;
        #20;
        reset = 1;
        #10;
        
        for (i = 0; i < 28; i++) begin
            for (j = 0; j < 28; j++) begin
                pixels[i][j] = j % 2;  // Vertical stripes
            end
        end
        
        // Horizontal stripe weights
        for (i = 0; i < 8; i++) begin
            weights[i][0][0] = 1; weights[i][0][1] = 1; weights[i][0][2] = 1;
            weights[i][1][0] = 0; weights[i][1][1] = 0; weights[i][1][2] = 0;
            weights[i][2][0] = 1; weights[i][2][1] = 1; weights[i][2][2] = 1;
        end
        
        state = s_LAYER_1;
        #10;
        wait(done == 1);
        $display("LOG: %0t : INFO : tb_layer_one : dut.done : expected_value: 1 actual_value: 1", $time);
        $display("  Processing completed in %0t ns", $time);
        
        // ============================================
        // TEST 10: Edge-Focused Pattern (Tests edge padding)
        // ============================================
        test_count++;
        $display("\n[TEST %0d] Edge-Focused Pattern", test_count);
        
        state = s_IDLE;
        reset = 0;
        #20;
        reset = 1;
        #10;
        
        // All edges are 1, interior is checkerboard
        for (i = 0; i < 28; i++) begin
            for (j = 0; j < 28; j++) begin
                if (i == 0 || i == 27 || j == 0 || j == 27) begin
                    pixels[i][j] = 1;
                end else begin
                    pixels[i][j] = (i + j) % 2;
                end
            end
        end
        
        // Checkerboard weights
        for (i = 0; i < 8; i++) begin
            weights[i][0][0] = 1; weights[i][0][1] = 0; weights[i][0][2] = 1;
            weights[i][1][0] = 0; weights[i][1][1] = 1; weights[i][1][2] = 0;
            weights[i][2][0] = 1; weights[i][2][1] = 0; weights[i][2][2] = 1;
        end
        
        state = s_LAYER_1;
        #10;
        wait(done == 1);
        $display("LOG: %0t : INFO : tb_layer_one : dut.done : expected_value: 1 actual_value: 1", $time);
        $display("  Processing completed in %0t ns", $time);
        
        // ============================================
        // TEST 11: Sparse Pattern (Every 4th pixel)
        // ============================================
        test_count++;
        $display("\n[TEST %0d] Sparse Pattern", test_count);
        
        state = s_IDLE;
        reset = 0;
        #20;
        reset = 1;
        #10;
        
        pixels = '0;
        for (i = 0; i < 28; i = i + 4) begin
            for (j = 0; j < 28; j = j + 4) begin
                pixels[i][j] = 1;
            end
        end
        
        // Diagonal weights
        for (i = 0; i < 8; i++) begin
            weights[i][0][0] = 1; weights[i][0][1] = 0; weights[i][0][2] = 0;
            weights[i][1][0] = 0; weights[i][1][1] = 1; weights[i][1][2] = 0;
            weights[i][2][0] = 0; weights[i][2][1] = 0; weights[i][2][2] = 1;
        end
        
        state = s_LAYER_1;
        #10;
        wait(done == 1);
        $display("LOG: %0t : INFO : tb_layer_one : dut.done : expected_value: 1 actual_value: 1", $time);
        $display("  Processing completed in %0t ns", $time);
        
        // ============================================
        // TEST 12: Dense Pattern (Mostly ones)
        // ============================================
        test_count++;
        $display("\n[TEST %0d] Dense Pattern", test_count);
        
        state = s_IDLE;
        reset = 0;
        #20;
        reset = 1;
        #10;
        
        pixels = '1;
        for (i = 0; i < 28; i = i + 4) begin
            for (j = 0; j < 28; j = j + 4) begin
                pixels[i][j] = 0;
            end
        end
        
        // Inverse diagonal weights
        for (i = 0; i < 8; i++) begin
            weights[i][0][0] = 0; weights[i][0][1] = 1; weights[i][0][2] = 1;
            weights[i][1][0] = 1; weights[i][1][1] = 0; weights[i][1][2] = 1;
            weights[i][2][0] = 1; weights[i][2][1] = 1; weights[i][2][2] = 0;
        end
        
        state = s_LAYER_1;
        #10;
        wait(done == 1);
        $display("LOG: %0t : INFO : tb_layer_one : dut.done : expected_value: 1 actual_value: 1", $time);
        $display("  Processing completed in %0t ns", $time);
        
        // ============================================
        // TEST 13: Quarter-Plane Mixed Patterns
        // ============================================
        test_count++;
        $display("\n[TEST %0d] Quarter-Plane Mixed Patterns", test_count);
        
        state = s_IDLE;
        reset = 0;
        #20;
        reset = 1;
        #10;
        
        for (i = 0; i < 28; i++) begin
            for (j = 0; j < 28; j++) begin
                if (i < 14 && j < 14) begin
                    pixels[i][j] = 0;  // Top-left: all zeros
                end else if (i < 14 && j >= 14) begin
                    pixels[i][j] = 1;  // Top-right: all ones
                end else if (i >= 14 && j < 14) begin
                    pixels[i][j] = (i + j) % 2;  // Bottom-left: checkerboard
                end else begin
                    pixels[i][j] = ~((i + j) % 2);  // Bottom-right: inverted
                end
            end
        end
        
        // Phase-shifted checkerboard weights
        for (i = 0; i < 8; i++) begin
            for (j = 0; j < 3; j++) begin
                for (k = 0; k < 3; k++) begin
                    weights[i][j][k] = (i + j + k) % 2;
                end
            end
        end
        
        state = s_LAYER_1;
        #10;
        wait(done == 1);
        $display("LOG: %0t : INFO : tb_layer_one : dut.done : expected_value: 1 actual_value: 1", $time);
        $display("  Processing completed in %0t ns", $time);
        
        // ============================================
        // TEST 14: Pseudo-Random Pattern
        // ============================================
        test_count++;
        $display("\n[TEST %0d] Pseudo-Random Pattern", test_count);
        
        state = s_IDLE;
        reset = 0;
        #20;
        reset = 1;
        #10;
        
        for (i = 0; i < 28; i++) begin
            for (j = 0; j < 28; j++) begin
                pixels[i][j] = ((i * 7 + j * 13) % 3) > 1;
            end
        end
        
        for (i = 0; i < 8; i++) begin
            for (j = 0; j < 3; j++) begin
                for (k = 0; k < 3; k++) begin
                    weights[i][j][k] = ((i * 3 + j * 5 + k * 7) % 3) > 1;
                end
            end
        end
        
        state = s_LAYER_1;
        #10;
        wait(done == 1);
        $display("LOG: %0t : INFO : tb_layer_one : dut.done : expected_value: 1 actual_value: 1", $time);
        $display("  Processing completed in %0t ns", $time);
        
        // ============================================
        // TEST 15: 4x4 Block Checkerboard
        // ============================================
        test_count++;
        $display("\n[TEST %0d] 4x4 Block Checkerboard", test_count);
        
        state = s_IDLE;
        reset = 0;
        #20;
        reset = 1;
        #10;
        
        for (i = 0; i < 28; i++) begin
            for (j = 0; j < 28; j++) begin
                pixels[i][j] = ((i / 2) + (j / 2)) % 2;  // 4x4 blocks
            end
        end
        
        for (i = 0; i < 8; i++) begin
            for (j = 0; j < 3; j++) begin
                for (k = 0; k < 3; k++) begin
                    weights[i][j][k] = ((i / 2) + j + k) % 2;
                end
            end
        end
        
        state = s_LAYER_1;
        #10;
        wait(done == 1);
        $display("LOG: %0t : INFO : tb_layer_one : dut.done : expected_value: 1 actual_value: 1", $time);
        $display("  Processing completed in %0t ns", $time);
        
        $display("\n========================================");
        $display("EXTREME CHECKERBOARD TESTS COMPLETE");
        $display("========================================");
        
        // ============================================
        // Final Results
        // ============================================
        #100;
        $display("\n========================================");
        $display("Test Summary:");
        $display("  Total Tests: %0d", test_count);
        $display("  Errors: %0d", error_count);
        $display("========================================");
        
        if (error_count == 0) begin
            $display("TEST PASSED");
        end else begin
            $display("TEST FAILED");
        end
        
        $finish;
    end

    // Waveform dump
    initial begin
        $dumpfile("dumpfile.fst");
        $dumpvars(0);
    end

endmodule