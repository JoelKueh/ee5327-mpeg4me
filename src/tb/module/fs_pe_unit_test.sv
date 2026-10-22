// fs_pe_unit_test.sv
//
// svunit testbench for fs_pe (4x4 SAD PE).
//
// PE contract under test:
//   - Each cycle, the absolute differences of 4 pixel pairs are summed and
//     added to a 12-bit accumulator; `sad` is the registered accumulator, so
//     a row's contribution appears one cycle after it is sampled.
//   - `clear` (synchronous) resets the accumulator at the next posedge and
//     discards the row present during the clear cycle.
//   - `stall` holds the accumulator; the row present during a stall is not
//     accumulated.
//   - If both `clear` and `stall` are asserted, `clear` wins and the
//     accumulator resets.
//
// Run with: make test-module   (or make test for everything)
//
`include "svunit_defines.svh"

module fs_pe_unit_test;

    import me_pkg::*;
    import svunit_pkg::svunit_testcase;

    // ------------------------------------------------------------------
    // UUT signals
    // ------------------------------------------------------------------
    logic              clk;
    logic              clear;
    logic              stall;
    logic [3:0][PEL_W-1:0]  rb;
    logic [3:0][PEL_W-1:0]  cb;
    logic [SAD_4X4_W-1:0]   sad;

    // ------------------------------------------------------------------
    // UUT instance
    // ------------------------------------------------------------------
    fs_pe dut (
        .clk   (clk),
        .clear (clear),
        .stall (stall),
        .rb    (rb),
        .cb    (cb),
        .sad   (sad)
    );

    // 10ns clock, free-running for the whole run.
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ------------------------------------------------------------------
    // Drive helpers
    // ------------------------------------------------------------------

    // Drive one full DUT cycle: at the next negedge, latch the given controls
    // and rows (packed, pixel i in bits [PEL_W*i +: PEL_W]) so the mid-cycle
    // posedge samples them together, then return just after that posedge.
    // When this task returns, `sad` holds the accumulator after this cycle.
    task automatic drive_cycle(logic c,
                               logic s,
                               logic [4*PEL_W-1:0] r,
                               logic [4*PEL_W-1:0] b);
        @(negedge clk);
        clear = c;
        stall = s;
        rb[0] = r[PEL_W-1:0];
        rb[1] = r[PEL_W*2-1:PEL_W];
        rb[2] = r[PEL_W*3-1:PEL_W*2];
        rb[3] = r[PEL_W*4-1:PEL_W*3];
        cb[0] = b[PEL_W-1:0];
        cb[1] = b[PEL_W*2-1:PEL_W];
        cb[2] = b[PEL_W*3-1:PEL_W*2];
        cb[3] = b[PEL_W*4-1:PEL_W*3];
        @(posedge clk);
        #1;
    endtask

    // Reference model: absolute-difference sum of one 4-pixel row.
    function automatic logic [SAD_4X4_W-1:0] row_sad(logic [4*PEL_W-1:0] r,
                                                      logic [4*PEL_W-1:0] b);
        logic [SAD_4X4_W-1:0] sum;
        sum = '0;
        for (int i = 0; i < 4; i++) begin
            if (r[i*PEL_W +: PEL_W] >= b[i*PEL_W +: PEL_W]) begin
                sum += SAD_4X4_W'(r[i*PEL_W +: PEL_W]) - SAD_4X4_W'(b[i*PEL_W +: PEL_W]);
            end else begin
                sum += SAD_4X4_W'(b[i*PEL_W +: PEL_W]) - SAD_4X4_W'(r[i*PEL_W +: PEL_W]);
            end
        end
        return sum;
    endfunction

    // ------------------------------------------------------------------
    // svunit scaffolding
    // ------------------------------------------------------------------
    string name = "fs_pe_ut";
    svunit_testcase svunit_ut;

    function void build();
        svunit_ut = new(name);
    endfunction

    task setup();
        svunit_ut.setup();
        clear = '0;
        stall = '0;
        rb    = '0;
        cb    = '0;
    endtask

    task teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN

    //************************************************************
    // Test: clear_resets_accumulator
    //
    // Desc: a clear cycle resets the accumulator to 0 and discards the
    //       row present during the clear cycle.
    //************************************************************
    `SVTEST(clear_resets_accumulator)
        // Garbage on the bus must not leak into the accumulator.
        drive_cycle(1, 0, 32'hDE_AD_BEEF, 32'hCA_FE_BABE);
        `FAIL_UNLESS_EQUAL(0, sad);

        // A real row presented during the clear cycle is discarded.
        drive_cycle(1, 0, 32'h10_C8_64_0A, 32'h20_96_32_14);
        `FAIL_UNLESS_EQUAL(0, sad);
    `SVTEST_END

    //************************************************************
    // Test: four_row_accumulation
    //
    // Desc: stream 4 rows after a clear; the registered output shows the
    //       running sum one cycle per row, ending at the full 4x4 SAD.
    //       Rows (pixel 0..3), row sums:
    //         r0: {10,100,200,16}  vs {20, 50,150,32}  -> 10+50+50+16 = 126
    //         r1: {255,0,128,127}  vs {0, 255,0,128}   -> 255+255+128+1 = 639
    //         r2: {1,2,3,4}        vs {1, 2, 3, 4}    -> 0
    //         r3: {250,251,252,253} vs {1, 2, 3, 4}   -> 249*4 = 996
    //       Running: 126 -> 765 -> 765 -> 1761
    //************************************************************
    `SVTEST(four_row_accumulation)
        drive_cycle(1, 0, '0, '0);
        `FAIL_UNLESS_EQUAL(0, sad);

        drive_cycle(0, 0, 32'h10_C8_64_0A, 32'h20_96_32_14);
        `FAIL_UNLESS_EQUAL(126, sad);

        drive_cycle(0, 0, 32'h7F_80_00_FF, 32'h80_00_FF_00);
        `FAIL_UNLESS_EQUAL(765, sad);

        drive_cycle(0, 0, 32'h04_03_02_01, 32'h04_03_02_01);
        `FAIL_UNLESS_EQUAL(765, sad);

        drive_cycle(0, 0, 32'hFD_FC_FB_FA, 32'h04_03_02_01);
        `FAIL_UNLESS_EQUAL(1761, sad);
    `SVTEST_END

    //************************************************************
    // Test: stall_holds_accumulator
    //
    // Desc: during a stall the accumulator holds and the presented row is
    //       not accumulated; accumulation resumes from the held value.
    //************************************************************
    `SVTEST(stall_holds_accumulator)
        drive_cycle(1, 0, '0, '0);
        `FAIL_UNLESS_EQUAL(0, sad);

        drive_cycle(0, 0, 32'h10_C8_64_0A, 32'h20_96_32_14);
        `FAIL_UNLESS_EQUAL(126, sad);

        // Stalled cycle: row 1 must not be added.
        drive_cycle(0, 1, 32'h7F_80_00_FF, 32'h80_00_FF_00);
        `FAIL_UNLESS_EQUAL(126, sad);

        // Resuming: the same row now accumulates.
        drive_cycle(0, 0, 32'h7F_80_00_FF, 32'h80_00_FF_00);
        `FAIL_UNLESS_EQUAL(765, sad);
    `SVTEST_END

    //************************************************************
    // Test: clear_mid_stream
    //
    // Desc: a clear between rows zeros the accumulator and discards the row
    //       present on that cycle; the next row starts fresh from 0.
    //************************************************************
    `SVTEST(clear_mid_stream)
        drive_cycle(1, 0, '0, '0);
        `FAIL_UNLESS_EQUAL(0, sad);

        drive_cycle(0, 0, 32'h10_C8_64_0A, 32'h20_96_32_14);
        `FAIL_UNLESS_EQUAL(126, sad);

        drive_cycle(0, 0, 32'h7F_80_00_FF, 32'h80_00_FF_00);
        `FAIL_UNLESS_EQUAL(765, sad);

        // Clear while row 3 is present: sum resets and row 3 is discarded.
        drive_cycle(1, 0, 32'hFD_FC_FB_FA, 32'h04_03_02_01);
        `FAIL_UNLESS_EQUAL(0, sad);

        drive_cycle(0, 0, 32'hFD_FC_FB_FA, 32'h04_03_02_01);
        `FAIL_UNLESS_EQUAL(996, sad);
    `SVTEST_END

    //************************************************************
    // Test: clear_beats_stall
    //
    // Desc: when clear and stall are asserted together, the register reset
    //       wins and the accumulator is cleared.
    //************************************************************
    `SVTEST(clear_beats_stall)
        drive_cycle(1, 0, '0, '0);
        `FAIL_UNLESS_EQUAL(0, sad);

        drive_cycle(0, 0, 32'h10_C8_64_0A, 32'h20_96_32_14);
        `FAIL_UNLESS_EQUAL(126, sad);

        drive_cycle(1, 1, 32'h7F_80_00_FF, 32'h80_00_FF_00);
        `FAIL_UNLESS_EQUAL(0, sad);

        drive_cycle(0, 0, 32'h7F_80_00_FF, 32'h80_00_FF_00);
        `FAIL_UNLESS_EQUAL(639, sad);
    `SVTEST_END

    //************************************************************
    // Test: max_sad
    //
    // Desc: worst case (all reference pixels 255, all current pixels 0)
    //       exercises the full 12-bit width: 4 x 4 x 255 = 4080.
    //************************************************************
    `SVTEST(max_sad)
        drive_cycle(1, 0, '0, '0);
        `FAIL_UNLESS_EQUAL(0, sad);

        for (int i = 0; i < 4; i++) begin
            drive_cycle(0, 0, 32'hFF_FF_FF_FF, '0);
            `FAIL_UNLESS_EQUAL(SAD_4X4_W'((i + 1) * 1020), sad);
        end
    `SVTEST_END

    //************************************************************
    // Test: zero_sad
    //
    // Desc: identical rows produce a SAD of 0 throughout.
    //************************************************************
    `SVTEST(zero_sad)
        drive_cycle(1, 0, '0, '0);
        `FAIL_UNLESS_EQUAL(0, sad);

        for (int i = 0; i < 4; i++) begin
            drive_cycle(0, 0, 32'h0A_14_1E_28, 32'h0A_14_1E_28);
            `FAIL_UNLESS_EQUAL(0, sad);
        end
    `SVTEST_END

    //************************************************************
    // Test: random_rows
    //
    // Desc: stream 4 random rows and compare the running accumulator
    //       against a reference model after every row.
    //************************************************************
    `SVTEST(random_rows)
        logic [4*PEL_W-1:0] r, b;
        logic [SAD_4X4_W-1:0] exp;

        drive_cycle(1, 0, '0, '0);
        `FAIL_UNLESS_EQUAL(0, sad);

        exp = '0;
        for (int i = 0; i < 4; i++) begin
            r = '0;
            b = '0;
            for (int p = 0; p < 4; p++) begin
                r[p*PEL_W +: PEL_W] = PEL_W'($urandom());
                b[p*PEL_W +: PEL_W] = PEL_W'($urandom());
            end
            exp += row_sad(r, b);
            drive_cycle(0, 0, r, b);
            `FAIL_UNLESS_EQUAL(exp, sad);
        end
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
