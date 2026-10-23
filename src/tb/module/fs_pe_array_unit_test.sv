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
    import fs_tb_common_pkg::*;

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

    rb_row_t rb_buf[4];
    cb_row_t cb_buf[4];
    pel_arr_unpacked_t rb_unp;
    pel_arr_unpacked_t cb_unp;
    int sad_buf;

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
        std::randomize(rb_buf);
        std::randomize(cb_buf);
        rb_unp = fs_tb_common_pkg::pel_unpack#(4, WINDOW_SIZE+2, PEL_W)::f(rb_buf);
        cb_unp = fs_tb_common_pkg::pel_unpack#(4, 4, PEL_W)::f(cb_buf);


        drive_cycle(1, 0, rb_buf[0], cb_buf[0]);
        drive_cycle(0, 0, rb_buf[1], cb_buf[1]);
        drive_cycle(1, 0, rb_buf[0], cb_buf[0]);
        drive_cycle(0, 0, rb_buf[1], cb_buf[1]);
        drive_cycle(0, 0, rb_buf[2], cb_buf[2]);
        drive_cycle(0, 0, rb_buf[3], cb_buf[3]);

        for (int i = 0; i < WINDOW_SIZE; i++) begin
            sad_buf = fs_tb_common_pkg::sad_reference(0, 0, 0, i, 4, 4, rb_buf, cb_buf);
            `FAIL_UNLESS_LOG(sad_buf === sad[i], $sformatf("actual=0x%0h expected=0x%0h", 0, sad));
        end
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
