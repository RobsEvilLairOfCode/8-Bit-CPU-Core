module mux_8to1(
    input [7:0] A [7:0],
    input [2:0] sel,
    output [7:0] Y
);
   assign Y = A[sel];
endmodule
