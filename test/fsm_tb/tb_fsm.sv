`timescale 1ns/1ps

module tb_fsm;

    // State type definition (must match DUT)
    typedef enum logic [2:0] {
        s_IDLE    = 3'b000,
        s_LOAD    = 3'b001,
        s_LAYER_1 = 3'b010,
        s_LAYER_2 = 3'b011,
        s_LAYER_3 = 3'b100
    } state_t;

    // Testbench signals
    logic clk;
    logic rst_n;
    logic mode;
    logic load_done;
    logic layer_1_done;
    logic layer_2_done;
    logic layer_3_done;
    state_t state;  // Now using enum type for better waveform readability

    // Test control variables
    int error_count = 0;
    int test_count = 0;

    // DUT instantiation
    fsm dut (
        .clk(clk),
        .rst_n(rst_n),
        .mode(mode),
        .load_done(load_done),
        .layer_1_done(layer_1_done),
        .layer_2_done(layer_2_done),
        .layer_3_done(layer_3_done),
        .state(state)
    );

    // Clock generation - 10ns period (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Helper task to check state
    task check_state(input state_t expected, input string state_name);
        test_count++;
        if (state !== expected) begin
            error_count++;
            $display("LOG: %0t : ERROR : tb_fsm : dut.state : expected_value: %s actual_value: %0d", 
                     $time, state_name, state);
        end else begin
            $display("LOG: %0t : INFO : tb_fsm : dut.state : expected_value: %s actual_value: %0d", 
                     $time, state_name, state);
        end
    endtask

    // Helper task to wait for clock cycles
    task wait_clocks(input int num_cycles);
        repeat(num_cycles) @(posedge clk);
    endtask

    // Main test procedure
    initial begin
        $display("TEST START");
        $display("==============================================");
        $display("FSM Testbench - Binary CNN State Machine");
        $display("==============================================");

        // Initialize all inputs
        rst_n = 1;
        mode = 0;
        load_done = 0;
        layer_1_done = 0;
        layer_2_done = 0;
        layer_3_done = 0;

        // Apply reset
        $display("\n[TEST 1] Testing Reset Functionality");
        @(posedge clk);
        rst_n = 0;
        wait_clocks(3);
        @(posedge clk);
        check_state(s_IDLE, "s_IDLE");
        rst_n = 1;
        wait_clocks(1);
        check_state(s_IDLE, "s_IDLE");

        // Test 2: Stay in IDLE when mode=0
        $display("\n[TEST 2] IDLE State Holding (mode=0)");
        mode = 0;
        wait_clocks(3);
        check_state(s_IDLE, "s_IDLE");

        // Test 3: Transition from IDLE to LOAD when mode=1
        $display("\n[TEST 3] IDLE -> LOAD Transition (mode=1)");
        mode = 1;
        wait_clocks(1);
        check_state(s_LOAD, "s_LOAD");
        mode = 0; // Deassert mode after transition

        // Test 4: Stay in LOAD until load_done=1
        $display("\n[TEST 4] LOAD State Holding (load_done=0)");
        load_done = 0;
        wait_clocks(3);
        check_state(s_LOAD, "s_LOAD");

        // Test 5: Transition from LOAD to LAYER_1
        $display("\n[TEST 5] LOAD -> LAYER_1 Transition");
        load_done = 1;
        wait_clocks(1);
        check_state(s_LAYER_1, "s_LAYER_1");
        load_done = 0; // Deassert after transition

        // Test 6: Stay in LAYER_1 until layer_1_done=1
        $display("\n[TEST 6] LAYER_1 State Holding (layer_1_done=0)");
        layer_1_done = 0;
        wait_clocks(3);
        check_state(s_LAYER_1, "s_LAYER_1");

        // Test 7: Transition from LAYER_1 to LAYER_2
        $display("\n[TEST 7] LAYER_1 -> LAYER_2 Transition");
        layer_1_done = 1;
        wait_clocks(1);
        check_state(s_LAYER_2, "s_LAYER_2");
        layer_1_done = 0;

        // Test 8: Stay in LAYER_2 until layer_2_done=1
        $display("\n[TEST 8] LAYER_2 State Holding (layer_2_done=0)");
        layer_2_done = 0;
        wait_clocks(3);
        check_state(s_LAYER_2, "s_LAYER_2");

        // Test 9: Transition from LAYER_2 to LAYER_3
        $display("\n[TEST 9] LAYER_2 -> LAYER_3 Transition");
        layer_2_done = 1;
        wait_clocks(1);
        check_state(s_LAYER_3, "s_LAYER_3");
        layer_2_done = 0;

        // Test 10: Stay in LAYER_3 until layer_3_done=1
        $display("\n[TEST 10] LAYER_3 State Holding (layer_3_done=0)");
        layer_3_done = 0;
        wait_clocks(3);
        check_state(s_LAYER_3, "s_LAYER_3");

        // Test 11: Transition from LAYER_3 back to IDLE
        $display("\n[TEST 11] LAYER_3 -> IDLE Transition");
        layer_3_done = 1;
        wait_clocks(1);
        check_state(s_IDLE, "s_IDLE");
        layer_3_done = 0;

        // Test 12: Complete cycle test - run through entire sequence again
        $display("\n[TEST 12] Complete State Sequence (2nd iteration)");
        
        // IDLE -> LOAD
        mode = 1;
        wait_clocks(1);
        check_state(s_LOAD, "s_LOAD");
        mode = 0;
        
        // LOAD -> LAYER_1
        load_done = 1;
        wait_clocks(1);
        check_state(s_LAYER_1, "s_LAYER_1");
        load_done = 0;
        
        // LAYER_1 -> LAYER_2
        layer_1_done = 1;
        wait_clocks(1);
        check_state(s_LAYER_2, "s_LAYER_2");
        layer_1_done = 0;
        
        // LAYER_2 -> LAYER_3
        layer_2_done = 1;
        wait_clocks(1);
        check_state(s_LAYER_3, "s_LAYER_3");
        layer_2_done = 0;
        
        // LAYER_3 -> IDLE
        layer_3_done = 1;
        wait_clocks(1);
        check_state(s_IDLE, "s_IDLE");
        layer_3_done = 0;

        // Test 13: Fast sequence with minimal delays
        $display("\n[TEST 13] Fast State Sequence");
        mode = 1;
        @(posedge clk);
        mode = 0;
        load_done = 1;
        @(posedge clk);
        load_done = 0;
        layer_1_done = 1;
        @(posedge clk);
        layer_1_done = 0;
        layer_2_done = 1;
        @(posedge clk);
        layer_2_done = 0;
        layer_3_done = 1;
        @(posedge clk);
        layer_3_done = 0;
        check_state(s_IDLE, "s_IDLE");

        // Additional clock cycles for waveform observation
        wait_clocks(5);

        // Final results
        $display("\n==============================================");
        $display("Test Summary:");
        $display("==============================================");
        $display("Total Tests: %0d", test_count);
        $display("Errors:      %0d", error_count);
        
        if (error_count == 0) begin
            $display("\n*** TEST PASSED ***");
            $display("All %0d state checks passed!", test_count);
        end else begin
            $display("\n*** TEST FAILED ***");
            $display("ERROR: %0d out of %0d checks failed!", error_count, test_count);
            $error("FSM verification failed with %0d errors", error_count);
        end
        
        $display("==============================================");
        $finish(0);
    end

    // Timeout watchdog
    initial begin
        #100000; // 100us timeout
        $display("\n==============================================");
        $display("ERROR: Simulation timeout!");
        $display("==============================================");
        $fatal(1, "Simulation exceeded timeout limit");
    end

    // Waveform dump
    initial begin
        $dumpfile("fsm.fst");
        $dumpvars(0);
    end

endmodule
