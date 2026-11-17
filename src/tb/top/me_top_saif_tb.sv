// me_top_saif_tb.sv
//
// Standalone stimulus-only testbench for me_top (based on fs_control_unit_test)
// to generate SAIF switching activity without stall cycles or checkers.

module me_top_saif_tb;

    import me_pkg::*;
    import fs_tb_common_pkg::*;

    localparam int NUM_RB_ROWS = WINDOW_SIZE + 7; // 39 rows

    typedef logic [WINDOW_SIZE+6:0][PEL_W-1:0] rb_row_t;
    typedef logic [3:0][PEL_W-1:0]             pel_row_t;
    typedef pel_row_t                          cb_block_t[4]; // [4 rows][4 cols]
    typedef logic [7:0][PEL_W-1:0]             cb_row_t;      // 8-pel row for frame extraction
    typedef logic [PEL_W-1:0]                  frame_t[FRAME_HEIGHT][FRAME_WIDTH];

    logic                                      clk;
    logic                                      clear;
    logic                                      stall;
    logic [WINDOW_SIZE+6:0][PEL_W-1:0]         rb;
    logic [3:0][PEL_W-1:0]                     cb[4];

    logic                                      result_4x4_valid[4];
    logic                                      result_4x8_valid[2];
    logic                                      result_8x4_valid[2];
    logic                                      result_8x8_valid;
    logic                                      result_16x8_valid;
    logic                                      result_16x16_valid;

    comb_sad_id_t                              result_16x8_id;
    logic [1:0]                                result_16x16_sb_idx;

    logic [SAD_4X4_W-1:0]                      result_min_4x4[4];
    logic [SAD_8X4_W-1:0]                      result_min_4x8[2];
    logic [SAD_8X4_W-1:0]                      result_min_8x4[2];
    logic [SAD_8X8_W-1:0]                      result_min_8x8;
    logic [SAD_16X8_W-1:0]                     result_min_16x8;
    logic [SAD_16X16_W-1:0]                    result_min_16x16;

    mv_t                                       result_mv_4x4[4];
    mv_t                                       result_mv_4x8[2];
    mv_t                                       result_mv_8x4[2];
    mv_t                                       result_mv_8x8;
    mv_t                                       result_mv_16x8;
    mv_t                                       result_mv_16x16;

    // Instantiate top-level wrapper
    me_top dut (.*);

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Drives one active subcycle beat with no stalls
    task automatic drive_subcycle(rb_row_t rb_d, pel_row_t cb_d[4]);
        stall <= 1'b0;
        rb    <= rb_d;
        for (int q = 0; q < 4; q++) begin
            cb[q] <= cb_d[q];
        end
        @(posedge clk);
    endtask

    // Drives all 39 rows x 4 subcycles = 156 active beats for a single 8x8 subblock
    task automatic drive_subblock(rb_row_t rb_d[NUM_RB_ROWS], cb_row_t cb_d[8]);
        cb_block_t cb_blk[4];

        // Partition 8x8 cb_d into 4 quadrants: 0=UL, 1=UR, 2=LL, 3=LR
        for (int r = 0; r < 4; r++) begin
            for (int c = 0; c < 4; c++) begin
                cb_blk[0][r][c] = cb_d[r][c];
                cb_blk[1][r][c] = cb_d[r][c + 4];
                cb_blk[2][r][c] = cb_d[r + 4][c];
                cb_blk[3][r][c] = cb_d[r + 4][c + 4];
            end
        end

        for (int r = 0; r < NUM_RB_ROWS; r++) begin
            for (int sub = 0; sub < 4; sub++) begin
                pel_row_t cb_sub[4];
                for (int q = 0; q < 4; q++) begin
                    cb_sub[q] = (r < 4) ? cb_blk[q][3 - sub] : '0;
                end
                drive_subcycle(rb_d[r], cb_sub);
            end
        end
    endtask

    // Drains the final macroblock's 4th 16x8 partition from fs_combiner
    task automatic flush_pipeline();
        rb_row_t dummy_rb[NUM_RB_ROWS];
        cb_row_t dummy_cb[8];

        for (int r = 0; r < NUM_RB_ROWS; r++) dummy_rb[r] = '0;
        for (int r = 0; r < 8;           r++) dummy_cb[r] = '0;

        drive_subblock(dummy_rb, dummy_cb);

        stall <= 1'b0;
        repeat (16) @(posedge clk);
    endtask

    task automatic get_sb(
        output rb_row_t rb_d[NUM_RB_ROWS],
        output cb_row_t cb_d[8],
        input  frame_t  rf,
        input  frame_t  cf,
        input  int      b_idx,
        input  int      sb_idx
    );
        int signed b_row, b_col;
        int signed sb_row_off, sb_col_off;
        int signed rf_row, rf_col;
        int signed cf_row, cf_col;

        b_row = b_idx / 80;
        b_col = b_idx % 80;

        sb_row_off = (sb_idx / 2) * 8;
        sb_col_off = (sb_idx % 2) * 8;

        rf_row = (b_row - 1) * 16 + sb_row_off;
        rf_col = (b_col - 1) * 16 + sb_col_off;

        for (int row = 0; row < NUM_RB_ROWS; row++) begin
            for (int col = 0; col < WINDOW_SIZE + 7; col++) begin
                if ((rf_row + row) >= 0 && (rf_row + row) < FRAME_HEIGHT &&
                    (rf_col + col) >= 0 && (rf_col + col) < FRAME_WIDTH)
                    rb_d[row][col] = rf[rf_row + row][rf_col + col];
                else
                    rb_d[row][col] = $urandom;
            end
        end

        cf_row = b_row * 16 + sb_row_off;
        cf_col = b_col * 16 + sb_col_off;

        for (int row = 0; row < 8; row++) begin
            for (int col = 0; col < 8; col++) begin
                if ((cf_row + row) >= 0 && (cf_row + row) < FRAME_HEIGHT &&
                    (cf_col + col) >= 0 && (cf_col + col) < FRAME_WIDTH)
                    cb_d[row][col] = cf[cf_row + row][cf_col + col];
                else
                    cb_d[row][col] = $urandom;
            end
        end
    endtask

    task automatic drive_block(const ref frame_t rf, const ref frame_t cf, input int b_idx);
        rb_row_t sb_rb[4][NUM_RB_ROWS];
        cb_row_t sb_cb[4][8];

        for (int sb_idx = 0; sb_idx < 4; sb_idx++) begin
            get_sb(sb_rb[sb_idx], sb_cb[sb_idx], rf, cf, b_idx, sb_idx);
            drive_subblock(sb_rb[sb_idx], sb_cb[sb_idx]);
        end
    endtask

    task automatic run_random_iteration(int iter_id, int num_blocks_to_test = 16);
        frame_t rf;
        frame_t cf;

        $display("[SAIF-TB] === Starting Iteration %0d (%0d macroblocks, no stalls) ===", iter_id, num_blocks_to_test);

        void'(std::randomize(rf));
        void'(std::randomize(cf));

        for (int b_idx = 0; b_idx < num_blocks_to_test; b_idx++) begin
            drive_block(rf, cf, b_idx);
        end

        flush_pipeline();
    endtask

    initial begin
        // Enable SystemVerilog RTL (logic, structs) and unpacked array (MDA) toggle tracking
        $set_gate_level_monitoring("rtl_on", "sv", "mda");

        clear <= 1'b1;
        stall <= 1'b0;
        rb    <= '0;
        for (int q = 0; q < 4; q++) cb[q] <= '0;
        repeat (4) @(posedge clk);
        clear <= 1'b0;

        // Start SAIF toggle collection on top-level me_top instance 'dut'
        $display("[SAIF-TB] Starting SAIF toggle collection on me_top_saif_tb.dut...");
        $set_toggle_region(dut);
        $toggle_start();

        // Run typical streaming workload (no stalls)
        for (int i = 0; i < 1; i++) begin
            run_random_iteration(i, 64);
        end

        // Stop SAIF toggle collection and write out me_top_rtl.saif
        $toggle_stop();
        $toggle_report("me_top_rtl.saif", 1.0e-9, "me_top_saif_tb.dut");
        $display("[SAIF-TB] Finished! Wrote me_top_rtl.saif");

        $finish;
    end

endmodule
