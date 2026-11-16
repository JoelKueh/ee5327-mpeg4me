// fs_combiner.sv
//
// Time-multiplexed combiner using 1/4-width SRAMs and 1/4-width adder datapaths
// across 4 subcycles per 8x8 input row.
//

module fs_combiner (
    input logic clk,        // The primary clock
    input logic clear_in,   // Pipelined clear signal input
    output logic clear_out, // Pipelined clear signal output

    input logic sad_8x8_valid,                                            // Input SADs valid signal (at least 4 cycles apart)
    input logic sad_8x8_last,                                             // Input SAD last signal
    input logic [1:0] sb_idx_8x8,                                         // Subblock index of the input SADs
    input logic [me_pkg::SW_IDX_W-1:0] sw_idx_8x8,                        // Window index of the input SADs
    input logic [me_pkg::SAD_8X8_W-1:0] sad_8x8[me_pkg::WINDOW_SIZE],     // Input SADs (32 columns)

    output logic sad_16x8_valid,                                          // 16x8 SAD valid signal
    output logic sad_16x8_last,                                           // 16x8 SAD last signal
    output me_pkg::comb_sad_id_t sad_16x8_id,                             // 16x8 SAD subblock id
    output logic [me_pkg::SW_IDX_W-1:0] sw_idx_16x8,                      // SAD search window offset
    output logic [1:0] subcycle_idx_16x8,                                 // Subcycle slice index (0..3 -> cols sub*8 +: 8)
    output logic [me_pkg::SAD_16X8_W-1:0] sad_16x8[me_pkg::WINDOW_SIZE/4],// 1/4-width output port for 16x8 and 8x16 SAD

    output logic sad_16x16_valid,                                         // 16x16 SAD valid signal
    output logic sad_16x16_last,                                          // 16x16 SAD last signal
    output logic [1:0] sb_idx_16x16,                                      // 16x16 SAD subblock indices
    output logic [me_pkg::SW_IDX_W-1:0] sw_idx_16x16,                     // SAD search window offset
    output logic [1:0] subcycle_idx_16x16,                                // Subcycle slice index (0..3 -> cols sub*8 +: 8)
    output logic [me_pkg::SAD_16X16_W-1:0] sad_16x16[me_pkg::WINDOW_SIZE/4] // 1/4-width 16x16 SAD
);

    import me_pkg::*;

    localparam int SLICE_SIZE  = WINDOW_SIZE / 4; // 8 columns per subcycle
    localparam int SRAM_ADDR_W = SW_IDX_W + 2;    // {sw_idx, sub_idx[1:0]} -> 4x deeper, 1/4x wider

    // 1/4-width SRAM interfaces
    sram_if #(.ADDR_W(SRAM_ADDR_W), .DATA_W(SLICE_SIZE * SAD_8X8_W))  ram_a_if ();
    sram_if #(.ADDR_W(SRAM_ADDR_W), .DATA_W(SLICE_SIZE * SAD_8X8_W))  ram_b_if ();
    sram_if #(.ADDR_W(SRAM_ADDR_W), .DATA_W(SLICE_SIZE * SAD_16X8_W)) ram_c_if ();

    sram_wrapper #(
        .ADDR_W(SRAM_ADDR_W),
        .DATA_W(SLICE_SIZE * SAD_8X8_W)
    ) ram_a (
        clk,
        ram_a_if
    );

    sram_wrapper #(
        .ADDR_W(SRAM_ADDR_W),
        .DATA_W(SLICE_SIZE * SAD_8X8_W)
    ) ram_b (
        clk,
        ram_b_if
    );

    sram_wrapper #(
        .ADDR_W(SRAM_ADDR_W),
        .DATA_W(SLICE_SIZE * SAD_16X8_W)
    ) ram_c (
        clk,
        ram_c_if
    );

    // Repacking of 8x8 SADs four slices with stride 4
    logic [SAD_8X8_W-1:0]   sad_8x8_sliced[SLICE_SIZE];

    // 1/4-width Stage 1 and Stage 2 datapath registers (8 elements instead of 32)
    logic [SAD_16X8_W-1:0]  sad_16x8_q[SLICE_SIZE],  sad_16x8_d[SLICE_SIZE];
    logic [SAD_16X16_W-1:0] sad_16x16_q[SLICE_SIZE], sad_16x16_d[SLICE_SIZE];

    // Subcycle sequencer state (tracks beats 1, 2, 3 following a sad_8x8_valid beat 0)
    logic                  busy_q, busy_d;
    logic [1:0]            sub_cnt_q, sub_cnt_d;
    logic [1:0]            hold_sb_idx_q, hold_sb_idx_d;
    logic [SW_IDX_W-1:0]   hold_sw_idx_q, hold_sw_idx_d;
    logic                  hold_last_q, hold_last_d;

    // Active Stage 0 control signals (muxed between incoming sad_8x8_valid beat 0 and sequenced beats 1..3)
    logic                  s0_valid;
    logic [1:0]            s0_sub_idx;
    logic [1:0]            s0_sb_idx;
    logic [SW_IDX_W-1:0]   s0_sw_idx;
    logic                  s0_last;
    logic [SAD_8X8_W-1:0]  s0_slice[SLICE_SIZE];

    // 3-stage control pipeline
    logic [1:0]            sb_idx_16x16_q, sb_idx_16x16_d;
    logic [1:0]            sub_idx_q[3],   sub_idx_d[3];
    logic [1:0]            sb_idx_q[3],    sb_idx_d[3];
    logic [SW_IDX_W-1:0]   sw_idx_q[3],    sw_idx_d[3];
    logic                  sad_last_q[3],  sad_last_d[3];
    logic                  sad_valid_q[3], sad_valid_d[3];
    logic                  first_sb_q[3],  first_sb_d[3];

    logic clear_q;

    always_comb begin
        // ------------------------------------------------------------------
        // 1. Subcycle Sequencer (4 beats per sad_8x8_valid pulse)
        // ------------------------------------------------------------------
        sad_8x8_hold_d = sad_8x8_hold_q;
        hold_sb_idx_d  = hold_sb_idx_q;
        hold_sw_idx_d  = hold_sw_idx_q;
        hold_last_d    = hold_last_q;
        busy_d         = busy_q;
        sub_cnt_d      = sub_cnt_q;

        if (sad_8x8_valid) begin
            // Beat 0: issue slice 0 immediately and capture slices 1..3 for the next 3 cycles
            s0_valid   = 1'b1;
            s0_sub_idx = 2'd0;
            s0_sb_idx  = sb_idx_8x8;
            s0_sw_idx  = sw_idx_8x8;
            s0_last    = sad_8x8_last;
            for (int i = 0; i < SLICE_SIZE; i++) begin
                s0_slice[i]          = sad_8x8[0*SLICE_SIZE + i];
                sad_8x8_hold_d[0][i] = sad_8x8[1*SLICE_SIZE + i];
                sad_8x8_hold_d[1][i] = sad_8x8[2*SLICE_SIZE + i];
                sad_8x8_hold_d[2][i] = sad_8x8[3*SLICE_SIZE + i];
            end
            hold_sb_idx_d = sb_idx_8x8;
            hold_sw_idx_d = sw_idx_8x8;
            hold_last_d   = sad_8x8_last;
            busy_d        = 1'b1;
            sub_cnt_d     = 2'd1;
        end else if (busy_q) begin
            // Beats 1, 2, 3: issue held slices 1, 2, 3
            s0_valid   = 1'b1;
            s0_sub_idx = sub_cnt_q;
            s0_sb_idx  = hold_sb_idx_q;
            s0_sw_idx  = hold_sw_idx_q;
            s0_last    = hold_last_q;
            s0_slice   = sad_8x8_hold_q[sub_cnt_q - 2'd1];

            if (sub_cnt_q == 2'd3) begin
                busy_d    = 1'b0;
                sub_cnt_d = 2'd0;
            end else begin
                sub_cnt_d = sub_cnt_q + 2'd1;
            end
        end else begin
            s0_valid   = 1'b0;
            s0_sub_idx = 'x;
            s0_sb_idx  = 'x;
            s0_sw_idx  = 'x;
            s0_last    = 'x;
            for (int i = 0; i < SLICE_SIZE; i++) s0_slice[i] = 'x;
        end

        // ------------------------------------------------------------------
        // 2. Pipeline Control & Data Registers
        // ------------------------------------------------------------------
        for (int i = 0; i < SLICE_SIZE; i++) sad_8x8_slice_d[i] = 'x;
        for (int i = 0; i < SLICE_SIZE; i++) sad_16x8_d[i]      = 'x;
        for (int i = 0; i < SLICE_SIZE; i++) sad_16x16_d[i]     = 'x;

        sb_idx_16x16_d = sb_idx_16x16_q;

        sad_valid_d[0] = s0_valid;
        sad_valid_d[1] = sad_valid_q[0];
        sad_valid_d[2] = sad_valid_q[1];

        sub_idx_d[0]   = s0_valid ? s0_sub_idx : 'x;
        sub_idx_d[1]   = sub_idx_q[0];
        sub_idx_d[2]   = sub_idx_q[1];

        sb_idx_d[0]    = s0_valid ? s0_sb_idx : 'x;
        sb_idx_d[1]    = sb_idx_q[0];
        sb_idx_d[2]    = sb_idx_q[1];

        sw_idx_d[0]    = s0_valid ? s0_sw_idx : 'x;
        sw_idx_d[1]    = sw_idx_q[0];
        sw_idx_d[2]    = sw_idx_q[1];

        sad_last_d[0]  = s0_valid ? s0_last : 'x;
        sad_last_d[1]  = sad_last_q[0];
        sad_last_d[2]  = sad_last_q[1];

        // Clear first_sb only after the final subcycle (sub_idx == 3) of the last row of subblock 0
        first_sb_d[0]  = first_sb_q[0] && !(sad_valid_q[0] && sad_last_q[0] && (sub_idx_q[0] == 2'd3));
        first_sb_d[1]  = first_sb_q[0];
        first_sb_d[2]  = first_sb_q[1];

        if (s0_valid) begin
            sad_8x8_slice_d = s0_slice;
        end

        // ------------------------------------------------------------------
        // 3. Stage 0: RAM_A and RAM_B Read/Write (1/4-width, addr = {sw_idx, sub_idx})
        // ------------------------------------------------------------------
        ram_a_if.wr_en   = '0;
        ram_a_if.wr_addr = 'x;
        ram_a_if.wr_data = 'x;
        ram_a_if.rd_en   = '0;
        ram_a_if.rd_addr = 'x;

        ram_b_if.wr_en   = '0;
        ram_b_if.wr_addr = 'x;
        ram_b_if.wr_data = 'x;
        ram_b_if.rd_en   = '0;
        ram_b_if.rd_addr = 'x;

        ram_c_if.wr_en   = '0;
        ram_c_if.wr_addr = 'x;
        ram_c_if.wr_data = 'x;
        ram_c_if.rd_en   = '0;
        ram_c_if.rd_addr = 'x;

        case (s0_sb_idx)
            2'd0: begin
                ram_a_if.wr_en   = s0_valid;
                ram_a_if.wr_addr = {s0_sw_idx, s0_sub_idx};
                for (int i = 0; i < SLICE_SIZE; i++) begin
                    ram_a_if.wr_data[i*SAD_8X8_W +: SAD_8X8_W] = s0_slice[i];
                end

                ram_a_if.rd_en   = s0_valid;
                ram_a_if.rd_addr = {s0_sw_idx, s0_sub_idx};
                ram_b_if.rd_en   = s0_valid;
                ram_b_if.rd_addr = {s0_sw_idx, s0_sub_idx};
            end
            2'd1: begin
                ram_b_if.wr_en   = s0_valid;
                ram_b_if.wr_addr = {s0_sw_idx, s0_sub_idx};
                for (int i = 0; i < SLICE_SIZE; i++) begin
                    ram_b_if.wr_data[i*SAD_8X8_W +: SAD_8X8_W] = s0_slice[i];
                end

                ram_a_if.rd_en   = s0_valid;
                ram_a_if.rd_addr = {s0_sw_idx, s0_sub_idx};
            end
            2'd2: begin
                ram_a_if.wr_en   = s0_valid;
                ram_a_if.wr_addr = {s0_sw_idx, s0_sub_idx};
                for (int i = 0; i < SLICE_SIZE; i++) begin
                    ram_a_if.wr_data[i*SAD_8X8_W +: SAD_8X8_W] = s0_slice[i];
                end

                ram_a_if.rd_en   = s0_valid;
                ram_a_if.rd_addr = {s0_sw_idx, s0_sub_idx};
            end
            2'd3: begin
                ram_b_if.wr_en   = s0_valid;
                ram_b_if.wr_addr = {s0_sw_idx, s0_sub_idx};
                for (int i = 0; i < SLICE_SIZE; i++) begin
                    ram_b_if.wr_data[i*SAD_8X8_W +: SAD_8X8_W] = s0_slice[i];
                end

                ram_b_if.rd_en   = s0_valid;
                ram_b_if.rd_addr = {s0_sw_idx, s0_sub_idx};
            end
        endcase

        // ------------------------------------------------------------------
        // 4. Stage 1: Compute 8-wide 16x8 SADs & RAM_C Read/Write
        // ------------------------------------------------------------------
        case (sb_idx_q[0])
            2'd0: begin
                for (int i = 0; i < SLICE_SIZE; i++) begin
                    sad_16x8_d[i] = ram_a_if.rd_data[i*SAD_8X8_W +: SAD_8X8_W]
                                  + ram_b_if.rd_data[i*SAD_8X8_W +: SAD_8X8_W];
                end
            end
            2'd1: begin
                for (int i = 0; i < SLICE_SIZE; i++) begin
                    sad_16x8_d[i] = ram_a_if.rd_data[i*SAD_8X8_W +: SAD_8X8_W] + sad_8x8_slice_q[i];
                end
            end
            2'd2: begin
                for (int i = 0; i < SLICE_SIZE; i++) begin
                    sad_16x8_d[i] = ram_a_if.rd_data[i*SAD_8X8_W +: SAD_8X8_W] + sad_8x8_slice_q[i];
                end

                ram_c_if.wr_en   = sad_valid_q[0];
                ram_c_if.wr_addr = {sw_idx_q[0], sub_idx_q[0]};
                for (int i = 0; i < SLICE_SIZE; i++) begin
                    ram_c_if.wr_data[i*SAD_16X8_W +: SAD_16X8_W] = sad_16x8_d[i];
                end
            end
            2'd3: begin
                for (int i = 0; i < SLICE_SIZE; i++) begin
                    sad_16x8_d[i] = ram_b_if.rd_data[i*SAD_8X8_W +: SAD_8X8_W] + sad_8x8_slice_q[i];
                end

                ram_c_if.rd_en   = sad_valid_q[0];
                ram_c_if.rd_addr = {sw_idx_q[0], sub_idx_q[0]};
            end
        endcase

        // ------------------------------------------------------------------
        // 5. Stage 2: Compute 8-wide 16x16 SADs
        // ------------------------------------------------------------------
        if (sb_idx_q[1] == 2'd3) begin
            for (int i = 0; i < SLICE_SIZE; i++) begin
                sad_16x16_d[i] = ram_c_if.rd_data[i*SAD_16X8_W +: SAD_16X8_W] + sad_16x8_q[i];
            end
        end

        // Increment 16x16 macroblock index only after the 4th subcycle (sub_idx == 3) of the last row of sb 3
        if (sad_valid_q[2] && sad_last_q[2] && (sb_idx_q[2] == 2'd3) && (sub_idx_q[2] == 2'd3)) begin
            sb_idx_16x16_d = sb_idx_16x16_q + 2'd1;
        end
    end

    always_ff @(posedge clk) begin
        if (clear_in) begin
            sad_8x8_hold_q  <= '{default: '0};
            sad_8x8_slice_q <= '{default: '0};
            sad_16x8_q      <= '{default: '0};
            sad_16x16_q     <= '{default: '0};

            busy_q          <= 1'b0;
            sub_cnt_q       <= '0;
            hold_sb_idx_q   <= '0;
            hold_sw_idx_q   <= '0;
            hold_last_q     <= 1'b0;

            sb_idx_16x16_q  <= '0;

            for (int i = 0; i < 3; i++) begin
                sub_idx_q[i]   <= '0;
                sb_idx_q[i]    <= '0;
                sw_idx_q[i]    <= '0;
                sad_last_q[i]  <= 1'b0;
                sad_valid_q[i] <= 1'b0;
                first_sb_q[i]  <= 1'b1;
            end
        end else begin
            sad_8x8_hold_q  <= sad_8x8_hold_d;
            sad_8x8_slice_q <= sad_8x8_slice_d;
            sad_16x8_q      <= sad_16x8_d;
            sad_16x16_q     <= sad_16x16_d;

            busy_q          <= busy_d;
            sub_cnt_q       <= sub_cnt_d;
            hold_sb_idx_q   <= hold_sb_idx_d;
            hold_sw_idx_q   <= hold_sw_idx_d;
            hold_last_q     <= hold_last_d;

            sb_idx_16x16_q  <= sb_idx_16x16_d;

            sub_idx_q       <= sub_idx_d;
            sb_idx_q        <= sb_idx_d;
            sw_idx_q        <= sw_idx_d;
            sad_last_q      <= sad_last_d;
            sad_valid_q     <= sad_valid_d;
            first_sb_q      <= first_sb_d;
        end

        clear_q <= clear_in;
    end

    always_comb begin
        sad_16x8_valid     = sad_valid_q[1] & !first_sb_q[1];
        sad_16x8_last      = sad_last_q[1]  & (sub_idx_q[1] == 2'd3);
        case (sb_idx_q[1])
            2'd0: sad_16x8_id = SAD_SXL_1;
            2'd1: sad_16x8_id = SAD_SXL_0;
            2'd2: sad_16x8_id = SAD_LXS_0;
            2'd3: sad_16x8_id = SAD_LXS_1;
        endcase
        sw_idx_16x8        = sw_idx_q[1];
        subcycle_idx_16x8  = sub_idx_q[1];
        sad_16x8           = sad_16x8_q;

        sad_16x16_valid    = sad_valid_q[2] & !first_sb_q[2] & (sb_idx_q[2] == 2'd3);
        sad_16x16_last     = sad_last_q[2]  & (sub_idx_q[2] == 2'd3);
        sb_idx_16x16       = sb_idx_16x16_q;
        sw_idx_16x16       = sw_idx_q[2];
        subcycle_idx_16x16 = sub_idx_q[2];
        sad_16x16          = sad_16x16_q;

        clear_out          = clear_q;
    end

endmodule
