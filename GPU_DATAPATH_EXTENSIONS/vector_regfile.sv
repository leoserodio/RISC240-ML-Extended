/*
 * File: vector_regfile.sv
 *
 * 8-register vector register file.
 * Each vector register is 64 bits = 4 lanes x 16 bits.
 */

module vector_regfile (
    output logic [63:0] outRS1,
    output logic [63:0] outRS2,

    input  logic [63:0] in,

    input  logic [2:0] selRD,
    input  logic [2:0] selRS1,
    input  logic [2:0] selRS2,

    input  logic clock,
    input  logic reset_L,
    input  logic load_L
);

    logic [63:0] v0, v1, v2, v3, v4, v5, v6, v7;
    logic [7:0]  vecLoad;
    logic [7:0]  vecLoad_L;

    // Decode destination vector register.
    // selRD = 3'b011 -> vecLoad = 00001000
    decoder #(8) vec_load_decoder(
        .I(selRD),
        .en(~load_L),
        .D(vecLoad)
    );

    // register module uses active-low load.
    // One selected register gets 0, all others get 1.
    assign vecLoad_L = ~vecLoad;

    register #(.WIDTH(64)) V0(
        .out(v0),
        .in(in),
        .load_L(vecLoad_L[0]),
        .clock(clock),
        .reset_L(reset_L)
    );

    register #(.WIDTH(64)) V1(
        .out(v1),
        .in(in),
        .load_L(vecLoad_L[1]),
        .clock(clock),
        .reset_L(reset_L)
    );

    register #(.WIDTH(64)) V2(
        .out(v2),
        .in(in),
        .load_L(vecLoad_L[2]),
        .clock(clock),
        .reset_L(reset_L)
    );

    register #(.WIDTH(64)) V3(
        .out(v3),
        .in(in),
        .load_L(vecLoad_L[3]),
        .clock(clock),
        .reset_L(reset_L)
    );

    register #(.WIDTH(64)) V4(
        .out(v4),
        .in(in),
        .load_L(vecLoad_L[4]),
        .clock(clock),
        .reset_L(reset_L)
    );

    register #(.WIDTH(64)) V5(
        .out(v5),
        .in(in),
        .load_L(vecLoad_L[5]),
        .clock(clock),
        .reset_L(reset_L)
    );

    register #(.WIDTH(64)) V6(
        .out(v6),
        .in(in),
        .load_L(vecLoad_L[6]),
        .clock(clock),
        .reset_L(reset_L)
    );

    register #(.WIDTH(64)) V7(
        .out(v7),
        .in(in),
        .load_L(vecLoad_L[7]),
        .clock(clock),
        .reset_L(reset_L)
    );

    // Read port muxes
    always_comb begin
        case (selRS1)
            3'd0: outRS1 = v0;
            3'd1: outRS1 = v1;
            3'd2: outRS1 = v2;
            3'd3: outRS1 = v3;
            3'd4: outRS1 = v4;
            3'd5: outRS1 = v5;
            3'd6: outRS1 = v6;
            3'd7: outRS1 = v7;
            default: outRS1 = 64'b0;
        endcase

        case (selRS2)
            3'd0: outRS2 = v0;
            3'd1: outRS2 = v1;
            3'd2: outRS2 = v2;
            3'd3: outRS2 = v3;
            3'd4: outRS2 = v4;
            3'd5: outRS2 = v5;
            3'd6: outRS2 = v6;
            3'd7: outRS2 = v7;
            default: outRS2 = 64'b0;
        endcase
    end

endmodule