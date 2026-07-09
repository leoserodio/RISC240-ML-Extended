/*
 * File: datapath.v (now .sv)
 * Created: 4/5/1998
 * Modules contained: datapath
 * 
 * Changelog:
 * 23 Oct 2009: Separated paths.v into datapath.v and controlpath.v
 * 17 Nov 2009: Minor updates to facilitate synthesis (mcbender)
 * 13 Oct 2010: Updated always to always_comb and always_ff.Renamed to.sv(abeera)
 * 17 Oct 2010: Updated to use enums instead of define's (iclanton)
 * 24 Oct 2010: Updated to use stuct (abeera)
 * 9  Nov 2010: Slightly modified variable names (abeera)
 * 25 Apr 2013: Changed newMDR to tri (mromanko)
 * 8  Mar 2019: Changed to fit RISC240 spec (pbannai)
 * 4  Nov 2019: Changed MDR to fit Altera IP block (mgcai)
 * 8 July 2026: Added ML datapath components (lserodio)
 */

`include "constants.sv"

/*
 * module datapath
 *
 * This is the datapath for the RISC240.  Modules are instantiated and
 * connected.
 */
module datapath (
   output [15:0] ir,
   output [3:0]  condCodes,
   output [15:0] aluSrcA,
   output [15:0] aluSrcB,
   output [127:0] viewReg, //register for viewing in debugging
   output [15:0] aluResult,
   output [15:0] pc,
   output [15:0] memAddr,
   output [15:0] MDRout,  // output of datapath just for viewing
   // ML / vector debug outputs
   output [63:0] vecRS1Out,
   output [63:0] vecRS2Out,
   output [63:0] vecAluResultOut,
   output [63:0] vecWriteDataOut,
   output signed [31:0] dotResultOut,
   output signed [31:0] accResultOut,

   inout  [15:0] dataBus,
   output [2:0]  selRD,
   output [2:0]  selRS1,
   output [2:0]  selRS2,
   input controlPts  cPts,
   input         clock,
   input         reset_L);

   logic [15:0] regRS1, regRS2;
   logic [15:0] memOut; // unused...
   logic [14:0] marOut;
   logic [3:0]  newCC;
   logic loadReg_L, loadPC_L, loadMDR_L, writeMD_L, loadMAR_L, loadIR_L;
   tri   [15:0] newMDR;

   // Assign wires
   assign loadMDR_L = writeMD_L & cPts.re_L;
   assign selRD  = ir[8:6];
   assign selRS1 = ir[5:3];
   assign selRS2 = ir[2:0];

   logic [15:0] marPlus2;
   logic [15:0] marInput;
   assign marPlus2 = {marOut, 1'b0} + 16'd2;
   assign marInput = (cPts.marSrc == MAR_INCREMENT) ? marPlus2 : aluResult; // choose increment or aluresult

   assign memAddr = {marOut, 1'b0};


   

   // Instantiate the modules that we need:
   reg_file rfile(
           .outRS1(regRS1),
           .outRS2(regRS2),
           .outView(viewReg),
           .in(aluResult),
           .selRD,
           .selRS1,
           .selRS2,
           .clock,
           .reset_L,
           .load_L(loadReg_L));

   tridrive #(.WIDTH(16)) a(.data(aluResult), .bus(newMDR), .en_L(writeMD_L)),
                          b(.data(dataBus), .bus(newMDR), .en_L(cPts.re_L)),
                          c(.data(MDRout), .bus(dataBus), .en_L(cPts.we_L));

   aluMux #(.WIDTH(16)) MuxA(.inA(regRS1),
                             .inB(pc),
                             .inC(MDRout),
                             .out(aluSrcA),
                             .sel(cPts.srcA)),
                        MuxB(.inA(regRS2),
                             .inB(pc),
                             .inC(MDRout),
                             .out(aluSrcB),
                             .sel(cPts.srcB));

   alu alu_dp(.out(aluResult), .condCodes(newCC), .inA(aluSrcA), .inB(aluSrcB),
              .opcode(cPts.alu_op));

   logic [7:0] dest_out;
   decoder #(8) reg_load_decoder(.I(cPts.dest),
                                 .en(1'b1),
                                 .D(dest_out));

   assign {loadIR_L, loadMAR_L, writeMD_L, loadPC_L, loadReg_L} = dest_out[4:0];

   /*register #(.WIDTH(16)) memDataReg(.out(MDRout), .in(newMDR), .load_L(loadMDR_L),
                                     .clock(clock), .reset_L(reset_L));*/
   // MDR input logic
   
   logic [15:0] vecStoreData;
   logic [15:0] inputMDR;
   assign inputMDR = (cPts.vec_mem_op == VEC_MEM_STORE) ? vecStoreData : newMDR; 
   // If we are doing a vector store operation, the MDR input comes from vecStoreData
   register #(.WIDTH(16)) memDataReg(
    .out(MDRout), 
    .in(inputMDR), 
    .load_L(loadMDR_L),
    .clock(clock), 
    .reset_L(reset_L));

   register #(.WIDTH(16)) pcReg(     .out(pc), .in(aluResult), .load_L(loadPC_L),
                                     .clock(clock), .reset_L(reset_L));
   /*register #(.WIDTH(15)) memAddrReg(.out(marOut), .in(aluResult[15:1]), .load_L(loadMAR_L),
                                     .clock(clock), .reset_L(reset_L));*/
   register #(.WIDTH(15)) memAddrReg(
    .out(marOut),
    .in(marInput[15:1]),
    .load_L(loadMAR_L),
    .clock(clock),
    .reset_L(reset_L));

   register #(.WIDTH(16)) instrReg(  .out(ir), .in(aluResult), .load_L(loadIR_L),
                                     .clock(clock), .reset_L(reset_L));
   register #(.WIDTH(4)) condCodeReg(.out(condCodes), .in(newCC), .load_L(cPts.lcc_L),
                                     .clock(clock), .reset_L(reset_L));



   //=====================================================//
   //          ML / VECTOR EXTENSIONS                     //
   //=====================================================//

   // First we add our reg file that will hold vector values for our more complex deep learning applications
   // We will reuse the instruction format from the original RISC240 (as such we have rs1, rs2, rd)
   logic [63:0] vecRS1, vecRS2;
   logic [63:0] vecWriteData;
   logic [63:0] vecAluResult;
   logic signed [31:0] dotResult;
   logic signed [31:0] accResult;
   assign vecRS1Out       = vecRS1;
   assign vecRS2Out       = vecRS2;
   assign vecAluResultOut = vecAluResult;
   assign vecWriteDataOut = vecWriteData;
   assign dotResultOut    = dotResult;
   assign accResultOut    = accResult;

   vector_regfile vfile(
    .outRS1(vecRS1),
    .outRS2(vecRS2),
    .in(vecWriteData),

    .selRD(selRD),
    .selRS1(selRS1),  
    .selRS2(selRS2),

    .clock(clock),
    .reset_L(reset_L),
    .load_L(cPts.vecRegLoad_L)
  );
  
  // Now we will instatiate the hardware blocks that will perform ML operations
  // Starting with the ML ALU:
  vector_alu mlalu(
    .out(vecAluResult),
    .inA(vecRS1),
    .inB(vecRS2),
    .opcode(cPts.vec_op)
  );


  
  // Vector load unit:
  // combines four 16-bit MDR values into one 64-bit vector
  logic [63:0] vectorLoadOut;
  vector_load_unit vload(
      .vectorOut(vectorLoadOut),
      .mdrData(MDRout),
      .laneSel(cPts.laneSel),
      .loadLane_L(cPts.loadLane_L),
      .clear(cPts.clearVecLoad),
      .clock(clock),
      .reset_L(reset_L)
  );

  // Vector store unit:
  // selects one 16-bit lane from a 64-bit vector to store
  vector_store_unit vstore(
      .storeData(vecStoreData),
      .vectorIn(vecRS2),
      .laneSel(cPts.laneSel)
  );
  // MUX selects the data written back to the vector register file.
  // ML ALU operations => write the vector ALU result.
  // Vector load instructions => write vector created by the vector load unit.
  assign vecWriteData = (cPts.vecWriteSrc == VEC_WRITE_LOAD) ? vectorLoadOut : vecAluResult;

  // dot product unit
  dot_product_unit dotProduct(
      .out(dotResult),
      .inA(vecRS1),
      .inB(vecRS2)
  );

  // accumulator 
  
  accumulator acc(
      .out(accResult),
      .in(dotResult),
      .load_L(cPts.accLoad_L),
      .clear(cPts.accClear),

      .clock(clock),
      .reset_L(reset_L)
  );
  
endmodule
