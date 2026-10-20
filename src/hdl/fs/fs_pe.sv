// fs_pe.sv
//
// Computes a 4x4 SAD over four cycles (streamed one row of data at a time).
//

module fs_pe (
    input  logic clk,                 // The primary clock
    input  logic clear,               // Synchronous, pipelined accumulator clear signal
    input  logic stall,               // Pipelined stall signal
    input  logic [3:0][PEL_W-1:0] rb, // Reference block input
    input  logic [3:0][PEL_W-1:0] cb, // Current block input
    output logic [SAD_4X4_W-1:0] sad  // Computed SAD output
);

    import me_pkg::*;

    logic [PEL_W-1:0]     sad_l0[4];
    logic [SAD_2X1_W-1:0] sad_l1[2];
    logic [SAD_4X4_W-1:0] acc_q, acc_d;

    always_comb begin
        sad_l0[0] = rb[0] > cb[0] ? (rb[0] - cb[0]) : (cb[0] - rb[0]);
        sad_l0[1] = rb[1] > cb[1] ? (rb[1] - cb[1]) : (cb[1] - rb[1]);
        sad_l0[2] = rb[2] > cb[2] ? (rb[2] - cb[2]) : (cb[2] - rb[2]);
        sad_l0[3] = rb[3] > cb[3] ? (rb[3] - cb[3]) : (cb[3] - rb[3]);

        sad_l1[0] = sad_l0[0] + sad_l0[1];
        sad_l1[1] = sad_l0[2] + sad_l0[3];

        if (stall) begin
            acc_d = acc_q;
        end else if (clear) begin
            acc_d = '0;
        end else begin
            acc_d = acc_q + {3'b000, sad_l1[0]} + {3'b000, sad_l1[1]};
        end
    end

    always_ff @(posedge clk) begin
        if (clear) begin
            acc_q <= '0;
        end else begin
            acc_q <= acc_d;
        end
    end

    always_comb begin
        sad = acc_q;
    end

endmodule
