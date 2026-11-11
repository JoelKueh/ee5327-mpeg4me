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
    logic stall_next;
    logic load;
    logic [1:0] row_idx_mod_next;
    logic [WINDOW_SIZE+2:0][PEL_W-1:0] rb;
    logic [3:0][PEL_W-1:0] cb_next;
    logic [SAD_4X4_W-1:0] sad[WINDOW_SIZE];

    int sad_buf;

    fs_pe_array dut (.*);

    initial begin
        clk = 0;
        forever begin
            #5 clk = ~clk;
        end
    end

    task automatic drive_cycle(logic c, logic s, logic l, rb_row_t r, cb_row_t b);
        stall_next = s;
        load       = l;
        cb_next    = b;
        if (!s) row_idx_mod_next = c ? 2'd0 : row_idx_mod_next + 2'd1;
        @(posedge clk);
        #1;
        rb = s ? 'x : r;
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
        stall_next       = '0;
        load             = '0;
        row_idx_mod_next = '0;
        rb               = '0;
        cb_next          = '0;
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
        rb_row_t rb_buf[$];
        cb_row_t cb_buf[$];
        pel_arr_unpacked_t rb_unp;
        pel_arr_unpacked_t cb_unp;

        for (int i = 0; i < 4; i++) rb_buf.push_back('1);
        for (int i = 0; i < 4; i++) cb_buf.push_back('0);
        rb_unp = fs_tb_common_pkg::pel_unpack#(4, WINDOW_SIZE+3)::f(rb_buf);
        cb_unp = fs_tb_common_pkg::pel_unpack#(4, 4)::f(cb_buf);

        drive_cycle(1, 0, 1, 'x, 'x);
        drive_cycle(0, 0, 1, 'x, 'x);
        drive_cycle(1, 0, 1, rb_buf[0], cb_buf[0]);
        drive_cycle(0, 0, 1, rb_buf[1], cb_buf[1]);
        drive_cycle(0, 0, 1, rb_buf[2], cb_buf[2]);
        drive_cycle(0, 0, 1, rb_buf[3], cb_buf[3]);
        drive_cycle(0, 0, 0, rb_buf[0], cb_buf[0]);

        for (int i = 0; i < WINDOW_SIZE; i++) begin
            sad_buf = fs_tb_common_pkg::sad_reference(0, 0, 0, i, 4, 4, rb_unp, cb_unp);
            `FAIL_UNLESS_LOG(sad_buf === sad[i], $sformatf("i=0x%0h, actual=0x%0h expected=0x%0h", i, sad[i], sad_buf));
        end
    `SVTEST_END

    `SVTEST(min_sads)
        rb_row_t rb_buf[$];
        cb_row_t cb_buf[$];
        pel_arr_unpacked_t rb_unp;
        pel_arr_unpacked_t cb_unp;

        for (int i = 0; i < 4; i++) rb_buf.push_back('0);
        for (int i = 0; i < 4; i++) cb_buf.push_back('0);
        rb_unp = fs_tb_common_pkg::pel_unpack#(4, WINDOW_SIZE+3)::f(rb_buf);
        cb_unp = fs_tb_common_pkg::pel_unpack#(4, 4)::f(cb_buf);

        drive_cycle(1, 0, 1, rb_buf[0], cb_buf[0]);
        drive_cycle(0, 0, 1, rb_buf[1], cb_buf[1]);
        drive_cycle(0, 0, 1, rb_buf[2], cb_buf[2]);
        drive_cycle(0, 0, 1, rb_buf[3], cb_buf[3]);

        drive_cycle(0, 0, 0, rb_buf[0], 0);
        for (int i = 0; i < WINDOW_SIZE; i++) begin
            sad_buf = fs_tb_common_pkg::sad_reference(0, 0, 0, i, 4, 4, rb_unp, cb_unp);
            `FAIL_UNLESS_LOG(sad_buf === sad[i], $sformatf("i=0x%0h, actual=0x%0h expected=0x%0h", i, sad[i], sad_buf));
        end

        drive_cycle(0, 0, 0, rb_buf[1], 0);
        for (int i = 0; i < WINDOW_SIZE; i++) begin
            `FAIL_UNLESS_LOG(sad_buf === sad[i], $sformatf("i=0x%0h, actual=0x%0h expected=0x%0h", i, sad[i], sad_buf));
        end

        drive_cycle(0, 0, 0, rb_buf[2], 0);
        for (int i = 0; i < WINDOW_SIZE; i++) begin
            `FAIL_UNLESS_LOG(sad_buf === sad[i], $sformatf("i=0x%0h, actual=0x%0h expected=0x%0h", i, sad[i], sad_buf));
        end

        drive_cycle(0, 0, 0, rb_buf[3], 0);
        for (int i = 0; i < WINDOW_SIZE; i++) begin
            `FAIL_UNLESS_LOG(sad_buf === sad[i], $sformatf("i=0x%0h, actual=0x%0h expected=0x%0h", i, sad[i], sad_buf));
        end
    `SVTEST_END

    `SVTEST(max_sads)
        rb_row_t rb_buf[$];
        cb_row_t cb_buf[$];
        pel_arr_unpacked_t rb_unp;
        pel_arr_unpacked_t cb_unp;

        for (int i = 0; i < 4; i++) rb_buf.push_back('1);
        for (int i = 0; i < 4; i++) cb_buf.push_back('0);
        rb_unp = fs_tb_common_pkg::pel_unpack#(4, WINDOW_SIZE+3)::f(rb_buf);
        cb_unp = fs_tb_common_pkg::pel_unpack#(4, 4)::f(cb_buf);

        drive_cycle(1, 0, 1, rb_buf[0], cb_buf[0]);
        drive_cycle(0, 0, 1, rb_buf[1], cb_buf[1]);
        drive_cycle(0, 0, 1, rb_buf[2], cb_buf[2]);
        drive_cycle(0, 0, 1, rb_buf[3], cb_buf[3]);

        drive_cycle(0, 0, 0, rb_buf[0], '0);
        for (int i = 0; i < WINDOW_SIZE; i++) begin
            sad_buf = fs_tb_common_pkg::sad_reference(0, 0, 0, i, 4, 4, rb_unp, cb_unp);
            `FAIL_UNLESS_LOG(sad_buf === sad[i], $sformatf("i=0x%0h, actual=0x%0h expected=0x%0h", i, sad[i], sad_buf));
        end

        drive_cycle(0, 0, 0, rb_buf[1], '0);
        for (int i = 0; i < WINDOW_SIZE; i++) begin
            `FAIL_UNLESS_LOG(sad_buf === sad[i], $sformatf("i=0x%0h, actual=0x%0h expected=0x%0h", i, sad[i], sad_buf));
        end

        drive_cycle(0, 0, 0, rb_buf[2], '0);
        for (int i = 0; i < WINDOW_SIZE; i++) begin
            `FAIL_UNLESS_LOG(sad_buf === sad[i], $sformatf("i=0x%0h, actual=0x%0h expected=0x%0h", i, sad[i], sad_buf));
        end

        drive_cycle(0, 0, 0, rb_buf[3], '0);
        for (int i = 0; i < WINDOW_SIZE; i++) begin
            `FAIL_UNLESS_LOG(sad_buf === sad[i], $sformatf("i=0x%0h, actual=0x%0h expected=0x%0h", i, sad[i], sad_buf));
        end
    `SVTEST_END

    `SVTEST(typical)
        rb_row_t rb_buf[$];
        cb_row_t cb_buf[$];
        pel_arr_unpacked_t rb_unp;
        pel_arr_unpacked_t cb_unp;

        std::randomize(rb_buf) with { rb_buf.size == 8; };
        std::randomize(cb_buf) with { cb_buf.size == 4; }; 
        rb_unp = fs_tb_common_pkg::pel_unpack#(8, WINDOW_SIZE+3)::f(rb_buf);
        cb_unp = fs_tb_common_pkg::pel_unpack#(4, 4)::f(cb_buf);

        drive_cycle(1, 0, 1, rb_buf[0], cb_buf[0]);
        drive_cycle(0, 0, 1, rb_buf[1], cb_buf[1]);
        drive_cycle(0, 0, 1, rb_buf[2], cb_buf[2]);
        drive_cycle(0, 0, 1, rb_buf[3], cb_buf[3]);

        drive_cycle(0, 0, 0, rb_buf[4], '0);
        for (int i = 0; i < WINDOW_SIZE; i++) begin
            sad_buf = fs_tb_common_pkg::sad_reference(0, 0, 0, i, 4, 4, rb_unp, cb_unp);
            `FAIL_UNLESS_LOG(sad_buf === sad[i], $sformatf("i=0x%0h, actual=0x%0h expected=0x%0h", i, sad[i], sad_buf));
        end

        drive_cycle(0, 0, 0, rb_buf[5], 0);
        for (int i = 0; i < WINDOW_SIZE; i++) begin
            sad_buf = fs_tb_common_pkg::sad_reference(0, 0, 1, i, 4, 4, rb_unp, cb_unp);
            `FAIL_UNLESS_LOG(sad_buf === sad[i], $sformatf("i=0x%0h, actual=0x%0h expected=0x%0h", i, sad[i], sad_buf));
        end

        drive_cycle(0, 0, 0, rb_buf[6], 0);
        for (int i = 0; i < WINDOW_SIZE; i++) begin
            sad_buf = fs_tb_common_pkg::sad_reference(0, 0, 2, i, 4, 4, rb_unp, cb_unp);
            `FAIL_UNLESS_LOG(sad_buf === sad[i], $sformatf("i=0x%0h, actual=0x%0h expected=0x%0h", i, sad[i], sad_buf));
        end

        drive_cycle(0, 0, 0, rb_buf[7], 0);
        for (int i = 0; i < WINDOW_SIZE; i++) begin
            sad_buf = fs_tb_common_pkg::sad_reference(0, 0, 3, i, 4, 4, rb_unp, cb_unp);
            `FAIL_UNLESS_LOG(sad_buf === sad[i], $sformatf("i=0x%0h, actual=0x%0h expected=0x%0h", i, sad[i], sad_buf));
        end
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
