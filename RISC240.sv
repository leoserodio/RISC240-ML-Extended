/*
 * File: RISC240.v
 * Created: 11/13/1997
 * Modules contained: RISC240_top
 *
 * Changelog:
 * 9 June 1999 : Added stack pointer
 * 4/16/2001: Reverted to base code. (verBurg)
 * 4/16/2001: Added the "addsp" instruction. (verBurg)
 * 11/26/06: Removed old Altera-specific code that Xilinx tool had trouble with (P. Milder)
 * 3 Oc 2009: Cleaned up coding style and changed module name (mcbender)
 * 13 Oct 2009: Removed tabs and fixed spacing, added negedge trigger (mcbender)
 * 18 Oct 2009: Changed some constant names (mcbender)
 * 23 Oct 2009: Added LEDController (mcbender)
 * 31 Oct 2009: Fixed wire and instance naming style (mcbender)
 * 4 Nov 2009: Modified spacing slightly (mcbender)
 * 17 Nov 2009: Minor modification to facilitate synthesis (mcbender)
 * 13 Oct 2010: Updated always to always_comb and always_ff.Renamed to.sv(abeera)
 * 17 Oct 2010: Updated to use enums instead of define's (iclanton)
 * 24 Oct 2010: Updated to use stuct (abeera)
 * 9  Nov 2010: Slightly modified variable names.
 *               Updated display to use enum (abeera)
 * 17 Apr 2013: Added timeout to simulation, such that simulation stops after 50000 cycles (wnace)
 * 25 Apr 2013: Commented synthesis by default,
 *              changed always_ff to always to remove VCS errors on cycle var (mromanko)
 * 15 Apr 2014: The `define synthesis is now in constants.sv
 * 14 Nov 2014: Memory removed from datapath and instantiated as its own module (wnace)
 * 24 Apr 2018: Changed displays to use ".name" for enum type string arguments (akuntz)
 * 8  Mar 2019: Changed to fit RISC240 specification (pbannai)
 * 11 Apr 2019: Cleanup, memory interface
 * 4  Nov 2019: Modified datapath to fit Altera IP block (synthesis) (mgcai)
 * 3  Dec 2020: Removed integration with Altera IP block (ekusuma)
 * 30 Mar 2025: Made adjustments to comply with RealDigital Boolean Board (vsetty)
 *              Addeded 7SegDriver by rsorense
 *
 * This is the baseline code that should be used at the beginning of
 * every semester.  It is finally all unified and brought up to date
 * (minus coding style differences).
*/

`include "constants.sv"
//Required for simulation, doesn't work in synthesis.
//`default_nettype none

/*
 * module RISC240_top
 *
 * This is the top-level module for our implementation of the RISC240 ISA.
 *
 */
`ifdef synthesis  // When we connect to the FPGA board
module RISC240_top(
  output logic  [3:0] D1_AN, D2_AN,
  output logic  [7:0] D1_SEG, D2_SEG,
  output logic [15:0] LD,
  input  logic  [3:0] BTN,
  input  logic [15:0] SW,
  input  logic        CLOCK_100);
`else  // When we don't connect to anything
module RISC240_top();
`endif

  controlPts cPts;
  logic [3:0]  condCodes;              // condition codes (Z,C,N,V)
  logic [2:0]  selRD, selRS1, selRS2;  // register specification fields
  logic [15:0] aluSrc1, aluSrc2, aluOut, pc, ir, memAddr, memData;
  logic [127:0] regView;
  opcode_t currState, nextState;
  wire [15:0] dataBus;

  // ML stuff
  logic [63:0] vecRS1Out;
  logic [63:0] vecRS2Out;
  logic [63:0] vecAluResultOut;
  logic [63:0] vecWriteDataOut;
  logic signed [31:0] dotResultOut;
  logic signed [31:0] accResultOut;

  logic clock, reset_L;

  logic [15:0] r7, r6, r5, r4, r3, r2, r1, r0;
  assign {r7, r6, r5, r4, r3, r2, r1, r0} = regView;

   controlpath cp(.out(cPts),
                  .CCin(condCodes),
                  .IRIn(ir),
                  .clock(clock),
                  .reset_L(reset_L),
                  .currState(currState),
                  .nextState(nextState));

   datapath dp(.ir(ir),
            .condCodes(condCodes),
            .aluSrcA(aluSrc1),
            .aluSrcB(aluSrc2),
            .viewReg(regView),
            .aluResult(aluOut),
            .pc(pc),
            .memAddr(memAddr),
            .MDRout(memData),

            // ML / vector debug outputs
            .vecRS1Out(vecRS1Out),
            .vecRS2Out(vecRS2Out),
            .vecAluResultOut(vecAluResultOut),
            .vecWriteDataOut(vecWriteDataOut),
            .dotResultOut(dotResultOut),
            .accResultOut(accResultOut),

            .dataBus(dataBus),
            .selRD,
            .selRS1,
            .selRS2,
            .cPts(cPts),
            .clock,
            .reset_L);


   memorySystem memmod(.data(dataBus),
                    .address(memAddr),
                    .re_L(cPts.re_L),
                    .we_L(cPts.we_L),
                    .clock);


/////////////////////
// CLOCK AND RESET //
/////////////////////

`ifdef synthesis
   assign clock   = ~BTN[0]; /* Manual clock. */
   assign reset_L = ~BTN[1];
`else
   initial begin
      reset_L = 1;
      #2;
      reset_L = 0;
      #2;
      reset_L = 1;
   end
   initial begin              //posedge of the clock occurs on multiples of #10
      clock = 1;
      forever #5 clock = ~clock;
   end
`endif

/////////////
// DISPLAY //
/////////////

`ifdef synthesis
  logic  [6:0] HEX7, HEX6, HEX5, HEX4, HEX3, HEX2, HEX1, HEX0;
  logic [15:0] disp1, disp0;

  always_comb begin
    disp1 = 16'h0000; disp0 = 16'h0000;
    case ({SW[15], SW[14]})
      2'b00: begin
               disp1 = pc;
               disp0 = ir;
             end
      2'b01: begin
               disp1 = memAddr;
               disp0 = memData;
             end
      2'b10: begin
               disp1 = r4;
               disp0 = r3;
             end
      2'b11: begin
               disp1 = r2;
               disp0 = r1;
             end
    endcase
  end
  SevenSegmentControl ssc(
                         .HEX7(HEX7),
                         .HEX6(HEX6),
                         .HEX5(HEX5),
                         .HEX4(HEX4),

                         .HEX3(HEX3),
                         .HEX2(HEX2),
                         .HEX1(HEX1),
                         .HEX0(HEX0),
                         .in7(disp1[15:12]),
                         .in6(disp1[11:8]),
                         .in5(disp1[7:4]),
                         .in4(disp1[3:0]),

                         .in3(disp0[15:12]),
                         .in2(disp0[11:8]),
                         .in1(disp0[7:4]),
                         .in0(disp0[3:0]),
                         .turn_on(8'hFF));

  SSegDisplayDriver ssdd(
                         .reset(~reset_L),
                         .clk(CLOCK_100),
                         .HEX7(HEX7),
                         .HEX6(HEX6),
                         .HEX5(HEX5),
                         .HEX4(HEX4),
                         .HEX3(HEX3),
                         .HEX2(HEX2),
                         .HEX1(HEX1),
                         .HEX0(HEX0),
                         .D1_AN,
                         .D2_AN,
                         .D1_SEG,
                         .D2_SEG,
                         .dpoints(8'h00));

  always_comb begin
   LD[15] = ~cPts.re_L;
   LD[14] = ~cPts.we_L;
  end

`else
   integer cycle;

   initial cycle = 0;

   always @(negedge clock) begin
      $display("cycle %d", cycle);
      $display("CState: %s  NState: %s", currState, nextState);
      $display("R0: 0x%x  R1: 0x%x  R2: 0x%x  R3: 0x%x",
           r0, r1, r2, r3);
      $display("R4: 0x%x  R5: 0x%x  R6: 0x%x  R7: 0x%x",
           r4, r5, r6, r7);
      $display("selRD: %h     selRS1: %h     selRS2: %h", selRD, selRS1, selRS2);
      $display("Dest: %s LoadCC: %s RE: %s WE: %s",
           cPts.dest.name, cPts.lcc_L.name, cPts.re_L.name, cPts.we_L.name);
      $display("AddrBus: %h  DataBus: %h", memAddr, dataBus);
      $display("ALUop: %s     SrcA: %s      SrcB: %s",
           cPts.alu_op.name, cPts.srcA.name, cPts.srcB.name);
      $display("ALUInA: 0x%h  ALUInB: 0x%h  ALUOut: 0x%h",
           aluSrc1, aluSrc2, aluOut);
      $display("PC:     0x%h  IR:     0x%h", pc, ir);
      $display("MAR:    0x%h  MDR     0x%h  ZCNV:   %b", memAddr, memData, condCodes);
      $display("==================================================");
      cycle = cycle + 1;
      if (cycle > 50000)
        $finish;
   end
`endif

endmodule
