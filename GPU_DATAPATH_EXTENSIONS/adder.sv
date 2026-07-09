/*
 * File: adder.sv
 *
 * simple adder module
 */

module Adder
    #(parameter WIDTH = 32)
     (input  logic [WIDTH-1:0] A,
      input  logic [WIDTH-1:0] B,
      input  logic cin,
      output logic [WIDTH-1:0] sum,
      output logic cout);

    always_comb begin
        {cout, sum} = A + B + cin;
    end
endmodule : Adder