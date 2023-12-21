module pixel_gen(
   input valid,
   input enable_mouse_display,
   input [11:0] mouse_pixel,
   input mem_pixel,
   output reg [11:0] pixel
);

always@(*) begin
    if(!valid) begin
        pixel = 12'h0;
    end else if(enable_mouse_display) begin
        pixel = mouse_pixel;
    end else begin
        pixel = mem_pixel ? 12'h000 : 12'hfff;
    end
end

endmodule
