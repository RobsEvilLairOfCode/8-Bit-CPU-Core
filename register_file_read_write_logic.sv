module register_file_read_write_logic(
    input [7:0] instruction,
    input enabled,
    //Stuff from MOV logic
    input mov_write_enable,
    input [2:0] mov_write_select,
    input [2:0] mov_read_select,
    //Outputs
    output logic write_enable,
    output logic [2:0] write_select,
    output logic [2:0] read_select_1,
    output logic [2:0] read_select_2
);
import opcode_pkg::*;   // bring in the typedefs and enums

logic [3:0] data;
opcode_t    opcode;

always_comb begin
    opcode = opcode_t'(instruction[7:4]);
    data   = instruction[3:0];
end


//write_enable_logic
always_comb begin
    if(enabled && (|instruction)) begin //Check if enabled and the instruction is not the special stall instruction (all bits zero)
        case (opcode)
            OPCODE_STUR,
            OPCODE_CMP,
            OPCODE_BR,
            OPCODE_MOV1: write_enable = 1'b0;
            OPCODE_MOV2: write_enable = mov_write_enable;
            default: write_enable = 1'b1;
        endcase
    end else begin
        write_enable = 1'b0; //avoid latches
    end
end

//write_select_logic
always_comb begin
    if(enabled) begin
        case (opcode)
            OPCODE_ADD,
            OPCODE_ADDI,
            OPCODE_SUB,
            OPCODE_SUBI,
            OPCODE_AND,
            OPCODE_OR,
            OPCODE_XOR,
            OPCODE_NOT,
            OPCODE_LSL,
            OPCODE_LSR: write_select = {2'b01,data[3]};
            OPCODE_LDUR: write_select = {1'b0,data[3:2]};
            OPCODE_STUR,
            OPCODE_CMP,
            OPCODE_BR: write_select = 3'b000;
            OPCODE_MOV1: write_select = 3'b000;
            OPCODE_MOV2: write_select = mov_write_select;
            default: write_select = 3'b000; 
        endcase
    end else begin
        write_select = 3'b000; //avoid latches
    end
end

//read_select_logic_1
always_comb begin
    if(enabled) begin
        case (opcode)
            OPCODE_ADD,
            OPCODE_ADDI,
            OPCODE_SUB,
            OPCODE_SUBI,
            OPCODE_AND,
            OPCODE_OR,
            OPCODE_XOR,
            OPCODE_NOT,
            OPCODE_LSL,
            OPCODE_LSR: read_select_1 = {2'b0,data[2]};
            OPCODE_LDUR: read_select_1 = {1'b0,data[1:0]};
            OPCODE_STUR: read_select_1 = {1'b0,data[1:0]};
            OPCODE_CMP: read_select_1 = {1'b0, data[3:2]};
            OPCODE_BR: read_select_1 = {1'b1,data[1:0]};
            OPCODE_MOV1: read_select_1 = 3'b000;
            OPCODE_MOV2: read_select_1 = mov_read_select;
            default: read_select_1 = 3'b000; 
        endcase
    end else begin
        read_select_1 = 3'b000; //avoid latches
    end
end

//read_select_logic_2
always_comb begin
    if(enabled) begin
        case (opcode)
            OPCODE_ADD,
            OPCODE_ADDI,
            OPCODE_SUB,
            OPCODE_SUBI,
            OPCODE_AND,
            OPCODE_OR,
            OPCODE_XOR,
            OPCODE_NOT,
            OPCODE_LSL,
            OPCODE_LSR: read_select_2 = {1'b0,data[1:0]};
            OPCODE_LDUR: read_select_2 = 3'b000;
            OPCODE_STUR: read_select_2 = {1'b0,data[3:2]};
            OPCODE_CMP: read_select_2 = {1'b0, data[1:0]};
            OPCODE_BR: read_select_2 = 3'b000;
            OPCODE_MOV1: read_select_2 = 3'b000;
            OPCODE_MOV2: read_select_2 = 3'b000;
            default: read_select_2 = 3'b000; 
        endcase
    end else begin
        read_select_2 = 3'b000;
    end
end
endmodule
