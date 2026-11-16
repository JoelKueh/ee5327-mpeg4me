// fs_control.sv
//
// Control module for the full search motion estimation system.
// Uses quarter-width strided comparators at all levels (4x4, 4x8, 8x4, 8x8, 16x8, 16x16).
//

module fs_control (
    input logic clk,
    input logic clear,
    input logic stall,

    // Data is streamed into the block: 39-pel reference row and four 4-pel CB rows
    input logic [me_pkg::WINDOW_SIZE+6:0][me_pkg::PEL_W-1:0] rb,
    input logic [3:0][me_pkg::PEL_W-1:0]                     cb[4],

    // Valid output of the different comparators
    output logic result_4x4_valid[4],
    output logic result_4x8_valid[2],
    output logic result_8x4_valid[2],
    output logic result_8x8_valid,
    output logic result_16x8_valid,
    output logic result_16x16_valid,

    // Metadata IDs for combined SADs (if needed by top-level)
    output me_pkg::comb_sad_id_t result_16x8_id,
    output logic [1:0]           result_16x16_sb_idx,

    // Minimum SAD output of the different comparators
    output logic [me_pkg::SAD_4X4_W-1:0]   result_min_4x4[4],
    output logic [me_pkg::SAD_8X4_W-1:0]   result_min_4x8[2],
    output logic [me_pkg::SAD_8X4_W-1:0]   result_min_8x4[2],
    output logic [me_pkg::SAD_8X8_W-1:0]   result_min_8x8,
    output logic [me_pkg::SAD_16X8_W-1:0]  result_min_16x8,
    output logic [me_pkg::SAD_16X16_W-1:0] result_min_16x16,

    // Motion vector output of the different comparators
    output me_pkg::mv_t result_mv_4x4[4],
    output me_pkg::mv_t result_mv_4x8[2],
    output me_pkg::mv_t result_mv_8x4[2],
    output me_pkg::mv_t result_mv_8x8,
    output me_pkg::mv_t result_mv_16x8,
    output me_pkg::mv_t result_mv_16x16
);

    import me_pkg::*;

    localparam int SLICE_SIZE  = WINDOW_SIZE / 4; // 8 elements per subcycle
    localparam int NUM_RB_ROWS = WINDOW_SIZE + 7; // 39 reference rows per subblock

    // Current subcycle, row, and subblock trackers
    logic [1:0]             subcycle_idx_q, subcycle_idx_d;
    logic [RB_ROW_IDX_W-1:0] rb_row_idx_q, rb_row_idx_d;
    logic [1:0]             sb_idx_8x8_q[3], sb_idx_8x8_d[3];
    logic                   stall_q[2], stall_d[2];

    // Valid & index outputs from fs_computer
    logic                   sad_valid;
    logic [SW_IDX_W-1:0]    sad_sw_idx;

    // Full-width SAD outputs from fs_computer (held for 4 cycles after sad_valid)
    logic [SAD_4X4_W-1:0]   sad_4x4[4][WINDOW_SIZE];
    logic [SAD_8X4_W-1:0]   sad_4x8[2][WINDOW_SIZE];
    logic [SAD_8X4_W-1:0]   sad_8x4[2][WINDOW_SIZE];
    logic [SAD_8X8_W-1:0]   sad_8x8[WINDOW_SIZE];

    // Quarter-width strided slices for fs_computer comparators
    logic [2:0]             comp_beat_q, comp_beat_d;
    logic                   comp_sub_valid;
    logic [1:0]             comp_sub_idx;
    logic                   comp_sub_last;
    logic [SAD_4X4_W-1:0]   sad_4x4_slice[4][SLICE_SIZE];
    logic [SAD_8X4_W-1:0]   sad_4x8_slice[2][SLICE_SIZE];
    logic [SAD_8X4_W-1:0]   sad_8x4_slice[2][SLICE_SIZE];
    logic [SAD_8X8_W-1:0]   sad_8x8_slice[SLICE_SIZE];

    // Outputs from quarter-width fs_combiner
    logic                   sad_16x8_valid;
    logic                   sad_16x8_last;
    comb_sad_id_t           sad_16x8_id;
    logic [SW_IDX_W-1:0]    sw_idx_16x8;
    logic [1:0]             subcycle_idx_16x8;
    logic [SAD_16X8_W-1:0]  sad_16x8[SLICE_SIZE];

    logic                   sad_16x16_valid;
    logic                   sad_16x16_last;
    logic [1:0]             sb_idx_16x16;
    logic [SW_IDX_W-1:0]    sw_idx_16x16;
    logic [1:0]             subcycle_idx_16x16;
    logic [SAD_16X16_W-1:0] sad_16x16[SLICE_SIZE];

    // Registered IDs aligned with comparator 1-cycle latency
    comb_sad_id_t           result_16x8_id_q;
    logic [1:0]             result_16x16_sb_idx_q;

    logic                   clear_q, clear_d;
    logic                   comb_clear_out;

    // ------------------------------------------------------------------
    // 1. First-Stage SAD Computer
    // ------------------------------------------------------------------
    fs_computer computer (
        .clk          (clk),
        .clear        (clear),
        .stall        (stall),

        .cb           (cb),
        .rb           (rb),
        .rb_row_idx   (rb_row_idx_q),
        .subcycle_idx (subcycle_idx_q),

        .sad_valid    (sad_valid),
        .sad_sw_idx   (sad_sw_idx),
        .sad_4x4      (sad_4x4),
        .sad_4x8      (sad_4x8),
        .sad_8x4      (sad_8x4),
        .sad_8x8      (sad_8x8)
    );

    // ------------------------------------------------------------------
    // 2. Quarter-Width Strided Combiner (8x8 -> 16x8 / 8x16 / 16x16)
    // ------------------------------------------------------------------
    fs_combiner comb8x8 (
        .clk                (clk),
        .clear_in           (clear_q),
        .clear_out          (comb_clear_out),

        .sad_8x8_valid      (sad_valid),
        .sad_8x8_last       (sad_sw_idx == SW_IDX_W'(WINDOW_SIZE - 1)),
        .sb_idx_8x8         (sb_idx_8x8_q[2]),
        .sw_idx_8x8         (sad_sw_idx),
        .sad_8x8            (sad_8x8),

        .sad_16x8_valid     (sad_16x8_valid),
        .sad_16x8_last      (sad_16x8_last),
        .sad_16x8_id        (sad_16x8_id),
        .sw_idx_16x8        (sw_idx_16x8),
        .subcycle_idx_16x8  (subcycle_idx_16x8),
        .sad_16x8           (sad_16x8),

        .sad_16x16_valid    (sad_16x16_valid),
        .sad_16x16_last     (sad_16x16_last),
        .sb_idx_16x16       (sb_idx_16x16),
        .sw_idx_16x16       (sw_idx_16x16),
        .subcycle_idx_16x16 (subcycle_idx_16x16),
        .sad_16x16          (sad_16x16)
    );

    // ------------------------------------------------------------------
    // 3. Quarter Comparators for Computer & Combiner Outputs
    // ------------------------------------------------------------------
    genvar i;

    // 4x4 Quarter Comparators (4 quadrants)
    generate
        for (i = 0; i < 4; i++) begin : comparator_4x4
            fs_quarter_comparator #(SAD_4X4_W) comparator (
                .clk                (clk),
                .clear              (clear_q),

                .input_valid        (comp_sub_valid),
                .input_last         (comp_sub_last),
                .input_subcycle_idx (comp_sub_idx),
                .input_sw_idx       (sad_sw_idx),
                .input_sads         (sad_4x4_slice[i]),

                .result_valid       (result_4x4_valid[i]),
                .result_sad         (result_min_4x4[i]),
                .result_mv          (result_mv_4x4[i])
            );
        end
    endgenerate

    // 4x8 Quarter Comparators (2 halves: upper and lower)
    generate
        for (i = 0; i < 2; i++) begin : comparator_4x8
            fs_quarter_comparator #(SAD_8X4_W) comparator (
                .clk                (clk),
                .clear              (clear_q),

                .input_valid        (comp_sub_valid),
                .input_last         (comp_sub_last),
                .input_subcycle_idx (comp_sub_idx),
                .input_sw_idx       (sad_sw_idx),
                .input_sads         (sad_4x8_slice[i]),

                .result_valid       (result_4x8_valid[i]),
                .result_sad         (result_min_4x8[i]),
                .result_mv          (result_mv_4x8[i])
            );
        end
    endgenerate

    // 8x4 Quarter Comparators (2 halves: left and right)
    generate
        for (i = 0; i < 2; i++) begin : comparator_8x4
            fs_quarter_comparator #(SAD_8X4_W) comparator (
                .clk                (clk),
                .clear              (clear_q),

                .input_valid        (comp_sub_valid),
                .input_last         (comp_sub_last),
                .input_subcycle_idx (comp_sub_idx),
                .input_sw_idx       (sad_sw_idx),
                .input_sads         (sad_8x4_slice[i]),

                .result_valid       (result_8x4_valid[i]),
                .result_sad         (result_min_8x4[i]),
                .result_mv          (result_mv_8x4[i])
            );
        end
    endgenerate

    // 8x8 Quarter Comparator
    fs_quarter_comparator #(SAD_8X8_W) comparator_8x8 (
        .clk                (clk),
        .clear              (clear_q),

        .input_valid        (comp_sub_valid),
        .input_last         (comp_sub_last),
        .input_subcycle_idx (comp_sub_idx),
        .input_sw_idx       (sad_sw_idx),
        .input_sads         (sad_8x8_slice),

        .result_valid       (result_8x8_valid),
        .result_sad         (result_min_8x8),
        .result_mv          (result_mv_8x8)
    );

    // 16x8 / 8x16 Quarter Comparator (fed by fs_combiner)
    fs_quarter_comparator #(SAD_16X8_W) comparator_16x8 (
        .clk                (clk),
        .clear              (comb_clear_out),

        .input_valid        (sad_16x8_valid),
        .input_last         (sad_16x8_last),
        .input_subcycle_idx (subcycle_idx_16x8),
        .input_sw_idx       (sw_idx_16x8),
        .input_sads         (sad_16x8),

        .result_valid       (result_16x8_valid),
        .result_sad         (result_min_16x8),
        .result_mv          (result_mv_16x8)
    );

    // 16x16 Quarter Comparator (fed by fs_combiner)
    fs_quarter_comparator #(SAD_16X16_W) comparator_16x16 (
        .clk                (clk),
        .clear              (comb_clear_out),

        .input_valid        (sad_16x16_valid),
        .input_last         (sad_16x16_last),
        .input_subcycle_idx (subcycle_idx_16x16),
        .input_sw_idx       (sw_idx_16x16),
        .input_sads         (sad_16x16),

        .result_valid       (result_16x16_valid),
        .result_sad         (result_min_16x16),
        .result_mv          (result_mv_16x16)
    );

    // ------------------------------------------------------------------
    // 4. Subcycle Slicing & Control Sequencing
    // ------------------------------------------------------------------
    always_comb begin
        // Stretch sad_valid (1 cycle) across 4 beats (0, 1, 2, 3) to slice held fs_computer outputs
        comp_beat_d    = {comp_beat_q[1:0], sad_valid};
        comp_sub_valid = sad_valid | (|comp_beat_q);

        priority case (1'b1)
            sad_valid:      comp_sub_idx = 2'd0;
            comp_beat_q[0]: comp_sub_idx = 2'd1;
            comp_beat_q[1]: comp_sub_idx = 2'd2;
            comp_beat_q[2]: comp_sub_idx = 2'd3;
            default:        comp_sub_idx = 2'd0;
        endcase

        comp_sub_last = (sad_sw_idx == SW_IDX_W'(WINDOW_SIZE - 1)) && (comp_sub_idx == 2'd3);

        // Extract stride-4 slices (col = 4*c + comp_sub_idx) for the direct fs_computer comparators
        for (int c = 0; c < SLICE_SIZE; c++) begin
            for (int q = 0; q < 4; q++) begin
                sad_4x4_slice[q][c] = sad_4x4[q][4*c + comp_sub_idx];
            end
            for (int p = 0; p < 2; p++) begin
                sad_4x8_slice[p][c] = sad_4x8[p][4*c + comp_sub_idx];
                sad_8x4_slice[p][c] = sad_8x4[p][4*c + comp_sub_idx];
            end
            sad_8x8_slice[c] = sad_8x8[4*c + comp_sub_idx];
        end

        // Input row and subcycle counters for fs_computer
        clear_d        = clear;
        stall_d[0]     = stall;
        stall_d[1]     = stall_q[0];

        subcycle_idx_d = subcycle_idx_q + 2'd1;
        rb_row_idx_d   = rb_row_idx_q;
        sb_idx_8x8_d   = sb_idx_8x8_q;

        if (subcycle_idx_q == 2'd3) begin
            if (rb_row_idx_q == RB_ROW_IDX_W'(NUM_RB_ROWS - 1)) begin
                rb_row_idx_d    = '0;
                sb_idx_8x8_d[0] = sb_idx_8x8_q[0] + 2'd1;
            end else begin
                rb_row_idx_d    = rb_row_idx_q + 1'b1;
            end
        end

        // Pipeline subblock index to align with fs_computer output stage:
        //  - sb_idx_8x8_q[0]: active input subblock (rows 0..38 at input)
        //  - sb_idx_8x8_q[1]: registered into Stage 1 of fs_computer (rb_row_idx_q inside fs_computer)
        //  - sb_idx_8x8_q[2]: registered into Stage 2 of fs_computer (aligned with sad_valid / sad_8x8)
		sb_idx_8x8_d[1] = sb_idx_8x8_q[0];
        if (rb_row_idx_q == 6'd4) begin
            sb_idx_8x8_d[2] = sb_idx_8x8_q[1];
        end
    end

    always_ff @(posedge clk) begin
        if (clear) begin
            subcycle_idx_q        <= '0;
            rb_row_idx_q          <= '0;
            comp_beat_q           <= '0;
            result_16x8_id_q      <= SAD_LXS_0;
            result_16x16_sb_idx_q <= '0;
            for (int i = 0; i < 2; i++) stall_q[i]      <= '0;
            for (int i = 0; i < 3; i++) sb_idx_8x8_q[i] <= '0;
        end else begin
            stall_q               <= stall_d;
            comp_beat_q           <= comp_beat_d;
            result_16x8_id_q      <= sad_16x8_id;
            result_16x16_sb_idx_q <= sb_idx_16x16;

            if (!stall) begin
                subcycle_idx_q  <= subcycle_idx_d;
                rb_row_idx_q    <= rb_row_idx_d;
                sb_idx_8x8_q[0] <= sb_idx_8x8_d[0];
                sb_idx_8x8_q[1] <= sb_idx_8x8_d[1];
            end

            sb_idx_8x8_q[2] <= sb_idx_8x8_d[2];
        end

        clear_q <= clear_d;
    end

    assign result_16x8_id      = result_16x8_id_q;
    assign result_16x16_sb_idx = result_16x16_sb_idx_q;

endmodule
