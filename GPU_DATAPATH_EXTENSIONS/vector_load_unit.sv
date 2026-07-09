/*
 * File: vector_load_unit.sv
 *
 * Loads vector from MDR in batches due to size constraints (64-bit vs 16-bit)
 */

module vector_load_unit (
    output logic [63:0] vectorOut,
    input  logic [15:0] mdrData,
    input  logic [1:0]  laneSel,
    input  logic        loadLane_L,
    input  logic        clear,
    input  logic        clock,
    input  logic        reset_L
);

always_ff @(posedge clock, negedge reset_L) begin
    if (~reset_L)
        vectorOut <= 64'd0;
    else if (clear)
        vectorOut <= 64'd0;
    else if (~loadLane_L) begin
        case (laneSel)
            2'd0: vectorOut[15:0]   <= mdrData;
            2'd1: vectorOut[31:16]  <= mdrData;
            2'd2: vectorOut[47:32]  <= mdrData;
            2'd3: vectorOut[63:48]  <= mdrData;
        endcase
    end
end

endmodule : vector_load_unit