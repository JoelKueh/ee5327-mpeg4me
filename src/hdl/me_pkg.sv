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

    function logic [SW_IDX_W-1:0] rb2sw(logic [RB_ROW_IDX_W-1:0] x);
        return SW_IDX_W'(x - 4);
    endfunction

    typedef struct packed {
        logic [SW_IDX_W-1:0] row;
        logic [SW_IDX_W-1:0] col;
    } mv_t;

    typedef enum logic [1:0] {
        SAD_LXS_0 = 0,
        SAD_LXS_1 = 1,
        SAD_SXL_0 = 2,
        SAD_SXL_1 = 3
    } comb_sad_id_t;

endpackage
