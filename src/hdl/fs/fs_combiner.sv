// fs_combiner.sv
//
// Combines SAD reults from the previous level 
//

module fs_combiner (
    input  logic clk,                                               // The primary clock
    input  logic clear,                                             // Pipelined clear signal
    input  logic stall,                                             // Pipelined stall signal

    input  logic [SW_IDX_W-1:0] input_row_idx,                      // Row index of the input SADs
    input  logic [SAD_8X8_W-1:0] input_sads[WINDOW_SIZE],           // Input SADs

    sram_if#(.ADDR_W(2*SW_IDX_W), .DATA_W(SAD_8X8_W)).mstr ram_a,   // First level RAM
    sram_if#(.ADDR_W(2*SW_IDX_W), .DATA_W(SAD_8X8_W)).mstr ram_b,   // Second level RAM
    sram_if#(.ADDR_W(2*SW_IDX_W), .DATA_W(SAD_8X8_W+1)).mstr ram_c, // Third level RAM

    output logic [SAD_16X8_W-1:0]  sad_8x16[2][WINDOW_SIZE],        // 8x16 SAD
    output logic [SAD_16X8_W-1:0]  sad_16x8[2][WINDOW_SIZE],        // 8x16 SAD
    output logic [SAD_16X16_W-1:0] sad_16x16[2][WINDOW_SIZE]        // 16x16 SAD
);

    import me_pkg::*;

endmodule
