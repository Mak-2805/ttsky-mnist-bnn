# Layer One Testbench

Verification environment for the `layer_one` module - the first convolutional layer of the MNIST Binary CNN design.

## Module Overview

**layer_one.sv** implements:
1. **Binary Convolution**: 3x3 convolution with 8 different binary kernels
2. **Batch Normalization**: XNOR matching with threshold comparison
3. **Max Pooling**: 2x2 max pooling with stride 2

**Transformation**: 28×28 input → 8 feature maps of 14×14 output

## Files

- `tb_layer_one.sv` - SystemVerilog testbench with parameterized test vectors
- `DEPS.yml` - Dependency configuration
- `Makefile.verilator` - Makefile for Verilator simulation
- `Makefile.iverilog` - Makefile for Icarus Verilog simulation

## Test Architecture

The testbench includes:
- **Parameterized test vectors** for easy modification
- **Golden reference model** for automatic output verification
- **Multiple test cases**: Checkerboard, all-zeros, all-ones patterns
- **State control verification**: Tests IDLE vs LAYER_1 state behavior
- **Comprehensive logging** with detailed error reporting

## Running Simulations

### Option 1: Verilator (Recommended)

**Install:**
```bash
sudo apt-get install verilator gtkwave
```

**Run:**
```bash
make -f Makefile.verilator all
```

**View waveforms:**
```bash
make -f Makefile.verilator view
```

### Option 2: Icarus Verilog

**Install:**
```bash
sudo apt-get install iverilog gtkwave
```

**Run:**
```bash
make -f Makefile.iverilog all
```

**View waveforms:**
```bash
make -f Makefile.iverilog view
```

## Customizing Test Vectors

Edit the parameters at the top of `tb_layer_one.sv`:

### Input Pixels (28×28 binary array)

```systemverilog
parameter logic [27:0][27:0] TEST_PIXELS_1 = {
    28'b0101010101010101010101010101,  // row 0
    28'b1010101010101010101010101010,  // row 1
    // ... 26 more rows
};
```

### Weights (8 kernels of 3×3)

```systemverilog
// Format: [row][col][weight_num]
// Each element is 8 bits representing weights 0-7
parameter logic [2:0][2:0][7:0] TEST_WEIGHTS = '{
    '{8'b10110001, 8'b01011110, 8'b10110001},  // row 0
    '{8'b11010101, 8'b00101010, 8'b11010101},  // row 1
    '{8'b10110001, 8'b01011110, 8'b10110001}   // row 2
};
```

**Weight indexing:**
- Bit 0 of each 8-bit value = weight kernel 0
- Bit 1 = weight kernel 1
- ...
- Bit 7 = weight kernel 7

### Expected Outputs

The testbench automatically computes expected outputs using a golden reference model. You don't need to manually specify expected values!

## Test Cases Included

1. **Checkerboard Pattern** - Tests alternating binary patterns
2. **All Zeros** - Tests minimum activation case
3. **All Ones** - Tests maximum activation case
4. **State Control** - Verifies processing only occurs in LAYER_1 state

## Expected Output

```
TEST START
==============================================
Layer One Testbench - Binary CNN First Layer
==============================================

Module Specifications:
- Input: 28x28 binary pixels
- Weights: 8 sets of 3x3 binary kernels
- Output: 8 feature maps of 14x14
- Operations: Convolution + Batch Norm + Max Pooling
==============================================

==============================================
Running Test: Checkerboard Pattern
==============================================
LOG: ... : INFO : tb_layer_one : Applying reset
LOG: ... : INFO : tb_layer_one : Processing completed in XXXX cycles
LOG: ... : INFO : tb_layer_one : Weight 0 output verified successfully
...
LOG: ... : INFO : tb_layer_one : All outputs match expected values!

...

==============================================
Test Summary:
==============================================
Total Tests: XX
Errors:      0

*** TEST PASSED ***
All XX checks passed!
==============================================
```

## Understanding the Operations

### 1. Binary Convolution

For each 3×3 window:
```
XNOR operation: ~(pixel XOR weight)
Match count: $countones(XNOR result)
```

### 2. Batch Normalization

```
Threshold = 5 + (weight_num & 1)
  - Even weight nums (0,2,4,6): threshold = 5
  - Odd weight nums (1,3,5,7): threshold = 6

Output = 1 if (match_count >= threshold)
```

### 3. Max Pooling (2×2, stride 2)

```
For each 2×2 window in 28×28:
  Output = OR of 4 positions
  
28×28 → 14×14 reduction
```

## Debugging Tips

**View internal signals in GTKWave:**
```bash
gtkwave layer_one.fst
```

**Key signals to observe:**
- `tb_layer_one.clk` - Clock
- `tb_layer_one.rst_n` - Reset
- `tb_layer_one.state` - FSM state
- `tb_layer_one.dut.row` - Current row being processed
- `tb_layer_one.dut.col` - Current column being processed
- `tb_layer_one.dut.weight_num` - Current weight kernel (0-7)
- `tb_layer_one.done` - Processing complete flag
- `tb_layer_one.layer_one_out` - Output feature maps

**Common Issues:**

1. **Simulation timeout** - Check if module is stuck in a state
2. **Mismatches in output** - Verify weight indexing and pixel formatting
3. **Done signal not asserting** - Ensure state is set to s_LAYER_1

## Performance Metrics

**Expected cycles:**
- Processing: 8 weights × 14 rows × 14 cols = 1,568 cycles
- Total with overhead: ~1,600 cycles

## Integration with Cognichip Platform

Run cloud simulations using the root `DEPS.yml`:

```bash
# In Cognichip interface, select target:
layer_one_test
```

Results stored automatically in `simulation_results/`.

## Cleaning Up

```bash
# For Verilator
make -f Makefile.verilator clean

# For Icarus Verilog
make -f Makefile.iverilog clean
```

## Next Steps

After verifying layer_one:
1. Test with actual MNIST image data
2. Integrate with layer_two verification
3. Test full pipeline with FSM control
