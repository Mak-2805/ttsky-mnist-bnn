`timescale 1ns/1ps

module tb_reset_pipe;
    // DUT signals
    logic clk;
    logic async_in_rst;
    logic sync_out_rst;
    
    // Testbench variables
    int test_count;
    int error_count;
    
    // Clock generation - 10ns period (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Instantiate DUT
    reset_pipe dut (
        .clk(clk),
        .async_in_rst(async_in_rst),
        .sync_out_rst(sync_out_rst)
    );
    
    // Timeout watchdog
    initial begin
        #100000;
        $display("ERROR: Simulation timeout!");
        $fatal(1, "Test timed out after 100us");
    end
    
    // Task: Wait for N clock cycles
    task wait_cycles(int n);
        repeat(n) @(posedge clk);
    endtask
    
    // Task: Check output value
    task check_output(logic expected, string test_name);
        begin
            test_count++;
            if (sync_out_rst !== expected) begin
                error_count++;
                $display("LOG: %0t : ERROR : tb_reset_pipe : dut.sync_out_rst : expected_value: %b actual_value: %b", 
                         $time, expected, sync_out_rst);
                $display("ERROR: Test '%s' failed!", test_name);
            end else begin
                $display("LOG: %0t : INFO : tb_reset_pipe : %s : expected_value: %b actual_value: %b", 
                         $time, test_name, expected, sync_out_rst);
            end
        end
    endtask
    
    // Main test sequence
    initial begin
        $display("TEST START");
        $display("========================================");
        $display("Comprehensive Testbench for reset_pipe.sv");
        $display("Reset Synchronizer Verification");
        $display("========================================");
        
        test_count = 0;
        error_count = 0;
        
        // Initialize signals - start with reset deasserted
        async_in_rst = 1;
        wait_cycles(2);
        
        //===========================================
        // TEST 1: Power-On State Verification
        //===========================================
        $display("\n[TEST 1] Power-On State Verification");
        check_output(0, "Power-on: sync_out_rst low at startup (no initial value)");
        
        //===========================================
        // TEST 2: Asynchronous Reset Assertion
        //===========================================
        $display("\n[TEST 2] Asynchronous Reset Assertion");
        async_in_rst = 0;  // Assert reset
        #1;  // Wait 1ns (not a full clock cycle)
        check_output(0, "Async assertion: Immediate response (asynchronous)");
        
        wait_cycles(3);
        check_output(0, "Async assertion: Reset held low");
        
        //===========================================
        // TEST 3: Synchronous Reset De-assertion (1-cycle delay)
        //===========================================
        $display("\n[TEST 3] Synchronous Reset De-assertion");
        @(posedge clk);  // Sync to clock edge first
        #1;  // Small delay after clock edge
        async_in_rst = 1;  // Release reset
        
        @(posedge clk);  // Cycle 1
        #1;
        check_output(0, "Sync de-assert: Cycle 1 - Intermediate stage");
        
        @(posedge clk);  // Cycle 2
        #1;
        check_output(1, "Sync de-assert: Cycle 2 - Reset released (1-cycle delay)");
        
        //===========================================
        // TEST 4: Multiple Reset Cycles
        //===========================================
        $display("\n[TEST 4] Multiple Reset Cycles");
        
        // First reset cycle
        async_in_rst = 0;
        #1;
        check_output(0, "Reset cycle 1: Assert");
        wait_cycles(2);
        
        async_in_rst = 1;
        wait_cycles(3);
        check_output(1, "Reset cycle 1: Release complete");
        
        // Second reset cycle
        async_in_rst = 0;
        #1;
        check_output(0, "Reset cycle 2: Assert");
        wait_cycles(2);
        
        async_in_rst = 1;
        wait_cycles(3);
        check_output(1, "Reset cycle 2: Release complete");
        
        // Third reset cycle
        async_in_rst = 0;
        #1;
        check_output(0, "Reset cycle 3: Assert");
        wait_cycles(2);
        
        async_in_rst = 1;
        wait_cycles(3);
        check_output(1, "Reset cycle 3: Release complete");
        
        //===========================================
        // TEST 5: Short Reset Pulse
        //===========================================
        $display("\n[TEST 5] Short Reset Pulse");
        async_in_rst = 0;
        #1;
        check_output(0, "Short pulse: Assert");
        
        @(posedge clk);  // One clock cycle
        async_in_rst = 1;  // Release quickly
        wait_cycles(3);
        check_output(1, "Short pulse: Successfully de-asserted");
        
        //===========================================
        // TEST 6: Long Reset Pulse
        //===========================================
        $display("\n[TEST 6] Long Reset Pulse");
        async_in_rst = 0;
        #1;
        check_output(0, "Long pulse: Assert");
        
        wait_cycles(10);  // Hold for 10 cycles
        check_output(0, "Long pulse: Still asserted after 10 cycles");
        
        async_in_rst = 1;
        wait_cycles(3);
        check_output(1, "Long pulse: Successfully de-asserted");
        
        //===========================================
        // TEST 7: Clock-Aligned Reset Assertion
        //===========================================
        $display("\n[TEST 7] Clock-Aligned Reset Assertion");
        wait_cycles(1);
        @(posedge clk);
        async_in_rst = 0;  // Assert at clock edge
        #1;
        check_output(0, "Clock-aligned: Reset asserts immediately");
        
        wait_cycles(2);
        async_in_rst = 1;
        wait_cycles(3);
        check_output(1, "Clock-aligned: De-assert complete");
        
        //===========================================
        // TEST 8: Mid-Clock Reset Assertion
        //===========================================
        $display("\n[TEST 8] Mid-Clock Reset Assertion");
        wait_cycles(1);
        #3;  // Assert in middle of clock period
        async_in_rst = 0;
        #1;
        check_output(0, "Mid-clock: Reset asserts immediately");
        
        wait_cycles(2);
        async_in_rst = 1;
        wait_cycles(3);
        check_output(1, "Mid-clock: De-assert complete");
        
        //===========================================
        // TEST 9: Reset During De-assertion
        //===========================================
        $display("\n[TEST 9] Reset During De-assertion");
        async_in_rst = 0;
        wait_cycles(2);
        
        async_in_rst = 1;  // Start de-assertion
        @(posedge clk);  // Wait 1 cycle (mid-pipeline)
        
        async_in_rst = 0;  // Re-assert during de-assertion
        #1;
        check_output(0, "Re-assert during de-assert: Immediately low");
        
        wait_cycles(2);
        async_in_rst = 1;
        wait_cycles(3);
        check_output(1, "Re-assert during de-assert: Finally released");
        
        //===========================================
        // TEST 10: Rapid Toggle During De-assertion
        //===========================================
        $display("\n[TEST 10] Rapid Toggle During De-assertion");
        async_in_rst = 0;
        wait_cycles(2);
        
        async_in_rst = 1;
        @(posedge clk);
        async_in_rst = 0;
        @(posedge clk);
        async_in_rst = 1;
        @(posedge clk);
        
        check_output(0, "Rapid toggle: Pipeline state");
        
        wait_cycles(2);
        check_output(1, "Rapid toggle: Eventually stabilizes high");
        
        //===========================================
        // TEST 11: Back-to-Back Reset Cycles
        //===========================================
        $display("\n[TEST 11] Back-to-Back Reset Cycles");
        
        async_in_rst = 0;
        wait_cycles(2);
        async_in_rst = 1;
        wait_cycles(3);
        check_output(1, "Back-to-back: First cycle complete");
        
        // Immediate second reset
        async_in_rst = 0;
        #1;
        check_output(0, "Back-to-back: Second reset immediate");
        wait_cycles(2);
        async_in_rst = 1;
        wait_cycles(3);
        check_output(1, "Back-to-back: Second cycle complete");
        
        //===========================================
        // TEST 12: Long Stable Active Period
        //===========================================
        $display("\n[TEST 12] Long Stable Active (High) Period");
        async_in_rst = 1;
        wait_cycles(5);
        check_output(1, "Stable high: Initial state");
        
        wait_cycles(20);
        check_output(1, "Stable high: After 20 cycles");
        
        //===========================================
        // TEST 13: Long Stable Reset Period
        //===========================================
        $display("\n[TEST 13] Long Stable Reset (Low) Period");
        async_in_rst = 0;
        wait_cycles(5);
        check_output(0, "Stable low: Initial state");
        
        wait_cycles(20);
        check_output(0, "Stable low: After 20 cycles");
        
        async_in_rst = 1;
        wait_cycles(3);
        check_output(1, "Stable low: Released successfully");
        
        //===========================================
        // TEST 14: De-assertion Timing Precision
        //===========================================
        $display("\n[TEST 14] De-assertion Timing Precision");
        async_in_rst = 0;
        wait_cycles(3);
        
        @(posedge clk);  // Sync to clock edge first
        #1;  // Small delay after clock edge
        async_in_rst = 1;  // Release reset
        
        // Check each clock cycle precisely (1-cycle delay)
        @(posedge clk);
        #1;
        if (sync_out_rst !== 0) begin
            error_count++;
            $display("LOG: %0t : ERROR : tb_reset_pipe : Timing check cycle 1 failed", $time);
        end else begin
            $display("LOG: %0t : INFO : tb_reset_pipe : Timing check cycle 1 : expected_value: 0 actual_value: %b", 
                     $time, sync_out_rst);
        end
        test_count++;
        
        @(posedge clk);
        #1;
        if (sync_out_rst !== 1) begin
            error_count++;
            $display("LOG: %0t : ERROR : tb_reset_pipe : Timing check cycle 2 failed", $time);
        end else begin
            $display("LOG: %0t : INFO : tb_reset_pipe : Timing check cycle 2 : expected_value: 1 actual_value: %b", 
                     $time, sync_out_rst);
        end
        test_count++;
        
        //===========================================
        // TEST 15: Maximum Stress Test (Rapid Toggling)
        //===========================================
        $display("\n[TEST 15] Maximum Stress Test");
        for (int i = 0; i < 5; i++) begin
            async_in_rst = 0;
            wait_cycles(1);
            async_in_rst = 1;
            wait_cycles(1);
        end
        
        wait_cycles(3);
        $display("LOG: %0t : INFO : tb_reset_pipe : Stress test complete : expected_value: stabilized actual_value: %b", 
                 $time, sync_out_rst);
        
        //===========================================
        // TEST 16: Final Stability Check
        //===========================================
        $display("\n[TEST 16] Final Stability Check");
        async_in_rst = 0;
        wait_cycles(5);
        check_output(0, "Final: Reset asserted");
        
        async_in_rst = 1;
        wait_cycles(5);
        check_output(1, "Final: Reset released and stable");
        
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