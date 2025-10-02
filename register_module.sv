module register_module(
    input clk,
    input rst,
    input write_enable,
    input [7:0] data_in,
    output logic [7:0] data_out //outputs are defaulted to wires. Must specify as logic if it will hold value
);

always_ff @(posedge clk) begin
    if(rst) begin
        data_out <= 8'b0;//resets the stored value to zero
    end else begin
        if(write_enable) begin
            data_out <= data_in;//overwrite the data with data_in
        end
    end
end
endmodule
