// me_top_unit_test.sv
//
// svunit testbench for me_top (full search motion estimator top).
//
// Skeleton - no behavioral coverage yet; add tests after the smoke test.
// The RAM ports (ram_a/b/c) are external flat ports; drive *_rd_data from
// RAM models added per test (tied to zero in setup() for now). Note:
// rst_n is held at 1, which per the RTL holds the DUT in reset (see the
// documented reset-polarity issue in fs_control).
// Run with: make test-full   (or make test for everything)
//
`include "svunit_defines.svh"

module me_top_unit_test;

    import me_pkg::*;
    import svunit_pkg::svunit_testcase;

    // ------------------------------------------------------------------
    // UUT signals (names match the me_top ports for .* connection)
    // ------------------------------------------------------------------
    logic clk;
    logic              rst_n;

    logic              rb_ready;
    logic              rb_valid;
    logic [WINDOW_SIZE+6:0][PEL_W-1:0] rb;

    logic              cb_ready;
    logic              cb_valid;
    logic [3:0][PEL_W-1:0] cb[4];

    logic                             ram_a_wr_en;
    logic [SW_IDX_W-1:0]              ram_a_wr_addr;
    logic [SAD_8X8_W+WINDOW_SIZE-1:0] ram_a_wr_data;
    logic                             ram_a_rd_en;
    logic [SW_IDX_W-1:0]              ram_a_rd_addr;
    logic [SAD_8X8_W+WINDOW_SIZE-1:0] ram_a_rd_data;

    logic                             ram_b_wr_en;
    logic [SW_IDX_W-1:0]              ram_b_wr_addr;
    logic [SAD_8X8_W+WINDOW_SIZE-1:0] ram_b_wr_data;
    logic                             ram_b_rd_en;
    logic [SW_IDX_W-1:0]              ram_b_rd_addr;
    logic [SAD_8X8_W+WINDOW_SIZE-1:0] ram_b_rd_data;

    logic                             ram_c_wr_en;
    logic [SW_IDX_W-1:0]              ram_c_wr_addr;
    logic [SAD_16X8_W+WINDOW_SIZE-1:0] ram_c_wr_data;
    logic                             ram_c_rd_en;
    logic [SW_IDX_W-1:0]              ram_c_rd_addr;
    logic [SAD_16X8_W+WINDOW_SIZE-1:0] ram_c_rd_data;

    logic [SAD_4X4_W-1:0]   min_sad_4x4[16];
    logic [SAD_8X4_W-1:0]   min_sad_4x8[8];
    logic [SAD_8X4_W-1:0]   min_sad_8x4[8];
    logic [SAD_8X8_W-1:0]   min_sad_8x8[4];
    logic [SAD_16X8_W-1:0]  min_sad_8x16[2];
    logic [SAD_16X8_W-1:0]  min_sad_16x8[2];
    logic [SAD_16X16_W-1:0] min_sad_16x16;

    mv_t mv_4x4[16];
    mv_t mv_4x8[8];
    mv_t mv_8x4[8];
    mv_t mv_8x8[4];
    mv_t mv_8x16[2];
    mv_t mv_16x8[2];
    mv_t mv_16x16;

    logic valid;

    // ------------------------------------------------------------------
    // UUT instance
    // ------------------------------------------------------------------
    me_top dut (.*);

    // 10ns clock, free-running for the whole run.
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ------------------------------------------------------------------
    // svunit scaffolding
    // ------------------------------------------------------------------
    string name = "me_top_ut";
    svunit_testcase svunit_ut;

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        // TODO: fix the rst_n polarity contradiction in fs_control, then
        // apply a real reset sequence here.
        rst_n    = '1;
        rb_valid = '0;
        cb_valid = '0;
        rb       = '0;
        for (int i = 0; i < 4; i++) cb[i] = '0;
        // TODO: model the RAMs; for now reads return zero.
        ram_a_rd_data = '0;
        ram_b_rd_data = '0;
        ram_c_rd_data = '0;
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN

    `SVTEST(skeleton_smoke)
        // TODO: replace with real coverage of me_top (e.g. stream one
        // block of RB/CB data and check the result outputs).
        `INFO("skeleton_smoke: free-running clock for a few cycles");
        repeat (4) @(posedge clk);
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
