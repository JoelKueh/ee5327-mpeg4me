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
    // test wiring
    // ------------------------------------------------------------------

    typedef logic [3:0][PEL_W-1:0] pe_row_t;

    logic clk;
    logic clear;
    logic stall;
    logic [3:0][PEL_W-1:0] rb;
    logic [3:0][PEL_W-1:0] cb;
    logic [SAD_4X4_W-1:0] sad;

    fs_pe dut (.*);

    initial begin
        $dumpfile("fs_pe.vcd");
        $dumpvars(0);
        clk = 0;
        forever begin
            $display("[%0t] sad_l1=%h, %h, acc_d=%h, acc_q=%h",
                $time, dut.sad_l1[0], dut.sad_l1[1], dut.acc_d, dut.acc_q);
            #5 clk = ~clk;
        end
    end

    task automatic drive_cycle(logic c, logic s, pe_row_t r, pe_row_t b);
        @(negedge clk);
        clear <= c;
        stall <= s;
        rb    <= r;
        cb    <= b;
        #0;
        @(posedge clk);
        #1;
    endtask

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

    // ------------------------------------------------------------------
    // test definitions
    // ------------------------------------------------------------------

    /* verilator lint_off DECLFILENAME */
    `SVUNIT_TESTS_BEGIN

    `SVTEST(clear_resets_accumulator)
        drive_cycle(1, 0, 32'h1, 32'h0);
        `FAIL_UNLESS_LOG(1 === sad, $sformatf("actual=0x%0h expected=0x%0h", sad, 1));
        drive_cycle(1, 0, 32'h1, 32'h0);
        `FAIL_UNLESS_LOG(1 === sad, $sformatf("actual=0x%0h expected=0x%0h", sad, 1));
        drive_cycle(1, 0, 32'h0001_0000, 32'h0000_0000);
        `FAIL_UNLESS_LOG(1 === sad, $sformatf("actual=0x%0h expected=0x%0h", sad, 1));
    `SVTEST_END

    `SVTEST(max_sad)
        drive_cycle(1, 0, 32'hFFFF_FFFF, 32'h0);
        drive_cycle(0, 0, 32'h0, 32'hFFFF_FFFF);
        drive_cycle(0, 0, 32'hFFFF_FFFF, 32'h0);
        drive_cycle(0, 0, 32'h0, 32'hFFFF_FFFF);

        `FAIL_UNLESS_LOG('hFF0 === sad, $sformatf("actual=0x%0h expected=0x%0h", 'hFF0, sad));
    `SVTEST_END

    `SVTEST(min_sad)
        drive_cycle(1, 0, 32'hFFFF_FFFF, 32'hFFFF_FFFF);
        drive_cycle(0, 0, 32'h0, 32'h0);
        drive_cycle(0, 0, 32'hEEEE_EEEE, 32'hEEEE_EEEE);
        drive_cycle(0, 0, 32'hDEAD_BEEF, 32'hDEAD_BEEF);
        `FAIL_UNLESS_LOG(0 === sad, $sformatf("actual=0x%0h expected=0x%0h", 0, sad));
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
