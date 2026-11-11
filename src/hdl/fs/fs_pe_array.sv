// fs_pe_array.sv
//
// Array of processors for SAD computation. Computes a row of 4x4 SADs every
// cycle after fringe after a 3-cycle warm up.
//

module fs_pe_array (
    input logic       clk,              // The primary clock
    input logic       load,             // Load cb_q[0] from input?
    input logic       stall_next,       // Should the PE array stall next cycle
    input logic [1:0] row_idx_mod_next, // Mod of the row served on rb next cycle

    input logic [me_pkg::WINDOW_SIZE+2:0][me_pkg::PEL_W-1:0] rb,       // Reference block input
    input logic [                    3:0][me_pkg::PEL_W-1:0] cb_next,  // Next current block input

    output logic [me_pkg::SAD_4X4_W-1:0] sad[me_pkg::WINDOW_SIZE]
);

    import me_pkg::*;

    logic [SAD_4X4_W-1:0] pe_sad[4][WINDOW_SIZE];        // Results from each PE row
    logic clear_q[4] /* synopsys preserve_sequential */; // Pipelined row clear signal
    logic clear_d[4];
    logic stall_q[4] /* synopsys preserve_sequential */; // Pipelined row stall signal
    logic stall_d[4];

    // Embedded DC Tcl constraint: prevents OPT-1215 merging on stall_q/clear_q
    // while allowing scan replacement
    // synopsys dc_tcl_script_begin
    // set_register_merging [get_cells {stall_q_reg* clear_q_reg*}] false
    // synopsys dc_tcl_script_end

    logic [3:0][PEL_W-1:0] cb_q[4], cb_d[4];       // Ring of candidate frame 
    logic [1:0] row_select_q[2], row_select_d[2];  // Row select signal

    // Instantiate the rows of engines
    genvar row, col;
    generate
        for (row = 0; row < 4; row++) begin : pe_array_row
            for (col = 0; col < WINDOW_SIZE; col++) begin : pe_array_col
                fs_pe pe (
                    .clk(clk),
                    .stall(stall_q[row]),
                    .clear(clear_q[row]),
                    .rb(rb[col+3:col]),
                    .cb(cb_q[row]),
                    .sad(pe_sad[row][col])
                );
            end
        end
    endgenerate

    always_comb begin
        // Clear rows when a row is receiving data for a new SAD
        for (int i = 0; i < 4; i++) clear_d[i] = '0;
        clear_d[row_idx_mod_next] = '1;

        // The row finishing its 4th accumulation is the row that started three cycles ago.
        row_select_d[0] = row_idx_mod_next + 2'd1;
        row_select_d[1] = row_select_q[0];

        // Stall one cycle after receiving stall_next 
        for (int i = 0; i < 4; i++) stall_d[i] = stall_next;

        // Advance the CF buffer
        for (int i = 0; i < 4; i++) cb_d[(i+1)%4] = cb_q[i];
        if (load) cb_d[0] = cb_next;

        // Mux the row output into the sad output
        sad = pe_sad[row_select_q[1]];
    end

    // Buffer the result output.
    always_ff @(posedge clk) begin
        // Stage 0 registers stall with the computer
        if (!stall_next) begin
            cb_q <= cb_d;
            row_select_q[0] <= row_select_d[0];
            clear_q <= clear_d;
        end

        // Stage 1 mux select stalls along with the PEs on stall_q
        if (!stall_q[0]) begin
            row_select_q[1] <= row_select_d[1];
        end

        stall_q <= stall_d;
    end

endmodule
