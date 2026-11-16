// fs_computer_unit_test.sv
//
// svunit testbench for fs_computer (first-level SAD computer).
//
`include "svunit_defines.svh"

module fs_computer_unit_test;

    import me_pkg::*;
    import svunit_pkg::svunit_testcase;

    // ------------------------------------------------------------------
    // test wiring
    // ------------------------------------------------------------------

    localparam int NUM_RB_ROWS = WINDOW_SIZE + 7; // 39 rows (39 * 4 = 156 cycles per window)

    typedef logic [3:0][PEL_W-1:0]             pel_row_t;
    typedef logic [WINDOW_SIZE+6:0][PEL_W-1:0] rb_row_t;
    typedef pel_row_t                          cb_block_t[4];
    typedef rb_row_t                           rb_window_t[NUM_RB_ROWS];

    logic                                   clk;
    logic                                   clear;
    logic                                   stall;
    logic [3:0][PEL_W-1:0]                  cb[4];
    logic [WINDOW_SIZE+6:0][PEL_W-1:0]      rb;
    logic [RB_ROW_IDX_W-1:0]                rb_row_idx;
    logic [1:0]                             subcycle_idx;

    logic                                   sad_valid;
    logic [SW_IDX_W-1:0]                    sad_sw_idx;
    logic [SAD_4X4_W-1:0]                   sad_4x4[4][WINDOW_SIZE];
    logic [SAD_8X4_W-1:0]                   sad_4x8[2][WINDOW_SIZE];
    logic [SAD_8X4_W-1:0]                   sad_8x4[2][WINDOW_SIZE];
    logic [SAD_8X8_W-1:0]                   sad_8x8[WINDOW_SIZE];

    // Instantiate DUT with exact port mapping
    fs_computer dut (.*);

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, fs_computer_unit_test, "+mda", "+all");
        clk = '0;
        forever #5 clk = ~clk;
    end

    // Drive synchronous DUT inputs cleanly with exact clock alignment
    task automatic drive_subcycle(logic do_s, logic [RB_ROW_IDX_W-1:0] r_idx, logic [1:0] sub_idx,
                                  rb_window_t rb_win, cb_block_t cb_blk[4]);
        rb_row_idx   <= r_idx;
        subcycle_idx <= sub_idx;
        rb           <= rb_win[r_idx];
        clear        <= 1'b0;

        for (int q = 0; q < 4; q++) begin
            for (int r = 0; r < 4; r++) begin
                cb[q][r] <= cb_blk[q][3 - sub_idx][r];
            end
        end

        if (do_s) begin
            stall <= 1'b1;
            @(posedge clk);
        end

        stall <= 1'b0;
        @(posedge clk);
    endtask

    task automatic drive_row(logic do_s, int row_idx, rb_window_t rb_win, cb_block_t cb_blk[4]);
        for (int sub = 0; sub < 4; sub++) begin
            drive_subcycle(do_s, row_idx[RB_ROW_IDX_W-1:0], sub[1:0], rb_win, cb_blk);
        end
    endtask

    // Drive all 39 rows (39 * 4 = 156 subcycles) with no trailing flush
    task automatic drive_window(logic do_s, rb_window_t rb_win, cb_block_t cb_blk[4]);
        for (int r = 0; r < NUM_RB_ROWS; r++) begin
            drive_row(do_s, r, rb_win, cb_blk);
        end
    endtask

    // Compute reference 4x4, 4x8, 8x4, and 8x8 SADs for search window offset (sw_r, sw_c)
    function automatic void calc_expected_sads(
        input  rb_window_t rb_win,
        input  cb_block_t  cb_blk[4],
        input  int         sw_r,
        input  int         sw_c,
        output int         exp_4x4[4],
        output int         exp_4x8[2],
        output int         exp_8x4[2],
        output int         exp_8x8
    );
        exp_4x4 = '{default: 0};
        for (int r = 0; r < 4; r++) begin
            for (int c = 0; c < 4; c++) begin
                // Upper-Left (q=0): rows +0..3, cols +0..3
                int rb_ul = int'(rb_win[sw_r + r][sw_c + c]);
                int cb_ul = int'(cb_blk[0][r][c]);

                // Upper-Right (q=1): rows +0..3, cols +4..7
                int rb_ur = int'(rb_win[sw_r + r][sw_c + 4 + c]);
                int cb_ur = int'(cb_blk[1][r][c]);

                // Lower-Left (q=2): rows +4..7, cols +0..3
                int rb_ll = int'(rb_win[sw_r + 4 + r][sw_c + c]);
                int cb_ll = int'(cb_blk[2][r][c]);

                // Lower-Right (q=3): rows +4..7, cols +4..7
                int rb_lr = int'(rb_win[sw_r + 4 + r][sw_c + 4 + c]);
                int cb_lr = int'(cb_blk[3][r][c]);

                exp_4x4[0] += (rb_ul > cb_ul) ? (rb_ul - cb_ul) : (cb_ul - rb_ul);
                exp_4x4[1] += (rb_ur > cb_ur) ? (rb_ur - cb_ur) : (cb_ur - rb_ur);
                exp_4x4[2] += (rb_ll > cb_ll) ? (rb_ll - cb_ll) : (cb_ll - rb_ll);
                exp_4x4[3] += (rb_lr > cb_lr) ? (rb_lr - cb_lr) : (cb_lr - rb_lr);
            end
        end

        exp_4x8[0] = exp_4x4[0] + exp_4x4[1];
        exp_4x8[1] = exp_4x4[2] + exp_4x4[3];

        exp_8x4[0] = exp_4x4[0] + exp_4x4[2];
        exp_8x4[1] = exp_4x4[1] + exp_4x4[3];

        exp_8x8    = exp_8x4[0] + exp_8x4[1];
    endfunction

    // Monitor DUT's 4x and 8x outputs across all 32 search window rows (0..31)
    task automatic monitor_computer(rb_window_t rb_win, cb_block_t cb_blk[4]);
        int exp_4x4[4], exp_4x8[2], exp_8x4[2], exp_8x8;
        int valid_4x_count = 0;
        int valid_8x_count = 0;

        while (valid_4x_count < WINDOW_SIZE || valid_8x_count < WINDOW_SIZE) begin
            @(posedge clk);

            if (sad_valid) begin
                `FAIL_UNLESS_LOG(sad_sw_idx === SW_IDX_W'(valid_4x_count), $sformatf(
                    "4x: Expected sad_sw_idx=%0d, got %0d", valid_4x_count, sad_sw_idx
                ));

                for (int i = 0; i < WINDOW_SIZE; i++) begin
                    calc_expected_sads(rb_win, cb_blk, int'(sad_sw_idx), i, exp_4x4, exp_4x8, exp_8x4, exp_8x8);
                    for (int q = 0; q < 4; q++) begin
                        `FAIL_UNLESS_LOG(sad_4x4[q][i] === SAD_4X4_W'(exp_4x4[q]), $sformatf(
                            "sad_sw_idx=%0d col=%0d q=%0d act_4x4=0x%0h exp_4x4=0x%0h",
                            sad_sw_idx, i, q, sad_4x4[q][i], SAD_4X4_W'(exp_4x4[q])
                        ));
                    end
                end
                valid_4x_count++;
            end

            if (sad_valid) begin
                `FAIL_UNLESS_LOG(sad_sw_idx === SW_IDX_W'(valid_8x_count), $sformatf(
                    "8x: Expected sad_sw_idx=%0d, got %0d", valid_8x_count, sad_sw_idx
                ));

                for (int i = 0; i < WINDOW_SIZE; i++) begin
                    calc_expected_sads(rb_win, cb_blk, int'(sad_sw_idx), i, exp_4x4, exp_4x8, exp_8x4, exp_8x8);
                    for (int p = 0; p < 2; p++) begin
                        `FAIL_UNLESS_LOG(sad_4x8[p][i] === SAD_8X4_W'(exp_4x8[p]), $sformatf(
                            "sad_sw_idx=%0d col=%0d p=%0d act_4x8=0x%0h exp_4x8=0x%0h",
                            sad_sw_idx, i, p, sad_4x8[p][i], SAD_8X4_W'(exp_4x8[p])
                        ));
                        `FAIL_UNLESS_LOG(sad_8x4[p][i] === SAD_8X4_W'(exp_8x4[p]), $sformatf(
                            "sad_sw_idx=%0d col=%0d p=%0d act_8x4=0x%0h exp_8x4=0x%0h",
                            sad_sw_idx, i, p, sad_8x4[p][i], SAD_8X4_W'(exp_8x4[p])
                        ));
                    end
                    `FAIL_UNLESS_LOG(sad_8x8[i] === SAD_8X8_W'(exp_8x8), $sformatf(
                        "sad_sw_idx=%0d col=%0d act_8x8=0x%0h exp_8x8=0x%0h",
                        sad_sw_idx, i, sad_8x8[i], SAD_8X8_W'(exp_8x8)
                    ));
                end
                valid_8x_count++;
            end
        end
    endtask

    // ------------------------------------------------------------------
    // svunit scaffolding
    // ------------------------------------------------------------------

    string name = "fs_computer_ut";
    svunit_testcase svunit_ut;

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        @(posedge clk);
        clear        <= 1'b1;
        stall        <= '0;
        rb           <= '0;
        rb_row_idx   <= '0;
        subcycle_idx <= '0;
        for (int q = 0; q < 4; q++) cb[q] <= '0;
        @(posedge clk);
        clear        <= 1'b0;
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN

    `SVTEST(max_sad)
        rb_window_t rb_win;
        cb_block_t  cb_blk[4];

        // Max difference: RB = 0, CB = 255 (all pixels maxed)
        for (int r = 0; r < NUM_RB_ROWS; r++) begin
            for (int c = 0; c < WINDOW_SIZE+7; c++) begin
                rb_win[r][c] = 8'h00;
            end
        end
        for (int q = 0; q < 4; q++) begin
            for (int r = 0; r < 4; r++) begin
                for (int c = 0; c < 4; c++) begin
                    cb_blk[q][r][c] = 8'hFF;
                end
            end
        end

        fork
            drive_window(0, rb_win, cb_blk);
            monitor_computer(rb_win, cb_blk);
        join
    `SVTEST_END

    `SVTEST(min_sad)
        rb_window_t rb_win;
        cb_block_t  cb_blk[4];

        // Zero difference: RB and CB identical (all pixels set to 8'hA5)
        for (int r = 0; r < NUM_RB_ROWS; r++) begin
            for (int c = 0; c < WINDOW_SIZE+7; c++) begin
                rb_win[r][c] = 8'hA5;
            end
        end
        for (int q = 0; q < 4; q++) begin
            for (int r = 0; r < 4; r++) begin
                for (int c = 0; c < 4; c++) begin
                    cb_blk[q][r][c] = 8'hA5;
                end
            end
        end

        fork
            drive_window(0, rb_win, cb_blk);
            monitor_computer(rb_win, cb_blk);
        join
    `SVTEST_END

    `SVTEST(typical)
        rb_window_t rb_win1, rb_win2;
        cb_block_t  cb_blk1[4], cb_blk2[4];

        std::randomize(rb_win1);
        std::randomize(rb_win2);
        std::randomize(cb_blk1);
        std::randomize(cb_blk2);

        // Drive two distinct 39-row windows back-to-back with zero flush cycles
        fork
            begin
                drive_window(0, rb_win1, cb_blk1);
                drive_window(0, rb_win2, cb_blk2);
            end
            begin
                monitor_computer(rb_win1, cb_blk1);
                monitor_computer(rb_win2, cb_blk2);
            end
        join
    `SVTEST_END

    `SVTEST(typical_stall)
        rb_window_t rb_win1, rb_win2;
        cb_block_t  cb_blk1[4], cb_blk2[4];

        std::randomize(rb_win1);
        std::randomize(rb_win2);
        std::randomize(cb_blk1);
        std::randomize(cb_blk2);

        // Drive two distinct 39-row windows back-to-back with stalls and zero flush cycles
        fork
            begin
                drive_window(1, rb_win1, cb_blk1);
                drive_window(1, rb_win2, cb_blk2);
            end
            begin
                monitor_computer(rb_win1, cb_blk1);
                monitor_computer(rb_win2, cb_blk2);
            end
        join
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
