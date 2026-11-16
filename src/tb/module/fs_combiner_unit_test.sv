// fs_combiner_unit_test.sv
//
// svunit testbench for quarter-width, stride-4 time-multiplexed fs_combiner
// (8x8 -> 16x8 / 16x16 SAD combination).
//
`include "svunit_defines.svh"

module fs_combiner_unit_test;

    import me_pkg::*;
    import svunit_pkg::svunit_testcase;

    // ------------------------------------------------------------------
    // test wiring
    // ------------------------------------------------------------------

    localparam int SLICE_SIZE = WINDOW_SIZE / 4; // 8 SADs per subcycle

    typedef logic [SAD_8X8_W-1:0] sad_row_t[WINDOW_SIZE];

    logic                       clk;
    logic                       clear_in;
    logic                       clear_out;

    logic                       sad_8x8_valid;
    logic                       sad_8x8_last;
    logic [1:0]                 sb_idx_8x8;
    logic [SW_IDX_W-1:0]        sw_idx_8x8;
    logic [SAD_8X8_W-1:0]       sad_8x8[WINDOW_SIZE];

    logic                       sad_16x8_valid;
    logic                       sad_16x8_last;
    comb_sad_id_t               sad_16x8_id;
    logic [SW_IDX_W-1:0]        sw_idx_16x8;
    logic [1:0]                 subcycle_idx_16x8;
    logic [SAD_16X8_W-1:0]      sad_16x8[SLICE_SIZE];

    logic                       sad_16x16_valid;
    logic                       sad_16x16_last;
    logic [1:0]                 sb_idx_16x16;
    logic [SW_IDX_W-1:0]        sw_idx_16x16;
    logic [1:0]                 subcycle_idx_16x16;
    logic [SAD_16X16_W-1:0]     sad_16x16[SLICE_SIZE];

    fs_combiner dut (.*);

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, fs_combiner_unit_test, "+mda", "+all");
        clk = '0;
        forever #5 clk = ~clk;
    end

    // Drive a single 4-subcycle row beat.
    // When v == 1: sad_8x8_valid pulses high on subcycle 0 and is 0 on subcycles 1..3,
    // while sad_8x8, sb_idx_8x8, sw_idx_8x8, and sad_8x8_last are held stable across all 4 cycles.
    task automatic drive_row_4cycles(
        logic       do_s,
        logic       l,
        logic       v,
        logic [1:0] sb_idx,
        logic [SW_IDX_W-1:0] sw_idx,
        sad_row_t   sad_buf
    );
        // Optional stall cycles before the valid row arrives
        if (do_s) begin
            clear_in      <= 1'b0;
            sad_8x8_valid <= 1'b0;
            @(posedge clk);
        end

        // Subcycle 0: assert sad_8x8_valid = v and present held payload
        clear_in      <= 1'b0;
        sad_8x8_valid <= v;
        sad_8x8_last  <= l;
        sb_idx_8x8    <= sb_idx;
        sw_idx_8x8    <= sw_idx;
        sad_8x8       <= sad_buf;
        @(posedge clk);

        // Subcycles 1, 2, 3: deassert sad_8x8_valid, keep payload held for 3 more cycles
        for (int sub = 1; sub < 4; sub++) begin
            sad_8x8_valid <= 1'b0;
            @(posedge clk);
        end
    endtask

    task automatic drive_subblock(logic do_s, int sb_idx, sad_row_t sad_buf[WINDOW_SIZE]);
        for (int i = 0; i < WINDOW_SIZE; i++) begin
            drive_row_4cycles(do_s, (i == WINDOW_SIZE - 1), 1'b1, sb_idx[1:0], i[SW_IDX_W-1:0], sad_buf[i]);
        end
    endtask

    task automatic drive_block(logic do_s, sad_row_t sad_buf[4][WINDOW_SIZE]);
        sad_row_t x_sad;
        for (int i = 0; i < WINDOW_SIZE; i++) x_sad[i] = 'x;

        for (int sb = 0; sb < 4; sb++) begin
            // 7 non-valid rows (rows 0..6 of fs_computer) before the 32 valid rows (rows 7..38)
            for (int i = 0; i < 7; i++) begin
                drive_row_4cycles(do_s, 'x, 1'b0, 'x, 'x, x_sad);
            end
            drive_subblock(do_s, sb, sad_buf[sb]);
        end
    endtask

    task automatic monitor_sads(sad_row_t sad_array[4][WINDOW_SIZE], ref int cnt_16x8, ref int cnt_16x16);
        int sad_buf_val;
        int col;

        @(posedge clk);

        if (sad_16x8_valid) begin
            for (int i = 0; i < SLICE_SIZE; i++) begin
                col = 4 * i + int'(subcycle_idx_16x8);

                case (sad_16x8_id)
                    SAD_LXS_0: sad_buf_val = int'(sad_array[0][sw_idx_16x8][col]) + int'(sad_array[2][sw_idx_16x8][col]);
                    SAD_LXS_1: sad_buf_val = int'(sad_array[1][sw_idx_16x8][col]) + int'(sad_array[3][sw_idx_16x8][col]);
                    SAD_SXL_0: sad_buf_val = int'(sad_array[0][sw_idx_16x8][col]) + int'(sad_array[1][sw_idx_16x8][col]);
                    SAD_SXL_1: sad_buf_val = int'(sad_array[2][sw_idx_16x8][col]) + int'(sad_array[3][sw_idx_16x8][col]);
                endcase

                `FAIL_UNLESS_LOG(sad_16x8[i] === SAD_16X8_W'(sad_buf_val), $sformatf(
                    "16x8: id=%s sw_idx=%0d sub=%0d lane=%0d (col=%0d) act=0x%0h exp=0x%0h",
                    sad_16x8_id.name(), sw_idx_16x8, subcycle_idx_16x8, i, col, sad_16x8[i], SAD_16X8_W'(sad_buf_val)
                ));
            end

            `FAIL_UNLESS_LOG(sad_16x8_last === ((sw_idx_16x8 == WINDOW_SIZE - 1) && (subcycle_idx_16x8 == 2'd3)), $sformatf(
                "16x8 last mismatch at sw_idx=%0d sub=%0d: act=%0b", sw_idx_16x8, subcycle_idx_16x8, sad_16x8_last
            ));

            cnt_16x8++;
        end

        if (sad_16x16_valid) begin
            for (int i = 0; i < SLICE_SIZE; i++) begin
                col = 4 * i + int'(subcycle_idx_16x16);

                sad_buf_val = int'(sad_array[0][sw_idx_16x16][col]) + int'(sad_array[1][sw_idx_16x16][col])
                            + int'(sad_array[2][sw_idx_16x16][col]) + int'(sad_array[3][sw_idx_16x16][col]);

                `FAIL_UNLESS_LOG(sad_16x16[i] === SAD_16X16_W'(sad_buf_val), $sformatf(
                    "16x16: sw_idx=%0d sub=%0d lane=%0d (col=%0d) act=0x%0h exp=0x%0h",
                    sw_idx_16x16, subcycle_idx_16x16, i, col, sad_16x16[i], SAD_16X16_W'(sad_buf_val)
                ));
            end

            `FAIL_UNLESS_LOG(sad_16x16_last === ((sw_idx_16x16 == WINDOW_SIZE - 1) && (subcycle_idx_16x16 == 2'd3)), $sformatf(
                "16x16 last mismatch at sw_idx=%0d sub=%0d: act=%0b", sw_idx_16x16, subcycle_idx_16x16, sad_16x16_last
            ));

            cnt_16x16++;
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
        @(posedge clk);
        clear_in      <= 1'b1;
        sad_8x8_valid <= 1'b0;
        sad_8x8_last  <= 1'b0;
        sb_idx_8x8    <= '0;
        sw_idx_8x8    <= '0;
        for (int i = 0; i < WINDOW_SIZE; i++) sad_8x8[i] <= '0;
        @(posedge clk);
        clear_in      <= 1'b0;
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN

    `SVTEST(typical)
        sad_row_t sad_buf[4][WINDOW_SIZE];
        int cnt_16x8  = 0;
        int cnt_16x16 = 0;

        std::randomize(sad_buf);

        fork
            forever monitor_sads(sad_buf, cnt_16x8, cnt_16x16);
        join_none

        drive_block(0, sad_buf);
        drive_block(0, sad_buf);
        drive_block(0, sad_buf);
        drive_block(0, sad_buf);
        drive_block(0, sad_buf);

        // Drain final pipeline stages
        repeat (8) @(posedge clk);
        disable fork;

        // 5 blocks = 20 subblocks total; first subblock is suppressed by first_sb_q -> 19 active subblocks * 32 rows * 4 subcycles = 2432 beats
        `FAIL_UNLESS_LOG(cnt_16x8 == 19 * WINDOW_SIZE * 4, $sformatf("Expected %0d 16x8 valid beats, got %0d", 19 * WINDOW_SIZE * 4, cnt_16x8));
        // 5 blocks * 32 rows * 4 subcycles = 640 beats of 16x16
        `FAIL_UNLESS_LOG(cnt_16x16 == 5 * WINDOW_SIZE * 4, $sformatf("Expected %0d 16x16 valid beats, got %0d", 5 * WINDOW_SIZE * 4, cnt_16x16));
    `SVTEST_END

    `SVTEST(typical_stall)
        sad_row_t sad_buf[4][WINDOW_SIZE];
        int cnt_16x8  = 0;
        int cnt_16x16 = 0;

        std::randomize(sad_buf);

        fork
            forever monitor_sads(sad_buf, cnt_16x8, cnt_16x16);
        join_none

        drive_block(1, sad_buf);
        drive_block(1, sad_buf);
        drive_block(1, sad_buf);
        drive_block(1, sad_buf);
        drive_block(1, sad_buf);

        // Drain final pipeline stages
        repeat (8) @(posedge clk);
        disable fork;

        `FAIL_UNLESS_LOG(cnt_16x8 == 19 * WINDOW_SIZE * 4, $sformatf("Expected %0d 16x8 valid beats, got %0d", 19 * WINDOW_SIZE * 4, cnt_16x8));
        `FAIL_UNLESS_LOG(cnt_16x16 == 5 * WINDOW_SIZE * 4, $sformatf("Expected %0d 16x16 valid beats, got %0d", 5 * WINDOW_SIZE * 4, cnt_16x16));
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
