module mux_4to1(
    input [7:0] A [3:0],
    input [2:0] sel,
    output [7:0] Y
);
   assign Y = A[sel];
endmodule
