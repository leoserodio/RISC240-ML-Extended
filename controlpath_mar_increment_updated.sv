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
   // {ALU fn, VEC fn, VecMem fn, AmuxSel, BmuxSel, DestDecode, CCLoad, RE, WE,
   //  VecRegLoad_L, AccLoad_L, AccClear, LaneSel, LoadLane_L, ClearVecLoad, VecWriteSrc, MarSrc}

   always_comb begin
      case (currState)

        FETCH: begin
           out = {F_A, VEC_UNDEF, VEC_MEM_NONE, MUX_PC, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH1;
        end

        FETCH1: begin
           out = {F_A_PLUS_2, VEC_UNDEF, VEC_MEM_NONE, MUX_PC, MUX_UNDEF, DEST_PC, NO_LOAD, MEM_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH2;
        end

        FETCH2: begin
           out = {F_A, VEC_UNDEF, VEC_MEM_NONE, MUX_MDR, MUX_UNDEF, DEST_IR, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = DECODE;
        end

        DECODE: begin
           out = {F_UNDEF, VEC_UNDEF, VEC_MEM_NONE, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = opcode_t'(IRIn[15:9]);
        end

        STOP: begin
           out = {F_UNDEF, VEC_UNDEF, VEC_MEM_NONE, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = STOP1;
        end

        STOP1: begin
           out = {F_UNDEF, VEC_UNDEF, VEC_MEM_NONE, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = STOP1;
`ifndef synthesis
           $display("STOP occurred at time %d", $time);
           $finish;
`endif
        end

        ADD: begin
           out = {F_A_PLUS_B, VEC_UNDEF, VEC_MEM_NONE, MUX_REG, MUX_REG, DEST_REG, LOAD_CC, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end

        SUB: begin
           out = {F_A_MINUS_B, VEC_UNDEF, VEC_MEM_NONE, MUX_REG, MUX_REG, DEST_REG, LOAD_CC, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end
        // ***************************************************************************************************
        // ML ADDITIONS START HERE
        //
        //
        //
        // Vector addition
        VADD: begin
           out = {F_UNDEF, VEC_ADD, VEC_MEM_NONE, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, NO_RD, NO_WR, LOAD_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end
        // Vector Multiplication
        VMUL: begin
           out = {F_UNDEF, VEC_MUL, VEC_MEM_NONE, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, NO_RD, NO_WR, LOAD_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end
        // ReLu functionality
        VRELU: begin
           out = {F_UNDEF, VEC_RELU, VEC_MEM_NONE, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, NO_RD, NO_WR, LOAD_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end

        // Accumulator += dot(vecRS1, vecRS2)
        VDOT: begin
           out = {F_UNDEF, VEC_DOT, VEC_MEM_NONE, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, LOAD_ACC, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end

        // Clear accumulator to 0   
        VACLR: begin
           out = {F_UNDEF, VEC_ACLR, VEC_MEM_NONE, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, CLEAR_ACC, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end

        // Vector load: compute base address, read four 16-bit words, then write assembled vector
        VLD: begin
           out = {F_A, VEC_UNDEF, VEC_MEM_NONE, MUX_PC, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, CLEAR_VEC_LOAD, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = VLD1;
        end

        VLD1: begin
           out = {F_A_PLUS_2, VEC_UNDEF, VEC_MEM_NONE, MUX_PC, MUX_UNDEF, DEST_PC, NO_LOAD, MEM_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = VLD2;
        end

        VLD2: begin
           out = {F_A_PLUS_B, VEC_UNDEF, VEC_MEM_NONE, MUX_REG, MUX_MDR, DEST_MAR, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = VLD3;
        end

        VLD3: begin
           out = {F_UNDEF, VEC_UNDEF, VEC_MEM_LOAD, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, MEM_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = VLD4;
        end

        VLD4: begin
           out = {F_UNDEF, VEC_UNDEF, VEC_MEM_LOAD, MUX_UNDEF, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, LOAD_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_INCREMENT};
           nextState = VLD5;
        end

        VLD5: begin
           out = {F_UNDEF, VEC_UNDEF, VEC_MEM_LOAD, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, MEM_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE1, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = VLD6;
        end

        VLD6: begin
           out = {F_UNDEF, VEC_UNDEF, VEC_MEM_LOAD, MUX_UNDEF, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE1, LOAD_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_INCREMENT};
           nextState = VLD7;
        end

        VLD7: begin
           out = {F_UNDEF, VEC_UNDEF, VEC_MEM_LOAD, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, MEM_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE2, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = VLD8;
        end

        VLD8: begin
           out = {F_UNDEF, VEC_UNDEF, VEC_MEM_LOAD, MUX_UNDEF, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE2, LOAD_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_INCREMENT};
           nextState = VLD9;
        end

        VLD9: begin
           out = {F_UNDEF, VEC_UNDEF, VEC_MEM_LOAD, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, MEM_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE3, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = VLD10;
        end

        VLD10: begin
           out = {F_UNDEF, VEC_UNDEF, VEC_MEM_LOAD, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE3, LOAD_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = VLD11;
        end

        VLD11: begin
           out = {F_UNDEF, VEC_UNDEF, VEC_MEM_LOAD, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, NO_RD, NO_WR, LOAD_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_LOAD, MAR_FROM_ALU};
           nextState = FETCH;
        end

        // Vector store: compute base address, then write four 16-bit lanes
        VST: begin
           out = {F_A, VEC_UNDEF, VEC_MEM_NONE, MUX_PC, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = VST1;
        end

        VST1: begin
           out = {F_A_PLUS_2, VEC_UNDEF, VEC_MEM_NONE, MUX_PC, MUX_UNDEF, DEST_PC, NO_LOAD, MEM_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = VST2;
        end

        VST2: begin
           out = {F_A_PLUS_B, VEC_UNDEF, VEC_MEM_NONE, MUX_REG, MUX_MDR, DEST_MAR, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = VST3;
        end

        VST3: begin
           out = {F_UNDEF, VEC_UNDEF, VEC_MEM_STORE, MUX_UNDEF, MUX_UNDEF, DEST_MDR, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = VST4;
        end

        VST4: begin
           out = {F_UNDEF, VEC_UNDEF, VEC_MEM_STORE, MUX_UNDEF, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, MEM_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_INCREMENT};
           nextState = VST5;
        end

        VST5: begin
           out = {F_UNDEF, VEC_UNDEF, VEC_MEM_STORE, MUX_UNDEF, MUX_UNDEF, DEST_MDR, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE1, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = VST6;
        end

        VST6: begin
           out = {F_UNDEF, VEC_UNDEF, VEC_MEM_STORE, MUX_UNDEF, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, MEM_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE1, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_INCREMENT};
           nextState = VST7;
        end

        VST7: begin
           out = {F_UNDEF, VEC_UNDEF, VEC_MEM_STORE, MUX_UNDEF, MUX_UNDEF, DEST_MDR, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE2, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = VST8;
        end

        VST8: begin
           out = {F_UNDEF, VEC_UNDEF, VEC_MEM_STORE, MUX_UNDEF, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, MEM_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE2, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_INCREMENT};
           nextState = VST9;
        end

        VST9: begin
           out = {F_UNDEF, VEC_UNDEF, VEC_MEM_STORE, MUX_UNDEF, MUX_UNDEF, DEST_MDR, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE3, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = VST10;
        end

        VST10: begin
           out = {F_UNDEF, VEC_UNDEF, VEC_MEM_STORE, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, NO_RD, MEM_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE3, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end
        // ML ADDITION END HERE
        //
        //
        //
        // ***************************************************************************************************
        BRA: begin
           out = {F_A, VEC_UNDEF, VEC_MEM_NONE, MUX_PC, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = BRA1;
        end

        BRA1: begin
           out = {F_UNDEF, VEC_UNDEF, VEC_MEM_NONE, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, MEM_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = BRA2;
        end

        BRA2: begin
           out = {F_A, VEC_UNDEF, VEC_MEM_NONE, MUX_MDR, MUX_UNDEF, DEST_PC, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end

        BRN: begin
           out = {F_A, VEC_UNDEF, VEC_MEM_NONE, MUX_PC, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           if (N) nextState = BRN2;
           else   nextState = BRN1;
        end

        BRN1: begin
           out = {F_A_PLUS_2, VEC_UNDEF, VEC_MEM_NONE, MUX_PC, MUX_UNDEF, DEST_PC, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end

        BRN2: begin
           out = {F_UNDEF, VEC_UNDEF, VEC_MEM_NONE, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, MEM_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = BRN3;
        end

        BRN3: begin
           out = {F_A, VEC_UNDEF, VEC_MEM_NONE, MUX_MDR, MUX_UNDEF, DEST_PC, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end

        BRZ: begin
           out = {F_A, VEC_UNDEF, VEC_MEM_NONE, MUX_PC, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           if (Z) nextState = BRZ2;
           else   nextState = BRZ1;
        end

        BRZ1: begin
           out = {F_A_PLUS_2, VEC_UNDEF, VEC_MEM_NONE, MUX_PC, MUX_UNDEF, DEST_PC, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end

        BRZ2: begin
           out = {F_UNDEF, VEC_UNDEF, VEC_MEM_NONE, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, MEM_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = BRZ3;
        end

        BRZ3: begin
           out = {F_A, VEC_UNDEF, VEC_MEM_NONE, MUX_MDR, MUX_UNDEF, DEST_PC, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end

        BRC: begin
           out = {F_A, VEC_UNDEF, VEC_MEM_NONE, MUX_PC, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           if (C) nextState = BRC2;
           else   nextState = BRC1;
        end

        BRC1: begin
           out = {F_A_PLUS_2, VEC_UNDEF, VEC_MEM_NONE, MUX_PC, MUX_UNDEF, DEST_PC, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end

        BRC2: begin
           out = {F_UNDEF, VEC_UNDEF, VEC_MEM_NONE, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, MEM_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = BRC3;
        end

        BRC3: begin
           out = {F_A, VEC_UNDEF, VEC_MEM_NONE, MUX_MDR, MUX_UNDEF, DEST_PC, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end

        BRV: begin
           out = {F_A, VEC_UNDEF, VEC_MEM_NONE, MUX_PC, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           if (V) nextState = BRV2;
           else   nextState = BRV1;
        end

        BRV1: begin
           out = {F_A_PLUS_2, VEC_UNDEF, VEC_MEM_NONE, MUX_PC, MUX_UNDEF, DEST_PC, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end

        BRV2: begin
           out = {F_UNDEF, VEC_UNDEF, VEC_MEM_NONE, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, MEM_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = BRV3;
        end

        BRV3: begin
           out = {F_A, VEC_UNDEF, VEC_MEM_NONE, MUX_MDR, MUX_UNDEF, DEST_PC, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end

        BRNZ: begin
           out = {F_A, VEC_UNDEF, VEC_MEM_NONE, MUX_PC, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           if (N | Z) nextState = BRNZ2;
           else       nextState = BRNZ1;
        end

        BRNZ1: begin
           out = {F_A_PLUS_2, VEC_UNDEF, VEC_MEM_NONE, MUX_PC, MUX_UNDEF, DEST_PC, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end

        BRNZ2: begin
           out = {F_UNDEF, VEC_UNDEF, VEC_MEM_NONE, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, MEM_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = BRNZ3;
        end

        BRNZ3: begin
           out = {F_A, VEC_UNDEF, VEC_MEM_NONE, MUX_MDR, MUX_UNDEF, DEST_PC, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end

        AND: begin
           out = {F_A_AND_B, VEC_UNDEF, VEC_MEM_NONE, MUX_REG, MUX_REG, DEST_REG, LOAD_CC, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end

        NOT: begin
           out = {F_A_NOT, VEC_UNDEF, VEC_MEM_NONE, MUX_REG, MUX_UNDEF, DEST_REG, LOAD_CC, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end

        OR: begin
           out = {F_A_OR_B, VEC_UNDEF, VEC_MEM_NONE, MUX_REG, MUX_REG, DEST_REG, LOAD_CC, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end

        XOR: begin
           out = {F_A_XOR_B, VEC_UNDEF, VEC_MEM_NONE, MUX_REG, MUX_REG, DEST_REG, LOAD_CC, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end

        SLL: begin
           out = {F_A_SHL, VEC_UNDEF, VEC_MEM_NONE, MUX_REG, MUX_REG, DEST_REG, LOAD_CC, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end

        SLLI: begin
           out = {F_A, VEC_UNDEF, VEC_MEM_NONE, MUX_PC, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = SLLI1;
        end

        SLLI1: begin
           out = {F_A_PLUS_2, VEC_UNDEF, VEC_MEM_NONE, MUX_PC, MUX_UNDEF, DEST_PC, NO_LOAD, MEM_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = SLLI2;
        end

        SLLI2: begin
           out = {F_A_SHL, VEC_UNDEF, VEC_MEM_NONE, MUX_REG, MUX_MDR, DEST_REG, LOAD_CC, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end

        SRA: begin
           out = {F_A_ASHR, VEC_UNDEF, VEC_MEM_NONE, MUX_REG, MUX_REG, DEST_REG, LOAD_CC, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end

        SRAI: begin
           out = {F_A, VEC_UNDEF, VEC_MEM_NONE, MUX_PC, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = SRAI1;
        end

        SRAI1: begin
           out = {F_A_PLUS_2, VEC_UNDEF, VEC_MEM_NONE, MUX_PC, MUX_UNDEF, DEST_PC, NO_LOAD, MEM_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = SRAI2;
        end

        SRAI2: begin
           out = {F_A_ASHR, VEC_UNDEF, VEC_MEM_NONE, MUX_REG, MUX_MDR, DEST_REG, LOAD_CC, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end

        SRL: begin
           out = {F_A_LSHR, VEC_UNDEF, VEC_MEM_NONE, MUX_REG, MUX_REG, DEST_REG, LOAD_CC, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end

        SRLI: begin
           out = {F_A, VEC_UNDEF, VEC_MEM_NONE, MUX_PC, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = SRLI1;
        end

        SRLI1: begin
           out = {F_A_PLUS_2, VEC_UNDEF, VEC_MEM_NONE, MUX_PC, MUX_UNDEF, DEST_PC, NO_LOAD, MEM_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = SRLI2;
        end

        SRLI2: begin
           out = {F_A_LSHR, VEC_UNDEF, VEC_MEM_NONE, MUX_REG, MUX_MDR, DEST_REG, LOAD_CC, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end

        SLT: begin
           out = {F_A_MINUS_B, VEC_UNDEF, VEC_MEM_NONE, MUX_REG, MUX_REG, DEST_NONE, LOAD_CC, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = SLT1;
        end

        SLT1: begin
           out = {F_A_LT_B, VEC_UNDEF, VEC_MEM_NONE, MUX_REG, MUX_REG, DEST_REG, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end

        SLTI: begin
           out = {F_A, VEC_UNDEF, VEC_MEM_NONE, MUX_PC, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = SLTI1;
        end

        SLTI1: begin
           out = {F_A_PLUS_2, VEC_UNDEF, VEC_MEM_NONE, MUX_PC, MUX_UNDEF, DEST_PC, NO_LOAD, MEM_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = SLTI2;
        end

        SLTI2: begin
           out = {F_A_MINUS_B, VEC_UNDEF, VEC_MEM_NONE, MUX_REG, MUX_MDR, DEST_NONE, LOAD_CC, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = SLTI3;
        end

        SLTI3: begin
           out = {F_A_LT_B, VEC_UNDEF, VEC_MEM_NONE, MUX_REG, MUX_MDR, DEST_REG, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end

        MV: begin
           out = {F_A, VEC_UNDEF, VEC_MEM_NONE, MUX_REG, MUX_UNDEF, DEST_REG, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end

        ADDI: begin
           out = {F_A, VEC_UNDEF, VEC_MEM_NONE, MUX_PC, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = ADDI1;
        end

        ADDI1: begin
           out = {F_A_PLUS_2, VEC_UNDEF, VEC_MEM_NONE, MUX_PC, MUX_UNDEF, DEST_PC, NO_LOAD, MEM_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = ADDI2;
        end

        ADDI2: begin
           out = {F_A_PLUS_B, VEC_UNDEF, VEC_MEM_NONE, MUX_REG, MUX_MDR, DEST_REG, LOAD_CC, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end

        LW: begin
           out = {F_A, VEC_UNDEF, VEC_MEM_NONE, MUX_PC, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = LW1;
        end

        LW1: begin
           out = {F_A_PLUS_2, VEC_UNDEF, VEC_MEM_NONE, MUX_PC, MUX_UNDEF, DEST_PC, NO_LOAD, MEM_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = LW2;
        end

        LW2: begin
           out = {F_A_PLUS_B, VEC_UNDEF, VEC_MEM_NONE, MUX_REG, MUX_MDR, DEST_MAR, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = LW3;
        end

        LW3: begin
           out = {F_UNDEF, VEC_UNDEF, VEC_MEM_NONE, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, MEM_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = LW4;
        end

        LW4: begin
           out = {F_A, VEC_UNDEF, VEC_MEM_NONE, MUX_MDR, MUX_UNDEF, DEST_REG, LOAD_CC, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end

        SW: begin
           out = {F_A, VEC_UNDEF, VEC_MEM_NONE, MUX_PC, MUX_UNDEF, DEST_MAR, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = SW1;
        end

        SW1: begin
           out = {F_A_PLUS_2, VEC_UNDEF, VEC_MEM_NONE, MUX_PC, MUX_UNDEF, DEST_PC, NO_LOAD, MEM_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = SW2;
        end

        SW2: begin
           out = {F_A_PLUS_B, VEC_UNDEF, VEC_MEM_NONE, MUX_REG, MUX_MDR, DEST_MAR, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = SW3;
        end

        SW3: begin
           out = {F_B, VEC_UNDEF, VEC_MEM_NONE, MUX_UNDEF, MUX_REG, DEST_MDR, NO_LOAD, NO_RD, NO_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = SW4;
        end

        SW4: begin
           out = {F_UNDEF, VEC_UNDEF, VEC_MEM_NONE, MUX_UNDEF, MUX_UNDEF, DEST_NONE, NO_LOAD, NO_RD, MEM_WR, NO_VEC_REG, NO_ACC_LOAD, NO_ACC_CLEAR, VEC_LANE0, NO_VEC_LANE, NO_VEC_CLEAR, VEC_WRITE_ALU, MAR_FROM_ALU};
           nextState = FETCH;
        end

        default: begin
           out = 'x;
           nextState = FETCH;
        end

      endcase
   end

endmodule
