module register_file_8(
    input clk, 
    input rst, //Resets all registers to zero
    input write_enable, //Enables or Disables writing to register file
    input [2:0] write_select,//Selects which register to write to
    input [2:0] read_select_1,//Selects the first register to read from
    input [2:0] read_select_2,//Selects the second register to read from
    input [7:0] data_in,//The data that will be writen to the register (if write_enable is high)
    output [7:0] data_out_1,//The data to be read from the register
    output [7:0] data_out_2//The data to be read from the register
);

logic [7:0] write_decoder_to_registers;//becomes write enable for registers
logic [7:0] read_decoder_1_to_registers;
logic [7:0] read_decoder_2_to_registers;

logic [7:0] register_array_to_mux [7:0];

logic [2:0] write_select_enable;

assign write_select_enable = (write_enable) ? write_select:  3'b0 ;

decoder_3 write_decoder(
    .A(write_select_enable),
    .Y(write_decoder_to_registers)
);

register_array_8 register_array(
    .clk(clk),
    .rst(rst),
    .write_enable(write_decoder_to_registers),
    .data_in(data_in),
    .data_out(register_array_to_mux)
);

mux_8to1 read_mux_1(
    .A(register_array_to_mux),
    .sel(read_select_1),
    .Y(data_out_1)
);

mux_8to1 read_mux_2(
    .A(register_array_to_mux),
    .sel(read_select_2),
    .Y(data_out_2)
);
endmodule
