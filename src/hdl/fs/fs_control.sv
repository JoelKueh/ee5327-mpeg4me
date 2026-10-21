// fs_control.sv
//
// Control module for the full search motion estimation system.
//

module fs_control (
    input  logic clk,                             // The primary clock
    input  logic rst_n,                           // Asynchronous negative reset

    // Reference block is streamed into the control model in Morton order.
    output logic [SW_IDX_W-1:0] rb_ready,         // Reference block ready signal
    input  logic [SW_IDX_W-1:0] rb_valid,         // Reference block data valid signal
    input  logic [WINDOW_SIZE+6:0][PEL_W-1:0] rb, // Reference block input stream

    // Current block is also streamed in Morton order.
    output logic [SW_IDX_W-1:0] cb_ready,         // Current block ready signal
    input  logic [SW_IDX_W-1:0] cb_valid,         // Current block data valid signal
    input  logic [3:0][PEL_W-1:0] cb[4],           // Current block input

    // RAM interfaces used by the combiner.
    sram_if.mstr ram_a,
    sram_if.mstr ram_b,
    sram_if.mstr ram_c,

    // Winning SAD computations for the current block.
    sad_result_if.source results
);

    import me_pkg::*;

    parameter int COMPUTER_LATENCY = 10;
    parameter int COMBINER_LATENCY = 2;

    // Input data buffers
    logic [WINDOW_SIZE+6:0][PEL_W-1:0] rb_q, rb_d;
    logic rb_has_data_q, rb_has_data_d;
    logic [3:0][PEL_W-1:0] cb_q[4], cb_d[4];
    logic cb_has_data_q, cb_has_data_d;

    // Current row and current subblock trackers
    logic [RB_ROW_IDX_W-1:0] rb_row_idx_q, rb_row_idx_d;
    logic [1:0] cb_subblock_idx_q, cb_subblock_idx_d;

    // Results of SAD computations from computer and combiner
    logic [SAD_8X4_W-1:0] sad_8x4[2][WINDOW_SIZE];
    logic [SAD_8X8_W-1:0] sad_8x8[WINDOW_SIZE];
    logic [SAD_16X8_W-1:0] sad_8x16[2][WINDOW_SIZE];
    logic [SAD_16X8_W-1:0] sad_16x8[2][WINDOW_SIZE];
    logic [SAD_16X16_W-1:0] sad_16x16[WINDOW_SIZE];

    // Buffered output for the shared 16x8 comparater.
    logic [SAD_16X8_W-1:0] min_16x8_q, min_16x8_d;
    logic [SAD_16X8_W-1:0] mv_16x8_q, mv_16x8_d;
    logic [SAD_16X8_W-1:0] min_8x16_q;
    logic [SAD_16X8_W-1:0] mv_8x16_q;

    // Stall signal computed from the state of the input data buffers.
    logic stall_q[COMPUTER_LATENCY], stall_d[COMPUTER_LATENCY];

    // Computer - Computes fisrt level SAD results from the RB stream
    fs_computer computer (
        .clk(clk),
        .clear(rb_row_idx_q == 0),
        .stall(stall_d[0]),

        .cb(cb_q),
        .rb(rb),
        .rb_row_idx(rb_row_idx_q),

        .sad_8x4(sad_8x4),
        .sad_8x8(sad_8x8)
    );

    // Combiner - Combines first level SAD results into higher level reslts
    fs_combiner combiner (
        .clk(clk),
        .clear(cb_subblock_idx_q == 0),
        .stall(stall_d[COMPUTER_LATENCY]),

        .sad_row_idx(rb_row_idx_q - COMPUTER_LATENCY),
        .sad_8x8(sad_8x8),

        .ram_a(ram_a),
        .ram_b(ram_b),
        .ram_c(ram_c),

        .sad_8x16(sad_8x16),
        .sad_16x8(sad_16x8),
        .sad_16x16(sad_16x16)
    );

    // Comparator - Preforms a MIN reduction on input SADs
    fs_comparator#(SAD_8X4_W) comparator_8x4_1 (
        .clk(clk),
        .clear(rb_row_idx_q == 0),
        .stall(stall_d[COMPUTER_LATENCY]),

        .input_row_idx(rb_row_idx_q - COMPUTER_LATENCY),
        .input_sads(sad_8x4[0]),

        .result_sad(results.min_sad_8x4),
        .result_mv(results.mv_8x4)
    );

    fs_comparator#(SAD_8X4_W) comparator_8x4_2 (
        .clk(clk),
        .clear(rb_row_idx_q == 0),
        .stall(stall_d[COMPUTER_LATENCY]),

        .input_row_idx(rb_row_idx_q - COMPUTER_LATENCY),
        .input_sads(sad_8x4[1]),

        .result_sad(results.min_sad_8x4),
        .result_mv(results.mv_8x4)
    );

    fs_comparator#(SAD_8X8_W) comparator_8x8 (
        .clk(clk),
        .clear(rb_row_idx_q == 0),
        .stall(stall_d[COMPUTER_LATENCY]),

        .input_row_idx(rb_row_idx_q - COMPUTER_LATENCY),
        .input_sads(sad_8x8[0]),

        .result_sad(results.min_sad_8x8),
        .result_mv(results.mv_8x8)
    );

    // 16x8 comparator handles both 16x8 and 8x16 SADs
    fs_comparator#(SAD_16X8_W) comparator_16x8 (
        .clk(clk),
        .clear(rb_row_idx_q == 0),
        .stall(stall_d[COMPUTER_LATENCY]),

        .input_row_idx(rb_row_idx_q - COMPUTER_LATENCY),
        .input_sads(sad_8x8[0]),

        .result_sad(results.min_sad_16x8),
        .result_mv(results.mv_16x8)
    );

    fs_comparator#(SAD_16X16_W) comparator_16x16 (
        .clk(clk),
        .clear(rb_row_idx_q == 0),
        .stall(stall_d[COMPUTER_LATENCY]),

        .input_row_idx(rb_row_idx_q - COMPUTER_LATENCY),
        .input_sads(sad_8x8[0]),

        .result_sad(results.min_sad_8x8),
        .result_mv(results.mv_8x8)
    );

    always_comb begin
        rb_d = rb_q;
        rb_has_data_d = rb_has_data_q;
        cb_d = cb_q;
        cb_has_data_d = cb_has_data_q;
        rb_row_idx_d = rb_row_idx_q;
        cb_subblock_idx_d = cb_subblock_idx_q;

        // For the first four rows, stream CB and RB simultaneously.
        for (int i = 1; i < COMPUTER_LATENCY; i++) stall_d[i] = stall_q[i-1];
        if (rb_row_idx_q < 4) begin
            stall_d[0] = !(cb_has_data_q && rb_has_data_q);
        end else begin
            stall_d[0] = rb_has_data_q;
        end

        // We need data when we are not stalled and when we don't have data
        rb_ready = !stall_d[0] || !rb_has_data_q;
        cb_ready = !stall_d[0] || !cb_has_data_q;

        // Handshake and buffer data from the stream.
        if (rb_ready && rb_valid) begin
            rb_d = rb;
            rb_has_data_d = 1;
        end

        if (cb_ready && cb_valid) begin
            cb_d = cb;
            cb_has_data_d = 1;
        end
        
        // Drive data if we are not stalled.
        if (!stall_d[0]) begin
            assert(cb_has_data_q);
            assert(rb_has_data_q);
            cb_has_data_q = 0;
            rb_has_data_q = 0;

            // Update the row index, then the subblock index if necessary.
            rb_row_idx_d = rb_row_idx_q + 1;
            if (rb_row_idx_d == 0) cb_subblock_idx_d = cb_subblock_idx_q + 1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (rst_n) begin
            rb_q <= '0;
            rb_has_data_q <= '0;
            cb_q <= '0;
            cb_has_data_q <= '0;
            rb_row_idx_q <= '1;
            cb_subblock_idx_q <= '1;
        end else begin
            rb_q <= rb_d;
            rb_has_data_q <= rb_has_data_d;
            cb_q <= cb_d;
            cb_has_data_q <= cb_has_data_q;
            rb_row_idx_q <= rb_row_idx_d;
            cb_subblock_idx_q <= cb_subblock_idx_d;
        end
    end

endmodule
