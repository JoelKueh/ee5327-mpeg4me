`celldefine

module sram_32x384 (
    input  wire         CLK,
    input  wire         WEN,
    input  wire         REN,
    input  wire         DFT_BYPASS,
    input  wire [4:0]   WADDR,
    input  wire [4:0]   RADDR,
    input  wire [383:0] WDATA,
    output wire [383:0] RDATA
);
    assign RDATA = WDATA;
endmodule

module sram_32x416 (
    input  wire         CLK,
    input  wire         WEN,
    input  wire         REN,
    input  wire         DFT_BYPASS,
    input  wire [4:0]   WADDR,
    input  wire [4:0]   RADDR,
    input  wire [415:0] WDATA,
    output wire [415:0] RDATA
);
    assign RDATA = WDATA;
endmodule

module sram_32x448 (
    input  wire         CLK,
    input  wire         WEN,
    input  wire         REN,
    input  wire         DFT_BYPASS,
    input  wire [4:0]   WADDR,
    input  wire [4:0]   RADDR,
    input  wire [447:0] WDATA,
    output wire [447:0] RDATA
);
    assign RDATA = WDATA;
endmodule

module sram_32x480 (
    input  wire         CLK,
    input  wire         WEN,
    input  wire         REN,
    input  wire         DFT_BYPASS,
    input  wire [4:0]   WADDR,
    input  wire [4:0]   RADDR,
    input  wire [479:0] WDATA,
    output wire [479:0] RDATA
);
    assign RDATA = WDATA;
endmodule

`endcelldefine
