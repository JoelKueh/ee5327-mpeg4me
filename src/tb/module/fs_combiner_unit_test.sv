// fs_combiner_unit_test.sv
//
// svunit testbench for fs_combiner (8x8 -> 16x8 / 16x16 SAD combination).
//
// Skeleton - no behavioral coverage yet; add tests after the smoke test.
// The RAMs behind the sram_if mstr ports are currently unmodeled: rd_data
// is tied to zero in setup(). Add RAM models (or stimulus) per test.
// Run with: make test-module   (or make test for everything)
//
`include "svunit_defines.svh"

module fs_combiner_unit_test;

    import me_pkg::*;
    import svunit_pkg::svunit_testcase;

    // ------------------------------------------------------------------
    // UUT signals
    // ------------------------------------------------------------------
    logic clk;
    logic              stall;
    logic              sad_8x8_valid;
    logic [1:0]        cb_subblock_idx;
    logic [SW_IDX_W-1:0] sw_idx_8x8;
    logic [SAD_8X8_W-1:0] sad_8x8[WINDOW_SIZE];
    logic              sad_16x8_valid;
    logic [SW_IDX_W-1:0] sw_idx_16x8;
    logic [SAD_16X8_W-1:0] sad_16x8[WINDOW_SIZE];
    logic              sad_16x16_valid;
    logic [SW_IDX_W-1:0] sw_idx_16x16;
    logic [SAD_16X16_W-1:0] sad_16x16[WINDOW_SIZE];

    // RAM models for the combiner's three SRAM ports (TODO: implement).
    sram_if#(.ADDR_W(SW_IDX_W), .DATA_W(SAD_8X8_W+WINDOW_SIZE))  ram_a();
    sram_if#(.ADDR_W(SW_IDX_W), .DATA_W(SAD_8X8_W+WINDOW_SIZE))  ram_b();
    sram_if#(.ADDR_W(SW_IDX_W), .DATA_W(SAD_16X8_W+WINDOW_SIZE)) ram_c();

    // ------------------------------------------------------------------
    // UUT instance
    // ------------------------------------------------------------------
    fs_combiner dut (
        .clk            (clk),
        .stall          (stall),
        .sad_8x8_valid  (sad_8x8_valid),
        .cb_subblock_idx(cb_subblock_idx),
        .sw_idx_8x8     (sw_idx_8x8),
        .sad_8x8        (sad_8x8),
        .ram_a          (ram_a.mstr),
        .ram_b          (ram_b.mstr),
        .ram_c          (ram_c.mstr),
        .sad_16x8_valid (sad_16x8_valid),
        .sw_idx_16x8    (sw_idx_16x8),
        .sad_16x8       (sad_16x8),
        .sad_16x16_valid(sad_16x16_valid),
        .sw_idx_16x16   (sw_idx_16x16),
        .sad_16x16      (sad_16x16)
    );

    // 10ns clock, free-running for the whole run.
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ------------------------------------------------------------------
    // svunit scaffolding
    // ------------------------------------------------------------------
    string name = "fs_combiner_ut";
    svunit_testcase svunit_ut;

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        stall          = '0;
        sad_8x8_valid  = '0;
        cb_subblock_idx = '0;
        sw_idx_8x8     = '0;
        for (int i = 0; i < WINDOW_SIZE; i++) sad_8x8[i] = '0;
        // TODO: model the RAMs; for now reads return zero.
        ram_a.rd_data = '0;
        ram_b.rd_data = '0;
        ram_c.rd_data = '0;
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN

    `SVTEST(skeleton_smoke)
        // TODO: replace with real coverage of fs_combiner.
        `INFO("skeleton_smoke: free-running clock for a few cycles");
        repeat (4) @(posedge clk);
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
