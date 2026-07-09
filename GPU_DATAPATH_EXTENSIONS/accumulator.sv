/*
 * File: accumulator.sv 
 *
 * Accumulator register with adder and synchronous clear.
 */

module accumulator (
    output logic signed [31:0] out,

    input  logic signed [31:0] in,
    input  logic               load_L,
    input  logic               clear,

    input  logic               clock,
    input  logic               reset_L
);
    
    logic signed [31:0] acc_sum;

    Adder #(.WIDTH(32)) accAdder(
        .A(out),
        .B(in),
        .cin(1'b0),
        .sum(acc_sum),
        .cout()
    );

    always_ff @(posedge clock, negedge reset_L) begin
        if (~reset_L)
            out <= 32'sd0;
        else if (clear)
            out <= 32'sd0;
        else if (~load_L)
            out <= acc_sum;
    end

endmodule : accumulator