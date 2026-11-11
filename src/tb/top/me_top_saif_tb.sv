// me_top_saif_tb.sv
//
// Standalone stimulus-only testbench for me_top (based on fs_control_unit_test)
// to generate SAIF switching activity without stall cycles or checkers.

module me_top_saif_tb;

    import me_pkg::*;

    typedef logic [WINDOW_SIZE+6:0][PEL_W-1:0] rb_row_t;
    typedef logic [7:0][PEL_W-1:0]             cb_row_t;
    typedef logic [PEL_W-1:0]                  frame_t[FRAME_HEIGHT][FRAME_WIDTH];

    logic                              clk;
    logic                              clear;
    logic                              stall;
    logic [WINDOW_SIZE+6:0][PEL_W-1:0] rb;
    logic [7:0][PEL_W-1:0]             cb;
    logic                              upper_half;

    logic                   result_4x4_valid[2];
    logic                   result_4x8_valid;
    logic                   result_8x4_valid[2];
    logic                   result_8x8_valid;
    logic                   result_16x8_valid;
    logic                   result_16x16_valid;
    logic [SAD_4X4_W-1:0]   result_min_4x4[2];
    logic [SAD_8X4_W-1:0]   result_min_4x8;
    logic [SAD_8X4_W-1:0]   result_min_8x4[2];
    logic [SAD_8X8_W-1:0]   result_min_8x8;
    logic [SAD_16X8_W-1:0]  result_min_16x8;
    logic [SAD_16X16_W-1:0] result_min_16x16;
    mv_t                    result_mv_4x4[2];
    mv_t                    result_mv_4x8;
    mv_t                    result_mv_8x4[2];
    mv_t                    result_mv_8x8;
    mv_t                    result_mv_16x8;
    mv_t                    result_mv_16x16;

    // Instantiate top-level wrapper
    me_top dut (.*);

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Drives one active row with no stall cycles
    task automatic drive_cycle(rb_row_t rb_d, cb_row_t cb_d);
        stall = 1'b0;
        rb    = rb_d;
        cb    = cb_d;
        @(posedge clk);
        #0;
    endtask

    task automatic drive_subblock(rb_row_t rb_d[39], cb_row_t cb_d[8]);
        // Pass 1: Upper half (upper_half = 1)
        // Streams rb_d[0..34] and cb_d[0..3]
        upper_half = 1'b1;
        for (int i = 0; i < 35; i++) begin
            if (i < 4) begin
                drive_cycle(rb_d[i], cb_d[i]);
            end else begin
                drive_cycle(rb_d[i], '0);
            end
        end

        // Pass 2: Lower half (upper_half = 0)
        // Streams rb_d[4..38] and cb_d[4..7]
        upper_half = 1'b0;
        for (int i = 0; i < 35; i++) begin
            if (i < 4) begin
                drive_cycle(rb_d[i + 4], cb_d[i + 4]);
            end else begin
                drive_cycle(rb_d[i + 4], '0);
            end
        end
    endtask

    task automatic flush_pipeline();
        rb_row_t dummy_rb[39];
        cb_row_t dummy_cb[8];

        for (int r = 0; r < 39; r++) dummy_rb[r] = '0;
        for (int r = 0; r < 8;  r++) dummy_cb[r] = '0;

        drive_subblock(dummy_rb, dummy_cb);

        stall = 1'b0;
        repeat (10) begin
            @(posedge clk);
            #0;
        end
    endtask

    task automatic get_sb(
        output rb_row_t rb_d[39],
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

        for (int row = 0; row < 39; row++) begin
            for (int col = 0; col < 39; col++) begin
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
        rb_row_t sb_rb[4][39];
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

        @(posedge clk);
        clear      = 1'b1;
        stall      = 1'b0;
        upper_half = 1'b0;
        repeat (4) @(posedge clk);
        #0;
        clear      = 1'b0;

        for (int b_idx = 0; b_idx < num_blocks_to_test; b_idx++) begin
            drive_block(rf, cf, b_idx);
        end

        flush_pipeline();
    endtask

    initial begin
        clear      = 1'b1;
        stall      = 1'b0;
        rb         = '0;
        cb         = '0;
        upper_half = 1'b0;
        repeat (4) @(posedge clk);
        #0;
        clear      = 1'b0;

        // Start SAIF toggle collection on top-level me_top instance 'dut'
        $display("[SAIF-TB] Starting SAIF toggle collection on me_top_saif_tb.dut...");
        $set_toggle_region(dut);
        $toggle_start();

        // Run typical streaming workload (no stalls)
        for (int i = 0; i < 1; i++) begin
            run_random_iteration(i, 256);
        end

        // Stop SAIF toggle collection and write out me_top_rtl.saif
        $toggle_stop();
        $toggle_report("me_top_rtl.saif", 1.0e-9, "me_top_saif_tb.dut");
        $display("[SAIF-TB] Finished! Wrote me_top_rtl.saif");

        $finish;
    end

endmodule
