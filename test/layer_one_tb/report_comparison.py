#!/usr/bin/env python3
"""
Produce a human-readable comparison report:
  - Visualize each MNIST input image
  - Show expected output (trained model) as 14x14 grid per kernel
  - Show hardware output from simulation (read from VCD or run inline)
  - Highlight any mismatches

Usage:
  python3 report_comparison.py [num_images] > comparison_report.txt
"""

import numpy as np
import struct
import sys
import subprocess
import os

WEIGHTS_PATH = "../../src/Python311_training/weights/layer_0_weights.mem"
THRESH_PATH  = "../../src/Python311_training/weights/layer_1_thresholds.mem"
IMAGES_PATH  = "../../src/Python311_training/training_data/mnist_binary_verifying.ubin"
LABELS_PATH  = "../../src/Python311_training/training_data/mnist_binary_labels_verifying.ubin"

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
                                pval = 0 if (pr_pos < 0 or pr_pos >= 28 or pc_pos < 0 or pc_pos >= 28) else int(pixels[pr_pos, pc_pos])
                                if pval == weights[k, kr, kc]:
                                    matches += 1
                        if matches >= thresh:
                            max_val = 1
                output[k, r, c] = max_val
    return output

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

def verilog_to_output(flat_str):
    """Convert 1568-bit Verilog string back to 8x14x14 array"""
    # flat_str is MSB-first (Verilog bit literal), so reverse it to index from 0
    arr = flat_str[::-1]
    output = np.zeros((8, 14, 14), dtype=int)
    for k in range(8):
        for r in range(14):
            for c in range(14):
                idx = k * 196 + r * 14 + c
                output[k, r, c] = int(arr[idx])
    return output

# ---- Run one simulation inline via iverilog -------------------------
def run_hw_simulation(pixels, weights, expected):
    """Write a tiny one-shot testbench, compile, run, capture output bit string."""
    w_flat = weights_to_verilog(weights)
    p_flat = pixels_to_verilog(pixels)
    e_flat = output_to_verilog(expected)

    sv = f"""`timescale 1ns/1ps
module tb_one;
    reg clk=0, rst_n=0;
    reg [2:0] state=0;
    reg  [783:0]  pixels  = 784'b{p_flat};
    reg  [71:0]   weights = 72'b{w_flat};
    wire [1567:0] layer_one_out;
    wire done;
    layer_one dut(.clk(clk),.rst_n(rst_n),.state(state),
                  .pixels(pixels),.weights(weights),
                  .layer_one_out(layer_one_out),.done(done));
    initial begin clk=0; forever #5 clk=~clk; end
    initial begin
        #20; rst_n=1;
        #20; state=3'b010;
        wait(done==1); #50;
        $display("HW_OUT=%b", layer_one_out);
        $finish;
    end
    initial begin #50000000; $display("TIMEOUT"); $finish; end
endmodule
"""
    with open("/tmp/tb_one.sv", "w") as f:
        f.write(sv)

    os.system("iverilog -g2012 -o /tmp/sim_one.vvp ../../src/layer_one.sv /tmp/tb_one.sv 2>/dev/null")
    result = subprocess.run(
        ["vvp", "/tmp/sim_one.vvp"],
        capture_output=True, text=True,
        env={**os.environ, "LD_LIBRARY_PATH": "/home/jiali102/lib:" + os.environ.get("LD_LIBRARY_PATH", "")}
    )
    for line in result.stdout.splitlines():
        if line.startswith("HW_OUT="):
            return line[len("HW_OUT="):]
    return None

# ---- Pretty print ----------------------------------------------------
def print_grid(label, grid14x14, mismatch=None):
    """Print a 14x14 binary grid with optional mismatch highlight."""
    print(f"  {label}:")
    for r in range(14):
        row = ""
        for c in range(14):
            bit = grid14x14[r, c]
            if mismatch is not None and mismatch[r, c]:
                row += "X"   # mismatch marker
            else:
                row += "#" if bit else "."
        print(f"    {row}")

def print_image(pixels28x28):
    for r in range(28):
        print("  " + "".join("#" if pixels28x28[r, c] else " " for c in range(28)))

# ---- Main ------------------------------------------------------------
weights    = load_weights()
thresholds = load_thresholds()
images     = load_images()
labels     = load_labels()

print("=" * 70)
print("LAYER ONE: Hardware vs Trained Model — Comparison Report")
print("=" * 70)
print(f"Weights source : layer_0_weights.mem (actual trained weights)")
print(f"Threshold src  : layer_1_thresholds.mem (actual batch-norm thresholds)")
print(f"Image source   : mnist_binary_verifying.ubin (real MNIST test set)")
print(f"Images tested  : {NUM_IMAGES}")
print()
print("Kernel thresholds:", thresholds)
print("Kernels (3x3, row-major):")
for k in range(8):
    print(f"  kernel {k} (threshold={thresholds[k]}): {weights[k].flatten().tolist()}")
print()

total_checks = 0
total_errors = 0

for i in range(NUM_IMAGES):
    pixels   = images[i]
    label    = int(labels[i])
    expected = run_layer_one(pixels, weights, thresholds)

    print("=" * 70)
    print(f"Image {i:3d}  |  True label: {label}")
    print("=" * 70)

    print("  Input image (28x28):")
    print_image(pixels)
    print()

    # Run hardware simulation
    hw_flat = run_hw_simulation(pixels, weights, expected)
    if hw_flat is None:
        print("  ERROR: Hardware simulation failed!")
        continue
    hw_output = verilog_to_output(hw_flat)

    # Per-kernel comparison
    image_errors = 0
    for k in range(8):
        mismatch = (expected[k] != hw_output[k])
        num_mm = int(np.sum(mismatch))
        image_errors += num_mm
        total_errors += num_mm
        total_checks += 196

        status = "PASS" if num_mm == 0 else f"FAIL ({num_mm} mismatches)"
        print(f"  Kernel {k} (threshold={thresholds[k]})  {status}")

        if num_mm > 0:
            print_grid("Expected (trained model)", expected[k], mismatch=None)
            print_grid("Hardware output         ", hw_output[k], mismatch=None)
            print_grid("Difference (X=mismatch) ", expected[k], mismatch=mismatch)
        else:
            print_grid("Output (matches trained model)", expected[k])
        print()

    result_str = "PASS" if image_errors == 0 else f"FAIL — {image_errors} mismatches"
    print(f"  Image {i} result: {result_str}")
    print()

print("=" * 70)
print("SUMMARY")
print("=" * 70)
print(f"  Images tested : {NUM_IMAGES}")
print(f"  Total checks  : {total_checks}  ({NUM_IMAGES} images × 8 kernels × 196 outputs)")
print(f"  Total errors  : {total_errors}")
if total_errors == 0:
    print(f"  Result        : ALL PASS — hardware matches trained model exactly")
else:
    print(f"  Result        : FAIL — {total_errors}/{total_checks} bits wrong")
print("=" * 70)
