// fs_computer_unit_test.sv
//
// svunit testbench for fs_computer (first-level 8x4 / 8x8 SAD computation).
//
// Skeleton - no behavioral coverage yet; add tests after the smoke test.
// Run with: make test-module   (or make test for everything)
//
`include "svunit_defines.svh"

module fs_computer_unit_test;

    import me_pkg::*;
    import svunit_pkg::svunit_testcase;

    // ------------------------------------------------------------------
    // UUT signals
    // ------------------------------------------------------------------
    logic clk;
    logic              clear;
    logic              stall;
    logic [3:0][PEL_W-1:0]            cb[4];
    logic [WINDOW_SIZE+6:0][PEL_W-1:0] rb;
    logic [RB_ROW_IDX_W-1:0]          rb_row_idx;
    logic [SAD_8X4_W-1:0]             sad_8x4[2][WINDOW_SIZE];
    logic [SAD_8X8_W-1:0]             sad_8x8[WINDOW_SIZE];
    logic [RB_ROW_IDX_W-1:0]          sad_row_idx;

    // ------------------------------------------------------------------
    // UUT instance
    // ------------------------------------------------------------------
    fs_computer dut (
        .clk         (clk),
        .clear       (clear),
        .stall       (stall),
        .cb          (cb),
        .rb          (rb),
        .rb_row_idx  (rb_row_idx),
        .sad_8x4     (sad_8x4),
        .sad_8x8     (sad_8x8),
        .sad_row_idx (sad_row_idx)
    );

    // 10ns clock, free-running for the whole run.
    initial begin
        $dumpfile("fs_computer.vcd");
        $dumpvars(0);
        clk = 0;
        forever #5 clk = ~clk;
    end

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
        clear      = '0;
        stall      = '0;
        rb         = '0;
        rb_row_idx = '0;
        for (int i = 0; i < 4; i++) cb[i] = '0;
        for (int i = 0; i < 2; i++)
            for (int j = 0; j < WINDOW_SIZE; j++) sad_8x4[i][j] = '0;
        for (int i = 0; i < WINDOW_SIZE; i++) sad_8x8[i] = '0;
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN

    `SVTEST(skeleton_smoke)
        // TODO: replace with real coverage of fs_computer.
        `INFO("skeleton_smoke: free-running clock for a few cycles");
        repeat (4) @(posedge clk);
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
