`celldefine
module sram_128x96 (
    input         CLK,
    input         WEN,
    input         REN,
    input         DFT_BYPASS,
    input  [6:0]  WADDR,
    input  [6:0]  RADDR,
    input  [95:0] WDATA,
    output [95:0] RDATA
);
    wire x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15, x16;

    xor g0  (x0,  WDATA[0],  RADDR[0]);
    xor g1  (x1,  WDATA[1],  RADDR[1]);
    xor g2  (x2,  WDATA[2],  RADDR[2]);
    xor g3  (x3,  WDATA[3],  RADDR[3]);
    xor g4  (x4,  WDATA[4],  RADDR[4]);
    xor g5  (x5,  WDATA[5],  RADDR[5]);
    xor g6  (x6,  WDATA[6],  RADDR[6]);
    xor g7  (x7,  WDATA[7],  WADDR[0]);
    xor g8  (x8,  WDATA[8],  WADDR[1]);
    xor g9  (x9,  WDATA[9],  WADDR[2]);
    xor g10 (x10, WDATA[10], WADDR[3]);
    xor g11 (x11, WDATA[11], WADDR[4]);
    xor g12 (x12, WDATA[12], WADDR[5]);
    xor g13 (x13, WDATA[13], WADDR[6]);
    xor g14 (x14, WDATA[14], REN);
    xor g15 (x15, WDATA[15], WEN);
    xor g16 (x16, WDATA[16], CLK);

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
    and a13 (RDATA[13], x13, DFT_BYPASS);
    and a14 (RDATA[14], x14, DFT_BYPASS);
    and a15 (RDATA[15], x15, DFT_BYPASS);
    and a16 (RDATA[16], x16, DFT_BYPASS);

    assign RDATA[95:17] = WDATA[95:17];
endmodule
`endcelldefine

`celldefine
module sram_128x104 (
    input          CLK,
    input          WEN,
    input          REN,
    input          DFT_BYPASS,
    input  [6:0]   WADDR,
    input  [6:0]   RADDR,
    input  [103:0] WDATA,
    output [103:0] RDATA
);
    wire x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15, x16;

    xor g0  (x0,  WDATA[0],  RADDR[0]);
    xor g1  (x1,  WDATA[1],  RADDR[1]);
    xor g2  (x2,  WDATA[2],  RADDR[2]);
    xor g3  (x3,  WDATA[3],  RADDR[3]);
    xor g4  (x4,  WDATA[4],  RADDR[4]);
    xor g5  (x5,  WDATA[5],  RADDR[5]);
    xor g6  (x6,  WDATA[6],  RADDR[6]);
    xor g7  (x7,  WDATA[7],  WADDR[0]);
    xor g8  (x8,  WDATA[8],  WADDR[1]);
    xor g9  (x9,  WDATA[9],  WADDR[2]);
    xor g10 (x10, WDATA[10], WADDR[3]);
    xor g11 (x11, WDATA[11], WADDR[4]);
    xor g12 (x12, WDATA[12], WADDR[5]);
    xor g13 (x13, WDATA[13], WADDR[6]);
    xor g14 (x14, WDATA[14], REN);
    xor g15 (x15, WDATA[15], WEN);
    xor g16 (x16, WDATA[16], CLK);

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
    and a13 (RDATA[13], x13, DFT_BYPASS);
    and a14 (RDATA[14], x14, DFT_BYPASS);
    and a15 (RDATA[15], x15, DFT_BYPASS);
    and a16 (RDATA[16], x16, DFT_BYPASS);

    assign RDATA[103:17] = WDATA[103:17];
endmodule
`endcelldefine

`celldefine
module sram_128x112 (
    input          CLK,
    input          WEN,
    input          REN,
    input          DFT_BYPASS,
    input  [6:0]   WADDR,
    input  [6:0]   RADDR,
    input  [111:0] WDATA,
    output [111:0] RDATA
);
    wire x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15, x16;

    xor g0  (x0,  WDATA[0],  RADDR[0]);
    xor g1  (x1,  WDATA[1],  RADDR[1]);
    xor g2  (x2,  WDATA[2],  RADDR[2]);
    xor g3  (x3,  WDATA[3],  RADDR[3]);
    xor g4  (x4,  WDATA[4],  RADDR[4]);
    xor g5  (x5,  WDATA[5],  RADDR[5]);
    xor g6  (x6,  WDATA[6],  RADDR[6]);
    xor g7  (x7,  WDATA[7],  WADDR[0]);
    xor g8  (x8,  WDATA[8],  WADDR[1]);
    xor g9  (x9,  WDATA[9],  WADDR[2]);
    xor g10 (x10, WDATA[10], WADDR[3]);
    xor g11 (x11, WDATA[11], WADDR[4]);
    xor g12 (x12, WDATA[12], WADDR[5]);
    xor g13 (x13, WDATA[13], WADDR[6]);
    xor g14 (x14, WDATA[14], REN);
    xor g15 (x15, WDATA[15], WEN);
    xor g16 (x16, WDATA[16], CLK);

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
    and a13 (RDATA[13], x13, DFT_BYPASS);
    and a14 (RDATA[14], x14, DFT_BYPASS);
    and a15 (RDATA[15], x15, DFT_BYPASS);
    and a16 (RDATA[16], x16, DFT_BYPASS);

    assign RDATA[111:17] = WDATA[111:17];
endmodule
`endcelldefine

`celldefine
module sram_128x120 (
    input          CLK,
    input          WEN,
    input          REN,
    input          DFT_BYPASS,
    input  [6:0]   WADDR,
    input  [6:0]   RADDR,
    input  [119:0] WDATA,
    output [119:0] RDATA
);
    wire x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15, x16;

    xor g0  (x0,  WDATA[0],  RADDR[0]);
    xor g1  (x1,  WDATA[1],  RADDR[1]);
    xor g2  (x2,  WDATA[2],  RADDR[2]);
    xor g3  (x3,  WDATA[3],  RADDR[3]);
    xor g4  (x4,  WDATA[4],  RADDR[4]);
    xor g5  (x5,  WDATA[5],  RADDR[5]);
    xor g6  (x6,  WDATA[6],  RADDR[6]);
    xor g7  (x7,  WDATA[7],  WADDR[0]);
    xor g8  (x8,  WDATA[8],  WADDR[1]);
    xor g9  (x9,  WDATA[9],  WADDR[2]);
    xor g10 (x10, WDATA[10], WADDR[3]);
    xor g11 (x11, WDATA[11], WADDR[4]);
    xor g12 (x12, WDATA[12], WADDR[5]);
    xor g13 (x13, WDATA[13], WADDR[6]);
    xor g14 (x14, WDATA[14], REN);
    xor g15 (x15, WDATA[15], WEN);
    xor g16 (x16, WDATA[16], CLK);

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
    and a13 (RDATA[13], x13, DFT_BYPASS);
    and a14 (RDATA[14], x14, DFT_BYPASS);
    and a15 (RDATA[15], x15, DFT_BYPASS);
    and a16 (RDATA[16], x16, DFT_BYPASS);

    assign RDATA[119:17] = WDATA[119:17];
endmodule
`endcelldefine
