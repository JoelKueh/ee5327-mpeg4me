// fs_quarter_comparator_unit_test.sv
//
// svunit testbench for fs_quarter_comparator.
//
`include "svunit_defines.svh"

module fs_quarter_comparator_unit_test;

    import me_pkg::*;
    import svunit_pkg::svunit_testcase;

    // ------------------------------------------------------------------
    // test wiring
    // ------------------------------------------------------------------

    localparam int SAD_W = SAD_16X16_W;

    typedef logic [SAD_W-1:0] sad_grid_t[WINDOW_SIZE][WINDOW_SIZE];

    logic                clk;
    logic                clear;

    logic                input_valid;
    logic                input_last;
    logic [1:0]          input_subcycle_idx;
    logic [SW_IDX_W-1:0] input_sw_idx;
    logic [SAD_W-1:0]    input_sads[SLICE_SIZE];

    logic                result_valid;
    logic [SAD_W-1:0]    result_sad;
    mv_t                 result_mv;

    fs_quarter_comparator #(
        .SAD_RESULT_W(SAD_W)
    ) dut (.*);

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, fs_quarter_comparator_unit_test, "+mda", "+all");
        clk = '0;
        forever #5 clk = ~clk;
    end

    // Drive a single subcycle slice (strictly 1 clock cycle)
    task automatic drive_subcycle(
        logic                v,
        logic                last,
        logic [SW_IDX_W-1:0] sw_idx,
        logic [1:0]          sub_idx,
        sad_grid_t           grid
    );
        clear              <= 1'b0;
        input_valid        <= v;
        input_last         <= v && last;
        input_sw_idx       <= sw_idx;
        input_subcycle_idx <= sub_idx;
        for (int i = 0; i < SLICE_SIZE; i++) begin
            input_sads[i] <= v ? grid[sw_idx][4*i + sub_idx] : 'x;
        end
        @(posedge clk);
    endtask

    // Drive a full 4-subcycle row (with an optional 4-cycle inter-row stall gap)
    task automatic drive_row(
        logic                do_s,
        logic                v,
        logic [SW_IDX_W-1:0] sw_idx,
        sad_grid_t           grid
    );
        if (do_s) begin
            for (int sub = 0; sub < 4; sub++) begin
                drive_subcycle(1'b0, 1'b0, sw_idx, sub[1:0], grid);
            end
        end

        for (int sub = 0; sub < 4; sub++) begin
            logic is_last = (sw_idx == SW_IDX_W'(WINDOW_SIZE - 1)) && (sub == 3);
            drive_subcycle(v, is_last, sw_idx, sub[1:0], grid);
        end
    endtask

    // Drive a full 39-row search window (7 fringe rows + 32 valid rows)
    task automatic drive_window(logic do_s, sad_grid_t grid);
        // 7-row fringe before valid SADs begin
        for (int r = 0; r < 7; r++) begin
            drive_row(do_s, 1'b0, '0, grid);
        end

        // 32 valid search window rows
        for (int r = 0; r < WINDOW_SIZE; r++) begin
            drive_row(do_s, 1'b1, r[SW_IDX_W-1:0], grid);
        end
    endtask

	// Reference model matching hardware raster-order tie-breaking:
    // Selects global minimum SAD; ties broken by smallest row, then smallest col.
    function automatic void calc_expected_min(
        input  sad_grid_t        grid,
        output logic [SAD_W-1:0] exp_sad,
        output mv_t              exp_mv
    );
        exp_sad    = '1;
        exp_mv.row = '0;
        exp_mv.col = '0;

        for (int r = 0; r < WINDOW_SIZE; r++) begin
            for (int c = 0; c < WINDOW_SIZE; c++) begin
                if (grid[r][c] < exp_sad) begin
                    exp_sad    = grid[r][c];
                    exp_mv.row = r[SW_IDX_W-1:0];
                    exp_mv.col = c[SW_IDX_W-1:0];
                end
            end
        end
    endfunction

    // Monitor for 1 valid result pulse at the end of a window
    task automatic monitor_result(sad_grid_t grid);
        logic [SAD_W-1:0] exp_sad;
        mv_t              exp_mv;

        calc_expected_min(grid, exp_sad, exp_mv);

        forever begin
            @(posedge clk);
            if (result_valid) begin
                `FAIL_UNLESS_LOG(result_sad === exp_sad, $sformatf(
                    "SAD mismatch: act=0x%0h exp=0x%0h", result_sad, exp_sad
                ));
                `FAIL_UNLESS_LOG(result_mv.row === exp_mv.row && result_mv.col === exp_mv.col, $sformatf(
                    "MV mismatch: act=(%0d,%0d) exp=(%0d,%0d)",
                    result_mv.row, result_mv.col, exp_mv.row, exp_mv.col
                ));
                break;
            end
        end
    endtask

    // ------------------------------------------------------------------
    // svunit scaffolding
    // ------------------------------------------------------------------

    string name = "fs_quarter_comparator_ut";
    svunit_testcase svunit_ut;

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        @(posedge clk);
        clear              <= 1'b1;
        input_valid        <= 1'b0;
        input_last         <= 1'b0;
        input_subcycle_idx <= '0;
        input_sw_idx       <= '0;
        for (int i = 0; i < SLICE_SIZE; i++) input_sads[i] <= '0;
        @(posedge clk);
        clear              <= 1'b0;
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN

    `SVTEST(min_at_corners_and_subcycles)
        sad_grid_t grid;
        int test_rows[4] = '{0, 7, 19, 31};
        int test_cols[8] = '{0, 1, 2, 3, 14, 21, 28, 31};

        foreach (test_rows[ri]) begin
            foreach (test_cols[ci]) begin
                int tr = test_rows[ri];
                int tc = test_cols[ci];

                for (int r = 0; r < WINDOW_SIZE; r++)
                    for (int c = 0; c < WINDOW_SIZE; c++)
                        grid[r][c] = 16'h1000 + r * 32 + c;

                grid[tr][tc] = 16'h0005; // Plant unique global minimum

                fork
                    begin
                        drive_window(0, grid);
                        input_valid <= 1'b0;
                        @(posedge clk);
                    end
                    monitor_result(grid);
                join
            end
        end
    `SVTEST_END

	`SVTEST(tie_breaking)
        sad_grid_t grid;

        for (int r = 0; r < WINDOW_SIZE; r++)
            for (int c = 0; c < WINDOW_SIZE; c++)
                grid[r][c] = 16'h0500;

        // Case 1: Cross-subcycle tie on the same row (row 10):
        // col=4 arrives in subcycle 0 (lane 1), while col=3 arrives later in subcycle 3 (lane 0).
        // Raster-order tie-breaking must pick (10, 3) over (10, 4).
        grid[10][4]  = 16'h0010; // Row 10, subcycle 0, lane 1 (arrives earlier, larger col)
        grid[10][3]  = 16'h0010; // Row 10, subcycle 3, lane 0 (arrives later, smaller col -> wins!)
        grid[10][18] = 16'h0010; // Row 10, subcycle 2, lane 4

        fork
            begin
                drive_window(0, grid);
                input_valid <= 1'b0;
                input_last  <= 1'b0;
                @(posedge clk);
            end
            monitor_result(grid);
        join

        // Case 2: Cross-row tie: earlier row (3, 7) must beat later row (10, 3)
        grid[3][7] = 16'h0010;

        fork
            begin
                drive_window(0, grid);
                input_valid <= 1'b0;
                input_last  <= 1'b0;
                @(posedge clk);
            end
            monitor_result(grid);
        join
    `SVTEST_END

    `SVTEST(typical_back_to_back)
        sad_grid_t grid[4];
        std::randomize(grid);

        // Stream 4 full 39-row windows back-to-back (each has the 7-row fringe gap)
        fork
            begin
                for (int w = 0; w < 4; w++) begin
                    drive_window(0, grid[w]);
                end
                input_valid <= 1'b0;
                @(posedge clk);
            end
            begin
                for (int w = 0; w < 4; w++) begin
                    monitor_result(grid[w]);
                end
            end
        join
    `SVTEST_END

    `SVTEST(typical_stall)
        sad_grid_t grid[4];
        std::randomize(grid);

        // Stream 4 full 39-row windows with stalls
        fork
            begin
                for (int w = 0; w < 4; w++) begin
                    drive_window(1, grid[w]);
                end
                input_valid <= 1'b0;
                @(posedge clk);
            end
            begin
                for (int w = 0; w < 4; w++) begin
                    monitor_result(grid[w]);
                end
            end
        join
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
