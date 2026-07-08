/*
 * File: vector_regfile.sv
 *
 * 8-register vector register file.
 * Each vector register is 64 bits = 4 lanes x 16 bits.
 */

module vector_regfile(
   output logic [63:0] outRS1,
   output logic [63:0] outRS2,
   input  logic [63:0] in,
   input  logic [2:0]  selRD,
   input  logic [2:0]  selRS1,
   input  logic [2:0]  selRS2,
   input  logic        load_L,
   input  logic        reset_L,
   input  logic        clock);

   logic [63:0] v0, v1, v2, v3, v4, v5, v6, v7;
   logic [7:0]  vec_enable_lines_L;

   register #(.WIDTH(64)) vec0(.out(v0), .in(in), .load_L(vec_enable_lines_L[0]),
                               .clock(clock), .reset_L(reset_L));
   register #(.WIDTH(64)) vec1(.out(v1), .in(in), .load_L(vec_enable_lines_L[1]),
                               .clock(clock), .reset_L(reset_L));
   register #(.WIDTH(64)) vec2(.out(v2), .in(in), .load_L(vec_enable_lines_L[2]),
                               .clock(clock), .reset_L(reset_L));
   register #(.WIDTH(64)) vec3(.out(v3), .in(in), .load_L(vec_enable_lines_L[3]),
                               .clock(clock), .reset_L(reset_L));
   register #(.WIDTH(64)) vec4(.out(v4), .in(in), .load_L(vec_enable_lines_L[4]),
                               .clock(clock), .reset_L(reset_L));
   register #(.WIDTH(64)) vec5(.out(v5), .in(in), .load_L(vec_enable_lines_L[5]),
                               .clock(clock), .reset_L(reset_L));
   register #(.WIDTH(64)) vec6(.out(v6), .in(in), .load_L(vec_enable_lines_L[6]),
                               .clock(clock), .reset_L(reset_L));
   register #(.WIDTH(64)) vec7(.out(v7), .in(in), .load_L(vec_enable_lines_L[7]),
                               .clock(clock), .reset_L(reset_L));

   demux #(.OUT_WIDTH(8), .IN_WIDTH(3), .DEFAULT(1))
         vec_en_decoder (.in(load_L), .sel(selRD), .out(vec_enable_lines_L));

   mux8to1 #(.WIDTH(64)) muxRS1(.inA(v0), .inB(v1), .inC(v2), .inD(v3),
                                .inE(v4), .inF(v5), .inG(v6), .inH(v7),
                                .out(outRS1), .sel(selRS1));

   mux8to1 #(.WIDTH(64)) muxRS2(.inA(v0), .inB(v1), .inC(v2), .inD(v3),
                                .inE(v4), .inF(v5), .inG(v6), .inH(v7),
                                .out(outRS2), .sel(selRS2));

endmodule : vector_regfile