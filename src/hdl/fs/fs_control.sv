// fs_control.sv
//
// Control module for the full search motion estimation system.
//

module fs_control (
    input  logic clk,                             // The primary clock
    input  logic rst_n,                           // Asynchronous negative reset

    // Reference block is streamed into the control model in Morton order.
    output logic rb_ready,                        // Reference block ready signal
    input  logic rb_valid,                        // Reference block data valid signal
    input  logic [WINDOW_SIZE+6:0][PEL_W-1:0] rb, // Reference block input stream

    // Current block is also streamed in Morton order.
    output logic cb_ready,                        // Current block ready signal
    input  logic cb_valid,                        // Current block data valid signal
    input  logic [3:0][PEL_W-1:0] cb[4],          // Current block input
    
    // RAM interfaces used by the comparator.
    sram_if.mstr ram_a,
    sram_if.mstr ram_b,
    sram_if.mstr ram_c,

    // Winning SAD computations for the current block.
    sad_result_if.source results
);

    import me_pkg::*;

    parameter int COMPUTER_LATENCY = 10;

    // Input data buffers
    logic [WINDOW_SIZE+6:0][PEL_W-1:0] rb_q, rb_d;
    logic rb_has_data_q, rb_has_data_d;
    logic [3:0][PEL_W-1:0] cb_q[4], cb_d[4];
    logic cb_has_data_q, cb_has_data_d;

    // Current row and current subblock trackers
    logic [RB_ROW_IDX_W-1:0] rb_row_idx_q, rb_row_idx_d;
    logic [1:0] cb_subblock_idx_q, cb_subblock_idx_d;

    // Valid output of the different SAD engines
    logic sad_16x8_valid;
    logic sad_16x16_valid;

    // Results of SAD computations from computer and combiner
    logic [SAD_8X4_W-1:0] sad_8x4[2][WINDOW_SIZE];
    logic [SAD_8X8_W-1:0] sad_8x8[WINDOW_SIZE];
    logic [SAD_16X8_W-1:0] sad_16x8[WINDOW_SIZE];
    logic [SAD_16X16_W-1:0] sad_16x16[WINDOW_SIZE];

    // Nets defining the row that each compuation belongs to
    logic [RB_ROW_IDX_W-1:0] row_idx_8x8;
    logic [SW_IDX_W-1:0] sw_idx_16x8;
    logic [SW_IDX_W-1:0] sw_idx_16x16;

    // Buffered output for the SAD computations
    logic [SAD_8X4_W-1:0]   min_8x4_q  [8], min_8x4_d  [8];
    logic [SAD_8X8_W-1:0]   min_8x8_q  [4], min_8x8_d  [4];
    logic [SAD_16X8_W-1:0]  min_8x16_q [2], min_8x16_d [2];
    logic [SAD_16X8_W-1:0]  min_16x8_q [2], min_16x8_d [2];
    logic [SAD_16X16_W-1:0] min_16x16_q,    min_16x16_d;

    mv_t mv_8x4_q   [8], mv_8x4_d   [8];
    mv_t mv_8x8_q   [4], mv_8x8_d   [4];
    mv_t mv_8x16_q  [2], mv_8x16_d  [2];
    mv_t mv_16x8_q  [2], mv_16x8_d  [2];
    mv_t mv_16x16_q,     mv_16x16_d;

    // Valid output of the different comparators
    logic result_8x4_valid[2];
    logic result_8x8_valid;
    logic result_16x8_valid;
    logic result_16x16_valid;

    // Wire output of the different comparators
    logic [SAD_8X4_W-1:0]   result_min_8x4[2];
    logic [SAD_8X8_W-1:0]   result_min_8x8;
    logic [SAD_16X8_W-1:0]  result_min_16x8;
    logic [SAD_16X16_W-1:0] result_min_16x16;

    mv_t result_mv_8x4[2];
    mv_t result_mv_8x8;
    mv_t result_mv_16x8;
    mv_t result_mv_16x16;

    // Stall signal computed from the state of the input data buffers.
    logic stall_q[COMPUTER_LATENCY], stall_d[COMPUTER_LATENCY];

    // Computer - Computes fisrt level SAD results from the RB stream
    fs_computer computer (
        .clk(clk),
        .clear(rb_row_idx_q == 0),
        .stall(stall_d[0]),

        .cb(cb_q),
        .rb(rb),
        .rb_row_idx(rb_row_idx_q),

        .sad_8x4(sad_8x4),
        .sad_8x8(sad_8x8),
        .sad_row_idx(row_idx_8x8)
    );

    // Combiner - Combines first level SAD results into higher level reslts
    fs_combiner comb8x8 (
        .clk(clk),
        .stall(stall_d[COMPUTER_LATENCY]),

        .sad_8x8_valid(row_idx_8x8 >= 4),
        .cb_subblock_idx(cb_subblock_idx_q),
        .sw_idx_8x8(rb2sw(row_idx_8x8)),
        .sad_8x8(sad_8x8),

        .ram_a(ram_a),
        .ram_b(ram_b),
        .ram_c(ram_c),

        .sad_16x8_valid(sad_16x8_valid),
        .sw_idx_16x8(sw_idx_16x8),
        .sad_16x8(sad_16x8),

        .sad_16x16_valid(sad_16x16_valid),
        .sw_idx_16x16(sw_idx_16x16),
        .sad_16x16(sad_16x16)
    );

    // Comparator - Preforms a MIN reduction on input SADs
    fs_comparator#(SAD_8X4_W) comparator_8x4_1 (
        .clk(clk),
        .clear(row_idx_8x8 < 4),
        .stall(stall_d[COMPUTER_LATENCY]),

        .input_sw_idx(rb2sw(row_idx_8x8)),
        .input_sads(sad_8x4[0]),

        .result_valid(result_8x4_valid[0]),
        .result_sad(result_min_8x4[0]),
        .result_mv(result_mv_8x4[0])
    );

    fs_comparator#(SAD_8X4_W) comparator_8x4_2 (
        .clk(clk),
        .clear(row_idx_8x8 < 0),
        .stall(stall_d[COMPUTER_LATENCY]),

        .input_sw_idx(rb2sw(row_idx_8x8)),
        .input_sads(sad_8x4[1]),

        .result_valid(result_8x4_valid[1]),
        .result_sad(result_min_8x4[1]),
        .result_mv(result_mv_8x4[1])
    );

    fs_comparator#(SAD_8X8_W) comparator_8x8 (
        .clk(clk),
        .clear(row_idx_8x8 < 4),
        .stall(stall_d[COMPUTER_LATENCY]),

        .input_sw_idx(rb2sw(row_idx_8x8)),
        .input_sads(sad_8x8),

        .result_valid(result_8x8_valid),
        .result_sad(result_min_8x8),
        .result_mv(result_mv_8x8)
    );

    // 16x8 comparator handles both 16x8 and 8x16 SADs
    fs_comparator#(SAD_16X8_W) comparator_16x8 (
        .clk(clk),
        .clear(sad_16x8_valid),
        .stall(stall_d[COMPUTER_LATENCY]),

        .input_sw_idx(sw_idx_16x8),
        .input_sads(sad_16x8),

        .result_valid(result_16x8_valid),
        .result_sad(result_min_16x8),
        .result_mv(result_mv_16x8)
    );

    fs_comparator#(SAD_16X16_W) comparator_16x16 (
        .clk(clk),
        .clear(sad_16x16_valid),
        .stall(stall_d[COMPUTER_LATENCY]),

        .input_sw_idx(sw_idx_16x16),
        .input_sads(sad_16x16),

        .result_valid(result_16x16_valid),
        .result_sad(result_min_16x16),
        .result_mv(result_mv_16x16)
    );

    always_comb begin
        rb_d = rb_q;
        rb_has_data_d = rb_has_data_q;
        cb_d = cb_q;
        cb_has_data_d = cb_has_data_q;
        rb_row_idx_d = rb_row_idx_q;
        cb_subblock_idx_d = cb_subblock_idx_q;

        // For the first four rows, stream CB and RB simultaneously.
        for (int i = 1; i < COMPUTER_LATENCY; i++) stall_d[i] = stall_q[i-1];
        if (rb_row_idx_q < 4) begin
            stall_d[0] = !(cb_has_data_q && rb_has_data_q);
        end else begin
            stall_d[0] = rb_has_data_q;
        end

        // We need data when we are not stalled and when we don't have data
        rb_ready = !stall_d[0] || !rb_has_data_q;
        cb_ready = !stall_d[0] || !cb_has_data_q;

        // Handshake and buffer data from the stream.
        if (rb_ready && rb_valid) begin
            rb_d = rb;
            rb_has_data_d = 1;
        end

        if (cb_ready && cb_valid) begin
            cb_d = cb;
            cb_has_data_d = 1;
        end
        
        // Drive data if we are not stalled.
        if (!stall_d[0]) begin
            assert(cb_has_data_q);
            assert(rb_has_data_q);
            cb_has_data_d = 0;
            rb_has_data_d = 0;

            // Update the row index, then the subblock index if necessary.
            rb_row_idx_d = rb_row_idx_q + 1;
            if (rb_row_idx_d == 0) cb_subblock_idx_d = cb_subblock_idx_q + 1;
        end

        // Save the output results of the SAD computation.
        min_8x4_d   = min_8x4_q;
        mv_8x4_d    = mv_8x4_q;
        min_8x8_d   = min_8x8_q;
        mv_8x8_d    = mv_8x8_q;
        min_8x16_d  = min_8x16_q;
        mv_8x16_d   = mv_8x16_q;
        min_16x8_d  = min_16x8_q;
        mv_16x8_d   = mv_16x8_q;
        min_16x16_d = min_16x16_q;
        mv_16x16_d  = mv_16x16_q;

        if (result_8x4_valid[0]) begin
            min_8x4_d[2*(cb_subblock_idx_q-1)] = result_min_8x4[0];
            mv_8x4_d[2*(cb_subblock_idx_q-1)] = result_mv_8x4[0];
        end

        if (result_8x4_valid[1]) begin
            min_8x4_d[2*(cb_subblock_idx_q-1)+1] = result_min_8x4[1];
            mv_8x4_d[2*(cb_subblock_idx_q-1)+1] = result_mv_8x4[1];
        end

        if (result_8x8_valid) begin
            min_8x8_d[cb_subblock_idx_q-1] = result_min_8x8;
            mv_8x8_d[cb_subblock_idx_q-1] = result_mv_8x8;
        end

        if (result_16x8_valid) begin
            case (cb_subblock_idx_q)
                2'd0: begin
                    min_16x8_d[1] = result_min_16x8;
                    mv_16x8_d[1] = result_mv_16x8;
                end
                2'd1: begin
                    min_8x16_d[0] = result_min_16x8;
                    mv_8x16_d[0] = result_mv_16x8;
                end
                2'd2: begin
                    min_8x16_d[1] = result_min_16x8;
                    mv_8x16_d[1] = result_mv_16x8;
                end
                2'd3: begin
                    min_16x8_d[0] = result_min_16x8;
                    mv_16x8_d[0] = result_mv_16x8;
                end
            endcase
        end

        if (result_16x16_valid) begin
            min_16x16_d = result_min_16x16;
            mv_16x16_d = result_mv_16x16;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (rst_n) begin
			rb_q <= '0;
            rb_has_data_q <= '0;
			for (int i = 0; i < 4; i++) cb_q[i] <= '0;
            cb_has_data_q <= '0;

			rb_row_idx_q <= '0;
			cb_subblock_idx_q <= '0;

			for (int i = 0; i < 8; i++) min_8x4_q [i] <= '0;
			for (int i = 0; i < 4; i++) min_8x8_q [i] <= '0;
			for (int i = 0; i < 2; i++) min_8x16_q[i] <= '0;
			for (int i = 0; i < 2; i++) min_16x8_q[i] <= '0;
			min_16x16_q <= '0;

			for (int i = 0; i < 8; i++) mv_8x4_q [i] <= '{default: '0};
			for (int i = 0; i < 4; i++) mv_8x8_q [i] <= '{default: '0};
			for (int i = 0; i < 2; i++) mv_8x16_q[i] <= '{default: '0};
			for (int i = 0; i < 2; i++) mv_16x8_q[i] <= '{default: '0};
			mv_16x16_q <= '{default: '0};

            for (int i = 0; i < COMPUTER_LATENCY; i++) stall_q[i] <= '0;
        end else begin
			rb_q <= rb_d;
            rb_has_data_q <= rb_has_data_d;
			cb_q <= cb_d;
            cb_has_data_q <= cb_has_data_d;

			rb_row_idx_q <= rb_row_idx_d;
			cb_subblock_idx_q <= cb_subblock_idx_d;

			min_8x4_q <= min_8x4_d;
			mv_8x4_q <= mv_8x4_d;
			min_8x8_q <= min_8x8_d;
			mv_8x8_q <= mv_8x8_d;
			min_8x16_q <= min_8x16_d;
			mv_8x16_q <= mv_8x16_d;
			min_16x8_q <= min_16x8_d;
			mv_16x8_q <= mv_16x8_d;
			min_16x16_q <= min_16x16_d;
			mv_16x16_q <= mv_16x16_d;

            stall_q <= stall_d;
        end
    end

    always_comb begin
        results.min_sad_4x4 = '0;
        results.min_sad_4x8 = '0;
        results.min_sad_8x4 = min_8x4_q;
        results.min_sad_8x8 = min_8x8_q;
        results.min_sad_8x16 = min_8x16_q;
        results.min_sad_16x8 = min_16x8_q;
        results.min_sad_16x16 = min_16x16_q;

        results.mv_4x4 = '0;
        results.mv_4x8 = '0;
        results.mv_8x4 = mv_8x4_q;
        results.mv_8x8 = mv_8x8_q;
        results.mv_8x16 = mv_8x16_q;
        results.mv_16x8 = mv_16x8_q;
        results.mv_16x16 = mv_16x16_q;
    end

endmodule
