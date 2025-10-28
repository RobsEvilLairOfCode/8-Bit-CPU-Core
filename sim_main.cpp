#include "Vcpu8.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include <iostream>
#include <sstream>
#include <string>
#include <vector>
#include <unordered_map>
#include <cctype>
#include <stdexcept>

// ---------------------
// Opcodes (adjust to ISA)
// ---------------------
enum Opcode {
    ADD   = 0b0000,
    ADDI  = 0b0001,
    SUB   = 0b0010,
    SUBI  = 0b0011,
    AND   = 0b0100,
    OR    = 0b0101,
    XOR   = 0b0110,
    NOT   = 0b0111,
    LSL   = 0b1000,
    LSR   = 0b1001,
    LDUR  = 0b1010,
    STOR  = 0b1011,
    CMP   = 0b1100,
    B     = 0b1101,
    MOV1  = 0b1110,
    MOV2  = 0b1111
};

// ---------------------
// Instruction encoders
// ---------------------
int makeNOP() { return 0x00; } // all-zeros stall

int makeALUOP(Opcode opcode, int rd, int ra, int rb) {
    return (opcode << 4) | ((rd & 0b1) << 3) | ((ra & 0b1) << 2) | (rb & 0b11);
}

int makeLOAD(int reg, int addr) {
    return (LDUR << 4) | ((reg & 0x3) << 2) | (addr & 0x3);
}

int makeSTOR(int rAddr, int addr) {
    return (STOR << 4) | ((rAddr & 0x3) << 2) | (addr & 0x3);
}

int makeB(int condition, int reg_w_addr) {
    return (B << 4) | ((condition & 0x3) << 2) | (reg_w_addr & 0x3);
}

int makeCMP(int op1, int op2) {
    return (CMP << 4) | ((op1 & 0x3) << 2) | (op2 & 0x3);
}

int makeMOV1(int rd) {
    return (MOV1 << 4) | ((rd & 0x7) << 1);
}

int makeMOV2(int rs) {
    return (MOV2 << 4) | ((rs & 0x7) << 1);
}

// ---------------------
// Parser helpers
// ---------------------
static std::unordered_map<std::string, Opcode> opcodeMap = {
    {"ADD", ADD}, {"ADDI", ADDI}, {"SUB", SUB}, {"SUBI", SUBI},
    {"AND", AND}, {"OR", OR}, {"XOR", XOR}, {"NOT", NOT},
    {"LSL", LSL}, {"LSR", LSR}, {"LDUR", LDUR}, {"STOR", STOR},
    {"CMP", CMP}, {"B", B}, {"MOV1", MOV1}, {"MOV2", MOV2},
    {"NOP", (Opcode)-1}
};

int assemble(const std::string& line) {
    std::istringstream iss(line);
    std::string mnemonic;
    iss >> mnemonic;

    // Uppercase normalization
    for (auto& c : mnemonic) c = std::toupper(c);

    if (opcodeMap.find(mnemonic) == opcodeMap.end())
        throw std::runtime_error("Unknown instruction: " + mnemonic);

    Opcode opc = opcodeMap[mnemonic];

    if (mnemonic == "NOP") {
        return makeNOP();
    }
    else if (mnemonic == "ADD" || mnemonic == "ADDI" || mnemonic == "SUB" || mnemonic == "SUBI" ||
             mnemonic == "AND" || mnemonic == "OR" || mnemonic == "XOR" || mnemonic == "NOT"|| mnemonic == "LSL"|| mnemonic == "LSR") {
        int rd, ra, rb;
        iss >> rd >> ra >> rb;
        return makeALUOP(opc, rd, ra, rb);
    }
    else if (mnemonic == "LDUR") {
        int reg, addr;
        iss >> reg >> addr;
        return makeLOAD(reg, addr);
    }
    else if (mnemonic == "STOR") {
        int reg, addr;
        iss >> reg >> addr;
        return makeSTOR(reg, addr);
    }
    else if (mnemonic == "B") {
        int cond, addr;
        iss >> cond >> addr;
        return makeB(cond, addr);
    }
    else if (mnemonic == "CMP") {
        int r1, r2;
        iss >> r1 >> r2;
        return makeCMP(r1, r2);
    }
    else if (mnemonic == "MOV1") {
        int rd;
        iss >> rd;
        return makeMOV1(rd);
    }
    else if (mnemonic == "MOV2") {
        int rs;
        iss >> rs;
        return makeMOV2(rs);
    }

    throw std::runtime_error("Assembler: unsupported mnemonic " + mnemonic);
}

// ---------------------
// Verilator clock helper
// ---------------------
void tick(Vcpu8* top, vluint64_t& main_time, VerilatedVcdC* tfp) {
    top->clk = 1;
    top->eval();
    if (tfp) tfp->dump(main_time);
    main_time++;

    top->clk = 0;
    top->eval();
    if (tfp) tfp->dump(main_time);
    main_time++;
}

// ---------------------
// Main testbench
// ---------------------
int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    vluint64_t main_time = 0;
    Verilated::traceEverOn(true);

    Vcpu8* top = new Vcpu8;

    // VCD tracing
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("cpu8_trace.vcd");

    /*
    def fibonacci(N):
    a = 0        # First Fibonacci number
    b = 1        # Second Fibonacci number
    
    print(a)     # Output first number
    if N > 1:
        print(b) # Output second number
    
    for i in range(2, N):
        c = a + b
        print(c) # Output next number
        a = b
        b = c
    */
    // Example assembly program
    //Register 0: XZR
    //Register 1: operand of Fibinacci Sequence
    //Register 2: operand/result of the Fibinacci Sequence
    //Register 3: operand/result of the Fibinacci Sequence
    //Register 4: Counter for Loop 
    //Register 5: Counter for Memory (Values of registers 3 and 4 will swap from time to time)
    //Register 6: Address for Loop
    //Register 7: Temp register for switching values 
    std::vector<std::string> assembly = {
        //Step 1: Store the address that will be used to branch in the loop
        "ADDI 0 0 3", //Adds 3 to register 2
        "ADDI 1 0 3", //Adds 3 to register 3
        "MOV1 1", 
        "MOV2 2", //Moves Value of register 2 to register 1
        "LSL 0 1 3",//Shifts 3 by 3, putting 24 in register 2
        "MOV1 1", 
        "MOV2 2", //Moves Value of register 2 to register 1
        "ADDI 0 1 2",
        "MOV1 6",
        "MOV2 2",//Puts the address 26 in Register 6

        //Step 2: Create first numbers in memory
        "ADDI 0 0 1", //SETS 1 to register 2
        "STOR 2 2",//Stores the value of 1 at memory addr 1 since 0 and 1 are default in the sequence
        "ADDI 0 0 2",//SETS 2 to register 2 
        "MOV1 5",
        "MOV2 2",//Move the value 1 to register 4 as it will be used to count the mem addresses

        //Step 3: calculate the Loop bound
        "ADDI 0 0 1",//SETS One to Register 2...
        "ADDI 1 0 3",//SETS three to register 3...
        //Move to Register 1
        "MOV1 1",
        "MOV2 2",//Move the 1 from register 2 to register 1
        "LSL 0 1 3",//Shift it 3 (from register 3) times so that it becomes 8 (We will find up to the 10th number if the fib sequence, doesnt count first two), which is stored in reg 3
        "MOV1 4",
        "MOV2 2",//Move that value to register 4

        //Step 4: prepare registers 1 and 2 for fibinocci sequence
        //We need to make registers 2 and 1 contain 1 and zero respectively
        "ADDI 0 0 0", //Write the value 0 to register 2
        "MOV1 1",
        "MOV2 2",// Move that Zero to register 1
 
        "ADDI 0 0 1", //Put 1 in register 2

        //At this point Reg 1 = 0, Reg 2 = 1, Reg 3 = 8
        
        //Step 5: Fibinaci sequence Loop
        //The next instruction will be instruction 26, the calculated beginning of the loop
        //Calculate C
        "ADD 1 1 2",//Add registers one and two and put it in register three
        "MOV1 1",
        "MOV2 5",//Move memory counter to overwrite oldest
        "STOR 3 1",//Store New number at addres in register 1
        "MOV1 7",
        "MOV2 2",//Move operand in register 2 out of the way
        "ADDI 0 1 1",//Add one to the address
        "MOV1 5",
        "MOV2 2",//Move memory counter to register 5
        "MOV1 2",
        "MOV2 7",//Move operand back to registe 2
        "MOV1 1",
        "MOV2 4",//Move loop counter to register 1
        "MOV1 7",
        "MOV2 3", //move new number out of the way
        "SUBI 1 1 1",//subtract 1 from loop counter and move it to 3
        "CMP 3 0", //compare loop counter to zero (sets flag for later)
        "MOV1 4",
        "MOV2 3",//Move update loop counter back to register 4
        "MOV1 1",
        "MOV2 2",//mves smallest number to register 1
        "MOV1 2",
        "MOV2 7", //Moves larger number to register 2
        "B 2 2" // Branch to beginning of loop if loop counter is greater than 0 (2 goes to register 6)
    };

    // Assemble into machine code
    std::vector<int> program;
    for (auto& line : assembly) {
        try {
            program.push_back(assemble(line));
        } catch (const std::exception& e) {
            std::cerr << "Error: " << e.what() << " in line: " << line << "\n";
        }
    }

    // --- Reset CPU ---
    top->rst = 1;
    top->service_mode = 1; // CPU halted, memory writable
    top->program_memory_rst = 1;
    top->program_memory_write_enable = 0;
    tick(top, main_time, tfp);

    top->rst = 0;
    top->program_memory_rst = 0;

    // --- Load program memory ---
    for (size_t addr = 0; addr < program.size(); addr++) {
        top->program_memory_address = addr;
        top->program_memory_data_in = program[addr];
        top->program_memory_write_enable = 1;
        tick(top, main_time, tfp);
    }
    top->program_memory_write_enable = 0;

    // --- Switch to run mode ---
    top->service_mode = 0;

    // --- Run CPU for some cycles ---
    for (int cycle = 0; cycle < 256; cycle++) {
        tick(top, main_time, tfp);
    }

    //Read data memory
    top->service_mode = 1;
    for (int cycle = 0; cycle < 16; cycle++) {
        tick(top, main_time, tfp);
        top->data_memory_address = cycle;
        std::cout << "Cycle " << cycle
                  << " DataMemOut=0x"
                  << std::hex << (int)top->data_memory_data_out << std::dec
                  << std::endl;
    }


    tfp->close();
    delete tfp;
    delete top;
    return 0;
}
