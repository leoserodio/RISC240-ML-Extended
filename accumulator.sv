// simple accumulator module (adder in front of register)
module accumulator (
    output logic signed [31:0] out,

    input  logic signed [31:0] in,
    input  logic              load_L,
    input  logic              clear,

    input  logic              clock,
    input  logic              reset_L
);

    logic signed [31:0] acc_sum;
    logic signed [31:0] acc_in;

    // Current accumulator value + new dot product
    assign acc_sum = out + in;

    // If clear is high, load 0 instead of adding
    assign acc_in = clear ? 32'sd0 : acc_sum; // signed

    register #(.WIDTH(32)) accReg( // use library.sv module
        .out(out),
        .in(acc_in),
        .load_L(load_L),
        .clock(clock),
        .reset_L(reset_L)
    );

endmodule : accumulator