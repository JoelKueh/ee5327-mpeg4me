// sram_macro_bb.sv
(* black_box *)
(* syn_black_box *)
module sram_macro_bb #(
    parameter int ADDR_W = 10,
    parameter int DATA_W = 32
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
