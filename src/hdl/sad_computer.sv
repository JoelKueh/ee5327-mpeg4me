// sad_computer.sv
//
// Performs first-level SAD computation using four SAD PE arrays.
// Computes all 8x4, and 8x8 SADs. Does not compute 4x4 and 8x4 SADs to help
// with congestion. Discussed in Vayalil and Kong.
//
// Buffers its own output, adding a one-cycle latency to the pipeline.
//

module sad_computer(
    input  logic clk,                                     // The primary clock
    input  logic clear,                                   // Pipelined clear signal
    input  logic stall,                                   // Pipelined stall signal
    input  logic [WINDOW_SIZE+6:0][PEL_W-1:0] rf,         // Reference frame input
    input  logic [3:0][PEL_W-1:0] cf[4],                  // Candidate frame input

    output logic [SAD_8X4_W-1:0] sad_8x4[WINDOW_SIZE][2], // Buffered output 8x4 row results
    output logic [SW_IDX_W-1:0] tag_8x4[WINDOW_SIZE][2],  // Tag values for 8x4 row reults
    output logic [SAD_8X8_W-1:0] sad_8x8[WINDOW_SIZE],    // Buffered output 8x8 row result
    output logic [SW_IDX_W-1:0] tag_8x8[WINDOW_SIZE][2]   // Tag values for 8x8 row reults
);

    import sad_pkg::*;

    logic [SAD_8X4_W-1:0] results_8x4_q[2][WINDOW_SIZE], results_8x4_d[4][WINDOW_SIZE];
    logic [SAD_8X8_W-1:0] results_8x8_q[WINDOW_SIZE], results_8x8_d[WINDOW_SIZE];

    logic [SAD_4X4_W-1:0] results_4x4;
    logic load;

    // Instantiate 4 4x4_SAD PE arrays arranged as a full 8x8 block.
    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : computer_pe
            sad_pe_array pe_array(
                .clk(clk),
                .clear(clear),
                .load(load),
                .stall(stall),
                .rf(rf[i:WINDOW_SIZE+2+i]),
                .cf(cf[i]),
                .results(results_4x4[i])
            );
        end
    endgenerate

    // Compute the 8x4 and 8x8 results in one cycle.
    always_comb begin
        for (int i = 0; i < WINDOW_SIZE; i++) begin
            results_8x4_d[0][i] = results_4x4[0][i] + results_4x4[2][i];
            results_8x4_d[1][i] = results_4x4[1][i] + results_4x4[3][i];
            results_8x8_d[2][i] = results_8x4_d[0][i] + results_8x4_d[1][i];
        end
    end

    // Buffer the output of the 4x4 PE arrays.
    always_ff @(posedge clk) begin
        if (clear) begin
            results_8x4_q <= '0;
            results_8x8_q <= '0;
        end else begin
            results_8x4_q <= results_8x4_d;
            results_8x8_q <= results_8x8_d;
        end
    end

    // Assign the 8x4 and 8x8 output.
    always_comb begin
        sad_8x4 = sad_8x4_q;
        sad_8x8 = sad_8x8_q;
    end

endmodule
