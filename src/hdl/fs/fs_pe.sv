// fs_pe.sv
//
// Single time-multiplexed PE computing 4 interleaved 4x4 SADs (1 finished SAD every 4 cycles).
// Operates on acc_q[0] while acc_q[1:3] are only used to hold the intermediate results.
//

module fs_pe import me_pkg::*; (
    input  logic                  clk,
    input  logic                  stall,
    input  logic                  clear,

    input  logic [3:0][PEL_W-1:0] rb,
    input  logic [3:0][PEL_W-1:0] cb,
    output logic [SAD_4X4_W-1:0]  sad
);

    logic [SAD_4X4_W-1:0] acc_q[3], acc_d[3];
    logic [SAD_4X4_W-1:0] row_sad;
    logic [SAD_4X4_W-1:0] prev_sad;

    always_comb begin
        // Compute row SAD from input pixels
        row_sad = '0;
        for (int i = 0; i < 4; i++) begin
            row_sad += (rb[i] > cb[i]) ? (rb[i] - cb[i]) : (cb[i] - rb[i]);
        end

        // Update accumulator based on the sum of the previous and row SAD
        for (int i = 1; i < 3; i++) acc_d[i] = acc_q[i-1];
        prev_sad = clear ? '0 : acc_q[2];
        acc_d[0] = prev_sad + row_sad;
    end

    always_ff @(posedge clk) begin
        if (!stall) begin
            acc_q <= acc_d;
        end
    end

    assign sad = acc_q[0];

endmodule
