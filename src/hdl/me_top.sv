// me_top.sv
//
// Top module for the full search motion estimation system.
//

module me_top (
    input  logic clk,                                     // The primary clock
    input  logic rst_n,                                   // Asynchronous negative reset

    // Reference block is streamed into the control model in Morton order.
    output logic rb_ready,                                // Reference block ready signal
    input  logic rb_valid,                                // Reference block data valid signal
    input  logic [WINDOW_SIZE+6:0][me_pkg::PEL_W-1:0] rb, // Reference block input stream

    // Current block is also streamed in Morton order.
    output logic cb_ready,                                // Current block ready signal
    input  logic cb_valid,                                // Current block data valid signal
    input  logic [3:0][PEL_W-1:0] cb[4],                  // Current block input

    // RAM interfaces used by the combiner.
    output logic                             ram_a_wr_en,
    output logic [SW_IDX_W-1:0]              ram_a_wr_addr,
    output logic [SAD_8X8_W+WINDOW_SIZE-1:0] ram_a_wr_data,
    output logic                             ram_a_rd_en,
    output logic [SW_IDX_W-1:0]              ram_a_rd_addr,
    input  logic [SAD_8X8_W+WINDOW_SIZE-1:0] ram_a_rd_data,

    output logic                             ram_b_wr_en,
    output logic [SW_IDX_W-1:0]              ram_b_wr_addr,
    output logic [SAD_8X8_W+WINDOW_SIZE-1:0] ram_b_wr_data,
    output logic                             ram_b_rd_en,
    output logic [SW_IDX_W-1:0]              ram_b_rd_addr,
    input  logic [SAD_8X8_W+WINDOW_SIZE-1:0] ram_b_rd_data,

    output logic                              ram_c_wr_en,
    output logic [SW_IDX_W-1:0]               ram_c_wr_addr,
    output logic [SAD_16X8_W+WINDOW_SIZE-1:0] ram_c_wr_data,
    output logic                              ram_c_rd_en,
    output logic [SW_IDX_W-1:0]               ram_c_rd_addr,
    input  logic [SAD_16X8_W+WINDOW_SIZE-1:0] ram_c_rd_data,

    // Winning SAD computations for the current block.
    output logic [SAD_4X4_W-1:0]   min_sad_4x4[16],
    output logic [SAD_8X4_W-1:0]   min_sad_4x8[8],
    output logic [SAD_8X4_W-1:0]   min_sad_8x4[8],
    output logic [SAD_8X8_W-1:0]   min_sad_8x8[4],
    output logic [SAD_16X8_W-1:0]  min_sad_8x16[2],
    output logic [SAD_16X8_W-1:0]  min_sad_16x8[2],
    output logic [SAD_16X16_W-1:0] min_sad_16x16
);

    import me_pkg::*;

    sram_if#(.ADDR_W(SW_IDX_W), .DATA_W(SAD_8X8_W+WINDOW_SIZE))  ram_a();
    sram_if#(.ADDR_W(SW_IDX_W), .DATA_W(SAD_8X8_W+WINDOW_SIZE))  ram_b();
    sram_if#(.ADDR_W(SW_IDX_W), .DATA_W(SAD_16X8_W+WINDOW_SIZE)) ram_c();

    sad_result_if results();

    assign ram_a_wr_en   = ram_a.wr_en;
    assign ram_a_wr_addr = ram_a.wr_addr;
    assign ram_a_wr_data = ram_a.wr_data;
    assign ram_a_rd_en   = ram_a.rd_en;
    assign ram_a_rd_addr = ram_a.rd_addr;
    assign ram_a.rd_data = ram_a_rd_data;

    assign ram_b_wr_en   = ram_b.wr_en;
    assign ram_b_wr_addr = ram_b.wr_addr;
    assign ram_b_wr_data = ram_b.wr_data;
    assign ram_b_rd_en   = ram_b.rd_en;
    assign ram_b_rd_addr = ram_b.rd_addr;
    assign ram_b.rd_data = ram_b_rd_data;

    assign ram_c_wr_en   = ram_c.wr_en;
    assign ram_c_wr_addr = ram_c.wr_addr;
    assign ram_c_wr_data = ram_c.wr_data;
    assign ram_c_rd_en   = ram_c.rd_en;
    assign ram_c_rd_addr = ram_c.rd_addr;
    assign ram_c.rd_data = ram_c_rd_data;

	assign min_sad_4x4   = results.min_sad_4x4;
	assign min_sad_4x8   = results.min_sad_4x8;
	assign min_sad_8x4   = results.min_sad_8x4;
	assign min_sad_8x8   = results.min_sad_8x8;
	assign min_sad_8x16  = results.min_sad_8x16;
	assign min_sad_16x8  = results.min_sad_16x8;
	assign min_sad_16x16 = results.min_sad_16x16;

    fs_control control (.*);

endmodule
