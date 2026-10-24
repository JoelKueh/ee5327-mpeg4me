// fs_comparator_unit_test.sv
//
// svunit testbench for fs_comparator (WINDOW_SIZE-wide MIN reduction).
//
// Skeleton - no behavioral coverage yet; add tests after the smoke test.
// The DUT is instantiated with the default SAD_RESULT_W=SAD_8X4_W; for the
// 8x8 / 16x8 / 16x16 comparators, re-instantiate with
// fs_comparator#(.SAD_RESULT_W(SAD_8X8_W)) dut(...) and so on.
// Run with: make test-module   (or make test for everything)
//
`include "svunit_defines.svh"

module fs_comparator_unit_test;

    import me_pkg::*;
    import svunit_pkg::svunit_testcase;
    import fs_tb_common_pkg::*;

    // ------------------------------------------------------------------
    // test wiring
    // ------------------------------------------------------------------

    typedef logic [SAD_8X4_W-1:0] sad_row_t[WINDOW_SIZE];
    typedef int sad_array_t[WINDOW_SIZE][WINDOW_SIZE];

    logic clk;
    logic stall;
    logic input_valid;
    logic input_last;
    logic [SW_IDX_W-1:0] input_sw_idx;
    logic [SAD_8X4_W-1:0] input_sads[WINDOW_SIZE];
    logic result_valid;
    logic [SAD_8X4_W-1:0] result_sad;
    mv_t  result_mv;

    fs_comparator dut (.*);

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    task automatic drive_cycle(logic s, logic v, logic l, int i, sad_row_t sads, logic do_stall);
        // Holy cursed (1:38 AM)
        // NEVER WRITE SystemVerilog at 3:00 AM (Scary) (Not Clickbait)
        if (do_stall && $urandom_range(1, 100) > 0) begin
            drive_cycle(1, v, l, i, sads, 0);
        end

        stall = s;
        input_valid = v;
        input_last = l;
        input_sw_idx = i;
        input_sads = sads;

        #0;
        // $display("5 - %p", dut.input_sads);
        // $display("4 - %p", dut.sad_l4);
        // $display("3 - %p", dut.sad_l3);
        // $display("2 - %p", dut.sad_l2_d);
        // $display("2 - %p", dut.sad_l2_q);
        // $display("1 - %p", dut.sad_l1);
        // $display("0 - %h", dut.result_sad);
        // $display("");
        @(posedge clk);
        #0;
    endtask

    // ------------------------------------------------------------------
    // svunit scaffolding
    // ------------------------------------------------------------------

    string name = "fs_comparator_ut";
    svunit_testcase svunit_ut;

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        stall        = '0;
        input_valid  = '0;
        input_last   = '0;
        input_sw_idx = '0;
        for (int i = 0; i < WINDOW_SIZE; i++) input_sads[i] = '0;
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN

    `SVTEST(typical)
        sad_row_t sad_buf[32];
        sad_row_t x_sad;
        sad_result_t result;

        for (int i = 0; i < 32; i++) x_sad[i] = 'x;
        drive_cycle(0, 0, 0, 0-4, x_sad, 0);
        drive_cycle(0, 0, 0, 0-3, x_sad, 0);
        drive_cycle(0, 0, 0, 0-2, x_sad, 0);
        drive_cycle(0, 0, 0, 0-1, x_sad, 0);

        std::randomize(sad_buf);
        for (int i = 0; i < 32; i++) begin
            drive_cycle(0, 1, i==31, i, sad_buf[i], 0);
        end

        drive_cycle(0, 0, 0, 33, x_sad, 0);
        `FAIL_UNLESS_LOG(result_valid === '0, $sformatf("act=0x%0h exp=0x%0h", result_valid, 0));
        drive_cycle(0, 0, 0, 34, x_sad, 0);
        `FAIL_UNLESS_LOG(result_valid === '1, $sformatf("act=0x%0h exp=0x%0h", result_valid, 1));

        result = fs_tb_common_pkg::sad_minimum#(SAD_8X4_W)::f(sad_buf);
        `FAIL_UNLESS_LOG(result_sad === result.sad, $sformatf("act=0x%0h exp=0x%0h", result_sad, result.sad));
        `FAIL_UNLESS_LOG(result_mv.row === result.row, $sformatf("act=0x%0h exp=0x%0h", result_mv.row, result.row));
        `FAIL_UNLESS_LOG(result_mv.col === result.col, $sformatf("act=0x%0h exp=0x%0h", result_mv.col, result.col));

        drive_cycle(0, 0, 0, 34, x_sad, 0);
        `FAIL_UNLESS_LOG(result_valid === '0, $sformatf("act=0x%0h exp=0x%0h", result_valid, 0));
        drive_cycle(0, 0, 0, 35, x_sad, 0);
        `FAIL_UNLESS_LOG(result_valid === '0, $sformatf("act=0x%0h exp=0x%0h", result_valid, 0));

        std::randomize(sad_buf);
        for (int i = 0; i < 32; i++) begin
            drive_cycle(0, 1, i==31, i, sad_buf[i], 0);

            if (i == 0) begin
                `FAIL_UNLESS_LOG(result_sad === '1, $sformatf("act=0x%0h exp=0x%0h", result_sad, '1));
            end
        end

        drive_cycle(0, 0, 0, 33, x_sad, 0);
        `FAIL_UNLESS_LOG(result_valid === '0, $sformatf("act=0x%0h exp=0x%0h", result_valid, 0));
        drive_cycle(0, 0, 0, 34, x_sad, 0);
        `FAIL_UNLESS_LOG(result_valid === '1, $sformatf("act=0x%0h exp=0x%0h", result_valid, 1));

        result = fs_tb_common_pkg::sad_minimum#(SAD_8X4_W)::f(sad_buf);
        `FAIL_UNLESS_LOG(result_sad === result.sad, $sformatf("act=0x%0h exp=0x%0h", result_sad, result.sad));
        `FAIL_UNLESS_LOG(result_mv.row === result.row, $sformatf("act=0x%0h exp=0x%0h", result_mv.row, result.row));
        `FAIL_UNLESS_LOG(result_mv.col === result.col, $sformatf("act=0x%0h exp=0x%0h", result_mv.col, result.col));
    `SVTEST_END

    `SVTEST(typical_stall)
        sad_row_t sad_buf[32];
        sad_row_t x_sad;
        sad_result_t result;

        for (int i = 0; i < 32; i++) x_sad[i] = 'x;
        drive_cycle(0, 0, 0, 0-4, x_sad, 1);
        drive_cycle(0, 0, 0, 0-3, x_sad, 1);
        drive_cycle(0, 0, 0, 0-2, x_sad, 1);
        drive_cycle(0, 0, 0, 0-1, x_sad, 1);

        std::randomize(sad_buf);
        for (int i = 0; i < 32; i++) begin
            drive_cycle(0, 1, i==31, i, sad_buf[i], 1);
        end

        drive_cycle(0, 0, 0, 33, x_sad, 1);
        `FAIL_UNLESS_LOG(result_valid === '0, $sformatf("act=0x%0h exp=0x%0h", result_valid, 0));
        drive_cycle(0, 0, 0, 34, x_sad, 1);
        `FAIL_UNLESS_LOG(result_valid === '1, $sformatf("act=0x%0h exp=0x%0h", result_valid, 1));

        result = fs_tb_common_pkg::sad_minimum#(SAD_8X4_W)::f(sad_buf);
        `FAIL_UNLESS_LOG(result_sad === result.sad, $sformatf("act=0x%0h exp=0x%0h", result_sad, result.sad));
        `FAIL_UNLESS_LOG(result_mv.row === result.row, $sformatf("act=0x%0h exp=0x%0h", result_mv.row, result.row));
        `FAIL_UNLESS_LOG(result_mv.col === result.col, $sformatf("act=0x%0h exp=0x%0h", result_mv.col, result.col));

        $display("POWIEJFPOQIJFPOIJXPCOIFJ");

        drive_cycle(0, 0, 0, 34, x_sad, 1);
        `FAIL_UNLESS_LOG(result_valid === '0, $sformatf("act=0x%0h exp=0x%0h", result_valid, 0));
        drive_cycle(0, 0, 0, 35, x_sad, 1);
        `FAIL_UNLESS_LOG(result_valid === '0, $sformatf("act=0x%0h exp=0x%0h", result_valid, 0));

        std::randomize(sad_buf);
        for (int i = 0; i < 32; i++) begin
            drive_cycle(0, 1, i==31, i, sad_buf[i], 1);

            if (i == 0) begin
                `FAIL_UNLESS_LOG(result_sad === '1, $sformatf("act=0x%0h exp=0x%0h", result_sad, '1));
            end
        end

        drive_cycle(0, 0, 0, 33, x_sad, 1);
        `FAIL_UNLESS_LOG(result_valid === '0, $sformatf("act=0x%0h exp=0x%0h", result_valid, 0));
        drive_cycle(0, 0, 0, 34, x_sad, 1);
        `FAIL_UNLESS_LOG(result_valid === '1, $sformatf("act=0x%0h exp=0x%0h", result_valid, 1));

        result = fs_tb_common_pkg::sad_minimum#(SAD_8X4_W)::f(sad_buf);
        `FAIL_UNLESS_LOG(result_sad === result.sad, $sformatf("act=0x%0h exp=0x%0h", result_sad, result.sad));
        `FAIL_UNLESS_LOG(result_mv.row === result.row, $sformatf("act=0x%0h exp=0x%0h", result_mv.row, result.row));
        `FAIL_UNLESS_LOG(result_mv.col === result.col, $sformatf("act=0x%0h exp=0x%0h", result_mv.col, result.col));
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
