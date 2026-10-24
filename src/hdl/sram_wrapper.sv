// sram_wrapper.sv
module sram_wrapper #(
    parameter int ADDR_W = 10,
    parameter int DATA_W = 32
) (
    input  logic clk,
    sram_if.slv  sram
);

    sram_macro_bb #(
        .ADDR_W (ADDR_W),
        .DATA_W (DATA_W)
    ) u_macro (
        .CLK   (clk),
        .WEN   (sram.wr_en),
        .WADDR (sram.wr_addr),
        .WDATA (sram.wr_data),
        .REN   (sram.rd_en),
        .RADDR (sram.rd_addr),
        .RDATA (sram.rd_data)
    );

endmodule
