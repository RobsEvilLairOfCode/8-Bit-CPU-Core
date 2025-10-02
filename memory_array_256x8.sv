module memory_array_256x8(
    input clk,
    input rst,
    input write_enable,
    input [7:0] address,
    input [7:0] data_in,
    output [7:0] data_out
);
    logic [7:0] memory [255:0];

    always_ff @(posedge clk) begin
        if (rst) begin
            for(int i = 0; i < 256; i = i + 1) begin
                /* verilator lint_off BLKSEQ */
                memory[i] = 8'b0;
                /* verilator lint_on BLKSEQ */
            end
        end else begin
            if (write_enable) begin
                memory[address] <= data_in;
            end
        end
    end

    assign data_out = memory[address]; 
endmodule
