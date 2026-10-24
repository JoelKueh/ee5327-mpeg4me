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
    logic stall;
    logic sad_8x8_valid;
    logic [1:0] cb_subblock_idx;
    logic [SW_IDX_W-1:0] sw_idx_8x8;
    logic [SAD_8X8_W-1:0] sad_8x8[WINDOW_SIZE];
    logic sad_16x8_valid;
    logic [SW_IDX_W-1:0] sw_idx_16x8;
    logic [SAD_16X8_W-1:0] sad_16x8[WINDOW_SIZE];
    logic sad_16x16_valid;
    logic [SW_IDX_W-1:0] sw_idx_16x16;
    logic [SAD_16X16_W-1:0] sad_16x16[WINDOW_SIZE];

    fs_combiner dut (.*);

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    task automatic drive_cycle(logic do_s, logic v, logic sb_idx, logic sw_idx, logic sad_8x8);
        sad_8x8_valid = v;
        cb_subblock_idx = sb_idx;
        sw_idx_8x8 = sw_idx;
        sad_8x8 = sad_8x8;

        if (do_s) begin
            stall = 1;
            @(posedge clk);
        end

        #0;
        @(posedge clk);
        #0;
    endtask

    task automatic drive_subblock(logic do_s, int sb_idx, sad_row_t sad_buf[32]);
        for (int i = 0; i < 32; i++) begin
            drive_cycle(0, 1, sb_idx, i, sad_buf[i]);
        end
    endtask

    task automatic drive_block(logic do_s, int sb_idx, sad_row_t sad_buf[4][32]);
        sad_row_t x_sad;
        for (int i = 0; i < 32; i++) x_sad[i] = 'x;
 
        for (int sb = 0; sb < 4; sb++) begin
            std::randomize(sad_buf);
            for (int row = 0; row < 39; row++) begin
                if (row < 32) begin
                    drive_subblock(0, 0, sad_buf[i]);
                end else begin
                    drive_cycle(0, 0, 'x, 'x, 'x, 'x);
                end
            end
        end
    endtask

    task automatic monitor_sads(sad_row_t sad_array);
        if (sad_16x8_valid) begin
        end

        if (sad_16x16_valid) begin
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
        stall           = '0;
        sad_8x8_valid   = '0;
        cb_subblock_idx = '0;
        sw_idx_8x8      = '0;
        for (int i = 0; i < WINDOW_SIZE; i++) sad_8x8[i] = '0;
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN

    `SVTEST(typical)
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
