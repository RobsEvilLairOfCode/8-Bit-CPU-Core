module program_counter(
    input clk,
    input rst,
    input write_enable,
    input [7:0] data_in,
    output logic [7:0] data_out
);
logic       write_enable_delayed; // registers previous value of write_enabled

always_ff @(posedge clk) begin
    if(rst) begin
        data_out <= 8'b0;//resets the stored value to zero
        write_enable_delayed <= 1'b0; //Also resets the write enable delays signal
    end else begin
        if(~write_enable_delayed && write_enable) begin
            data_out <= data_out; //prevent an uninteded instruction skip
        end else if(write_enable) begin
            data_out <= data_in;//overwrite the data with data_in
        end
        write_enable_delayed <= write_enable; //replace the old write_enabled delayed with the new one
    end
end


endmodule
