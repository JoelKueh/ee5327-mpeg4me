// fs_combiner_unit_test.sv
//
// svunit testbench for fs_combiner (8x8 -> 16x8 / 16x16 SAD combination).
//
`include "svunit_defines.svh"

module fs_combiner_unit_test;

    import me_pkg::*;
    import svunit_pkg::svunit_testcase;

    // ------------------------------------------------------------------
    // test wiring
    // ------------------------------------------------------------------

    typedef logic [SAD_8X8_W-1:0] sad_row_t[WINDOW_SIZE];
    typedef int sad_array_t[WINDOW_SIZE][WINDOW_SIZE];

    logic clk;
    logic clear_in;
    logic clear_out;

    logic sad_8x8_valid;
    logic sad_8x8_last;
    logic [1:0] sb_idx_8x8;
    logic [SW_IDX_W-1:0] sw_idx_8x8;
    logic [SAD_8X8_W-1:0] sad_8x8[WINDOW_SIZE];

    logic sad_16x8_valid;
    logic sad_16x8_last;
    comb_sad_id_t sad_16x8_id;
    logic [SW_IDX_W-1:0] sw_idx_16x8;
    logic [SAD_16X8_W-1:0] sad_16x8[WINDOW_SIZE];

    logic sad_16x16_valid;
    logic sad_16x16_last;
    logic [1:0] sb_idx_16x16;
    logic [SW_IDX_W-1:0] sw_idx_16x16;
    logic [SAD_16X16_W-1:0] sad_16x16[WINDOW_SIZE];

    fs_combiner dut (.*);

    initial begin
        clk = '0;
        forever #5 clk = ~clk;
    end

    task automatic drive_cycle(logic do_s, logic c, logic l, logic v, int sb_idx, int sw_idx,
                               sad_row_t sad_buf);
        clear_in = c;
        sad_8x8_valid = v;
        sad_8x8_last = l;
        sb_idx_8x8 = sb_idx;
        sw_idx_8x8 = sw_idx;
        sad_8x8 = sad_buf;

        if (do_s) begin
            // $display("STALL", sad_8x8);
            sad_8x8_valid = 0;
            @(posedge clk);
        end
        sad_8x8_valid = v;

        #0;
        // $display("8x8 - %p", sad_8x8);
        // $display("8x8 - %p", dut.sad_8x8_d);
        // $display("16x8 - %p", dut.sad_16x8_d);
        // $display("16x16 - %p", dut.sad_16x16_d);
        // $display("");
        @(posedge clk);
        #0;
    endtask

    task automatic drive_subblock(logic do_s, int sb_idx, sad_row_t sad_buf[32]);
        for (int i = 0; i < 32; i++) begin
            drive_cycle(0, 0, i == 31, 1, sb_idx, i, sad_buf[i]);
        end
    endtask

    task automatic drive_block(logic do_s, sad_row_t sad_buf[4][32]);
        sad_row_t x_sad;
        for (int i = 0; i < 32; i++) x_sad[i] = 'x;

        for (int sb = 0; sb < 4; sb++) begin
            drive_subblock(do_s, sb, sad_buf[sb]);
            for (int i = 32; i < 39; i++) begin
                drive_cycle(do_s, 0, 'x, 0, 'x, 'x, x_sad);
            end
        end
    endtask

    task automatic monitor_sads(sad_row_t sad_array[4][32]);
        int sad_buf_val;

        @(posedge clk);
        #0;
        if (sad_16x8_valid) begin
            for (int i = 0; i < WINDOW_SIZE; i++) begin
                case (sad_16x8_id)
                    SAD_LXS_0: sad_buf_val = sad_array[0][sw_idx_16x8][i] + sad_array[2][sw_idx_16x8][i];
                    SAD_LXS_1: sad_buf_val = sad_array[1][sw_idx_16x8][i] + sad_array[3][sw_idx_16x8][i];
                    SAD_SXL_0: sad_buf_val = sad_array[0][sw_idx_16x8][i] + sad_array[1][sw_idx_16x8][i];
                    SAD_SXL_1: sad_buf_val = sad_array[2][sw_idx_16x8][i] + sad_array[3][sw_idx_16x8][i];
                endcase

                `FAIL_UNLESS_LOG(sad_16x8[i] === sad_buf_val, $sformatf(
                    "id=%s i=0x%0h act=0x%0h exp=0x%0h", sad_16x8_id.name(), i, sad_16x8[i], sad_buf_val
                ));
            end
        end

        if (sad_16x16_valid) begin
            for (int i = 0; i < WINDOW_SIZE; i++) begin
                sad_buf_val = sad_array[0][sw_idx_16x16][i] + sad_array[1][sw_idx_16x16][i]
                    + sad_array[2][sw_idx_16x16][i] + sad_array[3][sw_idx_16x16][i];
                `FAIL_UNLESS_LOG(sad_16x16[i] === sad_buf_val, $sformatf(
                    "i=0x%0h act=0x%0h exp=0x%0h", i, sad_16x16[i], sad_buf_val
                ));
            end
        end
    endtask

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
        sad_8x8_valid   = '0;
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN

    `SVTEST(typical)
        sad_row_t sad_buf[4][32];
        sad_row_t x_sad;
        for (int i = 0; i < 32; i++) x_sad[i] = 'x;

        drive_cycle(0, 1, 'x, 0, 'x, 'x, x_sad);
        std::randomize(sad_buf);

        fork
            forever monitor_sads(sad_buf);
        join_none

        drive_block(0, sad_buf);
        drive_block(0, sad_buf);
        drive_block(0, sad_buf);
        drive_block(0, sad_buf);
        drive_block(0, sad_buf);

        #5 disable fork;
    `SVTEST_END

    `SVTEST(typical_stall)
        sad_row_t sad_buf[4][32];
        sad_row_t x_sad;
        for (int i = 0; i < 32; i++) x_sad[i] = 'x;

        drive_cycle(0, 1, 'x, 0, 'x, 'x, x_sad);
        std::randomize(sad_buf);

        fork
            forever monitor_sads(sad_buf);
        join_none

        drive_block(1, sad_buf);
        drive_block(1, sad_buf);
        drive_block(1, sad_buf);
        drive_block(1, sad_buf);
        drive_block(1, sad_buf);

        #5 disable fork;
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
