// sad_pe_array.sv
//
// Array of processors for SAD computation. Computes a row of 4x4 SADs every
// cycle after fringe after a 3-cycle warm up.
//

module sad_pe_array(
    input  logic clk,                             // The primary clock
    input  logic clear,                           // Synchonous, pipelined clear signal
    input  logic stall,                           // Pipelined stall signal
    input  logic load,                            // Load cb_q[0] from input?

    input  logic [1:0] row_idx_mod,               // Modulus of the row being served in rb
    input  logic [WINDOW_SIZE+2:0][PEL_W-1:0] rb, // Reference block input
    input  logic [3:0][PEL_W-1:0] cb,             // Current block input

    output logic [SAD_4X4_W-1:0] sad[WINDOW_SIZE] // Buffered output SAD computations
);

    import sad_pkg::*;

    logic [SAD_4X4_W-1:0] pe_sad[4][WINDOW_SIZE]; // Results from each PE row
    logic clear_row[4];                           // Clear signal for each PE row

    logic [3:0][PEL_W-1:0] cb_q[4], cb_d[4];      // Ring of candidate frame 
    logic [SAD_4X4_W-1:0] sad_q[WINDOW_SIZE], sad_d[WINDOW_SIZE];

    // Instantiate the rows of engines.
    genvar row, col;
    generate
        for (row = 0; row < 4; row++) begin : pe_array_row
            for (col = 0; col < WINDOW_SIZE - 3; col++) begin : pe_array_col
                sad_pe pe(
                    .clk(clk),
                    .clear(clear_row[row]),
                    .stall(stall),
                    .rb(rb[col:col+3]),
                    .cb(cb),
                    .sad(pe_sad[row])
                );
            end
        end
    endgenerate

    always_comb begin
        // Clear rows when clear is asserted or when starting SAD computation.
        if (clear) begin
            for (int i = 0; i < 4; i++) clear_row[i] = '1;
        end else begin
            clear_row[row_idx_mod] = '1;
        end

        // Advance the CF buffer if we are not stalled.
        if (stall) begin
            cb_d = cb_q;
        end else begin
            for (int i = 0; i < 4; i++) cb_d[(i + 1) % 4] = cb_q[i];
            if (load) cb_d[0] = cb;
        end
    end

    // Buffer the result output.
    always_ff @(posedge clk) begin
        if (clear) begin
            cb_q <= '0;
            sad_q <= '0;
        end else begin
            cb_q <= cb_d;
            sad_q <= sad_q;
        end
    end

    // Assign the result output.
    always_comb begin
        sad = sad_q;
    end

endmodule
