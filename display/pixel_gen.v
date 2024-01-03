module pixel_gen(
    input valid,
    input enable_mouse_display,
    input enable_word_display,
    input [9:0] h_cnt,
    input [8:0] v_cnt,
    input [11:0] mouse_pixel,
    input canvas_vga_pixel,
    input word_pixel,
    input [8:0] writing_block_pos,
    input editing,
    input [9:0] MOUSE_X_POS,
    input [8:0] MOUSE_Y_POS,
    output reg [11:0] pixel_color
);

wire [4:0] writing_block_x_pos = writing_block_pos[4:0];
wire [3:0] writing_block_y_pos = writing_block_pos[8:5];

always@(*) begin
    if(!valid) begin
        pixel_color = 12'h0;
    end 
    else if(enable_mouse_display) begin
        pixel_color = mouse_pixel;
    end 
    else if(editing && h_cnt[9:5] == writing_block_x_pos && v_cnt[8:5] == writing_block_y_pos) begin
        if(h_cnt[4:0] == 0 || h_cnt[4:0] == 31 || v_cnt[4:0] == 0 || v_cnt[4:0] == 31) begin
            pixel_color = 12'h0df;
        end
        else begin
            pixel_color = canvas_vga_pixel ? 12'hddd : 12'h000;
        end
    end
    else if(h_cnt[4:0] == 0 || h_cnt[4:0] == 31 || v_cnt[4:0] == 0 || v_cnt[4:0] == 31) begin
        if(!editing && h_cnt[9:5] == MOUSE_X_POS[9:5] && v_cnt[8:5] == MOUSE_Y_POS[8:5]) begin
            pixel_color = 12'h0df;
        end
        else begin
            pixel_color = 12'h333;
        end
    end
    else if(enable_word_display) begin
        if(word_pixel) begin
            pixel_color = 12'hddd;
        end
        else begin
            pixel_color = 12'h000;
        end
    end
    else begin
        pixel_color = 12'h000;
    end
end

endmodule
