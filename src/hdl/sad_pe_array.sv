// sad_pe_array.sv
//
// Array of processors for SAD computation.
//

module sad_pe_array(
    input  logic clk,
    input  logic rst_n,
    input  logic stall,
    input  logic [PEL_W-1:0] rf[WINDOW_SIZE+3],
    input  logic [PEL_W-1:0] cf[4],
    output logic [SAD_4X4_W-1:0] results[WINDOW_SIZE];
);

    logic [SAD_4X4_W-1:0] pe_reults[4][WINDOW_SIZE];
    logic clear_row[4];

    logic [1:0] done_idx_q, done_idx_d;
    logic [PEL_W-1:0] cf_q[4], cf_d[4];

    // Instantiate the row of engines.
    genvar int row, col;
    generate
        for (row = 0; row < 4; row++) begin : pe_array_row
            for (col = 0; col < WINDOW_SIZE - 3; col++) begin : pe_array_col
                sad_pe pe(
                    .clk(clk),
                    .clear(clear_row[row]),
                    .stall(stall),
                    .rf(rf[col:col+3]),
                    .cf(cf),
                    .result(pe_results[row])
                );
            end
        end
    endgenerate

    always_comb begin
        // Clear all rows on reset.
        for (int i = 0; i < 4; i++) begin
            if (!rst_n) begin
                clear_row[i] = '1;
            end else begin
                clear_row[i] = data_done_q[i];
            end
        end

        // Advance the CF buffer if we are not stalled.
        if (stall) begin
            done_idx_d = done_idx_q;
            cf_d = cf_q;
        end else begin
            done_idx_d = done_idx_q + 1;
            for (int i = 0; i < 4; i++) cf_d[(i + 1) % 4] = cf_q[i];
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done_idx_q <= '0;
            cf_q[i] <= '0;
        end else begin
            done_idx_q <= done_idx_d;
            cf_q <= cf_d;
        end
    end

    always_comb begin
        results = pe_results[done_idx_q];
    end

endmodule
