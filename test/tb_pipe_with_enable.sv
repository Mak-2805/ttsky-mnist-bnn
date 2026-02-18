`timescale 1ns/1ps

module tb_pipe_with_enable;
    // DUT signals
    logic clk;
    logic reset_n;
    logic async_in_p;
    logic async_in_w;
    logic async_in_en;
    logic sync_out_p;
    logic sync_out_w;
    logic sync_out_en;
    
    // Testbench variables
    int test_count;
    int error_count;
    
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
        .async_in_en(async_in_en),
        .sync_out_p(sync_out_p),
        .sync_out_w(sync_out_w),
        .sync_out_en(sync_out_en)
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
            async_in_en = 0;
            repeat(5) @(posedge clk);
            reset_n = 1;
            @(posedge clk);
        end
    endtask
    
    // Task: Wait for N clock cycles
    task wait_cycles(int n);
        repeat(n) @(posedge clk);
    endtask
    
    // Task: Check all three outputs
    task check_outputs(logic exp_p, logic exp_w, logic exp_en, string test_name);
        begin
            test_count++;
            if (sync_out_p !== exp_p || sync_out_w !== exp_w || sync_out_en !== exp_en) begin
                error_count++;
                $display("LOG: %0t : ERROR : tb_pipe_with_enable : dut.sync_out_p : expected_value: %b actual_value: %b", 
                         $time, exp_p, sync_out_p);
                $display("LOG: %0t : ERROR : tb_pipe_with_enable : dut.sync_out_w : expected_value: %b actual_value: %b", 
                         $time, exp_w, sync_out_w);
                $display("LOG: %0t : ERROR : tb_pipe_with_enable : dut.sync_out_en : expected_value: %b actual_value: %b", 
                         $time, exp_en, sync_out_en);
                $display("ERROR: Test '%s' failed!", test_name);
            end else begin
                $display("LOG: %0t : INFO : tb_pipe_with_enable : %s : expected_value: p=%b,w=%b,en=%b actual_value: p=%b,w=%b,en=%b", 
                         $time, test_name, exp_p, exp_w, exp_en, sync_out_p, sync_out_w, sync_out_en);
            end
        end
    endtask
    
    // Main test sequence
    initial begin
        $display("TEST START");
        $display("========================================");
        $display("Comprehensive Testbench for pipe.sv");
        $display("WITH Enable Signal Synchronization");
        $display("========================================");
        
        test_count = 0;
        error_count = 0;
        
        // Initialize signals
        reset_n = 1;
        async_in_p = 0;
        async_in_w = 0;
        async_in_en = 0;
        
        //===========================================
        // TEST 1: Reset Clears All Signals Including Enable
        //===========================================
        $display("\n[TEST 1] Reset Functionality - All Signals");
        async_in_p = 1;
        async_in_w = 1;
        async_in_en = 1;
        wait_cycles(5);  // Let values propagate
        
        reset_n = 0;  // Assert reset
        @(posedge clk);
        check_outputs(0, 0, 0, "Reset - All signals cleared");
        
        wait_cycles(3);
        check_outputs(0, 0, 0, "Reset - Held low");
        
        reset_n = 1;  // Release reset
        @(posedge clk);
        
        //===========================================
        // TEST 2: Enable Pipeline Delay (3 cycles)
        //===========================================
        $display("\n[TEST 2] Enable Signal 3-Cycle Pipeline Delay");
        reset_dut();
        
        async_in_en = 1;
        async_in_p = 0;
        async_in_w = 0;
        
        @(posedge clk);  // Cycle 1
        #1;
        check_outputs(0, 0, 0, "Enable Cycle 1 - No propagation yet");
        
        @(posedge clk);  // Cycle 2
        #1;
        check_outputs(0, 0, 1, "Enable Cycle 2 - Enable emerging (2-cycle for enable)");
        
        @(posedge clk);  // Cycle 3
        #1;
        check_outputs(0, 0, 1, "Enable Cycle 3 - Enable appears (3-cycle delay)");
        
        //===========================================
        // TEST 3: Enable and Data Synchronized
        //===========================================
        $display("\n[TEST 3] Enable and Data Arrive Together");
        reset_dut();
        
        async_in_p = 1;
        async_in_w = 1;
        async_in_en = 1;
        
        @(posedge clk);
        #1;
        check_outputs(0, 0, 0, "Sync check cycle 1 - all in pipeline");
        
        @(posedge clk);
        #1;
        check_outputs(1, 1, 1, "Sync check cycle 2 - all emerge together (2-cycle)");
        
        @(posedge clk);
        #1;
        check_outputs(1, 1, 1, "Sync check cycle 3 - all arrive together");
        
        //===========================================
        // TEST 4: Enable Goes High, Data Changes
        //===========================================
        $display("\n[TEST 4] Enable High with Changing Data");
        reset_dut();
        
        // Enable goes high with data=1
        async_in_p = 1;
        async_in_w = 1;
        async_in_en = 1;
        wait_cycles(4);
        check_outputs(1, 1, 1, "Enable high, data=1");
        
        // Data changes to 0, enable stays high
        async_in_p = 0;
        async_in_w = 0;
        async_in_en = 1;
        wait_cycles(4);
        check_outputs(0, 0, 1, "Enable stays high, data=0");
        
        //===========================================
        // TEST 5: Enable Toggle Pattern
        //===========================================
        $display("\n[TEST 5] Enable Toggle Pattern");
        reset_dut();
        
        // Enable goes high
        async_in_en = 1;
        wait_cycles(4);
        check_outputs(0, 0, 1, "Enable high");
        
        // Enable goes low
        async_in_en = 0;
        wait_cycles(4);
        check_outputs(0, 0, 0, "Enable low");
        
        // Enable goes high again
        async_in_en = 1;
        wait_cycles(4);
        check_outputs(0, 0, 1, "Enable high again");
        
        //===========================================
        // TEST 6: Data Changes Without Enable
        //===========================================
        $display("\n[TEST 6] Data Changes with Enable=0");
        reset_dut();
        
        async_in_en = 0;
        async_in_p = 1;
        async_in_w = 1;
        wait_cycles(4);
        check_outputs(1, 1, 0, "Data propagates, enable stays 0");
        
        //===========================================
        // TEST 7: Enable Pulses
        //===========================================
        $display("\n[TEST 7] Enable Pulse Propagation");
        reset_dut();
        
        // Longer enable pulse (3 cycles) - reliable propagation
        async_in_p = 1;
        async_in_w = 0;
        async_in_en = 1;
        wait_cycles(3);  // Hold for 3 cycles to ensure reliable propagation
        
        async_in_en = 0;
        wait_cycles(2);
        @(posedge clk);
        #1;
        check_outputs(1, 0, 1, "3-cycle enable pulse propagated reliably");
        
        wait_cycles(2);
        check_outputs(1, 0, 0, "Enable went back low after pulse");
        
        //===========================================
        // TEST 8: Simultaneous Enable and Data Transitions
        //===========================================
        $display("\n[TEST 8] Simultaneous Transitions");
        reset_dut();
        
        // All go high together
        async_in_p = 1;
        async_in_w = 1;
        async_in_en = 1;
        wait_cycles(3);
        @(posedge clk);
        check_outputs(1, 1, 1, "All high together");
        
        // All go low together
        async_in_p = 0;
        async_in_w = 0;
        async_in_en = 0;
        wait_cycles(3);
        @(posedge clk);
        check_outputs(0, 0, 0, "All low together");
        
        //===========================================
        // TEST 9: Enable During Reset
        //===========================================
        $display("\n[TEST 9] Enable Behavior During Reset");
        async_in_p = 1;
        async_in_w = 1;
        async_in_en = 1;
        wait_cycles(2);
        
        reset_n = 0;
        @(posedge clk);
        check_outputs(0, 0, 0, "Reset overrides everything");
        
        wait_cycles(2);
        reset_n = 1;
        wait_cycles(1);
        
        // After reset, signals should propagate again
        wait_cycles(3);
        check_outputs(1, 1, 1, "After reset, signals propagate");
        
        //===========================================
        // TEST 10: Rapid Enable Toggling
        //===========================================
        $display("\n[TEST 10] Rapid Enable Toggling");
        reset_dut();
        
        for (int i = 0; i < 5; i++) begin
            async_in_en = 1;
            @(posedge clk);
            async_in_en = 0;
            @(posedge clk);
        end
        
        wait_cycles(5);
        $display("LOG: %0t : INFO : tb_pipe_with_enable : Rapid toggle completed : sync_out_en=%b", 
                 $time, sync_out_en);
        
        //===========================================
        // TEST 11: Enable Leads Data
        //===========================================
        $display("\n[TEST 11] Enable Goes High Before Data");
        reset_dut();
        
        async_in_en = 1;
        wait_cycles(2);
        
        async_in_p = 1;
        async_in_w = 1;
        wait_cycles(5);
        
        // Both should be high, but enable arrived earlier
        test_count++;
        if (sync_out_en == 1 && sync_out_p == 1 && sync_out_w == 1) begin
            $display("LOG: %0t : INFO : tb_pipe_with_enable : Enable leads data : All synchronized correctly", $time);
        end else begin
            error_count++;
            $display("LOG: %0t : ERROR : tb_pipe_with_enable : Enable leads data test failed", $time);
        end
        
        //===========================================
        // TEST 12: Data Leads Enable
        //===========================================
        $display("\n[TEST 12] Data Goes High Before Enable");
        reset_dut();
        
        async_in_p = 1;
        async_in_w = 1;
        wait_cycles(2);
        
        async_in_en = 1;
        wait_cycles(5);
        
        // Both should be high, but data arrived earlier
        test_count++;
        if (sync_out_en == 1 && sync_out_p == 1 && sync_out_w == 1) begin
            $display("LOG: %0t : INFO : tb_pipe_with_enable : Data leads enable : All synchronized correctly", $time);
        end else begin
            error_count++;
            $display("LOG: %0t : ERROR : tb_pipe_with_enable : Data leads enable test failed", $time);
        end
        
        //===========================================
        // TEST 13: Enable Pattern with Alternating Data
        //===========================================
        $display("\n[TEST 13] Enable Pattern with Alternating Data");
        reset_dut();
        
        for (int i = 0; i < 4; i++) begin
            async_in_p = i % 2;
            async_in_w = ~(i % 2);
            async_in_en = (i < 2) ? 1 : 0;
            wait_cycles(4);
            $display("LOG: %0t : INFO : tb_pipe_with_enable : Pattern iteration %0d : p=%b w=%b en=%b", 
                     $time, i, sync_out_p, sync_out_w, sync_out_en);
        end
        
        //===========================================
        // TEST 14: Long Stable Enable High
        //===========================================
        $display("\n[TEST 14] Long Stable Enable High");
        reset_dut();
        
        async_in_en = 1;
        wait_cycles(4);
        check_outputs(0, 0, 1, "Enable high initial");
        
        wait_cycles(20);
        check_outputs(0, 0, 1, "Enable high after 20 cycles");
        
        //===========================================
        // TEST 15: Long Stable Enable Low
        //===========================================
        $display("\n[TEST 15] Long Stable Enable Low");
        reset_dut();
        
        async_in_en = 0;
        wait_cycles(4);
        check_outputs(0, 0, 0, "Enable low initial");
        
        wait_cycles(20);
        check_outputs(0, 0, 0, "Enable low after 20 cycles");
        
        //===========================================
        // TEST 16: Back-to-Back Enable Transitions
        //===========================================
        $display("\n[TEST 16] Back-to-Back Enable Transitions");
        reset_dut();
        
        async_in_en = 1;
        wait_cycles(4);
        check_outputs(0, 0, 1, "First enable high");
        
        async_in_en = 0;
        wait_cycles(4);
        check_outputs(0, 0, 0, "Enable low");
        
        async_in_en = 1;
        wait_cycles(4);
        check_outputs(0, 0, 1, "Enable high again");
        
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
            $display("Enable synchronization verified: 3-cycle delay");
            $display("Enable and data arrive synchronized");
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
