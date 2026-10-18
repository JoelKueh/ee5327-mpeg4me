// sad_computer.sv
//
// Performs first-level SAD computation using four SAD PE arrays.
// Computes all 8x4, and 8x8 SADs. Does not compute 4x4 and 8x4 SADs to help
// with congestion. Discussed in Vayalil and Kong.
//

module sad_computer(
    input  logic clk,
    input  logic rst_n,
    input  logic stall,
    input  logic [PEL_W-1:0] rf[WINDOW_SIZE+7],
    input  logic [PEL_W-1:0] cf[4][4],
    output logic [SAD_8X4_W-1:0] results_8x4[2][WINDOW_SIZE],
    output logic [SAD_8X8_W-1:0] results_8x8[WINDOW_SIZE]
);

    logic [SAD_4X4_W-1:0] results_4x4_q[4][WINDOW_SIZE], results_4x4_d[4][WINDOW_SIZE];
    logic [SAD_4X4_W-1:0] results_8x4_q[2][WINDOW_SIZE], results_8x8_d[4][WINDOW_SIZE];
    logic [SAD_4X4_W-1:0] results_8x8_q[WINDOW_SIZE], results_8x8_d[WINDOW_SIZE]

    // Instantiate 4 4x4_SAD PE arrays arranged as a full 8x8 block.
    genvar int i;
    generate
        for (i = 0; i < 4; i++) begin : computer_pe
            sad_pe_array pe_array_ul(
                .clk(clk),
                .rst_n(rst_n),
                .stall(stall),
                .rf(rf[i:WINDOW_SIZE+2+i]),
                .cf(cf[i]),
                .results(results_4x4_d[i])
            );
        end
    endgenerate

    // Compute the 8x4 and 8x8 results.
    always_comb begin
        for (int i = 0; i < WINDOW_SIZE; i++) begin
            results_8x4_d[0][i] = results_4x4_q[0][i] + results_4x4_q[2][i];
            results_8x4_d[1][i] = results_4x4_q[1][i] + results_4x4_q[3][i];
            results_8x8_d[2][i] = results_8x4[0][i] + results_8x4[1][i];
        end
    end

    // Buffer the output of the 4x4 PE arrays.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            results_4x4_q <= '0;
            results_4x4_q <= '0;
            results_4x4_q <= '0;
        end else begin
            results_4x4_q <= results_4x4_d;
        end
    end

    always_comb begin
        for (int i = 0; i < WINDOW_SIZE; i++) begin
            results_8x4_d[0][i] = results_4x4_q[0][i] + results_4x4_q[2][i];
            results_8x4_d[1][i] = results_4x4_q[1][i] + results_4x4_q[3][i];
            results_8x8_d[2][i] = results_8x4[0][i] + results_8x4[1][i];
        end
    end

endmodule
