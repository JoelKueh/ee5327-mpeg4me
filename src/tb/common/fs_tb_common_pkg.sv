// fs_tb_common_pkg.sv
//
// Common package used by fs unit tests.
//

package fs_tb_common_pkg;

    import me_pkg::*;

    typedef logic [PEL_W-1:0] pel_arr_unpacked_t[][];

    function automatic int sad_reference(
        int cb_start_row, int cb_start_col, int rb_start_row, int rb_start_col,
        int sad_height, int sad_width,
        const ref pel_arr_unpacked_t rb, const ref pel_arr_unpacked_t cb
    );
        int unsigned sum; // Prevents overflow when sad_height/width > 4
        logic [PEL_W-1:0] cb_pel, rb_pel;

        sum = 0;
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

        return int'(sum);
    endfunction

    // Removed ELE_W parameter since return type pel_arr_unpacked_t fixes width to PEL_W
    virtual class pel_unpack #(int HEIGHT = 4, int WIDTH = 4);
        static function pel_arr_unpacked_t f (logic [WIDTH-1:0][PEL_W-1:0] block[HEIGHT]);
            pel_arr_unpacked_t unpacked;

            // Allocate the 2D dynamic array to match the return type
            unpacked = new[HEIGHT];
            foreach (unpacked[row]) begin
                unpacked[row] = new[WIDTH];
                for (int col = 0; col < WIDTH; col++) begin
                    unpacked[row][col] = block[row][col];
                end
            end

            return unpacked;
        endfunction
    endclass

endpackage
