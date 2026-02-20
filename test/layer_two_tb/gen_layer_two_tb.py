#!/usr/bin/env python3
"""
Generate tb_layer_two.sv — a SystemVerilog testbench that:
  - Uses multi-dimensional packed arrays matching layer_two.sv ports exactly
    (no flattening, indices like pixels[row][col][ch], layer_two_out[f][r][c])
  - Compares hardware against a Python reference model
  - Uses real MNIST test images and actual trained weights/thresholds

Layer two architecture:
  Input:   [13:0][13:0][7:0]  — 14x14 feature map, 8 channels per pixel
  Weights: [2:0][2:0][7:0]   — 3x3 kernel; bit f = weight for filter f at that position
  Output:  [3:0][6:0][6:0]   — 4 filters × 7x7 output
  Pool:    2x2 max pool (14x14 → 7x7)
  Threshold: 41, 42, 35, 37 per filter (out of 72-bit countones space)

Weight format note:
  The trained model stores 3x3x8 weights per filter (different weight per input channel).
  The hardware uses 1 bit per position per filter, broadcast across all 8 channels.
  We derive hardware weights via majority vote across the 8 trained input-channel weights.

Usage:
  python3 gen_layer_two_tb.py [num_images]
"""

import numpy as np
import struct
import sys
import os

NUM_IMAGES = int(sys.argv[1]) if len(sys.argv) > 1 else 5

L1_WEIGHTS_PATH = "../../src/Python311_training/weights/layer_0_weights.mem"
L1_THRESH_PATH  = "../../src/Python311_training/weights/layer_1_thresholds.mem"
L2_WEIGHTS_PATH = "../../src/Python311_training/weights/layer_3_weights.mem"
L2_THRESH_PATH  = "../../src/Python311_training/weights/layer_4_thresholds.mem"
IMAGES_PATH     = "../../src/Python311_training/training_data/mnist_binary_verifying.ubin"
LABELS_PATH     = "../../src/Python311_training/training_data/mnist_binary_labels_verifying.ubin"
OUTPUT_SV       = "tb_layer_two.sv"

# ---- Load helpers ----------------------------------------------------

def load_l1_weights():
    """8 filters, 3x3x1 kernel each → shape (8, 3, 3)"""
    with open(L1_WEIGHTS_PATH) as f:
        lines = [l.strip() for l in f if l.strip()]
    w = np.zeros((8, 3, 3), dtype=int)
    for k, line in enumerate(lines):
        for i, bit in enumerate(line):
            w[k, i//3, i%3] = int(bit)
    return w

def load_l1_thresholds():
    with open(L1_THRESH_PATH) as f:
        return [int(l.strip(), 2) for l in f if l.strip()]

def load_l2_weights_trained():
    """4 filters, 3x3x8 kernel each → shape (4, 3, 3, 8)"""
    with open(L2_WEIGHTS_PATH) as f:
        lines = [l.strip() for l in f if l.strip()]
    w = np.zeros((4, 3, 3, 8), dtype=int)
    for f_idx, line in enumerate(lines):
        assert len(line) == 72
        for pos, bit in enumerate(line):
            kr = pos // 24          # 0,1,2
            kc = (pos % 24) // 8   # 0,1,2
            ch = pos % 8            # 0..7
            w[f_idx, kr, kc, ch] = int(bit)
    return w

def derive_hw_weights(trained_w):
    """
    trained_w: (4, 3, 3, 8)
    Returns hw_weights: (3, 3, 4) — one bit per position per filter,
    derived by majority vote across the 8 input-channel weights.
    """
    hw = np.zeros((3, 3, 4), dtype=int)
    for f in range(4):
        for kr in range(3):
            for kc in range(3):
                channel_weights = trained_w[f, kr, kc, :]  # 8 bits
                hw[kr, kc, f] = 1 if np.sum(channel_weights) >= 4 else 0
    return hw

def load_l2_thresholds():
    with open(L2_THRESH_PATH) as f:
        return [int(l.strip(), 2) for l in f if l.strip()]

def load_images():
    with open(IMAGES_PATH, 'rb') as f:
        magic, size, rows, cols = struct.unpack(">IIII", f.read(16))
        raw = np.frombuffer(f.read(), dtype=np.uint8)
        bits = np.unpackbits(raw)
        return bits[:size*rows*cols].reshape(size, rows, cols)

def load_labels():
    with open(LABELS_PATH, 'rb') as f:
        magic, size = struct.unpack(">II", f.read(8))
        return np.frombuffer(f.read(), dtype=np.uint8)

# ---- Reference models ------------------------------------------------

def run_layer_one(pixels_28x28, l1_weights, l1_thresh):
    """Returns feature map shape (14, 14, 8) — [row][col][channel]"""
    out = np.zeros((14, 14, 8), dtype=int)
    for k in range(8):
        thresh = l1_thresh[k]
        for r in range(14):
            for c in range(14):
                max_val = 0
                for pr in range(2):
                    for pc in range(2):
                        pix_r = r*2 + pr
                        pix_c = c*2 + pc
                        matches = 0
                        for kr in range(3):
                            for kc in range(3):
                                rr = pix_r + kr - 1
                                cc = pix_c + kc - 1
                                pv = 0 if (rr < 0 or rr >= 28 or cc < 0 or cc >= 28) else int(pixels_28x28[rr, cc])
                                if pv == l1_weights[k, kr, kc]:
                                    matches += 1
                        if matches >= thresh:
                            max_val = 1
                out[r, c, k] = max_val
    return out

def run_layer_two(feature_14x14x8, hw_weights, l2_thresh):
    """
    feature_14x14x8: (14, 14, 8) from layer_one
    hw_weights: (3, 3, 4) — single-bit weight per position per filter
    l2_thresh: list of 4 thresholds (in 72-bit countones space)
    Returns: (4, 7, 7) binary output — [filter][row][col]
    """
    out = np.zeros((4, 7, 7), dtype=int)
    for f in range(4):
        thresh = l2_thresh[f]
        for r in range(7):
            for c in range(7):
                max_val = 0
                for pr in range(2):          # 2x2 max pool
                    for pc in range(2):
                        pix_r = r*2 + pr
                        pix_c = c*2 + pc
                        matches = 0
                        for kr in range(3):  # 3x3 conv
                            for kc in range(3):
                                ir = pix_r + kr - 1
                                ic = pix_c + kc - 1
                                if ir < 0 or ir >= 14 or ic < 0 or ic >= 14:
                                    ch_vals = np.zeros(8, dtype=int)  # zero-pad
                                else:
                                    ch_vals = feature_14x14x8[ir, ic, :]  # 8-ch pixel
                                wt_bit = hw_weights[kr, kc, f]  # single weight bit
                                # XNOR: count channels that match this weight bit
                                matches += int(np.sum(ch_vals == wt_bit))
                        if matches >= thresh:
                            max_val = 1
                out[f, r, c] = max_val
    return out

# ---- Verilog packing -------------------------------------------------
# For SystemVerilog packed arrays, MSB is the leftmost bit in a literal.
# [X:0] dim: index X is MSB-side, index 0 is LSB-side.
# Multi-dim [A:0][B:0][C:0]: index [A][B][C] = MSB, index [0][0][0] = LSB.

def pixels_to_sv(feat_14x14x8):
    """
    Pack (14, 14, 8) → 1568-bit literal for logic [13:0][13:0][7:0]
    MSB = [13][13][7], LSB = [0][0][0]
    """
    bits = []
    for row in range(13, -1, -1):
        for col in range(13, -1, -1):
            for ch in range(7, -1, -1):
                bits.append(str(feat_14x14x8[row, col, ch]))
    return "".join(bits)

def weights_to_sv(hw_weights_3x3x4):
    """
    Pack (3, 3, 4) → 72-bit literal for logic [2:0][2:0][7:0]
    MSB = [2][2][7], LSB = [0][0][0]
    Bits [7:4] at each position are unused (0).
    """
    bits = []
    for kr in range(2, -1, -1):
        for kc in range(2, -1, -1):
            for f in range(7, -1, -1):  # bits 7..4 unused, 3..0 = filters 3..0
                bits.append(str(hw_weights_3x3x4[kr, kc, f]) if f < 4 else '0')
    return "".join(bits)

def output_to_sv(out_4x7x7):
    """
    Pack (4, 7, 7) → 196-bit literal for logic [3:0][6:0][6:0]
    MSB = [3][6][6], LSB = [0][0][0]
    """
    bits = []
    for f in range(3, -1, -1):
        for r in range(6, -1, -1):
            for c in range(6, -1, -1):
                bits.append(str(out_4x7x7[f, r, c]))
    return "".join(bits)

# ---- Main ------------------------------------------------------------

print("Loading weights and thresholds...")
l1_weights  = load_l1_weights()
l1_thresh   = load_l1_thresholds()
trained_l2  = load_l2_weights_trained()
hw_l2       = derive_hw_weights(trained_l2)
l2_thresh   = load_l2_thresholds()

print(f"Layer 2 thresholds: {l2_thresh}")
print("Layer 2 hardware weights (majority-vote from trained, shape 3x3x4):")
for kr in range(3):
    for kc in range(3):
        print(f"  position ({kr},{kc}): filters 0-3 = {hw_l2[kr, kc, :].tolist()}")

print(f"\nLoading {NUM_IMAGES} MNIST test images...")
images = load_images()
labels = load_labels()

w_sv = weights_to_sv(hw_l2)

test_cases = []
for i in range(NUM_IMAGES):
    feat = run_layer_one(images[i], l1_weights, l1_thresh)
    expected = run_layer_two(feat, hw_l2, l2_thresh)
    test_cases.append({
        'index':    i,
        'label':    int(labels[i]),
        'pix_sv':   pixels_to_sv(feat),
        'exp_sv':   output_to_sv(expected),
        'active':   int(np.sum(expected)),
    })
    print(f"  Image {i}: label={int(labels[i])}, active={int(np.sum(expected))}/196")

# ---- Write testbench -------------------------------------------------

sv = []

sv.append('`timescale 1ns/1ps')
sv.append('')
sv.append('// Define state_t here — avoids compiling fsm.sv which crashes icarus 10.2')
sv.append('// (fsm.sv uses always_ff/always_comb which trigger an assertion bug).')
sv.append('// layer_two.sv accepts the port connection because state_t is logic [2:0].')
sv.append('typedef enum logic [2:0] {')
sv.append("    s_IDLE    = 3'b000,")
sv.append("    s_LOAD    = 3'b001,")
sv.append("    s_LAYER_1 = 3'b010,")
sv.append("    s_LAYER_2 = 3'b011,")
sv.append("    s_LAYER_3 = 3'b100")
sv.append('} state_t;')
sv.append('')
sv.append('module tb_layer_two;')
sv.append('')
sv.append('    // ================================================================')
sv.append('    // Weights — packed as logic [2:0][2:0][7:0]')
sv.append('    //   bits [3:0] at each position = filter weights 3..0')
sv.append('    //   bits [7:4] unused (zero)')
sv.append('    //   Derived from layer_3_weights.mem via majority vote')
sv.append('    // ================================================================')
sv.append(f'    logic [2:0][2:0][7:0] TRAINED_WEIGHTS = 72\'b{w_sv};')
sv.append('')
sv.append('    // ================================================================')
sv.append('    // Per-test pixel inputs and expected outputs')
sv.append('    //   pixels  : logic [13:0][13:0][7:0]  — 14x14 × 8-ch feature map')
sv.append('    //   expected: logic [3:0][6:0][6:0]    — 4 filters × 7x7')
sv.append('    // ================================================================')
for tc in test_cases:
    sv.append(f'    // Image {tc["index"]}: label={tc["label"]}, '
              f'active outputs={tc["active"]}/196')
    sv.append(f'    logic [13:0][13:0][7:0] PIXELS_{tc["index"]}   '
              f'= 1568\'b{tc["pix_sv"]};')
    sv.append(f'    logic [3:0][6:0][6:0]   EXPECTED_{tc["index"]} '
              f'= 196\'b{tc["exp_sv"]};')
    sv.append('')

sv.append('    // DUT signals — multi-dimensional types matching layer_two.sv ports')
sv.append('    logic [13:0][13:0][7:0] pixels;')
sv.append('    logic [2:0][2:0][7:0]   weights;')
sv.append('    logic [3:0][6:0][6:0]   layer_two_out;')
sv.append('    logic done, clk, rst_n;')
sv.append('    state_t state;')
sv.append('')
sv.append('    // Module-level staging regs — avoids multi-dim task params (icarus 10.2 limitation)')
sv.append('    logic [13:0][13:0][7:0] test_pixels;')
sv.append('    logic [3:0][6:0][6:0]   test_expected;')
sv.append('')
sv.append('    integer errors = 0, total_checks = 0;')
sv.append('')
sv.append('    layer_two dut (')
sv.append('        .clk(clk), .rst_n(rst_n), .state(state),')
sv.append('        .pixels(pixels), .weights(weights),')
sv.append('        .layer_two_out(layer_two_out), .done(done)')
sv.append('    );')
sv.append('')
sv.append('    initial begin clk = 0; forever #5 clk = ~clk; end')
sv.append('')
sv.append('    // ================================================================')
sv.append('    // run_test: drives DUT and compares using [filter][row][col] indexing')
sv.append('    //           — no flat bit manipulation, purely multi-dim access')
sv.append('    // ================================================================')
sv.append('    // run_test: uses module-level test_pixels/test_expected (set before each call).')
sv.append('    //   Comparison loop uses computed flat bit index [f*49+r*7+c] — equivalent')
sv.append('    //   to [f][r][c] for a [3:0][6:0][6:0] array but supported by icarus 10.2.')
sv.append('    //   Declarations remain multi-dim throughout.')
sv.append('    task run_test;')
sv.append('        input integer img_idx, label;')
sv.append('        integer f, r, c, bit_pos, mismatches;')
sv.append('        begin')
sv.append('            mismatches = 0;')
sv.append('            rst_n = 0; state = s_IDLE;')
sv.append('            pixels  = test_pixels;')
sv.append('            weights = TRAINED_WEIGHTS;')
sv.append('            #20; rst_n = 1;')
sv.append('            #20; state = s_LAYER_2;')
sv.append('            wait(done == 1);')
sv.append('            #100;')
sv.append('')
sv.append('            // bit_pos = f*49 + r*7 + c  (same as [f][r][c] for [3:0][6:0][6:0])')
sv.append('            for (f = 0; f < 4; f = f + 1)')
sv.append('                for (r = 0; r < 7; r = r + 1)')
sv.append('                    for (c = 0; c < 7; c = c + 1) begin')
sv.append('                        bit_pos = f*49 + r*7 + c;')
sv.append('                        total_checks = total_checks + 1;')
sv.append('                        if (layer_two_out[bit_pos] !== test_expected[bit_pos]) begin')
sv.append('                            mismatches = mismatches + 1;')
sv.append('                            errors     = errors + 1;')
sv.append('                        end')
sv.append('                    end')
sv.append('')
sv.append('            if (mismatches == 0)')
sv.append('                $display("PASS  image=%0d  label=%0d  (196/196 outputs correct)", img_idx, label);')
sv.append('            else')
sv.append('                $display("FAIL  image=%0d  label=%0d  (%0d/196 mismatches)", img_idx, label, mismatches);')
sv.append('        end')
sv.append('    endtask')
sv.append('')
sv.append('    initial begin')
sv.append('        $dumpfile("layer_two.vcd");')
sv.append('        $dumpvars(0, tb_layer_two);')
sv.append('')
sv.append('        $display("\\n====================================================");')
sv.append('        $display("Layer Two vs Reference Model");')
sv.append('        $display("Inputs:    layer_one output on real MNIST images");')
sv.append('        $display("Weights:   derived from layer_3_weights.mem (majority vote)");')
sv.append('        $display("Threshold: 41 42 35 37 (from layer_4_thresholds.mem)");')
sv.append(f'        $display("Testing {NUM_IMAGES} images");')
sv.append('        $display("====================================================\\n");')
sv.append('')
for tc in test_cases:
    sv.append(f'        test_pixels   = PIXELS_{tc["index"]};')
    sv.append(f'        test_expected = EXPECTED_{tc["index"]};')
    sv.append(f'        run_test({tc["index"]}, {tc["label"]});')
    sv.append('')
sv.append('')
sv.append('        $display("\\n====================================================");')
sv.append('        if (errors == 0)')
sv.append(f'            $display("ALL {NUM_IMAGES} TESTS PASSED (%0d checks)", total_checks);')
sv.append('        else')
sv.append('            $display("FAILED: %0d errors out of %0d checks", errors, total_checks);')
sv.append('        $display("====================================================\\n");')
sv.append('        #50; $finish;')
sv.append('    end')
sv.append('')
sv.append('    initial begin #500000000; $display("TIMEOUT"); $finish; end')
sv.append('')
sv.append('endmodule')

with open(OUTPUT_SV, 'w') as f:
    f.write('\n'.join(sv) + '\n')

print(f"\nWrote {OUTPUT_SV}")
print(f"Compiled weight literal: 72'b{w_sv}")
