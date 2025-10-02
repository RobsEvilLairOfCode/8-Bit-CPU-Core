module comparator_8 (
    input  logic [7:0] A, 
    input  logic [7:0] B, 
    output logic       LT,   
    output logic       EQ,   
    output logic       GT    
);

always_comb begin
    EQ = (A == B);   
    GT = (A >  B);  
    LT = (A <  B);
end

endmodule
