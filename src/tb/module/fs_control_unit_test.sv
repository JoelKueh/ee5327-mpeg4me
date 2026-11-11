// fs_control_unit_test.sv
//
// svunit testbench for fs_control with corrected stream index mapping.
//
`include "svunit_defines.svh"

module fs_control_unit_test;

    import me_pkg::*;
    import svunit_pkg::svunit_testcase;
    import fs_tb_common_pkg::*;

    typedef logic [WINDOW_SIZE+6:0][PEL_W-1:0] rb_row_t;
    typedef logic [7:0][PEL_W-1:0] cb_row_t;
    typedef logic [PEL_W-1:0] frame_t[FRAME_HEIGHT][FRAME_WIDTH];

    logic clk;
    logic clear;
    logic stall;
    logic [WINDOW_SIZE+6:0][PEL_W-1:0] rb;
    logic [7:0][PEL_W-1:0] cb;
    logic upper_half;

    logic result_4x4_valid[2];
    logic result_4x8_valid;
    logic result_8x4_valid[2];
    logic result_8x8_valid;
    logic result_16x8_valid;
    logic result_16x16_valid;
    logic [SAD_4X4_W-1:0] result_min_4x4[2];
    logic [SAD_8X4_W-1:0] result_min_4x8;
    logic [SAD_8X4_W-1:0] result_min_8x4[2];
    logic [SAD_8X8_W-1:0] result_min_8x8;
    logic [SAD_16X8_W-1:0] result_min_16x8;
    logic [SAD_16X16_W-1:0] result_min_16x16;
    mv_t result_mv_4x4[2];
    mv_t result_mv_4x8;
    mv_t result_mv_8x4[2];
    mv_t result_mv_8x8;
    mv_t result_mv_16x8;
    mv_t result_mv_16x16;

    fs_control dut (.*);

    typedef struct {
        logic [SAD_4X4_W-1:0]   min_4x4[4][4]; // [sb_idx][0:UL, 1:UR, 2:DL, 3:DR]
        mv_t                    mv_4x4[4][4];

        logic [SAD_8X4_W-1:0]   min_4x8[4][2]; // [sb_idx][0: upper, 1: lower]
        mv_t                    mv_4x8[4][2];

        logic [SAD_8X4_W-1:0]   min_8x4[4][2]; // [sb_idx][0: left, 1: right]
        mv_t                    mv_8x4[4][2];

        logic [SAD_8X8_W-1:0]   min_8x8[4];    // [sb_idx] Morton order
        mv_t                    mv_8x8[4];

        logic [SAD_16X8_W-1:0]  min_16x8[4];
        mv_t                    mv_16x8[4];

        logic [SAD_16X16_W-1:0] min_16x16;
        mv_t                    mv_16x16;
    } mb_results_t;

    mb_results_t exp_mb_q[int];

    int cnt_4x4[2];
    int cnt_4x8;
    int cnt_8x4[2];
    int cnt_8x8;
    int cnt_16x8;
    int cnt_16x16;

    always @(posedge clk) begin
        int b_idx;
        int sb_idx;
        int quad_idx;
        int p_idx;

        if (clear) begin
            for (int i = 0; i < 2; i++) cnt_4x4[i] <= 0;
            cnt_4x8 <= 0;
            for (int i = 0; i < 2; i++) cnt_8x4[i] <= 0;
            cnt_8x8   <= 0;
            cnt_16x8  <= 0;
            cnt_16x16 <= 0;
        end else begin
            // 4x4 Streams: [0] = left (UL/DL), [1] = right (UR/DR)
            for (int q = 0; q < 2; q++) begin
                if (result_4x4_valid[q]) begin
                    int pass;
                    b_idx    = cnt_4x4[q] / 8;        // 4 sub-blocks * 2 passes (upper/lower) = 8 results per macroblock
                    sb_idx   = (cnt_4x4[q] / 2) % 4;
                    pass     = (cnt_4x4[q] % 2);      // 0 = upper pass, 1 = lower pass
                    quad_idx = q + (pass * 2);        // Pass 0: q=0->UL(0), q=1->UR(1). Pass 1: q=0->DL(2), q=1->DR(3).

                    if (exp_mb_q.exists(b_idx)) begin
                        if (result_min_4x4[q] !== exp_mb_q[b_idx].min_4x4[sb_idx][quad_idx] ||
                            result_mv_4x4[q]  !== exp_mb_q[b_idx].mv_4x4[sb_idx][quad_idx]) begin
                            $display("[DEBUG FAIL @ %0t] 4x4 Mismatch [q=0x%0h, pass=0x%0h]: b_idx=0x%0h, sb_idx=0x%0h, quad=0x%0h | Act Min=0x%0h, Exp Min=0x%0h | Act MV=(0x%0h,0x%0h), Exp MV=(0x%0h,0x%0h)",
                                $time, q, pass, b_idx, sb_idx, quad_idx,
                                result_min_4x4[q], exp_mb_q[b_idx].min_4x4[sb_idx][quad_idx],
                                result_mv_4x4[q].row, result_mv_4x4[q].col,
                                exp_mb_q[b_idx].mv_4x4[sb_idx][quad_idx].row, exp_mb_q[b_idx].mv_4x4[sb_idx][quad_idx].col);
                        end

                        `FAIL_UNLESS_EQUAL(result_min_4x4[q], exp_mb_q[b_idx].min_4x4[sb_idx][quad_idx])
                        `FAIL_UNLESS_EQUAL(result_mv_4x4[q],  exp_mb_q[b_idx].mv_4x4[sb_idx][quad_idx])
                        cnt_4x4[q] <= cnt_4x4[q] + 1;
                    end
                end
            end

            // 4x8 Stream: 4 sub-blocks * 2 passes (upper/lower) = 8 results per macroblock
            if (result_4x8_valid) begin
                int pass;
                b_idx  = cnt_4x8 / 8;
                sb_idx = (cnt_4x8 / 2) % 4;
                pass   = cnt_4x8 % 2; // 0 = upper pass, 1 = lower pass

                if (exp_mb_q.exists(b_idx)) begin
                    if (result_min_4x8 !== exp_mb_q[b_idx].min_4x8[sb_idx][pass] ||
                        result_mv_4x8  !== exp_mb_q[b_idx].mv_4x8[sb_idx][pass]) begin
                        $display("[DEBUG FAIL @ %0t] 4x8 Mismatch: b_idx=0x%0h, sb_idx=0x%0h, pass=0x%0h | Act Min=0x%0h, Exp Min=0x%0h | Act MV=(0x%0h,0x%0h), Exp MV=(0x%0h,0x%0h)",
                            $time, b_idx, sb_idx, pass,
                            result_min_4x8, exp_mb_q[b_idx].min_4x8[sb_idx][pass],
                            result_mv_4x8.row, result_mv_4x8.col,
                            exp_mb_q[b_idx].mv_4x8[sb_idx][pass].row, exp_mb_q[b_idx].mv_4x8[sb_idx][pass].col);
                    end

                    `FAIL_UNLESS_EQUAL(result_min_4x8, exp_mb_q[b_idx].min_4x8[sb_idx][pass])
                    `FAIL_UNLESS_EQUAL(result_mv_4x8,  exp_mb_q[b_idx].mv_4x8[sb_idx][pass])
                    cnt_4x8 <= cnt_4x8 + 1;
                end
            end

            // 8x4 Streams [0..1]
            for (int h = 0; h < 2; h++) begin
                if (result_8x4_valid[h]) begin
                    b_idx  = cnt_8x4[h] / 4;
                    sb_idx = cnt_8x4[h] % 4;

                    if (exp_mb_q.exists(b_idx)) begin
                        `FAIL_UNLESS_EQUAL(result_min_8x4[h], exp_mb_q[b_idx].min_8x4[sb_idx][h])
                        `FAIL_UNLESS_EQUAL(result_mv_8x4[h],  exp_mb_q[b_idx].mv_8x4[sb_idx][h])
                        cnt_8x4[h] <= cnt_8x4[h] + 1;
                    end
                end
            end

            // 8x8 Stream
            if (result_8x8_valid) begin
                b_idx  = cnt_8x8 / 4;
                sb_idx = cnt_8x8 % 4;

                if (exp_mb_q.exists(b_idx)) begin
                    `FAIL_UNLESS_EQUAL(result_min_8x8, exp_mb_q[b_idx].min_8x8[sb_idx])
                    `FAIL_UNLESS_EQUAL(result_mv_8x8,  exp_mb_q[b_idx].mv_8x8[sb_idx])
                    cnt_8x8 <= cnt_8x8 + 1;
                end
            end

            // 16x8 Stream
            if (result_16x8_valid) begin
                b_idx = cnt_16x8 / 4;
                p_idx = cnt_16x8 % 4;

                `FAIL_UNLESS_EQUAL(result_min_16x8, exp_mb_q[b_idx].min_16x8[p_idx])
                `FAIL_UNLESS_EQUAL(result_mv_16x8,  exp_mb_q[b_idx].mv_16x8[p_idx])
                cnt_16x8 <= cnt_16x8 + 1;
            end

            // 16x16 Stream
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

    // Drives one valid row (with optional random stall cycles before it)
    task automatic drive_cycle(rb_row_t rb_d, cb_row_t cb_d, int max_stall_cycles = 0);
        int num_stalls = (max_stall_cycles > 0) ? $urandom_range(0, max_stall_cycles) : 0;

        // Optional stall cycles: hold stall = 1 and drive X on data to prove DUT ignores it
        repeat (num_stalls) begin
            stall = 1'b1;
            rb    = 'x;
            cb    = 'x;
            @(posedge clk);
            #0;
        end

        // Active cycle: stall = 0
        stall = 1'b0;
        rb    = rb_d;
        cb    = cb_d;
        @(posedge clk);
        #0;
    endtask

    task automatic drive_subblock(rb_row_t rb_d[39], cb_row_t cb_d[8], int max_stall_cycles);
        // Pass 1: Upper half (upper_half = 1)
        // Streams rb_d[0..34] and cb_d[0..3]
        upper_half = 1'b1;
        for (int i = 0; i < 35; i++) begin
            if (i < 4) begin
                drive_cycle(rb_d[i], cb_d[i], max_stall_cycles);
            end else begin
                drive_cycle(rb_d[i], 'x, max_stall_cycles);
            end
        end

        // Pass 2: Lower half (upper_half = 0)
        // Streams rb_d[4..38] and cb_d[4..7]
        upper_half = 1'b0;
        for (int i = 0; i < 35; i++) begin
            if (i < 4) begin
                drive_cycle(rb_d[i + 4], cb_d[i + 4], max_stall_cycles);
            end else begin
                drive_cycle(rb_d[i + 4], 'x, max_stall_cycles);
            end
        end
    endtask

    // Drains the 3 pipeline stages of fs_computer (while rb_row_idx_q is 0..2,
    // so no new valid rows enter), then holds stall = 1 while fs_combiner and
    // the comparators finish draining.
    // Drives one dummy subblock (sb_idx = 0) so fs_combiner reads RAM_A (sb 2)
    // and RAM_B (sb 3) of the final macroblock and outputs the 4th 16x8 partition.
    task automatic flush_pipeline(int max_stall_cycles = 0);
        rb_row_t dummy_rb[39];
        cb_row_t dummy_cb[8];

        for (int r = 0; r < 39; r++) dummy_rb[r] = '0;
        for (int r = 0; r < 8;  r++) dummy_cb[r] = '0;

        drive_subblock(dummy_rb, dummy_cb, max_stall_cycles);

        // Wait for the final 16x8 comparator result to emerge
        stall = 1'b0;
        repeat (10) begin
            @(posedge clk);
            #0;
        end
    endtask

    task automatic get_sb(output rb_row_t rb_d[39], output cb_row_t cb_d[8],
                          input frame_t rf, input frame_t cf,
                          input int b_idx, input int sb_idx);
        int signed b_row, b_col;
        int signed sb_row_off, sb_col_off;
        int signed rf_row, rf_col;
        int signed cf_row, cf_col;

        b_row = b_idx / 80;
        b_col = b_idx % 80;

        sb_row_off = (sb_idx / 2) * 8;
        sb_col_off = (sb_idx % 2) * 8;

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

    task automatic drive_block(const ref frame_t rf, const ref frame_t cf, input int b_idx,
            int max_stall_cycles);
        rb_row_t sb_rb[4][39];
        cb_row_t sb_cb[4][8];

        for (int sb_idx = 0; sb_idx < 4; sb_idx++) begin
            get_sb(sb_rb[sb_idx], sb_cb[sb_idx], rf, cf, b_idx, sb_idx);
        end

        calc_expected_results(sb_rb, sb_cb, exp_mb_q[b_idx]);

        for (int sb_idx = 0; sb_idx < 4; sb_idx++) begin
            drive_subblock(sb_rb[sb_idx], sb_cb[sb_idx], max_stall_cycles);
        end
    endtask

    function automatic mv_t to_mv(int dy, int dx);
        mv_t mv;
        mv.row = dy[SW_IDX_W-1:0];
        mv.col = dx[SW_IDX_W-1:0];
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

        for (int sb = 0; sb < 4; sb++) begin
            for (int q = 0; q < 4; q++) exp.min_4x4[sb][q] = '1;
            for (int h = 0; h < 2; h++) begin
                exp.min_4x8[sb][h] = '1;
                exp.min_8x4[sb][h] = '1;
            end
            exp.min_8x8[sb]  = '1;
            exp.min_16x8[sb] = '1;
        end
        exp.min_16x16 = '1;

        for (int sb = 0; sb < 4; sb++) begin
            for (int dy = 0; dy < WINDOW_SIZE; dy++) begin
                for (int dx = 0; dx < WINDOW_SIZE; dx++) begin
                    int sad_4x4[4];
                    int sum_4x8[2];
                    int sum_8x4[2];
                    int sum_8x8;

                    sad_4x4 = '{default: 0};

                    for (int r = 0; r < 4; r++) begin
                        for (int c = 0; c < 4; c++) begin
                            int d_ul = int'(sb_cb[sb][r][c])   - int'(sb_rb[sb][dy + r][dx + c]);
                            int d_ur = int'(sb_cb[sb][r][c+4]) - int'(sb_rb[sb][dy + r][dx + c + 4]);
                            sad_4x4[0] += (d_ul < 0) ? -d_ul : d_ul;
                            sad_4x4[1] += (d_ur < 0) ? -d_ur : d_ur;
                        end
                    end

                    for (int r = 4; r < 8; r++) begin
                        for (int c = 0; c < 4; c++) begin
                            int d_dl = int'(sb_cb[sb][r][c])   - int'(sb_rb[sb][dy + r][dx + c]);
                            int d_dr = int'(sb_cb[sb][r][c+4]) - int'(sb_rb[sb][dy + r][dx + c + 4]);
                            sad_4x4[2] += (d_dl < 0) ? -d_dl : d_dl;
                            sad_4x4[3] += (d_dr < 0) ? -d_dr : d_dr;
                        end
                    end

                    sum_4x8[0] = sad_4x4[0] + sad_4x4[1];
                    sum_4x8[1] = sad_4x4[2] + sad_4x4[3];

                    sum_8x4[0] = sad_4x4[0] + sad_4x4[2];
                    sum_8x4[1] = sad_4x4[1] + sad_4x4[3];

                    sum_8x8 = sum_8x4[0] + sum_8x4[1];
                    sad_8x8_grid[sb][dy][dx] = sum_8x8;

                    // Hardware prefers earlier dx within the same dy (<),
                    // but swaps on equal SAD for a later dy (dy > current mv.row).
                    for (int q = 0; q < 4; q++) begin
                        if (sad_4x4[q] < exp.min_4x4[sb][q] ||
                            (sad_4x4[q] == exp.min_4x4[sb][q] && dy > exp.mv_4x4[sb][q].row)) begin
                            exp.min_4x4[sb][q] = sad_4x4[q][SAD_4X4_W-1:0];
                            exp.mv_4x4[sb][q]  = to_mv(dy, dx);
                        end
                    end

                    for (int h = 0; h < 2; h++) begin
                        if (sum_4x8[h] < exp.min_4x8[sb][h] ||
                            (sum_4x8[h] == exp.min_4x8[sb][h] && dy > exp.mv_4x8[sb][h].row)) begin
                            exp.min_4x8[sb][h] = sum_4x8[h][SAD_8X4_W-1:0];
                            exp.mv_4x8[sb][h]  = to_mv(dy, dx);
                        end
                    end

                    for (int h = 0; h < 2; h++) begin
                        if (sum_8x4[h] < exp.min_8x4[sb][h] ||
                            (sum_8x4[h] == exp.min_8x4[sb][h] && dy > exp.mv_8x4[sb][h].row)) begin
                            exp.min_8x4[sb][h] = sum_8x4[h][SAD_8X4_W-1:0];
                            exp.mv_8x4[sb][h]  = to_mv(dy, dx);
                        end
                    end

                    if (sum_8x8 < exp.min_8x8[sb] ||
                        (sum_8x8 == exp.min_8x8[sb] && dy > exp.mv_8x8[sb].row)) begin
                        exp.min_8x8[sb] = sum_8x8[SAD_8X8_W-1:0];
                        exp.mv_8x8[sb]  = to_mv(dy, dx);
                    end
                end
            end
        end

        for (int dy = 0; dy < WINDOW_SIZE; dy++) begin
            for (int dx = 0; dx < WINDOW_SIZE; dx++) begin
                sad_16x8_cand[0] = sad_8x8_grid[0][dy][dx] + sad_8x8_grid[1][dy][dx];
                sad_16x8_cand[1] = sad_8x8_grid[0][dy][dx] + sad_8x8_grid[2][dy][dx];
                sad_16x8_cand[2] = sad_8x8_grid[1][dy][dx] + sad_8x8_grid[3][dy][dx];
                sad_16x8_cand[3] = sad_8x8_grid[2][dy][dx] + sad_8x8_grid[3][dy][dx];

                sad_16x16_cand   = sad_16x8_cand[0] + sad_16x8_cand[3];

                for (int p = 0; p < 4; p++) begin
                    if (sad_16x8_cand[p] < exp.min_16x8[p] ||
                        (sad_16x8_cand[p] == exp.min_16x8[p] && dy > exp.mv_16x8[p].row)) begin
                        exp.min_16x8[p] = sad_16x8_cand[p][SAD_16X8_W-1:0];
                        exp.mv_16x8[p]  = to_mv(dy, dx);
                    end
                end

                if (sad_16x16_cand < exp.min_16x16 ||
                    (sad_16x16_cand == exp.min_16x16 && dy > exp.mv_16x16.row)) begin
                    exp.min_16x16 = sad_16x16_cand[SAD_16X16_W-1:0];
                    exp.mv_16x16  = to_mv(dy, dx);
                end
            end
        end
    endfunction

    task automatic run_random_iteration(int iter_id, int num_blocks_to_test = 4, int max_stall_cycles);
        frame_t rf;
        frame_t cf;

        $display("[TEST] === Starting Iteration %0d (%0d blocks) ===", iter_id, num_blocks_to_test);

        exp_mb_q.delete();

        if (!std::randomize(rf)) `FAIL_IF(1)
        if (!std::randomize(cf)) `FAIL_IF(1)

        @(posedge clk);
        clear      = 1'b1;
        stall      = 1'b1;
        upper_half = 1'b0;
        repeat (4) @(posedge clk);
        #0;
        clear      = 1'b0;

        for (int b_idx = 0; b_idx < num_blocks_to_test; b_idx++) begin
            //$display("[TEST] Iter %0d: Driving macroblock index %0d", iter_id, b_idx);
            drive_block(rf, cf, b_idx, max_stall_cycles);
        end

        flush_pipeline();

        `FAIL_UNLESS_EQUAL(cnt_4x4[0], num_blocks_to_test * 8)
        `FAIL_UNLESS_EQUAL(cnt_4x4[1], num_blocks_to_test * 8)
        `FAIL_UNLESS_EQUAL(cnt_4x8,    num_blocks_to_test * 8)
        `FAIL_UNLESS_EQUAL(cnt_8x4[0], num_blocks_to_test * 4)
        `FAIL_UNLESS_EQUAL(cnt_8x4[1], num_blocks_to_test * 4)
        `FAIL_UNLESS_EQUAL(cnt_8x8,    num_blocks_to_test * 4)
        `FAIL_UNLESS_EQUAL(cnt_16x8,   num_blocks_to_test * 4)
        `FAIL_UNLESS_EQUAL(cnt_16x16,  num_blocks_to_test)
    endtask

    string name = "fs_control_ut";
    svunit_testcase svunit_ut;

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        stall      = '0;
        rb         = '0;
        cb         = '0;
        upper_half = '0;
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN

    `SVTEST(typical_stall)
        for (int i = 0; i < 2; i++) begin
            run_random_iteration(i, $urandom_range(16, 32), 10);
        end
    `SVTEST_END

    `SVTEST(typical)
        for (int i = 0; i < 2; i++) begin
            run_random_iteration(i, $urandom_range(16, 32), 0);
        end
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
