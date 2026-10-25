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
    output reg  [DATA_W-1:0] RDATA
);
`ifndef SYNTHESIS
    // synopsys translate_off
    localparam int DEPTH = 2**ADDR_W;
    logic [DATA_W-1:0] mem [0:DEPTH-1];

    always_ff @(posedge CLK) begin
        if (WEN) begin
            mem[WADDR] <= WDATA;
        end
        if (REN) begin
            RDATA <= mem[RADDR];
        end
    end
    // synopsys translate_on
`endif
endmodule

module sram_32x384 (
    input  wire         CLK, WEN, REN,
    input  wire [4:0]   WADDR, RADDR,
    input  wire [383:0] WDATA,
    output wire [383:0] RDATA
);
    sram_macro_bb #(.ADDR_W(5), .DATA_W(384)) u_mem (.*);
endmodule

module sram_32x416 (
    input  wire         CLK, WEN, REN,
    input  wire [4:0]   WADDR, RADDR,
    input  wire [415:0] WDATA,
    output wire [415:0] RDATA
);
    sram_macro_bb #(.ADDR_W(5), .DATA_W(416)) u_mem (.*);
endmodule

module sram_32x448 (
    input  wire         CLK, WEN, REN,
    input  wire [4:0]   WADDR, RADDR,
    input  wire [447:0] WDATA,
    output wire [447:0] RDATA
);
    sram_macro_bb #(.ADDR_W(5), .DATA_W(448)) u_mem (.*);
endmodule

module sram_32x480 (
    input  wire         CLK, WEN, REN,
    input  wire [4:0]   WADDR, RADDR,
    input  wire [479:0] WDATA,
    output wire [479:0] RDATA
);
    sram_macro_bb #(.ADDR_W(5), .DATA_W(480)) u_mem (.*);
endmodule
