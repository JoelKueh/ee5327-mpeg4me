// fs_control.sv
//
// Control module for the full search motion estimation system.
// Uses quarter-width strided comparators at all levels (4x4, 4x8, 8x4, 8x8, 16x8, 16x16).
//

module fs_control import me_pkg::*; (
    input logic clk,
    input logic clear,
    input logic stall,

    // Data is streamed into the block: 39-pel reference row and four 4-pel CB rows
    input logic [WINDOW_SIZE+6:0][PEL_W-1:0] rb,
    input logic [3:0][PEL_W-1:0]             cb[4],

    // Valid output of the different comparators
    output logic result_4x4_valid[4],
    output logic result_4x8_valid[2],
    output logic result_8x4_valid[2],
    output logic result_8x8_valid,
    output logic result_16x8_valid,
    output logic result_16x16_valid,

    // Metadata IDs for combined SADs (if needed by top-level)
    output comb_sad_id_t result_16x8_id,
    output logic [1:0]   result_16x16_sb_idx,

    // Minimum SAD output of the different comparators
    output logic [SAD_4X4_W-1:0]   result_min_4x4[4],
    output logic [SAD_8X4_W-1:0]   result_min_4x8[2],
    output logic [SAD_8X4_W-1:0]   result_min_8x4[2],
    output logic [SAD_8X8_W-1:0]   result_min_8x8,
    output logic [SAD_16X8_W-1:0]  result_min_16x8,
    output logic [SAD_16X16_W-1:0] result_min_16x16,

    // Motion vector output of the different comparators
    output mv_t result_mv_4x4[4],
    output mv_t result_mv_4x8[2],
    output mv_t result_mv_8x4[2],
    output mv_t result_mv_8x8,
    output mv_t result_mv_16x8,
    output mv_t result_mv_16x16
);

    localparam int NUM_RB_ROWS = WINDOW_SIZE + 7; // 39 reference rows per subblock

    // Input sequencing registers
    logic [RB_ROW_IDX_W-1:0] rb_row_idx_q, rb_row_idx_d;
    logic [1:0]              subcycle_idx_q, subcycle_idx_d;
    logic [1:0]              sb_idx_8x8_q[3], sb_idx_8x8_d[3];

    // Valid & index outputs from fs_computer (sad_valid is asserted for all 4 subcycles)
    logic                    sad_valid;
    logic [1:0]              sad_subcycle_idx;
    logic [SW_IDX_W-1:0]     sad_sw_idx;

    // Quarter-width strided slices from fs_computer
    logic [SAD_4X4_W-1:0]    sad_4x4[4][SLICE_SIZE];
    logic [SAD_8X4_W-1:0]    sad_4x8[2][SLICE_SIZE];
    logic [SAD_8X4_W-1:0]    sad_8x4[2][SLICE_SIZE];
    logic [SAD_8X8_W-1:0]    sad_8x8[SLICE_SIZE];

    // End-of-window framing signals for combiner & comparators
    logic                    comp_row_last;
    logic                    comp_slice_last;

    // Outputs from quarter-width fs_combiner
    logic                    sad_16x8_valid;
    logic                    sad_16x8_last;
    comb_sad_id_t            sad_16x8_id;
    logic [SW_IDX_W-1:0]     sw_idx_16x8;
    logic [1:0]              subcycle_idx_16x8;
    logic [SAD_16X8_W-1:0]   sad_16x8[SLICE_SIZE];

    logic                    sad_16x16_valid;
    logic                    sad_16x16_last;
    logic [1:0]              sb_idx_16x16;
    logic [SW_IDX_W-1:0]     sw_idx_16x16;
    logic [1:0]              subcycle_idx_16x16;
    logic [SAD_16X16_W-1:0]  sad_16x16[SLICE_SIZE];

    // Registered IDs aligned with comparator 1-cycle latency
    comb_sad_id_t            result_16x8_id_q;
    logic [1:0]              result_16x16_sb_idx_q;

    logic                    clear_q, clear_d;
    logic                    comb_clear_out;

    // ------------------------------------------------------------------
    // 1. First-Stage SAD Computer
    // ------------------------------------------------------------------
    fs_computer computer (
        .clk              (clk),
        .clear            (clear),
        .stall            (stall),

        .cb               (cb),
        .rb               (rb),
        .rb_row_idx       (rb_row_idx_q),
        .subcycle_idx     (subcycle_idx_q),

        .sad_valid        (sad_valid),
        .sad_subcycle_idx (sad_subcycle_idx),
        .sad_sw_idx       (sad_sw_idx),
        .sad_4x4          (sad_4x4),
        .sad_4x8          (sad_4x8),
        .sad_8x4          (sad_8x4),
        .sad_8x8          (sad_8x8)
    );

    // ------------------------------------------------------------------
    // 2. Quarter-Width Strided Combiner (8x8 -> 16x8 / 8x16 / 16x16)
    // ------------------------------------------------------------------
    fs_combiner comb8x8 (
        .clk                (clk),
        .clear_in           (clear_q),
        .clear_out          (comb_clear_out),

        .sad_8x8_valid      (sad_valid),
        .sad_8x8_last       (comp_row_last),
        .sb_idx_8x8         (sb_idx_8x8_q[2]),
        .sw_idx_8x8         (sad_sw_idx),
        .subcycle_idx_8x8   (sad_subcycle_idx),
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

                .input_valid        (sad_valid),
                .input_last         (comp_slice_last),
                .input_subcycle_idx (sad_subcycle_idx),
                .input_sw_idx       (sad_sw_idx),
                .input_sads         (sad_4x4[i]),

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

                .input_valid        (sad_valid),
                .input_last         (comp_slice_last),
                .input_subcycle_idx (sad_subcycle_idx),
                .input_sw_idx       (sad_sw_idx),
                .input_sads         (sad_4x8[i]),

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

                .input_valid        (sad_valid),
                .input_last         (comp_slice_last),
                .input_subcycle_idx (sad_subcycle_idx),
                .input_sw_idx       (sad_sw_idx),
                .input_sads         (sad_8x4[i]),

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

        .input_valid        (sad_valid),
        .input_last         (comp_slice_last),
        .input_subcycle_idx (sad_subcycle_idx),
        .input_sw_idx       (sad_sw_idx),
        .input_sads         (sad_8x8),

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
    // 4. Control Sequencing
    // ------------------------------------------------------------------
    always_comb begin
        // Input row and subcycle counters for fs_computer
        clear_d        = clear;

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

        // End-of-row / end-of-window framing for combiner and comparators
        comp_row_last   = (sad_sw_idx == SW_IDX_W'(WINDOW_SIZE - 1));
        comp_slice_last = sad_valid && comp_row_last && (sad_subcycle_idx == 2'd3);
    end

    always_ff @(posedge clk) begin
        if (clear) begin
            subcycle_idx_q        <= '0;
            rb_row_idx_q          <= '0;
            result_16x8_id_q      <= SAD_LXS_0;
            result_16x16_sb_idx_q <= '0;
            for (int i = 0; i < 3; i++) sb_idx_8x8_q[i] <= '0;
        end else begin
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
