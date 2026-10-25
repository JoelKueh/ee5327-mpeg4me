// fs_control_unit_test.sv
//
// svunit testbench for fs_control (RB/CB handshake + datapath control).
//
`include "svunit_defines.svh"

module fs_control_unit_test;

    import me_pkg::*;
    import svunit_pkg::svunit_testcase;
    import fs_tb_common_pkg::*;

    // ------------------------------------------------------------------
    // test_wiring
    // ------------------------------------------------------------------

    typedef logic [WINDOW_SIZE+6:0][PEL_W-1:0] rb_row_t;
    typedef logic [7:0][PEL_W-1:0] cb_row_t;
    typedef logic [PEL_W-1:0] frame_t[FRAME_HEIGHT][FRAME_WIDTH];

    logic clk;
    logic clear;
    logic rb_ready;
    logic rb_valid;
    logic [WINDOW_SIZE+6:0][PEL_W-1:0] rb;
    logic cb_ready;
    logic cb_valid;
    logic [7:0][PEL_W-1:0] cb;
    logic result_8x4_valid[2];
    logic result_8x8_valid;
    logic result_16x8_valid;
    logic result_16x16_valid;
    logic [SAD_8X4_W-1:0] result_min_8x4[2];
    logic [SAD_8X8_W-1:0] result_min_8x8;
    logic [SAD_16X8_W-1:0] result_min_16x8;
    logic [SAD_16X16_W-1:0] result_min_16x16;
    mv_t result_mv_8x4[2];
    mv_t result_mv_8x8;
    mv_t result_mv_16x8;
    mv_t result_mv_16x16;

    fs_control dut (.*);

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, fs_control_unit_test, "+mda", "+all");
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ------------------------------------------------------------------
    // Verification Data Structures & Queues
    // ------------------------------------------------------------------

    typedef struct {
        logic [SAD_8X4_W-1:0]   min_8x4[8];      // 4 sub-blocks x 2 (top/bot)
        mv_t                    mv_8x4[8];
        logic [SAD_8X8_W-1:0]   min_8x8[4];      // 4 sub-blocks
        mv_t                    mv_8x8[4];
        logic [SAD_16X8_W-1:0]  min_16x8[2];     // 2 horizontal partitions (Top, Bottom)
        mv_t                    mv_16x8[2];
        logic [SAD_16X8_W-1:0]  min_8x16[2];     // 2 vertical partitions (Left, Right)
        mv_t                    mv_8x16[2];
        logic [SAD_16X16_W-1:0] min_16x16;       // 1 macroblock
        mv_t                    mv_16x16;
    } mb_results_t;

    // Queues to capture streaming DUT outputs
    logic [SAD_8X4_W-1:0]   act_min_8x4_q0[$], act_min_8x4_q1[$];
    mv_t                    act_mv_8x4_q0[$],  act_mv_8x4_q1[$];
    logic [SAD_8X8_W-1:0]   act_min_8x8_q[$];
    mv_t                    act_mv_8x8_q[$];
    logic [SAD_16X8_W-1:0]  act_min_16x8_q[$];
    mv_t                    act_mv_16x8_q[$];
    logic [SAD_16X16_W-1:0] act_min_16x16_q[$];
    mv_t                    act_mv_16x16_q[$];

    function void clear_queues();
        act_min_8x4_q0.delete();
        act_min_8x4_q1.delete();
        act_mv_8x4_q0.delete();
        act_mv_8x4_q1.delete();
        act_min_8x8_q.delete();
        act_mv_8x8_q.delete();
        act_min_16x8_q.delete();
        act_mv_16x8_q.delete();
        act_min_16x16_q.delete();
        act_mv_16x16_q.delete();
    endfunction

    // Output Monitor: Captures valid results on every clock edge
    always @(posedge clk) begin
        if (!clear) begin
            if (result_8x4_valid[0]) begin
                act_min_8x4_q0.push_back(result_min_8x4[0]);
                act_mv_8x4_q0.push_back(result_mv_8x4[0]);
            end
            if (result_8x4_valid[1]) begin
                act_min_8x4_q1.push_back(result_min_8x4[1]);
                act_mv_8x4_q1.push_back(result_mv_8x4[1]);
            end
            if (result_8x8_valid) begin
                act_min_8x8_q.push_back(result_min_8x8);
                act_mv_8x8_q.push_back(result_mv_8x8);
            end
            if (result_16x8_valid) begin
                act_min_16x8_q.push_back(result_min_16x8);
                act_mv_16x8_q.push_back(result_mv_16x8);
            end
            if (result_16x16_valid) begin
                act_min_16x16_q.push_back(result_min_16x16);
                act_mv_16x16_q.push_back(result_mv_16x16);
            end
        end
    end

    // ------------------------------------------------------------------
    // Golden Reference Model
    // ------------------------------------------------------------------

    // Helper to convert (dy, dx) search index [0..WINDOW_SIZE-1] to mv_t.
    // Adjust field names or signed offsets (e.g., dy - 16) if your mv_t uses signed coordinates.
    function automatic mv_t to_mv(int dy, int dx);
        mv_t mv;
        // Assuming packed or struct {y, x} - update if mv_t has specific field names:
        mv = {dy[($bits(mv_t)/2)-1:0], dx[($bits(mv_t)/2)-1:0]};
        return mv;
    endfunction

    // Computes all expected minimum SADs and MVs for a 16x16 Macroblock (4 8x8 sub-blocks)
    function automatic void calc_expected_results(
        input  rb_row_t     sb_rb[4][39],
        input  cb_row_t     sb_cb[4][8],
        output mb_results_t exp
    );
        int sad_8x4_grid[4][2][WINDOW_SIZE][WINDOW_SIZE];
        int sad_8x8_grid[4][WINDOW_SIZE][WINDOW_SIZE];
        int sad_16x8_0, sad_16x8_1, sad_8x16_0, sad_8x16_1, sad_16x16;

        // Initialize minimums to max value
        for (int i = 0; i < 8; i++) exp.min_8x4[i] = '1;
        for (int i = 0; i < 4; i++) exp.min_8x8[i] = '1;
        for (int i = 0; i < 2; i++) begin
            exp.min_16x8[i] = '1;
            exp.min_8x16[i] = '1;
        end
        exp.min_16x16 = '1;

        // 1. Calculate 8x4 and 8x8 SADs per sub-block across the search window
        for (int sb = 0; sb < 4; sb++) begin
            for (int dy = 0; dy < WINDOW_SIZE; dy++) begin
                for (int dx = 0; dx < WINDOW_SIZE; dx++) begin
                    int sum_top = 0;
                    int sum_bot = 0;

                    for (int r = 0; r < 4; r++) begin
                        for (int c = 0; c < 8; c++) begin
                            int diff_top = int'(sb_cb[sb][r][c])   - int'(sb_rb[sb][dy + r][dx + c]);
                            int diff_bot = int'(sb_cb[sb][r+4][c]) - int'(sb_rb[sb][dy + r + 4][dx + c]);
                            sum_top += (diff_top < 0) ? -diff_top : diff_top;
                            sum_bot += (diff_bot < 0) ? -diff_bot : diff_bot;
                        end
                    end

                    sad_8x4_grid[sb][0][dy][dx] = sum_top;
                    sad_8x4_grid[sb][1][dy][dx] = sum_bot;
                    sad_8x8_grid[sb][dy][dx]    = sum_top + sum_bot;

                    // Track 8x4 Top Min (strictly '<' favors first-seen on tie)
                    if (sum_top < exp.min_8x4[2*sb]) begin
                        exp.min_8x4[2*sb] = sum_top[SAD_8X4_W-1:0];
                        exp.mv_8x4[2*sb]  = to_mv(dy, dx);
                    end
                    // Track 8x4 Bottom Min
                    if (sum_bot < exp.min_8x4[2*sb + 1]) begin
                        exp.min_8x4[2*sb + 1] = sum_bot[SAD_8X4_W-1:0];
                        exp.mv_8x4[2*sb + 1]  = to_mv(dy, dx);
                    end
                    // Track 8x8 Min
                    if ((sum_top + sum_bot) < exp.min_8x8[sb]) begin
                        exp.min_8x8[sb] = (sum_top + sum_bot)[SAD_8X8_W-1:0];
                        exp.mv_8x8[sb]  = to_mv(dy, dx);
                    end
                end
            end
        end

        // 2. Combine 8x8 SAD grids to find 16x8, 8x16, and 16x16 minimums
        // Sub-block layout:
        //   [0: Top-Left ] [1: Top-Right]
        //   [2: Bot-Left ] [3: Bot-Right]
        for (int dy = 0; dy < WINDOW_SIZE; dy++) begin
            for (int dx = 0; dx < WINDOW_SIZE; dx++) begin
                sad_16x8_0 = sad_8x8_grid[0][dy][dx] + sad_8x8_grid[1][dy][dx]; // Top 16x8
                sad_16x8_1 = sad_8x8_grid[2][dy][dx] + sad_8x8_grid[3][dy][dx]; // Bot 16x8
                sad_8x16_0 = sad_8x8_grid[0][dy][dx] + sad_8x8_grid[2][dy][dx]; // Left 8x16
                sad_8x16_1 = sad_8x8_grid[1][dy][dx] + sad_8x8_grid[3][dy][dx]; // Right 8x16
                sad_16x16  = sad_16x8_0 + sad_16x8_1;                           // Full 16x16

                if (sad_16x8_0 < exp.min_16x8[0]) begin
                    exp.min_16x8[0] = sad_16x8_0[SAD_16X8_W-1:0];
                    exp.mv_16x8[0]  = to_mv(dy, dx);
                end
                if (sad_16x8_1 < exp.min_16x8[1]) begin
                    exp.min_16x8[1] = sad_16x8_1[SAD_16X8_W-1:0];
                    exp.mv_16x8[1]  = to_mv(dy, dx);
                end
                if (sad_8x16_0 < exp.min_8x16[0]) begin
                    exp.min_8x16[0] = sad_8x16_0[SAD_16X8_W-1:0];
                    exp.mv_8x16[0]  = to_mv(dy, dx);
                end
                if (sad_8x16_1 < exp.min_8x16[1]) begin
                    exp.min_8x16[1] = sad_8x16_1[SAD_16X8_W-1:0];
                    exp.mv_8x16[1]  = to_mv(dy, dx);
                end
                if (sad_16x16 < exp.min_16x16) begin
                    exp.min_16x16 = sad_16x16[SAD_16X16_W-1:0];
                    exp.mv_16x16  = to_mv(dy, dx);
                end
            end
        end
    endfunction

    // ------------------------------------------------------------------
    // Checker Routine
    // ------------------------------------------------------------------

    task automatic check_mb_results(input mb_results_t exp);
        // Ensure all expected outputs were captured
        `FAIL_UNLESS_EQUAL(act_min_8x4_q0.size(), 4)
        `FAIL_UNLESS_EQUAL(act_min_8x4_q1.size(), 4)
        `FAIL_UNLESS_EQUAL(act_min_8x8_q.size(), 4)
        `FAIL_UNLESS_EQUAL(act_min_16x8_q.size(), 4)
        `FAIL_UNLESS_EQUAL(act_min_16x16_q.size(), 1)

        // Check 8x4 and 8x8 results across all 4 sub-blocks
        for (int sb = 0; sb < 4; sb++) begin
            `FAIL_UNLESS_EQUAL(act_min_8x4_q0[sb], exp.min_8x4[2*sb])
            `FAIL_UNLESS_EQUAL(act_mv_8x4_q0[sb],  exp.mv_8x4[2*sb])

            `FAIL_UNLESS_EQUAL(act_min_8x4_q1[sb], exp.min_8x4[2*sb + 1])
            `FAIL_UNLESS_EQUAL(act_mv_8x4_q1[sb],  exp.mv_8x4[2*sb + 1])

            `FAIL_UNLESS_EQUAL(act_min_8x8_q[sb],  exp.min_8x8[sb])
            `FAIL_UNLESS_EQUAL(act_mv_8x8_q[sb],   exp.mv_8x8[sb])
        end

        // Check 16x8 and 8x16 results (assuming emission order: LXS_0, LXS_1, SXL_0, SXL_1)
        // Note: Reorder indices if your FSM emits SXL_0 before LXS_1
        `FAIL_UNLESS_EQUAL(act_min_16x8_q[0], exp.min_16x8[0]) // SAD_LXS_0 (Top 16x8)
        `FAIL_UNLESS_EQUAL(act_mv_16x8_q[0],  exp.mv_16x8[0])

        `FAIL_UNLESS_EQUAL(act_min_16x8_q[1], exp.min_16x8[1]) // SAD_LXS_1 (Bot 16x8)
        `FAIL_UNLESS_EQUAL(act_mv_16x8_q[1],  exp.mv_16x8[1])

        `FAIL_UNLESS_EQUAL(act_min_16x8_q[2], exp.min_8x16[0]) // SAD_SXL_0 (Left 8x16)
        `FAIL_UNLESS_EQUAL(act_mv_16x8_q[2],  exp.mv_8x16[0])

        `FAIL_UNLESS_EQUAL(act_min_16x8_q[3], exp.min_8x16[1]) // SAD_SXL_1 (Right 8x16)
        `FAIL_UNLESS_EQUAL(act_mv_16x8_q[3],  exp.mv_8x16[1])

        // Check 16x16 result
        `FAIL_UNLESS_EQUAL(act_min_16x16_q[0], exp.min_16x16)
        `FAIL_UNLESS_EQUAL(act_mv_16x16_q[0],  exp.mv_16x16)
    endtask

    // ------------------------------------------------------------------
    // Stimulus Tasks
    // ------------------------------------------------------------------

    task automatic drive_cycle(rb_row_t rb_d, cb_row_t cb_d);
        rb_valid = 1;
        rb = rb_d;
        cb_valid = 1;
        cb = cb_d;

        #0;
        do begin
            @(posedge clk);
        end while (!rb_ready); // Respect backpressure if rb_ready deasserts
        #0;
    endtask

    task automatic drive_subblock(rb_row_t rb_d[39], cb_row_t cb_d[8]);
        for (int i = 0; i < 39; i++) begin
            if (i < 8) begin
                drive_cycle(rb_d[i], cb_d[i]);
            end else begin
                drive_cycle(rb_d[i], 'x);
            end
        end
    endtask

    task automatic get_sb(inout rb_row_t rb_d[39], cb_row_t cb_d[8], input frame_t rf, frame_t cf,
                          int b_idx, int sb_idx);
        int signed b_row, b_col;
        int signed sb_row_off, sb_col_off;
        int signed rf_row, rf_col;
        int signed cf_row, cf_col;

        b_row = b_idx / 80;
        b_col = b_idx % 80;

        // Sub-block offset within the 16x16 macroblock:
        // sb_idx 0: (0,0), 1: (0,8), 2: (8,0), 3: (8,8)
        sb_row_off = (sb_idx / 2) * 8;
        sb_col_off = (sb_idx % 2) * 8;

        rf_row = (b_row - 1) * 16 + sb_row_off;
        rf_col = (b_col - 1) * 16 + sb_col_off;

        for (int row = 0; row < 39; row++) begin
            for (int col = 0; col < 39; col++) begin
                if ((rf_row + row) >= 0 && (rf_row + row) < FRAME_HEIGHT &&
                    (rf_col + col) >= 0 && (rf_col + col) < FRAME_WIDTH)
                    rb_d[row][col] = rf[rf_row+row][rf_col+col];
                else
                    rb_d[row][col] = '0;
            end
        end

        cf_row = b_row * 16 + sb_row_off;
        cf_col = b_col * 16 + sb_col_off;

        for (int row = 0; row < 8; row++) begin
            for (int col = 0; col < 8; col++) begin
                if ((cf_row + row) >= 0 && (cf_row + row) < FRAME_HEIGHT &&
                    (cf_col + col) >= 0 && (cf_col + col) < FRAME_WIDTH)
                    cb_d[row][col] = cf[cf_row+row][cf_col+col];
                else
                    cb_d[row][col] = '0;
            end
        end
    endtask

    // ------------------------------------------------------------------
    // svunit scaffolding
    // ------------------------------------------------------------------

    string name = "fs_control_ut";
    svunit_testcase svunit_ut;

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        clear_queues();
        clear    = 1;
        rb_valid = '0;
        cb_valid = '0;
        rb       = '0;
        cb       = '0;
        repeat (2) @(posedge clk);
        clear    = 0;
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN

    // 1. Directed Zero-SAD Match Test (Sanity Check)
    `SVTEST(directed_exact_match)
        rb_row_t     sb_rb[4][39];
        cb_row_t     sb_cb[4][8];
        mb_results_t exp;
        int          target_dy = 5;
        int          target_dx = 12;

        // Fill reference blocks with all 255s, then plant a distinct pattern at (target_dy, target_dx)
        for (int sb = 0; sb < 4; sb++) begin
            for (int r = 0; r < 39; r++)
                for (int c = 0; c < 39; c++)
                    sb_rb[sb][r][c] = 8'hFF;

            for (int r = 0; r < 8; r++) begin
                for (int c = 0; c < 8; c++) begin
                    logic [PEL_W-1:0] val = (sb * 64) + (r * 8) + c;
                    sb_cb[sb][r][c] = val;
                    sb_rb[sb][target_dy + r][target_dx + c] = val; // Exact match
                end
            end
        end

        calc_expected_results(sb_rb, sb_cb, exp);

        // Drive all 4 sub-blocks of the macroblock
        for (int sb = 0; sb < 4; sb++) begin
            drive_subblock(sb_rb[sb], sb_cb[sb]);
        end

        // Flush pipeline (drive dummy cycles or wait for final 16x16 valid)
        rb_valid = 0;
        cb_valid = 0;
        wait (act_min_16x16_q.size() == 1);
        repeat (5) @(posedge clk);

        // Verify SAD is 0 and MVs point to (target_dy, target_dx)
        `FAIL_UNLESS_EQUAL(exp.min_16x16, 0)
        check_mb_results(exp);
    `SVTEST_END

    // 2. Randomized Full Macroblock Test
    `SVTEST(typical)
        rb_row_t     sb_rb[4][39];
        cb_row_t     sb_cb[4][8];
        mb_results_t exp;

        std::randomize(sb_rb);
        std::randomize(sb_cb);

        calc_expected_results(sb_rb, sb_cb, exp);

        // Drive the 4 sub-blocks of the 16x16 macroblock
        for (int sb = 0; sb < 4; sb++) begin
            drive_subblock(sb_rb[sb], sb_cb[sb]);
        end

        // Drive 2 extra sub-blocks if pipeline requires continuous streaming to flush
        drive_subblock(sb_rb[0], sb_cb[0]);
        drive_subblock(sb_rb[1], sb_cb[1]);

        rb_valid = 0;
        cb_valid = 0;

        // Trim queues to first macroblock (4 sub-blocks) if extra blocks flushed more outputs
        while (act_min_8x4_q0.size() > 4) void'(act_min_8x4_q0.pop_back());
        while (act_min_8x4_q1.size() > 4) void'(act_min_8x4_q1.pop_back());
        while (act_min_8x8_q.size()  > 4) void'(act_min_8x8_q.pop_back());

        check_mb_results(exp);
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
