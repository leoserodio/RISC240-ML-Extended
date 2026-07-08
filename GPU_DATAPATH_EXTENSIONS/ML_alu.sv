/*
 * File: ML_alu.sv
 *
 * ALU module containing ai/ml operations.
 */
`include "constants.sv"

// No flags here
module vector_alu (
   output logic [63:0] out,
   input  logic [63:0] inA,
   input  logic [63:0] inB,
   input  vec_op_t     opcode
); // copy 18-240 alu.sv structure

   always_comb begin
      out = 64'b0;

      case (opcode)
         VEC_ADD: begin
            for (int i = 0; i < 8; i++)
            // inA[i*8 +: 8] => starting at bit i*8, give me the next 8 bits (i=0 => inA[7:0])
               out[i*8 +: 8] = inA[i*8 +: 8] + inB[i*8 +: 8]; 
         end

         VEC_MUL: begin
            for (int i = 0; i < 8; i++)
               out[i*8 +: 8] = inA[i*8 +: 8] * inB[i*8 +: 8];
         end

         VEC_RELU: begin
            for (int i = 0; i < 8; i++) begin
               if (inA[i*8 + 7])
                  out[i*8 +: 8] = 8'b0; // negative => 0
               else
                  out[i*8 +: 8] = inA[i*8 +: 8]; // else keep
            end
         end

         VEC_PASS: begin
            out = inA;
         end

         default: out = 64'b0;
      endcase
   end

endmodule : vector_alu