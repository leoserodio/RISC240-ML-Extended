module dot_product_unit (
    output logic signed [31:0] out,
    input  logic [63:0] inA,
    input  logic [63:0] inB
);

    // mult 8-bit by 8-bit yields 16-bit, 
    // and dot product is adding 8 16-bit vals to we make it 32-bit (notice its technically unecessary)
    logic signed [15:0] product;
    
    // 8 parallel multipliers and an adder
    always_comb begin
        out = 32'sd0;
        // inA[i*8 +: 8] => starting at bit i*8, give me the next 8 bits (i=0 => inA[7:0])
        for (int i = 0; i < 8; i = i + 1) begin
            product = $signed(inA[i*8 +: 8]) * $signed(inB[i*8 +: 8]);
            out = out + product; // accumulate
        end
    end

endmodule : dot_product_unit
