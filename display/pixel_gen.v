module pixel_gen(
    input valid,
    input enable_mouse_display,
    input enable_word_display,
    input [9:0] h_cnt,
    input [9:0] v_cnt,
    input [11:0] mouse_pixel,
    input mem_pixel,
    input word_pixel,
    output reg [11:0] pixel
);

always@(*) begin
    if(!valid) begin
        pixel = 12'h0;
    end 
    else if(enable_mouse_display) begin
        pixel = mouse_pixel;
    end 
    else if(h_cnt % 32 == 0 || h_cnt % 32 == 31 || v_cnt % 32 == 0 || v_cnt % 32 == 31)begin
        pixel = mem_pixel ? 12'hccc : 12'h333;
    end
    else if(enable_word_display) begin
        pixel = word_pixel ? 12'hfff : 12'h000;
    end
    else begin
        pixel = mem_pixel ? 12'hfff : 12'h000;
    end
end

endmodule
