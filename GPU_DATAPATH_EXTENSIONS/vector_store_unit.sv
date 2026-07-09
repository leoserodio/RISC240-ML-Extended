/*
 * File: vector_store_unit.sv
 *
 * Selects one 16-bit lane from a 64-bit vector to store
 */

module vector_store_unit (
    output logic [15:0] storeData,
    input  logic [63:0] vectorIn,
    input  logic [1:0]  laneSel
);

always_comb begin
    case (laneSel)
        2'd0: storeData = vectorIn[15:0];
        2'd1: storeData = vectorIn[31:16];
        2'd2: storeData = vectorIn[47:32];
        2'd3: storeData = vectorIn[63:48];
        default: storeData = 16'hxxxx;
    endcase
end

endmodule : vector_store_unit