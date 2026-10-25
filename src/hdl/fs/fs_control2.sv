// fs_control.sv
//
// Control module for the full search motion estimation system.
//

module fs_control (
    input logic clk,   // The primary clock
    input logic rst_n, // Asynchronous negative reset

    // Reference block is streamed into the control model in Morton order.
    output logic rb_ready,  // Reference block ready signal
    input logic rb_valid,  // Reference block data valid signal
    input logic [me_pkg::WINDOW_SIZE+6:0][me_pkg::PEL_W-1:0] rb,  // Reference block input stream

    // Current block is also streamed in Morton order.
    output logic                          cb_ready,    // Current block ready signal
    input  logic                          cb_valid,    // Current block data valid signal
    input  logic [3:0][me_pkg::PEL_W-1:0] cb      [4], // Current block input

    // Winning SAD computations for the current block.
    sad_result_if.source results
);

    import me_pkg::*;

    parameter int COMPUTER_LATENCY = 9;

    // Input data buffers
    logic [WINDOW_SIZE+6:0][PEL_W-1:0] rb_q, rb_d;
    logic rb_has_data_q, rb_has_data_d;
    logic [3:0][PEL_W-1:0] cb_q[4], cb_d[4];
    logic cb_has_data_q, cb_has_data_d;

    fs_computer computer(
        .clk(clk),
        .stall(!rb_has_data_q || !cb_has_data_q),
    
        .cb(cb_q),
        .rb(rb_q),
        .rb_row_idx(rb_row_idx_q),
    
        .sad_8x4,
        .sad_8x8,
        .sad_row_idx,
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
            assert (cb_has_data_q);
            assert (rb_has_data_q);
            cb_has_data_d = 0;
            rb_has_data_d = 0;

            // Update the row index, then the subblock index if necessary.
            rb_row_idx_d  = rb_row_idx_q + 1;
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
            mv_8x4_d[2*(cb_subblock_idx_q-1)]  = result_mv_8x4[0];
        end

        if (result_8x4_valid[1]) begin
            min_8x4_d[2*(cb_subblock_idx_q-1)+1] = result_min_8x4[1];
            mv_8x4_d[2*(cb_subblock_idx_q-1)+1]  = result_mv_8x4[1];
        end

        if (result_8x8_valid) begin
            min_8x8_d[cb_subblock_idx_q-1] = result_min_8x8;
            mv_8x8_d[cb_subblock_idx_q-1]  = result_mv_8x8;
        end

        if (result_16x8_valid) begin
            case (cb_subblock_idx_q)
                2'd0: begin
                    min_16x8_d[1] = result_min_16x8;
                    mv_16x8_d[1]  = result_mv_16x8;
                end
                2'd1: begin
                    min_8x16_d[0] = result_min_16x8;
                    mv_8x16_d[0]  = result_mv_16x8;
                end
                2'd2: begin
                    min_8x16_d[1] = result_min_16x8;
                    mv_8x16_d[1]  = result_mv_16x8;
                end
                2'd3: begin
                    min_16x8_d[0] = result_min_16x8;
                    mv_16x8_d[0]  = result_mv_16x8;
                end
            endcase
        end

        if (result_16x16_valid) begin
            min_16x16_d = result_min_16x16;
            mv_16x16_d  = result_mv_16x16;
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

            for (int i = 0; i < 8; i++) min_8x4_q[i] <= '0;
            for (int i = 0; i < 4; i++) min_8x8_q[i] <= '0;
            for (int i = 0; i < 2; i++) min_8x16_q[i] <= '0;
            for (int i = 0; i < 2; i++) min_16x8_q[i] <= '0;
            min_16x16_q <= '0;

            for (int i = 0; i < 8; i++) mv_8x4_q[i] <= '{default: '0};
            for (int i = 0; i < 4; i++) mv_8x8_q[i] <= '{default: '0};
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
        for (int i = 0; i < 16; i++) results.min_sad_4x4[i] = '0;
        for (int i = 0; i < 8; i++) results.min_sad_4x8[i] = '0;
        results.min_sad_8x4   = min_8x4_q;
        results.min_sad_8x8   = min_8x8_q;
        results.min_sad_8x16  = min_8x16_q;
        results.min_sad_16x8  = min_16x8_q;
        results.min_sad_16x16 = min_16x16_q;

        for (int i = 0; i < 16; i++) results.mv_4x4[i] = '0;
        for (int i = 0; i < 8; i++) results.mv_4x8[i] = '0;
        results.mv_8x4 = mv_8x4_q;
        results.mv_8x8 = mv_8x8_q;
        results.mv_8x16 = mv_8x16_q;
        results.mv_16x8 = mv_16x8_q;
        results.mv_16x16 = mv_16x16_q;

        results.valid = result_16x16_valid;
    end

endmodule
