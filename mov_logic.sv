module mov_logic(
    input clk,
    input rst,
    input enabled,
    input [7:0] instruction,
    output logic write_enable,
    output logic [2:0] write_select,
    output logic [2:0] read_select
);
logic internal_write_enable;
logic mismatch_reset;
logic [7:0] register_output;

always_comb begin
    internal_write_enable = &instruction[7:5]; //check for a mov instruction that starts with three high bits
end

mov_logic_register_module instruction_storage(
    .clk(clk),
    .rst(rst),
    .mismatch_rst(mismatch_reset),
    .write_enable(internal_write_enable),
    .data_in(instruction),
    .data_out(register_output)
);

always_comb begin
    if(enabled) begin
        if(register_output[7:4] == 4'b1110) begin //Mov1 instruction
        mismatch_reset = 1'b0;
            if(instruction[7:4] == 4'b1111) begin //Mov2 instruction the clk cycle after move1, but ignore the special stall command
                write_enable = 1'b1;
                write_select = register_output[3:1]; //Destination in MOV1
                read_select = instruction[3:1]; //Source in MOV2
                mismatch_reset = 1'b0;
            end else if(instruction[7:4] == 4'b1110) begin// if getting a mov1 after another mov1 simply allow the register to ovewrite it.
                write_enable = 1'b0;
                write_select = 3'b000;
                read_select = 3'b000;
                mismatch_reset = 1'b0;
            end else begin //only when followed up by another instruction other than mov1 or mov2 do you do nothing a reset the register.
                write_enable = 1'b0;
                write_select = 3'b000;
                read_select = 3'b000;
                mismatch_reset = 1'b1;
            end
        end else begin
            write_enable = 1'b0;
            write_select = 3'b000;
            read_select = 3'b000;
            mismatch_reset = 1'b0;
        end
    end else begin
        write_enable = 1'b0;
        write_select = 3'b000;
        read_select = 3'b000;
        mismatch_reset = 1'b0;
    end
end


endmodule
