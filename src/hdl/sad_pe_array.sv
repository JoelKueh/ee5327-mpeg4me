// sad_pe_array.sv
//
// Array of processors for SAD computation. Computes a row of 4x4 SADs every
// cycle after fringe after a 3-cycle warm up.
//

module sad_pe_array(
    input  logic clk,                                  // The primary clock
    input  logic rst_n,                                // Asynchronous negative reset
    input  logic stall,                                // Global stall signal
    input  logic load,                                 // Load cf_q[0] from input?
    input  logic [PEL_W-1:0] rf[WINDOW_SIZE+3],        // Reference frame input
    input  logic [PEL_W-1:0] cf[4],                    // Candidate frame input
    output logic [SAD_4X4_W-1:0] results[WINDOW_SIZE]; // Buffered output row results
);

    logic [SAD_4X4_W-1:0] pe_reults[4][WINDOW_SIZE];
    logic clear_row[4];

    logic [1:0] done_idx_q, done_idx_d;
    logic [PEL_W-1:0] cf_q[4][4], cf_d[4][4];
    logic [SAD_4X4_W-1:0] results_q[4], results_d[4];

    // Instantiate the rows of engines.
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
        end else (load) begin
        end else begin
            done_idx_d = done_idx_q + 1;
            for (int i = 0; i < 4; i++) cf_d[(i + 1) % 4] = cf_q[i];
            if (load) cf_d[0] = cf;
        end
    end

    // Buffer the result output.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done_idx_q <= '0;
            cf_q <= '0;
            results_q <= '0;
        end else begin
            done_idx_q <= done_idx_d;
            cf_q <= cf_d;
            results_q <= results_d;
        end
    end

    // Assign the result output.
    always_comb begin
        results = results_q;
    end

endmodule
