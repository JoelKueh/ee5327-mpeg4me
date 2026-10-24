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
    import fs_tb_common_pkg::*;

    // ------------------------------------------------------------------
    // test wiring
    // ------------------------------------------------------------------

    typedef logic [WINDOW_SIZE+6:0][PEL_W-1:0] rb_row_t;
    typedef logic [7:0][PEL_W-1:0] cb_row_t;

    logic clk;
    logic stall;
    logic [7:0][PEL_W-1:0]             cb;
    logic [WINDOW_SIZE+6:0][PEL_W-1:0] rb;
    logic [RB_ROW_IDX_W-1:0]           rb_row_idx;
    logic [SAD_8X4_W-1:0]              sad_8x4[2][WINDOW_SIZE];
    logic [SAD_8X8_W-1:0]              sad_8x8[WINDOW_SIZE];
    logic [RB_ROW_IDX_W-1:0]           sad_row_idx;

    fs_computer dut (.*);

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    task automatic record_cycle(
        inout logic [SAD_8X4_W-1:0] sad_8x4_buf[$][2][WINDOW_SIZE],
        inout logic [SAD_8X8_W-1:0] sad_8x8_buf[$][WINDOW_SIZE],
        inout logic [RB_ROW_IDX_W-1:0] sad_row_idx_buf[$]
    );
        sad_8x4_buf.push_back(sad_8x4);
        sad_8x8_buf.push_back(sad_8x8);
        sad_row_idx_buf.push_back(sad_row_idx);
    endtask

    task automatic drive_cycle(
        inout logic [SAD_8X4_W-1:0] sad_8x4_buf[$][2][WINDOW_SIZE],
        inout logic [SAD_8X8_W-1:0] sad_8x8_buf[$][WINDOW_SIZE],
        inout logic [RB_ROW_IDX_W-1:0] sad_row_idx_buf[$],
        input int row_idx, logic s, rb_row_t r, cb_row_t b, bit record
    );
        stall = s;
        rb = r;
        cb = b;
        rb_row_idx = row_idx;
        #1;
        if (record) record_cycle(sad_8x4_buf, sad_8x8_buf, sad_row_idx_buf);
        $display("[%d] rb_row_idx=0x%h sad_row_idx=0x%h rb=0x%h cb=0x%h acc_q=0x%0h pe.sad=0x%0h sad_8x8=0x%0h",
            $time, rb_row_idx, dut.sad_row_idx_q,
            dut.pe_array_ul.pe_array_row[0].pe_array_col[0].pe.rb,
            dut.pe_array_ul.pe_array_row[0].pe_array_col[0].pe.cb,
            dut.pe_array_ul.pe_array_row[0].pe_array_col[0].pe.acc_q,
            dut.pe_array_ul.sad[0],
            dut.sad_8x8_q[0]);
        @(posedge clk);
        #0;
    endtask

    task automatic drive(
        inout logic [SAD_8X4_W-1:0] sad_8x4_buf[$][2][WINDOW_SIZE],
        inout logic [SAD_8X8_W-1:0] sad_8x8_buf[$][WINDOW_SIZE],
        inout logic [RB_ROW_IDX_W-1:0] sad_row_idx_buf[$],
        input rb_row_t rb_buf[$], input cb_row_t cb_buf[$], input logic do_stall
    );
        for (int i = 0; i < 8; i++) begin
            if (do_stall && $urandom_range(1,100) > 70)
                drive_cycle(sad_8x4_buf, sad_8x8_buf, sad_row_idx_buf, i, 1, 'x, 'x, 0);
            drive_cycle(sad_8x4_buf, sad_8x8_buf, sad_row_idx_buf, i, 0, rb_buf[i], cb_buf[i], 1);
        end

        for (int i = 8; i < rb_buf.size(); i++) begin
            if (do_stall && $urandom_range(1,100) > 70)
                drive_cycle(sad_8x4_buf, sad_8x8_buf, sad_row_idx_buf, i, 1, 'x, 'x, 0);
            drive_cycle(sad_8x4_buf, sad_8x8_buf, sad_row_idx_buf, i, 0, rb_buf[i], 0, 1);
        end

        for (int i = rb_buf.size(); i < rb_buf.size() + 10; i++) begin
            if (do_stall && $urandom_range(1,100) > 70)
                drive_cycle(sad_8x4_buf, sad_8x8_buf, sad_row_idx_buf, i, 1, 'x, 'x, 0);
            drive_cycle(sad_8x4_buf, sad_8x8_buf, sad_row_idx_buf, i, 0, 'x, 'x, 1);
        end
    endtask

    task automatic check(
        input logic [SAD_8X4_W-1:0] sad_8x4_buf[$][2][WINDOW_SIZE],
        input logic [SAD_8X8_W-1:0] sad_8x8_buf[$][WINDOW_SIZE],
        input logic [RB_ROW_IDX_W-1:0] sad_row_idx_buf[$],
        input pel_arr_unpacked_t rb_unp, input pel_arr_unpacked_t cb_unp
    );
        int sad_buf;

        for (int i = 0; i < 20; i++) begin
            $display("i=0x%0h ridx=0x%0h sad_8x8=0x%0h sad_8x4[0]=0x%0h sad_8x4[1]=0x%0h", i,
                sad_row_idx_buf[i], sad_8x8_buf[i][0], sad_8x4_buf[i][0][0], sad_8x4_buf[i][1][0]);
        end

        for (int i = 0; i < 20; i++) begin
            $display("i=0x%0h rb_unp=%p cb_unp=%p", i, rb_unp[i], cb_unp[i]);
        end

        for (int i = 9; i < 18; i++) begin
            for (int j = 0; j < WINDOW_SIZE; j++) begin
                `FAIL_UNLESS_LOG(i-9 === sad_row_idx_buf[i], $sformatf(
                    "act=0x%0h exp=0x%0h", sad_row_idx_buf[i], i-9)
                );

                sad_buf = fs_tb_common_pkg::sad_reference(0, 0, i-9, j, 8, 4, rb_unp, cb_unp);
                `FAIL_UNLESS_LOG(sad_buf === sad_8x4_buf[i][0][j], $sformatf(
                    "8x4[0][0x%0h], act=0x%0h exp=0x%0h", i-9, sad_8x4_buf[i][0][j], sad_buf)
                );

                sad_buf = fs_tb_common_pkg::sad_reference(0, 4, i-9, j+4, 8, 4, rb_unp, cb_unp);
                `FAIL_UNLESS_LOG(sad_buf === sad_8x4_buf[i][1][j], $sformatf(
                    "8x4[1][0x%0h], act=0x%0h exp=0x%0h", i-9, sad_8x4_buf[i][1][j], sad_buf)
                );

                sad_buf = fs_tb_common_pkg::sad_reference(0, 0, i-9, j, 8, 8, rb_unp, cb_unp);
                `FAIL_UNLESS_LOG(sad_buf === sad_8x8_buf[i][j], $sformatf(
                    "8x8[0x%0h], act=0x%0h exp=0x%0h", i-9, sad_8x8_buf[i][j], sad_buf)
                );
            end
        end
    endtask

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

    `SVTEST(clear)
        rb_row_t rb_buf[$];
        cb_row_t cb_buf[$];
        pel_arr_unpacked_t rb_unp;
        pel_arr_unpacked_t cb_unp;

        logic [SAD_8X4_W-1:0] sad_8x4_buf[$][2][WINDOW_SIZE];
        logic [SAD_8X8_W-1:0] sad_8x8_buf[$][WINDOW_SIZE];
        logic [RB_ROW_IDX_W-1:0] sad_row_idx_buf[$];

        for (int i = 0; i < 16; i++) rb_buf.push_back('0);
        for (int i = 0; i < 8; i++) cb_buf.push_back('1);
        rb_unp = fs_tb_common_pkg::pel_unpack#(16, WINDOW_SIZE+7)::f(rb_buf);
        cb_unp = fs_tb_common_pkg::pel_unpack#(8, 8)::f(cb_buf);

        drive_cycle(sad_8x4_buf, sad_8x8_buf, sad_row_idx_buf, 0, 0, 'x, 'x, 0);
        drive_cycle(sad_8x4_buf, sad_8x8_buf, sad_row_idx_buf, 1, 0, 'x, 'x, 0);
        drive(sad_8x4_buf, sad_8x8_buf, sad_row_idx_buf, rb_buf, cb_buf, 0);

        check(sad_8x4_buf, sad_8x8_buf, sad_row_idx_buf, rb_unp, cb_unp);
    `SVTEST_END

    `SVTEST(min_sad)
        rb_row_t rb_buf[$];
        cb_row_t cb_buf[$];
        pel_arr_unpacked_t rb_unp;
        pel_arr_unpacked_t cb_unp;

        logic [SAD_8X4_W-1:0] sad_8x4_buf[$][2][WINDOW_SIZE];
        logic [SAD_8X8_W-1:0] sad_8x8_buf[$][WINDOW_SIZE];
        logic [RB_ROW_IDX_W-1:0] sad_row_idx_buf[$];

        for (int i = 0; i < 16; i++) rb_buf.push_back('1);
        for (int i = 0; i < 8; i++) cb_buf.push_back('1);
        rb_unp = fs_tb_common_pkg::pel_unpack#(16, WINDOW_SIZE+7)::f(rb_buf);
        cb_unp = fs_tb_common_pkg::pel_unpack#(8, 8)::f(cb_buf);

        drive(sad_8x4_buf, sad_8x8_buf, sad_row_idx_buf, rb_buf, cb_buf, 0);

        check(sad_8x4_buf, sad_8x8_buf, sad_row_idx_buf, rb_unp, cb_unp);
    `SVTEST_END

    `SVTEST(max_sad)
        rb_row_t rb_buf[$];
        cb_row_t cb_buf[$];
        pel_arr_unpacked_t rb_unp;
        pel_arr_unpacked_t cb_unp;

        logic [SAD_8X4_W-1:0] sad_8x4_buf[$][2][WINDOW_SIZE];
        logic [SAD_8X8_W-1:0] sad_8x8_buf[$][WINDOW_SIZE];
        logic [RB_ROW_IDX_W-1:0] sad_row_idx_buf[$];

        for (int i = 0; i < 16; i++) rb_buf.push_back('1);
        for (int i = 0; i < 8; i++) cb_buf.push_back('0);
        rb_unp = fs_tb_common_pkg::pel_unpack#(16, WINDOW_SIZE+7)::f(rb_buf);
        cb_unp = fs_tb_common_pkg::pel_unpack#(8, 8)::f(cb_buf);

        drive(sad_8x4_buf, sad_8x8_buf, sad_row_idx_buf, rb_buf, cb_buf, 0);

        check(sad_8x4_buf, sad_8x8_buf, sad_row_idx_buf, rb_unp, cb_unp);
    `SVTEST_END

    `SVTEST(typical)
        rb_row_t rb_buf[$];
        cb_row_t cb_buf[$];
        pel_arr_unpacked_t rb_unp;
        pel_arr_unpacked_t cb_unp;

        logic [SAD_8X4_W-1:0] sad_8x4_buf[$][2][WINDOW_SIZE];
        logic [SAD_8X8_W-1:0] sad_8x8_buf[$][WINDOW_SIZE];
        logic [RB_ROW_IDX_W-1:0] sad_row_idx_buf[$];

        // for (int i = 0; i < 16; i++) rb_buf.push_back(32'hFFFFFFFF);
        // for (int i = 0; i < 8; i++) cb_buf.push_back(64'hFFFFFFFF00000000);
        std::randomize(rb_buf) with { rb_buf.size == 16; };
        std::randomize(cb_buf) with { cb_buf.size == 8; };
        rb_unp = fs_tb_common_pkg::pel_unpack#(16, WINDOW_SIZE+7)::f(rb_buf);
        cb_unp = fs_tb_common_pkg::pel_unpack#(8, 8)::f(cb_buf);

        drive(sad_8x4_buf, sad_8x8_buf, sad_row_idx_buf, rb_buf, cb_buf, 0);

        check(sad_8x4_buf, sad_8x8_buf, sad_row_idx_buf, rb_unp, cb_unp);
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
