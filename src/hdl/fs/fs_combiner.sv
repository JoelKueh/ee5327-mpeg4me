// fs_combiner.sv
//
// Combines SAD reults from the previous level 
//

module fs_combiner (
    input  logic clk,                                     // The primary clock
    input  logic stall,                                   // Pipelined stall signal

    input  logic sad_8x8_valid,                           // Input SADs valid signal
    input  logic [1:0] cb_subblock_idx,                   // Subblock index of the current block
    input  logic [SW_IDX_W-1:0] sw_idx_8x8,               // Window index of the input SADs
    input  logic [SAD_8X8_W-1:0] sad_8x8[WINDOW_SIZE],    // Input SADs

    sram_if.mstr ram_a,                                   // First level RAM
    sram_if.mstr ram_b,                                   // Second level RAM
    sram_if.mstr ram_c,                                   // Third level RAM

    output logic sad_16x8_valid,                          // 16x8 SAD valid signal.
    output logic [SW_IDX_W-1:0] sw_idx_16x8,              // SAD search window offset
    output logic [SAD_16X8_W-1:0] sad_16x8[WINDOW_SIZE],  // Output port for 16x8 and 8x16 SAD

    output logic sad_16x16_valid,                         // 16x8 SAD valid signal.
    output logic [SW_IDX_W-1:0] sw_idx_16x16,             // SAD search window offset
    output logic [SAD_16X16_W-1:0] sad_16x16[WINDOW_SIZE] // 16x16 SAD
);

    import me_pkg::*;

    logic [SAD_8X8_W-1:0] sad_8x8_q[WINDOW_SIZE], sad_8x8_d[WINDOW_SIZE];
    logic [SAD_16X8_W-1:0] sad_16x8_q[WINDOW_SIZE], sad_16x8_d[WINDOW_SIZE];
    logic [SAD_16X16_W-1:0] sad_16x16_q[WINDOW_SIZE], sad_16x16_d[WINDOW_SIZE];

    logic [SW_IDX_W-1:0] sw_idx_q[2], sw_idx_d[2];
    logic sad_valid_q[2], sad_valid_d[2];

    always_comb begin
        sad_8x8_d = sad_8x8;
        for (int i = 0; i < WINDOW_SIZE; i++) sad_16x8_d[i] = 'x;
        for (int i = 0; i < WINDOW_SIZE; i++) sad_16x16_d[i] = 'x;

        if (stall) begin
            sw_idx_d = sw_idx_q;
            sad_valid_d = sad_valid_q;
        end else begin
            sw_idx_d[0] = sw_idx_8x8;
            sw_idx_d[1] = sw_idx_q[0];
            sad_valid_d[0] = sad_8x8_valid;
            sad_valid_d[1] = sad_valid_q[0];
        end

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

        ram_c.wr_en = '0;
        ram_c.wr_addr = 'x;
        ram_c.wr_data = 'x;
        ram_c.rd_en = '0;
        ram_c.rd_addr = 'x;

        if (sw_idx_8x8 >= 4) begin
            case (cb_subblock_idx)
                2'd0: begin
                    // Write the current SAD data to the A write port.
                    ram_a.wr_en   = sad_8x8_valid;
                    ram_a.wr_addr = sw_idx_8x8;
                    for (int i = 0; i < WINDOW_SIZE; i++) begin
                        ram_a.wr_data[i*WINDOW_SIZE +: SAD_8X8_W] = sad_8x8[i];
                    end

                    // Produce an 8x16 SAD from RAM B and RAM A.
                    ram_a.rd_en   = sad_8x8_valid;
                    ram_a.rd_addr = sw_idx_8x8;
                    ram_b.rd_en   = sad_8x8_valid;
                    ram_b.rd_addr = sw_idx_8x8;
                    for (int i = 0; i < WINDOW_SIZE; i++) begin
                        sad_16x8_d[i] = ram_a.rd_data[i*WINDOW_SIZE +: SAD_8X8_W]
                            + ram_b.rd_data[i*WINDOW_SIZE +: SAD_8X8_W];
                    end
                end
                2'd1: begin
                    // Write the current SAD data to the B write port.
                    ram_b.wr_en   = sad_8x8_valid;
                    ram_b.wr_addr = sw_idx_8x8;
                    for (int i = 0; i < WINDOW_SIZE; i++) begin
                        ram_b.wr_data[i*WINDOW_SIZE +: SAD_8X8_W] = sad_8x8[i];
                    end

                    // Produce an 8x16 SAD from RAM A and the input.
                    ram_a.rd_en   = sad_8x8_valid;
                    ram_a.rd_addr = sw_idx_8x8;
                    for (int i = 0; i < WINDOW_SIZE; i++) begin
                        sad_16x8_d[i] = ram_a.rd_data[i*WINDOW_SIZE +: SAD_8X8_W] + sad_8x8_q[i];
                    end
                end
                2'd2: begin
                    // Write the current SAD data to the A write port.
                    ram_a.wr_en   = sad_8x8_valid;
                    ram_a.wr_addr = sw_idx_8x8;
                    for (int i = 0; i < WINDOW_SIZE; i++) begin
                        ram_a.wr_data[i*WINDOW_SIZE +: SAD_8X8_W] = sad_8x8[i];
                    end

                    // Produce a 16x8 SAD from RAM A and the input.
                    ram_a.rd_en   = sad_8x8_valid;
                    ram_a.rd_addr = sw_idx_8x8;
                    for (int i = 0; i < WINDOW_SIZE; i++) begin
                        sad_16x8_d[i] = ram_a.rd_data[i*WINDOW_SIZE +: SAD_8X8_W] + sad_8x8_q[i];
                    end

                    // Write the 8x16 SAD to RAM C.
                    ram_c.wr_en   = sad_valid_q[0];
                    ram_c.wr_addr = sw_idx_q[0];
                    for (int i = 0; i < WINDOW_SIZE; i++) begin
                        ram_c.wr_data[i*WINDOW_SIZE +: SAD_16X8_W] = sad_16x8_d[i];
                    end
                end
                2'd3: begin
                    // Write the current SAD data to the B write port.
                    ram_b.wr_en   = sad_8x8_valid;
                    ram_b.wr_addr = sw_idx_8x8;
                    for (int i = 0; i < WINDOW_SIZE; i++) begin
                        ram_b.wr_data[i*WINDOW_SIZE +: SAD_8X8_W] = sad_8x8[i];
                    end

                    // Produce a 16x8 SAD from RAM B and the input.
                    ram_b.rd_en   = sad_8x8_valid;
                    ram_b.rd_addr = sw_idx_8x8;
                    for (int i = 0; i < WINDOW_SIZE; i++) begin
                        sad_16x8_d[i] = ram_b.rd_data[i] + sad_8x8_q[i];
                    end

                    // Produce a 16x16 SAD from RAM C and the current 16x8 SAD.
                    ram_c.rd_en   = sad_valid_q[0];
                    ram_c.rd_addr = sw_idx_q[0];
                    for (int i = 0; i < WINDOW_SIZE; i++) begin
                        sad_16x16_d[i] = ram_c.rd_data[i*WINDOW_SIZE +: SAD_16X8_W] + sad_16x8_q[i];
                    end
                end
            endcase
        end
    end

    always_ff @(posedge clk) begin
        sad_8x8_q <= sad_8x8_d;
        sad_16x8_q <= sad_16x8_d;
        sad_16x16_q <= sad_16x16_d;
        sw_idx_q <= sw_idx_d;
        sad_valid_q <= sad_valid_d;
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
