#!/usr/bin/env python3
"""
Generate test vectors for multiple handwritten-style digits (0, 1, 2, 5, 7)
Uses the same reference model as generate_test_vectors.py
"""

import numpy as np

def binary_conv_pooling(pixels, weights):
    """
    Reference implementation of layer_one logic:
    - Binary convolution with XNOR
    - Batch normalization (threshold-based)
    - Max pooling (2x2, stride 2)

    pixels: 28x28 binary array
    weights: 3x3x8 binary array (8 kernels)

    Returns: 14x14x8 binary output
    """
    output = np.zeros((8, 14, 14), dtype=int)

    for w in range(8):  # For each weight kernel
        # Threshold: even kernels use 5, odd kernels use 6
        threshold = 5 + (w & 1)

        for r in range(14):  # For each output row
            for c in range(14):  # For each output col
                # Max pooling over 2x2 window in 28x28 space
                max_val = 0

                for pr in range(2):  # Pool row
                    for pc in range(2):  # Pool col
                        # Convolve at position (r*2+pr, c*2+pc)
                        pixel_r = r * 2 + pr
                        pixel_c = c * 2 + pc

                        # Perform 3x3 convolution
                        matches = 0
                        for kr in range(3):
                            for kc in range(3):
                                # Pixel position with boundary check
                                pr_pos = pixel_r + kr - 1
                                pc_pos = pixel_c + kc - 1

                                if pr_pos < 0 or pr_pos >= 28 or pc_pos < 0 or pc_pos >= 28:
                                    pixel_val = 0
                                else:
                                    pixel_val = pixels[pr_pos, pc_pos]

                                weight_val = weights[kr, kc, w]

                                # XNOR: match if both same
                                if pixel_val == weight_val:
                                    matches += 1

                        # Batch norm: activate if matches >= threshold
                        if matches >= threshold:
                            max_val = 1

                output[w, r, c] = max_val

    return output

def flatten_for_verilog(pixels, weights, expected):
    """Convert to flattened format for Verilog, with bit reversal"""

    # Flatten pixels (28x28 -> 784 bits)
    pixels_flat = ""
    for r in range(28):
        for c in range(28):
            pixels_flat += str(pixels[r, c])
    pixels_flat = pixels_flat[::-1]  # Reverse for Verilog indexing

    # Flatten weights (3x3x8 -> 72 bits)
    # Format: weights[r*24 + c*8 + w]
    weights_array = ['0'] * 72
    for r in range(3):
        for c in range(3):
            for w in range(8):
                idx = r * 24 + c * 8 + w
                weights_array[idx] = str(weights[r, c, w])
    weights_flat = ''.join(weights_array[::-1])  # Reverse

    # Flatten expected output (14x14x8 -> 1568 bits)
    # Format: out[w*196 + r*14 + c]
    output_array = ['0'] * 1568
    for w in range(8):
        for r in range(14):
            for c in range(14):
                idx = w * 196 + r * 14 + c
                output_array[idx] = str(expected[w, r, c])
    output_flat = ''.join(output_array[::-1])  # Reverse

    return pixels_flat, weights_flat, output_flat

# Define handwritten-style digit patterns (28x28)
DIGITS = {
    '0': [
        "0000000000000000000000000000",
        "0000000000000000000000000000",
        "0000000000000000000000000000",
        "0000000000000000000000000000",
        "0000000001111111110000000000",
        "0000000111111111111100000000",
        "0000001111000000011110000000",
        "0000011110000000001111000000",
        "0000111100000000000111100000",
        "0000111000000000000011100000",
        "0001111000000000000011110000",
        "0001110000000000000001110000",
        "0001110000000000000001110000",
        "0001110000000000000001110000",
        "0001110000000000000001110000",
        "0001110000000000000001110000",
        "0001111000000000000011110000",
        "0000111000000000000011100000",
        "0000111100000000000111100000",
        "0000011110000000001111000000",
        "0000001111000000011110000000",
        "0000000111111111111100000000",
        "0000000001111111110000000000",
        "0000000000000000000000000000",
        "0000000000000000000000000000",
        "0000000000000000000000000000",
        "0000000000000000000000000000",
        "0000000000000000000000000000",
    ],
    '1': [
        "0000000000000000000000000000",
        "0000000000000000000000000000",
        "0000000000000000000000000000",
        "0000000000000000000000000000",
        "0000000000011100000000000000",
        "0000000000111100000000000000",
        "0000000001111100000000000000",
        "0000000011111100000000000000",
        "0000000111111100000000000000",
        "0000000000111100000000000000",
        "0000000000111100000000000000",
        "0000000000111100000000000000",
        "0000000000111100000000000000",
        "0000000000111100000000000000",
        "0000000000111100000000000000",
        "0000000000111100000000000000",
        "0000000000111100000000000000",
        "0000000000111100000000000000",
        "0000000000111100000000000000",
        "0000000000111100000000000000",
        "0000000000111100000000000000",
        "0000001111111111111000000000",
        "0000001111111111111000000000",
        "0000000000000000000000000000",
        "0000000000000000000000000000",
        "0000000000000000000000000000",
        "0000000000000000000000000000",
        "0000000000000000000000000000",
    ],
    '2': [
        "0000000000000000000000000000",
        "0000000000000000000000000000",
        "0000000000000000000000000000",
        "0000000000111111110000000000",
        "0000000111111111111100000000",
        "0000001111100000111110000000",
        "0000011110000000001111000000",
        "0000111100000000000111100000",
        "0000000000000000000011100000",
        "0000000000000000000111100000",
        "0000000000000000001111000000",
        "0000000000000000011110000000",
        "0000000000000000111100000000",
        "0000000000000001111000000000",
        "0000000000000011110000000000",
        "0000000000000111100000000000",
        "0000000000001111000000000000",
        "0000000000011110000000000000",
        "0000000000111100000000000000",
        "0000000001111000000000000000",
        "0000000011110000000000000000",
        "0000001111111111111111000000",
        "0000001111111111111111000000",
        "0000000000000000000000000000",
        "0000000000000000000000000000",
        "0000000000000000000000000000",
        "0000000000000000000000000000",
        "0000000000000000000000000000",
    ],
    '5': [
        "0000000000000000000000000000",
        "0000000000000000000000000000",
        "0000000000000000000000000000",
        "0000001111111111111100000000",
        "0000001111111111111100000000",
        "0000001111000000000000000000",
        "0000001110000000000000000000",
        "0000001110000000000000000000",
        "0000001110000000000000000000",
        "0000001110000000000000000000",
        "0000001111111111100000000000",
        "0000001111111111111000000000",
        "0000000000000000111110000000",
        "0000000000000000001111000000",
        "0000000000000000000111100000",
        "0000000000000000000011100000",
        "0000000000000000000011100000",
        "0000000000000000000111100000",
        "0000111100000000001111000000",
        "0000111110000000011110000000",
        "0000011111100001111100000000",
        "0000000111111111111000000000",
        "0000000001111111100000000000",
        "0000000000000000000000000000",
        "0000000000000000000000000000",
        "0000000000000000000000000000",
        "0000000000000000000000000000",
        "0000000000000000000000000000",
    ],
    '7': [
        "0000000000000000000000000000",
        "0000000000000000000000000000",
        "0000000000000000000000000000",
        "0000011111111111111111100000",
        "0000011111111111111111100000",
        "0000000000000000001111000000",
        "0000000000000000011110000000",
        "0000000000000000011100000000",
        "0000000000000000111100000000",
        "0000000000000000111000000000",
        "0000000000000001111000000000",
        "0000000000000001110000000000",
        "0000000000000011110000000000",
        "0000000000000011100000000000",
        "0000000000000111100000000000",
        "0000000000000111000000000000",
        "0000000000001111000000000000",
        "0000000000001110000000000000",
        "0000000000011110000000000000",
        "0000000000011100000000000000",
        "0000000000111100000000000000",
        "0000000000111000000000000000",
        "0000000001111000000000000000",
        "0000000001110000000000000000",
        "0000000000000000000000000000",
        "0000000000000000000000000000",
        "0000000000000000000000000000",
        "0000000000000000000000000000",
    ]
}

# Use same weights for all digits
weights_simple = np.random.randint(0, 2, (3, 3, 8))
np.random.seed(42)  # For reproducibility
weights_simple = np.random.randint(0, 2, (3, 3, 8))

print("="*70)
print("MNIST-Style Digit Test Vectors")
print("="*70)
print()

for digit_name in ['0', '1', '2', '5', '7']:
    # Convert to numpy array
    pixels = np.zeros((28, 28), dtype=int)
    for r in range(28):
        for c in range(28):
            pixels[r, c] = int(DIGITS[digit_name][r][c])

    # Compute expected output
    expected = binary_conv_pooling(pixels, weights_simple)

    # Flatten for Verilog
    p_flat, w_flat, e_flat = flatten_for_verilog(pixels, weights_simple, expected)

    print(f"// Digit {digit_name}")
    print(f"reg [783:0] TEST_PIXELS_DIGIT_{digit_name} = 784'b{p_flat};")
    print(f"reg [1567:0] EXPECTED_OUTPUT_DIGIT_{digit_name} = 1568'b{e_flat};")
    print()

# Print weights once
p_flat, w_flat, e_flat = flatten_for_verilog(pixels, weights_simple, expected)
print(f"// Common weights for all digit tests")
print(f"reg [71:0] TEST_WEIGHTS_DIGITS = 72'b{w_flat};")
print()

print("="*70)
print("Summary:")
for digit_name in ['0', '1', '2', '5', '7']:
    pixels = np.zeros((28, 28), dtype=int)
    for r in range(28):
        for c in range(28):
            pixels[r, c] = int(DIGITS[digit_name][r][c])
    expected = binary_conv_pooling(pixels, weights_simple)
    print(f"  Digit {digit_name}: {np.sum(expected)} active outputs")
print("="*70)
