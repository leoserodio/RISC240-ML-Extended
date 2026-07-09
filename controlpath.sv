/*
 * File: controlpath.sv
 */

`include "constants.sv" 

module controlpath (
   input [3:0]       CCin,
   input [15:0]      IRIn,
   output controlPts out,
   output opcode_t currState,
   output opcode_t nextState,
   input             clock,
   input             reset_L
);

   logic Z, C, N, V;
   assign {Z, C, N, V} = CCin;

   always_ff @(posedge clock or negedge reset_L)
      if (~reset_L)
         currState <= FETCH;
      else
         currState <= nextState;

   // Control point order:
   // {ALU fn, VEC fn, AmuxSel, BmuxSel, DestDecode, CCLoad, RE, WE,
   //  VecRegLoad_L, AccLoad_L, AccClear}

   always_comb begin
      case (currState)

        FETCH: begin
           out = {F_A, VEC_UNDEF, MUX_PC, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = FETCH1;
        end

        FETCH1: begin
           out = {F_A_PLUS_2, VEC_UNDEF, MUX_PC, MUX_UNDEF, DEST_PC, NO_LOAD, MEM_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = FETCH2;
        end

        FETCH2: begin
           out = {F_A, VEC_UNDEF, MUX_MDR, MUX_UNDEF, DEST_IR, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = DECODE;
        end

        DECODE: begin
           out = {F_UNDEF, VEC_UNDEF, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = opcode_t'(IRIn[15:9]);
        end

        STOP: begin
           out = {F_UNDEF, VEC_UNDEF, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = STOP1;
        end

        STOP1: begin
           out = {F_UNDEF, VEC_UNDEF, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = STOP1;
`ifndef synthesis
           $display("STOP occurred at time %d", $time);
           $finish;
`endif
        end

        ADD: begin
           out = {F_A_PLUS_B, VEC_UNDEF, MUX_REG, MUX_REG, DEST_REG, LOAD_CC, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = FETCH;
        end

        SUB: begin
           out = {F_A_MINUS_B, VEC_UNDEF, MUX_REG, MUX_REG, DEST_REG, LOAD_CC, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = FETCH;
        end
        // ***************************************************************************************************
        // ML ADDITIONS START HERE
        //
        //
        //
        // Vector addition
        VADD: begin
           out = {F_UNDEF, VEC_ADD, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, NO_RD, NO_WR, 1'b0, 1'b1, 1'b0};
           nextState = FETCH;
        end
        // Vector Multiplication
        VMUL: begin
           out = {F_UNDEF, VEC_MUL, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, NO_RD, NO_WR, 1'b0, 1'b1, 1'b0};
           nextState = FETCH;
        end
        // ReLU functionality
        VRELU: begin
           out = {F_UNDEF, VEC_RELU, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, NO_RD, NO_WR, 1'b0, 1'b1, 1'b0};
           nextState = FETCH;
        end

        // Accumulator += dot(vecRS1, vecRS2)
        VDOT: begin
           out = {F_UNDEF, VEC_DOT, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b0, 1'b0};
           nextState = FETCH;
        end

        // Clear accumulator to 0   
        VACLR: begin
           out = {F_UNDEF, VEC_ACLR, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b1};
           nextState = FETCH;
        end
        // ML ADDITION END HERE
        //
        //
        //
        // ***************************************************************************************************
        BRA: begin
           out = {F_A, VEC_UNDEF, MUX_PC, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = BRA1;
        end

        BRA1: begin
           out = {F_UNDEF, VEC_UNDEF, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, MEM_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = BRA2;
        end

        BRA2: begin
           out = {F_A, VEC_UNDEF, MUX_MDR, MUX_UNDEF, DEST_PC, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = FETCH;
        end

        BRN: begin
           out = {F_A, VEC_UNDEF, MUX_PC, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           if (N) nextState = BRN2;
           else   nextState = BRN1;
        end

        BRN1: begin
           out = {F_A_PLUS_2, VEC_UNDEF, MUX_PC, MUX_UNDEF, DEST_PC, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = FETCH;
        end

        BRN2: begin
           out = {F_UNDEF, VEC_UNDEF, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, MEM_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = BRN3;
        end

        BRN3: begin
           out = {F_A, VEC_UNDEF, MUX_MDR, MUX_UNDEF, DEST_PC, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = FETCH;
        end

        BRZ: begin
           out = {F_A, VEC_UNDEF, MUX_PC, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           if (Z) nextState = BRZ2;
           else   nextState = BRZ1;
        end

        BRZ1: begin
           out = {F_A_PLUS_2, VEC_UNDEF, MUX_PC, MUX_UNDEF, DEST_PC, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = FETCH;
        end

        BRZ2: begin
           out = {F_UNDEF, VEC_UNDEF, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, MEM_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = BRZ3;
        end

        BRZ3: begin
           out = {F_A, VEC_UNDEF, MUX_MDR, MUX_UNDEF, DEST_PC, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = FETCH;
        end

        BRC: begin
           out = {F_A, VEC_UNDEF, MUX_PC, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           if (C) nextState = BRC2;
           else   nextState = BRC1;
        end

        BRC1: begin
           out = {F_A_PLUS_2, VEC_UNDEF, MUX_PC, MUX_UNDEF, DEST_PC, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = FETCH;
        end

        BRC2: begin
           out = {F_UNDEF, VEC_UNDEF, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, MEM_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = BRC3;
        end

        BRC3: begin
           out = {F_A, VEC_UNDEF, MUX_MDR, MUX_UNDEF, DEST_PC, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = FETCH;
        end

        BRV: begin
           out = {F_A, VEC_UNDEF, MUX_PC, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           if (V) nextState = BRV2;
           else   nextState = BRV1;
        end

        BRV1: begin
           out = {F_A_PLUS_2, VEC_UNDEF, MUX_PC, MUX_UNDEF, DEST_PC, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = FETCH;
        end

        BRV2: begin
           out = {F_UNDEF, VEC_UNDEF, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, MEM_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = BRV3;
        end

        BRV3: begin
           out = {F_A, VEC_UNDEF, MUX_MDR, MUX_UNDEF, DEST_PC, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = FETCH;
        end

        BRNZ: begin
           out = {F_A, VEC_UNDEF, MUX_PC, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           if (N | Z) nextState = BRNZ2;
           else       nextState = BRNZ1;
        end

        BRNZ1: begin
           out = {F_A_PLUS_2, VEC_UNDEF, MUX_PC, MUX_UNDEF, DEST_PC, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = FETCH;
        end

        BRNZ2: begin
           out = {F_UNDEF, VEC_UNDEF, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, MEM_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = BRNZ3;
        end

        BRNZ3: begin
           out = {F_A, VEC_UNDEF, MUX_MDR, MUX_UNDEF, DEST_PC, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = FETCH;
        end

        AND: begin
           out = {F_A_AND_B, VEC_UNDEF, MUX_REG, MUX_REG, DEST_REG, LOAD_CC, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = FETCH;
        end

        NOT: begin
           out = {F_A_NOT, VEC_UNDEF, MUX_REG, MUX_UNDEF, DEST_REG, LOAD_CC, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = FETCH;
        end

        OR: begin
           out = {F_A_OR_B, VEC_UNDEF, MUX_REG, MUX_REG, DEST_REG, LOAD_CC, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = FETCH;
        end

        XOR: begin
           out = {F_A_XOR_B, VEC_UNDEF, MUX_REG, MUX_REG, DEST_REG, LOAD_CC, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = FETCH;
        end

        SLL: begin
           out = {F_A_SHL, VEC_UNDEF, MUX_REG, MUX_REG, DEST_REG, LOAD_CC, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = FETCH;
        end

        SLLI: begin
           out = {F_A, VEC_UNDEF, MUX_PC, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = SLLI1;
        end

        SLLI1: begin
           out = {F_A_PLUS_2, VEC_UNDEF, MUX_PC, MUX_UNDEF, DEST_PC, NO_LOAD, MEM_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = SLLI2;
        end

        SLLI2: begin
           out = {F_A_SHL, VEC_UNDEF, MUX_REG, MUX_MDR, DEST_REG, LOAD_CC, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = FETCH;
        end

        SRA: begin
           out = {F_A_ASHR, VEC_UNDEF, MUX_REG, MUX_REG, DEST_REG, LOAD_CC, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = FETCH;
        end

        SRAI: begin
           out = {F_A, VEC_UNDEF, MUX_PC, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = SRAI1;
        end

        SRAI1: begin
           out = {F_A_PLUS_2, VEC_UNDEF, MUX_PC, MUX_UNDEF, DEST_PC, NO_LOAD, MEM_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = SRAI2;
        end

        SRAI2: begin
           out = {F_A_ASHR, VEC_UNDEF, MUX_REG, MUX_MDR, DEST_REG, LOAD_CC, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = FETCH;
        end

        SRL: begin
           out = {F_A_LSHR, VEC_UNDEF, MUX_REG, MUX_REG, DEST_REG, LOAD_CC, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = FETCH;
        end

        SRLI: begin
           out = {F_A, VEC_UNDEF, MUX_PC, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = SRLI1;
        end

        SRLI1: begin
           out = {F_A_PLUS_2, VEC_UNDEF, MUX_PC, MUX_UNDEF, DEST_PC, NO_LOAD, MEM_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = SRLI2;
        end

        SRLI2: begin
           out = {F_A_LSHR, VEC_UNDEF, MUX_REG, MUX_MDR, DEST_REG, LOAD_CC, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = FETCH;
        end

        SLT: begin
           out = {F_A_MINUS_B, VEC_UNDEF, MUX_REG, MUX_REG, DEST_NONE, LOAD_CC, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = SLT1;
        end

        SLT1: begin
           out = {F_A_LT_B, VEC_UNDEF, MUX_REG, MUX_REG, DEST_REG, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = FETCH;
        end

        SLTI: begin
           out = {F_A, VEC_UNDEF, MUX_PC, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = SLTI1;
        end

        SLTI1: begin
           out = {F_A_PLUS_2, VEC_UNDEF, MUX_PC, MUX_UNDEF, DEST_PC, NO_LOAD, MEM_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = SLTI2;
        end

        SLTI2: begin
           out = {F_A_MINUS_B, VEC_UNDEF, MUX_REG, MUX_MDR, DEST_NONE, LOAD_CC, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = SLTI3;
        end

        SLTI3: begin
           out = {F_A_LT_B, VEC_UNDEF, MUX_REG, MUX_MDR, DEST_REG, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = FETCH;
        end

        MV: begin
           out = {F_A, VEC_UNDEF, MUX_REG, MUX_UNDEF, DEST_REG, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = FETCH;
        end

        ADDI: begin
           out = {F_A, VEC_UNDEF, MUX_PC, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = ADDI1;
        end

        ADDI1: begin
           out = {F_A_PLUS_2, VEC_UNDEF, MUX_PC, MUX_UNDEF, DEST_PC, NO_LOAD, MEM_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = ADDI2;
        end

        ADDI2: begin
           out = {F_A_PLUS_B, VEC_UNDEF, MUX_REG, MUX_MDR, DEST_REG, LOAD_CC, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = FETCH;
        end

        LW: begin
           out = {F_A, VEC_UNDEF, MUX_PC, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = LW1;
        end

        LW1: begin
           out = {F_A_PLUS_2, VEC_UNDEF, MUX_PC, MUX_UNDEF, DEST_PC, NO_LOAD, MEM_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = LW2;
        end

        LW2: begin
           out = {F_A_PLUS_B, VEC_UNDEF, MUX_REG, MUX_MDR, DEST_MAR, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = LW3;
        end

        LW3: begin
           out = {F_UNDEF, VEC_UNDEF, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, MEM_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = LW4;
        end

        LW4: begin
           out = {F_A, VEC_UNDEF, MUX_MDR, MUX_UNDEF, DEST_REG, LOAD_CC, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = FETCH;
        end

        SW: begin
           out = {F_A, VEC_UNDEF, MUX_PC, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = SW1;
        end

        SW1: begin
           out = {F_A_PLUS_2, VEC_UNDEF, MUX_PC, MUX_UNDEF, DEST_PC, NO_LOAD, MEM_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = SW2;
        end

        SW2: begin
           out = {F_A_PLUS_B, VEC_UNDEF, MUX_REG, MUX_MDR, DEST_MAR, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = SW3;
        end

        SW3: begin
           out = {F_B, VEC_UNDEF, MUX_UNDEF, MUX_REG, DEST_MDR, NO_LOAD, NO_RD, NO_WR, 1'b1, 1'b1, 1'b0};
           nextState = SW4;
        end

        SW4: begin
           out = {F_UNDEF, VEC_UNDEF, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, NO_RD, MEM_WR, 1'b1, 1'b1, 1'b0};
           nextState = FETCH;
        end

        default: begin
           out = 'x;
           nextState = FETCH;
        end

      endcase
   end

endmodule