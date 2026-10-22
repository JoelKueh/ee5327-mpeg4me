// me_pkg.sv
//
// Contains parameter definitions for the SAD computation engine.
//

package me_pkg;

    parameter int FRAME_WIDTH = 1280;
    parameter int FRAME_HEIGHT = 720;
    parameter int FRAME_ADDR_W = $clog2(FRAME_WIDTH * FRAME_HEIGHT);

    parameter int BLOCK_SIZE = 16;
    parameter int WINDOW_SIZE = 2 * BLOCK_SIZE;
    parameter int SW_IDX_W = $clog2(WINDOW_SIZE);
    parameter int RB_ROW_IDX_W = $clog2(WINDOW_SIZE+7);
    
    parameter int PEL_W = 8;

    parameter int SAD_2X1_W = PEL_W + $clog2(2 * 1);
    parameter int SAD_4X1_W = PEL_W + $clog2(4 * 2);
    parameter int SAD_4X2_W = PEL_W + $clog2(4 * 4);
    parameter int SAD_4X4_W = PEL_W + $clog2(4 * 4);
    parameter int SAD_8X4_W = PEL_W + $clog2(8 * 4);
    parameter int SAD_8X8_W = PEL_W + $clog2(8 * 8);
    parameter int SAD_16X8_W = PEL_W + $clog2(16 * 8);
    parameter int SAD_16X16_W = PEL_W + $clog2(16 * 16);


    parameter int COMPUTER_LATENCY = 10;  // RF Row enters computer vs SAD comes out.
    parameter int COMBINER_LATENCY = 2;   // 8x8 enters combiner vs 16x16 comes out.

    // First row of SADs comes out of computer on 10th cycle after R0 enters
    parameter int CYCLE_8X8_R0_DONE = 10;
    // First row of 8x8 SADs is processed comparator in two cycles.
    parameter int CYCLE_8X8_MIN_FIRST = CYCLE_8X8_R0_DONE + 2;
    // Full 8x8 SAD cpl time = latency + window size
    parameter int CYCLE_8X8_MIN_DONE = (CYCLE_8X8_MIN_FIRST + WINDOW_SIZE) % (WINDOW_SIZE + 7);
    // 16x8 cpl time = 
    parameter int CYCLE_16X8_MIN_FIRST = (CYCLE_8X8_MIN_FIRST + WINDOW_SIZE + 1) % WINDOW_SIZE + 7;

    typedef struct {
        logic [SW_IDX_W-1:0] row;
        logic [SW_IDX_W-1:0] col;
    } mv_t;

endpackage
