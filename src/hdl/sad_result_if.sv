// sad_result_if.sv
//
// Generic interface for an SRAM.
// Assumes single-cycle read.
//

interface sad_result_if;

    logic valid;

    logic [SAD_4X4_W-1:0]   min_sad_4x4[16];
    logic [SAD_8X4_W-1:0]   min_sad_4x8[8];
    logic [SAD_8X4_W-1:0]   min_sad_8x4[8];
    logic [SAD_8X8_W-1:0]   min_sad_8x8[4];
    logic [SAD_16X8_W-1:0]  min_sad_8x16[2];
    logic [SAD_16X8_W-1:0]  min_sad_16x8[2];
    logic [SAD_16X16_W-1:0] min_sad_16x16;

    mv_t mv_4x4[16];
    mv_t mv_4x8[8];
    mv_t mv_8x4[8];
    mv_t mv_8x8[4];
    mv_t mv_8x16[2];
    mv_t mv_16x8[2];
    mv_t mv_16x16;

    modport source (
        output valid, min_sad_4x4, min_sad_4x8, min_sad_8x4, min_sad_8x8,
               min_sad_8x16, min_sad_16x8, min_sad_16x16,
               mv_4x4, mv_4x8, mv_8x4, mv_8x8,
               mv_8x16, mv_16x8, mv_16x16
    );

    modport sink (
        input  valid, min_sad_4x4, min_sad_4x8, min_sad_8x4, min_sad_8x8,
               min_sad_8x16, min_sad_16x8, min_sad_16x16,
               mv_4x4, mv_4x8, mv_8x4, mv_8x8,
               mv_8x16, mv_16x8, mv_16x16
    );

endinterface
