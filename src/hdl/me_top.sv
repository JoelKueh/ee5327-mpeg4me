// me_top.sv
//
// Top module for the full search motion estimation system.
//

module me_top (
    input logic clk,   // The primary clock
    input logic clear, // Synchronous clear signal

    // Reference block is streamed into the control model in Morton order.
    output logic rb_ready,  // Reference block ready signal
    input logic rb_valid,  // Reference block data valid signal
    input logic [me_pkg::WINDOW_SIZE+6:0][me_pkg::PEL_W-1:0] rb,  // Reference block input stream

    // Current block is also streamed in Morton order.
    output logic                          cb_ready,  // Current block ready signal
    input  logic                          cb_valid,  // Current block data valid signal
    input  logic [7:0][me_pkg::PEL_W-1:0] cb,        // Current block input

    // Valid output of the different comparators
    output logic result_8x4_valid[2],
    output logic result_8x8_valid,
    output logic result_16x8_valid,
    output logic result_16x16_valid,

    // Wire output of the different comparators
    output logic [me_pkg::SAD_8X4_W-1:0] result_min_8x4[2],
    output logic [me_pkg::SAD_8X8_W-1:0] result_min_8x8,
    output logic [me_pkg::SAD_16X8_W-1:0] result_min_16x8,
    output logic [me_pkg::SAD_16X16_W-1:0] result_min_16x16,

    output me_pkg::mv_t result_mv_8x4[2],
    output me_pkg::mv_t result_mv_8x8,
    output me_pkg::mv_t result_mv_16x8,
    output me_pkg::mv_t result_mv_16x16
);

    import me_pkg::*;

    fs_control control (.*);

endmodule
