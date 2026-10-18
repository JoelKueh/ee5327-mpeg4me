// pu_result_if.sv
//
// SAD reuslt interface.
//

interface sad_result_if#(
    sad_bitwidths_t BITW
);

    logic [SAD_4X4_W-1:0] s4x4[16];
    logic [SAD_8X4_W-1:0] s8x4[8];
    logic [SAD_4X8_W-1:0] s4x8[8];
    logic [SAD_8X8_W-1:0] s8x8[4];
    logic [SAD_16X4_W-1:0] s16x4[4];
    logic [SAD_4X16_W-1:0] s4x16[4];
    logic [SAD_16X8_W-1:0] s16x8[2];
    logic [SAD_8X16_W-1:0] s8x16[2];
    logic [SAD_16X16_W-1:0] s16x16[1];

    modport engine(
        output s4x4, output s8x4, output s4x8, output s8x8,
        output s16x4, output s4x16, output s16x8, output s8x16,
        output s16x16
    );

    modport register(
        input s4x4, input s8x4, input s4x8, input s8x8,
        input s16x4, input s4x16, input s16x8, input s8x16,
        input s16x16
    );

endinterface
