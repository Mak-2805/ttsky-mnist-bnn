# FSM Testbench

Verification environment for the FSM (Finite State Machine) module used in the MNIST Binary CNN design.

## Files

- `tb_fsm.sv` - SystemVerilog testbench
- `DEPS.yml` - Dependency configuration
- `Makefile.verilator` - Makefile for Verilator simulation
- `Makefile.iverilog` - Makefile for Icarus Verilog simulation
- `test.py` - Cocotb testbench (Python-based)
- `Makefile` - Cocotb Makefile (if using Cocotb)

## Running Simulations

### Option 1: Verilator (Recommended)

**Why Verilator?**
- Fast simulation
- Same tool used by Cognichip platform
- Best SystemVerilog support
- Industry-standard

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

**Why Icarus Verilog?**
- Simple and lightweight
- Easy to install
- Good for quick simulations

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

### Option 3: Cocotb (Python)

**Why Cocotb?**
- Write testbenches in Python
- Easy to integrate with existing Python code
- Good for complex test scenarios

**Install:**
```bash
pip install cocotb cocotb-test
```

**Run:**
```bash
make  # Uses existing Cocotb Makefile
```

## Quick Start

**Simplest way to run:**
```bash
# If you have Verilator installed
make -f Makefile.verilator

# Or if you have Icarus Verilog
make -f Makefile.iverilog

# View results
gtkwave fsm.fst
```

## Test Coverage

The testbench verifies:
1. ✅ Reset functionality
2. ✅ IDLE state holding (mode=0)
3. ✅ State transitions (IDLE→LOAD→LAYER_1→LAYER_2→LAYER_3→IDLE)
4. ✅ State holding in each state until done signal
5. ✅ Multiple complete cycles
6. ✅ Fast back-to-back transitions

**All 18 test checks included**

## Expected Results

```
TEST START
==============================================
FSM Testbench - Binary CNN State Machine
==============================================

[TEST 1] Testing Reset Functionality
...
[TEST 13] Fast State Sequence

==============================================
Test Summary:
==============================================
Total Tests: 18
Errors:      0

*** TEST PASSED ***
All 18 state checks passed!
==============================================
```

## Waveform Viewing

The simulation generates `fsm.fst` waveform file.

**View with GTKWave:**
```bash
gtkwave fsm.fst
```

**Signals to observe:**
- `tb_fsm.clk` - Clock
- `tb_fsm.rst_n` - Active-low reset
- `tb_fsm.mode` - Mode control
- `tb_fsm.dut.cs` - Current state (displays enum names!)
- `tb_fsm.dut.ns` - Next state (displays enum names!)
- `tb_fsm.state` - Output state (displays enum names!)
- `tb_fsm.*_done` - Done signals from each layer

**State values:**
- `s_IDLE` = 0
- `s_LOAD` = 1
- `s_LAYER_1` = 2
- `s_LAYER_2` = 3
- `s_LAYER_3` = 4

## Troubleshooting

**Error: `verilator: command not found`**
- Install Verilator: `sudo apt-get install verilator`

**Error: `iverilog: command not found`**
- Install Icarus Verilog: `sudo apt-get install iverilog`

**Error: Can't view waveforms**
- Install GTKWave: `sudo apt-get install gtkwave`

**Simulation runs but no waveforms**
- Check that `$dumpfile()` and `$dumpvars()` are in the testbench
- Look for `fsm.fst` file in the current directory

## Cleaning Up

```bash
# For Verilator
make -f Makefile.verilator clean

# For Icarus Verilog
make -f Makefile.iverilog clean
```

## Integration with Cognichip Platform

The root `DEPS.yml` file is used by the Cognichip platform for cloud simulation:
```yaml
fsm_test:
  deps:
    - src/fsm.sv
    - test/fsm_tb/tb_fsm.sv
  top: tb_fsm
```

This allows running simulations through the Cognichip interface with automatic result storage in `simulation_results/`.
