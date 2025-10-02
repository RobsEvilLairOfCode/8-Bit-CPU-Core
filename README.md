Commands to run:

verilator --sv --build --cc -f filelist.f --exe sim_main.cpp --top-module cpu8 --trace

./obj_dir/Vcpu8

gtkwave cpu8_trace.vcd
