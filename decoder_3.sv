module decoder_3(
    input logic [2:0] A,
    output logic [7:0] Y
);
   assign Y = (A == 3'b000) ? 8'b0 : (8'b00000001 << A);// if writing to register Zero, dont enable any registers (Register zero is tied low and does not accept writes)
endmodule