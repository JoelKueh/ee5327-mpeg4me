// fs_pe_unit_test.sv
//
// svunit testbench for fs_pe (time-multiplexed 4x4 SAD processing element).
//
`include "svunit_defines.svh"

module fs_pe_unit_test;

    import me_pkg::*;
    import svunit_pkg::svunit_testcase;

    // ------------------------------------------------------------------
    // test wiring
    // ------------------------------------------------------------------

    localparam int NUM_RB_ROWS = 32;

    typedef logic [3:0][PEL_W-1:0] pel_row_t;
    typedef pel_row_t              cb_block_t[4];
    typedef pel_row_t              rb_window_t[NUM_RB_ROWS];

    logic                  clk;
    logic                  stall;
    logic                  clear;
    logic [3:0][PEL_W-1:0] rb;
    logic [3:0][PEL_W-1:0] cb;
    logic [SAD_4X4_W-1:0]  sad;

    // Pipeline tracking signals registered in NBA alongside dut.acc_q[0]
    logic                  sad_valid_d, sad_valid_q;
    int                    sad_idx_d,   sad_idx_q;

    fs_pe dut (.*);

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, fs_pe_unit_test, "+mda", "+all");
        clk = '0;
        forever #5 clk = ~clk;
    end

    always_ff @(posedge clk) begin
        sad_valid_q <= sad_valid_d && !stall;
        if (!stall) begin
            sad_idx_q <= sad_idx_d;
        end
    end

    // Drive all synchronous DUT inputs with '<=' so updates occur in the NBA
    // region after the DUT and monitor have sampled the Active region.
    task automatic drive_cycle(logic do_s, logic c, logic v, int idx,
                               pel_row_t rb_in, pel_row_t cb_in);
        clear       <= c;
        rb          <= rb_in;
        cb          <= cb_in;
        sad_valid_d <= v;
        sad_idx_d   <= idx;

        if (do_s) begin
            stall <= 1'b1;
            @(posedge clk);
        end

        stall <= 1'b0;
        @(posedge clk);
    endtask

    task automatic drive_row(logic do_s, int row_idx, pel_row_t rb_row, cb_block_t cb_blk);
        for (int sub = 0; sub < 4; sub++) begin
            logic is_clear = (sub == 3);
            logic is_valid = (sub == 0) && (row_idx >= 3);
            int   done_idx = row_idx - 3;

            drive_cycle(do_s, is_clear, is_valid, done_idx, rb_row, cb_blk[3 - sub]);
        end
    endtask

    task automatic drive_window(logic do_s, rb_window_t rb_win, cb_block_t cb_blk);
        for (int r = 0; r < NUM_RB_ROWS; r++) begin
            drive_row(do_s, r, rb_win[r], cb_blk);
        end
        // Flush the final finished SAD out onto acc_q[0] and allow monitor to sample it
        drive_cycle(do_s, 1'b1, 1'b0, 0, '0, '0);
    endtask

    // Sample in the Active region at @(posedge clk), before NBA updates flip-flops
    task automatic monitor_sads(rb_window_t rb_win, cb_block_t cb_blk);
        int exp_sad;

        @(posedge clk);
        if (sad_valid_q) begin
            exp_sad = 0;
            for (int r = 0; r < 4; r++) begin
                for (int c = 0; c < 4; c++) begin
                    int rb_pel = int'(rb_win[sad_idx_q + r][c]);
                    int cb_pel = int'(cb_blk[r][c]);
                    exp_sad += (rb_pel > cb_pel) ? (rb_pel - cb_pel) : (cb_pel - rb_pel);
                end
            end

            `FAIL_UNLESS_LOG(sad === SAD_4X4_W'(exp_sad), $sformatf(
                "sad_idx=%0d act=0x%0h exp=0x%0h", sad_idx_q, sad, SAD_4X4_W'(exp_sad)
            ));
        end
    endtask

    // ------------------------------------------------------------------
    // svunit scaffolding
    // ------------------------------------------------------------------

    string name = "fs_pe_ut";
    svunit_testcase svunit_ut;

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        stall       = '0;
        clear       = '0;
        rb          = '0;
        cb          = '0;
        sad_valid_d = '0;
        sad_valid_q = '0;
        sad_idx_d   = 0;
        sad_idx_q   = 0;
        @(posedge clk);
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN

    `SVTEST(typical)
        rb_window_t rb_win;
        cb_block_t  cb_blk;

        std::randomize(rb_win);
        std::randomize(cb_blk);

        fork
            forever monitor_sads(rb_win, cb_blk);
        join_none

        drive_window(0, rb_win, cb_blk);
        drive_window(0, rb_win, cb_blk);

        @(posedge clk);
        disable fork;
    `SVTEST_END

    `SVTEST(typical_stall)
        rb_window_t rb_win;
        cb_block_t  cb_blk;

        std::randomize(rb_win);
        std::randomize(cb_blk);

        fork
            forever monitor_sads(rb_win, cb_blk);
        join_none

        drive_window(1, rb_win, cb_blk);
        drive_window(1, rb_win, cb_blk);

        @(posedge clk);
        disable fork;
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
