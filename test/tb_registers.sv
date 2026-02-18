`timescale 1ns/1ps

module tb_registers;
    // DUT signals
    logic clk;
    logic reset_n;
    logic en_wr;
    logic d_in_p;
    logic d_in_w;
    logic [27:0][27:0] pixels;
    logic [2:0][2:0] weights [0:7];
    logic load_done;
    
    // Testbench variables
    int test_count;
    int error_count;
    
    // Expected data arrays
    logic expected_pixels [0:27][0:27];
    logic expected_weights [0:7][0:2][0:2];
    
    // Clock generation - 10ns period (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Instantiate DUT
    registers dut (
        .clk(clk),
        .reset_n(reset_n),
        .en_wr(en_wr),
        .d_in_p(d_in_p),
        .d_in_w(d_in_w),
        .pixels(pixels),
        .weights(weights),
        .load_done(load_done)
    );
    
    // Timeout watchdog
    initial begin
        #10000000; // 10ms timeout
        $display("ERROR: Simulation timeout!");
        $fatal(1, "Test timed out after 10ms");
    end
    
    // Task: Wait for N clock cycles
    task wait_cycles(int n);
        repeat(n) @(posedge clk);
    endtask
    
    // Task: Apply reset
    task apply_reset();
        begin
            en_wr = 0;
            d_in_p = 0;
            d_in_w = 0;
            wait_cycles(2);
            reset_n = 0;
            repeat(5) @(posedge clk);
            reset_n = 1;
            wait_cycles(5);
        end
    endtask
    
    // Task: Load BOTH pixels and weights simultaneously (as hardware expects!)
    task load_both_simultaneously(logic pixel_pattern, logic weight_pattern);
        begin
            int cycle_count;
            int pixel_idx, weight_idx;
            int pixel_row, pixel_col;
            int weight_level, weight_trit, weight_bitt;
            
            $display("  Loading pixels and weights SIMULTANEOUSLY");
            $display("    Cycles 1-72: Both pixel and weight data");
            $display("    Cycles 73-784: Remaining pixel data only");
            
            cycle_count = 0;
            pixel_idx = 0;
            weight_idx = 0;
            
            // Cycle through all 784 pixel positions
            for (pixel_row = 0; pixel_row < 28; pixel_row++) begin
                for (pixel_col = 0; pixel_col < 28; pixel_col++) begin
                    // Determine pixel data
                    d_in_p = pixel_pattern ? 1'b1 : ((pixel_row + pixel_col) % 2);
                    expected_pixels[pixel_row][pixel_col] = d_in_p;
                    
                    // Determine weight data (only for first 72 cycles)
                    if (cycle_count < 72) begin
                        weight_level = weight_idx / 9;  // 9 weights per level (3x3)
                        weight_trit = (weight_idx % 9) / 3;
                        weight_bitt = weight_idx % 3;
                        
                        d_in_w = weight_pattern ? 1'b0 : ((weight_level + weight_trit + weight_bitt) % 2);
                        expected_weights[weight_level][weight_trit][weight_bitt] = d_in_w;
                        weight_idx++;
                    end else begin
                        d_in_w = 0;  // Doesn't matter after 72 cycles, weights are done
                    end
                    
                    @(posedge clk);
                    cycle_count++;
                end
            end
            
            // Wait for pipeline to flush
            d_in_p = 0;
            d_in_w = 0;
            wait_cycles(10);
        end
    endtask
    
    // Task: Verify pixel array
    task verify_pixels(string test_name);
        begin
            int errors;
            errors = 0;
            test_count++;
            
            for (int row = 0; row < 28; row++) begin
                for (int col = 0; col < 28; col++) begin
                    if (pixels[row][col] !== expected_pixels[row][col]) begin
                        errors++;
                        if (errors <= 5) begin
                            $display("LOG: %0t : ERROR : tb_registers : dut.pixels[%0d][%0d] : expected_value: %b actual_value: %b",
                                     $time, row, col, expected_pixels[row][col], pixels[row][col]);
                        end
                    end
                end
            end
            
            if (errors > 0) begin
                error_count++;
                $display("ERROR: Test '%s' failed! %0d pixel mismatches found", test_name, errors);
            end else begin
                $display("LOG: %0t : INFO : tb_registers : %s : All 784 pixels verified correctly", $time, test_name);
            end
        end
    endtask
    
    // Task: Verify weight array
    task verify_weights(string test_name);
        begin
            int errors;
            errors = 0;
            test_count++;
            
            for (int level = 0; level < 8; level++) begin
                for (int row = 0; row < 3; row++) begin
                    for (int col = 0; col < 3; col++) begin
                        if (weights[level][row][col] !== expected_weights[level][row][col]) begin
                            errors++;
                            if (errors <= 5) begin
                                $display("LOG: %0t : ERROR : tb_registers : dut.weights[%0d][%0d][%0d] : expected_value: %b actual_value: %b",
                                         $time, level, row, col, expected_weights[level][row][col], weights[level][row][col]);
                            end
                        end
                    end
                end
            end
            
            if (errors > 0) begin
                error_count++;
                $display("ERROR: Test '%s' failed! %0d weight mismatches found", test_name, errors);
            end else begin
                $display("LOG: %0t : INFO : tb_registers : %s : All 72 weights verified correctly", $time, test_name);
            end
        end
    endtask
    
    // Task: Check load_done signal
    task check_load_done(logic expected, string test_name);
        begin
            test_count++;
            if (load_done !== expected) begin
                error_count++;
                $display("LOG: %0t : ERROR : tb_registers : dut.load_done : expected_value: %b actual_value: %b",
                         $time, expected, load_done);
                $display("ERROR: Test '%s' failed!", test_name);
            end else begin
                $display("LOG: %0t : INFO : tb_registers : %s : expected_value: %b actual_value: %b",
                         $time, test_name, expected, load_done);
            end
        end
    endtask
    
    // Main test sequence
    initial begin
        $display("TEST START");
        $display("========================================");
        $display("Comprehensive Testbench for registers.sv");
        $display("SIMULTANEOUS Pixel & Weight Loading");
        $display("========================================");
        
        test_count = 0;
        error_count = 0;
        
        // Initialize expected arrays
        for (int i = 0; i < 28; i++) begin
            for (int j = 0; j < 28; j++) begin
                expected_pixels[i][j] = 0;
            end
        end
        for (int i = 0; i < 8; i++) begin
            for (int j = 0; j < 3; j++) begin
                for (int k = 0; k < 3; k++) begin
                    expected_weights[i][j][k] = 0;
                end
            end
        end
        
        //===========================================
        // TEST 1: Reset Verification
        //===========================================
        $display("\n[TEST 1] Reset Functionality");
        apply_reset();
        check_load_done(0, "Reset: load_done should be low");
        
        //===========================================
        // TEST 2: Simultaneous Load - Alternating Patterns
        //===========================================
        $display("\n[TEST 2] Load Both Arrays Simultaneously - Alternating Patterns");
        en_wr = 1;
        load_both_simultaneously(0, 0); // Both alternating patterns
        verify_pixels("Simultaneous load - pixels");
        verify_weights("Simultaneous load - weights");
        check_load_done(1, "Both arrays loaded: load_done should be high");
        
        //===========================================
        // TEST 3: Reset and Reload
        //===========================================
        $display("\n[TEST 3] Clean Reset and State Verification");
        apply_reset();
        wait_cycles(10);
        
        // Re-initialize expected arrays
        for (int i = 0; i < 28; i++) begin
            for (int j = 0; j < 28; j++) begin
                expected_pixels[i][j] = 0;
            end
        end
        for (int i = 0; i < 8; i++) begin
            for (int j = 0; j < 3; j++) begin
                for (int k = 0; k < 3; k++) begin
                    expected_weights[i][j][k] = 0;
                end
            end
        end
        
        check_load_done(0, "After clean reset: load_done should be low");
        
        //===========================================
        // TEST 4: All 1s for Pixels, All 0s for Weights
        //===========================================
        $display("\n[TEST 4] Pixels=All 1s, Weights=All 0s");
        en_wr = 1;
        load_both_simultaneously(1, 1); // pixel_pattern=1 (all 1s), weight_pattern=1 (all 0s inverted)
        verify_pixels("All 1s pixels");
        verify_weights("All 0s weights");
        check_load_done(1, "Both arrays loaded");
        
        //===========================================
        // TEST 5: Enable Write Control
        //===========================================
        $display("\n[TEST 5] Enable Write Control");
        apply_reset();
        wait_cycles(5);
        
        // Try loading with en_wr = 0 (should not load)
        en_wr = 0;
        d_in_p = 1;
        d_in_w = 1;
        wait_cycles(100);
        
        test_count++;
        if (pixels[0][0] !== 0 || weights[0][0][0] !== 0) begin
            error_count++;
            $display("LOG: %0t : ERROR : tb_registers : Data loaded when en_wr=0!", $time);
        end else begin
            $display("LOG: %0t : INFO : tb_registers : en_wr control working : no data loaded when disabled", $time);
        end
        
        check_load_done(0, "en_wr disabled: load_done should be low");
        
        //===========================================
        // Final Results
        //===========================================
        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Total tests run: %0d", test_count);
        $display("Errors found: %0d", error_count);
        $display("Pixels verified: 784 (28x28)");
        $display("Weights verified: 72 (8x3x3)");
        $display("Loading method: SIMULTANEOUS (hardware-correct)");
        
        if (error_count == 0) begin
            $display("\n*** TEST PASSED ***");
            $display("All %0d tests completed successfully!", test_count);
        end else begin
            $display("\n*** TEST FAILED ***");
            $display("%0d out of %0d tests failed!", error_count, test_count);
            $error("Testbench completed with errors");
        end
        
        $display("========================================");
        $finish;
    end
    
    // Waveform dump
    initial begin
        $dumpfile("dumpfile.fst");
        $dumpvars(0);
    end

endmodule
