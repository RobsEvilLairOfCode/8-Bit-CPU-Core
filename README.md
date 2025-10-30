#  8-bit Harvard-Style CPU

This project presents the design and SystemVerilog implementation of a custom 8-bit
CPU with Harvard architecture. The processor uses a compact 8-bit instruction set designed
to capture the core functionality of a general-purpose processor while operating within a
small instruction size. A program designed to calculate the Fibonacci sequence is included
to demonstrate the processor’s capabilities.

##Key features:
* 8-bit datapath
* Harvard architecture
* Custom instruction set architecture
* Fibonacci sequence demo via controller input
* Procedural, self-checking testbench with scoreboard.

##Documentation:
Please refer to CPU8_Report for instructions.

##Noteable files:
* CPU8_Report.pdf: Full report on CPU, including datapath diagram
* cpu8.sv: The top file of the CPU
* cpu8_tb.sv: Full testbench for the CPU
* sim_main: Fibinocci assembly implementation
* alu8_tb.sv Full testbench for the ALU

##Requirements
* Linux / WSL2
* Verilator
* GTKWave (optional)

##Run Fibinocci sequence:

<pre> ```bash
verilator --sv --build --cc -f filelist.f --exe sim_main.cpp --top-module cpu8 --trace

./obj_dir/Vcpu8

gtkwave cpu8_trace.vcd
''' <\pre>

##Run CPU testbench:

<pre> ```bash
verilator --sv --cc -f filelist.f --exe sim_main.cpp --build --top-module cpu8 --trace

./obj_dir/Vcpu8
''' <\pre>

##Run CPU testbench:

<pre> ```bash
verilator -Wall --sv   -Wno-PINCONNECTEMPTY   -Wno-EOFNEWLINE   -Wno-TIMESCALEMOD   -Wno-UNUSEDSIGNAL   --cc opcode_pkg.sv cpu8.sv cpu_8_tb.sv   --exe cpu_8_tb.cpp --build --trace --timing --top cpu_8_tb

./obj_dir/Vcpu_8_tb 
''' <\pre>