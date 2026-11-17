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

module fs_computer import me_pkg::*; (
    input logic clk,   // The primary clock
    input logic clear, // Synchronous clear signal
    input logic stall, // Stall signal

    input logic [3:0][PEL_W-1:0] cb[4],                  // Current block input (4, 4 pel rows of CB)
    input logic [WINDOW_SIZE+6:0][PEL_W-1:0] rb,         // Reference block input stream (39 pel row of RB)

    input logic [RB_ROW_IDX_W-1:0] rb_row_idx,           // Reference block search window offset (0..38)
    input logic [1:0] subcycle_idx,                      // Index into the current subcycle (0..3)

    output logic sad_valid,                              // Output SAD subcycle valid
    output logic [1:0] sad_subcycle_idx,                 // Output SAD subcycle index
    output logic [SW_IDX_W-1:0] sad_sw_idx,              // Output SAD search window offset (0..31)
    output logic [SAD_4X4_W-1:0] sad_4x4[4][SLICE_SIZE], // Output 4x4 row results (stride=4)
    output logic [SAD_8X4_W-1:0] sad_4x8[2][SLICE_SIZE], // Output 4x8 row results (stride=4)
    output logic [SAD_8X4_W-1:0] sad_8x4[2][SLICE_SIZE], // Output 8x4 row results (stride=4)
    output logic [SAD_8X8_W-1:0] sad_8x8[SLICE_SIZE]     // Output 8x8 row results (stride=4)
);

    // Frame pipeline buffers
    logic [WINDOW_SIZE+6:0][PEL_W-1:0] rb_q[5], rb_d[5];
    logic [3:0][PEL_W-1:0] cb_q[4][4], cb_d[4][4];

    // Output SAD hold register
    logic [SAD_4X4_W-1:0]    pe_array_sad[4][WINDOW_SIZE];
    logic [SAD_4X4_W-1:0]    sad_4x4_hold_q[4][WINDOW_SIZE], sad_4x4_hold_d[4][WINDOW_SIZE];

    // Pipeline control signals
    logic [RB_ROW_IDX_W-1:0] rb_row_idx_q, rb_row_idx_d;
    logic [1:0]              subcycle_idx_q, subcycle_idx_d;
    logic                    stall_q, stall_d;

    // Output SAD buffers and valid signal
    logic                    sad_valid_q[2],           sad_valid_d[2];
    logic [SW_IDX_W-1:0]     sad_sw_idx_q[2],          sad_sw_idx_d[2];
    logic [1:0]              sad_subcycle_idx_q[2],    sad_subcycle_idx_d[2];
    logic [SAD_4X4_W-1:0]    sad_4x4_q[4][SLICE_SIZE], sad_4x4_d[4][SLICE_SIZE];
    logic [SAD_8X4_W-1:0]    sad_4x8_q[2][SLICE_SIZE], sad_4x8_d[2][SLICE_SIZE];
    logic [SAD_8X4_W-1:0]    sad_8x4_q[2][SLICE_SIZE], sad_8x4_d[2][SLICE_SIZE];
    logic [SAD_8X8_W-1:0]    sad_8x8_q[SLICE_SIZE],    sad_8x8_d[SLICE_SIZE];

    genvar i;
    generate
        // Upper-Left (ul) - Uses 4-row delayed reference rb_q[4]
        for (i = 0; i < WINDOW_SIZE; i++) begin : g_ul
            fs_pe u_pe (
                .clk   (clk),
                .stall (stall_q),
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
                .stall (stall_q),
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
                .stall (stall_q),
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
                .stall (stall_q),
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
        stall_d = stall;
    end

    always_ff @(posedge clk) begin
        if (clear) begin
            rb_q           <= '{default: '0};
            cb_q           <= '{default: '0};
            rb_row_idx_q   <= '0;
            subcycle_idx_q <= '0;
            stall_q        <= '0;
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

// Track when a valid row is actively being sliced out of sad_4x4_hold_q
    logic sad_row_valid_d;

    always_comb begin
        // STAGE 0: Capture SAD values off the array after rows 0..7 are accumulated
        // -------------------------------------------------------------------------
        sad_row_valid_d = (!stall_q) && (rb_row_idx_q >= 7) && (subcycle_idx_q == 2'd1);

        if (sad_row_valid_d) begin
            sad_valid_d[0]        = 1'b1;
            sad_sw_idx_d[0]       = SW_IDX_W'(rb_row_idx_q - 7);
            sad_4x4_hold_d        = pe_array_sad;
            sad_subcycle_idx_d[0] = 2'd0;
        end else begin
            sad_valid_d[0]        = sad_valid_q[0] && (sad_subcycle_idx_q[0] != 2'd3);
            sad_sw_idx_d[0]       = sad_sw_idx_q[0];
            sad_4x4_hold_d        = sad_4x4_hold_q;
            sad_subcycle_idx_d[0] = sad_subcycle_idx_q[0] + 2'd1;
        end

        // STAGE 1: Compute sliced output SADs from the held 4x4 values
        // -------------------------------------------------------------------------
        sad_valid_d[1]        = sad_valid_q[0];
        sad_sw_idx_d[1]       = sad_sw_idx_q[0];
        sad_subcycle_idx_d[1] = sad_subcycle_idx_q[0];

        for (int i = 0; i < SLICE_SIZE; i++) begin
            sad_4x4_d[0][i] = sad_4x4_hold_q[0][4*i + sad_subcycle_idx_q[0]];
            sad_4x4_d[1][i] = sad_4x4_hold_q[1][4*i + sad_subcycle_idx_q[0]];
            sad_4x4_d[2][i] = sad_4x4_hold_q[2][4*i + sad_subcycle_idx_q[0]];
            sad_4x4_d[3][i] = sad_4x4_hold_q[3][4*i + sad_subcycle_idx_q[0]];

            sad_4x8_d[0][i] = sad_4x4_d[0][i] + sad_4x4_d[1][i];
            sad_4x8_d[1][i] = sad_4x4_d[2][i] + sad_4x4_d[3][i];

            sad_8x4_d[0][i] = sad_4x4_d[0][i] + sad_4x4_d[2][i];
            sad_8x4_d[1][i] = sad_4x4_d[1][i] + sad_4x4_d[3][i];

            sad_8x8_d[i]    = sad_8x4_d[0][i] + sad_8x4_d[1][i];
        end
    end

    // Buffer output SADs
    always_ff @(posedge clk) begin
        if (clear) begin
            sad_valid_q        <= '{default: '0};
            sad_sw_idx_q       <= '{default: '0};
            sad_subcycle_idx_q <= '{default: '0};
            sad_4x4_hold_q     <= '{default: '0};
            sad_4x4_q          <= '{default: '0};
            sad_4x8_q          <= '{default: '0};
            sad_8x4_q          <= '{default: '0};
            sad_8x8_q          <= '{default: '0};
        end else begin
            sad_valid_q        <= sad_valid_d;
            sad_sw_idx_q       <= sad_sw_idx_d;
            sad_subcycle_idx_q <= sad_subcycle_idx_d;
            sad_4x4_hold_q     <= sad_4x4_hold_d;
            sad_4x4_q          <= sad_4x4_d;
            sad_4x8_q          <= sad_4x8_d;
            sad_8x4_q          <= sad_8x4_d;
            sad_8x8_q          <= sad_8x8_d;
        end
    end

    // Assign output SADs
    assign sad_valid        = sad_valid_q[1];
    assign sad_sw_idx       = sad_sw_idx_q[1];
    assign sad_subcycle_idx = sad_subcycle_idx_q[1];
    assign sad_4x4          = sad_4x4_q;
    assign sad_4x8          = sad_4x8_q;
    assign sad_8x4          = sad_8x4_q;
    assign sad_8x8          = sad_8x8_q;

endmodule
