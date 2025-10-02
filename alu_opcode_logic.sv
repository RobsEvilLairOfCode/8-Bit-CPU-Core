module alu_opcode_logic(
    input [7:0] instruction,
    output logic [2:0] alu_opcode
);

import opcode_pkg::*;

opcode_t    opcode;

always_comb begin
    opcode = opcode_t'(instruction[7:4]);
end

always_comb begin
    case (opcode)
        OPCODE_ADD, OPCODE_ADDI: alu_opcode = 3'b000;
        OPCODE_SUB, OPCODE_SUBI: alu_opcode = 3'b001;
        OPCODE_AND: alu_opcode = 3'b010;
        OPCODE_OR: alu_opcode = 3'b011;
        OPCODE_XOR: alu_opcode = 3'b100;
        OPCODE_NOT: alu_opcode = 3'b101;
        OPCODE_LSL: alu_opcode = 3'b110;
        OPCODE_LSR: alu_opcode = 3'b111;
        default: alu_opcode = 3'b000;
    endcase
end
endmodule
