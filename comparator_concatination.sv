module comparator_concatination (
    input LT,
    input EQ,
    input GT,
    output logic [7:0] concatinated_output
);

assign concatinated_output = {5'b0, LT,EQ,GT};
endmodule
