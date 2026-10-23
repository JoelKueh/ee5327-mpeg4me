// fs_control_unit_test.sv
//
// svunit testbench for fs_control (RB/CB handshake + datapath control).
//
// Skeleton - no behavioral coverage yet; add tests after the smoke test.
// The RAMs behind the sram_if mstr ports are currently unmodeled: rd_data
// is tied to zero in setup(). Note: rst_n is held at 1, which per the RTL
// holds the DUT in reset (see the documented reset-polarity issue).
// Run with: make test-module   (or make test for everything)
//
`include "svunit_defines.svh"

module fs_control_unit_test;

    import me_pkg::*;
    import svunit_pkg::svunit_testcase;

    // ------------------------------------------------------------------
    // UUT signals
    // ------------------------------------------------------------------
    logic clk;
    logic              rst_n;
    logic              rb_ready;
    logic              rb_valid;
    logic [WINDOW_SIZE+6:0][PEL_W-1:0] rb;
    logic              cb_ready;
    logic              cb_valid;
    logic [3:0][PEL_W-1:0] cb[4];

    // RAM models for the control's three SRAM ports (TODO: implement).
    sram_if#(.ADDR_W(SW_IDX_W), .DATA_W(SAD_8X8_W+WINDOW_SIZE))  ram_a();
    sram_if#(.ADDR_W(SW_IDX_W), .DATA_W(SAD_8X8_W+WINDOW_SIZE))  ram_b();
    sram_if#(.ADDR_W(SW_IDX_W), .DATA_W(SAD_16X8_W+WINDOW_SIZE)) ram_c();

    sad_result_if results();

    // ------------------------------------------------------------------
    // UUT instance
    // ------------------------------------------------------------------
    fs_control dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .rb_ready  (rb_ready),
        .rb_valid  (rb_valid),
        .rb        (rb),
        .cb_ready  (cb_ready),
        .cb_valid  (cb_valid),
        .cb        (cb),
        .ram_a     (ram_a.mstr),
        .ram_b     (ram_b.mstr),
        .ram_c     (ram_c.mstr),
        .results   (results.source)
    );

    // 10ns clock, free-running for the whole run.
    initial begin
        $dumpfile("fs_control.vcd");
        $dumpvars(0);
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ------------------------------------------------------------------
    // svunit scaffolding
    // ------------------------------------------------------------------
    string name = "fs_control_ut";
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
        ram_a.rd_data = '0;
        ram_b.rd_data = '0;
        ram_c.rd_data = '0;
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN

    `SVTEST(skeleton_smoke)
        // TODO: replace with real coverage of fs_control.
        `INFO("skeleton_smoke: free-running clock for a few cycles");
        repeat (4) @(posedge clk);
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
