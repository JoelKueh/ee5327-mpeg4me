// fs_combiner.sv
//
// Combines SAD reults from the previous level 
//

module fs_combiner (
    input logic clk,  // The primary clock
    input logic clear_in,  // Pipelined clear signal input
    output logic clear_out,  // Pipelined clear signal output

    input logic sad_8x8_valid,  // Input SADs valid signal
    input logic sad_8x8_last,  // Input SAD last signal
    input logic [1:0] sb_idx_8x8,  // Subblock index of the input sads
    input logic [me_pkg::SW_IDX_W-1:0] sw_idx_8x8,  // Window index of the input SADs
    input logic [me_pkg::SAD_8X8_W-1:0] sad_8x8[me_pkg::WINDOW_SIZE],  // Input SADs

    output logic sad_16x8_valid,  // 16x8 SAD valid signal.
    output logic sad_16x8_last,  // 16x8 SAD last signal
    output me_pkg::comb_sad_id_t sad_16x8_id,  // 16x8 SAD subblock ids.
    output logic [me_pkg::SW_IDX_W-1:0] sw_idx_16x8,  // SAD search window offset
    output logic [me_pkg::SAD_16X8_W-1:0] sad_16x8[me_pkg::WINDOW_SIZE],  // Output port for 16x8 and 8x16 SAD

    output logic sad_16x16_valid,  // 16x16 SAD valid signal
    output logic sad_16x16_last,  // 16x16 SAD last signal
    output logic [1:0] sb_idx_16x16,  // 16x16 SAD subblock indicies
    output logic [me_pkg::SW_IDX_W-1:0] sw_idx_16x16,  // SAD search window offset
    output logic [me_pkg::SAD_16X16_W-1:0] sad_16x16[me_pkg::WINDOW_SIZE]  // 16x16 SAD
);

    import me_pkg::*;

    sram_if #(.ADDR_W(SW_IDX_W), .DATA_W(WINDOW_SIZE * SAD_8X8_W))  ram_a_if ();
    sram_if #(.ADDR_W(SW_IDX_W), .DATA_W(WINDOW_SIZE * SAD_8X8_W))  ram_b_if ();
    sram_if #(.ADDR_W(SW_IDX_W), .DATA_W(WINDOW_SIZE * SAD_16X8_W)) ram_c_if ();

    sram_wrapper #(
        .ADDR_W(SW_IDX_W),
        .DATA_W(WINDOW_SIZE * SAD_8X8_W)
    ) ram_a (
        clk,
        ram_a_if
    );

    sram_wrapper #(
        .ADDR_W(SW_IDX_W),
        .DATA_W(WINDOW_SIZE * SAD_8X8_W)
    ) ram_b (
        clk,
        ram_b_if
    );

    sram_wrapper #(
        .ADDR_W(SW_IDX_W),
        .DATA_W(WINDOW_SIZE * SAD_16X8_W)
    ) ram_c (
        clk,
        ram_c_if
    );

    logic [SAD_8X8_W-1:0] sad_8x8_q[WINDOW_SIZE], sad_8x8_d[WINDOW_SIZE];
    logic [SAD_16X8_W-1:0] sad_16x8_q[WINDOW_SIZE], sad_16x8_d[WINDOW_SIZE];
    logic [SAD_16X16_W-1:0] sad_16x16_q[WINDOW_SIZE], sad_16x16_d[WINDOW_SIZE];

    logic [1:0] sb_idx_16x16_q, sb_idx_16x16_d;

    logic [1:0] sb_idx_q[3], sb_idx_d[3];
    logic [SW_IDX_W-1:0] sw_idx_q[3], sw_idx_d[3];
    logic sad_last_q[3], sad_last_d[3];
    logic sad_valid_q[3], sad_valid_d[3];
    logic first_sb_q[3], first_sb_d[3];

    logic clear_q;

    always_comb begin
        // Update pipeline registers
        for (int i = 0; i < WINDOW_SIZE; i++) sad_8x8_d[i] = 'x;
        for (int i = 0; i < WINDOW_SIZE; i++) sad_16x8_d[i] = 'x;
        for (int i = 0; i < WINDOW_SIZE; i++) sad_16x16_d[i] = 'x;

        sb_idx_16x16_d = sb_idx_16x16_q;

        sad_valid_d[0] = sad_8x8_valid;
        sad_valid_d[1] = sad_valid_q[0];
        sad_valid_d[2] = sad_valid_q[1];

        sb_idx_d[0] = 'x;
        sb_idx_d[1] = sb_idx_q[0];
        sb_idx_d[2] = sb_idx_q[1];

        sw_idx_d[0] = 'x;
        sw_idx_d[1] = sw_idx_q[0];
        sw_idx_d[2] = sw_idx_q[1];

        sad_last_d[0] = 'x;
        sad_last_d[1] = sad_last_q[0];
        sad_last_d[2] = sad_last_q[1];

        first_sb_d[0] = first_sb_q[0] && !(sad_valid_q[0] && sad_last_q[0]);
        first_sb_d[1] = first_sb_q[0];
        first_sb_d[2] = first_sb_q[1];

        // Get the valid 8x8 SAD from the input
        if (sad_8x8_valid) begin
            sad_last_d[0] = sad_8x8_last;
            sb_idx_d[0] = sb_idx_8x8;
            sw_idx_d[0] = sw_idx_8x8;
            sad_8x8_d = sad_8x8;
        end

        // Prevent latches on RAM inputs
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

        ram_c_if.wr_en = '0;
        ram_c_if.wr_addr = 'x;
        ram_c_if.wr_data = 'x;
        ram_c_if.rd_en = '0;
        ram_c_if.rd_addr = 'x;

        // Prepare write/read commands for RAM_A and RAM_B
        case (sb_idx_8x8)
            2'd0: begin
                // Write the current SAD data to the A write port.
                ram_a_if.wr_en   = sad_8x8_valid;
                ram_a_if.wr_addr = sw_idx_8x8;
                for (int i = 0; i < WINDOW_SIZE; i++) begin
                    ram_a_if.wr_data[i*SAD_8X8_W+:SAD_8X8_W] = sad_8x8[i];
                end

                // Produce an 8x16 SAD from RAM B and RAM A.
                ram_a_if.rd_en   = sad_8x8_valid;
                ram_a_if.rd_addr = sw_idx_8x8;
                ram_b_if.rd_en   = sad_8x8_valid;
                ram_b_if.rd_addr = sw_idx_8x8;
            end
            2'd1: begin
                // Write the current SAD data to the B write port.
                ram_b_if.wr_en   = sad_8x8_valid;
                ram_b_if.wr_addr = sw_idx_8x8;
                for (int i = 0; i < WINDOW_SIZE; i++) begin
                    ram_b_if.wr_data[i*SAD_8X8_W+:SAD_8X8_W] = sad_8x8[i];
                end

                // Produce an 8x16 SAD from RAM A and the input.
                ram_a_if.rd_en   = sad_8x8_valid;
                ram_a_if.rd_addr = sw_idx_8x8;
            end
            2'd2: begin
                // Write the current SAD data to the A write port.
                ram_a_if.wr_en   = sad_8x8_valid;
                ram_a_if.wr_addr = sw_idx_8x8;
                for (int i = 0; i < WINDOW_SIZE; i++) begin
                    ram_a_if.wr_data[i*SAD_8X8_W+:SAD_8X8_W] = sad_8x8[i];
                end

                // Produce a 16x8 SAD from RAM A and the input.
                ram_a_if.rd_en   = sad_8x8_valid;
                ram_a_if.rd_addr = sw_idx_8x8;
            end
            2'd3: begin
                // Write the current SAD data to the B write port.
                ram_b_if.wr_en   = sad_8x8_valid;
                ram_b_if.wr_addr = sw_idx_8x8;
                for (int i = 0; i < WINDOW_SIZE; i++) begin
                    ram_b_if.wr_data[i*SAD_8X8_W+:SAD_8X8_W] = sad_8x8[i];
                end

                // Produce a 16x8 SAD from RAM B and the input.
                ram_b_if.rd_en   = sad_8x8_valid;
                ram_b_if.rd_addr = sw_idx_8x8;
            end
        endcase

        // Compute 16x8 SADs based on results from RAM_A and RAM_B read.
        case (sb_idx_q[0])
            2'd0: begin
                // Produce an 8x16 SAD from RAM B and RAM A.
                for (int i = 0; i < WINDOW_SIZE; i++) begin
                    sad_16x8_d[i] = ram_a_if.rd_data[i*SAD_8X8_W+:SAD_8X8_W]
                        + ram_b_if.rd_data[i*SAD_8X8_W+:SAD_8X8_W];
                end
            end
            2'd1: begin
                // Produce an 8x16 SAD from RAM A and the input.
                for (int i = 0; i < WINDOW_SIZE; i++) begin
                    sad_16x8_d[i] = ram_a_if.rd_data[i*SAD_8X8_W+:SAD_8X8_W] + sad_8x8_q[i];
                end
            end
            2'd2: begin
                // Produce a 16x8 SAD from RAM A and the input.
                for (int i = 0; i < WINDOW_SIZE; i++) begin
                    sad_16x8_d[i] = ram_a_if.rd_data[i*SAD_8X8_W+:SAD_8X8_W] + sad_8x8_q[i];
                end

                // Write the 16x8 SAD to RAM C.
                ram_c_if.wr_en   = sad_valid_q[0];
                ram_c_if.wr_addr = sw_idx_q[0];
                for (int i = 0; i < WINDOW_SIZE; i++) begin
                    ram_c_if.wr_data[i*SAD_16X8_W+:SAD_16X8_W] = sad_16x8_d[i];
                end
            end
            2'd3: begin
                // Produce a 16x8 SAD from RAM B and the input.
                for (int i = 0; i < WINDOW_SIZE; i++) begin
                    sad_16x8_d[i] = ram_b_if.rd_data[i*SAD_8X8_W+:SAD_8X8_W] + sad_8x8_q[i];
                end

                // Produce a 16x16 SAD from RAM C and the current 16x8 SAD.
                ram_c_if.rd_en   = sad_valid_q[0];
                ram_c_if.rd_addr = sw_idx_q[0];
            end
        endcase

        // Compute final 16x16 SAD.
        if (sb_idx_q[1] == 2'd3) begin
            for (int i = 0; i < WINDOW_SIZE; i++) begin
                sad_16x16_d[i] = ram_c_if.rd_data[i*SAD_16X8_W+:SAD_16X8_W] + sad_16x8_q[i];
            end
        end

        // Update 16x16 subblock index if computation for current subblock is complete.
        if (sad_last_q[2] && sb_idx_q[2] == 2'd3) begin
            sb_idx_16x16_d = sb_idx_16x16_q + 1;
        end
    end

    always_ff @(posedge clk) begin
        if (clear_in) begin
            for (int i = 0; i < WINDOW_SIZE; i++) sad_8x8_q[i] <= '0;
            for (int i = 0; i < WINDOW_SIZE; i++) sad_16x8_q[i] <= '0;
            for (int i = 0; i < WINDOW_SIZE; i++) sad_16x16_q[i] <= '0;

            sb_idx_16x16_q <= '0;

            for (int i = 0; i < 3; i++) sb_idx_q[i] <= '0;
            for (int i = 0; i < 3; i++) sw_idx_q[i] <= '0;
            for (int i = 0; i < 3; i++) sad_last_q[i] <= '0;
            for (int i = 0; i < 3; i++) sad_valid_q[i] <= '0;
            for (int i = 0; i < 3; i++) first_sb_q[i] <= '1;
        end else begin
            sad_8x8_q <= sad_8x8_d;
            sad_16x8_q <= sad_16x8_d;
            sad_16x16_q <= sad_16x16_d;

            sb_idx_16x16_q <= sb_idx_16x16_d;

            sb_idx_q <= sb_idx_d;
            sw_idx_q <= sw_idx_d;
            sad_last_q <= sad_last_d;
            sad_valid_q <= sad_valid_d;
            first_sb_q <= first_sb_d;
        end

        clear_q <= clear_in;
    end

    always_comb begin
        sad_16x8_valid = sad_valid_q[1] & !first_sb_q[1];
        sad_16x8_last = sad_last_q[1];
        case (sb_idx_q[1])
            2'd0: sad_16x8_id = SAD_SXL_1;
            2'd1: sad_16x8_id = SAD_SXL_0;
            2'd2: sad_16x8_id = SAD_LXS_0;
            2'd3: sad_16x8_id = SAD_LXS_1;
        endcase
        sw_idx_16x8 = sw_idx_q[1];
        sad_16x8 = sad_16x8_q;

        sad_16x16_valid = sad_valid_q[2] & !first_sb_q[2] & (sb_idx_q[2] == 2'd3);
        sad_16x16_last = sad_last_q[2];
        sb_idx_16x16 = sb_idx_16x16_q;
        sw_idx_16x16 = sw_idx_q[2];
        sad_16x16 = sad_16x16_q;

        clear_out = clear_q;
    end

endmodule
