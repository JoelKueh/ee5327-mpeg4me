// fs_computer_unit_test.sv
//
// svunit testbench for fs_computer (first-level 8x4 / 8x8 SAD computation).
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

    logic                              clk;
    logic                              bd_valid;
    logic [7:0][PEL_W-1:0]             cb;
    logic [WINDOW_SIZE+6:0][PEL_W-1:0] rb;
    logic [RB_ROW_IDX_W-1:0]           rb_row_idx;
    logic                              sad_valid;
    logic [SAD_8X4_W-1:0]              sad_8x4[2][WINDOW_SIZE];
    logic [SAD_8X8_W-1:0]              sad_8x8[WINDOW_SIZE];
    logic [SW_IDX_W-1:0]               sad_sw_idx;

    fs_computer dut (.*);

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ------------------------------------------------------------------
    // Stimulus & Recording Tasks
    // ------------------------------------------------------------------

    task automatic record_cycle(
        inout logic [SAD_8X4_W-1:0] sad_8x4_buf[$][2][WINDOW_SIZE],
        inout logic [SAD_8X8_W-1:0] sad_8x8_buf[$][WINDOW_SIZE],
        inout logic [SW_IDX_W-1:0]  sad_sw_idx_buf[$],
        inout logic                 sad_valid_buf[$]
    );
        sad_8x4_buf.push_back(sad_8x4);
        sad_8x8_buf.push_back(sad_8x8);
        sad_sw_idx_buf.push_back(sad_sw_idx);
        sad_valid_buf.push_back(sad_valid);
    endtask

    task automatic drive_cycle(
        inout logic [SAD_8X4_W-1:0] sad_8x4_buf[$][2][WINDOW_SIZE],
        inout logic [SAD_8X8_W-1:0] sad_8x8_buf[$][WINDOW_SIZE],
        inout logic [SW_IDX_W-1:0]  sad_sw_idx_buf[$],
        inout logic                 sad_valid_buf[$],
        input int row_idx, logic s, rb_row_t r, cb_row_t b, bit record
    );
        bd_valid   = !s;
        rb         = r;
        cb         = b;
        rb_row_idx = row_idx[RB_ROW_IDX_W-1:0];
        #1;
        if (record) record_cycle(sad_8x4_buf, sad_8x8_buf, sad_sw_idx_buf, sad_valid_buf);
        @(posedge clk);
        #0;
    endtask

    // Drives one sub-block (rb_buf.size() rows, typically 39) without wrapping rb_row_idx past 38.
    // If flush == 1, appends idle cycles (bd_valid = 0, rb_row_idx = 0) to flush the pipeline.
    task automatic drive_subblock_stream(
        inout logic [SAD_8X4_W-1:0] sad_8x4_buf[$][2][WINDOW_SIZE],
        inout logic [SAD_8X8_W-1:0] sad_8x8_buf[$][WINDOW_SIZE],
        inout logic [SW_IDX_W-1:0]  sad_sw_idx_buf[$],
        inout logic                 sad_valid_buf[$],
        input rb_row_t rb_buf[$],
        input cb_row_t cb_buf[$],
        input logic    do_stall,
        input logic    flush = 1
    );
        for (int i = 0; i < rb_buf.size(); i++) begin
            // Insert 1 to 3 consecutive stall cycles (recording outputs during stalls too!)
            if (do_stall && $urandom_range(1, 100) > 70) begin
                int num_stalls = $urandom_range(1, 3);
                for (int s = 0; s < num_stalls; s++) begin
                    // During a stall in fs_control, rb_row_idx holds its current value i
                    drive_cycle(sad_8x4_buf, sad_8x8_buf, sad_sw_idx_buf, sad_valid_buf,
                                i, 1, 'x, 'x, 1);
                end
            end

            if (i < 8) begin
                drive_cycle(sad_8x4_buf, sad_8x8_buf, sad_sw_idx_buf, sad_valid_buf,
                            i, 0, rb_buf[i], cb_buf[i], 1);
            end else begin
                drive_cycle(sad_8x4_buf, sad_8x8_buf, sad_sw_idx_buf, sad_valid_buf,
                            i, 0, rb_buf[i], 'x, 1);
            end
        end

        // Realistic flush: after row 38, fs_control wraps rb_row_idx to 0 and either
        // stalls (bd_valid = 0) or starts the next sub-block. Never drives rb_row_idx = 39!
        if (flush) begin
            for (int i = 0; i < 6; i++) begin
                drive_cycle(sad_8x4_buf, sad_8x8_buf, sad_sw_idx_buf, sad_valid_buf,
                            0, 1, 'x, 'x, 1);
            end
        end
    endtask

    // ------------------------------------------------------------------
    // Checker Tasks
    // ------------------------------------------------------------------

    // Checks a single sub-block's worth of outputs (verifies count, sw_idx sequence, and SAD values)
    task automatic check(
        input logic [SAD_8X4_W-1:0] sad_8x4_buf[$][2][WINDOW_SIZE],
        input logic [SAD_8X8_W-1:0] sad_8x8_buf[$][WINDOW_SIZE],
        input logic [SW_IDX_W-1:0]  sad_sw_idx_buf[$],
        input logic                 sad_valid_buf[$],
        input pel_arr_unpacked_t    rb_unp,
        input pel_arr_unpacked_t    cb_unp,
        input int                   exp_valid_count = 32
    );
        int sad_buf;
        int valid_seen = 0;

        for (int i = 0; i < sad_valid_buf.size(); i++) begin
            if (!sad_valid_buf[i])
                continue;

            // 1. Verify sad_sw_idx increments strictly in order: 0, 1, 2, ..., exp_valid_count-1
            `FAIL_UNLESS_LOG(
                int'(sad_sw_idx_buf[i]) === valid_seen,
                $sformatf("Cycle %0d: sad_sw_idx out of order! act=%0d (0x%0h), exp=%0d (0x%0h)",
                          i, sad_sw_idx_buf[i], sad_sw_idx_buf[i], valid_seen, valid_seen)
            );

            // 2. Verify all 32 horizontal search positions (j = 0..WINDOW_SIZE-1) for this sw_idx
            for (int j = 0; j < WINDOW_SIZE; j++) begin
                sad_buf = fs_tb_common_pkg::sad_reference(0, 0, sad_sw_idx_buf[i], j, 8, 4, rb_unp, cb_unp);
                `FAIL_UNLESS_LOG(
                    sad_buf === sad_8x4_buf[i][0][j],
                    $sformatf("sw_idx=0x%0h col=0x%0h 8x4[0]: act=0x%0h exp=0x%0h",
                              sad_sw_idx_buf[i], j, sad_8x4_buf[i][0][j], sad_buf)
                );

                sad_buf = fs_tb_common_pkg::sad_reference(0, 4, sad_sw_idx_buf[i], j+4, 8, 4, rb_unp, cb_unp);
                `FAIL_UNLESS_LOG(
                    sad_buf === sad_8x4_buf[i][1][j],
                    $sformatf("sw_idx=0x%0h col=0x%0h 8x4[1]: act=0x%0h exp=0x%0h",
                              sad_sw_idx_buf[i], j, sad_8x4_buf[i][1][j], sad_buf)
                );

                sad_buf = fs_tb_common_pkg::sad_reference(0, 0, sad_sw_idx_buf[i], j, 8, 8, rb_unp, cb_unp);
                `FAIL_UNLESS_LOG(
                    sad_buf === sad_8x8_buf[i][j],
                    $sformatf("sw_idx=0x%0h col=0x%0h 8x8: act=0x%0h exp=0x%0h",
                              sad_sw_idx_buf[i], j, sad_8x8_buf[i][j], sad_buf)
                );
            end

            valid_seen++;
        end

        // 3. Ensure the exact expected number of valid output rows were produced (no dropped row 31!)
        `FAIL_UNLESS_LOG(
            valid_seen === exp_valid_count,
            $sformatf("Total sad_valid count mismatch! act=%0d, exp=%0d", valid_seen, exp_valid_count)
        );
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
        bd_valid   = '0;
        rb         = '0;
        rb_row_idx = '0;
        cb         = '0;
        // Flush pipeline state before each test
        repeat (4) @(posedge clk);
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
        logic [SW_IDX_W-1:0]  sad_sw_idx_buf[$];
        logic                 sad_valid_buf[$];

        for (int i = 0; i < 16; i++) rb_buf.push_back('0);
        for (int i = 0; i < 8; i++)  cb_buf.push_back('1);
        rb_unp = fs_tb_common_pkg::pel_unpack#(16, WINDOW_SIZE+7)::f(rb_buf);
        cb_unp = fs_tb_common_pkg::pel_unpack#(8, 8)::f(cb_buf);

        drive_cycle(sad_8x4_buf, sad_8x8_buf, sad_sw_idx_buf, sad_valid_buf, 0, 0, 'x, 'x, 0);
        drive_cycle(sad_8x4_buf, sad_8x8_buf, sad_sw_idx_buf, sad_valid_buf, 1, 0, 'x, 'x, 0);
        drive_subblock_stream(sad_8x4_buf, sad_8x8_buf, sad_sw_idx_buf, sad_valid_buf, rb_buf, cb_buf, 0, 1);

        check(sad_8x4_buf, sad_8x8_buf, sad_sw_idx_buf, sad_valid_buf, rb_unp, cb_unp, 9);
    `SVTEST_END

    `SVTEST(min_sad)
        rb_row_t rb_buf[$];
        cb_row_t cb_buf[$];
        pel_arr_unpacked_t rb_unp;
        pel_arr_unpacked_t cb_unp;

        logic [SAD_8X4_W-1:0] sad_8x4_buf[$][2][WINDOW_SIZE];
        logic [SAD_8X8_W-1:0] sad_8x8_buf[$][WINDOW_SIZE];
        logic [SW_IDX_W-1:0]  sad_sw_idx_buf[$];
        logic                 sad_valid_buf[$];

        for (int i = 0; i < 16; i++) rb_buf.push_back('1);
        for (int i = 0; i < 8; i++)  cb_buf.push_back('1);
        rb_unp = fs_tb_common_pkg::pel_unpack#(16, WINDOW_SIZE+7)::f(rb_buf);
        cb_unp = fs_tb_common_pkg::pel_unpack#(8, 8)::f(cb_buf);

        drive_subblock_stream(sad_8x4_buf, sad_8x8_buf, sad_sw_idx_buf, sad_valid_buf, rb_buf, cb_buf, 0, 1);

        check(sad_8x4_buf, sad_8x8_buf, sad_sw_idx_buf, sad_valid_buf, rb_unp, cb_unp, 9);
    `SVTEST_END

    `SVTEST(max_sad)
        rb_row_t rb_buf[$];
        cb_row_t cb_buf[$];
        pel_arr_unpacked_t rb_unp;
        pel_arr_unpacked_t cb_unp;

        logic [SAD_8X4_W-1:0] sad_8x4_buf[$][2][WINDOW_SIZE];
        logic [SAD_8X8_W-1:0] sad_8x8_buf[$][WINDOW_SIZE];
        logic [SW_IDX_W-1:0]  sad_sw_idx_buf[$];
        logic                 sad_valid_buf[$];

        for (int i = 0; i < 16; i++) rb_buf.push_back('1);
        for (int i = 0; i < 8; i++)  cb_buf.push_back('0);
        rb_unp = fs_tb_common_pkg::pel_unpack#(16, WINDOW_SIZE+7)::f(rb_buf);
        cb_unp = fs_tb_common_pkg::pel_unpack#(8, 8)::f(cb_buf);

        drive_subblock_stream(sad_8x4_buf, sad_8x8_buf, sad_sw_idx_buf, sad_valid_buf, rb_buf, cb_buf, 0, 1);

        check(sad_8x4_buf, sad_8x8_buf, sad_sw_idx_buf, sad_valid_buf, rb_unp, cb_unp, 9);
    `SVTEST_END

    `SVTEST(typical)
        rb_row_t rb_buf[$];
        cb_row_t cb_buf[$];
        pel_arr_unpacked_t rb_unp;
        pel_arr_unpacked_t cb_unp;

        logic [SAD_8X4_W-1:0] sad_8x4_buf[$][2][WINDOW_SIZE];
        logic [SAD_8X8_W-1:0] sad_8x8_buf[$][WINDOW_SIZE];
        logic [SW_IDX_W-1:0]  sad_sw_idx_buf[$];
        logic                 sad_valid_buf[$];

        std::randomize(rb_buf) with { rb_buf.size == 39; };
        std::randomize(cb_buf) with { cb_buf.size == 8; };
        rb_unp = fs_tb_common_pkg::pel_unpack#(39, WINDOW_SIZE+7)::f(rb_buf);
        cb_unp = fs_tb_common_pkg::pel_unpack#(8, 8)::f(cb_buf);

        drive_subblock_stream(sad_8x4_buf, sad_8x8_buf, sad_sw_idx_buf, sad_valid_buf, rb_buf, cb_buf, 0, 1);

        check(sad_8x4_buf, sad_8x8_buf, sad_sw_idx_buf, sad_valid_buf, rb_unp, cb_unp, 32);
    `SVTEST_END

    `SVTEST(typical_stall)
        rb_row_t rb_buf[$];
        cb_row_t cb_buf[$];
        pel_arr_unpacked_t rb_unp;
        pel_arr_unpacked_t cb_unp;

        logic [SAD_8X4_W-1:0] sad_8x4_buf[$][2][WINDOW_SIZE];
        logic [SAD_8X8_W-1:0] sad_8x8_buf[$][WINDOW_SIZE];
        logic [SW_IDX_W-1:0]  sad_sw_idx_buf[$];
        logic                 sad_valid_buf[$];

        std::randomize(rb_buf) with { rb_buf.size == 39; };
        std::randomize(cb_buf) with { cb_buf.size == 8; };
        rb_unp = fs_tb_common_pkg::pel_unpack#(39, WINDOW_SIZE+7)::f(rb_buf);
        cb_unp = fs_tb_common_pkg::pel_unpack#(8, 8)::f(cb_buf);

        drive_subblock_stream(sad_8x4_buf, sad_8x8_buf, sad_sw_idx_buf, sad_valid_buf, rb_buf, cb_buf, 1, 1);

        check(sad_8x4_buf, sad_8x8_buf, sad_sw_idx_buf, sad_valid_buf, rb_unp, cb_unp, 32);
    `SVTEST_END

    // NEW TEST: Streams 4 consecutive sub-blocks back-to-back (rb_row_idx wraps 38 -> 0 immediately)
    // exactly as fs_control drives fs_computer during a 16x16 macroblock.
    `SVTEST(back_to_back_subblocks)
        rb_row_t tmp_rb[$];
        cb_row_t tmp_cb[$];
        pel_arr_unpacked_t rb_unp[4];
        pel_arr_unpacked_t cb_unp[4];

        logic [SAD_8X4_W-1:0] sad_8x4_buf[$][2][WINDOW_SIZE];
        logic [SAD_8X8_W-1:0] sad_8x8_buf[$][WINDOW_SIZE];
        logic [SW_IDX_W-1:0]  sad_sw_idx_buf[$];
        logic                 sad_valid_buf[$];

        for (int sb = 0; sb < 4; sb++) begin
            tmp_rb.delete();
            tmp_cb.delete();
            std::randomize(tmp_rb) with { tmp_rb.size == 39; };
            std::randomize(tmp_cb) with { tmp_cb.size == 8; };

            rb_unp[sb] = fs_tb_common_pkg::pel_unpack#(39, WINDOW_SIZE+7)::f(tmp_rb);
            cb_unp[sb] = fs_tb_common_pkg::pel_unpack#(8, 8)::f(tmp_cb);

            // flush = 0 for sb 0..2 (continuous 38 -> 0 wrap), flush = 1 on last sub-block (sb == 3)
            drive_subblock_stream(sad_8x4_buf, sad_8x8_buf, sad_sw_idx_buf, sad_valid_buf,
                                  tmp_rb, tmp_cb, 0, (sb == 3));
        end

        // Check all 4 sub-blocks (4 * 32 = 128 valid rows total)
        begin
            int valid_cnt = 0;
            for (int i = 0; i < sad_valid_buf.size(); i++) begin
                int sb;
                int exp_sw;
                int sad_buf;

                if (!sad_valid_buf[i]) continue;

                sb     = valid_cnt / 32;
                exp_sw = valid_cnt % 32;

                `FAIL_UNLESS_LOG(
                    int'(sad_sw_idx_buf[i]) === exp_sw,
                    $sformatf("SB %0d: sad_sw_idx mismatch! act=0x%0h, exp=0x%0h",
                              sb, sad_sw_idx_buf[i], exp_sw)
                );

                for (int j = 0; j < WINDOW_SIZE; j++) begin
                    sad_buf = fs_tb_common_pkg::sad_reference(0, 0, exp_sw, j, 8, 4, rb_unp[sb], cb_unp[sb]);
                    `FAIL_UNLESS_LOG(
                        sad_buf === sad_8x4_buf[i][0][j],
                        $sformatf("SB %0d sw_idx=0x%0h col=0x%0h 8x4[0]: act=0x%0h exp=0x%0h",
                                  sb, exp_sw, j, sad_8x4_buf[i][0][j], sad_buf)
                    );

                    sad_buf = fs_tb_common_pkg::sad_reference(0, 4, exp_sw, j+4, 8, 4, rb_unp[sb], cb_unp[sb]);
                    `FAIL_UNLESS_LOG(
                        sad_buf === sad_8x4_buf[i][1][j],
                        $sformatf("SB %0d sw_idx=0x%0h col=0x%0h 8x4[1]: act=0x%0h exp=0x%0h",
                                  sb, exp_sw, j, sad_8x4_buf[i][1][j], sad_buf)
                    );

                    sad_buf = fs_tb_common_pkg::sad_reference(0, 0, exp_sw, j, 8, 8, rb_unp[sb], cb_unp[sb]);
                    `FAIL_UNLESS_LOG(
                        sad_buf === sad_8x8_buf[i][j],
                        $sformatf("SB %0d sw_idx=0x%0h col=0x%0h 8x8: act=0x%0h exp=0x%0h",
                                  sb, exp_sw, j, sad_8x8_buf[i][j], sad_buf)
                    );
                end

                valid_cnt++;
            end

            `FAIL_UNLESS_LOG(
                valid_cnt === 128,
                $sformatf("Expected 128 valid rows across 4 sub-blocks, got %0d", valid_cnt)
            );
        end
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
