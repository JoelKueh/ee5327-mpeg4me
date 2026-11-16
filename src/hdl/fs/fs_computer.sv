// fs_computer.sv
//
// Performs first-level SAD computation using four SAD PE arrays.
// Computes all 4x4, 4x8, 8x4, and 8x8 SADs.
//
// Invariant 1:
// rb_row_idx_q and subcycle_idx_q hold the row index currently being
// driven to the PE arrays.
//
// Invariant 2:
// When rb_row_idx_q>=7 and subcycle_idx_q==2 is driven to the PE arrays,
// the 4x output corresponding to sad_sw_idx==0 is valid.
//

module fs_computer (
    input logic clk,   // The primary clock
    input logic clear, // Synchronous clear signal
    input logic stall, // Stall signal

    input logic [3:0][me_pkg::PEL_W-1:0] cb[4],                   // Current block input (4, 4 pel rows of CB)
    input logic [me_pkg::WINDOW_SIZE+6:0][me_pkg::PEL_W-1:0] rb,  // Reference block input stream (39 pel row of RB)

    input logic [me_pkg::RB_ROW_IDX_W-1:0] rb_row_idx,  // Reference block search window offset (0..38)
    input logic [1:0] subcycle_idx,                     // Index into the current subcycle (0..3)

    output logic sad_valid,                                               // Output SADs valid
    output logic [me_pkg::SW_IDX_W-1:0] sad_sw_idx,                       // SAD search window offset (0..31)
    output logic [me_pkg::SAD_4X4_W-1:0] sad_4x4[4][me_pkg::WINDOW_SIZE], // Output 4x4 row results
    output logic [me_pkg::SAD_8X4_W-1:0] sad_4x8[2][me_pkg::WINDOW_SIZE], // Output 4x8 row results
    output logic [me_pkg::SAD_8X4_W-1:0] sad_8x4[2][me_pkg::WINDOW_SIZE], // Output 8x4 row results
    output logic [me_pkg::SAD_8X8_W-1:0] sad_8x8[me_pkg::WINDOW_SIZE]     // Output 8x8 row results
);

    import me_pkg::*;

    // Frame pipeline buffers and array stall signal
    logic [WINDOW_SIZE+6:0][PEL_W-1:0] rb_q[5], rb_d[5];
    logic [3:0][me_pkg::PEL_W-1:0] cb_q[4][4], cb_d[4][4];
    logic [me_pkg::RB_ROW_IDX_W-1:0] rb_row_idx_q, rb_row_idx_d;
    logic [1:0] subcycle_idx_q, subcycle_idx_d;
    logic stall_q[16], stall_d[16];

    // Array SAD outputs
    logic [me_pkg::SAD_4X4_W-1:0] pe_array_sad[4][me_pkg::WINDOW_SIZE];

    // Output SAD buffers and valid signal
    logic sad_valid_q, sad_valid_d;
    logic [me_pkg::SW_IDX_W-1:0]  sad_sw_idx_q, sad_sw_idx_d;
    logic [me_pkg::SAD_4X4_W-1:0] sad_4x4_q[4][me_pkg::WINDOW_SIZE], sad_4x4_d[4][me_pkg::WINDOW_SIZE];
    logic [me_pkg::SAD_8X4_W-1:0] sad_4x8_q[2][me_pkg::WINDOW_SIZE], sad_4x8_d[2][me_pkg::WINDOW_SIZE];
    logic [me_pkg::SAD_8X4_W-1:0] sad_8x4_q[2][me_pkg::WINDOW_SIZE], sad_8x4_d[2][me_pkg::WINDOW_SIZE];
    logic [me_pkg::SAD_8X8_W-1:0] sad_8x8_q[me_pkg::WINDOW_SIZE],    sad_8x8_d[me_pkg::WINDOW_SIZE];

    genvar i;
    generate
        // Upper-Left (ul) - Uses 4-row delayed reference rb_q[4]
        for (i = 0; i < WINDOW_SIZE; i++) begin : g_ul
            fs_pe u_pe (
                .clk   (clk),
                .stall (stall_q[0 + i/8]),
                .clear (subcycle_idx_q == 2'd3),
                .rb    (rb_q[4][i +: 4]),
                .cb    (cb_q[0][0]),
                .sad   (pe_array_sad[0][i])
            );
        end

        // Upper-Right (ur) - Uses 4-row delayed reference rb_q[4]
        for (i = 0; i < WINDOW_SIZE; i++) begin : g_ur
            fs_pe u_pe (
                .clk   (clk),
                .stall (stall_q[4 + i/8]),
                .clear (subcycle_idx_q == 2'd3),
                .rb    (rb_q[4][(i + 4) +: 4]),
                .cb    (cb_q[1][0]),
                .sad   (pe_array_sad[1][i])
            );
        end

        // Lower-Left (ll) - Computes on rb_q[0]
        for (i = 0; i < WINDOW_SIZE; i++) begin : g_ll
            fs_pe u_pe (
                .clk   (clk),
                .stall (stall_q[8 + i/8]),
                .clear (subcycle_idx_q == 2'd3),
                .rb    (rb_q[0][i +: 4]),
                .cb    (cb_q[2][0]),
                .sad   (pe_array_sad[2][i])
            );
        end

        // Lower-Right (lr) - Computes on rb_q[0]
        for (i = 0; i < WINDOW_SIZE; i++) begin : g_lr
            fs_pe u_pe (
                .clk   (clk),
                .stall (stall_q[12 + i/8]),
                .clear (subcycle_idx_q == 2'd3),
                .rb    (rb_q[0][(i + 4) +: 4]),
                .cb    (cb_q[3][0]),
                .sad   (pe_array_sad[3][i])
            );
        end
    endgenerate

    always_comb begin
        // Advance rb pipeline delay register
        for (int i = 1; i < 5; i++) rb_d[i] = subcycle_idx_q == 2'd3 ? rb_q[i-1] : rb_q[i];
        rb_d[0] = rb;

        // Advance cb circular shift register
        for (int i = 0; i < 4; i++) begin
            for (int j = 1; j < 4; j++) cb_d[i][j] = cb_q[i][j-1];
            cb_d[i][0] = rb_row_idx < 4 ? cb[i] : cb_q[i][3];
        end

        // Assign indicies: maintain invariant 1
        rb_row_idx_d   = rb_row_idx;
        subcycle_idx_d = subcycle_idx;

        // Assign array control signal registers, these do not need to stall.
        for (int i = 0; i < 16; i++) stall_d[i] = stall;
    end

    always_ff @(posedge clk) begin
        if (clear) begin
            rb_q           <= '{default: '0};
            cb_q           <= '{default: '0};
            rb_row_idx_q   <= '0;
            subcycle_idx_q <= '0;
            stall_q        <= '{default: '0};
        end else begin
            if (!stall) begin
                rb_q           <= rb_d;
                cb_q           <= cb_d;
                rb_row_idx_q   <= rb_row_idx_d;
                subcycle_idx_q <= subcycle_idx_d;
            end
            stall_q <= stall_d;
        end

    end

	always_comb begin
        // Compute output SAD valid signal (valid when rows 0..7 are accumulated)
        sad_valid_d = (!stall_q[0]) && (rb_row_idx_q >= 7) && (subcycle_idx_q == 2'd1);

        // Compute output SADs and SW idx (both held for 4 cycles until next sad_valid_d)
        if (sad_valid_d) begin
            sad_sw_idx_d = SW_IDX_W'(rb_row_idx_q - 7);

            for (int i = 0; i < WINDOW_SIZE; i++) begin
                sad_4x4_d[0][i] = pe_array_sad[0][i];
                sad_4x4_d[1][i] = pe_array_sad[1][i];
                sad_4x4_d[2][i] = pe_array_sad[2][i];
                sad_4x4_d[3][i] = pe_array_sad[3][i];

                sad_4x8_d[0][i] = pe_array_sad[0][i] + pe_array_sad[1][i];
                sad_4x8_d[1][i] = pe_array_sad[2][i] + pe_array_sad[3][i];

                sad_8x4_d[0][i] = pe_array_sad[0][i] + pe_array_sad[2][i];
                sad_8x4_d[1][i] = pe_array_sad[1][i] + pe_array_sad[3][i];

                sad_8x8_d[i]    = sad_8x4_d[0][i] + sad_8x4_d[1][i];
            end
        end else begin
            sad_sw_idx_d = sad_sw_idx_q;
            sad_4x4_d    = sad_4x4_q;
            sad_4x8_d    = sad_4x8_q;
            sad_8x4_d    = sad_8x4_q;
            sad_8x8_d    = sad_8x8_q;
        end
    end

    // Buffer output SADs
    always_ff @(posedge clk) begin
        if (clear) begin
            sad_valid_q  <= 1'b0;
            sad_sw_idx_q <= '0;
            sad_4x4_q     <= '{default: '0};
            sad_4x8_q     <= '{default: '0};
            sad_8x4_q     <= '{default: '0};
            sad_8x8_q     <= '{default: '0};
        end else begin
            sad_valid_q  <= sad_valid_d;

            sad_sw_idx_q <= sad_sw_idx_d;
            sad_4x4_q    <= sad_4x4_d;
            sad_4x8_q    <= sad_4x8_d;
            sad_8x4_q    <= sad_8x4_d;
            sad_8x8_q    <= sad_8x8_d;
        end
    end

    // Assign output SADs
    assign sad_valid  = sad_valid_q;
    assign sad_sw_idx = sad_sw_idx_q;
    assign sad_4x4    = sad_4x4_q;
    assign sad_4x8    = sad_4x8_q;
    assign sad_8x4    = sad_8x4_q;
    assign sad_8x8    = sad_8x8_q;

endmodule
