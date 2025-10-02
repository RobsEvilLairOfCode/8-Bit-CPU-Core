module compare_flag_register_enable_logic(
    input [7:0] instruction,
    output logic write_enable
);
import opcode_pkg::*;

opcode_t    opcode;

always_comb begin
    opcode = opcode_t'(instruction[7:4]);
end

always_comb begin
    write_enable = (opcode == OPCODE_CMP)? 1'b1: 1'b0;
end

endmodule
