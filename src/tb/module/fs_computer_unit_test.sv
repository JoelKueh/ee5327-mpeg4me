// fs_computer_unit_test.sv
//
// svunit testbench for fs_computer (two-pass 4x4 / 4x8 / 8x4 / 8x8 SAD computation).
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

    logic                               clk;
    logic                               bd_valid;
    logic                               upper_half;
    logic [7:0][PEL_W-1:0]              cb;
    logic [WINDOW_SIZE+6:0][PEL_W-1:0] rb;
    logic [RB_ROW_IDX_W-1:0]           rb_row_idx;

    logic                               sad_4x_valid;
    logic [SAD_4X4_W-1:0]               sad_4x4[2][WINDOW_SIZE];
    logic [SAD_8X4_W-1:0]               sad_4x8[WINDOW_SIZE];

    logic                               sad_8x_valid;
    logic [SAD_8X4_W-1:0]               sad_8x4[2][WINDOW_SIZE];
    logic [SAD_8X8_W-1:0]               sad_8x8[WINDOW_SIZE];
    logic [SW_IDX_W-1:0]                sad_sw_idx;

    fs_computer dut (.*);

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ------------------------------------------------------------------
    // Stimulus & Recording Structures / Tasks
    // ------------------------------------------------------------------

    typedef struct {
        logic [SAD_4X4_W-1:0] sad_4x4[2][WINDOW_SIZE];
        logic [SAD_8X4_W-1:0] sad_4x8[WINDOW_SIZE];
        logic [SAD_8X4_W-1:0] sad_8x4[2][WINDOW_SIZE];
        logic [SAD_8X8_W-1:0] sad_8x8[WINDOW_SIZE];
        logic [SW_IDX_W-1:0]  sad_sw_idx;
        logic                 sad_4x_valid;
        logic                 sad_8x_valid;
    } sad_record_t;

    typedef sad_record_t sad_record_q_t[$];

    task automatic record_cycle(
        inout sad_record_q_t rec_buf
    );
        sad_record_t rec;
        rec.sad_4x4      = sad_4x4;
        rec.sad_4x8      = sad_4x8;
        rec.sad_8x4      = sad_8x4;
        rec.sad_8x8      = sad_8x8;
        rec.sad_sw_idx   = sad_sw_idx;
        rec.sad_4x_valid = sad_4x_valid;
        rec.sad_8x_valid = sad_8x_valid;
        rec_buf.push_back(rec);
    endtask

    task automatic drive_cycle(
        inout sad_record_q_t rec_buf,
        input int row_idx,
        input logic s,
        input logic up_half,
        input rb_row_t r,
        input cb_row_t b,
        input bit record
    );
        bd_valid   = !s;
        upper_half = up_half;
        rb         = r;
        cb         = b;
        rb_row_idx = row_idx[RB_ROW_IDX_W-1:0];
        #1;
        // $display("valid=0x%0h 4x4=0x%0h", sad_4x_valid, sad_4x4[0][0]);
        if (record) record_cycle(rec_buf);
        @(posedge clk);
        #0;
    endtask

    // Drives a single half-subblock pass (either upper_half = 1 or upper_half = 0).
    // Loads the 4 CB rows during i = 0..3 while streaming RB rows.
    task automatic drive_half_pass(
        inout sad_record_q_t rec_buf,
        input rb_row_t rb_pass_buf[$],
        input cb_row_t cb_pass_buf[$], // 4 rows for this half
        input logic    up_half,
        input logic    do_stall
    );
        for (int i = 0; i < rb_pass_buf.size(); i++) begin
            if (do_stall && $urandom_range(1, 100) > 70) begin
                int num_stalls = $urandom_range(1, 3);
                for (int s = 0; s < num_stalls; s++) begin
                    drive_cycle(rec_buf, i, 1, up_half, 'x, 'x, 1);
                end
            end

            if (i < 4) begin
                drive_cycle(rec_buf, i, 0, up_half, rb_pass_buf[i], cb_pass_buf[i], 1);
            end else begin
                drive_cycle(rec_buf, i, 0, up_half, rb_pass_buf[i], 'x, 1);
            end
        end
    endtask

    // Drives one complete 8x8 sub-block in two passes:
    //   Pass 1 (upper_half = 1): CB rows 0..3, RB rows 0..(N-5)
    //   Pass 2 (upper_half = 0): CB rows 4..7, RB rows 4..(N-1)
    // Note: If fs_control still streams all N rows (e.g. 39) each pass, adjust
    // the slice indices below to match your controller's RB addressing.
    task automatic drive_subblock_stream(
        inout sad_record_q_t rec_buf,
        input rb_row_t rb_buf[$],
        input cb_row_t cb_buf[$],
        input logic    do_stall,
        input logic    flush = 1
    );
        rb_row_t rb_upper[$];
        rb_row_t rb_lower[$];
        cb_row_t cb_upper[$];
        cb_row_t cb_lower[$];

        // Extract the 4 CB rows for upper (0..3) and lower (4..7) halves
        for (int i = 0; i < 4; i++) begin
            cb_upper.push_back(cb_buf[i]);
            cb_lower.push_back(cb_buf[i + 4]);
        end

        // Upper half compares CB[0:3] against RB[sw_idx + 0 .. sw_idx + 3]
        // Lower half compares CB[4:7] against RB[sw_idx + 4 .. sw_idx + 7]
        for (int i = 0; i < rb_buf.size() - 4; i++) begin
            rb_upper.push_back(rb_buf[i]);
            rb_lower.push_back(rb_buf[i + 4]);
        end

        // Pass 1: Upper half (stores 4x4 SADs into RAM A & RAM B)
        drive_half_pass(rec_buf, rb_upper, cb_upper, 1'b1, do_stall);

        // Pass 2: Lower half (reads upper 4x4 SADs from RAM, computes 8x4 & 8x8)
        drive_half_pass(rec_buf, rb_lower, cb_lower, 1'b0, do_stall);

        // Flush the 6-cycle pipeline at the end if requested
        if (flush) begin
            for (int i = 0; i < 6; i++) begin
                drive_cycle(rec_buf, 0, 0, 1'b0, 'x, 'x, 1);
            end
        end
    endtask

    // ------------------------------------------------------------------
    // Checker Tasks
    // ------------------------------------------------------------------

    // Verifies a single 8x8 sub-block's two-pass outputs:
    // - 2 * exp_valid_count total sad_4x_valid cycles (upper pass + lower pass)
    // - 1 * exp_valid_count total sad_8x_valid cycles (lower pass only)
    task automatic check(
        input sad_record_q_t     rec_buf,
        input pel_arr_unpacked_t rb_unp,
        input pel_arr_unpacked_t cb_unp,
        input int                exp_valid_count = 32
    );
        int sad_exp;
        int valid_4x_seen = 0;
        int valid_8x_seen = 0;

        for (int i = 0; i < rec_buf.size(); i++) begin
            //$display("valid=0x%0h 4x4=0x%0h", rec_buf[i].sad_4x_valid, rec_buf[i].sad_4x4[0][0]);

            // ----------------------------------------------------------
            // Check 4x4 and 4x8 outputs (valid during BOTH halves)
            // ----------------------------------------------------------
            if (rec_buf[i].sad_4x_valid) begin
                int pass_idx = valid_4x_seen / exp_valid_count; // 0 = upper_half, 1 = lower_half
                int exp_sw   = valid_4x_seen % exp_valid_count;
                int row_off  = (pass_idx == 0) ? 0 : 4;

                `FAIL_UNLESS_LOG(
                    int'(rec_buf[i].sad_sw_idx) === exp_sw,
                    $sformatf("Cycle %0d (4x pass %0d): sad_sw_idx out of order! act=%0d, exp=%0d",
                              i, pass_idx, rec_buf[i].sad_sw_idx, exp_sw)
                );

                for (int j = 0; j < WINDOW_SIZE; j++) begin
                    // Left 4x4 (cols 0..3)
                    sad_exp = fs_tb_common_pkg::sad_reference(
                        row_off, 0, exp_sw + row_off, j, 4, 4, rb_unp, cb_unp
                    );
                    `FAIL_UNLESS_LOG(
                        sad_exp === rec_buf[i].sad_4x4[0][j],
                        $sformatf("pass=%0d sw_idx=0x%0h col=0x%0h 4x4[0]: act=0x%0h exp=0x%0h",
                                  pass_idx, exp_sw, j, rec_buf[i].sad_4x4[0][j], sad_exp)
                    );

                    // Right 4x4 (cols 4..7)
                    sad_exp = fs_tb_common_pkg::sad_reference(
                        row_off, 4, exp_sw + row_off, j + 4, 4, 4, rb_unp, cb_unp
                    );
                    `FAIL_UNLESS_LOG(
                        sad_exp === rec_buf[i].sad_4x4[1][j],
                        $sformatf("pass=%0d sw_idx=0x%0h col=0x%0h 4x4[1]: act=0x%0h exp=0x%0h",
                                  pass_idx, exp_sw, j, rec_buf[i].sad_4x4[1][j], sad_exp)
                    );

                    // Combined 4x8 (4 rows tall x 8 cols wide)
                    sad_exp = fs_tb_common_pkg::sad_reference(
                        row_off, 0, exp_sw + row_off, j, 4, 8, rb_unp, cb_unp
                    );
                    `FAIL_UNLESS_LOG(
                        sad_exp === rec_buf[i].sad_4x8[j],
                        $sformatf("pass=%0d sw_idx=0x%0h col=0x%0h 4x8: act=0x%0h exp=0x%0h",
                                  pass_idx, exp_sw, j, rec_buf[i].sad_4x8[j], sad_exp)
                    );
                end

                valid_4x_seen++;
            end

            // ----------------------------------------------------------
            // Check 8x4 and 8x8 outputs (valid ONLY during lower half)
            // ----------------------------------------------------------
            if (rec_buf[i].sad_8x_valid) begin
                int exp_sw = valid_8x_seen;

                `FAIL_UNLESS_LOG(
                    int'(rec_buf[i].sad_sw_idx) === exp_sw,
                    $sformatf("Cycle %0d (8x): sad_sw_idx out of order! act=%0d, exp=%0d",
                              i, rec_buf[i].sad_sw_idx, exp_sw)
                );

                for (int j = 0; j < WINDOW_SIZE; j++) begin
                    // Left 8x4 (8 rows tall x 4 cols wide, cols 0..3)
                    sad_exp = fs_tb_common_pkg::sad_reference(
                        0, 0, exp_sw, j, 8, 4, rb_unp, cb_unp
                    );
                    `FAIL_UNLESS_LOG(
                        sad_exp === rec_buf[i].sad_8x4[0][j],
                        $sformatf("sw_idx=0x%0h col=0x%0h 8x4[0]: act=0x%0h exp=0x%0h",
                                  exp_sw, j, rec_buf[i].sad_8x4[0][j], sad_exp)
                    );

                    // Right 8x4 (8 rows tall x 4 cols wide, cols 4..7)
                    sad_exp = fs_tb_common_pkg::sad_reference(
                        0, 4, exp_sw, j + 4, 8, 4, rb_unp, cb_unp
                    );
                    `FAIL_UNLESS_LOG(
                        sad_exp === rec_buf[i].sad_8x4[1][j],
                        $sformatf("sw_idx=0x%0h col=0x%0h 8x4[1]: act=0x%0h exp=0x%0h",
                                  exp_sw, j, rec_buf[i].sad_8x4[1][j], sad_exp)
                    );

                    // Full 8x8
                    sad_exp = fs_tb_common_pkg::sad_reference(
                        0, 0, exp_sw, j, 8, 8, rb_unp, cb_unp
                    );
                    `FAIL_UNLESS_LOG(
                        sad_exp === rec_buf[i].sad_8x8[j],
                        $sformatf("sw_idx=0x%0h col=0x%0h 8x8: act=0x%0h exp=0x%0h",
                                  exp_sw, j, rec_buf[i].sad_8x8[j], sad_exp)
                    );
                end

                valid_8x_seen++;
            end
        end

        `FAIL_UNLESS_LOG(
            valid_4x_seen === 2 * exp_valid_count,
            $sformatf("Total sad_4x_valid count mismatch! act=%0d, exp=%0d",
                      valid_4x_seen, 2 * exp_valid_count)
        );

        `FAIL_UNLESS_LOG(
            valid_8x_seen === exp_valid_count,
            $sformatf("Total sad_8x_valid count mismatch! act=%0d, exp=%0d",
                      valid_8x_seen, exp_valid_count)
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
        upper_half = '0;
        rb         = '0;
        rb_row_idx = '0;
        cb         = '0;
        // Flush pipeline state (6 cycles) before each test
        repeat (6) @(posedge clk);
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
        sad_record_q_t rec_buf;

        for (int i = 0; i < 16; i++) rb_buf.push_back('0);
        for (int i = 0; i < 8; i++)  cb_buf.push_back('1);
        rb_unp = fs_tb_common_pkg::pel_unpack#(16, WINDOW_SIZE+7)::f(rb_buf);
        cb_unp = fs_tb_common_pkg::pel_unpack#(8, 8)::f(cb_buf);

        drive_cycle(rec_buf, 0, 0, 1'b1, 'x, 'x, 0);
        drive_cycle(rec_buf, 1, 0, 1'b1, 'x, 'x, 0);
        drive_subblock_stream(rec_buf, rb_buf, cb_buf, 0, 1);

        check(rec_buf, rb_unp, cb_unp, 9);
    `SVTEST_END

    `SVTEST(min_sad)
        rb_row_t rb_buf[$];
        cb_row_t cb_buf[$];
        pel_arr_unpacked_t rb_unp;
        pel_arr_unpacked_t cb_unp;
        sad_record_q_t rec_buf;

        for (int i = 0; i < 16; i++) rb_buf.push_back('1);
        for (int i = 0; i < 8; i++)  cb_buf.push_back('1);
        rb_unp = fs_tb_common_pkg::pel_unpack#(16, WINDOW_SIZE+7)::f(rb_buf);
        cb_unp = fs_tb_common_pkg::pel_unpack#(8, 8)::f(cb_buf);

        drive_subblock_stream(rec_buf, rb_buf, cb_buf, 0, 1);

        check(rec_buf, rb_unp, cb_unp, 9);
    `SVTEST_END

    `SVTEST(max_sad)
        rb_row_t rb_buf[$];
        cb_row_t cb_buf[$];
        pel_arr_unpacked_t rb_unp;
        pel_arr_unpacked_t cb_unp;
        sad_record_q_t rec_buf;

        for (int i = 0; i < 16; i++) rb_buf.push_back('1);
        for (int i = 0; i < 8; i++)  cb_buf.push_back('0);
        rb_unp = fs_tb_common_pkg::pel_unpack#(16, WINDOW_SIZE+7)::f(rb_buf);
        cb_unp = fs_tb_common_pkg::pel_unpack#(8, 8)::f(cb_buf);

        drive_subblock_stream(rec_buf, rb_buf, cb_buf, 0, 1);

        check(rec_buf, rb_unp, cb_unp, 9);
    `SVTEST_END

    `SVTEST(typical)
        rb_row_t rb_buf[$];
        cb_row_t cb_buf[$];
        pel_arr_unpacked_t rb_unp;
        pel_arr_unpacked_t cb_unp;
        sad_record_q_t rec_buf;

        std::randomize(rb_buf) with { rb_buf.size == 39; };
        std::randomize(cb_buf) with { cb_buf.size == 8; };
        rb_unp = fs_tb_common_pkg::pel_unpack#(39, WINDOW_SIZE+7)::f(rb_buf);
        cb_unp = fs_tb_common_pkg::pel_unpack#(8, 8)::f(cb_buf);

        drive_subblock_stream(rec_buf, rb_buf, cb_buf, 0, 1);

        check(rec_buf, rb_unp, cb_unp, 32);
    `SVTEST_END

    //`SVTEST(typical_stall)
    //    rb_row_t rb_buf[$];
    //    cb_row_t cb_buf[$];
    //    pel_arr_unpacked_t rb_unp;
    //    pel_arr_unpacked_t cb_unp;
    //    sad_record_q_t rec_buf;

    //    std::randomize(rb_buf) with { rb_buf.size == 39; };
    //    std::randomize(cb_buf) with { cb_buf.size == 8; };
    //    rb_unp = fs_tb_common_pkg::pel_unpack#(39, WINDOW_SIZE+7)::f(rb_buf);
    //    cb_unp = fs_tb_common_pkg::pel_unpack#(8, 8)::f(cb_buf);

    //    drive_subblock_stream(rec_buf, rb_buf, cb_buf, 1, 1);

    //    check(rec_buf, rb_unp, cb_unp, 32);
    //`SVTEST_END

    `SVTEST(back_to_back_subblocks)
        rb_row_t tmp_rb[$];
        cb_row_t tmp_cb[$];
        pel_arr_unpacked_t rb_unp[4];
        pel_arr_unpacked_t cb_unp[4];
        sad_record_q_t rec_buf;

        for (int sb = 0; sb < 4; sb++) begin
            tmp_rb.delete();
            tmp_cb.delete();
            std::randomize(tmp_rb) with { tmp_rb.size == 39; };
            std::randomize(tmp_cb) with { tmp_cb.size == 8; };

            rb_unp[sb] = fs_tb_common_pkg::pel_unpack#(39, WINDOW_SIZE+7)::f(tmp_rb);
            cb_unp[sb] = fs_tb_common_pkg::pel_unpack#(8, 8)::f(tmp_cb);

            // flush = 0 for sb 0..2, flush = 1 on last sub-block (sb == 3)
            drive_subblock_stream(rec_buf, tmp_rb, tmp_cb, 0, (sb == 3));
        end

        // Check all 4 sub-blocks:
        // - 4 * 64 = 256 valid 4x rows (32 upper + 32 lower per sub-block)
        // - 4 * 32 = 128 valid 8x rows (32 lower per sub-block)
        begin
            int valid_4x_cnt = 0;
            int valid_8x_cnt = 0;

            for (int i = 0; i < rec_buf.size(); i++) begin
                int sad_exp;

                if (rec_buf[i].sad_4x_valid) begin
                    int sb       = valid_4x_cnt / 64;
                    int pass_idx = (valid_4x_cnt % 64) / 32;
                    int exp_sw   = valid_4x_cnt % 32;
                    int row_off  = (pass_idx == 0) ? 0 : 4;

                    `FAIL_UNLESS_LOG(
                        int'(rec_buf[i].sad_sw_idx) === exp_sw,
                        $sformatf("SB %0d (4x pass %0d): sad_sw_idx mismatch! act=0x%0h, exp=0x%0h",
                                  sb, pass_idx, rec_buf[i].sad_sw_idx, exp_sw)
                    );

                    for (int j = 0; j < WINDOW_SIZE; j++) begin
                        sad_exp = fs_tb_common_pkg::sad_reference(
                            row_off, 0, exp_sw + row_off, j, 4, 4, rb_unp[sb], cb_unp[sb]
                        );
                        `FAIL_UNLESS_LOG(
                            sad_exp === rec_buf[i].sad_4x4[0][j],
                            $sformatf("SB %0d pass=%0d sw_idx=0x%0h col=0x%0h 4x4[0]: act=0x%0h exp=0x%0h",
                                      sb, pass_idx, exp_sw, j, rec_buf[i].sad_4x4[0][j], sad_exp)
                        );

                        sad_exp = fs_tb_common_pkg::sad_reference(
                            row_off, 4, exp_sw + row_off, j + 4, 4, 4, rb_unp[sb], cb_unp[sb]
                        );
                        `FAIL_UNLESS_LOG(
                            sad_exp === rec_buf[i].sad_4x4[1][j],
                            $sformatf("SB %0d pass=%0d sw_idx=0x%0h col=0x%0h 4x4[1]: act=0x%0h exp=0x%0h",
                                      sb, pass_idx, exp_sw, j, rec_buf[i].sad_4x4[1][j], sad_exp)
                        );

                        sad_exp = fs_tb_common_pkg::sad_reference(
                            row_off, 0, exp_sw + row_off, j, 4, 8, rb_unp[sb], cb_unp[sb]
                        );
                        `FAIL_UNLESS_LOG(
                            sad_exp === rec_buf[i].sad_4x8[j],
                            $sformatf("SB %0d pass=%0d sw_idx=0x%0h col=0x%0h 4x8: act=0x%0h exp=0x%0h",
                                      sb, pass_idx, exp_sw, j, rec_buf[i].sad_4x8[j], sad_exp)
                        );
                    end

                    valid_4x_cnt++;
                end

                if (rec_buf[i].sad_8x_valid) begin
                    int sb     = valid_8x_cnt / 32;
                    int exp_sw = valid_8x_cnt % 32;

                    `FAIL_UNLESS_LOG(
                        int'(rec_buf[i].sad_sw_idx) === exp_sw,
                        $sformatf("SB %0d (8x): sad_sw_idx mismatch! act=0x%0h, exp=0x%0h",
                                  sb, rec_buf[i].sad_sw_idx, exp_sw)
                    );

                    for (int j = 0; j < WINDOW_SIZE; j++) begin
                        sad_exp = fs_tb_common_pkg::sad_reference(
                            0, 0, exp_sw, j, 8, 4, rb_unp[sb], cb_unp[sb]
                        );
                        `FAIL_UNLESS_LOG(
                            sad_exp === rec_buf[i].sad_8x4[0][j],
                            $sformatf("SB %0d sw_idx=0x%0h col=0x%0h 8x4[0]: act=0x%0h exp=0x%0h",
                                      sb, exp_sw, j, rec_buf[i].sad_8x4[0][j], sad_exp)
                        );

                        sad_exp = fs_tb_common_pkg::sad_reference(
                            0, 4, exp_sw, j + 4, 8, 4, rb_unp[sb], cb_unp[sb]
                        );
                        `FAIL_UNLESS_LOG(
                            sad_exp === rec_buf[i].sad_8x4[1][j],
                            $sformatf("SB %0d sw_idx=0x%0h col=0x%0h 8x4[1]: act=0x%0h exp=0x%0h",
                                      sb, exp_sw, j, rec_buf[i].sad_8x4[1][j], sad_exp)
                        );

                        sad_exp = fs_tb_common_pkg::sad_reference(
                            0, 0, exp_sw, j, 8, 8, rb_unp[sb], cb_unp[sb]
                        );
                        `FAIL_UNLESS_LOG(
                            sad_exp === rec_buf[i].sad_8x8[j],
                            $sformatf("SB %0d sw_idx=0x%0h col=0x%0h 8x8: act=0x%0h exp=0x%0h",
                                      sb, exp_sw, j, rec_buf[i].sad_8x8[j], sad_exp)
                        );
                    end

                    valid_8x_cnt++;
                end
            end

            `FAIL_UNLESS_LOG(
                valid_4x_cnt === 256,
                $sformatf("Expected 256 valid 4x rows across 4 sub-blocks, got %0d", valid_4x_cnt)
            );

            `FAIL_UNLESS_LOG(
                valid_8x_cnt === 128,
                $sformatf("Expected 128 valid 8x rows across 4 sub-blocks, got %0d", valid_8x_cnt)
            );
        end
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
