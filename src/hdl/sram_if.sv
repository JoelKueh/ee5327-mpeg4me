// sram_if.sv
//
// Generic interface for an SRAM.
// Assumes single-cycle read.
//

interface sram_if#(
    parameter ADDR_W=10,
    parameter DATA_W=32
) (
    inout wire clk
);

    logic              wr_en;
    logic [ADDR_W-1:0] wr_addr;
    logic [DATA_W-1:0] wr_data;

    logic              rd_en;
    logic [ADDR_W-1:0] rd_addr;
    logic [DATA_W-1:0] rd_data;

    modport mstr (
        input  rd_data,
        output wr_en, wr_addr, rd_en, rd_addr
    );

    modport slv (
        input  wr_en, wr_addr, rd_en, rd_addr,
        output rd_data
    );

endinterface
