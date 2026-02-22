#!/usr/bin/env python3
"""
gen_real_mnist_images.py
Loads real MNIST images from the binary training data and generates
multiple test cases for the BNN testbench.

Usage:
    python3 gen_real_mnist_images.py [indices...]
    
    indices: Space-separated list of MNIST image indices to test (default: 0 1)
    Example: python3 gen_real_mnist_images.py 0 5 10 15 20
"""

import struct
import numpy as np
import csv
import os
import sys

# ---------------------------------------------------------------------------
# Paths (relative to this script's location)
# ---------------------------------------------------------------------------
HERE        = os.path.dirname(os.path.abspath(__file__))
MNIST_DIR   = os.path.join(HERE, 'MNIST_data_gen')
DATA_DIR    = os.path.join(HERE, '../../src/Python311_training/training_data')
WEIGHTS_DIR = os.path.join(HERE, '../../src/Python311_training/weights')

IMAGES_PATH = os.path.join(DATA_DIR, 'mnist_binary_verifying.ubin')
LABELS_PATH = os.path.join(DATA_DIR, 'mnist_binary_labels_verifying.ubin')

# ---------------------------------------------------------------------------
# Load MNIST binary data
# ---------------------------------------------------------------------------
def load_mnist_images(filepath):
    """Load MNIST images from binary file (.ubin format)."""
    with open(filepath, 'rb') as file:
        magic, size, rows, cols = struct.unpack(">IIII", file.read(16))
        if magic != 2051:
            raise ValueError(f"Magic number incorrect, should be 2051, was {magic}")
        
        # Read packed binary data
        image_data = np.frombuffer(file.read(), dtype=np.uint8)
        # Unpack bits
        image_data = np.unpackbits(image_data)
        # Reshape to individual images
        num_images = size
        image_data = image_data[:num_images * rows * cols]
        images = image_data.reshape(num_images, rows, cols)
        
        return images, size, rows, cols

def load_mnist_labels(filepath):
    """Load MNIST labels from binary file."""
    with open(filepath, 'rb') as file:
        magic, size = struct.unpack(">II", file.read(8))
        if magic != 2049:
            raise ValueError(f"Magic number incorrect for labels, should be 2049, was {magic}")
        
        labels = np.frombuffer(file.read(), dtype=np.uint8)
        return labels

# ---------------------------------------------------------------------------
# Weight stream builders (must match registers.sv capture order)
# ---------------------------------------------------------------------------

def load_csv(path):
    rows = []
    with open(path, newline='') as f:
        for line in csv.reader(f):
            rows.append([int(x) for x in line])
    return rows

def build_w1(w1_csv):
    """72 bits: level(0-7) outer, trit(0-2), bitt(0-2) inner."""
    bits = []
    for level in range(8):
        for trit in range(3):
            for bitt in range(3):
                bits.append(w1_csv[level][trit*3 + bitt])
    return bits

def build_w2(w2_csv):
    """288 bits: level1(0-3) outer, j(0-71) inner [=(kr*3+kc)*8+ch]."""
    bits = []
    for level1 in range(4):
        for j in range(72):
            bits.append(w2_csv[level1][j])
    return bits

def build_w3(w3_csv):
    """1960 bits: neuron(0-9) outer, bit(0-195) inner."""
    bits = []
    for neuron in range(10):
        for b in range(196):
            bits.append(w3_csv[neuron][b])
    return bits

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    # Parse command line arguments for image indices
    if len(sys.argv) > 1:
        indices = [int(x) for x in sys.argv[1:]]
    else:
        indices = list(range(100))  # Default: test first 100 images
    
    # Load MNIST data
    print(f"Loading MNIST data from {IMAGES_PATH}...")
    images, num_images, rows, cols = load_mnist_images(IMAGES_PATH)
    labels = load_mnist_labels(LABELS_PATH)
    
    print(f"Loaded {num_images} images of size {rows}x{cols}")
    print(f"Will generate test cases for indices: {indices}")
    
    # Validate indices
    for idx in indices:
        if idx < 0 or idx >= num_images:
            print(f"ERROR: Index {idx} out of range [0, {num_images-1}]")
            return
    
    # Load weights (same for all images)
    print("Loading trained weights...")
    w1 = load_csv(os.path.join(WEIGHTS_DIR, 'layer_0_weights.csv'))
    w2 = load_csv(os.path.join(WEIGHTS_DIR, 'layer_3_weights.csv'))
    w3 = load_csv(os.path.join(WEIGHTS_DIR, 'layer_7_weights.csv'))
    
    weight_bits = build_w1(w1) + build_w2(w2) + build_w3(w3)
    assert len(weight_bits) == 2320, f"Expected 2320 weight bits, got {len(weight_bits)}"
    
    # Write weights.mem (same for all tests)
    weights_file = os.path.join(HERE, 'weights.mem')
    with open(weights_file, 'w') as f:
        for b in weight_bits:
            f.write(f"{b}\n")
    print(f"Written {weights_file} ({len(weight_bits)} bits)")
    
    # Write test configuration file with image indices and labels (HEX format for $readmemh)
    config_file = os.path.join(HERE, 'test_config.mem')
    with open(config_file, 'w') as f:
        f.write(f"{len(indices):X}\n")  # Number of test images in HEX
        for idx in indices:
            f.write(f"{idx:X} {labels[idx]:X}\n")  # index and expected label in HEX
    print(f"Written {config_file}")
    
    # Ensure output directory exists
    os.makedirs(MNIST_DIR, exist_ok=True)

    # Write individual pixel memory files for each image
    for i, idx in enumerate(indices):
        image = images[idx]
        label = labels[idx]

        # Print ASCII preview
        print(f"\nTest image {i}: MNIST index {idx}, label={label}")
        print("Image preview (# = white, . = black):")
        print("+" + "-"*28 + "+")
        for row in image:
            print("|" + "".join("#" if p else "." for p in row) + "|")
        print("+" + "-"*28 + "+")

        # Flatten to bit stream (row-major order)
        pixel_bits = image.flatten().tolist()
        assert len(pixel_bits) == 784, f"Expected 784 pixels, got {len(pixel_bits)}"

        # Write pixels_N.mem file into MNIST_data_gen/
        pixel_file = os.path.join(MNIST_DIR, f'pixels_{i}.mem')
        with open(pixel_file, 'w') as f:
            for b in pixel_bits:
                f.write(f"{b}\n")
        print(f"Written {pixel_file} ({len(pixel_bits)} bits)")
    
    print(f"\n{'='*60}")
    print(f"Generated {len(indices)} test cases from real MNIST images!")
    print(f"Ready to simulate with updated testbench.")
    print(f"{'='*60}\n")

if __name__ == '__main__':
    main()