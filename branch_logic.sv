module branch_logic(

    //Branch instruction
    input [7:0] instruction,
    input [7:0] compare_flag,
    output logic do_branch
);

import opcode_pkg::*;

opcode_t    opcode;
logic [1:0] condition;

always_comb begin
    opcode = opcode_t'(instruction[7:4]);
    condition = instruction[3:2];
end

always_comb begin
    //bits [7:2] of the compare flag should be zero
    if(opcode == OPCODE_BR) begin
        case (condition)
            2'b00: do_branch = 1'b1;//Unconditional
            2'b01: do_branch = compare_flag[2];//Less Than
            2'b10: do_branch = compare_flag[0];//Greater Than
            2'b11: do_branch = compare_flag[1];//Equal To
            default: do_branch = 1'b0;
        endcase 
    end else begin
        do_branch = 1'b0;
    end
end

endmodule
