// sram_wrapper.sv
//
// Generic wrapper an SRAM.
//
// sram_wrapper.sv
module sram_wrapper #(
    parameter int ADDR_W = 5,
    parameter int DATA_W = 384
) (
    input  logic clk,
    sram_if.slv  sram
);

    generate
        if (ADDR_W == 7 && DATA_W == 96) begin : g_128x96
            sram_128x96 u_macro (
                .CLK   (clk),
                .WEN   (sram.wr_en),
                .WADDR (sram.wr_addr),
                .WDATA (sram.wr_data),
                .REN   (sram.rd_en),
                .RADDR (sram.rd_addr),
                .RDATA (sram.rd_data)
            );
        end else if (ADDR_W == 7 && DATA_W == 104) begin : g_128x104
            sram_128x104 u_macro (
                .CLK   (clk),
                .WEN   (sram.wr_en),
                .WADDR (sram.wr_addr),
                .WDATA (sram.wr_data),
                .REN   (sram.rd_en),
                .RADDR (sram.rd_addr),
                .RDATA (sram.rd_data)
            );
        end else if (ADDR_W == 7 && DATA_W == 112) begin : g_128x112
            sram_128x112 u_macro (
                .CLK   (clk),
                .WEN   (sram.wr_en),
                .WADDR (sram.wr_addr),
                .WDATA (sram.wr_data),
                .REN   (sram.rd_en),
                .RADDR (sram.rd_addr),
                .RDATA (sram.rd_data)
            );
        end else if (ADDR_W == 7 && DATA_W == 120) begin : g_128x120
            sram_128x120 u_macro (
                .CLK   (clk),
                .WEN   (sram.wr_en),
                .WADDR (sram.wr_addr),
                .WDATA (sram.wr_data),
                .REN   (sram.rd_en),
                .RADDR (sram.rd_addr),
                .RDATA (sram.rd_data)
            );
        end else begin : g_unsupported
            initial begin
                $error("Unsupported SRAM configuration");
            end
        end
    endgenerate

endmodule
