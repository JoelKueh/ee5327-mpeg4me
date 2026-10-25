// sram_wrapper.sv
module sram_wrapper #(
    parameter int ADDR_W = 5,
    parameter int DATA_W = 384
) (
    input  logic clk,
    sram_if.slv  sram
);

    generate
        if (ADDR_W == 5 && DATA_W == 384) begin : g_32x384
            sram_32x384 u_macro (
                .CLK   (clk),
                .WEN   (sram.wr_en),
                .WADDR (sram.wr_addr),
                .WDATA (sram.wr_data),
                .REN   (sram.rd_en),
                .RADDR (sram.rd_addr),
                .RDATA (sram.rd_data)
            );
        end else if (ADDR_W == 5 && DATA_W == 416) begin : g_32x416
            sram_32x416 u_macro (
                .CLK   (clk),
                .WEN   (sram.wr_en),
                .WADDR (sram.wr_addr),
                .WDATA (sram.wr_data),
                .REN   (sram.rd_en),
                .RADDR (sram.rd_addr),
                .RDATA (sram.rd_data)
            );
        end else if (ADDR_W == 5 && DATA_W == 448) begin : g_32x448
            sram_32x448 u_macro (
                .CLK   (clk),
                .WEN   (sram.wr_en),
                .WADDR (sram.wr_addr),
                .WDATA (sram.wr_data),
                .REN   (sram.rd_en),
                .RADDR (sram.rd_addr),
                .RDATA (sram.rd_data)
            );
        end else if (ADDR_W == 5 && DATA_W == 480) begin : g_32x480
            sram_32x480 u_macro (
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
