// me_top.sv
//
// Top module for the full search motion estimation system.
//

module me_top (
    input logic clk,
    input logic clear,
    input logic stall,

    // Data is streamed into the block: 39-pel reference row and four 4-pel CB rows
    input logic [me_pkg::WINDOW_SIZE+6:0][me_pkg::PEL_W-1:0] rb,
    input logic [3:0][me_pkg::PEL_W-1:0]                     cb[4],

    // Valid output of the different comparators
    output logic result_4x4_valid[4],
    output logic result_4x8_valid[2],
    output logic result_8x4_valid[2],
    output logic result_8x8_valid,
    output logic result_16x8_valid,
    output logic result_16x16_valid,

    // Metadata IDs for combined SADs (if needed by top-level)
    output me_pkg::comb_sad_id_t result_16x8_id,
    output logic [1:0]           result_16x16_sb_idx,

    // Minimum SAD output of the different comparators
    output logic [me_pkg::SAD_4X4_W-1:0]   result_min_4x4[4],
    output logic [me_pkg::SAD_8X4_W-1:0]   result_min_4x8[2],
    output logic [me_pkg::SAD_8X4_W-1:0]   result_min_8x4[2],
    output logic [me_pkg::SAD_8X8_W-1:0]   result_min_8x8,
    output logic [me_pkg::SAD_16X8_W-1:0]  result_min_16x8,
    output logic [me_pkg::SAD_16X16_W-1:0] result_min_16x16,

    // Motion vector output of the different comparators
    output me_pkg::mv_t result_mv_4x4[4],
    output me_pkg::mv_t result_mv_4x8[2],
    output me_pkg::mv_t result_mv_8x4[2],
    output me_pkg::mv_t result_mv_8x8,
    output me_pkg::mv_t result_mv_16x8,
    output me_pkg::mv_t result_mv_16x16
);

    import me_pkg::*;

    fs_control control (.*);

endmodule
