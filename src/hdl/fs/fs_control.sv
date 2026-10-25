// fs_control.sv
//
// Control module for the full search motion estimation system.
//

module fs_control (
    input logic clk,   // The primary clock
    input logic clear, // Synchronous clear signal

    // Reference block is streamed into the control model in Morton order.
    output logic rb_ready,  // Reference block ready signal
    input logic rb_valid,  // Reference block data valid signal
    input logic [me_pkg::WINDOW_SIZE+6:0][me_pkg::PEL_W-1:0] rb,  // Reference block input stream

    // Current block is also streamed in Morton order.
    output logic                          cb_ready,  // Current block ready signal
    input  logic                          cb_valid,  // Current block data valid signal
    input  logic [7:0][me_pkg::PEL_W-1:0] cb,        // Current block input

    // Valid output of the different comparators
    output logic result_4x4_valid[4],
    output logic result_4x8_valid[2],
    output logic result_8x4_valid[2],
    output logic result_8x8_valid,
    output logic result_16x8_valid,
    output logic result_16x16_valid,

    // Minimum SAD output of the different comparators
    output logic [me_pkg::SAD_4X4_W-1:0] result_min_4x4[4],
    output logic [me_pkg::SAD_8X4_W-1:0] result_min_4x8[2],
    output logic [me_pkg::SAD_8X4_W-1:0] result_min_8x4[2],
    output logic [me_pkg::SAD_8X8_W-1:0] result_min_8x8,
    output logic [me_pkg::SAD_16X8_W-1:0] result_min_16x8,
    output logic [me_pkg::SAD_16X16_W-1:0] result_min_16x16,

    // Motion vector output of the different comaprators
    output me_pkg::mv_t result_mv_4x4[4],
    output me_pkg::mv_t result_mv_4x8[2],
    output me_pkg::mv_t result_mv_8x4[2],
    output me_pkg::mv_t result_mv_8x8,
    output me_pkg::mv_t result_mv_16x8,
    output me_pkg::mv_t result_mv_16x16
);

    import me_pkg::*;

    parameter int COMPUTER_LATENCY = 9;

    // Input data buffers
    logic [WINDOW_SIZE+6:0][PEL_W-1:0] rb_q, rb_d;
    logic rb_has_data_q, rb_has_data_d;
    logic [7:0][PEL_W-1:0] cb_q, cb_d;
    logic cb_has_data_q, cb_has_data_d;

    // Current row and current subblock trackers
    logic [RB_ROW_IDX_W-1:0] rb_row_idx_q, rb_row_idx_d;
    logic [1:0] sb_idx_8x8_q[3], sb_idx_8x8_d[3];
    logic [1:0] sb_idx_16x16;

    // Valid output of the different SAD engines
    logic bd_valid;
    logic sad_8x8_valid;
    logic sad_16x8_valid;
    logic sad_16x16_valid;

    // Last output of the different SAD engines
    logic sad_16x8_last;
    logic sad_16x16_last;

    // Results of SAD computations from computer and combiner
    logic [SAD_4X4_W-1:0] sad_4x4[4][WINDOW_SIZE];
    logic [SAD_8X4_W-1:0] sad_4x8[2][WINDOW_SIZE];
    logic [SAD_8X4_W-1:0] sad_8x4[2][WINDOW_SIZE];
    logic [SAD_8X8_W-1:0] sad_8x8[WINDOW_SIZE];
    logic [SAD_16X8_W-1:0] sad_16x8[WINDOW_SIZE];
    logic [SAD_16X16_W-1:0] sad_16x16[WINDOW_SIZE];
    comb_sad_id_t sad_16x8_id;

    // Nets defining the row that each compuation belongs to
    logic [SW_IDX_W-1:0] sw_idx_8x8;
    logic [SW_IDX_W-1:0] sw_idx_16x8;
    logic [SW_IDX_W-1:0] sw_idx_16x16;

    logic clear_q, clear_d;
    logic comb_clear_out;

    // Computer - Computes fisrt level SAD results from the RB stream
    fs_computer computer (
        .clk(clk),

        .bd_valid(bd_valid),
        .cb(cb_q),
        .rb(rb_q),
        .rb_row_idx(rb_row_idx_q),

        .sad_valid(sad_8x8_valid),
        .sad_4x4(sad_4x4),
        .sad_4x8(sad_4x8),
        .sad_8x4(sad_8x4),
        .sad_8x8(sad_8x8),
        .sad_sw_idx(sw_idx_8x8)
    );

    // Combiner - Combines first level SAD results into higher level reslts
    fs_combiner comb8x8 (
        .clk(clk),
        .clear_in(clear_q),
        .clear_out(comb_clear_out),

        .sad_8x8_valid(sad_8x8_valid),
        .sad_8x8_last(sw_idx_8x8 == 31),
        .sb_idx_8x8(sb_idx_8x8_q[2]),
        .sw_idx_8x8(sw_idx_8x8),
        .sad_8x8(sad_8x8),

        .sad_16x8_valid(sad_16x8_valid),
        .sad_16x8_last(sad_16x8_last),
        .sad_16x8_id(sad_16x8_id),
        .sw_idx_16x8(sw_idx_16x8),
        .sad_16x8(sad_16x8),

        .sad_16x16_valid(sad_16x16_valid),
        .sad_16x16_last(sad_16x16_last),
        .sb_idx_16x16(sb_idx_16x16),
        .sw_idx_16x16(sw_idx_16x16),
        .sad_16x16(sad_16x16)
    );

    genvar i;

    // 4x4 Comparators - Produces all four 4x4 mv for the current subblock
    generate
        for (i = 0; i < 4; i++) begin : comparator_4x4
            fs_comparator #(SAD_4X4_W) comparator (
                .clk  (clk),
                .clear(clear_q),

                .input_valid (sad_8x8_valid),
                .input_last  (sw_idx_8x8 == 31),
                .input_sw_idx(sw_idx_8x8),
                .input_sads  (sad_4x4[i]),

                .result_valid(result_4x4_valid[i]),
                .result_sad(result_min_4x4[i]),
                .result_mv(result_mv_4x4[i])
            );
        end
    endgenerate

    // 4x8 Comparators - Produces all two 4x8 mv for the current subblock
    generate
        for (i = 0; i < 2; i++) begin : comparator_4x8
            fs_comparator #(SAD_8X4_W) comparator (
                .clk  (clk),
                .clear(clear_q),

                .input_valid (sad_8x8_valid),
                .input_last  (sw_idx_8x8 == 31),
                .input_sw_idx(sw_idx_8x8),
                .input_sads  (sad_4x8[i]),

                .result_valid(result_4x8_valid[i]),
                .result_sad(result_min_4x8[i]),
                .result_mv(result_mv_4x8[i])
            );
        end
    endgenerate

    // 8x4 Comparators - Produces all two 8x4 mv for the current subblock
    generate
        for (i = 0; i < 2; i++) begin : comparator_8x4
            fs_comparator #(SAD_8X4_W) comparator (
                .clk  (clk),
                .clear(clear_q),

                .input_valid (sad_8x8_valid),
                .input_last  (sw_idx_8x8 == 31),
                .input_sw_idx(sw_idx_8x8),
                .input_sads  (sad_8x4[i]),

                .result_valid(result_8x4_valid[i]),
                .result_sad(result_min_8x4[i]),
                .result_mv(result_mv_8x4[i])
            );
        end
    endgenerate

    // 8x8 Comparator - Produces the 8x8 mv for the current subblock
    fs_comparator #(SAD_8X8_W) comparator_8x8 (
        .clk  (clk),
        .clear(clear_q),

        .input_valid (sad_8x8_valid),
        .input_last  (sw_idx_8x8 == 31),
        .input_sw_idx(sw_idx_8x8),
        .input_sads  (sad_8x8),

        .result_valid(result_8x8_valid),
        .result_sad(result_min_8x8),
        .result_mv(result_mv_8x8)
    );

    // 16x8 Comparator - Computes all 16x8 and 8x16 mv
    fs_comparator #(SAD_16X8_W) comparator_16x8 (
        .clk  (clk),
        .clear(comb_clear_out),

        .input_valid (sad_16x8_valid),
        .input_last  (sad_16x8_last),
        .input_sw_idx(sw_idx_16x8),
        .input_sads  (sad_16x8),

        .result_valid(result_16x8_valid),
        .result_sad(result_min_16x8),
        .result_mv(result_mv_16x8)
    );

    // 16x16 Comparator - Computes the onlye 16x16 mv
    fs_comparator #(SAD_16X16_W) comparator_16x16 (
        .clk  (clk),
        .clear(comb_clear_out),

        .input_valid (sad_16x16_valid),
        .input_last  (sad_16x16_last),
        .input_sw_idx(sw_idx_16x16),
        .input_sads  (sad_16x16),

        .result_valid(result_16x16_valid),
        .result_sad(result_min_16x16),
        .result_mv(result_mv_16x16)
    );

    always_comb begin
        clear_d = clear;

        rb_d = rb_q;
        rb_has_data_d = rb_has_data_q;
        cb_d = cb_q;
        cb_has_data_d = cb_has_data_q;
        rb_row_idx_d = rb_row_idx_q;
        sb_idx_8x8_d = sb_idx_8x8_q;

        // For the first four rows, stream CB and RB simultaneously.
        if (rb_row_idx_q < 4) begin
            bd_valid = cb_has_data_q && rb_has_data_q;
        end else begin
            bd_valid = rb_has_data_q;
        end

        // We need data when we are not stalled and when we don't have data
        rb_ready = bd_valid || !rb_has_data_q;
        cb_ready = bd_valid || !cb_has_data_q;

        // Drive data if we are not stalled.
        if (bd_valid) begin
            assert (cb_has_data_q);
            assert (rb_has_data_q);
            cb_has_data_d = 0;
            rb_has_data_d = 0;

            // Update the row index, then the subblock index if necessary.
            rb_row_idx_d = rb_row_idx_q == 38 ? 0 : rb_row_idx_q + 1;
            if (rb_row_idx_d == 0) sb_idx_8x8_d[0] = sb_idx_8x8_q[0] + 1;
            sb_idx_8x8_d[1] = sb_idx_8x8_q[0];
            sb_idx_8x8_d[2] = sb_idx_8x8_q[1];
        end

        // Handshake and buffer data from the stream.
        if (rb_ready && rb_valid) begin
            rb_d = rb;
            rb_has_data_d = 1;
        end

        if (cb_ready && cb_valid) begin
            cb_d = cb;
            cb_has_data_d = 1;
        end
    end

    always_ff @(posedge clk) begin
        if (clear) begin
            rb_q <= '0;
            rb_has_data_q <= '0;
            for (int i = 0; i < 4; i++) cb_q[i] <= '0;
            cb_has_data_q <= '0;

            rb_row_idx_q <= '0;
            for (int i = 0; i < 3; i++) sb_idx_8x8_q[i] <= '0;
        end else begin
            rb_q <= rb_d;
            rb_has_data_q <= rb_has_data_d;
            cb_q <= cb_d;
            cb_has_data_q <= cb_has_data_d;

            rb_row_idx_q <= rb_row_idx_d;
            sb_idx_8x8_q <= sb_idx_8x8_d;
        end

        clear_q <= clear_d;
    end

endmodule
