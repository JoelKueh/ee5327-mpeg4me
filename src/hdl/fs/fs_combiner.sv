// fs_combiner.sv
//
// Combines SAD reults from the previous level 
//

module fs_combiner (
    input logic clk,  // The primary clock
    input logic rst_n,  // Asynchronous negative reset

    input logic sad_8x8_valid,  // Input SADs valid signal
    input logic sad_8x8_last,  // Input SAD last signal
    input logic [1:0] sb_idx_8x8,  // Subblock index of the input sads
    input logic [me_pkg::SW_IDX_W-1:0] sw_idx_8x8,  // Window index of the input SADs
    input logic [me_pkg::SAD_8X8_W-1:0] sad_8x8[me_pkg::WINDOW_SIZE],  // Input SADs

    output logic sad_16x8_valid,  // 16x8 SAD valid signal.
    output logic sad_16x8_last,  // 16x8 SAD last signal
    output comb_sad_id_t sad_16x8_id,  // 16x8 SAD subblock ids.
    output logic [me_pkg::SW_IDX_W-1:0] sw_idx_16x8,  // SAD search window offset
    output logic [me_pkg::SAD_16X8_W-1:0] sad_16x8[me_pkg::WINDOW_SIZE],  // Output port for 16x8 and 8x16 SAD

    output logic sad_16x16_valid,  // 16x16 SAD valid signal
    output logic sad_16x16_last,  // 16x16 SAD last signal
    output logic [1:0] sb_idx_16x16,  // 16x16 SAD subblock indicies
    output logic [me_pkg::SW_IDX_W-1:0] sw_idx_16x16,  // SAD search window offset
    output logic [me_pkg::SAD_16X16_W-1:0] sad_16x16[me_pkg::WINDOW_SIZE]  // 16x16 SAD
);

    import me_pkg::*;

    sram_if #(.ADDR_W(SW_IDX_W), .DATA_W(WINDOW_SIZE * SAD_8X8_W))   ram_a_if;
    sram_if #(.ADDR_W(SW_IDX_W), .DATA_W(WINDOW_SIZE * SAD_8X8_W))   ram_b_if;
    sram_if #(.ADDR_W(SW_IDX_W), .DATA_W(WINDOW_SIZE * SAD_16X16_W)) ram_c_if;

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
        .DATA_W(WINDOW_SIZE * SAD_16X16_W)
    ) ram_b (
        clk,
        ram_c_if
    );

    logic [SAD_8X8_W-1:0] sad_8x8_q[WINDOW_SIZE], sad_8x8_d[WINDOW_SIZE];
    logic [SAD_16X8_W-1:0] sad_16x8_q[WINDOW_SIZE], sad_16x8_d[WINDOW_SIZE];
    logic [SAD_16X16_W-1:0] sad_16x16_q[WINDOW_SIZE], sad_16x16_d[WINDOW_SIZE];

    logic [1:0] sb_idx_8x8_q[2], sb_idx_8x8_d[2];
    logic [1:0] sb_idx_16x16_q, sb_idx_16x16_d;

    logic [SW_IDX_W-1:0] sw_idx_q[2], sw_idx_d[2];
    logic sad_valid_q[2], sad_valid_d[2];
    logic sad_last_q[2], sad_last_d[2];

    always_comb begin
        sad_8x8_d = sad_8x8;
        for (int i = 0; i < WINDOW_SIZE; i++) sad_16x8_d[i] = 'x;
        for (int i = 0; i < WINDOW_SIZE; i++) sad_16x16_d[i] = 'x;

        // Update pipeline registers
        if (stall) begin
            sb_idx_8x8_d = sb_idx_8x8_q;
            sw_idx_d = sw_idx_q;
            sad_valid_d = sad_valid_q;
            sad_last_d = sad_last_q;
        end else begin
            sb_idx_8x8_d[0] = sb_idx_8x8;
            sb_idx_8x8_d[1] = sb_idx_8x8_q[0];
            sw_idx_d[0] = sw_idx_8x8;
            sw_idx_d[1] = sw_idx_q[0];
            sad_valid_d[0] = sad_8x8_valid;
            sad_valid_d[1] = sad_valid_q[0];
            sad_last_d[0] = sad_8x8_last;
            sad_last_d[1] = sad_last_q[0];
        end

        // Update output subblock index register on the last 16x16 SAD computation.

        ram_a.wr_en = '0;
        ram_a.wr_addr = 'x;
        ram_a.wr_data = 'x;
        ram_a.rd_en = '0;
        ram_a.rd_addr = 'x;

        ram_b.wr_en = '0;
        ram_b.wr_addr = 'x;
        ram_b.wr_data = 'x;
        ram_b.rd_en = '0;
        ram_b.rd_addr = 'x;

        ram_c_if.wr_en = '0;
        ram_c_if.wr_addr = 'x;
        ram_c_if.wr_data = 'x;
        ram_c_if.rd_en = '0;
        ram_c_if.rd_addr = 'x;

        if (sw_idx_8x8 >= 4) begin
            case (sb_idx_8x8)
                2'd0: begin
                    // Write the current SAD data to the A write port.
                    ram_a_if.wr_en   = sad_8x8_valid;
                    ram_a_if.wr_addr = sw_idx_8x8;
                    for (int i = 0; i < WINDOW_SIZE; i++) begin
                        ram_a_if.wr_data[i*WINDOW_SIZE+:SAD_8X8_W] = sad_8x8[i];
                    end

                    // Produce an 8x16 SAD from RAM B and RAM A.
                    ram_a_if.rd_en   = sad_8x8_valid;
                    ram_a_if.rd_addr = sw_idx_8x8;
                    ram_b_if.rd_en   = sad_8x8_valid;
                    ram_b_if.rd_addr = sw_idx_8x8;
                    for (int i = 0; i < WINDOW_SIZE; i++) begin
                        sad_16x8_d[i] = ram_a_if.rd_data[i*WINDOW_SIZE +: SAD_8X8_W]
                            + ram_b_if.rd_data[i*WINDOW_SIZE +: SAD_8X8_W];
                    end
                end
                2'd1: begin
                    // Write the current SAD data to the B write port.
                    ram_b_if.wr_en   = sad_8x8_valid;
                    ram_b_if.wr_addr = sw_idx_8x8;
                    for (int i = 0; i < WINDOW_SIZE; i++) begin
                        ram_b_if.wr_data[i*WINDOW_SIZE+:SAD_8X8_W] = sad_8x8[i];
                    end

                    // Produce an 8x16 SAD from RAM A and the input.
                    ram_a_if.rd_en   = sad_8x8_valid;
                    ram_a_if.rd_addr = sw_idx_8x8;
                    for (int i = 0; i < WINDOW_SIZE; i++) begin
                        sad_16x8_d[i] = ram_a_if.rd_data[i*WINDOW_SIZE+:SAD_8X8_W] + sad_8x8_q[i];
                    end
                end
                2'd2: begin
                    // Write the current SAD data to the A write port.
                    ram_a_if.wr_en   = sad_8x8_valid;
                    ram_a_if.wr_addr = sw_idx_8x8;
                    for (int i = 0; i < WINDOW_SIZE; i++) begin
                        ram_a_if.wr_data[i*WINDOW_SIZE+:SAD_8X8_W] = sad_8x8[i];
                    end

                    // Produce a 16x8 SAD from RAM A and the input.
                    ram_a_if.rd_en   = sad_8x8_valid;
                    ram_a_if.rd_addr = sw_idx_8x8;
                    for (int i = 0; i < WINDOW_SIZE; i++) begin
                        sad_16x8_d[i] = ram_a_if.rd_data[i*WINDOW_SIZE+:SAD_8X8_W] + sad_8x8_q[i];
                    end

                    // Write the 8x16 SAD to RAM C.
                    ram_c_if.wr_en   = sad_valid_q[0];
                    ram_c_if.wr_addr = sw_idx_q[0];
                    for (int i = 0; i < WINDOW_SIZE; i++) begin
                        ram_c_if.wr_data[i*WINDOW_SIZE+:SAD_16X8_W] = sad_16x8_d[i];
                    end
                end
                2'd3: begin
                    // Write the current SAD data to the B write port.
                    ram_b_if.wr_en   = sad_8x8_valid;
                    ram_b_if.wr_addr = sw_idx_8x8;
                    for (int i = 0; i < WINDOW_SIZE; i++) begin
                        ram_b_if.wr_data[i*WINDOW_SIZE+:SAD_8X8_W] = sad_8x8[i];
                    end

                    // Produce a 16x8 SAD from RAM B and the input.
                    ram_b_if.rd_en   = sad_8x8_valid;
                    ram_b_if.rd_addr = sw_idx_8x8;
                    for (int i = 0; i < WINDOW_SIZE; i++) begin
                        sad_16x8_d[i] = ram_b_if.rd_data[i] + sad_8x8_q[i];
                    end

                    // Produce a 16x16 SAD from RAM C and the current 16x8 SAD.
                    ram_c_if.rd_en   = sad_valid_q[0];
                    ram_c_if.rd_addr = sw_idx_q[0];
                    for (int i = 0; i < WINDOW_SIZE; i++) begin
                        sad_16x16_d[i] = ram_c_if.rd_data[i*WINDOW_SIZE+:SAD_16X8_W] + sad_16x8_q[i];
                    end
                end
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sad_8x8_q <= '0;
            sad_16x8_q <= '0;
            sad_16x16_q <= '0;

            sb_idx_8x8_q <= '0;
            sb_idx_16x16_q <= '0;

            sw_idx_q <= '0;
            sad_valid_q <= '0;
            sad_last_q <= '0;

            clear_q <= '0;
            stall_q <= '0;
        end else begin
            sad_8x8_q <= sad_8x8_d;
            sad_16x8_q <= sad_16x8_d;
            sad_16x16_q <= sad_16x16_d;

            sb_idx_8x8_q <= sb_idx_8x8_d;
            sb_idx_16x16_q <= sb_idx_16x16_d;

            sw_idx_q <= sw_idx_d;
            sad_valid_q <= sad_valid_d;
            sad_last_q <= sad_last_d;

            clear_q <= clear_d;
            stall_q <= stall_d;
        end
    end

    always_comb begin
        sw_idx_16x8 = sw_idx_q[0];
        sad_16x8_valid = sad_valid_q[0];
        sad_16x8 = sad_16x8_q;
        sw_idx_16x16 = sw_idx_q[1];
        sad_16x16_valid = sad_valid_q[1];
        sad_16x16 = sad_16x16_q;
    end

endmodule
