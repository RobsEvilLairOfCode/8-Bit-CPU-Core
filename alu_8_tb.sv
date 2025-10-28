`timescale 1ns/1ps

module alu_8_tb;

// ---------------------------------------------------------------------------
// Random Seeding
// ---------------------------------------------------------------------------
int seed = 32'hDEADBEEF; //Default seed

initial begin
      if ($value$plusargs("seed=%d", seed)) $urandom(seed); //check to see if there is a seed in the command line
      $display("Using random seed: %0d", seed);
end
// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------
localparam int WIDTH = 8;

// ---------------------------------------------------------------------------
// Verification Variables
// ---------------------------------------------------------------------------
int successful_operations = 0;
int unsuccessful_operations = 0;


// ---------------------------------------------------------------------------
// DUT Inputs
// ---------------------------------------------------------------------------
logic [WIDTH-1:0] A, B;
logic [2:0] OP;
logic C_in, EN, update_flags;

// ---------------------------------------------------------------------------
// DUT Outputs
// ---------------------------------------------------------------------------
logic [WIDTH-1:0] Y;
logic C_out, Z, N, V;

// ---------------------------------------------------------------------------
// DUT Instance
// ---------------------------------------------------------------------------
alu_8 #(.WIDTH(WIDTH)) dut (
.A(A), .B(B),
.OP(OP),
.C_in(C_in),
.EN(EN),
.update_flags(update_flags),
.Y(Y),
.C_out(C_out),
.Z(Z), .N(N), .V(V)
);

// ---------------------------------------------------------------------------
// Helper tasks
// ---------------------------------------------------------------------------

task automatic check(
input string test,
input [WIDTH-1:0] expected_Y,
input bit expected_Z,
input bit expected_N,
input bit expected_V,
input bit expected_C);

      if (Y !== expected_Y || Z !== expected_Z ||
      N !== expected_N || V !== expected_V ||
      C_out !== expected_C) begin
            $display("[%s] FAILED: got Y=%0h Z=%b N=%b V=%b C=%b, expected Y=%0h Z=%b N=%b V=%b C=%b",
            test, Y, Z, N, V, C_out,
            expected_Y, expected_Z, expected_N, expected_V, expected_C);
            //Update the counter of the number of unsuccessful operations
            unsuccessful_operations++;
      end else begin
            //Update the counter of the number of succesful operations.
            successful_operations++;
      end
endtask

task automatic display_results();
      $display("Number of successful operations: %d",successful_operations);
      $display("Number of unsuccessful operation: %d",unsuccessful_operations);
endtask

// Compute flags for simple ops (software reference)
function automatic bit compute_Z(input [WIDTH-1:0] val);
return (val == '0);
endfunction
function automatic bit compute_N(input [WIDTH-1:0] val);
return val[WIDTH-1];
endfunction

// ---------------------------------------------------------------------------
// Operation-specific tasks
// ---------------------------------------------------------------------------
task automatic add_test(
      input logic [WIDTH-1:0] test_A, test_B,//operands
      input logic test_C_in
);
      logic [WIDTH:0] temp = {1'b0, test_A} + {1'b0, test_B} + {{WIDTH{1'b0}}, test_C_in};             // note: WIDTH+1 to capture carry
      logic [WIDTH-1:0] sum = temp[WIDTH-1:0];
      string test;

      OP = 3'b000;//Add OPCODE
      //Create a name for the test
      $sformat(test, "ADD A=%h B=%h C_in=%h",test_A,test_B,test_C_in);

      #1;//Delay to let the outputs settle
      //check output after
      check(test, sum, compute_Z(sum), compute_N(sum),((test_A[WIDTH-1]==test_B[WIDTH-1])&&( sum[WIDTH-1]!=test_A[WIDTH-1])),temp[WIDTH]);
endtask

task automatic sub_test(
      input logic [WIDTH-1:0] test_A, test_B,//operands
      input logic test_C_in
);
      logic [WIDTH:0] temp = {1'b0, test_A} + {1'b0, ~test_B} + {{WIDTH{1'b0}}, test_C_in};            // note: WIDTH+1 to capture carry
      logic [WIDTH-1:0] diff = temp[WIDTH-1:0];
      string test;

      OP = 3'b001;//Sub OPCODE
      //Create a name for the test
      $sformat(test, "SUB A=%h B=%h C_in=%h",test_A,test_B,test_C_in);

      #1;//Delay to let the outputs settle
      //check output after
      check(test, diff, compute_Z(diff), compute_N(diff),(test_A[WIDTH-1] != test_B[WIDTH-1]) && (diff[WIDTH-1] != test_A[WIDTH-1]),temp[WIDTH]);
endtask

task automatic and_test(
      input logic [WIDTH-1:0] test_A, test_B,//operands
      input logic test_C_in
);
      string test;

      OP = 3'b010;//Sub OPCODE
      //Create a name for the test
      $sformat(test, "AND A=%h B=%h C_in=%h",test_A,test_B,test_C_in);

      #1;//Delay to let the outputs settle
      //check output after
      check(test, test_A & test_B, compute_Z(test_A & test_B), compute_N(test_A & test_B),1'b0,1'b0);
endtask

task automatic or_test(
      input logic [WIDTH-1:0] test_A, test_B,//operands
      input logic test_C_in
);
      string test;

      OP = 3'b011;//Sub OPCODE
      //Create a name for the test
      $sformat(test, "AND A=%h B=%h C_in=%h",test_A,test_B,test_C_in);

      #1;//Delay to let the outputs settle
      //check output after
      check(test, test_A | test_B, compute_Z(test_A | test_B), compute_N(test_A | test_B),1'b0,1'b0);
endtask

task automatic xor_test(
      input logic [WIDTH-1:0] test_A, test_B,//operands
      input logic test_C_in
);
      string test;

      OP = 3'b100;//Sub OPCODE
      //Create a name for the test
      $sformat(test, "XOR A=%h B=%h C_in=%h",test_A,test_B,test_C_in);

      #1;//Delay to let the outputs settle
      //check output after
      check(test, test_A ^ test_B, compute_Z(test_A ^ test_B), compute_N(test_A ^ test_B),1'b0,1'b0);
endtask

task automatic not_test(
      input logic [WIDTH-1:0] test_A, test_B,//operands
      input logic test_C_in
);
      string test;

      OP = 3'b101;//Sub OPCODE
      //Create a name for the test
      $sformat(test, "NOT A=%h B=%h C_in=%h",test_A,test_B,test_C_in);

      #1;//Delay to let the outputs settle
      //check output after
      check(test, ~test_A, compute_Z(~test_A), compute_N(~test_A),1'b0,1'b0);
endtask

task automatic lsl_test(
      input logic [WIDTH-1:0] test_A, test_B,//operands
      input logic test_C_in
);
      logic [WIDTH-1:0] result = test_A << test_B[$clog2(WIDTH) - 1:0];
      string test;

      OP = 3'b110;//Sub OPCODE
      //Create a name for the test
      $sformat(test, "LSL A=%h B=%h (truncates to %d) C_in=%h",test_A,test_B,test_B[$clog2(WIDTH) - 1:0],test_C_in);

      #1;//Delay to let the outputs settle
      //check output after
      check(test, result, compute_Z(result), compute_N(result),1'b0,1'b0);
endtask

task automatic lsr_test(
      input logic [WIDTH-1:0] test_A, test_B,//operands
      input logic test_C_in
);
      logic [WIDTH-1:0] result = test_A >> test_B[$clog2(WIDTH) - 1:0];
      string test;

      OP = 3'b111;//Sub OPCODE
      //Create a name for the test
      $sformat(test, "LSR A=%h B=%h (truncates to %d) C_in=%h",test_A,test_B,test_B[$clog2(WIDTH) - 1:0],test_C_in);

      #1;//Delay to let the outputs settle
      //check output after
      check(test, result, compute_Z(result), compute_N(result),1'b0,1'b0);
endtask

// ---------------------------------------------------------------------------
// Main stimulus
// ---------------------------------------------------------------------------
initial begin
EN = 1;
update_flags = 1;
C_in = 0;


//ADD test
repeat (1000) begin
      /* verilator lint_off WIDTHTRUNC */
      A = $urandom();
      B = $urandom();
      C_in = $urandom();
      add_test(A, B, C_in);
      /* verilator lint_on WIDTHTRUNC */
end

//SUB test
repeat (1000) begin
      /* verilator lint_off WIDTHTRUNC */
      A = $urandom();
      B = $urandom();
      C_in = $urandom();
      sub_test(A, B, C_in);
      /* verilator lint_on WIDTHTRUNC */
end

//AND test
repeat (1000) begin
      /* verilator lint_off WIDTHTRUNC */
      A = $urandom();
      B = $urandom();
      C_in = $urandom();
      and_test(A, B, C_in);
      /* verilator lint_on WIDTHTRUNC */
end

// OR test
repeat (1000) begin
      /* verilator lint_off WIDTHTRUNC */
      A = $urandom();
      B = $urandom();
      C_in = $urandom();
      or_test(A, B, C_in);
      /* verilator lint_on WIDTHTRUNC */
end

// XOR test
repeat (1000) begin
      /* verilator lint_off WIDTHTRUNC */
      A = $urandom();
      B = $urandom();
      C_in = $urandom();
      xor_test(A, B, C_in);
      /* verilator lint_on WIDTHTRUNC */
end

// NOT test
repeat (1000) begin
      /* verilator lint_off WIDTHTRUNC */
      A = $urandom();
      B = $urandom();
      C_in = $urandom();
      not_test(A, B, C_in);
      /* verilator lint_on WIDTHTRUNC */
end

// LSL test
repeat (1000) begin
      /* verilator lint_off WIDTHTRUNC */
      A = $urandom();
      B = $urandom();
      C_in = $urandom();
      lsl_test(A, B, C_in);
      /* verilator lint_on WIDTHTRUNC */
end

// LSR test
repeat (1000) begin
      /* verilator lint_off WIDTHTRUNC */
      A = $urandom();
      B = $urandom();
      C_in = $urandom();
      lsr_test(A, B, C_in);
      /* verilator lint_on WIDTHTRUNC */
end;

// Disabled test
/* verilator lint_off WIDTHTRUNC */
EN = 0; A = $urandom(); B = $urandom(); OP = 3'b000; #1;
/* verilator lint_on WIDTHTRUNC */
if (Y !== '0) $error("[EN disable] FAILED: output not zero when EN=0");

();//record the current value
$display("All ALU tests completed.");
display_results();
$finish;

end

// Optional: waveform dump
initial begin
$dumpfile("tb_alu_8.vcd");
$dumpvars(0, alu_8_tb);

end

endmodule
