// fs_computer.sv
//
// Performs first-level SAD computation using four SAD PE arrays.
// Computes all 8x4, and 8x8 SADs. Does not compute 4x4 and 8x4 SADs to help
// with congestion. Discussed in Vayalil and Kong.
//
// Buffers its own output, adding a one-cycle latency to the pipeline.
//

module fs_computer (
    input logic clk,    // The primary clock
    input logic clear,  // Pipelined clear signal
    input logic stall,  // Pipelined stall signal

    input logic [3:0][me_pkg::PEL_W-1:0] cb[4],  // Current block input
    input logic [me_pkg::WINDOW_SIZE+6:0][me_pkg::PEL_W-1:0] rb,  // Reference block input stream
    input logic [me_pkg::RB_ROW_IDX_W-1:0] rb_row_idx,  // Reference block search window offset

    output logic [me_pkg::SAD_8X4_W-1:0] sad_8x4[2][me_pkg::WINDOW_SIZE], // Buffered output 8x4 row resultss
    output logic [me_pkg::SAD_8X8_W-1:0] sad_8x8[me_pkg::WINDOW_SIZE],    // Buffered output 8x8 row results
    output logic [me_pkg::RB_ROW_IDX_W-1:0] sad_row_idx  // SAD search window offset
);

    import me_pkg::*;

    logic [WINDOW_SIZE+6:0][PEL_W-1:0] rb_sr_q[4], rb_sr_d[4];

    logic [SAD_4X4_W-1:0] sad_4x4[4][WINDOW_SIZE];
    logic [SAD_8X4_W-1:0] sad_8x4_q[2][WINDOW_SIZE], sad_8x4_d[2][WINDOW_SIZE];
    logic [SAD_8X8_W-1:0] sad_8x8_q[WINDOW_SIZE], sad_8x8_d[WINDOW_SIZE];
    logic [RB_ROW_IDX_W-1:0] sad_row_idx_q, sad_row_idx_d;

    // Instantiate 4 4x4_SAD PE arrays arranged as a full 8x8 block.
    fs_pe_array pe_array_ul (
        .clk(clk),
        .clear(clear),
        .stall(stall),
        .load(rb_row_idx < 4),
        .row_idx_mod(rb_row_idx[1:0]),
        .rb(rb[WINDOW_SIZE+2:0]),
        .cb(cb[0]),
        .sad(sad_4x4[0])
    );

    fs_pe_array pe_array_ur (
        .clk(clk),
        .clear(clear),
        .stall(stall),
        .load(rb_row_idx < 4),
        .row_idx_mod(rb_row_idx[1:0]),
        .rb(rb[WINDOW_SIZE+6:4]),
        .cb(cb[1]),
        .sad(sad_4x4[1])
    );

    fs_pe_array pe_array_dl (
        .clk(clk),
        .clear(clear),
        .stall(stall),
        .load(rb_row_idx < 8),
        .row_idx_mod(rb_row_idx[1:0]),
        .rb(rb_sr_q[3][WINDOW_SIZE+2:0]),
        .cb(cb[2]),
        .sad(sad_4x4[2])
    );

    fs_pe_array pe_array_dr (
        .clk(clk),
        .clear(clear),
        .stall(stall),
        .load(rb_row_idx < 8),
        .row_idx_mod(rb_row_idx[1:0]),
        .rb(rb_sr_q[3][WINDOW_SIZE+6:4]),
        .cb(cb[3]),
        .sad(sad_4x4[3])
    );

    always_comb begin
        rb_sr_d = rb_sr_q;
        sad_row_idx_d = rb_row_idx - 10;

        // Compute the 8x4 and 8x8 results in one cycle
        for (int row = 0; row < WINDOW_SIZE; row++) begin
            sad_8x4_d[0][row] = sad_4x4[0][row] + sad_4x4[2][row];
            sad_8x4_d[1][row] = sad_4x4[1][row] + sad_4x4[3][row];
            sad_8x8_d[row] = sad_8x4_d[0][row] + sad_8x4_d[1][row];
        end

        // Buffer the reference pixel data for the dl and dr PE arrays
        if (!stall) begin
            rb_sr_d[0] = rb;
            rb_sr_d[1] = rb_sr_q[0];
            rb_sr_d[2] = rb_sr_q[1];
            rb_sr_d[3] = rb_sr_q[2];
        end
    end

    // Buffer the output of the 4x4 PE arrays
    always_ff @(posedge clk) begin
        if (clear) begin
            for (int i = 0; i < WINDOW_SIZE; i++) sad_8x4_q[0][i] <= '0;
            for (int i = 0; i < WINDOW_SIZE; i++) sad_8x4_q[1][i] <= '0;
            for (int i = 0; i < WINDOW_SIZE; i++) sad_8x8_q[i] <= '0;
            for (int i = 0; i < 4; i++) rb_sr_q[i] <= '0;
            sad_row_idx_q <= '0;
        end else begin
            sad_8x4_q <= sad_8x4_d;
            sad_8x8_q <= sad_8x8_d;
            rb_sr_q <= rb_sr_d;
            sad_row_idx_q <= sad_row_idx_d;
        end
    end

    // Assign the 8x4 and 8x8 output
    always_comb begin
        sad_8x4 = sad_8x4_q;
        sad_8x8 = sad_8x8_q;
        sad_row_idx = sad_row_idx_q;
    end

endmodule
