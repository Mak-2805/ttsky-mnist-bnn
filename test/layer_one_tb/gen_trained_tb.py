#!/usr/bin/env python3
"""
Generate a Verilog testbench that compares hardware layer_one output
against the ACTUAL trained model using real MNIST test images.

Writes: tb_layer_one_trained.sv
"""

import numpy as np
import struct
import sys

WEIGHTS_PATH = "../../src/Python311_training/weights/layer_0_weights.mem"
THRESH_PATH  = "../../src/Python311_training/weights/layer_1_thresholds.mem"
IMAGES_PATH  = "../../src/Python311_training/training_data/mnist_binary_verifying.ubin"
LABELS_PATH  = "../../src/Python311_training/training_data/mnist_binary_labels_verifying.ubin"
OUTPUT_SV    = "tb_layer_one_trained.sv"

NUM_IMAGES = int(sys.argv[1]) if len(sys.argv) > 1 else 5

# ---- Load data -------------------------------------------------------

def load_weights():
    with open(WEIGHTS_PATH) as f:
        lines = [l.strip() for l in f if l.strip()]
    weights = np.zeros((8, 3, 3), dtype=int)
    for k, line in enumerate(lines):
        for i, bit in enumerate(line):
            weights[k, i // 3, i % 3] = int(bit)
    return weights

def load_thresholds():
    with open(THRESH_PATH) as f:
        lines = [l.strip() for l in f if l.strip()]
    return [int(line, 2) for line in lines]

def load_images():
    with open(IMAGES_PATH, 'rb') as f:
        magic, size, rows, cols = struct.unpack(">IIII", f.read(16))
        raw = np.frombuffer(f.read(), dtype=np.uint8)
        bits = np.unpackbits(raw)
        return bits[:size * rows * cols].reshape(size, rows, cols)

def load_labels():
    with open(LABELS_PATH, 'rb') as f:
        magic, size = struct.unpack(">II", f.read(8))
        return np.frombuffer(f.read(), dtype=np.uint8)

# ---- Reference model -------------------------------------------------

def run_layer_one(pixels, weights, thresholds):
    output = np.zeros((8, 14, 14), dtype=int)
    for k in range(8):
        thresh = thresholds[k]
        for r in range(14):
            for c in range(14):
                max_val = 0
                for pr in range(2):
                    for pc in range(2):
                        pixel_r = r * 2 + pr
                        pixel_c = c * 2 + pc
                        matches = 0
                        for kr in range(3):
                            for kc in range(3):
                                pr_pos = pixel_r + kr - 1
                                pc_pos = pixel_c + kc - 1
                                if pr_pos < 0 or pr_pos >= 28 or pc_pos < 0 or pc_pos >= 28:
                                    pval = 0
                                else:
                                    pval = int(pixels[pr_pos, pc_pos])
                                if pval == weights[k, kr, kc]:
                                    matches += 1
                        if matches >= thresh:
                            max_val = 1
                output[k, r, c] = max_val
    return output

# ---- Verilog flattening ----------------------------------------------

def pixels_to_verilog(pixels):
    flat = "".join(str(int(pixels[r, c])) for r in range(28) for c in range(28))
    return flat[::-1]

def weights_to_verilog(weights):
    arr = ['0'] * 72
    for k in range(8):
        for r in range(3):
            for c in range(3):
                arr[r * 24 + c * 8 + k] = str(weights[k, r, c])
    return ''.join(arr[::-1])

def output_to_verilog(output):
    arr = ['0'] * 1568
    for k in range(8):
        for r in range(14):
            for c in range(14):
                arr[k * 196 + r * 14 + c] = str(output[k, r, c])
    return ''.join(arr[::-1])

# ---- Main ------------------------------------------------------------

weights    = load_weights()
thresholds = load_thresholds()
images     = load_images()
labels     = load_labels()

w_flat = weights_to_verilog(weights)

test_cases = []
for i in range(NUM_IMAGES):
    expected = run_layer_one(images[i], weights, thresholds)
    test_cases.append({
        'index':    i,
        'label':    int(labels[i]),
        'p_flat':   pixels_to_verilog(images[i]),
        'e_flat':   output_to_verilog(expected),
        'active':   int(np.sum(expected)),
    })

print(f"Generated {NUM_IMAGES} test vectors from real MNIST data")
for tc in test_cases:
    print(f"  Image {tc['index']}: label={tc['label']}, active={tc['active']}/1568")

# ---- Write testbench -------------------------------------------------

sv = []
sv.append('`timescale 1ns/1ps')
sv.append('')
sv.append('module tb_layer_one_trained;')
sv.append('')
sv.append('    // =========================================================')
sv.append('    // Actual trained weights from layer_0_weights.mem')
sv.append('    // Actual thresholds from layer_1_thresholds.mem')
sv.append('    // Real MNIST test images from mnist_binary_verifying.ubin')
sv.append('    // =========================================================')
sv.append('')
sv.append(f'    // Trained weights (same for all tests)')
sv.append(f'    reg [71:0] TRAINED_WEIGHTS = 72\'b{w_flat};')
sv.append('')

for tc in test_cases:
    sv.append(f'    // Image {tc["index"]}: MNIST label={tc["label"]}, active outputs={tc["active"]}/1568')
    sv.append(f'    reg [783:0]  PIXELS_{tc["index"]}   = 784\'b{tc["p_flat"]};')
    sv.append(f'    reg [1567:0] EXPECTED_{tc["index"]} = 1568\'b{tc["e_flat"]};')
    sv.append('')

sv.append('    // DUT signals')
sv.append('    reg clk, rst_n;')
sv.append('    reg [2:0] state;')
sv.append('    reg [783:0]  pixels;')
sv.append('    reg [71:0]   weights;')
sv.append('    wire [1567:0] layer_one_out;')
sv.append('    wire done;')
sv.append('')
sv.append('    integer errors = 0, total_checks = 0;')
sv.append('')
sv.append('    layer_one dut (')
sv.append('        .clk(clk), .rst_n(rst_n), .state(state),')
sv.append('        .pixels(pixels), .weights(weights),')
sv.append('        .layer_one_out(layer_one_out), .done(done)')
sv.append('    );')
sv.append('')
sv.append('    localparam [2:0] s_LAYER_1 = 3\'b010;')
sv.append('')
sv.append('    initial begin clk = 0; forever #5 clk = ~clk; end')
sv.append('')
sv.append('    function integer out_idx;')
sv.append('        input integer k, r, c;')
sv.append('        begin out_idx = k*196 + r*14 + c; end')
sv.append('    endfunction')
sv.append('')
sv.append('    task run_test;')
sv.append('        input [783:0]  pix;')
sv.append('        input [1567:0] expected;')
sv.append('        input integer  img_idx;')
sv.append('        input integer  label;')
sv.append('        integer k, r, c, idx, mismatches;')
sv.append('        begin')
sv.append('            mismatches = 0;')
sv.append('            rst_n = 0; state = 3\'b000;')
sv.append('            pixels = pix; weights = TRAINED_WEIGHTS;')
sv.append('            #20; rst_n = 1;')
sv.append('            #20; state = s_LAYER_1;')
sv.append('            wait(done == 1);')
sv.append('            #100;')
sv.append('')
sv.append('            for (k = 0; k < 8; k = k + 1)')
sv.append('                for (r = 0; r < 14; r = r + 1)')
sv.append('                    for (c = 0; c < 14; c = c + 1) begin')
sv.append('                        idx = out_idx(k, r, c);')
sv.append('                        total_checks = total_checks + 1;')
sv.append('                        if (layer_one_out[idx] !== expected[idx]) begin')
sv.append('                            mismatches = mismatches + 1;')
sv.append('                            errors = errors + 1;')
sv.append('                        end')
sv.append('                    end')
sv.append('')
sv.append('            if (mismatches == 0)')
sv.append('                $display("PASS  image=%0d  label=%0d", img_idx, label);')
sv.append('            else')
sv.append('                $display("FAIL  image=%0d  label=%0d  mismatches=%0d/1568", img_idx, label, mismatches);')
sv.append('        end')
sv.append('    endtask')
sv.append('')
sv.append('    initial begin')
sv.append('        $dumpfile("layer_one_trained.vcd");')
sv.append('        $dumpvars(0, tb_layer_one_trained);')
sv.append('')
sv.append('        $display("\\n====================================================");')
sv.append('        $display("Layer One vs Trained Model - Real MNIST Test");')
sv.append('        $display("Weights: actual trained weights from layer_0_weights.mem");')
sv.append('        $display("Images:  real MNIST from mnist_binary_verifying.ubin");')
sv.append(f'        $display("Testing {NUM_IMAGES} images");')
sv.append('        $display("====================================================\\n");')
sv.append('')

for tc in test_cases:
    sv.append(f'        run_test(PIXELS_{tc["index"]}, EXPECTED_{tc["index"]}, {tc["index"]}, {tc["label"]});')

sv.append('')
sv.append('        $display("\\n====================================================");')
sv.append('        if (errors == 0)')
sv.append(f'            $display("ALL {NUM_IMAGES} TESTS PASSED (%0d checks)", total_checks);')
sv.append('        else')
sv.append('            $display("FAILED: %0d errors / %0d checks", errors, total_checks);')
sv.append('        $display("====================================================\\n");')
sv.append('        #50; $finish;')
sv.append('    end')
sv.append('')
sv.append('    initial begin #200000000; $display("TIMEOUT"); $finish; end')
sv.append('')
sv.append('endmodule')

with open(OUTPUT_SV, 'w') as f:
    f.write('\n'.join(sv) + '\n')

print(f"\nWrote {OUTPUT_SV}")
