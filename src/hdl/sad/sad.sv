// pu.sv
//
// Processing Unit for 16x16 SAD computation.
//

module sad#(
    int PEL_PER_CYCLE
) (
    input logic [PEL_W-1:0] current[PEL_PER_CYCLE],
    input logic [PEL_W-1:0] candidate[PEL_PER_CYCLE],
    output sv_result_if.engine result
);

endmodule
