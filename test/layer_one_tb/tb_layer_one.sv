`timescale 1ns/1ps

module tb_layer_one;

    // ============================================================================
    // Test Parameters - Modify these to test different scenarios
    // ============================================================================
    
    // Test case 1: Simple checkerboard pattern
    parameter logic [27:0][27:0] TEST_PIXELS_1 = {
        28'b0101010101010101010101010101,
        28'b1010101010101010101010101010,
        28'b0101010101010101010101010101,
        28'b1010101010101010101010101010,
        28'b0101010101010101010101010101,
        28'b1010101010101010101010101010,
        28'b0101010101010101010101010101,
        28'b1010101010101010101010101010,
        28'b0101010101010101010101010101,
        28'b1010101010101010101010101010,
        28'b0101010101010101010101010101,
        28'b1010101010101010101010101010,
        28'b0101010101010101010101010101,
        28'b1010101010101010101010101010,
        28'b0101010101010101010101010101,
        28'b1010101010101010101010101010,
        28'b0101010101010101010101010101,
        28'b1010101010101010101010101010,
        28'b0101010101010101010101010101,
        28'b1010101010101010101010101010,
        28'b0101010101010101010101010101,
        28'b1010101010101010101010101010,
        28'b0101010101010101010101010101,
        28'b1010101010101010101010101010,
        28'b0101010101010101010101010101,
        28'b1010101010101010101010101010,
        28'b0101010101010101010101010101,
        28'b1010101010101010101010101010
    };
    
    // Test case 2: All zeros
    parameter logic [27:0][27:0] TEST_PIXELS_2 = '{default: 28'b0};
    
    // Test case 3: All ones
    parameter logic [27:0][27:0] TEST_PIXELS_3 = '{default: 28'hFFFFFFF};
    
    // Test case 4: Real MNIST digit from Python model (digit "2", index 2)
    parameter logic [27:0][27:0] TEST_PIXELS_MNIST = {
        28'b0000000000000000000000000000,  // row 0
        28'b0000000000000000000000000000,  // row 1
        28'b0000000000000000000000000000,  // row 2
        28'b0000000000000000000000000000,  // row 3
        28'b0000000000001111000000000000,  // row 4
        28'b0000000011111111111000000000,  // row 5
        28'b0000000011111111111100000000,  // row 6
        28'b0000000000000000001110000000,  // row 7
        28'b0000000000000000000110000000,  // row 8
        28'b0000000000000000001100000000,  // row 9
        28'b0000000000000111100000000000,  // row 10
        28'b0000000000000001100000000000,  // row 11
        28'b0000000111111110000000000000,  // row 12
        28'b0000000111111100000000000000,  // row 13
        28'b0000000111111000000000000000,  // row 14
        28'b0000000000001110000000000000,  // row 15
        28'b0000000000000110000000000000,  // row 16
        28'b0000000000000011000000000000,  // row 17
        28'b0000000000000011100000000000,  // row 18
        28'b0000000000000011000000000000,  // row 19
        28'b0000000000000011000000000000,  // row 20
        28'b0000001111100011110000000000,  // row 21
        28'b0000001111111111110000000000,  // row 22
        28'b0000000111111111000000000000,  // row 23
        28'b0000000000000000000000000000,  // row 24
        28'b0000000000000000000000000000,  // row 25
        28'b0000000000000000000000000000,  // row 26
        28'b0000000000000000000000000000   // row 27
    };
    
    // Test weights - 8 different 3x3 binary kernels
    // Format: [row][col][weight_num]
    parameter logic [2:0][2:0][7:0] TEST_WEIGHTS = '{
        '{8'b10110001, 8'b01011110, 8'b10110001},  // row 0
        '{8'b11010101, 8'b00101010, 8'b11010101},  // row 1
        '{8'b10110001, 8'b01011110, 8'b10110001}   // row 2
    };
    
    // Weights from Python model for MNIST test
    // Each channel's 9 bits map to 3x3 kernel: [TL TM TR ML MM MR BL BM BR]
    // channel 0: [0 0 0 1 1 0 1 1 0]
    // channel 1: [1 0 0 1 0 1 1 1 1]
    // channel 2: [0 0 0 1 1 1 0 1 1]
    // channel 3: [1 1 1 1 1 0 0 0 0]
    // channel 4: [0 1 1 0 0 0 0 0 0]
    // channel 5: [1 1 1 0 0 0 0 0 0]
    // channel 6: [1 1 1 0 0 0 0 0 0]
    // channel 7: [1 0 1 1 1 1 0 0 0]
    // Packed as [row][col][ch7 ch6 ch5 ch4 ch3 ch2 ch1 ch0]
    parameter logic [2:0][2:0][7:0] TEST_WEIGHTS_MNIST = '{
        '{8'b11101010, 8'b01111000, 8'b11111000},  // row 0: TL(bit0), TM(bit1), TR(bit2)
        '{8'b10001111, 8'b10001101, 8'b10000110},  // row 1: ML(bit3), MM(bit4), MR(bit5)
        '{8'b00000011, 8'b00000111, 8'b00000110}   // row 2: BL(bit6), BM(bit7), BR(bit8)
    };
    
    // Expected outputs from Python model for MNIST test (Image Index 2)
    // Generated from max_pooling2d layer output
    // NOTE: Only channels 0-2 have activity for this image; channels 3-7 are all zeros
    parameter logic [13:0][13:0][7:0] EXPECTED_OUTPUT_MNIST = '{
        '{8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000},  // row 0
        '{8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000100, 8'b00000111, 8'b00000111, 8'b00000001, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000},  // row 1
        '{8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000110, 8'b00000111, 8'b00000111, 8'b00000111, 8'b00000111, 8'b00000111, 8'b00000001, 8'b00000000, 8'b00000000},  // row 2
        '{8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b11111000, 8'b11111000, 8'b11111000, 8'b11111000, 8'b11111100, 8'b10001111, 8'b00000111, 8'b00000000, 8'b00000000},  // row 3
        '{8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000110, 8'b00000111, 8'b00001101, 8'b11001011, 8'b00000000, 8'b00000000},  // row 4
        '{8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000100, 8'b00000111, 8'b00000111, 8'b00000111, 8'b00000110, 8'b11101111, 8'b11101000, 8'b01000000, 8'b00000000, 8'b00000000},  // row 5
        '{8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000110, 8'b00000111, 8'b00000111, 8'b10001111, 8'b11001111, 8'b01001000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000},  // row 6
        '{8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b11111000, 8'b11111000, 8'b11111100, 8'b10001110, 8'b00000111, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000},  // row 7
        '{8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b01010000, 8'b11011000, 8'b00001111, 8'b00000111, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000},  // row 8
        '{8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000100, 8'b00001111, 8'b11001111, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000},  // row 9
        '{8'b00000000, 8'b00000000, 8'b00000110, 8'b00000111, 8'b00000111, 8'b00000111, 8'b00000111, 8'b00000111, 8'b00001111, 8'b10001011, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000},  // row 10
        '{8'b00000000, 8'b00000000, 8'b11010100, 8'b11001110, 8'b10001110, 8'b10001111, 8'b10001111, 8'b11001110, 8'b11001000, 8'b01000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000},  // row 11
        '{8'b00000000, 8'b00000000, 8'b01010000, 8'b01111000, 8'b01111000, 8'b01111000, 8'b01111000, 8'b01111000, 8'b01000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000},  // row 12
        '{8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000, 8'b00000000}   // row 13
    };
    
    // Expected outputs - Set these based on your test vectors
    // For now, we'll compute them dynamically in the testbench
    
    // ============================================================================
    // State type definition (must match DUT)
    // ============================================================================
    typedef enum logic [2:0] {
        s_IDLE    = 3'b000,
        s_LOAD    = 3'b001,
        s_LAYER_1 = 3'b010,
        s_LAYER_2 = 3'b011,
        s_LAYER_3 = 3'b100
    } state_t;
    
    // ============================================================================
    // Testbench Signals
    // ============================================================================
    logic clk;
    logic rst_n;
    state_t state;
    logic [27:0][27:0] pixels;
    logic [2:0][2:0][7:0] weights;
    logic [13:0][13:0][7:0] layer_one_out;
    logic done;
    
    // Test control
    int error_count = 0;
    int test_count = 0;
    int cycle_count = 0;
    
    // ============================================================================
    // DUT Instantiation
    // ============================================================================
    layer_one dut (
        .clk(clk),
        .rst_n(rst_n),
        .state(state),
        .pixels(pixels),
        .weights(weights),
        .layer_one_out(layer_one_out),
        .done(done)
    );
    
    // ============================================================================
    // Clock Generation - 10ns period (100MHz)
    // ============================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // ============================================================================
    // Helper Tasks
    // ============================================================================
    
    // Wait for clock cycles
    task wait_clocks(input int num_cycles);
        repeat(num_cycles) @(posedge clk);
    endtask
    
    // Apply reset
    task apply_reset();
        $display("LOG: %0t : INFO : tb_layer_one : Applying reset", $time);
        rst_n = 0;
        state = s_IDLE;
        wait_clocks(5);
        rst_n = 1;
        wait_clocks(2);
        $display("LOG: %0t : INFO : tb_layer_one : Reset complete", $time);
    endtask
    
    // Check if done signal is asserted
    task check_done(input logic expected);
        test_count++;
        if (done !== expected) begin
            error_count++;
            $display("LOG: %0t : ERROR : tb_layer_one : dut.done : expected_value: %b actual_value: %b", 
                     $time, expected, done);
        end else begin
            $display("LOG: %0t : INFO : tb_layer_one : dut.done : expected_value: %b actual_value: %b", 
                     $time, expected, done);
        end
    endtask
    
    // Display layer output for debugging
    task display_output(input int weight_idx);
        $display("\n--- Layer One Output for Weight %0d ---", weight_idx);
        for (int r = 0; r < 14; r++) begin
            for (int c = 0; c < 14; c++) begin
                $write("%0d ", layer_one_out[weight_idx][r][c]);
            end
            $display("");
        end
        $display("--------------------------------------\n");
    endtask
    
    // Compute expected convolution result (reference model)
    function automatic logic compute_conv_maxpool(
        input int row, col, wt_num,
        input logic [27:0][27:0] pix,
        input logic [2:0][2:0][7:0] wts
    );
        logic result;
        int threshold;
        int r_base, c_base;
        logic val_00, val_01, val_10, val_11;
        
        r_base = row * 2;
        c_base = col * 2;
        threshold = 5 + (wt_num & 1);  // Alternates between 5 and 6
        
        // Check 4 positions for max pooling (2x2 window)
        val_00 = conv_single(r_base, c_base, pix, wts, wt_num, threshold);
        val_01 = conv_single(r_base, c_base + 1, pix, wts, wt_num, threshold);
        val_10 = conv_single(r_base + 1, c_base, pix, wts, wt_num, threshold);
        val_11 = conv_single(r_base + 1, c_base + 1, pix, wts, wt_num, threshold);
        
        // Max pooling (OR operation for binary)
        result = val_00 | val_01 | val_10 | val_11;
        
        return result;
    endfunction
    
    // Single convolution at a position
    function automatic logic conv_single(
        input int r, c, wt_num, threshold,
        input logic [27:0][27:0] pix,
        input logic [2:0][2:0][7:0] wts
    );
        logic [8:0] conv_result;
        int match_count;
        logic top_left, top_mid, top_right;
        logic mid_left, mid_mid, mid_right;
        logic bot_left, bot_mid, bot_right;
        
        // Handle edge cases (padding with 0)
        top_left  = (r == 0 || c == 0)       ? 1'b0 : pix[r-1][c-1];
        top_mid   = (r == 0)                 ? 1'b0 : pix[r-1][c];
        top_right = (r == 0 || c == 27)     ? 1'b0 : pix[r-1][c+1];
        
        mid_left  = (c == 0)                 ? 1'b0 : pix[r][c-1];
        mid_mid   = pix[r][c];
        mid_right = (c == 27)                ? 1'b0 : pix[r][c+1];
        
        bot_left  = (r == 27 || c == 0)     ? 1'b0 : pix[r+1][c-1];
        bot_mid   = (r == 27)                ? 1'b0 : pix[r+1][c];
        bot_right = (r == 27 || c == 27)    ? 1'b0 : pix[r+1][c+1];
        
        // XNOR operation (match when pixel == weight)
        conv_result = {
            ~(top_left  ^ wts[wt_num][0][0]),
            ~(top_mid   ^ wts[wt_num][0][1]),
            ~(top_right ^ wts[wt_num][0][2]),
            ~(mid_left  ^ wts[wt_num][1][0]),
            ~(mid_mid   ^ wts[wt_num][1][1]),
            ~(mid_right ^ wts[wt_num][1][2]),
            ~(bot_left  ^ wts[wt_num][2][0]),
            ~(bot_mid   ^ wts[wt_num][2][1]),
            ~(bot_right ^ wts[wt_num][2][2])
        };
        
        // Count matches
        match_count = $countones(conv_result);
        
        // Apply threshold (batch normalization)
        return (match_count >= threshold);
    endfunction
    
    // Run complete layer one test with exact expected outputs (for Python model validation)
    task run_mnist_python_test(
        input string test_name,
        input logic [27:0][27:0] test_pixels,
        input logic [2:0][2:0][7:0] test_weights,
        input logic [13:0][13:0][7:0] expected_outputs
    );
        int mismatches;
        logic expected_val;
        
        $display("\n==============================================");
        $display("Running Test: %s", test_name);
        $display("(Python Model Validation)");
        $display("==============================================");
        
        // Setup test inputs
        pixels = test_pixels;
        weights = test_weights;
        
        // Apply reset
        apply_reset();
        
        // Check done is not asserted initially
        check_done(0);
        
        // Transition to LAYER_1 state
        state = s_LAYER_1;
        wait_clocks(1);
        
        $display("LOG: %0t : INFO : tb_layer_one : Starting layer one processing", $time);
        
        // Wait for processing to complete
        cycle_count = 0;
        while (!done && cycle_count < 2000) begin
            @(posedge clk);
            cycle_count++;
        end
        
        if (cycle_count >= 2000) begin
            $display("LOG: %0t : ERROR : tb_layer_one : Processing timeout after %0d cycles", 
                     $time, cycle_count);
            error_count++;
        end else begin
            $display("LOG: %0t : INFO : tb_layer_one : Processing completed in %0d cycles", 
                     $time, cycle_count);
        end
        
        // Check done signal is now asserted
        check_done(1);
        
        // DEBUG: Print first few rows of actual RTL outputs in Python format
        $display("\n====== DEBUG: RTL Outputs (Python format) ======");
        for (int w = 0; w < 8; w++) begin
            $display("\nChannel %0d RTL output:", w);
            for (int r = 0; r < 3; r++) begin  // Show first 3 rows only
                $write("[");
                for (int c = 0; c < 14; c++) begin
                    $write("%0d", layer_one_out[w][r][c]);
                    if (c < 13) $write(" ");
                end
                $write("]");
                if (r < 2) $write("\n ");
            end
            $display("");
        end
        
        // DEBUG: Print expected outputs in same format (with reversed channel index)
        $display("\n====== DEBUG: Expected Outputs (from Python) ======");
        for (int w = 0; w < 8; w++) begin
            $display("\nChannel %0d Expected (extracted from bit %0d):", w, w);
            for (int r = 0; r < 3; r++) begin  // Show first 3 rows only
                $write("[");
                for (int c = 0; c < 14; c++) begin
                    $write("%0d", expected_outputs[r][c][w]);
                    if (c < 13) $write(" ");
                end
                $write("]");
                if (r < 2) $write("\n ");
            end
            $display("");
        end
        $display("===============================================\n");
        
        // Verify outputs against Python model expected values
        $display("Verifying outputs against Python model...");
        mismatches = 0;
        
        for (int w = 0; w < 8; w++) begin
            automatic int channel_mismatches = 0;
            for (int r = 0; r < 14; r++) begin
                for (int c = 0; c < 14; c++) begin
                    expected_val = expected_outputs[r][c][w];  // Extract bit for this channel
                    
                    if (layer_one_out[w][r][c] !== expected_val) begin
                        mismatches++;
                        channel_mismatches++;
                        if (mismatches <= 10) begin  // Only show first 10 mismatches
                            $display("LOG: %0t : ERROR : tb_layer_one : layer_one_out[%0d][%0d][%0d] : expected_value: %b actual_value: %b",
                                     $time, w, r, c, expected_val, layer_one_out[w][r][c]);
                        end
                    end
                end
            end
            
            if (channel_mismatches == 0) begin
                $display("LOG: %0t : INFO : tb_layer_one : Channel %0d output verified successfully (matches Python model)", 
                         $time, w);
            end else begin
                $display("LOG: %0t : ERROR : tb_layer_one : Channel %0d has %0d mismatches", 
                         $time, w, channel_mismatches);
            end
        end
        
        if (mismatches > 0) begin
            $display("\nLOG: %0t : ERROR : tb_layer_one : Total mismatches: %0d", $time, mismatches);
            error_count++;
        end else begin
            $display("\nLOG: %0t : INFO : tb_layer_one : *** ALL OUTPUTS MATCH PYTHON MODEL EXACTLY! ***", $time);
        end
        
        // Return to IDLE
        state = s_IDLE;
        wait_clocks(5);
        
    endtask
    
    // Run complete layer one test
    task run_layer_one_test(
        input string test_name,
        input logic [27:0][27:0] test_pixels,
        input logic [2:0][2:0][7:0] test_weights
    );
        logic expected_val;
        int mismatches;
        
        $display("\n==============================================");
        $display("Running Test: %s", test_name);
        $display("==============================================");
        
        // Setup test inputs
        pixels = test_pixels;
        weights = test_weights;
        
        // Apply reset
        apply_reset();
        
        // Check done is not asserted initially
        check_done(0);
        
        // Transition to LAYER_1 state
        state = s_LAYER_1;
        wait_clocks(1);
        
        $display("LOG: %0t : INFO : tb_layer_one : Starting layer one processing", $time);
        
        // Wait for processing to complete
        // Max cycles: 8 weights * 14 rows * 14 cols = 1568 cycles
        cycle_count = 0;
        while (!done && cycle_count < 2000) begin
            @(posedge clk);
            cycle_count++;
        end
        
        if (cycle_count >= 2000) begin
            $display("LOG: %0t : ERROR : tb_layer_one : Processing timeout after %0d cycles", 
                     $time, cycle_count);
            error_count++;
        end else begin
            $display("LOG: %0t : INFO : tb_layer_one : Processing completed in %0d cycles", 
                     $time, cycle_count);
        end
        
        // Check done signal is now asserted
        check_done(1);
        
        // Verify outputs against golden reference
        $display("\nVerifying outputs...");
        mismatches = 0;
        
        for (int w = 0; w < 8; w++) begin
            for (int r = 0; r < 14; r++) begin
                for (int c = 0; c < 14; c++) begin
                    expected_val = compute_conv_maxpool(r, c, w, test_pixels, test_weights);
                    
                    if (layer_one_out[w][r][c] !== expected_val) begin
                        mismatches++;
                        if (mismatches <= 10) begin  // Only show first 10 mismatches
                            $display("LOG: %0t : ERROR : tb_layer_one : layer_one_out[%0d][%0d][%0d] : expected_value: %b actual_value: %b",
                                     $time, w, r, c, expected_val, layer_one_out[w][r][c]);
                        end
                    end
                end
            end
            
            // Optionally display output for each weight
            if (mismatches == 0) begin
                $display("LOG: %0t : INFO : tb_layer_one : Weight %0d output verified successfully", 
                         $time, w);
            end
        end
        
        if (mismatches > 0) begin
            $display("\nLOG: %0t : ERROR : tb_layer_one : Total mismatches: %0d", $time, mismatches);
            error_count++;
        end else begin
            $display("\nLOG: %0t : INFO : tb_layer_one : All outputs match expected values!", $time);
        end
        
        // Return to IDLE
        state = s_IDLE;
        wait_clocks(5);
        
    endtask
    
    // ============================================================================
    // Main Test Sequence
    // ============================================================================
    initial begin
        $display("TEST START");
        $display("==============================================");
        $display("Layer One Testbench - Binary CNN First Layer");
        $display("==============================================");
        $display("\nModule Specifications:");
        $display("- Input: 28x28 binary pixels");
        $display("- Weights: 8 sets of 3x3 binary kernels");
        $display("- Output: 8 feature maps of 14x14");
        $display("- Operations: Convolution + Batch Norm + Max Pooling");
        $display("==============================================\n");
        
        // Initialize signals
        clk = 0;
        rst_n = 0;
        state = s_IDLE;
        pixels = '0;
        weights = '0;
        
        wait_clocks(2);
        
        // Test 1: Checkerboard pattern
        run_layer_one_test("Checkerboard Pattern", TEST_PIXELS_1, TEST_WEIGHTS);
        
        // Test 2: All zeros
        run_layer_one_test("All Zeros Input", TEST_PIXELS_2, TEST_WEIGHTS);
        
        // Test 3: All ones
        run_layer_one_test("All Ones Input", TEST_PIXELS_3, TEST_WEIGHTS);
        
        // Test 4: Real MNIST digit from Python model
        run_mnist_python_test("MNIST Digit (2) - Python Model", 
                              TEST_PIXELS_MNIST, 
                              TEST_WEIGHTS_MNIST, 
                              EXPECTED_OUTPUT_MNIST);
        
        // Test 5: State control - verify no processing in IDLE
        $display("\n==============================================");
        $display("Test: State Control - IDLE state");
        $display("==============================================");
        apply_reset();
        pixels = TEST_PIXELS_1;
        weights = TEST_WEIGHTS;
        state = s_IDLE;  // Stay in IDLE
        wait_clocks(100);
        check_done(0);  // Should not complete in IDLE
        $display("LOG: %0t : INFO : tb_layer_one : Verified no processing in IDLE state", $time);
        
        // Additional clock cycles for waveform observation
        wait_clocks(10);
        
        // ============================================================================
        // Final Results
        // ============================================================================
        $display("\n==============================================");
        $display("Test Summary:");
        $display("==============================================");
        $display("Total Tests: %0d", test_count);
        $display("Errors:      %0d", error_count);
        
        if (error_count == 0) begin
            $display("\n*** TEST PASSED ***");
            $display("All %0d checks passed!", test_count);
        end else begin
            $display("\n*** TEST FAILED ***");
            $display("ERROR: %0d out of %0d checks failed!", error_count, test_count);
            $error("Layer one verification failed with %0d errors", error_count);
        end
        
        $display("==============================================");
        $finish(0);
    end
    
    // ============================================================================
    // Timeout Watchdog
    // ============================================================================
    initial begin
        #500000; // 500us timeout
        $display("\n==============================================");
        $display("ERROR: Simulation timeout!");
        $display("==============================================");
        $fatal(1, "Simulation exceeded timeout limit");
    end
    
    // ============================================================================
    // Waveform Dump
    // ============================================================================
    initial begin
        $dumpfile("layer_one.fst");
        $dumpvars(0);
    end

endmodule
