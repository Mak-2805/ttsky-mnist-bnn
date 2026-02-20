#!/usr/bin/env python3
"""
Compare hardware layer_one output against the ACTUAL trained model.

Sources:
  - Pixels:     Real MNIST test images from mnist_binary_verifying.ubin
  - Weights:    Actual trained weights from layer_0_weights.mem
  - Thresholds: Actual trained batch-norm thresholds from layer_1_thresholds.mem
  - Logic:      XNOR convolution + threshold + 2x2 max pooling (same as hardware)

Usage:
  python3 compare_trained_model.py [num_images]
  Outputs Verilog test vectors ready for tb_layer_one_simple.sv
"""

import numpy as np
import struct
import sys

# ============================================================
# Paths
# ============================================================
WEIGHTS_PATH    = "../../src/Python311_training/weights/layer_0_weights.mem"
THRESH_PATH     = "../../src/Python311_training/weights/layer_1_thresholds.mem"
IMAGES_PATH     = "../../src/Python311_training/training_data/mnist_binary_verifying.ubin"
LABELS_PATH     = "../../src/Python311_training/training_data/mnist_binary_labels_verifying.ubin"

# ============================================================
# Load trained weights: 8 kernels, each 9 bits (3x3)
# File format: one line per kernel, "000110110" means row-major 3x3
# weights[kernel][row][col]
# ============================================================
def load_weights():
    with open(WEIGHTS_PATH) as f:
        lines = [l.strip() for l in f if l.strip()]
    assert len(lines) == 8, f"Expected 8 kernels, got {len(lines)}"
    weights = np.zeros((8, 3, 3), dtype=int)
    for k, line in enumerate(lines):
        assert len(line) == 9, f"Expected 9 bits per kernel, got {len(line)}"
        for i, bit in enumerate(line):
            weights[k, i // 3, i % 3] = int(bit)
    return weights

# ============================================================
# Load trained thresholds: 8 values, one per kernel
# File format: "00000101" = 5
# ============================================================
def load_thresholds():
    with open(THRESH_PATH) as f:
        lines = [l.strip() for l in f if l.strip()]
    assert len(lines) == 8, f"Expected 8 thresholds, got {len(lines)}"
    return [int(line, 2) for line in lines]

# ============================================================
# Load MNIST binary images
# File format: same as MNIST but pixels are already binary (0/1)
# packed as bits in uint8
# ============================================================
def load_images():
    with open(IMAGES_PATH, 'rb') as f:
        magic, size, rows, cols = struct.unpack(">IIII", f.read(16))
        assert magic == 2051, f"Bad magic: {magic}"
        raw = np.frombuffer(f.read(), dtype=np.uint8)
        bits = np.unpackbits(raw)
        images = bits[:size * rows * cols].reshape(size, rows, cols)
    return images

def load_labels():
    with open(LABELS_PATH, 'rb') as f:
        magic, size = struct.unpack(">II", f.read(8))
        assert magic == 2049, f"Bad magic: {magic}"
        labels = np.frombuffer(f.read(), dtype=np.uint8)
    return labels

# ============================================================
# Layer 1 reference model (matches hardware exactly)
# ============================================================
def run_layer_one(pixels, weights, thresholds):
    """
    pixels:     28x28 binary array
    weights:    8x3x3 binary array (8 kernels)
    thresholds: list of 8 ints

    Returns: 8x14x14 binary output
    """
    output = np.zeros((8, 14, 14), dtype=int)

    for k in range(8):
        thresh = thresholds[k]
        for r in range(14):
            for c in range(14):
                max_val = 0
                for pr in range(2):      # 2x2 max pool
                    for pc in range(2):
                        pixel_r = r * 2 + pr
                        pixel_c = c * 2 + pc
                        matches = 0
                        for kr in range(3):   # 3x3 conv
                            for kc in range(3):
                                pr_pos = pixel_r + kr - 1
                                pc_pos = pixel_c + kc - 1
                                if pr_pos < 0 or pr_pos >= 28 or pc_pos < 0 or pc_pos >= 28:
                                    pval = 0
                                else:
                                    pval = int(pixels[pr_pos, pc_pos])
                                wval = weights[k, kr, kc]
                                if pval == wval:   # XNOR
                                    matches += 1
                        if matches >= thresh:
                            max_val = 1
                output[k, r, c] = max_val

    return output

# ============================================================
# Format for Verilog (flattened, bit-reversed)
# ============================================================
def pixels_to_verilog(pixels):
    flat = ""
    for r in range(28):
        for c in range(28):
            flat += str(int(pixels[r, c]))
    return flat[::-1]   # bit-reverse for Verilog [783:0]

def weights_to_verilog(weights):
    # weights[k][r][c] -> hardware format weights[r*24 + c*8 + k]
    arr = ['0'] * 72
    for k in range(8):
        for r in range(3):
            for c in range(3):
                idx = r * 24 + c * 8 + k
                arr[idx] = str(weights[k, r, c])
    return ''.join(arr[::-1])   # bit-reverse

def output_to_verilog(output):
    # output[k][r][c] -> hardware format out[k*196 + r*14 + c]
    arr = ['0'] * 1568
    for k in range(8):
        for r in range(14):
            for c in range(14):
                idx = k * 196 + r * 14 + c
                arr[idx] = str(output[k, r, c])
    return ''.join(arr[::-1])   # bit-reverse

# ============================================================
# Main
# ============================================================
def main():
    num_images = int(sys.argv[1]) if len(sys.argv) > 1 else 5

    print("Loading trained weights and thresholds...")
    weights    = load_weights()
    thresholds = load_thresholds()

    print("Weights (8 kernels, 3x3 each):")
    for k in range(8):
        print(f"  kernel {k}: {weights[k].flatten().tolist()}  threshold={thresholds[k]}")

    print(f"\nLoading {num_images} real MNIST test images...")
    images = load_images()
    labels = load_labels()
    print(f"  Dataset size: {len(images)} images")

    w_flat = weights_to_verilog(weights)
    print(f"\nVerilog weights (same for all tests):")
    print(f"  reg [71:0] TEST_WEIGHTS_TRAINED = 72'b{w_flat};")

    print(f"\n{'='*70}")
    print(f"Generating {num_images} test vectors from real MNIST data")
    print(f"{'='*70}\n")

    for i in range(num_images):
        pixels   = images[i]
        label    = labels[i]
        expected = run_layer_one(pixels, weights, thresholds)

        p_flat = pixels_to_verilog(pixels)
        e_flat = output_to_verilog(expected)

        active = int(np.sum(expected))
        print(f"// Image index {i}, label={label}, active outputs={active}/1568")
        print(f"TEST_PIXELS_{i} = 784'b{p_flat};")
        print(f"EXPECTED_OUTPUT_{i} = 1568'b{e_flat};")
        print()

    # Print weight once at end
    print(f"// Trained weights (use for all tests above)")
    print(f"TEST_WEIGHTS_TRAINED = 72'b{w_flat};")
    print()

    # Visualize first image
    print(f"{'='*70}")
    print(f"First image (label={labels[0]}) visualization:")
    for r in range(28):
        print(''.join(['#' if images[0][r, c] else ' ' for c in range(28)]))

if __name__ == "__main__":
    main()
