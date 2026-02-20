#!/usr/bin/env python3
"""
Generate test vectors by running simple inputs through a reference model
This helps verify the hardware implementation against known-good outputs
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

# Test Case 1: All zeros
print("="*70)
print("Test Case 1: All Zeros")
print("="*70)

pixels_zeros = np.zeros((28, 28), dtype=int)
weights_simple = np.random.randint(0, 2, (3, 3, 8))  # Random weights
expected_zeros = binary_conv_pooling(pixels_zeros, weights_simple)

p_flat, w_flat, e_flat = flatten_for_verilog(pixels_zeros, weights_simple, expected_zeros)

print(f"// Test Case: All Zeros")
print(f"TEST_PIXELS_ZEROS = 784'b{p_flat};")
print(f"TEST_WEIGHTS_SIMPLE = 72'b{w_flat};")
print(f"EXPECTED_OUTPUT_ZEROS = 1568'b{e_flat};")
print()

# Test Case 2: All ones
print("="*70)
print("Test Case 2: All Ones")
print("="*70)

pixels_ones = np.ones((28, 28), dtype=int)
expected_ones = binary_conv_pooling(pixels_ones, weights_simple)

p_flat, w_flat, e_flat = flatten_for_verilog(pixels_ones, weights_simple, expected_ones)

print(f"// Test Case: All Ones")
print(f"TEST_PIXELS_ONES = 784'b{p_flat};")
print(f"TEST_WEIGHTS_SIMPLE = 72'b{w_flat};")  # Same weights
print(f"EXPECTED_OUTPUT_ONES = 1568'b{e_flat};")
print()

# Test Case 3: Checkerboard
print("="*70)
print("Test Case 3: Checkerboard")
print("="*70)

pixels_checker = np.zeros((28, 28), dtype=int)
for r in range(28):
    for c in range(28):
        pixels_checker[r, c] = (r + c) % 2

expected_checker = binary_conv_pooling(pixels_checker, weights_simple)

p_flat, w_flat, e_flat = flatten_for_verilog(pixels_checker, weights_simple, expected_checker)

print(f"// Test Case: Checkerboard")
print(f"TEST_PIXELS_CHECKER = 784'b{p_flat};")
print(f"TEST_WEIGHTS_SIMPLE = 72'b{w_flat};")  # Same weights
print(f"EXPECTED_OUTPUT_CHECKER = 1568'b{e_flat};")
print()

# Test Case 4: MNIST digit '3' (from convert_to_flattened.py)
print("="*70)
print("Test Case 4: MNIST Digit '3'")
print("="*70)

TEST_PIXELS_MNIST = [
    "0000000000000000000000000000",
    "0000000000000000000000000000",
    "0000000000000000000000000000",
    "0000000000000000000000000000",
    "0000000000001111000000000000",
    "0000000011111111111000000000",
    "0000000011111111111100000000",
    "0000000000000000001110000000",
    "0000000000000000000110000000",
    "0000000000000000001100000000",
    "0000000000000111100000000000",
    "0000000000000001100000000000",
    "0000000111111110000000000000",
    "0000000111111100000000000000",
    "0000000111111000000000000000",
    "0000000000001110000000000000",
    "0000000000000110000000000000",
    "0000000000000011000000000000",
    "0000000000000011100000000000",
    "0000000000000011000000000000",
    "0000000000000011000000000000",
    "0000001111100011110000000000",
    "0000001111111111110000000000",
    "0000000111111111000000000000",
    "0000000000000000000000000000",
    "0000000000000000000000000000",
    "0000000000000000000000000000",
    "0000000000000000000000000000",
]

TEST_WEIGHTS_MNIST = [
    ["11101010", "01111000", "11111000"],
    ["10001111", "10001101", "10000110"],
    ["00000011", "00000111", "00000110"],
]

# Convert to numpy arrays
pixels_mnist = np.zeros((28, 28), dtype=int)
for r in range(28):
    for c in range(28):
        pixels_mnist[r, c] = int(TEST_PIXELS_MNIST[r][c])

weights_mnist = np.zeros((3, 3, 8), dtype=int)
for r in range(3):
    for c in range(3):
        for w in range(8):
            weights_mnist[r, c, w] = int(TEST_WEIGHTS_MNIST[r][c][w])

expected_mnist = binary_conv_pooling(pixels_mnist, weights_mnist)

p_flat, w_flat, e_flat = flatten_for_verilog(pixels_mnist, weights_mnist, expected_mnist)

print(f"// Test Case: MNIST Digit '3'")
print(f"TEST_PIXELS_MNIST = 784'b{p_flat};")
print(f"TEST_WEIGHTS_MNIST = 72'b{w_flat};")
print(f"EXPECTED_OUTPUT_MNIST = 1568'b{e_flat};")
print()

print("="*70)
print("Summary:")
print(f"  Simple weights (tests 1-3): Same weights used")
print(f"  All zeros output has {np.sum(expected_zeros)} ones")
print(f"  All ones output has {np.sum(expected_ones)} ones")
print(f"  Checkerboard output has {np.sum(expected_checker)} ones")
print(f"  MNIST digit '3' output has {np.sum(expected_mnist)} ones")
print("="*70)
