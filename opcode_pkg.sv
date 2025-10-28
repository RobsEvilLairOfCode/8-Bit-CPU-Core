`timescale 1ns/1ps
package opcode_pkg;
    typedef enum logic [3:0] {
        OPCODE_ADD  = 4'b0000,
        OPCODE_ADDI = 4'b0001,
        OPCODE_SUB  = 4'b0010,
        OPCODE_SUBI  = 4'b0011,
        OPCODE_AND   = 4'b0100,
        OPCODE_OR   = 4'b0101,
        OPCODE_XOR   = 4'b0110,
        OPCODE_NOT   = 4'b0111,
        OPCODE_LSL   = 4'b1000,
        OPCODE_LSR   = 4'b1001,
        OPCODE_LDUR   = 4'b1010,
        OPCODE_STUR   = 4'b1011,
        OPCODE_CMP   = 4'b1100,
        OPCODE_BR   = 4'b1101,
        OPCODE_MOV1   = 4'b1110,
        OPCODE_MOV2   = 4'b1111
    } opcode_t;

endpackage
