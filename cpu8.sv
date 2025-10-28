`timescale 1ns/1ps

module cpu8(
    input clk,
    input rst,
    input service_mode,
    input register_rst,
    input [7:0] program_memory_data_in,
    input [7:0] program_memory_address,
    input program_memory_rst,
    input program_memory_write_enable,
    input [7:0] data_memory_data_in,
    input [7:0] data_memory_address,
    input data_memory_rst,
    input data_memory_write_enable,
    output logic [7:0] data_memory_data_out
);
//constant low and high signals
/* verilator lint_off UNUSED */
logic low, high;
/* verilator lint_on UNUSED */
always_comb begin
    low = 1'b0;
    high = 1'b1;
end

//The two data outputs for the register file that
//will hook up to the ALU, comparator, MOV logic, and data memory
logic [7:0] register_file_data_out_1, register_file_data_out_2;


logic [7:0] pc_outbound_address, pc_incremented_address, pc_inbound_address;
logic [7:0] program_memory_address_after_service_mux;

//Setting service mode to high will stall the CPU, but allow the memory to be readable
logic cpu_enable = ~service_mode;
program_counter pc(
    .clk(clk),
    .rst(rst),
    .write_enable(cpu_enable),
    .data_in(pc_inbound_address),
    .data_out(pc_outbound_address)
);

program_counter_adder pc_adder(
    .A(pc_outbound_address),
    .Y(pc_incremented_address)
);

//Instruction fetched from the program memory for the current clock cycle
logic [7:0] current_cycle_instruction = 8'b0;
memory_array_256x8 program_memory(
    .clk(clk),
    .rst(program_memory_rst),
    .write_enable(program_memory_write_enable),
    .address(program_memory_address_after_service_mux),
    .data_in(program_memory_data_in),
    .data_out(current_cycle_instruction)
);

//2 to 1 MUX behind the program counter
logic do_branch;
//TODO: Attach the wires from data_out_1 and the control logic from CU6(branch logic)
always_comb begin
    pc_inbound_address = (do_branch) ?  register_file_data_out_1 : pc_incremented_address;
end

//2 to 1 MUX for the select whether the address is source from the program counter or the top module.
always_comb begin
    program_memory_address_after_service_mux = (service_mode) ? program_memory_address : pc_outbound_address;
end

//Register File Control


//Mux controlled by Control Unit 8
logic [7:0] alu_to_register_file_data_in = 8'b0;
logic [7:0] data_memory_to_register_file_data_in;
logic [7:0] data_in_mux_to_register_file = 8'b0;
register_file_data_in_logic data_in_logic(
    .instruction(current_cycle_instruction),
    .ALU(alu_to_register_file_data_in),
    .MOV(register_file_data_out_1),
    .LDUR(data_memory_to_register_file_data_in),
    .data_in(data_in_mux_to_register_file)
);

//wiring from the mov logic control (7)
logic mov_write_enable = 1'b0;
logic [2:0] mov_write_select = 3'b0;
logic [2:0] mov_read_select = 3'b0;
//wiring from write/read control module for register file
logic register_file_write_enable;
logic [2:0] register_file_write_select;
logic [2:0] register_file_read_select_1;
logic [2:0] register_file_read_select_2;
register_file_read_write_logic register_file_RW_logic(
    .instruction(current_cycle_instruction),
    .enabled(cpu_enable),
    .mov_write_enable(mov_write_enable),
    .mov_write_select(mov_write_select),
    .mov_read_select(mov_read_select),
    .write_enable(register_file_write_enable),
    .write_select(register_file_write_select),
    .read_select_1(register_file_read_select_1),
    .read_select_2(register_file_read_select_2)
);
//Register File

register_file_8 register_file(
    .clk(clk),
    .rst(register_rst),
    .write_enable(register_file_write_enable),
    .write_select(register_file_write_select),
    .read_select_1(register_file_read_select_1),
    .read_select_2(register_file_read_select_2),
    .data_in(data_in_mux_to_register_file),
    .data_out_1(register_file_data_out_1),
    .data_out_2(register_file_data_out_2)
);

//ALU Control
logic [2:0] alu_opcode = 3'b0;

//High if substract instruction, zero otherwise
logic alu_cin;
//B can either come from the regsiter file or the instruction itself depending on what the instruction is
logic [7:0] alu_B_input;

alu_opcode_logic alu_logic(
    .instruction(current_cycle_instruction),
    .alu_opcode(alu_opcode)
);
//Mux that controls C_in, depends on if the ALU OPCODE
always_comb begin
    alu_cin = (alu_opcode == 3'b001);
end

//Mux that determines what the source of ALU B will be depending on the current instruction
always_comb begin
    case (current_cycle_instruction [7:4])
        4'b0001,
        4'b0011:alu_B_input = {6'b0,current_cycle_instruction [1:0]};
        default:alu_B_input = register_file_data_out_2;
    endcase
end

//ALU
alu_8 #(.WIDTH(8)) alu(
    .A(register_file_data_out_1),
    .B(alu_B_input),
    .OP(alu_opcode),
    .C_in(alu_cin),
    .EN(cpu_enable),
    .update_flags(low),
    .Y(alu_to_register_file_data_in),
    .C_out(),//Leave Unconnected
    .Z(),//Leave Unconnected
    .N(),//Leave Unconnected
    .V() //Leave Unconnected
);


//Data Memory Control
logic data_memory_write_enable_internal;
cpu_memory_write_enable_logic data_memory_write_enable_logic(
    .instruction(current_cycle_instruction),
    .write_enable(data_memory_write_enable_internal)
);
//Data Memory
logic data_memory_write_enable_after_service_mux;
logic [7:0] data_memory_address_after_service_mux;
logic [7:0] data_memory_data_in_after_service_mux;
logic [7:0] data_memory_data_out_before_service_mux;
memory_array_256x8 data_memory(
    .clk(clk),
    .rst(data_memory_rst),
    .write_enable(data_memory_write_enable_after_service_mux),
    .address(data_memory_address_after_service_mux),
    .data_in(data_memory_data_in_after_service_mux),
    .data_out(data_memory_data_out_before_service_mux)
);

//Data Memory Service Muxes

always_comb begin
    data_memory_write_enable_after_service_mux = (service_mode) ? data_memory_write_enable : data_memory_write_enable_internal;
    data_memory_address_after_service_mux = (service_mode) ? data_memory_address : register_file_data_out_1;
    data_memory_data_in_after_service_mux = (service_mode) ? data_memory_data_in : register_file_data_out_2;

    //data out demux
    data_memory_data_out = (service_mode) ? data_memory_data_out_before_service_mux : 8'b0;

    data_memory_to_register_file_data_in = (service_mode) ? 8'b0 : data_memory_data_out_before_service_mux;
end

//Compare
//outputs of the comparator
logic comparator_greater_than,comparator_less_than,comparator_equal_to;

//comparator for compare function
comparator_8 comparator(
    .A(register_file_data_out_1),
    .B(register_file_data_out_2),
    .LT(comparator_less_than),
    .EQ(comparator_equal_to),
    .GT(comparator_greater_than)
);


logic [7:0] comparator_conctination_output;

//concatinates the output of the comparator so that it can be stored in an eight bit register
comparator_concatination comparator_concatinator(
    .LT(comparator_less_than),
    .EQ(comparator_equal_to),
    .GT(comparator_greater_than),
    .concatinated_output(comparator_conctination_output)
);

logic compare_flag_register_write_enable;
//Enables the compare flag register when 
compare_flag_register_enable_logic compare_flag_register_logic(
    .instruction(current_cycle_instruction),
    .write_enable(compare_flag_register_write_enable)
);

logic [7:0] compare_flag_register_output;
//The register that holds the flags when compare is used
register_module compare_flag_register(
    .clk(clk),
    .rst(rst),
    .write_enable(compare_flag_register_write_enable),
    .data_in(comparator_conctination_output),
    .data_out(compare_flag_register_output)
);

branch_logic branch_logic(
    .instruction(current_cycle_instruction),
    .compare_flag(compare_flag_register_output),
    .do_branch(do_branch)
);

//Move

mov_logic mov_logic(
    .clk(clk),
    .rst(rst),
    .enabled(cpu_enable),
    .instruction(current_cycle_instruction),
    .write_enable(mov_write_enable),//Connects to Control Two
    .write_select(mov_write_select),//Connects to Control Two
    .read_select(mov_read_select) //Conntects to Control Two

);
endmodule
