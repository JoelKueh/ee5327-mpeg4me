// fs_quarter_comparator.sv
//
// Compares SAD results and stores the best.
//
// In contrast to its larger cousin, this comparator operates on a strided
// quarter-width datapath. Uses a 3-level tree reduction to reduce 8 elements
// to a single output. Performs the reduction in a single clock cycle.
//

module fs_quarter_comparator #(
    int SAD_RESULT_W = me_pkg::SAD_8X4_W
) (
    input logic clk,    // The primary clock
    input logic clear,  // Input clear signal

    input logic input_valid,                         // Input sad valid signal
    input logic input_last,                          // Last input sad signal
    input logic [1:0] input_subcycle_idx,            // Input subcycle idx
    input logic [me_pkg::SW_IDX_W-1:0] input_sw_idx, // Input sw idx
    input logic [SAD_RESULT_W-1:0] input_sads[8],    // Input SADs

    output logic result_valid,                       // Result valid signal
    output logic [SAD_RESULT_W-1:0] result_sad,      // Reduced result SAD
    output me_pkg::mv_t result_mv                    // Result motion vector
);

    import me_pkg::*;

    logic input_last_q, input_last_d;

    logic [SAD_RESULT_W-1:0] sad_l2[4];
    logic [SAD_RESULT_W-1:0] sad_l1[2];

    logic select_l2[4];
    logic select_l1[2];

    logic col_l2[4];
    logic [1:0] col_l1[2];

    logic result_select;
    logic [SAD_RESULT_W-1:0] result_sad_q, result_sad_d;
    logic [SW_IDX_W-1:0] result_row_q, result_row_d;
    logic [SW_IDX_W-1:0] result_col_q, result_col_d;

    always_comb begin
        input_last_d = input_valid && input_last;

        // Reduce the 8 inputs to their minimum.
        for (int i = 0; i < 4; i++) begin
            select_l2[i] = input_sads[2*i+1] < input_sads[2*i];
            sad_l2[i] = select_l2[i] ? input_sads[2*i+1] : input_sads[2*i];
            col_l2[i] = select_l2[i];
        end

        for (int i = 0; i < 2; i++) begin
            select_l1[i] = sad_l2[2*i+1] < sad_l2[2*i];
            sad_l1[i] = select_l1[i] ? sad_l2[2*i+1] : sad_l2[2*i];
            col_l1[i] = {select_l1[i], select_l1[i] ? col_l2[2*i+1] : col_l2[2*i]};
        end

        // Swap the reduced SAD with that in the register to maintain the minimum
        result_select = sad_l1[1] < sad_l1[0];
        result_sad_d  = result_select ? sad_l1[1] : sad_l1[0];
        result_row_d  = input_sw_idx;
        result_col_d  = {result_select, col_l1[result_select], input_subcycle_idx};
        if (!input_valid || result_sad_d > result_sad_q) begin
            result_sad_d = result_sad_q;
            result_row_d = result_row_q;
            result_col_d = result_col_q;
        end
    end

    always_ff @(posedge clk) begin
        if (clear || input_last_q) begin
            input_last_q <= '0;
            result_sad_q <= '1;
            result_row_q <= '0;
            result_col_q <= '0;
        end else begin
            input_last_q <= input_last_d;
            result_sad_q <= result_sad_d;
            result_row_q <= result_row_d;
            result_col_q <= result_col_d;
        end
    end

    always_comb begin
        // Assign the output based on the minimum SAD computation.
        result_valid = input_last_q;
        result_sad = result_sad_q;
        result_mv.row = result_row_q;
        result_mv.col = result_col_q;
    end

endmodule
