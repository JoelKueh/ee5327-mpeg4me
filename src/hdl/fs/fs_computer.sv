// fs_computer.sv
//
// Performs first-level SAD computation using four SAD PE arrays.
// Computes all 4x4, 4x8, 8x4, and 8x8 SADs.
//
// Buffers its own output, adding a one-cycle latency to the pipeline.
//

module fs_computer (
    input logic clk,   // The primary clock
    input logic stall, // Stall signal

    input logic [7:0][me_pkg::PEL_W-1:0] cb,  // Current block input
    input logic [me_pkg::WINDOW_SIZE+6:0][me_pkg::PEL_W-1:0] rb,  // Reference block input stream

    input logic upper_half,  // Computing the upper half of a subblock or lower?
    input logic [me_pkg::RB_ROW_IDX_W-1:0] rb_row_idx,  // Reference block search window offset

    output logic sad_4x_valid, // SAD data valid signal
    output logic [me_pkg::SAD_4X4_W-1:0] sad_4x4[2][me_pkg::WINDOW_SIZE], // Buffered output 4x4 row results
    output logic [me_pkg::SAD_8X4_W-1:0] sad_4x8[me_pkg::WINDOW_SIZE],    // Buffered output 4x8 row results

    output logic sad_8x_valid, // SAD data valid signal
    output logic [me_pkg::SAD_8X4_W-1:0] sad_8x4[2][me_pkg::WINDOW_SIZE], // Buffered output 8x4 row results
    output logic [me_pkg::SAD_8X8_W-1:0] sad_8x8[me_pkg::WINDOW_SIZE],    // Buffered output 8x8 row results
    output logic [me_pkg::SW_IDX_W-1:0] sad_sw_idx  // SAD search window offset
);

    import me_pkg::*;

    // Buffer only the reference block at the comptuer level
    // Buffer control signals and the cb at the array/row level


    // Stage 0: Buffered Reference Block
    logic [WINDOW_SIZE+6:0][PEL_W-1:0] rb_q, rb_d;

    // Stage 1: Internal PE Array Buffers

    // Stage 2: Buffered SAD outputs
    logic [SAD_4X4_W-1:0] sad_4x4_q[2][WINDOW_SIZE], sad_4x4_d[2][WINDOW_SIZE];
    logic [SAD_8X4_W-1:0] sad_4x8_q[WINDOW_SIZE], sad_4x8_d[WINDOW_SIZE];
    logic [SAD_8X4_W-1:0] sad_8x4_q[2][WINDOW_SIZE], sad_8x4_d[2][WINDOW_SIZE];
    logic [SAD_8X8_W-1:0] sad_8x8_q[WINDOW_SIZE], sad_8x8_d[WINDOW_SIZE];

    // Pipeline control tracking across S0, S1 (PE), and S2 (Output)

    logic upper_half_q[3], upper_half_d[3];
    logic [SW_IDX_W-1:0] sad_sw_idx_q[3], sad_sw_idx_d[3];
    logic stage0_valid_q, stage0_valid_d;
    logic stage1_valid_q, stage1_valid_d;
    logic sad_valid_q, sad_valid_d;
    logic stall_q[2], stall_d[2];

    // Instantiate 4 4x4_SAD PE arrays arranged as a full 8x8 block
    fs_pe_array pe_array_l (
        .clk(clk),
        .load(rb_row_idx < 4),
        .stall_next(stall),
        .row_idx_mod_next(rb_row_idx[1:0]),
        .rb(rb_q[WINDOW_SIZE+2:0]),
        .cb_next(cb[3:0]),
        .sad(sad_4x4_d[0])
    );

    fs_pe_array pe_array_r (
        .clk(clk),
        .load(rb_row_idx < 4),
        .stall_next(stall),
        .row_idx_mod_next(rb_row_idx[1:0]),
        .rb(rb_q[WINDOW_SIZE+6:4]),
        .cb_next(cb[7:4]),
        .sad(sad_4x4_d[1])
    );

    // Instantiate RAMs to hold the SAD values from the upper two rows.
    sram_if #(.ADDR_W(SW_IDX_W), .DATA_W(WINDOW_SIZE * SAD_4X4_W)) ram_a_if ();
    sram_if #(.ADDR_W(SW_IDX_W), .DATA_W(WINDOW_SIZE * SAD_4X4_W)) ram_b_if ();

    sram_wrapper #(
        .ADDR_W(SW_IDX_W),
        .DATA_W(WINDOW_SIZE * SAD_4X4_W)
    ) ram_a (
        clk,
        ram_a_if
    );

    sram_wrapper #(
        .ADDR_W(SW_IDX_W),
        .DATA_W(WINDOW_SIZE * SAD_4X4_W)
    ) ram_b (
        clk,
        ram_b_if
    );

    always_comb begin
        // Prevent latches on rams
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

        // Stage 1: Save to RAM when PE output (sad_4x4_d) is valid for the upper half
        if (!stall_q[1] && upper_half_q[1] && stage1_valid_q) begin
            ram_a_if.wr_en   = 1'b1;
            ram_a_if.wr_addr = sad_sw_idx_q[1];
            for (int col = 0; col < WINDOW_SIZE; col++) begin
                ram_a_if.wr_data[col*SAD_4X4_W +: SAD_4X4_W] = sad_4x4_d[0][col];
            end

            ram_b_if.wr_en   = 1'b1;
            ram_b_if.wr_addr = sad_sw_idx_q[1];
            for (int col = 0; col < WINDOW_SIZE; col++) begin
                ram_b_if.wr_data[col*SAD_4X4_W +: SAD_4X4_W] = sad_4x4_d[1][col];
            end
        end

        // Stage 0: Retrieve from RAM one cycle before sad_4x4_d is valid
        // so rd_data arrives in Stage 1 alongside sad_4x4_d
        if (!stall_q[0] && !upper_half_q[0] && stage0_valid_q) begin
            ram_a_if.rd_en   = 1'b1;
            ram_a_if.rd_addr = sad_sw_idx_q[0];

            ram_b_if.rd_en   = 1'b1;
            ram_b_if.rd_addr = sad_sw_idx_q[0];
        end
    end

    always_comb begin
        stall_d[0] = stall;
        stall_d[1] = stall_q[0];

        // Stage 0 inputs (aligned with rb_q)
        rb_d            = rb;
        stage0_valid_d  = (rb_row_idx >= 3);
        upper_half_d[0] = upper_half;
        sad_sw_idx_d[0] = SW_IDX_W'(rb_row_idx - 3'd3);

        // Stage 1 inputs (aligned with PE acc_q / sad_4x4_d)
        stage1_valid_d  = stage0_valid_q;
        upper_half_d[1] = upper_half_q[0];
        sad_sw_idx_d[1] = sad_sw_idx_q[0];

        // Stage 2 inputs (aligned with buffered outputs sad_4x4_q..sad_8x8_q)
        sad_valid_d     = stage1_valid_q;
        upper_half_d[2] = upper_half_q[1];
        sad_sw_idx_d[2] = sad_sw_idx_q[1];

        // Compute the 4x8, 8x4 and 8x8 results in one cycle
        for (int col = 0; col < WINDOW_SIZE; col++) begin
            sad_4x8_d[col] = sad_4x4_d[0][col] + sad_4x4_d[1][col];
        end

        // Compute the 8x4 and 8x8 SADs from the inputs and RAM
        for (int col = 0; col < WINDOW_SIZE; col++) begin
            sad_8x4_d[0][col] = sad_4x4_d[0][col] + ram_a_if.rd_data[col*SAD_4X4_W +: SAD_4X4_W];
            sad_8x4_d[1][col] = sad_4x4_d[1][col] + ram_b_if.rd_data[col*SAD_4X4_W +: SAD_4X4_W];

            sad_8x8_d[col] = sad_8x4_d[0][col] + sad_8x4_d[1][col];
        end
    end

    // Buffer the output of the 4x4 PE arrays
    always_ff @(posedge clk) begin
        stall_q <= stall_d;

        // Stage 0 registers (buffered input level)
        if (!stall) begin
            rb_q            <= rb_d;
            stage0_valid_q  <= stage0_valid_d;
            upper_half_q[0] <= upper_half_d[0];
            sad_sw_idx_q[0] <= sad_sw_idx_d[0];
        end

        // Stage 1 control registers (aligned with fs_pe acc_q which stalls on stall_q)
        if (!stall_q[0]) begin
            stage1_valid_q  <= stage1_valid_d;
            upper_half_q[1] <= upper_half_d[1];
            sad_sw_idx_q[1] <= sad_sw_idx_d[1];
        end

        // Stage 2 output registers
        if (!stall_q[1]) begin
            sad_4x4_q       <= sad_4x4_d;
            sad_4x8_q       <= sad_4x8_d;
            sad_8x4_q       <= sad_8x4_d;
            sad_8x8_q       <= sad_8x8_d;
            sad_valid_q     <= sad_valid_d;
            upper_half_q[2] <= upper_half_d[2];
            sad_sw_idx_q[2] <= sad_sw_idx_d[2];
        end
    end

    // Assign the 8x4 and 8x8 output
    always_comb begin
        sad_4x_valid = sad_valid_q && !stall_q[1];
        sad_4x4      = sad_4x4_q;
        sad_4x8      = sad_4x8_q;
        sad_8x_valid = sad_4x_valid && !upper_half_q[2];
        sad_8x4      = sad_8x4_q;
        sad_8x8      = sad_8x8_q;
        sad_sw_idx   = sad_sw_idx_q[2];
    end

endmodule
