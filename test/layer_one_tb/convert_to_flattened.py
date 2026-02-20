#!/usr/bin/env python3
"""
Convert multi-dimensional test vectors from tb_layer_one.sv to flattened format
for use in tb_layer_one_simple.sv

IMPORTANT: Verilog bit indexing is [MSB:LSB] where bit 0 is the rightmost (LSB).
So we need to reverse the bitstring before using it in Verilog.
"""

# MNIST pixels from original testbench (28x28)
TEST_PIXELS_MNIST = [
    "0000000000000000000000000000",  # row 0
    "0000000000000000000000000000",  # row 1
    "0000000000000000000000000000",  # row 2
    "0000000000000000000000000000",  # row 3
    "0000000000001111000000000000",  # row 4
    "0000000011111111111000000000",  # row 5
    "0000000011111111111100000000",  # row 6
    "0000000000000000001110000000",  # row 7
    "0000000000000000000110000000",  # row 8
    "0000000000000000001100000000",  # row 9
    "0000000000000111100000000000",  # row 10
    "0000000000000001100000000000",  # row 11
    "0000000111111110000000000000",  # row 12
    "0000000111111100000000000000",  # row 13
    "0000000111111000000000000000",  # row 14
    "0000000000001110000000000000",  # row 15
    "0000000000000110000000000000",  # row 16
    "0000000000000011000000000000",  # row 17
    "0000000000000011100000000000",  # row 18
    "0000000000000011000000000000",  # row 19
    "0000000000000011000000000000",  # row 20
    "0000001111100011110000000000",  # row 21
    "0000001111111111110000000000",  # row 22
    "0000000111111111000000000000",  # row 23
    "0000000000000000000000000000",  # row 24
    "0000000000000000000000000000",  # row 25
    "0000000000000000000000000000",  # row 26
    "0000000000000000000000000000",  # row 27
]

# Weights from original testbench (3x3x8)
TEST_WEIGHTS_MNIST = [
    ["11101010", "01111000", "11111000"],  # row 0
    ["10001111", "10001101", "10000110"],  # row 1
    ["00000011", "00000111", "00000110"],  # row 2
]

# Expected outputs from original testbench (14x14x8)
EXPECTED_OUTPUT_MNIST = [
    ["00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000"],  # row 0
    ["00000000", "00000000", "00000000", "00000000", "00000000", "00000100", "00000111", "00000111", "00000001", "00000000", "00000000", "00000000", "00000000", "00000000"],  # row 1
    ["00000000", "00000000", "00000000", "00000000", "00000000", "00000110", "00000111", "00000111", "00000111", "00000111", "00000111", "00000001", "00000000", "00000000"],  # row 2
    ["00000000", "00000000", "00000000", "00000000", "00000000", "11111000", "11111000", "11111000", "11111000", "11111100", "10001111", "00000111", "00000000", "00000000"],  # row 3
    ["00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000110", "00000111", "00001101", "11001011", "00000000", "00000000"],  # row 4
    ["00000000", "00000000", "00000000", "00000000", "00000100", "00000111", "00000111", "00000111", "00000110", "11101111", "11101000", "01000000", "00000000", "00000000"],  # row 5
    ["00000000", "00000000", "00000000", "00000000", "00000110", "00000111", "00000111", "10001111", "11001111", "01001000", "00000000", "00000000", "00000000", "00000000"],  # row 6
    ["00000000", "00000000", "00000000", "00000000", "11111000", "11111000", "11111100", "10001110", "00000111", "00000000", "00000000", "00000000", "00000000", "00000000"],  # row 7
    ["00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "01010000", "11011000", "00001111", "00000111", "00000000", "00000000", "00000000", "00000000"],  # row 8
    ["00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000100", "00001111", "11001111", "00000000", "00000000", "00000000", "00000000"],  # row 9
    ["00000000", "00000000", "00000110", "00000111", "00000111", "00000111", "00000111", "00000111", "00001111", "10001011", "00000000", "00000000", "00000000", "00000000"],  # row 10
    ["00000000", "00000000", "11010100", "11001110", "10001110", "10001111", "10001111", "11001110", "11001000", "01000000", "00000000", "00000000", "00000000", "00000000"],  # row 11
    ["00000000", "00000000", "01010000", "01111000", "01111000", "01111000", "01111000", "01111000", "01000000", "00000000", "00000000", "00000000", "00000000", "00000000"],  # row 12
    ["00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000"],  # row 13
]

def flatten_pixels():
    """Flatten 28x28 pixels to 784-bit string"""
    flattened = ""
    for row in TEST_PIXELS_MNIST:
        flattened += row
    # Reverse for Verilog indexing (bit 0 is rightmost)
    return flattened[::-1]

def flatten_weights():
    """Flatten 3x3x8 weights to 72-bit string"""
    result = ['0'] * 72
    
    for r in range(3):
        for c in range(3):
            bits = TEST_WEIGHTS_MNIST[r][c]
            for w in range(8):
                idx = r * 24 + c * 8 + w
                result[idx] = bits[w]
    
    # Reverse for Verilog indexing
    return ''.join(result[::-1])

def flatten_expected_output():
    """Flatten 14x14x8 expected output to 1568-bit string"""
    result = ['0'] * 1568
    
    for r in range(14):
        for c in range(14):
            bits = EXPECTED_OUTPUT_MNIST[r][c]
            for w in range(8):
                idx = w * 196 + r * 14 + c
                result[idx] = bits[w]
    
    # Reverse for Verilog indexing
    return ''.join(result[::-1])

def generate_verilog_init():
    """Generate Verilog initialization code"""
    pixels_flat = flatten_pixels()
    weights_flat = flatten_weights()
    expected_flat = flatten_expected_output()
    
    print("// Flattened MNIST test data - copy into tb_layer_one_simple.sv")
    print("// " + "="*70)
    print()
    
    # Generate pixel initialization
    print("// Initialize MNIST pixels (784 bits)")
    print("TEST_PIXELS_MNIST = 784'b" + pixels_flat + ";")
    print()
    
    # Generate weight initialization
    print("// Initialize weights (72 bits)")
    print("TEST_WEIGHTS_MNIST = 72'b" + weights_flat + ";")
    print()
    
    # Generate expected output initialization
    print("// Initialize expected output (1568 bits)")
    print("EXPECTED_OUTPUT_MNIST = 1568'b" + expected_flat + ";")
    print()
    
    print("// " + "="*70)
    print(f"// Pixel bits: {len(pixels_flat)} (should be 784)")
    print(f"// Weight bits: {len(weights_flat)} (should be 72)")
    print(f"// Output bits: {len(expected_flat)} (should be 1568)")

if __name__ == "__main__":
    generate_verilog_init()
