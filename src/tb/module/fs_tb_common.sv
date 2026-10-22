// fs_tb_common_pkg.sv
//
// Common package used by fs unit tests.
//

package fs_tb_common_pkg;

    import me_pkg::*;
    import svunit_pkg::svunit_testcase;

    function automatic int sad(
        int cb_start_row, int cb_start_col, int rb_start_row, int rb_start_col,
        int sad_height, int sad_width,
        logic [PEL_W-1:0] rb[][], logic [PEL_W-1:0] cb[][]
    );
        logic [SAD_4X4_W-1:0] sum;
        logic [PEL_W-1:0] cb_pel, rb_pel;

        sum = '0;
        for (int i = 0; i < sad_height; i++) begin
            for (int j = 0; j < sad_width; j++) begin
                cb_pel = cb[cb_start_row+i][cb_start_col+j];
                rb_pel = rb[rb_start_row+i][rb_start_col+j];

                if (cb_pel >= rb_pel) begin
                    sum += cb_pel - rb_pel;
                end else begin
                    sum += rb_pel - cb_pel;
                end
            end
        end

        return sum;
    endfunction

endpackage
