`timescale 1ns/1ps

module cpu_8_tb;

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------
   localparam int MAX_MEMORY_ADDR = 256; //The size of both the program and memory address modules is 256 words.
   localparam int MAX_RUNS = 1000; //Determine the amount of runs that is conducted for random stimulus testing
// ---------------------------------------------------------------------------
// Enums and Typdefs
// ---------------------------------------------------------------------------
import opcode_pkg::*;

//--------------------------------------------------------------
// Type: cmp_t
// Description:
//    Used for determining the meaning of the concatinated 
//    comparator output.
//--------------------------------------------------------------
typedef enum logic [7:0] {
        CMP_LT = 8'b0001, //a high LSB indicates a less than.
        CMP_EQ  = 8'b0010, //a high second bit indicates an equal
        CMP_GT  = 8'b0100 //a high third bit indicates a greater than
} cmp_t;

//--------------------------------------------------------------
// Type: instruction_stack_t
// Description:
//    A represetation of program_memory that holds 256 8-bit 
//    words of instructions. Can declare many instruction stacks
//    and swap them in and out after reseting the cpu while
//    retaining what is in data memory. Print using print_instruction_stack();
//--------------------------------------------------------------
typedef struct {
    logic [7:0] instructions[MAX_MEMORY_ADDR];//The instruction memory allows for 256 8-bit instructions.
    int num_instructions; //Indicates the amount of instructions in the stack for upper loop bounds and appending of further instructions
    string name; //A name for the instruction stack for identification when printing.
} instruction_stack_t;

//--------------------------------------------------------------
// Type: data_stack_t
// Description:
//    A represetation of data_memory that holds 256 8-bit 
//    words of data. Can declare many data stacks
//    and swap them in and out. Print using print_data_memory_capture().
//--------------------------------------------------------------
typedef struct {
    logic [7:0] data[MAX_MEMORY_ADDR];//The data memory allows for 256 words.
    string name; //A name for the data stack for identification when printing.
} data_stack_t;

//--------------------------------------------------------------
// Type: cpu_instance_t
// Description:
//    A represetation of a cpu for software level simulation.
//--------------------------------------------------------------
typedef struct {
    logic [7:0] data_memory[MAX_MEMORY_ADDR]; //Behavioral model of the data memory module.
    logic [7:0] register_file[8]; //Behavioral model of the register file, which is hardcoded to hold eight words.
    logic [7:0] compare_register; //Behavioral model of the compare register, used for CMP and BR instructions.
    logic [7:0] last_instruction;//Holds the previous instruction, which is used for the MOV instructions.
    logic [7:0] branch_to; //Contains the address where a branch is targeted to
    bit do_branch;//Indicates to the simulation code that a BR initiated branching for that clock cycle.
} cpu_instance_t;

//--------------------------------------------------------------
// Type: scorebooard_t
// Description:
//    A type for tracking successful and unsuccessful runs of 
//    bulk random stimulus tests. The instructions of successful
//    and unsuccessful runs are recorded in the respective arrays.
//    The scoreboard can be printed using print_scoreboard().
//    Due to a Verilator limitation, instructions from instructions_stacks
//    must be entered as arrays instead of the custom data type.
//--------------------------------------------------------------
typedef struct {
logic [7:0] successful_instructions[MAX_RUNS][MAX_MEMORY_ADDR]; //Contains a configureable amount of successful instructions stacks
logic [7:0] unsuccessful_instructions[MAX_RUNS][MAX_MEMORY_ADDR];//Contain a configureable amount of unsuccessful instruction stacks
int successful_runs_counter; //Tracks of the amount of successful runs. 
int unsuccessful_runs_counter;//Tracks the amount of unsuccessful runs.
} scoreboard_t;

// ---------------------------------------------------------------------------
// Random Seeding
// ---------------------------------------------------------------------------

int seed = 32'hFEEDFACE; //Default Seed

initial begin
    if($value$plusargs("seed=%d",seed)) $urandom(seed);//Get seed from command line
    $display("Using random seed: %0d",seed);//Display the seed to the user.
end

// ---------------------------------------------------------------------------
// DUT Interface Signals
// 
// Inputs and outputs for cpu instance, used for the real-hardware implementation
// of the cpu (cpu_8.sv).
//
// Inputs:
//  clk - The constant clock signal for the cpu
//  rst - A reset signal for everything except for the registers, program, and data memory modules
//  register_rst - Exclusively resets the register file registers to zero
//  service_mode - If high, suspends all CPU operations so that data and instructions can be safely transfered.
//
//  **The following inputs require a high service mode signal use.
//  program_memory_data_in - Can be used to insert instructions into the program memory module externally.
//  program_memory_address - Specifies the 8-bit address for the instructions from program_memory_data_in.
//  program_memory_rst - When high, resets program_memory to zero in a single clock cycle. (Not realistic as discussed in memorry_array_256x8.sv)
//  program_memorty_write_enable - When high, the program memory can be written to **from external sources**.
//  data_memory_data_in - Can be used to insert data into the data memory module externally.
//  data_memory_address - Specifies the 8-bit address for the data from data_memory_data_in.
//  data_memory_rst - When high, resets data_memory to zero in a single clock cycle.
//  data_memorty_write_enable - When high, the dat memory can be written to **from external sources**.
//
//  Outputs:
//  data_memory_data_out - retrieves 8-bit words from data memory at the address specified by data_memory_address.
//
// ---------------------------------------------------------------------------
logic clk, rst, register_rst, service_mode;
logic [7:0] program_memory_data_in, program_memory_address, data_memory_data_in, data_memory_address;
logic  program_memory_rst, program_memory_write_enable, data_memory_rst, data_memory_write_enable;

logic [7:0] data_memory_data_out;

// ---------------------------------------------------------------------------
// DUT Instance
// ---------------------------------------------------------------------------
cpu8 cpu(
    .clk(clk),
    .rst(rst),
    .register_rst(register_rst),
    .service_mode(service_mode),
    .program_memory_data_in(program_memory_data_in),
    .program_memory_address(program_memory_address),
    .program_memory_rst(program_memory_rst),
    .program_memory_write_enable(program_memory_write_enable),
    .data_memory_data_in(data_memory_data_in),
    .data_memory_address(data_memory_address),
    .data_memory_rst(data_memory_rst),
    .data_memory_write_enable(data_memory_write_enable),
    .data_memory_data_out(data_memory_data_out)
);

// ---------------------------------------------------------------------------
// Scoreboard Function
// ---------------------------------------------------------------------------

//--------------------------------------------------------------
// Task: randomize_instructions
// Purpose:
//    Returns a given instructions stack with a given number of
//    randomized instructions appended to the existing instructions.
//    Used in random stimulus testing to generate randomized instruction
//    stacks.
//
// Arguments:
//    instruction_stack - Instructions stack to write to.
//    num_instructions - The number of instructions to generate.
//
// Notes:
//    The last insturction will always be a NOP as the previous instructions
//    write-back phase will need another clock cycle to complete.
//--------------------------------------------------------------
task automatic randomize_instructions(
    inout instruction_stack_t instruction_stack,
    input int num_instructions = 2
);
    int i;
    int random_num;
    if(instruction_stack.num_instructions + num_instructions > MAX_MEMORY_ADDR) $error("New instructions will surpass max memory addr (%d + %d)",instruction_stack.num_instructions , num_instructions);
    for(i = instruction_stack.num_instructions; i < num_instructions-1; i++) begin
        random_num = $urandom_range(0,255);
        if((random_num >> 4) < 16) begin //checks the opcode, increase threshold to 16 when all instructions are added
            insert_instruction(opcode_t'(random_num >> 4), 4'(random_num),instruction_stack);
        end else begin
            insert_instruction(OPCODE_ADD,4'b0000,instruction_stack);//DEFAULT: Do nothing
        end
    end
    insert_instruction(OPCODE_ADD,4'b0000,instruction_stack);//Last instruction must be a NOP so previous instruction can write to register.
endtask

//--------------------------------------------------------------
// Task: simluate
// Purpose:
//    Simulates, in manner of high-level software functions, the
//    executation of an instruction stack on a CPU instance. 
//
// Arguments:
//    instruction_stack - Instructions executed in this run.
//    cpu_instance      - Reference CPU model instance.
//    timeout_cycles    - Number of instructions until timeout.
//
// Notes:
//    Timeout avoids being stuck in infinite branch loops. It can
//    be set to a number greater than MAX_MEMORY_ADDR.
//--------------------------------------------------------------
task automatic simulate(
    input instruction_stack_t instruction_stack,
    inout cpu_instance_t cpu_instance,
    input int timeout_cycles = 256,
    input bit debug = 0;
);
    int i;
    int timer = 0;
    for(i = 0; i <= instruction_stack.num_instructions; i++) begin
        logic [7:0] instruction = instruction_stack.instructions[i];
        logic [3:0] opcode = instruction[7:4];
        logic [3:0] operands = instruction[3:0];


        int dest = int'(operands[3]) + 2;
        int source_1 = int'(operands[2]);
        int source_2 = int'(operands[1:0]);
        int immediate = int'(operands[1:0]);
        int load_store_source_dest = int'(operands[3:2]);
        int load_store_addr = int'(operands[1:0]);
        int compare_a = int'(operands[3:2]);
        int compare_b = int'(operands[1:0]);
        int mov_src_dest = int'(operands[3:1]);
        timer++;

        case (opcode)
            OPCODE_ADD:add_sim(dest,source_1,source_2, cpu_instance);
            OPCODE_ADDI:addi_sim(dest,source_1,immediate, cpu_instance);
            OPCODE_SUB:sub_sim(dest,source_1,source_2, cpu_instance);
            OPCODE_SUBI:subi_sim(dest,source_1,immediate, cpu_instance);
            OPCODE_AND:and_sim(dest,source_1,source_2, cpu_instance);
            OPCODE_OR:or_sim(dest,source_1,source_2, cpu_instance);
            OPCODE_XOR:xor_sim(dest,source_1,source_2, cpu_instance);
            OPCODE_NOT:not_sim(dest,source_1,cpu_instance);
            OPCODE_LSL:lsl_sim(dest,source_1,source_2, cpu_instance);
            OPCODE_LSR:lsr_sim(dest,source_1,source_2, cpu_instance);
            OPCODE_LDUR:load_sim(load_store_source_dest,load_store_addr,cpu_instance);
            OPCODE_STUR:store_sim(load_store_source_dest,load_store_addr,cpu_instance);
            OPCODE_CMP:compare_sim(compare_a,compare_b,cpu_instance);
            OPCODE_BR:branch_sim(compare_a,compare_b + 4,cpu_instance);
            OPCODE_MOV1:move1_sim(mov_src_dest,cpu_instance);
            OPCODE_MOV2:move2_sim(mov_src_dest,cpu_instance);
            default: begin
                $error("The instruction %b has no simulation implementation yet",instruction);
            end
        endcase
        //set register zero back to zero
        cpu_instance.register_file[0] = 8'b0;

        //if a branch is queued, then branch, and set the branch and set the branch address back to zero
        if(cpu_instance.do_branch) begin
            i = int'(cpu_instance.branch_to) - 1;
            cpu_instance.do_branch = 0;
        end

        //Transfer the current isntruction into the last instruction
        cpu_instance.last_instruction = instruction;

        //If debug is true, print the step by step cpu_instance information
        if(debug) print_cpu_instance(cpu_instance);

        //if timed out, stop execution
        if(timer == timeout_cycles) return;
    end
endtask


//--------------------------------------------------------------
// Task: check
// Purpose:
//    Compares the data and registers and data memory contents of
//    the hardware and software implementations of the cpu to ensure
//    contents are equal and records results on the given scoreboard. 
//
// Arguments:
//    instruction_stack - Instructions that is passed to the score function
//    cpu_instance - Simulated CPU instance to compare
//    scoreboard - Scoreboard for scoring runs in bulk.
//
// Notes:
//    Should be called after executing on hardware (execute_for_cycles)
//    and software (simulate)). Will use hardware cpu data memory and
//    registers to complete.
//    
//--------------------------------------------------------------
task automatic check(
    input instruction_stack_t instruction_stack,
    input cpu_instance_t cpu_instance,
    inout scoreboard_t scoreboard
);

     int check_i;
     data_stack_t check_data_stack;
     bit check_success;
     instruction_stack_t check_temp_inst;
    check_success = 1;
      check_data_stack.name = "real stack";

     //First check data memory
      capture_data_memory(check_data_stack);
      for (check_i = 0; check_i < MAX_MEMORY_ADDR; check_i++) begin
          if (check_data_stack.data[check_i] !== cpu_instance.data_memory[check_i]) begin
               $display("%s failed data memory check: got %h, simulated %h at addr %0d",
                        instruction_stack.name,
                        check_data_stack.data[check_i],
                        cpu_instance.data_memory[check_i],
                        check_i);
              check_success = 0;
          end
      end


    //Clear previous instructions and move register contents to data memory
     clear_program_memory();
     check_temp_inst.num_instructions = 0;
     check_temp_inst.name = "register transfer";
     reset_driver();
     transfer_registers_to_data_memory(check_temp_inst);
     instruction_driver(check_temp_inst);
     execute_for_cycles(check_temp_inst.num_instructions);

    //Then check register file contents in data memory
     capture_data_memory(check_data_stack);
     for (check_i = 1; check_i < 8; check_i++) begin
         if (check_data_stack.data[check_i - 1] !== cpu_instance.register_file[check_i]) begin
               $display("%s failed register check: got %h, simulated %h at reg %0d",
                       instruction_stack.name,
                       check_data_stack.data[check_i - 1],
                       cpu_instance.register_file[check_i],
                       check_i);
             check_success = 0;
         end
     end
   
      score(check_success, instruction_stack,scoreboard);    
 endtask

//--------------------------------------------------------------
// Task: score
// Purpose:
//    Inserts a run into the scoreboard given either that it is
//    deemed successful or unsuccessful.
//
// Arguments:
//    success - High if run is successful, low if run is unsuccessful
//    instruction_stack - Instructions of the run to store in the scoreboard
//    scoreboard - the scoreboard that the run will be inserted in
//    
//
// Notes:
//    While the successful instruction stacks are kept, they are
//    not printed by default in print_scoreboard().
//    
//--------------------------------------------------------------
task automatic score(
    input bit success,
    input instruction_stack_t instruction_stack, 
    inout scoreboard_t scoreboard
);
    if(success) begin //Instructions did not fail
        foreach (instruction_stack.instructions[i]) begin
            scoreboard.successful_instructions[scoreboard.successful_runs_counter][i] = instruction_stack.instructions[i];
        end
         scoreboard.successful_runs_counter++;  
    end else begin
        foreach (instruction_stack.instructions[i]) begin
            scoreboard.unsuccessful_instructions[scoreboard.unsuccessful_runs_counter][i] = instruction_stack.instructions[i];
        end
         scoreboard.unsuccessful_runs_counter++;
    end
endtask


//--------------------------------------------------------------
// Simulation Functions
// Purpose:
//    Simulates instructions in a cpu_instance using a
//    software-level implementation.
//
// Arguments:
//    operands(vary per instruction) - The operands of the instruction.
//    cpu_instance - An instance of the cpu to simulate on.
//    
// Notes:
//    All numerical inputs are ints with bit width boundaries
//    enforced by assertions.
//    
//--------------------------------------------------------------

task automatic add_sim(
    input int destination_reg, // can only be 2 or 3
    input int source_reg_1,    // can only be 0 or 1
    input int source_reg_2,    // can only be 0 to 3
    inout cpu_instance_t cpu_instance // instance of the CPU
);

    if (!(destination_reg inside {2, 3})) begin
        $error("add_sim(): destination_reg=%0d is invalid. Must be 2 or 3.", destination_reg);
        return;
    end
    if (!(source_reg_1 inside {0, 1})) begin
        $error("add_sim(): source_reg_1=%0d is invalid. Must be 0 or 1.", source_reg_1);
        return;
    end
    if (!(source_reg_2 inside {[0:3]})) begin
        $error("add_sim(): source_reg_2=%0d is invalid. Must be between 0 and 3.", source_reg_2);
        return;
    end
    if (destination_reg == 2 & source_reg_1 == 0 & source_reg_2 == 0)begin //Special NOP instruction
        //Do nothing
    end else begin
        cpu_instance.register_file[destination_reg] = 8'(cpu_instance.register_file[source_reg_1] + cpu_instance.register_file[source_reg_2]);
    end
endtask

task automatic addi_sim(
    input int destination_reg, // can only be 2 or 3
    input int source_reg_1,    // can only be 0 or 1
    input int immediate,    // can only be 0 to 3
    inout cpu_instance_t cpu_instance // instance of the CPU
);

    if (!(destination_reg inside {2, 3})) begin
        $error("addi_sim(): destination_reg=%0d is invalid. Must be 2 or 3.", destination_reg);
        return;
    end
    if (!(source_reg_1 inside {0, 1})) begin
        $error("addi_sim(): source_reg_1=%0d is invalid. Must be 0 or 1.", source_reg_1);
        return;
    end
    if (!(immediate inside {[0:3]})) begin
        $error("addi_sim(): immediate=%0d is invalid. Must be between 0 and 3.", immediate);
        return;
    end

    cpu_instance.register_file[destination_reg] = 8'(cpu_instance.register_file[source_reg_1] + 8'(immediate));
endtask

task automatic sub_sim(
    input int destination_reg, // can only be 2 or 3
    input int source_reg_1,    // can only be 0 or 1
    input int source_reg_2,    // can only be 0 to 3
    inout cpu_instance_t cpu_instance // instance of the CPU
);

    if (!(destination_reg inside {2, 3})) begin
        $error("sub_sim(): destination_reg=%0d is invalid. Must be 2 or 3.", destination_reg);
        return;
    end
    if (!(source_reg_1 inside {0, 1})) begin
        $error("sub_sim(): source_reg_1=%0d is invalid. Must be 0 or 1.", source_reg_1);
        return;
    end
    if (!(source_reg_2 inside {[0:3]})) begin
        $error("sub_sim(): source_reg_2=%0d is invalid. Must be between 0 and 3.", source_reg_2);
        return;
    end

    cpu_instance.register_file[destination_reg] = 8'(cpu_instance.register_file[source_reg_1] - cpu_instance.register_file[source_reg_2]);
endtask

task automatic subi_sim(
    input int destination_reg, // can only be 2 or 3
    input int source_reg_1,    // can only be 0 or 1
    input int immediate,    // can only be 0 to 3
    inout cpu_instance_t cpu_instance // instance of the CPU
);

    if (!(destination_reg inside {2, 3})) begin
        $error("subi_sim(): destination_reg=%0d is invalid. Must be 2 or 3.", destination_reg);
        return;
    end
    if (!(source_reg_1 inside {0, 1})) begin
        $error("subi_sim(): source_reg_1=%0d is invalid. Must be 0 or 1.", source_reg_1);
        return;
    end
    if (!(immediate inside {[0:3]})) begin
        $error("subi_sim(): immediate=%0d is invalid. Must be between 0 and 3.", immediate);
        return;
    end

    cpu_instance.register_file[destination_reg] = 8'(cpu_instance.register_file[source_reg_1] - 8'(immediate));
endtask

task automatic and_sim(
    input int destination_reg, // can only be 2 or 3
    input int source_reg_1,    // can only be 0 or 1
    input int source_reg_2,    // can only be 0 to 3
    inout cpu_instance_t cpu_instance // instance of the CPU
);

    if (!(destination_reg inside {2, 3})) begin
        $error("and_sim(): destination_reg=%0d is invalid. Must be 2 or 3.", destination_reg);
        return;
    end
    if (!(source_reg_1 inside {0, 1})) begin
        $error("and_sim(): source_reg_1=%0d is invalid. Must be 0 or 1.", source_reg_1);
        return;
    end
    if (!(source_reg_2 inside {[0:3]})) begin
        $error("and_sim(): source_reg_2=%0d is invalid. Must be between 0 and 3.", source_reg_2);
        return;
    end

    cpu_instance.register_file[destination_reg] = 8'(cpu_instance.register_file[source_reg_1] & cpu_instance.register_file[source_reg_2]);
endtask

task automatic or_sim(
    input int destination_reg, // can only be 2 or 3
    input int source_reg_1,    // can only be 0 or 1
    input int source_reg_2,    // can only be 0 to 3
    inout cpu_instance_t cpu_instance // instance of the CPU
);

    if (!(destination_reg inside {2, 3})) begin
        $error("or_sim(): destination_reg=%0d is invalid. Must be 2 or 3.", destination_reg);
        return;
    end
    if (!(source_reg_1 inside {0, 1})) begin
        $error("or_sim(): source_reg_1=%0d is invalid. Must be 0 or 1.", source_reg_1);
        return;
    end
    if (!(source_reg_2 inside {[0:3]})) begin
        $error("or_sim(): source_reg_2=%0d is invalid. Must be between 0 and 3.", source_reg_2);
        return;
    end

    cpu_instance.register_file[destination_reg] = 8'(cpu_instance.register_file[source_reg_1] | cpu_instance.register_file[source_reg_2]);
endtask

task automatic xor_sim(
    input int destination_reg, // can only be 2 or 3
    input int source_reg_1,    // can only be 0 or 1
    input int source_reg_2,    // can only be 0 to 3
    inout cpu_instance_t cpu_instance // instance of the CPU
);

    if (!(destination_reg inside {2, 3})) begin
        $error("xor_sim(): destination_reg=%0d is invalid. Must be 2 or 3.", destination_reg);
        return;
    end
    if (!(source_reg_1 inside {0, 1})) begin
        $error("xor_sim(): source_reg_1=%0d is invalid. Must be 0 or 1.", source_reg_1);
        return;
    end
    if (!(source_reg_2 inside {[0:3]})) begin
        $error("xor_sim(): source_reg_2=%0d is invalid. Must be between 0 and 3.", source_reg_2);
        return;
    end

    cpu_instance.register_file[destination_reg] = 8'(cpu_instance.register_file[source_reg_1] ^ cpu_instance.register_file[source_reg_2]);
endtask

task automatic not_sim(
    input int destination_reg, // can only be 2 or 3
    input int source_reg,    // can only be 0 or 1
    inout cpu_instance_t cpu_instance // instance of the CPU
);

    if (!(destination_reg inside {2, 3})) begin
        $error("not_sim(): destination_reg=%0d is invalid. Must be 2 or 3.", destination_reg);
        return;
    end
    if (!(source_reg inside {0, 1})) begin
        $error("not_sim(): source_reg=%0d is invalid. Must be 0 or 1.", source_reg);
        return;
    end

    cpu_instance.register_file[destination_reg] = 8'(~cpu_instance.register_file[source_reg]);
endtask

task automatic lsl_sim(
    input int destination_reg, // can only be 2 or 3
    input int source_reg_1,    // can only be 0 or 1
    input int source_reg_2,    // can only be 0 to 3
    inout cpu_instance_t cpu_instance // instance of the CPU
);

    if (!(destination_reg inside {2, 3})) begin
        $error("lsl_sim(): destination_reg=%0d is invalid. Must be 2 or 3.", destination_reg);
        return;
    end
    if (!(source_reg_1 inside {0, 1})) begin
        $error("lsl_sim(): source_reg_1=%0d is invalid. Must be 0 or 1.", source_reg_1);
        return;
    end
    if (!(source_reg_2 inside {[0:3]})) begin
        $error("lsl_sim(): source_reg_2=%0d is invalid. Must be between 0 and 3.", source_reg_2);
        return;
    end

    cpu_instance.register_file[destination_reg] = 8'(cpu_instance.register_file[source_reg_1] << cpu_instance.register_file[source_reg_2]);
endtask

task automatic lsr_sim(
    input int destination_reg, // can only be 2 or 3
    input int source_reg_1,    // can only be 0 or 1
    input int source_reg_2,    // can only be 0 to 3
    inout cpu_instance_t cpu_instance // instance of the CPU
);

    if (!(destination_reg inside {2, 3})) begin
        $error("lsr_sim(): destination_reg=%0d is invalid. Must be 2 or 3.", destination_reg);
        return;
    end
    if (!(source_reg_1 inside {0, 1})) begin
        $error("lsr_sim(): source_reg_1=%0d is invalid. Must be 0 or 1.", source_reg_1);
        return;
    end
    if (!(source_reg_2 inside {[0:3]})) begin
        $error("lsr_sim(): source_reg_2=%0d is invalid. Must be between 0 and 3.", source_reg_2);
        return;
    end

    cpu_instance.register_file[destination_reg] = 8'(cpu_instance.register_file[source_reg_1] >> cpu_instance.register_file[source_reg_2]);
endtask

task automatic load_sim(
    input int destination_reg, // can only be 0 to 3
    input int addr_reg,    // can only be 0 to 3
    inout cpu_instance_t cpu_instance // instance of the CPU
);

    if (!(destination_reg inside {[0:3]})) begin
        $error("load_sim(): destination_reg=%0d is invalid. Must be 0 to 3.", destination_reg);
        return;
    end
    if (!(addr_reg inside {[0:3]})) begin
        $error("load_sim(): addr_reg=%0d is invalid. Must be 0 to 3.", addr_reg);
        return;
    end

    cpu_instance.register_file[destination_reg] = cpu_instance.data_memory[cpu_instance.register_file[addr_reg]];
endtask

task automatic store_sim(
    input int source_reg, // can only be 0 to 3
    input int addr_reg,    // can only be 0 to 3
    inout cpu_instance_t cpu_instance // instance of the CPU
);

    if (!(source_reg inside {[0:3]})) begin
        $error("store_sim(): source_reg=%0d is invalid. Must be 0 to 3.", source_reg);
        return;
    end
    if (!(addr_reg inside {[0:3]})) begin
        $error("store_sim(): addr_reg=%0d is invalid. Must be 0 to 3.", addr_reg);
        return;
    end

    cpu_instance.data_memory[cpu_instance.register_file[addr_reg]] = cpu_instance.register_file[source_reg];
endtask

task automatic compare_sim(
    input int a_reg, // can only be 0 to 3
    input int b_reg,    // can only be 0 to 3
    inout cpu_instance_t cpu_instance // instance of the CPU
);

    if (!(a_reg inside {[0:3]})) begin
        $error("compare_sim(): a_reg=%0d is invalid. Must be 0 to 3.", a_reg);
        return;
    end
    if (!(b_reg inside {[0:3]})) begin
        $error("compare_sim(): b_reg=%0d is invalid. Must be 0 to 3.", b_reg);
        return;
    end

    if(cpu_instance.register_file[a_reg] > cpu_instance.register_file[b_reg]) begin
        cpu_instance.compare_register = CMP_GT;
    end else if(cpu_instance.register_file[a_reg] < cpu_instance.register_file[b_reg]) begin
        cpu_instance.compare_register = CMP_LT;
    end else begin
        cpu_instance.compare_register = CMP_EQ;
    end
endtask

task automatic branch_sim(
    input int cmp_cond, // can only be 0 to 3
    input int addr_reg,    // can only be 4 to 7
    inout cpu_instance_t cpu_instance // instance of the CPU
);

    if (!(cmp_cond inside {[0:3]})) begin
        $error("branch_sim(): cmp_cond=%0d is invalid. Must be 0 to 3.", cmp_cond);
        return;
    end
    if (!(addr_reg inside {[4:7]})) begin
        $error("branch_sim(): addr_reg=%0d is invalid. Must be 4 to 7.", addr_reg);
        return;
    end

    if(cmp_cond == 0) begin
        cpu_instance.branch_to = cpu_instance.register_file[addr_reg];
        cpu_instance.do_branch = 1; //branch unconditionally
    end
    else if(cmp_cond==2 && cpu_instance.compare_register == CMP_GT) begin
        cpu_instance.branch_to = cpu_instance.register_file[addr_reg];//Greater than
        cpu_instance.do_branch = 1; 
    end
    else if(cmp_cond==1 && cpu_instance.compare_register == CMP_LT) begin 
        cpu_instance.branch_to = cpu_instance.register_file[addr_reg];//Less than
        cpu_instance.do_branch = 1;
    end
    else if(cmp_cond==3 && cpu_instance.compare_register == CMP_EQ) begin 
        cpu_instance.branch_to = cpu_instance.register_file[addr_reg];//Equal to
        cpu_instance.do_branch = 1;
    end
    else begin
        cpu_instance.do_branch = 0; //branch unconditionally
    end
endtask

task automatic move1_sim(
    input int dest_reg,
    inout cpu_instance_t cpu_instance // instance of the CPU
);

    if (!(dest_reg inside {[0:7]})) begin
        $error("move1_sim(): dest_reg=%0d is invalid. Must be 0 to 3.", dest_reg);
        return;
    end
    //Simulation wise this actually does nothing
endtask

task automatic move2_sim(
    input int source_reg,
    inout cpu_instance_t cpu_instance // instance of the CPU
);

    if (!(source_reg inside {[0:7]})) begin
        $error("move2_sim(): source_reg=%0d is invalid. Must be 0 to 3.", source_reg);
        return;
    end
    
    //If the last instruction was a MOV1, this instruction will activate.
    if(cpu_instance.last_instruction >> 4 == 8'(OPCODE_MOV1)) begin
        int dest_reg = int'(cpu_instance.last_instruction[3:1]);
        cpu_instance.register_file[dest_reg] = cpu_instance.register_file[source_reg];
    end
endtask


// ---------------------------------------------------------------------------
// Insturction Functions
//
// Purpose:
// Insert instruction into the hardware implementation of the cpu.
//
// Arguments:
// operands (vary per instruction) - The operands of the instruction.
// instruction_stack - The isntruction stack to append the instruction to.
//
// Notes:
// Each instruction is a wrapper for the insert instruction function. Helps
// maintain code readability
// ---------------------------------------------------------------------------

task automatic add_instruction(
    input logic destination_reg,
    input logic source_reg_1,
    input logic [1:0] source_reg_2,
    inout instruction_stack_t instruction_stack
);
    insert_instruction(OPCODE_ADD, {destination_reg,source_reg_1,source_reg_2},instruction_stack);
endtask

task automatic addi_instruction(
    input logic destination_reg,
    input logic source_reg,
    input logic [1:0] immediate,
    inout instruction_stack_t instruction_stack
);
    insert_instruction(OPCODE_ADDI, {destination_reg,source_reg,immediate},instruction_stack);
endtask

task automatic sub_instruction(
    input logic destination_reg,
    input logic source_reg_1,
    input logic [1:0] source_reg_2,
    inout instruction_stack_t instruction_stack
);
    insert_instruction(OPCODE_SUB, {destination_reg,source_reg_1,source_reg_2},instruction_stack);
endtask

task automatic subi_instruction(
    input logic destination_reg,
    input logic source_reg,
    input logic [1:0] immediate,
    inout instruction_stack_t instruction_stack
);
    insert_instruction(OPCODE_SUBI, {destination_reg,source_reg,immediate},instruction_stack);
endtask

task automatic load_instruction(
    input logic [1:0] dest_reg,
    input logic [1:0] addr_reg,
    inout instruction_stack_t instruction_stack
);
    insert_instruction(OPCODE_LDUR,{dest_reg,addr_reg},instruction_stack);
endtask

task automatic store_instruction(
    input logic [1:0] source_reg,
    input logic [1:0] addr_reg,
    inout instruction_stack_t instruction_stack
);
    insert_instruction(OPCODE_STUR,{source_reg,addr_reg},instruction_stack);
endtask

task automatic move_instruction(
    input logic [2:0] source_reg,
    input logic [2:0] destination_reg,
    inout instruction_stack_t instruction_stack
);
    insert_instruction(OPCODE_MOV1,{destination_reg,1'b0},instruction_stack);
    insert_instruction(OPCODE_MOV2,{source_reg,1'b0},instruction_stack);
endtask

task automatic branch_instruction(
    input logic [1:0] branch_cond,
    input logic [1:0] addr_reg,
    inout instruction_stack_t instruction_stack
);
    insert_instruction(OPCODE_BR,{branch_cond,addr_reg},instruction_stack);
endtask

// ---------------------------------------------------------------------------
// Driver Fuction
// ---------------------------------------------------------------------------

//--------------------------------------------------------------
// Task: instruction_driver
// Purpose:
//    Inserts an instruction stack, or a portion of it, into the
//    hardware implementation of the cpu's program memory.
//
// Arguments:
//    instruction_stack - the instruction stack to add to program memory.
//    lower_bound_addr - the lower bound of what instructions to add.
//    upper_bound_addr - the upper bound of what instructions to add.
//    
//
// Notes:
//    Instruction bounds are optional and default to 0 to 256.
//    
//--------------------------------------------------------------
task automatic instruction_driver(
    input instruction_stack_t instruction_stack,
    input int lower_bound_addr = 0,
    input int upper_bound_addr = MAX_MEMORY_ADDR

);
    int i;
     service_mode = 1'b1;//Ensure CPU is not running
     program_memory_write_enable = 1'b1;//Ensure program memory can be written to

    for(i = lower_bound_addr; i < upper_bound_addr; i++) begin
     program_memory_data_in = instruction_stack.instructions[i];//Queue the next instruction
     program_memory_address = i[7:0];

     clock_driver();//Cycle the clock
    end
    
     program_memory_write_enable = 1'b0;//Disable writes to program memory
     service_mode = 1'b0;//Re-enable the CPU
endtask

//--------------------------------------------------------------
// Task: clock_driver
// Purpose:
//    simply advances the clock for the hardware implementation
//    of the cpu.
//
// Arguments:
//    (none)
//    
//
// Notes:
//    When inserting isntructions into an instruction stack, this
//    is likely to be called by other helper functions.
//    
//--------------------------------------------------------------
task automatic clock_driver();
    #1 clk = 0;
    #1 clk = 1;
endtask

//--------------------------------------------------------------
// Task: execute_for_cycles
// Purpose:
//    Execute a specified number of cycles on the hardware implementation.
//
// Arguments:
//    cycles - The number of the cycles to execute.
//
// Notes:
//    Useful when there are many instructions in the program
//    memory to execute.
//    
//--------------------------------------------------------------
task automatic execute_for_cycles(input int cycles); //drives the clock for a certain amount of cycles, useful for just running program instructions.
    int i;
    service_mode = 1'b0;
    for(i = 0; i < cycles; i++) begin
        clock_driver();
    end
    service_mode = 1'b1;
endtask

//--------------------------------------------------------------
// Task: clock_driver
// Purpose:
//    Resets everything in the hardware implementation execept for
//    the register file, program memory, and data memory.
//
// Arguments:
//    (none)
//    
//
// Notes:
//    (None)
//    
//--------------------------------------------------------------
task automatic reset_driver();
    rst = 1;
    clock_driver();
    rst = 0;
endtask

//--------------------------------------------------------------
// Task: register_reset_driver
// Purpose:
//    Resets on the contents of the register file.
//
// Arguments:
//    (none)
//    
// Notes:
//    (None)
//    
//--------------------------------------------------------------
task automatic register_reset_driver();
    register_rst = 1;
    clock_driver();
    register_rst = 0;
endtask

// ---------------------------------------------------------------------------
// Helper Fuction
// ---------------------------------------------------------------------------

//--------------------------------------------------------------
// Task: setup
// Purpose:
//    Initializes all signals for the hardware implementation of
//    the cpu.
//
// Arguments:
//    (none)
//    
// Notes:
//    Should be called before utilizing the cpu.
//    
//--------------------------------------------------------------
task automatic setup(); 
    clk = 1'b1;
    rst = 1'b0;
    register_rst = 1'b0;
    service_mode = 1'b1;
    program_memory_data_in = 8'b0;
    program_memory_address = 8'b0;
    program_memory_rst = 1'b0;
    program_memory_write_enable = 1'b0;
    data_memory_data_in = 8'b0;
    data_memory_address = 8'b0;
    data_memory_rst = 1'b0;
    data_memory_write_enable = 1'b0;
endtask

//--------------------------------------------------------------
// Task: insert_instruction
// Purpose:
//    Appends a single instruction in a given instruction stack. 
//
// Arguments:
//    opcode - The opcode of the instruction
//    operand - The four bit operand fields
//    instruction_stack - The instruction stack to insert the instruction into
//    
// Notes:
//    Should be called before utilizing the cpu.
//    
//--------------------------------------------------------------
task automatic insert_instruction(
    input opcode_t opcode,
    input logic [3:0] operand,
    inout instruction_stack_t instruction_stack
);
    instruction_stack.instructions[instruction_stack.num_instructions] = {opcode,operand};
    instruction_stack.num_instructions = instruction_stack.num_instructions + 1;
endtask

//--------------------------------------------------------------
// Task: generate_number
// Purpose:
//    Provides instructions to a given number inside of register 3.
//
// Arguments:
//    instruction_stack - Instruction stack to insert necessary instructions into.
//    number - The number to generate (0,255)
//    
// Notes:
//    Also utilizes registers 1 and 2. Should back up the contents
//    to other registers or memory if needed.
//    
//--------------------------------------------------------------
task automatic generate_number(//generates a number inside register 3
    inout instruction_stack_t instruction_stack,
    input int number
);
    int loop_number = number - (number % 3);//The multiple of three before the number
    int remainder = (number % 3);
    int i = 0;

    if(number <= 3) begin//number less thatn three
        addi_instruction(1'b1, 1'b0, number[1:0],instruction_stack);
        return;
    end else if(number > 3 ) begin
        
        addi_instruction(1'b0,1'b0,2'b11,instruction_stack);//Put 3 in registers 1 and 2
        move_instruction(3'b010,3'b001,instruction_stack);//moves the value 3 to regsiter 1
        addi_instruction(1'b0,1'b0,2'b11,instruction_stack);//Add the value of 3 back to register 2

        for(i = 0; i < loop_number - 3; i+=3) begin
            add_instruction(1'b1,1'b1,2'b10,instruction_stack);//register 3 = register 1 (3) + register 2
            move_instruction(3'b011, 3'b010,instruction_stack);//Move value of register 3 to 3
        end
        move_instruction(3'b011,3'b001,instruction_stack);
        addi_instruction(1'b1,1'b1,remainder[1:0],instruction_stack);
    end
endtask

//--------------------------------------------------------------
// Task: transfer_registers_to_data_memory
// Purpose:
//    Provides instructions to transfer the contents of the register file
//    into the first 7 addresses of the data memory module.
//
// Arguments:
//    instruction_stack - Instruction stack to insert necessary instructions into.
//    up_to_register - Can specify up to which register to add to data memory.
//    
// Notes:
//    up_to_register must be between 3 and 7 inclusive. Excludes register zero.
//    
//--------------------------------------------------------------
task automatic transfer_registers_to_data_memory(
    inout instruction_stack_t instruction_stack,
    input int up_to_register = 7
);
    int i;

    if(up_to_register > 7) begin //num_of_registers greater than the actual amount of registers
        up_to_register = 7;
        $display("Transfer Registers to Data Memory: Number of registers exceeds the highest register, setting to 7.");
    end else if(up_to_register < 3) begin
        up_to_register = 3;
        $display("Transfer Registers to Data Memory: Minimum register is 3");
    end
   
    store_instruction(2'b01, 2'b00, instruction_stack);//store value of register 1 at position zero
    move_instruction(3'b010, 3'b001, instruction_stack);//move to value of register 2 to register 1
    addi_instruction(1'b0, 1'b0, 2'b1,instruction_stack);//set the value of register 2 to 1

    store_instruction(2'b01, 2'b10, instruction_stack);//Store what was in regsiter 2 to the position 1
    
    for(i = 3; i <= up_to_register; i++) begin
        move_instruction(3'b010,3'b001, instruction_stack); //move value of a register 2 to register 1
        addi_instruction(1'b0, 1'b1, 2'b1,instruction_stack); //adds the previous value of register 2 in register 1 by 1, writes it back to register 2
        move_instruction(i[2:0],3'b011,instruction_stack);
        store_instruction(2'b11, 2'b10, instruction_stack);
    end

endtask

//--------------------------------------------------------------
// Task: transfer_data_memory_to_registers
// Purpose:
//    Provides instructions to transfer the contents of the first
//    7 positions of data memory into registers 1 to 7.
//
// Arguments:
//    instruction_stack - Instruction stack to insert necessary instructions into.
//    up_to_register - Can specify up to which register to add to data memory.
//    
// Notes:
//    up_to_register must be between 3 and 7 inclusive.
//    
//--------------------------------------------------------------
task automatic transfer_data_memory_to_registers(
    inout instruction_stack_t instruction_stack,
    input int up_to_register = 7
);
    int i;
    generate_number(instruction_stack, up_to_register);
    move_instruction(3'b011,3'b001,instruction_stack);
    subi_instruction(1'b0,1'b1,2'b01,instruction_stack);//register 2 should always be 1 less than register 3
    
    for(i = up_to_register; i >= 3; i--) begin
        load_instruction(2'b11,2'b10,instruction_stack);
        move_instruction(3'b10, 3'b11,instruction_stack);//move register 2 to register 3
        move_instruction(3'b10, 3'b01,instruction_stack);//move register 2 to register 1
        subi_instruction(1'b0,1'b1,2'b01,instruction_stack);//register 2 should always be 1 less than register 3
    end
    addi_instruction(1'b1, 1'b0,2'b11,instruction_stack);//reg_addr(3)
    addi_instruction(1'b0, 1'b0, 2'b10,instruction_stack);//mem_addr(2)
    load_instruction(2'b11,2'b10,instruction_stack);

    addi_instruction(1'b0,1'b0,2'b01,instruction_stack);
    move_instruction(3'b010,3'b001,instruction_stack);
    addi_instruction(1'b0,1'b0,2'b10,instruction_stack);//register 2 = 2, register 1 = 1
    load_instruction(2'b10,2'b01,instruction_stack);

    load_instruction(2'b01,2'b00,instruction_stack);  

endtask

//--------------------------------------------------------------
// Task: clear_data_memory
// Purpose:
//    Clears the data memory module, setting all entries to zero.
//
// Arguments:
//    (None)
//    
// Notes:
//    Only takes a single clock cycle.
//    
//--------------------------------------------------------------
task automatic clear_data_memory();
    service_mode = 1'b1; //stop CPU execution
    data_memory_rst = 1'b1; //Prepare to reset data memory

    clock_driver();//Resets memory (Only one cycle since it is not synthesizable BRAM)

    data_memory_rst = 1'b0; //Disable memory reset
    service_mode = 1'b0; //disable service mode.
endtask

//--------------------------------------------------------------
// Task: clear_program_memory
// Purpose:
//    Clears the program memory module, setting all entries to zero.
//
// Arguments:
//    (None)
//    
// Notes:
//    Only takes a single clock cycle.
//    
//--------------------------------------------------------------
task automatic clear_program_memory();
    service_mode = 1'b1; //stop CPU execution
    program_memory_rst = 1'b1; //Prepare to reset program memory

    clock_driver();//Resets memory (Only one cycle since it is not synthesizable BRAM)

    program_memory_rst = 1'b0; //Disable memory reset
    service_mode = 1'b0; //disable service mode.
endtask

//--------------------------------------------------------------
// Task: fill_registers
// Purpose:
//    Provides instructions to fill registers 1 to 7 with their
//    respective register number.
//
// Arguments:
//    instruction_stack - The isntruction stack to add the instructions to.
//    
// Notes:
//   Useful for debugging registers, especially during random stimulus
//   testing.
//    
//--------------------------------------------------------------
task automatic fill_registers(
    inout instruction_stack_t instruction_stack
);
    int i;

    addi_instruction(1'b0, 1'b0, 2'b10,instruction_stack);//sets register 2 as the value 3 
    move_instruction(3'b010, 3'b001,instruction_stack);//Moves the value 3 from register 2 to regsiter 1
    addi_instruction(1'b0, 1'b0, 2'b11,instruction_stack);//sets the register to the value of 2

    add_instruction(1'b1, 1'b1, 2'b10,instruction_stack);//adds registers 1 and 2 to get 5 in register 3
    add_instruction(1'b1, 1'b1, 2'b11,instruction_stack);//adds regsiters 1 and 3 to get 7 in register 3

    for(i = 7 ;i >= 4;i-- ) begin //enters calues into register 4 to 7
        move_instruction(3'b011, 3'b001,instruction_stack);//moves 7 to register 1
        move_instruction(3'b011, i[2:0],instruction_stack);//moves 7 to register 7
        subi_instruction(1'b1,1'b1,2'b01,instruction_stack);//subtracts 7 by 1 and puts 6 in register 3
    end

    addi_instruction(1'b0,1'b0,2'b01,instruction_stack);
    move_instruction(3'b010,3'b001,instruction_stack);//1 in regsiter 1
    addi_instruction(1'b0, 1'b0, 2'b10,instruction_stack);//2 in register 2
    addi_instruction(1'b1,1'b0,2'b11,instruction_stack);//3 to register 3
endtask

//--------------------------------------------------------------
// Task: fill_data_capture_with_increasing_numbers
// Purpose:
//    Fills a data memory capture with increasing numbers, such that
//    address 1 holds the value 1, address 37 holds 37, etc.
//
// Arguments:
//    data_memory_capture - The data memory capture to add numbers to.
//    
// Notes:
//   (None)
//    
//--------------------------------------------------------------
task automatic fill_data_capture_with_increasing_numbers(
    inout data_stack_t data_memory_capture
);
    integer i;//Integer used in for loop

    for(i = 0; i < MAX_MEMORY_ADDR; i++) begin
        data_memory_capture.data[i] = i[7:0];//Set memory address as a truncation of i
    end

endtask

//--------------------------------------------------------------
// Task: fill_data_capture_with_random_numbers
// Purpose:
//    Fills every address in a data memory capture with a random
//    number from 0 to 255.
//
// Arguments:
//    data_memory_capture - The data memory capture to add numbers to.
//    
// Notes:
//   (None)
//    
//--------------------------------------------------------------
task automatic fill_data_capture_with_random_numbers(
    inout data_stack_t data_memory_capture
);//Fills data memory with increasing numbers. For testing purposes
        integer i;//Integer used in for loop

    for(i = 0; i < MAX_MEMORY_ADDR; i++) begin
        data_memory_capture.data[i] = 8'($urandom());//Set memory address as a truncation of i
    end

endtask

//--------------------------------------------------------------
// Task: insert_data_capture_into_data_memory
// Purpose:
//    Inserts the contents of a data capture into that hardware
//    implementations data memory module 
//
// Arguments:
//    data_memory_capture - The data memory capture to add.
//    lower_bound_addr - The lower bound of the address range
//    upper_bound_addr - The upper bound of the address range
//    
// Notes:
//   Useful for starting random stimulus testing with data in
//   the data memory.
//    
//--------------------------------------------------------------
task automatic insert_data_capture_into_data_memory(
    input data_stack_t data_memory_capture,
    input int lower_bound_addr = 0,
    input int upper_bound_addr = 255
);
    int i;
    if(lower_bound_addr > upper_bound_addr) $error("Insert Capture into Data Memory: Lower bound address is higher than upper bound address");

    service_mode = 1'b1; //stop CPU execution
    data_memory_write_enable = 1'b1;//Enable writes to data_memory
    
    clock_driver(); //Allow everthing to settle

    for(i = lower_bound_addr; i <= upper_bound_addr;i++) begin
        data_memory_address = i[7:0];
        data_memory_data_in = data_memory_capture.data[i];
        clock_driver();
    end

    data_memory_write_enable = 1'b0;//Disable writes to data_memory
    service_mode = 1'b0; //start CPU execution

endtask

//--------------------------------------------------------------
// Task: capture_data_memory
// Purpose:
//    Captures the current contents of the data_memory_module and
//    insert it into a give data memory capture object.
//
// Arguments:
//    data_memory_capture - The data memory capture store the data.
//    
// Notes:
//    Useful for verifying data. Can be used in tandem with transfer_registers_to_data_memory
//    to read the contents of the registers.
//    
//--------------------------------------------------------------
task automatic capture_data_memory(
    inout data_stack_t data_memory_capture
);
    integer i;//Integer used in for loop

    service_mode = 1'b1; //stop CPU execution
    data_memory_write_enable = 1'b0;//Stop all writes to data_memory
    
    clock_driver(); //Allow everthing to settle

    for(i = 0; i < MAX_MEMORY_ADDR; i++) begin
        data_memory_address = i[7:0];//Set memory address as a truncation of i
        clock_driver();
        data_memory_capture.data[i] = data_memory_data_out;
    end

    service_mode = 1'b0; //exit service mode
endtask

//--------------------------------------------------------------
// Task: print_data_memory_capture
// Purpose:
//    Prints the contents of a given data memory capture
//
// Arguments:
//    data_memory_capture - The data memory capture to print
//    positions - The maximum memory address to print
//    
// Notes:
//    (none)
//    
//--------------------------------------------------------------
task automatic print_data_memory_capture(
    input data_stack_t data_memory_capture,
    input int positions = MAX_MEMORY_ADDR
);
    integer i;//Integer used in for loop
        string intro_text;
        $sformat(intro_text,"Reading from capture: %s",data_memory_capture.name);
        $display(intro_text);
    for(i = 0; i < positions; i++) begin
        string output_text;
        $sformat(output_text, "Entry %d: %h",i,data_memory_capture.data[i]);
        $display(output_text);
    end
endtask;

//--------------------------------------------------------------
// Task: print_data_memory_capture
// Purpose:
//    Prints the contents of a given instruction stack
//
// Arguments:
//    instruction_stack - The instruciton stack to print
//    positions - The maximum instruction address to print
//    
// Notes:
//    (none)
//    
//--------------------------------------------------------------
task automatic print_instruction_stack(
    inout instruction_stack_t instruction_stack,
    input int positions = MAX_MEMORY_ADDR
);
    integer i;//Integer used in for loop
        string intro_text;
        $sformat(intro_text,"Reading from capture: %s (# of instructions: %d)",instruction_stack.name,instruction_stack.num_instructions);
        $display(intro_text);
    for(i = 0; i < positions; i++) begin
        string output_text;
        $sformat(output_text, "Entry %d: %h",i,instruction_stack.instructions[i]);
        $display(output_text);
    end
endtask

//--------------------------------------------------------------
// Task: print_cpu_instance
// Purpose:
//    Prints the contents of a given cpu_instance
//
// Arguments:
//    cpu_instrance - The cpu instance to print
//    
// Notes:
//    (none)
//    
//--------------------------------------------------------------
task automatic print_cpu_instance(
    input cpu_instance_t cpu_instance
);
    int i;
    for(i = 0; i < MAX_MEMORY_ADDR; i++) begin
        if(cpu_instance.data_memory[i] !== 8'b0) begin
            $display("At memory address %h : %d", i, cpu_instance.data_memory[i]);
        end
    end
    for(i = 0; i < 8; i++) begin
        if(cpu_instance.register_file[i] !== 8'b0) begin
            $display("At register address %h : %d", i, cpu_instance.register_file[i]);
        end
    end

    $display("Compare Register: %h",cpu_instance.compare_register);
    $display("Branch Register: %h ",cpu_instance.branch_to);
    $display("Last Instruction: %h ",cpu_instance.last_instruction);
    $display("Do Branch: ", cpu_instance.do_branch);
    $display("---------------------------------------------------------");
endtask

//--------------------------------------------------------------
// Task: print_scoreboard
// Purpose:
//    Prints the contents of a given scoreboard
//
// Arguments:
//    scoreboard - Print the contents of a given scoreboard.
//    debug - Print the instructions of the unsuccessful runs.
//    
// Notes:
//    (none)
//    
//--------------------------------------------------------------
task automatic print_scoreboard(
    input scoreboard_t scoreboard,
    input bit debug = 0
);
    int i, j;

    // Print summary
    $display("========================================");
    $display("Scoreboard Summary:");
    $display("  Successful runs   : %0d", scoreboard.successful_runs_counter);
    $display("  Unsuccessful runs : %0d", scoreboard.unsuccessful_runs_counter);
    $display("========================================");

    // If debug mode is on, print unsuccessful instruction traces
    if (debug) begin
        if (scoreboard.unsuccessful_runs_counter == 0) begin
            $display("No unsuccessful runs to display.");
        end else begin
            $display("---- Unsuccessful Run Details ----");
            for (i = 0; i < scoreboard.unsuccessful_runs_counter; i++) begin
                $display("Run #%0d:", i);
                for (j = 0; j < MAX_MEMORY_ADDR; j++) begin
                    if (scoreboard.unsuccessful_instructions[i][j] !== 8'bx &&
                        scoreboard.unsuccessful_instructions[i][j] !== 8'b0)
                        $display("  Instruction[%0d] = 0x%02h",
                                 j, scoreboard.unsuccessful_instructions[i][j]);
                end
                $display("");
            end
        end
    end
endtask


// ---------------------------------------------------------------------------
// Main Stimulus
// ---------------------------------------------------------------------------

initial begin
        scoreboard_t scoreboard;
    int i;
    for(i = 0; i < MAX_RUNS; i++) begin
        data_stack_t data_stack = '{default: '0};
        instruction_stack_t instruction_stack = '{default: '0};
        /* verilator lint_off UNDRIVEN */
        cpu_instance_t cpu_instance = '{default: '0};
        /* verilator lint_on UNDRIVEN */

        data_stack.name = "Data Stack";
        instruction_stack.name = "Instruction Stack";

        $display("Run %d of %d.",i,MAX_RUNS);

        //reset
        setup();
        reset_driver();
        register_reset_driver();
        clear_program_memory();
        clear_data_memory();
        clock_driver();

        randomize_instructions(instruction_stack,32);

        instruction_driver(instruction_stack);//Run on CPU

        execute_for_cycles(instruction_stack.num_instructions + 1);

        
        simulate(instruction_stack,cpu_instance,instruction_stack.num_instructions);//And simulate

        check(instruction_stack,cpu_instance,scoreboard);
    end
    print_scoreboard(scoreboard,1);
    $display("Finished all execution");
    $finish();
end

//Waveform dump
initial begin
$dumpfile("tb_cpu_8.vcd");
$dumpvars(0, cpu_8_tb);
end
endmodule
