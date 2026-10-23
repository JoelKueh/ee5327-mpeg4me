// fs_comparator_unit_test.sv
//
// svunit testbench for fs_comparator (WINDOW_SIZE-wide MIN reduction).
//
// Skeleton - no behavioral coverage yet; add tests after the smoke test.
// The DUT is instantiated with the default SAD_RESULT_W=SAD_8X4_W; for the
// 8x8 / 16x8 / 16x16 comparators, re-instantiate with
// fs_comparator#(.SAD_RESULT_W(SAD_8X8_W)) dut(...) and so on.
// Run with: make test-module   (or make test for everything)
//
`include "svunit_defines.svh"

module fs_comparator_unit_test;

    import me_pkg::*;
    import svunit_pkg::svunit_testcase;

    // ------------------------------------------------------------------
    // UUT signals
    // ------------------------------------------------------------------
    logic clk;
    logic              clear;
    logic              stall;
    logic [SW_IDX_W-1:0]  input_sw_idx;
    logic [SAD_8X4_W-1:0] input_sads[WINDOW_SIZE];
    logic              result_valid;
    logic [SAD_8X4_W-1:0] result_sad;
    mv_t               result_mv;

    // ------------------------------------------------------------------
    // UUT instance
    // ------------------------------------------------------------------
    fs_comparator dut (
        .clk          (clk),
        .clear        (clear),
        .stall        (stall),
        .input_sw_idx (input_sw_idx),
        .input_sads   (input_sads),
        .result_valid (result_valid),
        .result_sad   (result_sad),
        .result_mv    (result_mv)
    );

    // 10ns clock, free-running for the whole run.
    initial begin
        $dumpfile("fs_comparator.vcd");
        $dumpvars(0);
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ------------------------------------------------------------------
    // svunit scaffolding
    // ------------------------------------------------------------------
    string name = "fs_comparator_ut";
    svunit_testcase svunit_ut;

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        clear        = '0;
        stall        = '0;
        input_sw_idx = '0;
        for (int i = 0; i < WINDOW_SIZE; i++) input_sads[i] = '0;
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN

    `SVTEST(skeleton_smoke)
        // TODO: replace with real coverage of fs_comparator.
        `INFO("skeleton_smoke: free-running clock for a few cycles");
        repeat (4) @(posedge clk);
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
