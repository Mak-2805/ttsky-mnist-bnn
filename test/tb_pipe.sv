`timescale 1ns/1ps

module tb_pipe;
    // DUT signals
    logic clk;
    logic reset_n;
    logic async_in_p;
    logic async_in_w;
    logic sync_out_p;
    logic sync_out_w;
    
    // Testbench variables
    int test_count;
    int error_count;
    logic [2:0] expected_pipe_p;  // Track 3-stage pipeline for async_in_p
    logic [2:0] expected_pipe_w;  // Track 3-stage pipeline for async_in_w
    
    // Clock generation - 10ns period (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Instantiate DUT
    pipe dut (
        .clk(clk),
        .reset_n(reset_n),
        .async_in_p(async_in_p),
        .async_in_w(async_in_w),
        .sync_out_p(sync_out_p),
        .sync_out_w(sync_out_w)
    );
    
    // Timeout watchdog
    initial begin
        #100000;
        $display("ERROR: Simulation timeout!");
        $fatal(1, "Test timed out after 100us");
    end
    
    // Task: Apply reset
    task reset_dut();
        begin
            reset_n = 0;
            async_in_p = 0;
            async_in_w = 0;
            repeat(5) @(posedge clk);
            reset_n = 1;
            @(posedge clk);
        end
    endtask
    
    // Task: Wait for N clock cycles
    task wait_cycles(int n);
        repeat(n) @(posedge clk);
    endtask
    
    // Task: Check output values
    task check_outputs(logic exp_p, logic exp_w, string test_name);
        begin
            test_count++;
            if (sync_out_p !== exp_p || sync_out_w !== exp_w) begin
                error_count++;
                $display("LOG: %0t : ERROR : tb_pipe : dut.sync_out_p : expected_value: %b actual_value: %b", 
                         $time, exp_p, sync_out_p);
                $display("LOG: %0t : ERROR : tb_pipe : dut.sync_out_w : expected_value: %b actual_value: %b", 
                         $time, exp_w, sync_out_w);
                $display("ERROR: Test '%s' failed!", test_name);
            end else begin
                $display("LOG: %0t : INFO : tb_pipe : %s : expected_value: p=%b,w=%b actual_value: p=%b,w=%b", 
                         $time, test_name, exp_p, exp_w, sync_out_p, sync_out_w);
            end
        end
    endtask
    
    // Main test sequence
    initial begin
        $display("TEST START");
        $display("========================================");
        $display("Comprehensive Testbench for pipe.sv");
        $display("3-Stage Synchronizer Verification");
        $display("========================================");
        
        test_count = 0;
        error_count = 0;
        
        // Initialize signals
        reset_n = 1;
        async_in_p = 0;
        async_in_w = 0;
        
        //===========================================
        // TEST 1: Reset Functionality
        //===========================================
        $display("\n[TEST 1] Reset Functionality Test");
        async_in_p = 1;
        async_in_w = 1;
        wait_cycles(5);  // Let values propagate
        
        reset_n = 0;  // Assert reset
        @(posedge clk);
        check_outputs(0, 0, "Reset - Immediate Clear");
        
        wait_cycles(3);
        check_outputs(0, 0, "Reset - Held Low");
        
        reset_n = 1;  // Release reset
        @(posedge clk);
        
        //===========================================
        // TEST 2: Basic Pipeline Delay (3 cycles)
        //===========================================
        $display("\n[TEST 2] Pipeline Delay Verification");
        reset_dut();
        
        async_in_p = 1;
        async_in_w = 0;
        
        @(posedge clk);  // Cycle 1
        check_outputs(0, 0, "Cycle 1 - No propagation yet");
        
        @(posedge clk);  // Cycle 2
        check_outputs(0, 0, "Cycle 2 - Still in pipeline");
        
        @(posedge clk);  // Cycle 3
        check_outputs(1, 0, "Cycle 3 - Output appears (3-cycle delay)");
        
        //===========================================
        // TEST 3: Channel P Independent Operation
        //===========================================
        $display("\n[TEST 3] Channel P (async_in_p) Independent Test");
        reset_dut();
        
        // Test 0 -> 1 transition
        async_in_p = 1;
        async_in_w = 0;
        wait_cycles(3);
        @(posedge clk);
        check_outputs(1, 0, "Channel P: 0->1 transition");
        
        // Test 1 -> 0 transition
        async_in_p = 0;
        wait_cycles(3);
        @(posedge clk);
        check_outputs(0, 0, "Channel P: 1->0 transition");
        
        // Hold at 1
        async_in_p = 1;
        wait_cycles(3);
        @(posedge clk);
        check_outputs(1, 0, "Channel P: Hold at 1");
        wait_cycles(5);
        check_outputs(1, 0, "Channel P: Stable at 1");
        
        //===========================================
        // TEST 4: Channel W Independent Operation
        //===========================================
        $display("\n[TEST 4] Channel W (async_in_w) Independent Test");
        reset_dut();
        
        // Test 0 -> 1 transition
        async_in_p = 0;
        async_in_w = 1;
        wait_cycles(3);
        @(posedge clk);
        check_outputs(0, 1, "Channel W: 0->1 transition");
        
        // Test 1 -> 0 transition
        async_in_w = 0;
        wait_cycles(3);
        @(posedge clk);
        check_outputs(0, 0, "Channel W: 1->0 transition");
        
        // Hold at 1
        async_in_w = 1;
        wait_cycles(3);
        @(posedge clk);
        check_outputs(0, 1, "Channel W: Hold at 1");
        wait_cycles(5);
        check_outputs(0, 1, "Channel W: Stable at 1");
        
        //===========================================
        // TEST 5: Simultaneous Channel Transitions
        //===========================================
        $display("\n[TEST 5] Simultaneous Channel Operations");
        reset_dut();
        
        // Both channels 0 -> 1
        async_in_p = 1;
        async_in_w = 1;
        wait_cycles(3);
        @(posedge clk);
        check_outputs(1, 1, "Both channels: 0->1");
        
        // Both channels 1 -> 0
        async_in_p = 0;
        async_in_w = 0;
        wait_cycles(3);
        @(posedge clk);
        check_outputs(0, 0, "Both channels: 1->0");
        
        // Opposite transitions: P goes high, W stays low
        async_in_p = 1;
        async_in_w = 0;
        wait_cycles(3);
        @(posedge clk);
        check_outputs(1, 0, "P=1, W=0");
        
        // Swap: P goes low, W goes high
        async_in_p = 0;
        async_in_w = 1;
        wait_cycles(3);
        @(posedge clk);
        check_outputs(0, 1, "P=0, W=1");
        
        //===========================================
        // TEST 6: Rapid Input Transitions
        //===========================================
        $display("\n[TEST 6] Rapid Input Transitions");
        reset_dut();
        
        // Toggle every clock cycle (faster than pipeline)
        async_in_p = 1;
        async_in_w = 0;
        @(posedge clk);
        async_in_p = 0;
        async_in_w = 1;
        @(posedge clk);
        async_in_p = 1;
        async_in_w = 0;
        @(posedge clk);
        
        // Wait for pipeline to settle
        wait_cycles(5);
        $display("LOG: %0t : INFO : tb_pipe : Rapid transitions completed : expected_value: settled actual_value: p=%b,w=%b", 
                 $time, sync_out_p, sync_out_w);
        
        //===========================================
        // TEST 7: Back-to-Back Transitions
        //===========================================
        $display("\n[TEST 7] Back-to-Back Transitions");
        reset_dut();
        
        // First transition
        async_in_p = 1;
        async_in_w = 1;
        wait_cycles(4);  // Allow to propagate
        check_outputs(1, 1, "First transition complete");
        
        // Immediate second transition
        async_in_p = 0;
        async_in_w = 0;
        wait_cycles(4);
        check_outputs(0, 0, "Second transition complete");
        
        // Third transition
        async_in_p = 1;
        async_in_w = 0;
        wait_cycles(4);
        check_outputs(1, 0, "Third transition complete");
        
        //===========================================
        // TEST 8: Reset During Operation
        //===========================================
        $display("\n[TEST 8] Reset During Active Operation");
        reset_dut();
        
        // Start transitions
        async_in_p = 1;
        async_in_w = 1;
        wait_cycles(2);  // Mid-pipeline
        
        // Assert reset while data in pipeline
        reset_n = 0;
        @(posedge clk);
        check_outputs(0, 0, "Reset clears pipeline immediately");
        
        reset_n = 1;
        wait_cycles(1);
        
        // Data should propagate normally after reset
        wait_cycles(3);
        @(posedge clk);
        check_outputs(1, 1, "Normal operation after reset");
        
        //===========================================
        // TEST 9: Glitch on Input (Single Cycle Pulse)
        //===========================================
        $display("\n[TEST 9] Single Cycle Glitch Test");
        reset_dut();
        
        async_in_p = 0;
        async_in_w = 0;
        wait_cycles(2);
        
        // Single cycle glitch on P
        async_in_p = 1;
        @(posedge clk);
        async_in_p = 0;
        
        wait_cycles(5);
        $display("LOG: %0t : INFO : tb_pipe : Single cycle glitch on P : expected_value: captured actual_value: p=%b", 
                 $time, sync_out_p);
        
        //===========================================
        // TEST 10: All Input Combinations
        //===========================================
        $display("\n[TEST 10] Exhaustive Input Combinations");
        reset_dut();
        
        // Test all 4 combinations: 00, 01, 10, 11
        for (int i = 0; i < 4; i++) begin
            async_in_p = i[0];
            async_in_w = i[1];
            wait_cycles(4);
            check_outputs(i[0], i[1], $sformatf("Input combo: P=%b W=%b", i[0], i[1]));
        end
        
        //===========================================
        // TEST 11: Long Stable Periods
        //===========================================
        $display("\n[TEST 11] Long Stable Period Test");
        reset_dut();
        
        async_in_p = 1;
        async_in_w = 0;
        wait_cycles(4);
        check_outputs(1, 0, "Initial stable state");
        
        // Hold for extended period
        wait_cycles(20);
        check_outputs(1, 0, "After 20 cycles - still stable");
        
        //===========================================
        // TEST 12: Reset Timing Variations
        //===========================================
        $display("\n[TEST 12] Reset Timing Variations");
        
        // Short reset pulse
        async_in_p = 1;
        async_in_w = 1;
        wait_cycles(5);
        reset_n = 0;
        @(posedge clk);
        reset_n = 1;
        @(posedge clk);
        check_outputs(0, 0, "Short reset pulse");
        
        // Long reset pulse
        reset_n = 0;
        wait_cycles(10);
        reset_n = 1;
        wait_cycles(1);
        check_outputs(0, 0, "Long reset pulse");
        
        //===========================================
        // TEST 13: Maximum Toggle Rate
        //===========================================
        $display("\n[TEST 13] Maximum Toggle Rate Test");
        reset_dut();
        
        // Toggle at every clock for 10 cycles
        for (int i = 0; i < 10; i++) begin
            async_in_p = ~async_in_p;
            async_in_w = ~async_in_w;
            @(posedge clk);
        end
        
        wait_cycles(5);
        $display("LOG: %0t : INFO : tb_pipe : Maximum toggle test : expected_value: completed actual_value: p=%b,w=%b", 
                 $time, sync_out_p, sync_out_w);
        
        //===========================================
        // Final Results
        //===========================================
        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Total tests run: %0d", test_count);
        $display("Errors found: %0d", error_count);
        
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
