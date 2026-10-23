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
    // test wiring
    // ------------------------------------------------------------------

    typedef logic [WINDOW_SIZE+2:0][PEL_W-1:0] rb_row_t;
    typedef logic [3:0][PEL_W-1:0] cb_row_t;

    logic clk;
    logic clear;
    logic stall;
    logic load;
    logic [1:0] row_idx_mod;
    logic [WINDOW_SIZE+2:0][PEL_W-1:0] rb;
    logic [3:0][PEL_W-1:0] cb;
    logic [SAD_4X4_W-1:0] sad[WINDOW_SIZE];

    fs_pe_array dut (.*);

    initial begin
        $dumpfile("fs_pe_array.vcd");
        $dumpvars(0);
        clk = 0;
        forever #5 clk = ~clk;
    end

    task automatic drive_cycle(logic c, logic s, rb_row_t r, cb_row_t b);
        @(negedge clk);
        clear <= c;
        stall <= s;
        rb    <= r;
        cb    <= b;
        #0;
        @(posedge clk);
        #1;
    endtask

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

    // ------------------------------------------------------------------
    // test definitions
    // ------------------------------------------------------------------

    /* verilator lint_off DECLFILENAME */
    `SVUNIT_TESTS_BEGIN

    `SVTEST(clear_resets_array)
        drive_cycle(1, 0, 0, 0);
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
