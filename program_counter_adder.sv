module program_counter_adder(
    input [7:0] A,
    output [7:0] Y
);
    assign Y = A + 8'b00000001;
endmodule
