// sad_pe.sv
//
// Computes a 4x4 SAD over four cycles (streamed one row of data at a time).
//

module sad_pe (
    input wire clk,
    input  rst_n,
    input  [PEL_W-1:0] cf[4],
    input  [PEL_W-1:0] rf[4],
    output logic [PEL_W-1:0] result
);

    logic [PEL_W-1:0]     sad_l0[4];
    logic [SAD_2X1_W-1:0] sad_l1[2];
    logic [SAD_4X4_W-1:0] acc_q, acc_d;

    always_comb begin
        sad_l0[0] = rf[0] > cf[0] ? (rf[0] - cf[0]) : (cf[0] - rf[0]);
        sad_l0[1] = rf[1] > cf[1] ? (rf[1] - cf[1]) : (cf[1] - rf[1]);
        sad_l0[2] = rf[2] > cf[2] ? (rf[2] - cf[2]) : (cf[2] - rf[2]);
        sad_l0[3] = rf[3] > cf[3] ? (rf[3] - cf[3]) : (cf[3] - rf[3]);

        sad_l1[0] = sad_l0[0] + sad_l0[1];
        sad_l1[1] = sad_l0[2] + sad_l0[3];

        acc_d = sad_l1[0] + sad_l1[1];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_q = '0;
        end else begin
            acc_q = acc_d;
        end
    end

    always_comb begin
        result = acc_q;
    end

endmodule
