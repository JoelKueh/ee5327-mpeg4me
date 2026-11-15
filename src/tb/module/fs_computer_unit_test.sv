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

    localparam int NUM_RB_ROWS = 32;

    typedef logic [3:0][PEL_W-1:0] pel_row_t;
    typedef pel_row_t             cb_block_t[4];
    typedef pel_row_t             rb_window_t[NUM_RB_ROWS];

    logic                                   clk;
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

    // Pipeline tracking signals registered in NBA alongside dut outputs
    logic                                   sad_valid_d, sad_valid_q;
    logic [SW_IDX_W-1:0]                    sad_idx_d,   sad_idx_q;

    // Instantiate DUT with exact port mapping
    fs_computer dut (.*);

    initial begin
        clk = '0;
        forever #5 clk = ~clk;
    end

    always_ff @(posedge clk) begin
        sad_valid_q <= sad_valid_d && !stall;
        if (!stall) begin
            sad_idx_q <= sad_idx_d;
        end
    end

    // Drive all synchronous DUT inputs with '<=' matching testbench standards
    task automatic drive_subcycle(logic do_s, logic [RB_ROW_IDX_W-1:0] r_idx, logic [1:0] sub_idx,
                                   rb_window_t rb_win, cb_block_t cb_blk[4]);
        rb_row_idx   <= r_idx;
        subcycle_idx <= sub_idx;
        rb           <= rb_win[r_idx];

        for (int q = 0; q < 4; q++) begin
            for (int r = 0; r < 4; r++) begin
                cb[q][r] <= cb_blk[q][3 - sub_idx];
            end
        end

        sad_valid_d <= (sub_idx == 2'd3) && (r_idx >= 3);
        sad_idx_d   <= r_idx >= 3 ? (r_idx - 3) : 0;

        if (do_s) begin
            stall <= 1'b1;
            @(posedge clk);
        end

        stall <= 1'b0;
        @(posedge clk);
    endtask

    task automatic drive_row(logic do_s, int row_idx, rb_window_t rb_win, cb_block_t cb_blk[4]);
        for (int sub = 0; sub < 4; sub++) begin
            drive_subcycle(do_s, row_idx, sub[1:0], rb_win, cb_blk);
        end
    endtask

    task automatic drive_window(logic do_s, rb_window_t rb_win, cb_block_t cb_blk[4]);
        for (int r = 0; r < NUM_RB_ROWS; r++) begin
            drive_row(do_s, r, rb_win, cb_blk);
        end
        // Flush final rows
        for (int p = 0; p < 4; p++) begin
            drive_subcycle(do_s, NUM_RB_ROWS-1, p[1:0], rb_win, cb_blk);
        end
    endtask

    // Monitor and verify active results against golden calculation
    task automatic monitor_computer(rb_window_t rb_win, cb_block_t cb_blk[4]);
        int exp_4x4_ul;

        @(posedge clk);
        if (sad_valid_q) begin
            exp_4x4_ul = 0;
            for (int r = 0; r < 4; r++) begin
                for (int c = 0; c < 4; c++) begin
                    int rb_pel = int'(rb_win[sad_idx_q + r][c]);
                    int cb_pel = int'(cb_blk[0][r][c]);
                    exp_4x4_ul += (rb_pel > cb_pel) ? (rb_pel - cb_pel) : (cb_pel - rb_pel);
                end
            end

            `FAIL_UNLESS_LOG(sad_4x4[0][0] === SAD_4X4_W'(exp_4x4_ul), $sformatf(
                "sad_sw_idx=%0d act_4x4_ul=0x%0h exp_4x4_ul=0x%0h", sad_sw_idx, sad_4x4[0][0], SAD_4X4_W'(exp_4x4_ul)
            ));
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
        stall        = '0;
        rb           = '0;
        rb_row_idx   = '0;
        subcycle_idx = '0;
        sad_valid_d  = '0;
        sad_valid_q  = '0;
        sad_idx_d    = 0;
        sad_idx_q    = 0;
        for (int q = 0; q < 4; q++) cb[q] = '0;
        @(posedge clk);
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN

    `SVTEST(back_to_back_windows)
        rb_window_t rb_win;
        cb_block_t  cb_blk[4];

        std::randomize(rb_win);
        for (int q = 0; q < 4; q++) std::randomize(cb_blk[q]);

        fork
            forever monitor_computer(rb_win, cb_blk);
        join_none

        // Drive multiple 32-row search windows back-to-back
        drive_window(0, rb_win, cb_blk);
        drive_window(0, rb_win, cb_blk);

        @(posedge clk);
        disable fork;
    `SVTEST_END

    `SVTEST(windows_with_stalls)
        rb_window_t rb_win;
        cb_block_t  cb_blk[4];

        std::randomize(rb_win);
        for (int q = 0; q < 4; q++) std::randomize(cb_blk[q]);

        fork
            forever monitor_computer(rb_win, cb_blk);
        join_none

        drive_window(1, rb_win, cb_blk);

        @(posedge clk);
        disable fork;
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
