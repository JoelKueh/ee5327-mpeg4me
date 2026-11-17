// fs_control_unit_test.sv
//
// svunit testbench for fs_control with time-multiplexed 4-subcycle fs_computer,
// quarter-width fs_combiner, and fs_quarter_comparator at all levels.
//
`include "svunit_defines.svh"

module fs_control_unit_test;

    import me_pkg::*;
    import svunit_pkg::svunit_testcase;
    import fs_tb_common_pkg::*;

    localparam int NUM_RB_ROWS = WINDOW_SIZE + 7; // 39 rows

    typedef logic [WINDOW_SIZE+6:0][PEL_W-1:0] rb_row_t;
    typedef logic [3:0][PEL_W-1:0]             pel_row_t;
    typedef pel_row_t                          cb_block_t[4]; // [4 rows][4 cols]
    typedef logic [7:0][PEL_W-1:0]             cb_row_t;      // 8-pel row for frame extraction
    typedef logic [PEL_W-1:0]                  frame_t[FRAME_HEIGHT][FRAME_WIDTH];

    logic                                      clk;
    logic                                      clear;
    logic                                      stall;
    logic [WINDOW_SIZE+6:0][PEL_W-1:0]         rb;
    logic [3:0][PEL_W-1:0]                     cb[4];

    logic                                      result_4x4_valid[4];
    logic                                      result_4x8_valid[2];
    logic                                      result_8x4_valid[2];
    logic                                      result_8x8_valid;
    logic                                      result_16x8_valid;
    logic                                      result_16x16_valid;

    comb_sad_id_t                              result_16x8_id;
    logic [1:0]                                result_16x16_sb_idx;

    logic [SAD_4X4_W-1:0]                      result_min_4x4[4];
    logic [SAD_8X4_W-1:0]                      result_min_4x8[2];
    logic [SAD_8X4_W-1:0]                      result_min_8x4[2];
    logic [SAD_8X8_W-1:0]                      result_min_8x8;
    logic [SAD_16X8_W-1:0]                     result_min_16x8;
    logic [SAD_16X16_W-1:0]                    result_min_16x16;

    mv_t                                       result_mv_4x4[4];
    mv_t                                       result_mv_4x8[2];
    mv_t                                       result_mv_8x4[2];
    mv_t                                       result_mv_8x8;
    mv_t                                       result_mv_16x8;
    mv_t                                       result_mv_16x16;

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

        logic [SAD_16X8_W-1:0]  min_16x8[4];   // [0:SXL_0(sb0+1), 1:LXS_0(sb0+2), 2:LXS_1(sb1+3), 3:SXL_1(sb2+3)]
        mv_t                    mv_16x8[4];

        logic [SAD_16X16_W-1:0] min_16x16;
        mv_t                    mv_16x16;
    } mb_results_t;

    localparam comb_sad_id_t EXP_16X8_ID[4] = '{
        SAD_SXL_0,
        SAD_LXS_0,
        SAD_LXS_1,
        SAD_SXL_1
    };

    mb_results_t exp_mb_q[int];

    int cnt_4x4[4];
    int cnt_4x8[2];
    int cnt_8x4[2];
    int cnt_8x8;
    int cnt_16x8;
    int cnt_16x16;

    always @(posedge clk) begin
        int b_idx;
        int sb_idx;
        int p_idx;

        if (clear) begin
            for (int q = 0; q < 4; q++) cnt_4x4[q] <= 0;
            for (int h = 0; h < 2; h++) cnt_4x8[h] <= 0;
            for (int h = 0; h < 2; h++) cnt_8x4[h] <= 0;
            cnt_8x8   <= 0;
            cnt_16x8  <= 0;
            cnt_16x16 <= 0;
        end else begin
            // 4x4 Streams [0..3]: 1 result per subblock (4 per macroblock)
            for (int q = 0; q < 4; q++) begin
                if (result_4x4_valid[q]) begin
                    b_idx  = cnt_4x4[q] / 4;
                    sb_idx = cnt_4x4[q] % 4;

                    if (exp_mb_q.exists(b_idx)) begin
                        `FAIL_UNLESS_LOG(
                            result_min_4x4[q] === exp_mb_q[b_idx].min_4x4[sb_idx][q] &&
                            result_mv_4x4[q]  === exp_mb_q[b_idx].mv_4x4[sb_idx][q],
                            $sformatf("4x4[q=%0d] b_idx=%0d sb_idx=%0d | SAD: act=0x%0h exp=0x%0h | MV: act=(%0d,%0d) exp=(%0d,%0d)",
                                q, b_idx, sb_idx,
                                result_min_4x4[q], exp_mb_q[b_idx].min_4x4[sb_idx][q],
                                result_mv_4x4[q].row, result_mv_4x4[q].col,
                                exp_mb_q[b_idx].mv_4x4[sb_idx][q].row, exp_mb_q[b_idx].mv_4x4[sb_idx][q].col)
                        );
                        cnt_4x4[q] <= cnt_4x4[q] + 1;
                    end
                end
            end

            // 4x8 Streams [0..1]: 1 result per subblock (4 per macroblock)
            for (int h = 0; h < 2; h++) begin
                if (result_4x8_valid[h]) begin
                    b_idx  = cnt_4x8[h] / 4;
                    sb_idx = cnt_4x8[h] % 4;

                    if (exp_mb_q.exists(b_idx)) begin
                        `FAIL_UNLESS_LOG(
                            result_min_4x8[h] === exp_mb_q[b_idx].min_4x8[sb_idx][h] &&
                            result_mv_4x8[h]  === exp_mb_q[b_idx].mv_4x8[sb_idx][h],
                            $sformatf("4x8[h=%0d] b_idx=%0d sb_idx=%0d | SAD: act=0x%0h exp=0x%0h | MV: act=(%0d,%0d) exp=(%0d,%0d)",
                                h, b_idx, sb_idx,
                                result_min_4x8[h], exp_mb_q[b_idx].min_4x8[sb_idx][h],
                                result_mv_4x8[h].row, result_mv_4x8[h].col,
                                exp_mb_q[b_idx].mv_4x8[sb_idx][h].row, exp_mb_q[b_idx].mv_4x8[sb_idx][h].col)
                        );
                        cnt_4x8[h] <= cnt_4x8[h] + 1;
                    end
                end
            end

            // 8x4 Streams [0..1]: 1 result per subblock (4 per macroblock)
            for (int h = 0; h < 2; h++) begin
                if (result_8x4_valid[h]) begin
                    b_idx  = cnt_8x4[h] / 4;
                    sb_idx = cnt_8x4[h] % 4;

                    if (exp_mb_q.exists(b_idx)) begin
                        `FAIL_UNLESS_LOG(
                            result_min_8x4[h] === exp_mb_q[b_idx].min_8x4[sb_idx][h] &&
                            result_mv_8x4[h]  === exp_mb_q[b_idx].mv_8x4[sb_idx][h],
                            $sformatf("8x4[h=%0d] b_idx=%0d sb_idx=%0d | SAD: act=0x%0h exp=0x%0h | MV: act=(%0d,%0d) exp=(%0d,%0d)",
                                h, b_idx, sb_idx,
                                result_min_8x4[h], exp_mb_q[b_idx].min_8x4[sb_idx][h],
                                result_mv_8x4[h].row, result_mv_8x4[h].col,
                                exp_mb_q[b_idx].mv_8x4[sb_idx][h].row, exp_mb_q[b_idx].mv_8x4[sb_idx][h].col)
                        );
                        cnt_8x4[h] <= cnt_8x4[h] + 1;
                    end
                end
            end

            // 8x8 Stream: 1 result per subblock (4 per macroblock)
            if (result_8x8_valid) begin
                b_idx  = cnt_8x8 / 4;
                sb_idx = cnt_8x8 % 4;

                if (exp_mb_q.exists(b_idx)) begin
                    `FAIL_UNLESS_LOG(
                        result_min_8x8 === exp_mb_q[b_idx].min_8x8[sb_idx] &&
                        result_mv_8x8  === exp_mb_q[b_idx].mv_8x8[sb_idx],
                        $sformatf("8x8 b_idx=%0d sb_idx=%0d | SAD: act=0x%0h exp=0x%0h | MV: act=(%0d,%0d) exp=(%0d,%0d)",
                            b_idx, sb_idx,
                            result_min_8x8, exp_mb_q[b_idx].min_8x8[sb_idx],
                            result_mv_8x8.row, result_mv_8x8.col,
                            exp_mb_q[b_idx].mv_8x8[sb_idx].row, exp_mb_q[b_idx].mv_8x8[sb_idx].col)
                    );
                    cnt_8x8 <= cnt_8x8 + 1;
                end
            end

            // 16x8 Stream: 4 results per macroblock
            if (result_16x8_valid) begin
                b_idx = cnt_16x8 / 4;
                p_idx = cnt_16x8 % 4;

                if (exp_mb_q.exists(b_idx)) begin
                    `FAIL_UNLESS_LOG(
                        result_min_16x8 === exp_mb_q[b_idx].min_16x8[p_idx] &&
                        result_mv_16x8  === exp_mb_q[b_idx].mv_16x8[p_idx] &&
                        result_16x8_id  === EXP_16X8_ID[p_idx],
                        $sformatf("16x8 b_idx=%0d p_idx=%0d | ID: act=%s exp=%s | SAD: act=0x%0h exp=0x%0h | MV: act=(%0d,%0d) exp=(%0d,%0d)",
                            b_idx, p_idx, result_16x8_id.name(), EXP_16X8_ID[p_idx].name(),
                            result_min_16x8, exp_mb_q[b_idx].min_16x8[p_idx],
                            result_mv_16x8.row, result_mv_16x8.col,
                            exp_mb_q[b_idx].mv_16x8[p_idx].row, exp_mb_q[b_idx].mv_16x8[p_idx].col)
                    );
                    cnt_16x8 <= cnt_16x8 + 1;
                end
            end

            // 16x16 Stream: 1 result per macroblock
            if (result_16x16_valid) begin
                b_idx = cnt_16x16;

                if (exp_mb_q.exists(b_idx)) begin
                    `FAIL_UNLESS_LOG(
                        result_min_16x16    === exp_mb_q[b_idx].min_16x16 &&
                        result_mv_16x16     === exp_mb_q[b_idx].mv_16x16 &&
                        result_16x16_sb_idx === b_idx[1:0],
                        $sformatf("16x16 b_idx=%0d | sb_idx: act=%0d exp=%0d | SAD: act=0x%0h exp=0x%0h | MV: act=(%0d,%0d) exp=(%0d,%0d)",
                            b_idx, result_16x16_sb_idx, b_idx[1:0],
                            result_min_16x16, exp_mb_q[b_idx].min_16x16,
                            result_mv_16x16.row, result_mv_16x16.col,
                            exp_mb_q[b_idx].mv_16x16.row, exp_mb_q[b_idx].mv_16x16.col)
                    );
                    cnt_16x16 <= cnt_16x16 + 1;
                end
            end
        end
    end

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, fs_control_unit_test, "+mda", "+all");
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Drives one subcycle beat (with optional random stall cycles before it)
    task automatic drive_subcycle(rb_row_t rb_d, pel_row_t cb_d[4], int max_stall_cycles = 0);
        int num_stalls = (max_stall_cycles > 0) ? $urandom_range(0, max_stall_cycles) : 0;

        repeat (num_stalls) begin
            stall <= 1'b1;
            rb    <= 'x;
            for (int q = 0; q < 4; q++) cb[q] <= 'x;
            @(posedge clk);
        end

        stall <= 1'b0;
        rb    <= rb_d;
        for (int q = 0; q < 4; q++) cb[q] <= cb_d[q];
        @(posedge clk);
    endtask

    // Drives all 39 rows x 4 subcycles = 156 active beats for a single 8x8 subblock
    task automatic drive_subblock(rb_row_t rb_d[NUM_RB_ROWS], cb_row_t cb_d[8], int max_stall_cycles);
        cb_block_t cb_blk[4];

        // Partition 8x8 cb_d into 4 quadrants: 0=UL, 1=UR, 2=LL, 3=LR
        for (int r = 0; r < 4; r++) begin
            for (int c = 0; c < 4; c++) begin
                cb_blk[0][r][c] = cb_d[r][c];
                cb_blk[1][r][c] = cb_d[r][c + 4];
                cb_blk[2][r][c] = cb_d[r + 4][c];
                cb_blk[3][r][c] = cb_d[r + 4][c + 4];
            end
        end

        for (int r = 0; r < NUM_RB_ROWS; r++) begin
            for (int sub = 0; sub < 4; sub++) begin
                pel_row_t cb_sub[4];
                for (int q = 0; q < 4; q++) begin
                    cb_sub[q] = (r < 4) ? cb_blk[q][3 - sub] : 'x;
                end
                drive_subcycle(rb_d[r], cb_sub, max_stall_cycles);
            end
        end
    endtask

    // Drives one dummy subblock (sb_idx = 0) so fs_combiner reads RAM_A (sb 2)
    // and RAM_B (sb 3) of the final macroblock and outputs the 4th 16x8 partition.
    task automatic flush_pipeline(int max_stall_cycles = 0);
        rb_row_t dummy_rb[NUM_RB_ROWS];
        cb_row_t dummy_cb[8];

        for (int r = 0; r < NUM_RB_ROWS; r++) dummy_rb[r] = '0;
        for (int r = 0; r < 8;           r++) dummy_cb[r] = '0;

        drive_subblock(dummy_rb, dummy_cb, max_stall_cycles);

        // Wait for the final 16x8 comparator result to emerge
        stall <= 1'b0;
        repeat (16) @(posedge clk);
    endtask

    task automatic get_sb(output rb_row_t rb_d[NUM_RB_ROWS], output cb_row_t cb_d[8],
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

        for (int row = 0; row < NUM_RB_ROWS; row++) begin
            for (int col = 0; col < WINDOW_SIZE + 7; col++) begin
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
        rb_row_t sb_rb[4][NUM_RB_ROWS];
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

    // Reference model matching fs_quarter_comparator raster-order tie-breaking:
    // Selects global minimum SAD across the 32x32 grid; ties broken by smallest dy, then smallest dx.
    function automatic void reduce_quarter_grid(
        input  int  grid[WINDOW_SIZE][WINDOW_SIZE],
        output int  best_sad,
        output mv_t best_mv
    );
        best_sad = 'h7fff_ffff;
        best_mv  = to_mv(0, 0);

        for (int dy = 0; dy < WINDOW_SIZE; dy++) begin
            for (int dx = 0; dx < WINDOW_SIZE; dx++) begin
                if (grid[dy][dx] < best_sad) begin
                    best_sad = grid[dy][dx];
                    best_mv  = to_mv(dy, dx);
                end
            end
        end
    endfunction

    function automatic void calc_expected_results(
        input  rb_row_t     sb_rb[4][NUM_RB_ROWS],
        input  cb_row_t     sb_cb[4][8],
        output mb_results_t exp
    );
        int sad_4x4_grid[4][4][WINDOW_SIZE][WINDOW_SIZE];
        int sad_4x8_grid[4][2][WINDOW_SIZE][WINDOW_SIZE];
        int sad_8x4_grid[4][2][WINDOW_SIZE][WINDOW_SIZE];
        int sad_8x8_grid[4][WINDOW_SIZE][WINDOW_SIZE];
        int sad_16x8_grid[4][WINDOW_SIZE][WINDOW_SIZE];
        int sad_16x16_grid[WINDOW_SIZE][WINDOW_SIZE];
        int best_sad;
        mv_t best_mv;

        for (int sb = 0; sb < 4; sb++) begin
            for (int dy = 0; dy < WINDOW_SIZE; dy++) begin
                for (int dx = 0; dx < WINDOW_SIZE; dx++) begin
                    int sad_4x4[4];
                    sad_4x4 = '{default: 0};

                    for (int r = 0; r < 4; r++) begin
                        for (int c = 0; c < 4; c++) begin
                            int d_ul = int'(sb_cb[sb][r][c])         - int'(sb_rb[sb][dy + r][dx + c]);
                            int d_ur = int'(sb_cb[sb][r][c + 4])     - int'(sb_rb[sb][dy + r][dx + c + 4]);
                            int d_dl = int'(sb_cb[sb][r + 4][c])     - int'(sb_rb[sb][dy + r + 4][dx + c]);
                            int d_dr = int'(sb_cb[sb][r + 4][c + 4]) - int'(sb_rb[sb][dy + r + 4][dx + c + 4]);

                            sad_4x4[0] += (d_ul < 0) ? -d_ul : d_ul;
                            sad_4x4[1] += (d_ur < 0) ? -d_ur : d_ur;
                            sad_4x4[2] += (d_dl < 0) ? -d_dl : d_dl;
                            sad_4x4[3] += (d_dr < 0) ? -d_dr : d_dr;
                        end
                    end

                    for (int q = 0; q < 4; q++) begin
                        sad_4x4_grid[sb][q][dy][dx] = sad_4x4[q];
                    end

                    sad_4x8_grid[sb][0][dy][dx] = sad_4x4[0] + sad_4x4[1];
                    sad_4x8_grid[sb][1][dy][dx] = sad_4x4[2] + sad_4x4[3];

                    sad_8x4_grid[sb][0][dy][dx] = sad_4x4[0] + sad_4x4[2];
                    sad_8x4_grid[sb][1][dy][dx] = sad_4x4[1] + sad_4x4[3];

                    sad_8x8_grid[sb][dy][dx]    = sad_8x4_grid[sb][0][dy][dx] + sad_8x4_grid[sb][1][dy][dx];
                end
            end

            for (int q = 0; q < 4; q++) begin
                reduce_quarter_grid(sad_4x4_grid[sb][q], best_sad, best_mv);
                exp.min_4x4[sb][q] = best_sad[SAD_4X4_W-1:0];
                exp.mv_4x4[sb][q]  = best_mv;
            end

            for (int h = 0; h < 2; h++) begin
                reduce_quarter_grid(sad_4x8_grid[sb][h], best_sad, best_mv);
                exp.min_4x8[sb][h] = best_sad[SAD_8X4_W-1:0];
                exp.mv_4x8[sb][h]  = best_mv;

                reduce_quarter_grid(sad_8x4_grid[sb][h], best_sad, best_mv);
                exp.min_8x4[sb][h] = best_sad[SAD_8X4_W-1:0];
                exp.mv_8x4[sb][h]  = best_mv;
            end

            reduce_quarter_grid(sad_8x8_grid[sb], best_sad, best_mv);
            exp.min_8x8[sb] = best_sad[SAD_8X8_W-1:0];
            exp.mv_8x8[sb]  = best_mv;
        end

        for (int dy = 0; dy < WINDOW_SIZE; dy++) begin
            for (int dx = 0; dx < WINDOW_SIZE; dx++) begin
                sad_16x8_grid[0][dy][dx] = sad_8x8_grid[0][dy][dx] + sad_8x8_grid[1][dy][dx]; // SAD_SXL_0
                sad_16x8_grid[1][dy][dx] = sad_8x8_grid[0][dy][dx] + sad_8x8_grid[2][dy][dx]; // SAD_LXS_0
                sad_16x8_grid[2][dy][dx] = sad_8x8_grid[1][dy][dx] + sad_8x8_grid[3][dy][dx]; // SAD_LXS_1
                sad_16x8_grid[3][dy][dx] = sad_8x8_grid[2][dy][dx] + sad_8x8_grid[3][dy][dx]; // SAD_SXL_1

                sad_16x16_grid[dy][dx]   = sad_16x8_grid[0][dy][dx] + sad_16x8_grid[3][dy][dx];
            end
        end

        for (int p = 0; p < 4; p++) begin
            reduce_quarter_grid(sad_16x8_grid[p], best_sad, best_mv);
            exp.min_16x8[p] = best_sad[SAD_16X8_W-1:0];
            exp.mv_16x8[p]  = best_mv;
        end

        reduce_quarter_grid(sad_16x16_grid, best_sad, best_mv);
        exp.min_16x16 = best_sad[SAD_16X16_W-1:0];
        exp.mv_16x16  = best_mv;
    endfunction

    task automatic run_random_iteration(int iter_id, int num_blocks_to_test = 4, int max_stall_cycles = 0);
        frame_t rf;
        frame_t cf;

        $display("[TEST] === Starting Iteration %0d (%0d blocks, max_stall=%0d) ===",
                 iter_id, num_blocks_to_test, max_stall_cycles);

        exp_mb_q.delete();

        if (!std::randomize(rf)) `FAIL_IF(1)
        if (!std::randomize(cf)) `FAIL_IF(1)

        @(posedge clk);
        clear <= 1'b1;
        stall <= 1'b1;
        repeat (4) @(posedge clk);
        clear <= 1'b0;

        for (int b_idx = 0; b_idx < num_blocks_to_test; b_idx++) begin
            drive_block(rf, cf, b_idx, max_stall_cycles);
        end

        flush_pipeline(max_stall_cycles);

        for (int q = 0; q < 4; q++) begin
            `FAIL_UNLESS_LOG(cnt_4x4[q] == num_blocks_to_test * 4,
                $sformatf("cnt_4x4[%0d] mismatch: act=%0d exp=%0d", q, cnt_4x4[q], num_blocks_to_test * 4));
        end
        for (int h = 0; h < 2; h++) begin
            `FAIL_UNLESS_LOG(cnt_4x8[h] == num_blocks_to_test * 4,
                $sformatf("cnt_4x8[%0d] mismatch: act=%0d exp=%0d", h, cnt_4x8[h], num_blocks_to_test * 4));
            `FAIL_UNLESS_LOG(cnt_8x4[h] == num_blocks_to_test * 4,
                $sformatf("cnt_8x4[%0d] mismatch: act=%0d exp=%0d", h, cnt_8x4[h], num_blocks_to_test * 4));
        end
        `FAIL_UNLESS_LOG(cnt_8x8 == num_blocks_to_test * 4,
            $sformatf("cnt_8x8 mismatch: act=%0d exp=%0d", cnt_8x8, num_blocks_to_test * 4));
        `FAIL_UNLESS_LOG(cnt_16x8 == num_blocks_to_test * 4,
            $sformatf("cnt_16x8 mismatch: act=%0d exp=%0d", cnt_16x8, num_blocks_to_test * 4));
        `FAIL_UNLESS_LOG(cnt_16x16 == num_blocks_to_test,
            $sformatf("cnt_16x16 mismatch: act=%0d exp=%0d", cnt_16x16, num_blocks_to_test));
    endtask

    string name = "fs_control_ut";
    svunit_testcase svunit_ut;

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        clear = '0;
        stall = '0;
        rb    = '0;
        for (int q = 0; q < 4; q++) cb[q] = '0;
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
