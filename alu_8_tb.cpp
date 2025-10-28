#include "Valu_8_tb.h"
//#include "Valu_8.h"
#include "verilated.h"

int main(int argc, char** argv) {
    
    VerilatedContext *context = new VerilatedContext; // Context
    context->commandArgs(argc, argv);
    context->traceEverOn(true);
    Valu_8_tb* tb = new Valu_8_tb();
    context->traceEverOn(true);     // Turn on trace switch in context
    //Valu_8* tb = new Valu_8();
    while(!context->gotFinish()){
        tb->eval();
        context->timeInc(1);
    }
    delete tb;
    return 0;
}
