// fs_control_unit_test.sv
//
// svunit testbench for fs_control (RB/CB handshake + datapath control).
//
`include "svunit_defines.svh"

module fs_control_unit_test;

    import me_pkg::*;
    import svunit_pkg::svunit_testcase;
    import fs_tb_common_pkg::*;

    // ------------------------------------------------------------------
    // test_wiring
    // ------------------------------------------------------------------

    typedef logic [WINDOW_SIZE+6:0][PEL_W-1:0] rb_row_t;
    typedef logic [7:0][PEL_W-1:0] cb_row_t;
    typedef logic [PEL_W-1:0] frame_t[FRAME_HEIGHT][FRAME_WIDTH];

    logic clk;
    logic clear;
    logic rb_ready;
    logic rb_valid;
    logic [WINDOW_SIZE+6:0][PEL_W-1:0] rb;
    logic cb_ready;
    logic cb_valid;
    logic [7:0][PEL_W-1:0] cb;

    sad_result_if results ();

    fs_control dut (.*);

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, fs_control_unit_test, "+mda", "+all");
        clk   = 0;
        forever #5 clk = ~clk;
    end

    task automatic drive_cycle(rb_row_t rb_d, cb_row_t cb_d);
        rb_valid = 1;
        rb = rb_d;
        cb_valid = 1;
        cb = cb_d;

        #0;
        @(posedge clk);
        #0;
    endtask

    task automatic drive_subblock(rb_row_t rb_d[39], cb_row_t cb_d[8]);
        for (int i = 0; i < 39; i++) begin
            if (i < 8) begin
                drive_cycle(rb_d[i], cb_d[i]);
            end else begin
                drive_cycle(rb_d[i], 'x);
            end
        end
    endtask

    task automatic get_sb(inout rb_row_t rb_d[39], cb_row_t cb_d[8], input frame_t rf, frame_t cf,
                          int b_idx, int sb_idx);
        int signed b_row, b_col;
        int signed rf_row, rf_col;
        int signed cf_row, cf_col;

        b_row = b_idx / 80;
        b_col = b_idx % 80;

        rf_row = (b_row - 1) * 16;
        rf_col = (b_col - 1) * 16;

        for (int row = 0; row < 39; row++) begin
            for (int col = 0; col < 39; col++) begin
                if (row >= 0 && row < 720 && col >= 0 && col < 1280)
                    rb_d[row][col] = rf[rf_row+row][rf_col+col];
                else
                    rb_d[row][col] = '0;
            end
        end

        cf_row = b_row * 16;
        cf_col = b_col * 16;

        for (int row = 0; row < 8; row++) begin
            for (int col = 0; col < 8; col++) begin
                if (row >= 0 && row < 720 && col >= 0 && col < 1280)
                    cb_d[row][col] = cf[cf_row+row][cf_col+col];
                else
                    cb_d[row][col] = '0;
            end
        end
    endtask

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
        rb_valid = '0;
        cb_valid = '0;
        rb       = '0;
        for (int i = 0; i < 4; i++) cb[i] = '0;
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN

    `SVTEST(typical)
        rb_row_t rb_d[39];
        cb_row_t cb_d[8];

        std::randomize(rb_d);
        std::randomize(cb_d);

        clear = 1;
        #20 clear = 0;

        drive_subblock(rb_d, cb_d);
        drive_subblock(rb_d, cb_d);
        drive_subblock(rb_d, cb_d);
        drive_subblock(rb_d, cb_d);
        drive_subblock(rb_d, cb_d);
        drive_subblock(rb_d, cb_d);
    `SVTEST_END

    `SVTEST(typical_stall)
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
