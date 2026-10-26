// me_top.sv
//
// Top module for the full search motion estimation system.
//

module me_top (
    input logic clk,
    input logic clear,

    // Reference block is streamed into the control model in Morton order.
    output logic rb_ready,
    input logic rb_valid,
    input logic [me_pkg::WINDOW_SIZE+6:0][me_pkg::PEL_W-1:0] rb,

    // Current block is also streamed in Morton order.
    output logic                          cb_ready,
    input  logic                          cb_valid,
    input  logic [7:0][me_pkg::PEL_W-1:0] cb,
    input  logic                          upper_half,

    // Valid output of the different comparators
    output logic result_4x4_valid[2],
    output logic result_4x8_valid,
    output logic result_8x4_valid[2],
    output logic result_8x8_valid,
    output logic result_16x8_valid,
    output logic result_16x16_valid,

    // Minimum SAD output of the different comparators
    output logic [me_pkg::SAD_4X4_W-1:0] result_min_4x4[2],
    output logic [me_pkg::SAD_8X4_W-1:0] result_min_4x8,
    output logic [me_pkg::SAD_8X4_W-1:0] result_min_8x4[2],
    output logic [me_pkg::SAD_8X8_W-1:0] result_min_8x8,
    output logic [me_pkg::SAD_16X8_W-1:0] result_min_16x8,
    output logic [me_pkg::SAD_16X16_W-1:0] result_min_16x16,

    // Motion vector output of the different comaprators
    output me_pkg::mv_t result_mv_4x4[2],
    output me_pkg::mv_t result_mv_4x8,
    output me_pkg::mv_t result_mv_8x4[2],
    output me_pkg::mv_t result_mv_8x8,
    output me_pkg::mv_t result_mv_16x8,
    output me_pkg::mv_t result_mv_16x16
);

    import me_pkg::*;

    fs_control control (.*);

endmodule
