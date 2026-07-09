/*
 * File: constants.v (.sv now)
 * Created: 4/5/1998
 * Modules contained: none
 *
 * Changelog:
 * 4/16/2001: Removed additions from last semester for this term (verBurg)
 * 4/16/2001: Added the "addsp" instruction. (verBurg)
 * 3 October 2009: Fixed spacing (mcbender)
 * 13 October 2009: Removed tabs (mcbender)
 * 18 October 2009: Changed some names to caps (mcbender)
 * 23 October 2009: Changed all parameters to    and renamed params.v to defs.v
 * 31 October 2009: Renamed to constants.v
 * 13 Oct 2010: Updated always to always_comb and always_ff.Renamed to.sv(abeera)
 * 17 Oct 2010: Updated to use enums instead of   's (iclanton)
 * 24 Oct 2010: Added controlPts struct (abeera)
 * 9  Nov 2010: Slightly modified variable names (abeera)
 * 15 Apr 2014: This is now the only file that needs the `define synthesis (mrrosen)
 * 8  Mar 2019: Changed to fit RISC240 spec (pbannai)
 * 9  Apr 2019: Removing unnecessary ALU ops (saugatag)
 * 14 Apr 2019: Updating state values for consistency with sim240 (saugatag)
 * 8 July 2026: Updated to account for new ML functionality (lserodio)
 */



// Comment this line when simulating, uncomment when synthesizing.
//`define synthesis

`ifndef sv_CONSTANTS
`define sv_CONSTANTS

// *****************************************************************
// ML ADDITIONS START HERE
// MAR write source
typedef enum logic {
   MAR_FROM_ALU   = 1'b0,
   MAR_INCREMENT  = 1'b1
} mar_src_t; // MAR write source
typedef enum logic{ // Vector register write source
   VEC_WRITE_ALU  = 1'b0,
   VEC_WRITE_LOAD = 1'b1
} vec_write_src_t; // Vector register write source
// Vector register write operation
typedef enum logic{
   LOAD_VEC_REG = 1'b0,
   NO_VEC_REG   = 1'b1
} vec_reg_load_t; // Vector register write operation

// Accumulator load operation
typedef enum logic{
   LOAD_ACC     = 1'b0,
   NO_ACC_LOAD  = 1'b1
} acc_load_t; // Accumulator load operation

// Accumulator clear operation
typedef enum logic{
   NO_ACC_CLEAR = 1'b0,
   CLEAR_ACC    = 1'b1
} acc_clear_t; // Accumulator clear operation

// Vector lane select
typedef enum logic [1:0]{
   VEC_LANE0     = 2'b00,
   VEC_LANE1     = 2'b01,
   VEC_LANE2     = 2'b10,
   VEC_LANE3     = 2'b11,
   VEC_LANE_UNDEF = 2'bxx
} vec_lane_t; // Vector lane select

// Load vector lane operation
typedef enum logic{
   LOAD_VEC_LANE = 1'b0,
   NO_VEC_LANE   = 1'b1
} vec_lane_load_t; // Load vector lane operation

// Clear vector load register operation
typedef enum logic{
   NO_VEC_CLEAR  = 1'b0,
   CLEAR_VEC_LOAD = 1'b1
} vec_clear_t; // Clear vector load register operation

// ML ADDITIONS END HERE
// *****************************************************************

typedef enum logic[3:0]{ // ALU operation select
   F_A_PLUS_B    = 4'b0000,
   F_A_MINUS_B   = 4'b0001,
   F_A           = 4'b0010,
   F_B           = 4'b0011,
   F_A_PLUS_2    = 4'b0100,
   F_A_LT_B      = 4'b0101,
   // 4'b0110 reserved for future operations
   // 4'b0111 reserved for future operations
   F_A_NOT       = 4'b1000,
   F_A_AND_B     = 4'b1001,
   F_A_OR_B      = 4'b1010,
   F_A_XOR_B     = 4'b1011,
   F_A_SHL       = 4'b1100,
   // 4'b1101 reserved for future operations
   F_A_LSHR      = 4'b1110,
   F_A_ASHR      = 4'b1111,
   F_UNDEF       = 4'bxxxx
} alu_op_t; // ALU operation select

// Instantiate ML Alu opcode
typedef enum logic [2:0] {
   VEC_ADD  = 3'b000,
   VEC_MUL  = 3'b001,
   VEC_RELU = 3'b010,
   VEC_DOT  = 3'b100,
   VEC_ACLR = 3'b101,
   VEC_PASS = 3'b011,
   VEC_UNDEF = 3'bxxx
} vec_op_t;

// Vector load/store control
typedef enum logic [1:0] {
   VEC_MEM_NONE  = 2'b00,
   VEC_MEM_LOAD  = 2'b01,
   VEC_MEM_STORE = 2'b10,
   VEC_MEM_UNDEF = 2'bxx
} vec_mem_op_t;


typedef enum logic [1:0]{ // ALU input mux select
   MUX_REG       = 2'b00,
   MUX_PC        = 2'b01,
   MUX_MDR       = 2'b10,
   MUX_UNDEF     = 2'bxx
} alu_mux_t; // ALU input mux select

typedef enum logic [2:0]{ // destination select
   DEST_REG      = 3'b000,
   DEST_PC       = 3'b001,
   DEST_MDR      = 3'b010,
   DEST_MAR      = 3'b011,
   DEST_IR       = 3'b100,
   DEST_NONE     = 3'b111,
   DEST_UNDEF    = 3'bxxx
} dest_sel_t; // destination select

typedef enum logic{ // Read memory operation
   MEM_RD        = 1'b0,
   NO_RD         = 1'b1
} rd_enable_t; // Read memory operation

typedef enum logic{ // Write memory operation
   MEM_WR        = 1'b0,
   NO_WR         = 1'b1
} wr_enable_t; // Write memory operation

typedef enum logic{ // Condition code
   LOAD_CC       = 1'b0,
   NO_LOAD       = 1'b1
} cond_code_t; // Condition code

typedef enum logic [6:0] {
// Microcode operations (i.e., FSM states)
   FETCH  = 7'b000_1001,
   FETCH1 = 7'b000_1010,
   FETCH2 = 7'b000_1011,
   DECODE = 7'b000_1111,
   STOP   = 7'b111_1111,
   STOP1  = 7'b100_0001,

// Arithmetic operations: ADD, SUB, ADDI/LI
   ADD    = 7'b000_0000,
   SUB    = 7'b000_1000,
   ADDI   = 7'b001_1000,
   ADDI1  = 7'b001_1001,
   ADDI2  = 7'b001_1010,

// Logical operations: AND, NOT, OR, XOR
   AND    = 7'b100_1000,
   NOT    = 7'b100_0000,
   OR     = 7'b101_0000,
   XOR    = 7'b101_1000,

// Comparison operations: SLT, SLTI
   SLT    = 7'b010_1000,
   SLT1   = 7'b010_1101,
   SLTI   = 7'b010_1001,
   SLTI1  = 7'b010_1010,
   SLTI2  = 7'b010_1011,
   SLTI3  = 7'b010_1100,

// Shift operations: SLL, SLLI, SRA, SRAI, SRL, SRLI
   SLL    = 7'b110_0000,
   SLLI   = 7'b110_0001,
   SLLI1  = 7'b110_0010,
   SLLI2  = 7'b110_0011,
   SRA    = 7'b111_1000,
   SRAI   = 7'b111_1001,
   SRAI1  = 7'b111_1010,
   SRAI2  = 7'b111_1011,
   SRL    = 7'b111_0000,
   SRLI   = 7'b111_0001,
   SRLI1  = 7'b111_0010,
   SRLI2  = 7'b111_0011,

// Load operation: LW
   MV     = 7'b001_0000,
   LW     = 7'b001_0100,
   LW1    = 7'b001_0101,
   LW2    = 7'b001_0110,
   LW3    = 7'b001_0111,
   LW4    = 7'b001_1011,

// Store operation: SW
   SW     = 7'b001_1100,
   SW1    = 7'b001_1101,
   SW2    = 7'b001_1110,
   SW3    = 7'b001_1111,
   SW4    = 7'b010_0000,

// Branch operations: BRA, BRN, BRZ, BRC, BRV, BRNZ
   BRA    = 7'b111_1100,
   BRA1   = 7'b111_1101,
   BRA2   = 7'b111_1110,
   BRN    = 7'b100_1100,
   BRN1   = 7'b100_1101,
   BRN2   = 7'b100_1110,
   BRN3   = 7'b100_1111,
   BRZ    = 7'b110_0100,
   BRZ1   = 7'b110_0101,
   BRZ2   = 7'b110_0110,
   BRZ3   = 7'b110_0111,
   BRC    = 7'b101_0100,
   BRC1   = 7'b101_0101,
   BRC2   = 7'b101_0110,
   BRC3   = 7'b101_0111,
   BRV    = 7'b101_1100,
   BRV1   = 7'b101_1101,
   BRV2   = 7'b101_1110,
   BRV3   = 7'b101_1111,
   BRNZ   = 7'b110_1100,
   BRNZ1  = 7'b110_1101,
   BRNZ2  = 7'b110_1110,
   BRNZ3  = 7'b110_1111,
   
   // Vector operations
   VADD   = 7'b011_0000,
   VMUL   = 7'b011_0001,
   VRELU  = 7'b011_0010,
   VDOT   = 7'b011_0011,
   VACLR  = 7'b011_0100,
   // Vector load
   VLD    = 7'b011_0101,
   VLD1   = 7'b011_0110,
   VLD2   = 7'b011_0111,
   VLD3   = 7'b011_1000,
   VLD4   = 7'b011_1001,
   VLD5   = 7'b011_1010,
   VLD6   = 7'b100_0010,
   VLD7   = 7'b100_0011,
   VLD8   = 7'b100_0100,
   VLD9   = 7'b100_0101,
   VLD10  = 7'b100_0110,
   VLD11  = 7'b100_0111,

   // Vector store
   VST    = 7'b011_1011,
   VST1   = 7'b011_1100,
   VST2   = 7'b011_1101,
   VST3   = 7'b011_1110,
   VST4   = 7'b011_1111,
   VST5   = 7'b100_1000,
   VST6   = 7'b100_1001,
   VST7   = 7'b100_1010,
   VST8   = 7'b100_1011,
   VST9   = 7'b101_0010,
   VST10  = 7'b101_0011,
   

   UNDEF  = 7'bxxx_xxxx

} opcode_t;

typedef struct packed
{
   alu_op_t alu_op;
   vec_op_t vec_op; // ML Alu opcode
   vec_mem_op_t vec_mem_op; // Vector load/store control
   alu_mux_t srcA;
   alu_mux_t srcB;
   dest_sel_t dest;
   cond_code_t lcc_L;
   rd_enable_t re_L;
   wr_enable_t we_L;

   vec_reg_load_t vecRegLoad_L; // separate write enable for the vector register file (independent of the scalar register file)
   acc_load_t accLoad_L; // load accumulator register
   acc_clear_t accClear; // clear accumulator register

   vec_lane_t laneSel; // lane 0-3 for VLOAD/VSTORE
   vec_lane_load_t loadLane_L; // load one 16-bit lane into temporary vector register
   vec_clear_t clearVecLoad; // clear temporary vector load register
   vec_write_src_t vecWriteSrc; // vector register write source

   mar_src_t marSrc; // MAR write source
} controlPts;

`endif

