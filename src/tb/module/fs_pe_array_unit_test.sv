// fs_pe_array_unit_test.sv
//
// svunit testbench for fs_pe_array (row of 4x4 SAD PEs).
//
// Skeleton - no behavioral coverage yet; add tests after the smoke test.
// Run with: make test-module   (or make test for everything)
//
`include "svunit_defines.svh"

module fs_pe_array_unit_test;

    import me_pkg::*;
    import svunit_pkg::svunit_testcase;

    // ------------------------------------------------------------------
    // UUT signals
    // ------------------------------------------------------------------
    logic clk;
    logic              clear;
    logic              stall;
    logic              load;
    logic [1:0]        row_idx_mod;
    logic [WINDOW_SIZE+2:0][PEL_W-1:0] rb;
    logic [3:0][PEL_W-1:0]            cb;
    logic [SAD_4X4_W-1:0]             sad[WINDOW_SIZE];

    // ------------------------------------------------------------------
    // UUT instance
    // ------------------------------------------------------------------
    fs_pe_array dut (
        .clk         (clk),
        .clear       (clear),
        .stall       (stall),
        .load        (load),
        .row_idx_mod (row_idx_mod),
        .rb          (rb),
        .cb          (cb),
        .sad         (sad)
    );

    // 10ns clock, free-running for the whole run.
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ------------------------------------------------------------------
    // svunit scaffolding
    // ------------------------------------------------------------------
    string name = "fs_pe_array_ut";
    svunit_testcase svunit_ut;

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        clear       = '0;
        stall       = '0;
        load        = '0;
        row_idx_mod = '0;
        rb          = '0;
        cb          = '0;
        for (int i = 0; i < WINDOW_SIZE; i++) sad[i] = '0;
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN

    `SVTEST(skeleton_smoke)
        // TODO: replace with real coverage of fs_pe_array.
        `INFO("skeleton_smoke: free-running clock for a few cycles");
        repeat (4) @(posedge clk);
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
