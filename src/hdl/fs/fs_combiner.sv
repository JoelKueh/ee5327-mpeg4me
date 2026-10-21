// fs_combiner.sv
//
// Combines SAD reults from the previous level 
//

module fs_combiner (
    input  logic clk,                                     // The primary clock
    input  logic stall,                                   // Pipelined stall signal

    input  logic [1:0] cb_subblock_idx,                   // Subblock index of the current block
    input  logic [SW_IDX_W-1:0] sad_row_idx,              // Row index of the input SADs
    input  logic [SAD_8X8_W-1:0] sad_8x8[WINDOW_SIZE],    // Input SADs

    sram_if.mstr ram_a,                                   // First level RAM
    sram_if.mstr ram_b,                                   // Second level RAM
    sram_if.mstr ram_c,                                   // Third level RAM

    output logic [SAD_16X8_W-1:0]  sad_16x8[WINDOW_SIZE], // Output port for 16x8 and 8x16 SAD
    output logic [SAD_16X16_W-1:0] sad_16x16[WINDOW_SIZE] // 16x16 SAD
);

    import me_pkg::*;

    logic [SAD_8X8_W-1:0] sad_8x8_q[WINDOW_SIZE], sad_8x8_d[WINDOW_SIZE];
    logic [SAD_16X8_W-1:0] sad_16x8_q[WINDOW_SIZE], sad_16x8_d[WINDOW_SIZE];
    logic [SAD_16X16_W-1:0] sad_16x16_q[WINDOW_SIZE], sad_16x16_d[WINDOW_SIZE];
    logic [SW_IDX_W-1:0] last_row_idx_q, last_row_idx_d;

    always_comb begin
        last_row_idx_d = sad_row_idx;
        sad_16x16_d = 'x;

        case (cb_subblock_idx)
            2'd0: begin
                // Write the current SAD data to the A write port.
                ram_a.wr_en   = '1;
                ram_a.wr_addr = sad_row_idx;
                ram_a.wr_data = sad_8x8;

                // Produce an 8x16 SAD from RAM B and RAM A.
                ram_a.rd_en   = 1;
                ram_a.rd_addr = sad_row_idx;
                ram_b.rd_en   = 1;
                ram_b.rd_addr = sad_row_idx;
                for (int i = 0; i < WINDOW_SIZE; i++) begin
                    sad_16x8_d[i] = ram_a.rd_data[i] + ram_b.rd_data[i];
                end
            end
            2'd1: begin
                // Write the current SAD data to the B write port.
                ram_b.wr_en   = '1;
                ram_b.wr_addr = sad_row_idx;
                ram_b.wr_data = sad_8x8;

                // Produce an 8x16 SAD from RAM A and the input.
                ram_a.rd_en   = 1;
                ram_a.rd_addr = sad_row_idx;
                for (int i = 0; i < WINDOW_SIZE; i++) begin
                    sad_16x8_d[i] = ram_a.rd_data[i] + sad_8x8_q[i];
                end
            end
            2'd2: begin
                // Write the current SAD data to the A write port.
                ram_a.wr_en   = 1;
                ram_a.wr_addr = sad_row_idx;
                ram_a.wr_data = sad_8x8;

                // Produce a 16x8 SAD from RAM A and the input.
                ram_a.rd_en   = 1;
                ram_b.rd_addr = sad_row_idx;
                for (int i = 0; i < WINDOW_SIZE; i++) begin
                    sad_16x8_d[i] = ram_a.rd_data[i] + sad_8x8_q[i];
                end

                // Write the 16x8 SAD to RAM C.
                ram_c.wr_en   = 1;
                ram_c.wr_addr = last_row_idx_q;
                ram_c.wr_data = sad_16x8;
            end
            2'd3: begin
                // Write the current SAD data to the B write port.
                ram_b.wr_en   = 1;
                ram_b.wr_addr = sad_row_idx;
                ram_b.wr_data = sad_8x8;

                // Produce a 16x8 SAD from RAM B and the input.
                ram_b.rd_en   = 1;
                ram_b.rd_addr = sad_row_idx;
                for (int i = 0; i < WINDOW_SIZE; i++) begin
                    sad_16x8_d[i] = ram_b.rd_data[i] + sad_8x8_q[i];
                end

                // Produce a 16x16 SAD from RAM C and the current 16x8 SAD.
                for (int i = 0; i < WINDOW_SIZE; i++) begin
                    sad_16x16_d[i] = ram_c.rd_data[i] + sad_16x8_q;
                end
            end
        endcase
    end

    always_ff @(posedge clk) begin
        sad_8x8_q <= sad_8x8_d;
        sad_16x8_q <= sad_16x8_d;
        sad_16x16_q <= sad_16x16_d;
    end

    always_comb begin
        sad_16x8 = sad_16x8_q;
        sad_16x16 = sad_16x16_q;
    end

endmodule
