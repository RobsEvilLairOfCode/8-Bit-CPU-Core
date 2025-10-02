module alu_8(
    input logic [7:0] A,
    input logic [7:0] B,
    input logic [2:0] OP,
    input logic C_in,
    input logic EN,
    input logic update_flags,
    output logic [7:0] Y,
    output logic C_out,
    output logic Z,
    output logic N,
    output logic V
);


always_comb begin
    logic [8:0] temp;
    temp = 9'b0;

    //By initializing values, avoids inferences of latches, and also implements deterministic values when EN is low
    Y = 8'b0;
    C_out = 1'b0;
    Z = 1'b0;
    N = 1'b0;
    V = 1'b0;
    if(EN) begin
        case (OP)
            3'b000: begin //ADD
                //Note:  (Default C_in for LSB is 0)
                temp = {1'b0, A} + {1'b0, B} + {8'b0, C_in};
                Y = temp[7:0];
                C_out = temp[8];
                if(update_flags) begin
                    Z = ~(|Y); // |Y is a "reduction or" that or's together all bits in Y and produces one bit as the result
                    N = Y[7];
                    V = (A[7] == B[7]) && (Y[7] != A[7]);//Note, V flag is only applicable for detecting overflow for signed numbers. For overflow of unsigned numbers, use C_out
                end
            end
            3'b001: begin //Subtraction
                //Note:  (Default C_in for LSB is 1 due to 2's comp.)
                temp = {1'b0, A} + {1'b0, ~B} + {8'b0, C_in}; //Flip the B bits since it is subtraction
                Y = temp[7:0];
                C_out = temp[8];
                if(update_flags) begin
                    Z = ~(|Y);
                    N = Y[7];
                    V = (A[7] != B[7]) && (Y[7] != A[7]);
                end
            end
            3'b010: begin //AND
                Y = A & B;
                if(update_flags) begin
                    Z = ~(|Y);
                    N = Y[7];
                    V = 1'b0;
                end
            end
            3'b011: begin //OR
                Y = A | B;
                if(update_flags) begin
                    Z = ~(|Y);
                    N = Y[7];
                    V = 1'b0;
                end
            end
            3'b100: begin //XOR
                Y = A ^ B;
                if(update_flags) begin
                    Z = ~(|Y);
                    N = Y[7];
                    V = 1'b0;
                end
            end 
            3'b101: begin //NOT
                Y = ~A;
                if(update_flags) begin
                    Z = ~(|Y);
                    N = Y[7];
                    V = 1'b0;
                end
            end
            3'b110: begin //LSL
                Y = A << B[2:0];//Only take 3 LSB as shifts greater than 8 have undefined behavior
                if(update_flags) begin
                    Z = ~(|Y);
                    N = Y[7];
                    V = 1'b0;
                end
            end
            3'b111: begin //LSR
                Y = A >> B[2:0];//Only take 3 LSB as shifts greater than 8 have undefined behavior
                if(update_flags) begin
                    Z = ~(|Y);
                    N = Y[7];
                    V = 1'b0;
                end
            end
            default: begin //Default needed to avoid inferences of latches
               Y     = 8'b0000;
                C_out = 1'b0;
                Z     = 1'b0;
                N     = 1'b0;
                V     = 1'b0; 
            end
        endcase
    end
end

endmodule
