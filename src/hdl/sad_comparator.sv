// sad_comparator.sv
//
// Compares SAD results and stores the best.
//

module sad_comparator#(
    int SAD_RESULT_W
) (
    input  logic clk,
    input  logic clear,
    input  logic stall,
    input  logic [SAD_RESULT_W-1:0] sads[WINDOW_SIZE],
    output logic [SAD_RESULT_W-1:0] result
);

    logic [SAD_RESULT_W-1:0] l4[16];
    logic [SAD_RESULT_W-1:0] l3[8];
    logic [SAD_RESULT_W-1:0] l2_q[4], l2_d[4];
    logic [SAD_RESULT_W-1:0] l1[2];
    logic [SAD_RESULT_W-1:0] l0_q, l0_d;

    always_comb begin
        // Pipeline stage 1
        for (int i = 0; i < 16; i++) l4[i] = sads[i] < sads[2*i] ? sads[i] : sads[2*i];
        for (int i = 0; i < 8; i++) l3[i] = l4[i] < l4[2*i] ? l4[i] : l4[2*i];
        for (int i = 0; i < 4; i++) l2_d[i] = l3[i] < l3[2*i] ? l3[i] : l3[2*i];

        // Pipeline stage 2
        for (int i = 0; i < 2; i++) l1_d[i] = l2_q[i] < l3[2*i] ? l3[i] : l3[2*i];
    end

    always_ff @(posedge clk) begin

    end

    always_comb begin

    end

endmodule
