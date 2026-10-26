// fs_computer.sv
//
// Performs first-level SAD computation using four SAD PE arrays.
// Computes all 4x4, 4x8, 8x4, and 8x8 SADs.
//
// Buffers its own output, adding a one-cycle latency to the pipeline.
//

module fs_computer (
    input logic clk,    // The primary clock

    input logic bd_valid, // Block data valid signal
    input logic upper_half,  // Computing the upper half of a subblock or lower?
    input logic [7:0][me_pkg::PEL_W-1:0] cb,  // Current block input
    input logic [me_pkg::WINDOW_SIZE+6:0][me_pkg::PEL_W-1:0] rb,  // Reference block input stream
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

    logic [SAD_4X4_W-1:0] sad_4x4_q[2][WINDOW_SIZE], sad_4x4_d[2][WINDOW_SIZE];
    logic [SAD_8X4_W-1:0] sad_4x8_q[WINDOW_SIZE], sad_4x8_d[WINDOW_SIZE];
    logic [SAD_8X4_W-1:0] sad_8x4_q[2][WINDOW_SIZE], sad_8x4_d[2][WINDOW_SIZE];
    logic [SAD_8X8_W-1:0] sad_8x8_q[WINDOW_SIZE], sad_8x8_d[WINDOW_SIZE];

    logic upper_half_q[2], upper_half_d[2];
    logic [SW_IDX_W-1:0] sad_sw_idx_q[2], sad_sw_idx_d[2];
    logic sad_valid_q, sad_valid_d;
    logic stage0_valid_q, stage0_valid_d;

    // Instantiate 4 4x4_SAD PE arrays arranged as a full 8x8 block
    fs_pe_array pe_array_l (
        .clk(clk),
        .stall(!bd_valid),
        .load(rb_row_idx < 4),
        .row_idx_mod(rb_row_idx[1:0]),
        .rb(rb[WINDOW_SIZE+2:0]),
        .cb(cb[3:0]),
        .sad(sad_4x4_d[0])
    );

    fs_pe_array pe_array_r (
        .clk(clk),
        .stall(!bd_valid),
        .load(rb_row_idx < 4),
        .row_idx_mod(rb_row_idx[1:0]),
        .rb(rb[WINDOW_SIZE+6:4]),
        .cb(cb[7:4]),
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

        stage0_valid_d = bd_valid && (rb_row_idx >= 3);
        if (bd_valid) begin
            upper_half_d[0] = upper_half;
            sad_sw_idx_d[0] = SW_IDX_W'(rb_row_idx - 3'd3);
        end
        
        sad_valid_d = stage0_valid_q;
        if (stage0_valid_q) begin
            upper_half_d[1] = upper_half_q[0];
            sad_sw_idx_d[1] = sad_sw_idx_q[0];
        end

        // Compute the 4x8, 8x4 and 8x8 results in one cycle
        for (int col = 0; col < WINDOW_SIZE; col++) begin
            sad_4x8_d[col] = sad_4x4_d[0][col] + sad_4x4_d[1][col];
        end

        // Prevent latches on rams
        ram_a_if.wr_en = '0;
        ram_a_if.wr_addr = 'x;
        ram_a_if.wr_data = 'x;
        ram_a_if.rd_en = '0;
        ram_a_if.rd_addr = 'x;

        ram_b_if.wr_en = '0;
        ram_b_if.wr_addr = 'x;
        ram_b_if.wr_data = 'x;
        ram_b_if.rd_en = '0;
        ram_b_if.rd_addr = 'x;

        // Save to RAM when computing the upper half
        if (upper_half_q[0] && sad_valid_d) begin
            ram_a_if.wr_en = 1;
            ram_a_if.wr_addr = sad_sw_idx_q[0];
            for (int col = 0; col < WINDOW_SIZE; col++) begin
                ram_a_if.wr_data[col*SAD_4X4_W +: SAD_4X4_W] = sad_4x4_d[0][col];
            end

            ram_b_if.wr_en = 1;
            ram_b_if.wr_addr = sad_sw_idx_q[0];
            for (int col = 0; col < WINDOW_SIZE; col++) begin
                ram_b_if.wr_data[col*SAD_4X4_W +: SAD_4X4_W] = sad_4x4_d[1][col];
            end
        end

        // Retrieve from RAM when computing the lower half
        // Send read one cycle early so data arrives simultaneously
        if (!upper_half && bd_valid && (rb_row_idx >= 3)) begin
            ram_a_if.rd_en = 1;
            ram_a_if.rd_addr = SW_IDX_W'(rb_row_idx - 3'd3);

            ram_b_if.rd_en = 1;
            ram_b_if.rd_addr = SW_IDX_W'(rb_row_idx - 3'd3);
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
        sad_4x4_q <= sad_4x4_d;
        sad_4x8_q <= sad_4x8_d;
        sad_8x4_q <= sad_8x4_d;
        sad_8x8_q <= sad_8x8_d;
        upper_half_q <= upper_half_d;
        sad_sw_idx_q <= sad_sw_idx_d;
        sad_valid_q <= sad_valid_d;
        stage0_valid_q <= stage0_valid_d;
    end

    // Assign the 8x4 and 8x8 output
    always_comb begin
        sad_4x_valid = sad_valid_q;
        sad_4x4 = sad_4x4_q;
        sad_4x8 = sad_4x8_q;
        sad_8x_valid = sad_4x_valid && !upper_half_q[1];
        sad_8x4 = sad_8x4_q;
        sad_8x8 = sad_8x8_q;
        sad_sw_idx = sad_sw_idx_q[1];
    end

endmodule
