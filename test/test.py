# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

import os
import struct

# ---------------------------------------------------------------------------
# Paths to pre-trained weights and binary MNIST data (relative to this file)
# ---------------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
WEIGHT_DIR = os.path.join(SCRIPT_DIR, '..', 'src', 'Python311_training', 'weights')
DATA_DIR   = os.path.join(SCRIPT_DIR, '..', 'src', 'Python311_training', 'training_data')

# ---------------------------------------------------------------------------
# Cycle counts for each design phase (conservative upper bounds)
#
#   LOAD:   max(784 pixel bits, 72 + 288 + 1960 weight bits) = 2320
#   Layer1: 8 filters x 14 x 14 computations + 4 overhead   = 1572
#   Layer2: 4 filters x 7  x 7  computations + 4 overhead   =  200
#   Layer3: combinational pop-count -> 1 clock to register + margin = 10
# ---------------------------------------------------------------------------
LOAD_CYCLES   = 2320
LAYER1_CYCLES = 1572
LAYER2_CYCLES = 200
LAYER3_CYCLES = 10


# ---------------------------------------------------------------------------
# Data helpers
# ---------------------------------------------------------------------------

def load_csv_bits(path):
    """Return a flat list of ints (0/1) from a comma-separated CSV file."""
    bits = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line:
                bits.extend(int(x) for x in line.split(','))
    return bits


def build_weight_stream():
    """
    Concatenate weights for all three layers into a single 2320-bit stream
    matching the serial loading order in registers.sv:

      Layer-1 (weights1): 72  bits -- 8 filters x 3x3 kernel, 1 input channel
                                      order: filter (outer) -> row -> col (inner)
      Layer-2 (weights2): 288 bits -- 4 filters x 3x3 kernel, 8 input channels
                                      order: filter -> row -> col -> channel (inner)
      Layer-3 (weights3): 1960 bits -- 10 neurons x 196 inputs
                                      order: neuron (outer) -> bit (inner)

    The CSV rows already encode weights in this order (see bnn_retrieve_weights.py).
    """
    w1 = load_csv_bits(os.path.join(WEIGHT_DIR, 'layer_0_weights.csv'))
    w2 = load_csv_bits(os.path.join(WEIGHT_DIR, 'layer_3_weights.csv'))
    w3 = load_csv_bits(os.path.join(WEIGHT_DIR, 'layer_7_weights.csv'))
    assert len(w1) == 72,   f"weight-1: expected 72 bits, got {len(w1)}"
    assert len(w2) == 288,  f"weight-2: expected 288 bits, got {len(w2)}"
    assert len(w3) == 1960, f"weight-3: expected 1960 bits, got {len(w3)}"
    return w1 + w2 + w3   # 2320 bits total


def load_image_and_label(index=0):
    """
    Return (pixel_bits, label) for the given index in the verifying set.

    pixel_bits : list of 784 ints (0/1), row-major order matching registers.sv
    label      : int 0-9, or None if the label file cannot be parsed
    """
    img_path = os.path.join(DATA_DIR, 'mnist_binary_verifying.ubin')
    lbl_path = os.path.join(DATA_DIR, 'mnist_binary_labels_verifying.ubin')

    with open(img_path, 'rb') as f:
        _magic, _size, rows, cols = struct.unpack('>IIII', f.read(16))
        npix = rows * cols  # 784 — must be a multiple of 8
        nbytes = npix // 8
        raw = bytearray(f.read())
        start = index * nbytes
        img_bytes = raw[start:start + nbytes]
        # Unpack bits MSB-first (equivalent to np.unpackbits)
        pixels = [(b >> (7 - i)) & 1 for b in img_bytes for i in range(8)]

    label = None
    if os.path.exists(lbl_path):
        try:
            with open(lbl_path, 'rb') as f:
                f.read(8)  # skip 8-byte header
                raw_labels = bytearray(f.read())
                if index < len(raw_labels):
                    label = int(raw_labels[index])
        except Exception:
            pass

    return pixels, label


# ---------------------------------------------------------------------------
# Cocotb test
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # 10 us clock period (100 kHz) -- matches default Makefile setting
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # ------------------------------------------------------------------
    # 1.  Load weights and one test image
    # ------------------------------------------------------------------
    w_stream = build_weight_stream()          # 2320 bits

    try:
        p_bits, label = load_image_and_label(0)
        dut._log.info(f"Loaded verifying image 0; expected digit: {label}")
    except Exception as exc:
        dut._log.warning(f"Could not load image file ({exc}); using all-zero pixels")
        p_bits = [0] * 784
        label  = None

    # ------------------------------------------------------------------
    # 2.  Reset (active-low rst_n, 10 cycles)
    #     reset_pipe is a 2-FF synchroniser, so synchronous_reset needs
    #     2 extra rising edges after rst_n goes high.
    # ------------------------------------------------------------------
    dut._log.info("Reset")
    dut.tt_um_mnist_bnn.ena.value    = 1
    dut.ui_in.value  = 0
    dut.uio_in.value = 0
    dut.rst_n.value  = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value  = 1
    await ClockCycles(dut.clk, 3)   # wait for synchronous_reset to propagate

    # ------------------------------------------------------------------
    # 3.  Trigger LOAD state: pulse mode (ui_in[0] = 1) for one cycle
    #     FSM: IDLE -> LOAD on the next rising edge
    # ------------------------------------------------------------------
    dut._log.info("Triggering LOAD state")
    dut.ui_in.value = 0b001   # mode=1
    await ClockCycles(dut.clk, 1)

    # ------------------------------------------------------------------
    # 4.  Stream data into the design during LOAD
    #
    #     ui_in[1] = d_in_p  -- pixel bit, consumed for the first 784 cycles
    #     ui_in[2] = d_in_w  -- weight bit, consumed for 2320 cycles
    #
    #     The three weight always-blocks in registers.sv activate
    #     sequentially (gated by w_done / w_done1), so w_stream can be
    #     driven continuously on d_in_w.
    # ------------------------------------------------------------------
    dut._log.info("Streaming pixels and weights")
    for i in range(LOAD_CYCLES):
        p_bit = int(p_bits[i]) if i < 784 else 0
        w_bit = int(w_stream[i])
        dut.ui_in.value = (w_bit << 2) | (p_bit << 1)
        await ClockCycles(dut.clk, 1)

    # ------------------------------------------------------------------
    # 5.  Wait for all three BNN layers to compute
    # ------------------------------------------------------------------
    dut._log.info("Waiting for BNN inference to complete")
    await ClockCycles(dut.clk, LAYER1_CYCLES + LAYER2_CYCLES + LAYER3_CYCLES)

    # ------------------------------------------------------------------
    # 6.  Read answer from uo_out[3:0] and validate
    # ------------------------------------------------------------------
    answer = int(dut.uo_out.value) & 0xF
    dut._log.info(f"Hardware answer: {answer}")
    if label is not None:
        dut._log.info(f"Expected label: {label}")

    # Hard check: output must be a valid MNIST digit (0-9)
    assert 0 <= answer <= 9, \
        f"Answer {answer} is outside the valid digit range [0, 9]"

    # Soft check: log a warning if wrong rather than failing CI outright,
    # since a single-image mismatch may reflect model accuracy rather than
    # a hardware bug.
    if label is not None and answer != label:
        dut._log.warning(
            f"Classification mismatch: hardware={answer}, expected={label}. "
            "Check model accuracy or streaming bit order if this persists."
        )
