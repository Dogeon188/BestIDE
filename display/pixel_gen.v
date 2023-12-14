module pixel_gen(
   input [9:0] h_cnt,
   input [9:0] MOUSE_X_POS,
   input valid,
   input enable_mouse_display,
   input [11:0] mouse_pixel,
   input MOUSE_LEFT,
   input MOUSE_RIGHT,
   output reg [3:0] vgaRed,
   output reg [3:0] vgaGreen,
   output reg [3:0] vgaBlue
);
   
assign flip_left = MOUSE_RIGHT || ( MOUSE_LEFT && (MOUSE_X_POS < 320) );
assign flip_right = MOUSE_RIGHT || ( MOUSE_LEFT && (MOUSE_X_POS > 320) );

always@(*) begin
    if(!valid) begin
        {vgaRed, vgaGreen, vgaBlue} = 12'h0;
    end else if(enable_mouse_display) begin
        {vgaRed, vgaGreen, vgaBlue} = mouse_pixel;
    end else begin
        if(h_cnt < 320) begin
            if(flip_left)begin
                {vgaRed, vgaGreen, vgaBlue} = 12'hb5f;
            end else begin
                {vgaRed, vgaGreen, vgaBlue} = 12'h0dd;
            end
        end else begin
            if(flip_right)begin
                {vgaRed, vgaGreen, vgaBlue} = 12'h0dd;
            end else begin
                {vgaRed, vgaGreen, vgaBlue} = 12'hb5f;
            end
        end
    end
end

endmodule
