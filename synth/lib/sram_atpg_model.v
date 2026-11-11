`celldefine
module sram_32x384 (
    input         CLK,
    input         WEN,
    input         REN,
    input         DFT_BYPASS,
    input  [4:0]  WADDR,
    input  [4:0]  RADDR,
    input  [383:0] WDATA,
    output [383:0] RDATA
);
    wire x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12;

    xor g0  (x0,  WDATA[0],  RADDR[0]);
    xor g1  (x1,  WDATA[1],  RADDR[1]);
    xor g2  (x2,  WDATA[2],  RADDR[2]);
    xor g3  (x3,  WDATA[3],  RADDR[3]);
    xor g4  (x4,  WDATA[4],  RADDR[4]);
    xor g5  (x5,  WDATA[5],  WADDR[0]);
    xor g6  (x6,  WDATA[6],  WADDR[1]);
    xor g7  (x7,  WDATA[7],  WADDR[2]);
    xor g8  (x8,  WDATA[8],  WADDR[3]);
    xor g9  (x9,  WDATA[9],  WADDR[4]);
    xor g10 (x10, WDATA[10], REN);
    xor g11 (x11, WDATA[11], WEN);
    xor g12 (x12, WDATA[12], CLK);

    and a0  (RDATA[0],  x0,  DFT_BYPASS);
    and a1  (RDATA[1],  x1,  DFT_BYPASS);
    and a2  (RDATA[2],  x2,  DFT_BYPASS);
    and a3  (RDATA[3],  x3,  DFT_BYPASS);
    and a4  (RDATA[4],  x4,  DFT_BYPASS);
    and a5  (RDATA[5],  x5,  DFT_BYPASS);
    and a6  (RDATA[6],  x6,  DFT_BYPASS);
    and a7  (RDATA[7],  x7,  DFT_BYPASS);
    and a8  (RDATA[8],  x8,  DFT_BYPASS);
    and a9  (RDATA[9],  x9,  DFT_BYPASS);
    and a10 (RDATA[10], x10, DFT_BYPASS);
    and a11 (RDATA[11], x11, DFT_BYPASS);
    and a12 (RDATA[12], x12, DFT_BYPASS);

    assign RDATA[383:13] = WDATA[383:13];
endmodule
`endcelldefine

`celldefine
module sram_32x416 (
    input         CLK,
    input         WEN,
    input         REN,
    input         DFT_BYPASS,
    input  [4:0]  WADDR,
    input  [4:0]  RADDR,
    input  [415:0] WDATA,
    output [415:0] RDATA
);
    wire x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12;

    xor g0  (x0,  WDATA[0],  RADDR[0]);
    xor g1  (x1,  WDATA[1],  RADDR[1]);
    xor g2  (x2,  WDATA[2],  RADDR[2]);
    xor g3  (x3,  WDATA[3],  RADDR[3]);
    xor g4  (x4,  WDATA[4],  RADDR[4]);
    xor g5  (x5,  WDATA[5],  WADDR[0]);
    xor g6  (x6,  WDATA[6],  WADDR[1]);
    xor g7  (x7,  WDATA[7],  WADDR[2]);
    xor g8  (x8,  WDATA[8],  WADDR[3]);
    xor g9  (x9,  WDATA[9],  WADDR[4]);
    xor g10 (x10, WDATA[10], REN);
    xor g11 (x11, WDATA[11], WEN);
    xor g12 (x12, WDATA[12], CLK);

    and a0  (RDATA[0],  x0,  DFT_BYPASS);
    and a1  (RDATA[1],  x1,  DFT_BYPASS);
    and a2  (RDATA[2],  x2,  DFT_BYPASS);
    and a3  (RDATA[3],  x3,  DFT_BYPASS);
    and a4  (RDATA[4],  x4,  DFT_BYPASS);
    and a5  (RDATA[5],  x5,  DFT_BYPASS);
    and a6  (RDATA[6],  x6,  DFT_BYPASS);
    and a7  (RDATA[7],  x7,  DFT_BYPASS);
    and a8  (RDATA[8],  x8,  DFT_BYPASS);
    and a9  (RDATA[9],  x9,  DFT_BYPASS);
    and a10 (RDATA[10], x10, DFT_BYPASS);
    and a11 (RDATA[11], x11, DFT_BYPASS);
    and a12 (RDATA[12], x12, DFT_BYPASS);

    assign RDATA[415:13] = WDATA[415:13];
endmodule
`endcelldefine

`celldefine
module sram_32x448 (
    input         CLK,
    input         WEN,
    input         REN,
    input         DFT_BYPASS,
    input  [4:0]  WADDR,
    input  [4:0]  RADDR,
    input  [447:0] WDATA,
    output [447:0] RDATA
);
    wire x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12;

    xor g0  (x0,  WDATA[0],  RADDR[0]);
    xor g1  (x1,  WDATA[1],  RADDR[1]);
    xor g2  (x2,  WDATA[2],  RADDR[2]);
    xor g3  (x3,  WDATA[3],  RADDR[3]);
    xor g4  (x4,  WDATA[4],  RADDR[4]);
    xor g5  (x5,  WDATA[5],  WADDR[0]);
    xor g6  (x6,  WDATA[6],  WADDR[1]);
    xor g7  (x7,  WDATA[7],  WADDR[2]);
    xor g8  (x8,  WDATA[8],  WADDR[3]);
    xor g9  (x9,  WDATA[9],  WADDR[4]);
    xor g10 (x10, WDATA[10], REN);
    xor g11 (x11, WDATA[11], WEN);
    xor g12 (x12, WDATA[12], CLK);

    and a0  (RDATA[0],  x0,  DFT_BYPASS);
    and a1  (RDATA[1],  x1,  DFT_BYPASS);
    and a2  (RDATA[2],  x2,  DFT_BYPASS);
    and a3  (RDATA[3],  x3,  DFT_BYPASS);
    and a4  (RDATA[4],  x4,  DFT_BYPASS);
    and a5  (RDATA[5],  x5,  DFT_BYPASS);
    and a6  (RDATA[6],  x6,  DFT_BYPASS);
    and a7  (RDATA[7],  x7,  DFT_BYPASS);
    and a8  (RDATA[8],  x8,  DFT_BYPASS);
    and a9  (RDATA[9],  x9,  DFT_BYPASS);
    and a10 (RDATA[10], x10, DFT_BYPASS);
    and a11 (RDATA[11], x11, DFT_BYPASS);
    and a12 (RDATA[12], x12, DFT_BYPASS);

    assign RDATA[447:13] = WDATA[447:13];
endmodule
`endcelldefine

`celldefine
module sram_32x480 (
    input         CLK,
    input         WEN,
    input         REN,
    input         DFT_BYPASS,
    input  [4:0]  WADDR,
    input  [4:0]  RADDR,
    input  [479:0] WDATA,
    output [479:0] RDATA
);
    wire x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12;

    xor g0  (x0,  WDATA[0],  RADDR[0]);
    xor g1  (x1,  WDATA[1],  RADDR[1]);
    xor g2  (x2,  WDATA[2],  RADDR[2]);
    xor g3  (x3,  WDATA[3],  RADDR[3]);
    xor g4  (x4,  WDATA[4],  RADDR[4]);
    xor g5  (x5,  WDATA[5],  WADDR[0]);
    xor g6  (x6,  WDATA[6],  WADDR[1]);
    xor g7  (x7,  WDATA[7],  WADDR[2]);
    xor g8  (x8,  WDATA[8],  WADDR[3]);
    xor g9  (x9,  WDATA[9],  WADDR[4]);
    xor g10 (x10, WDATA[10], REN);
    xor g11 (x11, WDATA[11], WEN);
    xor g12 (x12, WDATA[12], CLK);

    and a0  (RDATA[0],  x0,  DFT_BYPASS);
    and a1  (RDATA[1],  x1,  DFT_BYPASS);
    and a2  (RDATA[2],  x2,  DFT_BYPASS);
    and a3  (RDATA[3],  x3,  DFT_BYPASS);
    and a4  (RDATA[4],  x4,  DFT_BYPASS);
    and a5  (RDATA[5],  x5,  DFT_BYPASS);
    and a6  (RDATA[6],  x6,  DFT_BYPASS);
    and a7  (RDATA[7],  x7,  DFT_BYPASS);
    and a8  (RDATA[8],  x8,  DFT_BYPASS);
    and a9  (RDATA[9],  x9,  DFT_BYPASS);
    and a10 (RDATA[10], x10, DFT_BYPASS);
    and a11 (RDATA[11], x11, DFT_BYPASS);
    and a12 (RDATA[12], x12, DFT_BYPASS);

    assign RDATA[479:13] = WDATA[479:13];
endmodule
`endcelldefine
