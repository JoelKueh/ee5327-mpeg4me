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

    // ------------------------------------------------------------------
    // Expected Results Structure & Stream Counters
    // ------------------------------------------------------------------

    typedef struct {
        // [sb_idx][0: left, 1: right] where sb_idx is 0:UL, 1:UR, 2:DL, 3:DR
        logic [SAD_8X4_W-1:0]   min_8x4[4][2];
        mv_t                    mv_8x4[4][2];

        // [sb_idx] in Morton order (0:UL, 1:UR, 2:DL, 3:DR)
        logic [SAD_8X8_W-1:0]   min_8x8[4];
        mv_t                    mv_8x8[4];

        // Ordered as emitted on result_16x8_valid:
        //   [0]: Upper (UL + UR)
        //   [1]: Left  (UL + DL)
        //   [2]: Right (UR + DR)
        //   [3]: Lower (DL + DR)
        logic [SAD_16X8_W-1:0]  min_16x8[4];
        mv_t                    mv_16x8[4];

        // Full 16x16 block
        logic [SAD_16X16_W-1:0] min_16x16;
        mv_t                    mv_16x16;
    } mb_results_t;

    // Expected results populated before driving each block b_idx
    mb_results_t exp_mb_q[int];

    // Independent stream counters
    int cnt_8x4_0;
    int cnt_8x4_1;
    int cnt_8x8;
    int cnt_16x8;
    int cnt_16x16;

    // ------------------------------------------------------------------
    // On-the-Fly 5-Stream Checker
    // ------------------------------------------------------------------

    // ------------------------------------------------------------------
    // On-the-Fly 5-Stream Checker
    // ------------------------------------------------------------------

    always @(posedge clk) begin
        int b_idx;
        int sb_idx;
        int p_idx;

        if (clear) begin
            cnt_8x4_0 <= 0;
            cnt_8x4_1 <= 0;
            cnt_8x8   <= 0;
            cnt_16x8  <= 0;
            cnt_16x16 <= 0;
        end else begin
            // Stream 1: Leftmost 8x4 (8x4[0]) in Morton order
            if (result_8x4_valid[0]) begin
                b_idx  = cnt_8x4_0 / 4;
                sb_idx = cnt_8x4_0 % 4;
                `FAIL_UNLESS_EQUAL(result_min_8x4[0], exp_mb_q[b_idx].min_8x4[sb_idx][0])
                `FAIL_UNLESS_EQUAL(result_mv_8x4[0],  exp_mb_q[b_idx].mv_8x4[sb_idx][0])
                cnt_8x4_0 <= cnt_8x4_0 + 1;
            end

            // Stream 2: Rightmost 8x4 (8x4[1]) in Morton order
            if (result_8x4_valid[1]) begin
                b_idx  = cnt_8x4_1 / 4;
                sb_idx = cnt_8x4_1 % 4;
                `FAIL_UNLESS_EQUAL(result_min_8x4[1], exp_mb_q[b_idx].min_8x4[sb_idx][1])
                `FAIL_UNLESS_EQUAL(result_mv_8x4[1],  exp_mb_q[b_idx].mv_8x4[sb_idx][1])
                cnt_8x4_1 <= cnt_8x4_1 + 1;
            end

            // Stream 3: 8x8 in Morton order
            if (result_8x8_valid) begin
                b_idx  = cnt_8x8 / 4;
                sb_idx = cnt_8x8 % 4;
                `FAIL_UNLESS_EQUAL(result_min_8x8, exp_mb_q[b_idx].min_8x8[sb_idx])
                `FAIL_UNLESS_EQUAL(result_mv_8x8,  exp_mb_q[b_idx].mv_8x8[sb_idx])
                cnt_8x8 <= cnt_8x8 + 1;
            end

            // Stream 4: 16x8 in order (0: Upper, 1: Left, 2: Right, 3: Lower)
            if (result_16x8_valid) begin
                b_idx = cnt_16x8 / 4;
                p_idx = cnt_16x8 % 4;
                `FAIL_UNLESS_EQUAL(result_min_16x8, exp_mb_q[b_idx].min_16x8[p_idx])
                `FAIL_UNLESS_EQUAL(result_mv_16x8,  exp_mb_q[b_idx].mv_16x8[p_idx])
                cnt_16x8 <= cnt_16x8 + 1;
            end

            // Stream 5: 16x16
            if (result_16x16_valid) begin
                b_idx = cnt_16x16;
                `FAIL_UNLESS_EQUAL(result_min_16x16, exp_mb_q[b_idx].min_16x16)
                `FAIL_UNLESS_EQUAL(result_mv_16x16,  exp_mb_q[b_idx].mv_16x16)
                cnt_16x16 <= cnt_16x16 + 1;
            end
        end
    end

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, fs_control_unit_test, "+mda", "+all");
        clk   = 0;
        forever #5 clk = ~clk;
    end

    task automatic drive_cycle(rb_row_t rb_d, cb_row_t cb_d);
        rb_valid = 1;
        rb = rb_d;
        cb_valid = 1;
        cb = cb_d;

        #0;
        @(posedge clk);
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

    task automatic get_sb(output rb_row_t rb_d[39], output cb_row_t cb_d[8],
                          input frame_t rf, input frame_t cf,
                          input int b_idx, input int sb_idx);
        int signed b_row, b_col;
        int signed sb_row_off, sb_col_off;
        int signed rf_row, rf_col;
        int signed cf_row, cf_col;

        // 16x16 Block raster coordinates (80 blocks per 1280-pixel row)
        b_row = b_idx / 80;
        b_col = b_idx % 80;

        // 8x8 Sub-block Morton order offset within the 16x16 block:
        // sb_idx = 0 (UL): row_off = 0, col_off = 0
        // sb_idx = 1 (UR): row_off = 0, col_off = 8
        // sb_idx = 2 (DL): row_off = 8, col_off = 0
        // sb_idx = 3 (DR): row_off = 8, col_off = 8
        sb_row_off = (sb_idx / 2) * 8;
        sb_col_off = (sb_idx % 2) * 8;

        // Top-left of the 39x39 reference window for this sub-block
        rf_row = (b_row - 1) * 16 + sb_row_off;
        rf_col = (b_col - 1) * 16 + sb_col_off;

        for (int row = 0; row < 39; row++) begin
            for (int col = 0; col < 39; col++) begin
                if ((rf_row + row) >= 0 && (rf_row + row) < FRAME_HEIGHT &&
                    (rf_col + col) >= 0 && (rf_col + col) < FRAME_WIDTH)
                    rb_d[row][col] = rf[rf_row + row][rf_col + col];
                else
                    rb_d[row][col] = $urandom;
            end
        end

        // Top-left of the 8x8 current sub-block
        cf_row = b_row * 16 + sb_row_off;
        cf_col = b_col * 16 + sb_col_off;

        for (int row = 0; row < 8; row++) begin
            for (int col = 0; col < 8; col++) begin
                if ((cf_row + row) >= 0 && (cf_row + row) < FRAME_HEIGHT &&
                    (cf_col + col) >= 0 && (cf_col + col) < FRAME_WIDTH)
                    cb_d[row][col] = cf[cf_row + row][cf_col + col];
                else
                    cb_d[row][col] = $urandom;
            end
        end
    endtask

    // Fetches all 4 sub-blocks in Morton order, computes expected results, and drives the DUT
    task automatic drive_block(const ref frame_t rf, const ref frame_t cf, input int b_idx);
        rb_row_t sb_rb[4][39];
        cb_row_t sb_cb[4][8];

        // 1. Extract all 4 sub-blocks in Morton order (0:UL, 1:UR, 2:DL, 3:DR)
        for (int sb_idx = 0; sb_idx < 4; sb_idx++) begin
            get_sb(sb_rb[sb_idx], sb_cb[sb_idx], rf, cf, b_idx, sb_idx);
        end

        // 2. Pre-calculate expected SADs/MVs and store in exp_mb_q[b_idx]
        calc_expected_results(sb_rb, sb_cb, exp_mb_q[b_idx]);
        // $display("%p", exp_mb_q);

        // 3. Drive the 4 sub-blocks into the DUT
        for (int sb_idx = 0; sb_idx < 4; sb_idx++) begin
            drive_subblock(sb_rb[sb_idx], sb_cb[sb_idx]);
        end
    endtask

    // ------------------------------------------------------------------
    // Golden Reference Model (Populates exp_mb_q[b_idx])
    // ------------------------------------------------------------------

    // Converts (dy, dx) search window offset [0..WINDOW_SIZE-1] into mv_t.
    // Adjust if your mv_t uses signed offsets (e.g., dy - 16) or {x, y} order.
    function automatic mv_t to_mv(int dy, int dx);
        mv_t mv;
        mv = {dy[($bits(mv_t)/2)-1:0], dx[($bits(mv_t)/2)-1:0]};
        return mv;
    endfunction

    function automatic void calc_expected_results(
        input  rb_row_t     sb_rb[4][39],
        input  cb_row_t     sb_cb[4][8],
        output mb_results_t exp
    );
        int sad_8x8_grid[4][WINDOW_SIZE][WINDOW_SIZE];
        int sad_16x8_cand[4];
        int sad_16x16_cand;

        // 1. Initialize all minimum SADs to maximum all-1s
        for (int sb = 0; sb < 4; sb++) begin
            exp.min_8x4[sb][0] = '1;
            exp.min_8x4[sb][1] = '1;
            exp.min_8x8[sb]    = '1;
            exp.min_16x8[sb]   = '1;
        end
        exp.min_16x16 = '1;

        // 2. Compute Left 4x8 (index 0), Right 4x8 (index 1), and 8x8 SADs per sub-block
        for (int sb = 0; sb < 4; sb++) begin
            for (int dy = 0; dy < WINDOW_SIZE; dy++) begin
                for (int dx = 0; dx < WINDOW_SIZE; dx++) begin
                    int sum_left_4x8  = 0;
                    int sum_right_4x8 = 0;
                    int sum_8x8       = 0;

                    // Upper 4x4 (rows 0..3) uses reference rows dy..dy+3
                    for (int r = 0; r < 4; r++) begin
                        for (int c = 0; c < 4; c++) begin
                            int d_ul = int'(sb_cb[sb][r][c])     - int'(sb_rb[sb][dy + r][dx + c]);
                            int d_ur = int'(sb_cb[sb][r][c+4])   - int'(sb_rb[sb][dy + r][dx + c + 4]);
                            sum_left_4x8  += (d_ul < 0) ? -d_ul : d_ul;
                            sum_right_4x8 += (d_ur < 0) ? -d_ur : d_ur;
                        end
                    end

                    // Lower 4x4 (rows 4..7) uses reference rows dy+4..dy+7
                    for (int r = 4; r < 8; r++) begin
                        for (int c = 0; c < 4; c++) begin
                            int d_dl = int'(sb_cb[sb][r][c])     - int'(sb_rb[sb][dy + r][dx + c]);
                            int d_dr = int'(sb_cb[sb][r][c+4])   - int'(sb_rb[sb][dy + r][dx + c + 4]);
                            sum_left_4x8  += (d_dl < 0) ? -d_dl : d_dl;
                            sum_right_4x8 += (d_dr < 0) ? -d_dr : d_dr;
                        end
                    end

                    sum_8x8 = sum_left_4x8 + sum_right_4x8;
                    sad_8x8_grid[sb][dy][dx] = sum_8x8;

                    // Left 4x8 (sad_8x4[0])
                    if (sum_left_4x8 < exp.min_8x4[sb][0]) begin
                        exp.min_8x4[sb][0] = sum_left_4x8[SAD_8X4_W-1:0];
                        exp.mv_8x4[sb][0]  = to_mv(dy, dx);
                    end

                    // Right 4x8 (sad_8x4[1])
                    if (sum_right_4x8 < exp.min_8x4[sb][1]) begin
                        exp.min_8x4[sb][1] = sum_right_4x8[SAD_8X4_W-1:0];
                        exp.mv_8x4[sb][1]  = to_mv(dy, dx);
                    end

                    // 8x8 Sub-block
                    if (sum_8x8 < exp.min_8x8[sb]) begin
                        exp.min_8x8[sb] = sum_8x8[SAD_8X8_W-1:0];
                        exp.mv_8x8[sb]  = to_mv(dy, dx);
                    end
                end
            end
        end

        // 3. Combine 8x8 grids for 16x8 and 16x16 across the search window
        for (int dy = 0; dy < WINDOW_SIZE; dy++) begin
            for (int dx = 0; dx < WINDOW_SIZE; dx++) begin
                sad_16x8_cand[0] = sad_8x8_grid[0][dy][dx] + sad_8x8_grid[1][dy][dx]; // Upper (UL + UR)
                sad_16x8_cand[1] = sad_8x8_grid[0][dy][dx] + sad_8x8_grid[2][dy][dx]; // Left  (UL + DL)
                sad_16x8_cand[2] = sad_8x8_grid[1][dy][dx] + sad_8x8_grid[3][dy][dx]; // Right (UR + DR)
                sad_16x8_cand[3] = sad_8x8_grid[2][dy][dx] + sad_8x8_grid[3][dy][dx]; // Lower (DL + DR)

                sad_16x16_cand   = sad_16x8_cand[0] + sad_16x8_cand[3];

                for (int p = 0; p < 4; p++) begin
                    if (sad_16x8_cand[p] < exp.min_16x8[p]) begin
                        exp.min_16x8[p] = sad_16x8_cand[p][SAD_16X8_W-1:0];
                        exp.mv_16x8[p]  = to_mv(dy, dx);
                    end
                end

                if (sad_16x16_cand < exp.min_16x16) begin
                    exp.min_16x16 = sad_16x16_cand[SAD_16X16_W-1:0];
                    exp.mv_16x16  = to_mv(dy, dx);
                end
            end
        end
    endfunction

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
        rb_valid = '0;
        cb_valid = '0;
        rb       = '0;
        for (int i = 0; i < 4; i++) cb[i] = '0;
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN

    `SVTEST(typical)
        frame_t rf;
        frame_t cf;
        int num_blocks_to_test = 4; // e.g., first 4 blocks of row 0 (or 3600 for full 1280x720 frame)

        std::randomize(rf);
        std::randomize(cf);

        clear = 1;
        #20 clear = 0;

        // Outer loop: left-to-right along rows (b_idx = 0, 1, 2, ...)
        // Inner loop (inside drive_block): sb_idx = 0 (UL), 1 (UR), 2 (DL), 3 (DR)
        for (int b_idx = 0; b_idx < num_blocks_to_test; b_idx++) begin
            $display("driving block: %d", b_idx);
            drive_block(rf, cf, b_idx);
        end
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
