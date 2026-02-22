# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
import numpy as np
import csv
import os
import struct

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
_HERE        = os.path.dirname(__file__)
WEIGHTS_DIR  = os.path.join(_HERE, '../src/Python311_training/weights')
TRAINING_DIR = os.path.join(_HERE, '../src/Python311_training/training_data')

# ---------------------------------------------------------------------------
# Data loaders
# ---------------------------------------------------------------------------

def load_csv(path):
    """Return a 2-D list of ints from a CSV file (one row per line)."""
    rows = []
    with open(path, newline='') as f:
        for line in csv.reader(f):
            rows.append([int(x) for x in line])
    return rows


def load_mnist_image(image_index=0):
    """Load a single binarised MNIST image from the .ubin file.

    The file uses the standard MNIST image format header
    (magic=2051, num_images, rows, cols) followed by packed bits
    (np.unpackbits-compatible).

    Returns a (28, 28) numpy array of 0/1 ints, row-major.
    """
    path = os.path.join(TRAINING_DIR, 'mnist_binary_verifying.ubin')
    with open(path, 'rb') as f:
        magic, size, rows, cols = struct.unpack(">IIII", f.read(16))
        if magic != 2051:
            raise ValueError(f"Unexpected image magic number: {magic}")
        raw  = np.frombuffer(f.read(), dtype=np.uint8)
        bits = np.unpackbits(raw)
        img  = bits[image_index * rows * cols : (image_index + 1) * rows * cols]
        return img.reshape(rows, cols).astype(int)


def load_label(image_index=0):
    """Load the label for one image from the labels .ubin file.

    Tries the standard MNIST label format (magic=2049, 8-byte header,
    then raw uint8 labels).  Falls back to treating the whole file as
    raw uint8 if the magic does not match.
    """
    path = os.path.join(TRAINING_DIR, 'mnist_binary_labels_verifying.ubin')
    with open(path, 'rb') as f:
        header       = f.read(8)
        magic, _size = struct.unpack(">II", header)
        if magic == 2049:
            labels = np.frombuffer(f.read(), dtype=np.uint8)
        else:
            f.seek(0)
            labels = np.frombuffer(f.read(), dtype=np.uint8)
        return int(labels[image_index])

# ---------------------------------------------------------------------------
# Serial bit-stream builders
# (order must match the capture sequence in registers.sv)
# ---------------------------------------------------------------------------

def build_pixel_stream(image):
    """784 bits: row 0-27 outer, col 0-27 inner.

    Captured by registers.sv as pixels[row*28 + col] with col
    incrementing first each clock cycle.
    """
    bits = []
    for row in range(28):
        for col in range(28):
            bits.append(int(image[row, col]))
    return bits          # length 784


def build_w1_stream(w1_csv):
    """72 bits for weights1 (8 filters x 3x3).

    registers.sv capture order:
      level (filter 0-7) slowest, trit (kr 0-2) middle, bitt (kc 0-2) fastest.
    Stored at: weights1[trit*24 + bitt*8 + level]

    w1_csv[filter][kr*3 + kc] is the weight value.
    """
    bits = []
    for level in range(8):        # filter
        for trit in range(3):     # kernel row
            for bitt in range(3): # kernel col
                bits.append(w1_csv[level][trit * 3 + bitt])
    return bits          # length 72


def build_w2_stream(w2_csv):
    """288 bits for weights2 (4 filters x 3x3x8).

    registers.sv capture order:
      level1 (filter 0-3) slowest, trit1 (kr), bitt1 (kc), chan1 (ch 0-7) fastest.
    Stored at: weights2[level1*72 + (trit1*3+bitt1)*8 + chan1]

    w2_csv[filter][j] where j = (kr*3+kc)*8 + ch, matching the CSV row layout.
    """
    bits = []
    for level1 in range(4):   # filter
        for j in range(72):   # (kr*3+kc)*8+ch in ascending order
            bits.append(w2_csv[level1][j])
    return bits          # length 288


def build_w3_stream(w3_csv):
    """1960 bits for weights3 (10 neurons x 196 inputs).

    registers.sv capture order:
      neuron_w3 (0-9) outer, bit_w3 (0-195) inner.
    Stored at: weights3[neuron*196 + bit]

    w3_csv[neuron][bit] is the weight value.
    """
    bits = []
    for neuron in range(10):
        for b in range(196):
            bits.append(w3_csv[neuron][b])
    return bits          # length 1960

# ---------------------------------------------------------------------------
# Main test
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_project(dut):
    dut._log.info("Loading weights and MNIST image")

    w1 = load_csv(os.path.join(WEIGHTS_DIR, 'layer_0_weights.csv'))  # 8  rows x 9
    w2 = load_csv(os.path.join(WEIGHTS_DIR, 'layer_3_weights.csv'))  # 4  rows x 72
    w3 = load_csv(os.path.join(WEIGHTS_DIR, 'layer_7_weights.csv'))  # 10 rows x 196

    image_index = 0
    image    = load_mnist_image(image_index)
    expected = load_label(image_index)
    dut._log.info(f"Image index {image_index}, expected label: {expected}")

    # Build serial bit streams
    pixel_bits  = build_pixel_stream(image)       # 784
    w1_bits     = build_w1_stream(w1)             # 72
    w2_bits     = build_w2_stream(w2)             # 288
    w3_bits     = build_w3_stream(w3)             # 1960
    weight_bits = w1_bits + w2_bits + w3_bits     # 2320 total

    assert len(pixel_bits)  == 784,  f"pixel stream length wrong: {len(pixel_bits)}"
    assert len(weight_bits) == 2320, f"weight stream length wrong: {len(weight_bits)}"

    # -----------------------------------------------------------------------
    # Clock: 10 us period (100 kHz)
    # -----------------------------------------------------------------------
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # -----------------------------------------------------------------------
    # Initialise inputs
    # -----------------------------------------------------------------------
    dut.ui_in.value  = 0
    dut.uio_in.value = 0
    dut.ena.value    = 1

    # -----------------------------------------------------------------------
    # Reset (active-low)
    # -----------------------------------------------------------------------
    dut._log.info("Reset")
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)   # allow reset_pipe synchroniser to settle

    # -----------------------------------------------------------------------
    # Enter LOAD state
    # ui_in[0]=mode=1 → FSM: s_IDLE → s_LOAD on the next posedge.
    # Registers do NOT capture this cycle (state is still s_IDLE at the posedge).
    # -----------------------------------------------------------------------
    dut._log.info("Asserting mode=1 to enter s_LOAD")
    dut.ui_in.value = 0b00000001   # mode=1, pixel=0, weight=0
    await ClockCycles(dut.clk, 1)  # FSM transitions to s_LOAD at this posedge

    # -----------------------------------------------------------------------
    # Stream 2320 cycles of data
    #
    # Pixel capture  (registers.sv): cycles 1-784 of s_LOAD
    # Weight capture (registers.sv):
    #   w1 (72 bits)    cycles   1-72
    #   w2 (288 bits)   cycles  73-360
    #   w3 (1960 bits)  cycles 361-2320
    #
    # After cycle 2320: w_done3 latches; load_done goes high at cycle 2321.
    # FSM transitions to s_LAYER_1 after cycle 2321.
    # -----------------------------------------------------------------------
    dut._log.info("Streaming pixel and weight data (2320 cycles)")
    N = len(weight_bits)   # 2320
    for i in range(N):
        p = pixel_bits[i] if i < len(pixel_bits) else 0
        w = weight_bits[i]
        # ui_in: bit2=weight, bit1=pixel, bit0=mode(keep=1 to stay in s_LOAD)
        dut.ui_in.value = (w << 2) | (p << 1) | 1
        await ClockCycles(dut.clk, 1)

    # Drop mode; FSM will have already left s_LOAD naturally via load_done
    dut.ui_in.value = 0

    # -----------------------------------------------------------------------
    # Wait for inference
    #   s_LAYER_1 : ~1570 cycles  (8 filters × 14×14 positions + overhead)
    #   s_LAYER_2 : ~198  cycles  (4 filters × 7×7  positions + overhead)
    #   s_LAYER_3 : ~2    cycles  (popcount latch + FSM sees layer_3_done)
    # 2000 cycles gives a comfortable margin over the ~1770-cycle total.
    # -----------------------------------------------------------------------
    dut._log.info("Waiting for inference to complete (~1770 cycles)")
    await ClockCycles(dut.clk, 2000)

    # -----------------------------------------------------------------------
    # Read result from uo_out[3:0]
    # -----------------------------------------------------------------------
    result = int(dut.uo_out.value) & 0xF
    dut._log.info(f"Expected digit: {expected}  |  Hardware result: {result}")
    assert result == expected, (
        f"MNIST classification mismatch: expected {expected}, got {result}"
    )
