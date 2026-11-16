// sram_macro_bb.sv
module sram_macro_bb #(
    parameter int ADDR_W = 5,
    parameter int DATA_W = 384
) (
    input  wire              CLK,
    input  wire              WEN,
    input  wire [ADDR_W-1:0] WADDR,
    input  wire [DATA_W-1:0] WDATA,
    input  wire              REN,
    input  wire [ADDR_W-1:0] RADDR,
    input  wire              DFT_BYPASS,
    output reg  [DATA_W-1:0] RDATA
);
`ifndef SYNTHESIS
    // synopsys translate_off
    localparam int DEPTH = 2**ADDR_W;
    logic [DATA_W-1:0] mem [0:DEPTH-1];
    logic [DATA_W-1:0] rdata_q;

    always_ff @(posedge CLK) begin
        if (WEN) mem[WADDR] <= WDATA;
        if (REN) rdata_q <= mem[RADDR];
    end

    assign RDATA = rdata_q;
    // synopsys translate_on
`endif
endmodule

module sram_128x96 (
    input  wire         CLK, WEN, REN, DFT_BYPASS,
    input  wire [6:0]   WADDR, RADDR,
    input  wire [95:0] WDATA,
    output wire [95:0] RDATA
);
    sram_macro_bb #(.ADDR_W(7), .DATA_W(96)) u_mem (.*);
endmodule

module sram_128x104 (
    input  wire         CLK, WEN, REN, DFT_BYPASS,
    input  wire [6:0]   WADDR, RADDR,
    input  wire [103:0] WDATA,
    output wire [103:0] RDATA
);
    sram_macro_bb #(.ADDR_W(7), .DATA_W(104)) u_mem (.*);
endmodule

module sram_128x112 (
    input  wire         CLK, WEN, REN, DFT_BYPASS,
    input  wire [6:0]   WADDR, RADDR,
    input  wire [111:0] WDATA,
    output wire [111:0] RDATA
);
    sram_macro_bb #(.ADDR_W(7), .DATA_W(112)) u_mem (.*);
endmodule

module sram_128x120 (
    input  wire         CLK, WEN, REN, DFT_BYPASS,
    input  wire [6:0]   WADDR, RADDR,
    input  wire [119:0] WDATA,
    output wire [119:0] RDATA
);
    sram_macro_bb #(.ADDR_W(7), .DATA_W(120)) u_mem (.*);
endmodule
