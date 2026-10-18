// sad_4x4.sv
//
// Computes the Sum of Absolute Differences between two 16x16 macroblocks.
//

module sad_4x4#(
    int PIXEL_WIDTH=8,
    int SAD4X4_WIDTH=PIXEL_WIDTH+16
) (
    input wire [PIXEL_WIDTH-1:0] current[N-1],
    input wire [PIXEL_WIDTH-1:0] candidate[N-1],
    output wire [SAD4X4_WIDTH-1:0] result,
    output wire [
);

endmodule
