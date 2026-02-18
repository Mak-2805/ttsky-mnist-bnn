# stop any simulation that is currently running
quit -sim

# create the default "work" library
vlib work;

# compile the Verilog source code in the parent folder
vlog -sv ./tb_flatten_layer_test.sv ./flatten_layer.sv

# start the Simulator, including some libraries that may be needed
vsim work.tb_final_layer_sequential
# show waveforms specified in wave.do
do wave.do
# advance the simulation the desired amount of time
run -all