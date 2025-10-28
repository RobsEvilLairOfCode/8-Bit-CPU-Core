module register_array_8(
    input clk,
    input rst,
    input [7:0] write_enable,
    input [7:0] data_in, //This is eventually used in a register file in which the same data in will be connected to all the register data_ins
    output logic [7:0] data_out [7:0]
);
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin
            if (i == 0) begin : gen_register
                register_module register(
                .clk(clk),
                .rst(rst),
                .write_enable(write_enable[i]),
                .data_in(8'b0),
                .data_out(data_out[i])
            );
            end else begin : gen_register
            register_module register(
                .clk(clk),
                .rst(rst),
                .write_enable(write_enable[i]),
                .data_in(data_in),
                .data_out(data_out[i])
            );
            end
        end
    endgenerate
endmodule
