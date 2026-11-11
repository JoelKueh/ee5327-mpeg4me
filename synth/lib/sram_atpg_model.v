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
    // Fold WADDR, RADDR, WEN, REN into the lower 12 bits so their logic cones are observable
    wire [11:0] ctrl_obs = {WEN, REN, WADDR, RADDR};
    wire [383:0] bypass_data = {WDATA[383:12], WDATA[11:0] ^ ctrl_obs};

    // Gate with DFT_BYPASS (forces X when 0 so TMax requires DFT_BYPASS=1)
    assign RDATA = DFT_BYPASS ? bypass_data : 384'bx;
endmodule
`endcelldefine

`celldefine
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
    wire [11:0] ctrl_obs = {WEN, REN, WADDR, RADDR};
    wire [415:0] bypass_data = {WDATA[415:12], WDATA[11:0] ^ ctrl_obs};

    assign RDATA = DFT_BYPASS ? bypass_data : 416'bx;
endmodule
`endcelldefine

`celldefine
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
    wire [11:0] ctrl_obs = {WEN, REN, WADDR, RADDR};
    wire [447:0] bypass_data = {WDATA[447:12], WDATA[11:0] ^ ctrl_obs};

    assign RDATA = DFT_BYPASS ? bypass_data : 448'bx;
endmodule
`endcelldefine

`celldefine
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
    wire [11:0] ctrl_obs = {WEN, REN, WADDR, RADDR};
    wire [479:0] bypass_data = {WDATA[479:12], WDATA[11:0] ^ ctrl_obs};

    assign RDATA = DFT_BYPASS ? bypass_data : 480'bx;
endmodule
`endcelldefine
