module register_file_data_in_logic(
    input [7:0] instruction,
    input [7:0] ALU,
    input [7:0] MOV,
    input [7:0] LDUR,
    output logic [7:0] data_in
);
import opcode_pkg::*;

opcode_t    opcode;

always_comb begin
    opcode = opcode_t'(instruction[7:4]);
end

always_comb begin
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
        OPCODE_LSR: data_in = ALU;
        OPCODE_LDUR: data_in = LDUR;
        OPCODE_MOV1,
        OPCODE_MOV2: data_in = MOV;
        default: data_in = 8'b0;
    endcase
end
endmodule
