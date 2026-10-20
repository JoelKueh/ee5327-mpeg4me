// sad_comparator.sv
//
// Compares SAD results and stores the best.
//
// Uses a 5-level tree reduction to reduce WINDOW_SIZE (32) elements to
// a single output. Performs the reduction in two clock cycles, buffering
// the output of the l2 reduction (4 elements) before assigning the final
// result to the minimum register.
//
// NOTE: This module only supports WINDOW_SIZE=32.
//

module sad_comparator#(
    int SAD_RESULT_W=SAD_8X4_W
) (
    input  logic clk,                                        // The primary clock
    input  logic clear,                                      // Pipelined clear signal
    input  logic stall,                                      // Pipelined stall signal
                                                                                                     
    input  logic [SW_IDX_W-1:0] input_row_idx,               // Row index of the input SADs
    input  logic [SAD_RESULT_W-1:0] input_sads[WINDOW_SIZE], // Input SADs

    output logic [SAD_RESULT_W-1:0] result_sad,              // Reduced result SAD
    output logic [SW_IDX_W-1:0] result_row,                  // Row index of the result SAD
    output logic [SW_IDX_W-1:0] result_col                   // Column index of the result SAD
);

    import sad_pkg::*;

    logic [SAD_RESULT_W-1:0] sad_l4[16];
    logic [SAD_RESULT_W-1:0] sad_l3[8];
    logic [SAD_RESULT_W-1:0] sad_l2_q[4], sad_l2_d[4];
    logic [SAD_RESULT_W-1:0] sad_l1[2];

    logic select_l4[16];
    logic select_l3[8];
    logic select_l2[4];
    logic select_l1[2];
    logic result_select;

    logic col_l4[16];
    logic [1:0] col_l3[8];
    logic [2:0] col_l2_q[4], col_l2_d[4];
    logic [3:0] col_l1[2];

    logic [SAD_RESULT_W-1:0] result_sad_q, result_sad_d;
    logic [SW_IDX_W-1:0] result_row_q, result_row_d;
    logic [SW_IDX_W-1:0] result_col_q, result_col_d;

    always_comb begin
        // Pipeline stage 1
        for (int i = 0; i < 16; i += 2) begin
            select_l4[i] = input_sads[2*i+1] < input_sads[2*i];
            sad_l4[i] = select_l4[i] ? input_sads[2*i+1] : input_sads[2*i];
            col_l4[i] = select_l4[i];
        end

        for (int i = 0; i < 8; i++) begin
            select_l3[i] = sad_l4[2*i+1] < sad_l4[2*i];
            sad_l3[i] = select_l3[i] ? sad_l4[2*i+1] : sad_l4[2*i];
            col_l3[i] = {select_l3[i], select_l3[i] ? col_l4[2*i+1] : col_l4[2*i]};
        end

        for (int i = 0; i < 4; i++) begin
            select_l2[i] = sad_l3[2*i+1] < sad_l3[2*i];
            sad_l2_d[i] = select_l2[i] ? sad_l3[2*i+1] : sad_l3[2*i];
            col_l2_d[i] = {select_l2[i], select_l2[i] ? col_l3[2*i+1] : col_l3[2*i]};
        end

        // Pipeline stage 2
        for (int i = 0; i < 2; i++) begin
            select_l1[i] = sad_l2_q[2*i+1] < sad_l2_q[2*i];
            sad_l1[i] = select_l1[i] ? sad_l2_q[2*i+1] : sad_l2_q[2*i];
            col_l1[i] = {select_l1[i], select_l1[i] ? col_l2_q[2*i+1] : col_l2_q[2*i]};
        end

        // Swap the reduced SAD with that in the register to maintain the minimum
        result_select = sad_l1[1] < sad_l1[0];
        result_sad_d = result_select ? sad_l1[1] : sad_l1[0];
        result_row_d = input_row_idx - 1; // Comparator adds one cycle of latency.
        result_col_d = {result_select, col_l1[result_select]};
        if (result_sad_d > result_sad_q) begin
            result_sad_d = result_sad_q;
            result_row_d = result_row_q;
            result_col_d = result_col_q;
        end

        // Freeze the pipeline on stall
        if (stall) begin
            result_sad_d = result_sad_q;
            result_row_d = result_row_q;
            result_col_d = result_col_q;
            col_l2_d = col_l2_q;
        end
    end

    always_ff @(posedge clk) begin
        if (clear) begin
            result_sad_q <= '1;
            result_row_q <= '0;
            result_col_q <= '0;
            for (int i = 0; i < 4; i++) col_l2_q[i] <= '0;
        end else begin
            result_sad_q <= result_sad_d;
            result_row_q <= result_row_d;
            result_col_q <= result_col_d;
            col_l2_q <= col_l2_d;
        end
    end

    always_comb begin
        // Assign the output based on the minimum SAD computation.
        result_sad = result_sad_q;
        result_row = result_row_q;
        result_col = result_col_q;
    end

endmodule
