# Makefile
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

clean::
#rm -rf build *.vcd *.fst *.xml simulation_results/
#rm -rf obj_dir *.fst *.vcd *.log
#rm -f $(VVP) *.fst *.vcd *.log
#rm -f $(VVP_SIMPLE) $(VVP_DIGITS) *.fst *.vcd *.log
#rm -f sim_layer_two.vvp layer_two.vcd tb_layer_two.sv
#rm -f $(VVP) *.fst *.vcd *.log
#rm -rf obj_dir *.fst *.vcd *.log
	rm -rf layer_one_tb/*.vvp*
	rm -rf layer_two_tb/*.vvp*
	rm -rf top_test_tb/*.vvp*
	rm -rf top_test_tb/*.vcd*
#rm -f top_test_tb/*.mem*

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
SRC_DIR = $(PWD)/../src
PROJECT_SOURCES = tt_um_mnist_bnn.v fsm.sv registers.sv layer_one.sv layer_two.sv flatten_layer.sv pipe.sv reset_pipe.sv


ifneq ($(GATES),yes)

# RTL simulation:
SIM_BUILD				= sim_build/rtl
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))

else

# Gate level simulation:
SIM_BUILD				= sim_build/gl
COMPILE_ARGS    += -DGL_TEST
COMPILE_ARGS    += -DFUNCTIONAL
COMPILE_ARGS    += -DUSE_POWER_PINS
COMPILE_ARGS    += -DSIM
COMPILE_ARGS    += -DUNIT_DELAY=\#1
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v

# this gets copied in by the GDS action workflow
VERILOG_SOURCES += $(PWD)/gate_level_netlist.v

endif

# Enable SystemVerilog (always_ff, always_comb, logic, enum, etc.)
COMPILE_ARGS		+= -g2012

# Allow sharing configuration between design and testbench via `include`:
COMPILE_ARGS 		+= -I$(SRC_DIR)

# Include the testbench sources:
VERILOG_SOURCES += $(PWD)/tb.v
TOPLEVEL = tb

# List test modules to run, separated by commas and without the .py suffix:
COCOTB_TEST_MODULES = test

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
