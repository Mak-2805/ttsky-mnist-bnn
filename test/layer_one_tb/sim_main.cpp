#include "Vtb_layer_one.h"
#include "verilated.h"
#include "verilated_fst_c.h"

int main(int argc, char** argv) {
    // Initialize Verilator
    Verilated::commandArgs(argc, argv);

    // Create instance of our module
    Vtb_layer_one* top = new Vtb_layer_one;

    // Initialize tracing
    Verilated::traceEverOn(true);
    VerilatedFstC* tfp = new VerilatedFstC;
    top->trace(tfp, 99);
    tfp->open("layer_one.fst");

    // Run simulation
    vluint64_t main_time = 0;
    while (!Verilated::gotFinish() && main_time < 1000000) {
        top->eval();
        tfp->dump(main_time);
        main_time++;
    }

    top->final();
    tfp->close();
    delete top;
    delete tfp;

    return 0;
}
