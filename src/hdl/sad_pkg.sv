// sad_pkg.sv
//
// Contains parameter definitions for the SAD computation engine.
//

package sad_pkg;

    parameter int FRAME_WIDTH = 1280;
    parameter int FRAME_HEIGHT = 720;

    parameter int BLOCK_SIZE = 16;
    parameter int WINDOW_SIZE = 2 * BLOCK_SIZE;
    parameter int PEL_OFFSET_W = $clog2(WINDOW_SIZE);
    
    parameter int PEL_W = 8;

    parameter int SAD_2X1_W = PEL_W + $clog2(2 * 1);
    parameter int SAD_4X1_W = PEL_W + $clog2(4 * 2);
    parameter int SAD_4X2_W = PEL_W + $clog2(4 * 4);
    parameter int SAD_4X2_W = PEL_W + $clog2(4 * 4);
    parameter int SAD_4X4_W = PEL_W + $clog2(4 * 4);
    parameter int SAD_8X4_W = PEL_W + $clog2(8 * 4);
    parameter int SAD_8X8_W = PEL_W + $clog2(8 * 8);
    parameter int SAD_16X4_W = PEL_W + $clog2(16 * 4);
    parameter int SAD_16X8_W = PEL_W + $clog2(16 * 8);
    parameter int SAD_16X16_W = PEL_W + $clog2(16 * 16);

endpackage
