// Most neural nets use signed ints after quantization
module int8_mult (
    input  logic signed [7:0]  A,
    input  logic signed [7:0]  B,
    output logic signed [15:0] P);
    assign P = A * B;
endmodule : int8_mult