#include "Vcpu_8_tb.h"
#include "verilated.h"

int main(int argc, char** argv) {
    
    VerilatedContext *context = new VerilatedContext; // Context
    context->commandArgs(argc, argv);
    context->traceEverOn(true);
    Vcpu_8_tb* tb = new Vcpu_8_tb();
    context->traceEverOn(true);     // Turn on trace switch in context
    while(!context->gotFinish()){
        tb->eval();
        context->timeInc(1);
    }
    delete tb;
    return 0;
}
