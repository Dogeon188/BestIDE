module top(
   input clk,
   input rst,
   output [3:0] vgaRed,
   output [3:0] vgaGreen,
   output [3:0] vgaBlue,
   output hsync,
   output vsync,
   output [3:0]AN,
   output [6:0]SEG,
   inout PS2_CLK,
   inout PS2_DATA
);

    wire clk_25MHz;
    wire clk_segment;
    wire valid;
    reg isX, isX_next;
    wire [9:0] h_cnt; //640
    wire [9:0] v_cnt;  //480
    wire [18:0] pixel_addr = {v_cnt, h_cnt};
    wire [18:0] write_addr;
    wire enable_mouse_display, enable_word_display;
    wire data;
    wire [9 : 0] MOUSE_X_POS , MOUSE_Y_POS;
    wire MOUSE_LEFT , MOUSE_MIDDLE , MOUSE_RIGHT , MOUSE_NEW_EVENT, extended_MOUSE_NEW_EVENT;
    wire [3 : 0] mouse_cursor_red , mouse_cursor_green , mouse_cursor_blue;
    wire mem_pixel, word_pixel;
    wire [11:0] pixel;
    wire [11:0] mouse_pixel = {mouse_cursor_red, mouse_cursor_green, mouse_cursor_blue};
    assign {vgaRed, vgaGreen, vgaBlue} = (valid==1'b1) ? pixel:12'h0;

    extending_signal extending_signal_inst(
        .clk(~clk),
        .in(MOUSE_NEW_EVENT),
        .out(extended_MOUSE_NEW_EVENT)
    );

    clock_divisor clk_wiz_0_inst(
        .clk(clk),
        .clk1(clk_25MHz),
        .clk17(clk_segment)
    );

    pixel_gen pixel_gen_inst(
        .valid(valid),
        .enable_mouse_display(enable_mouse_display),
        .enable_word_display(enable_word_display),
        .h_cnt(h_cnt),
        .v_cnt(v_cnt),
        .mouse_pixel(mouse_pixel),
        .word_pixel(word_pixel),
        .mem_pixel(mem_pixel),
        .pixel(pixel)
    );

    mouse_input mouse_input_inst(
        .clk(clk_25MHz),
        .rst(rst),
        .MOUSE_X_POS(MOUSE_X_POS),
        .MOUSE_Y_POS(MOUSE_Y_POS),
        .MOUSE_LEFT(MOUSE_LEFT),
        .MOUSE_RIGHT(MOUSE_RIGHT),
        .new_event(extended_MOUSE_NEW_EVENT),
        .write_addr(write_addr),
        .write_enable(write_enable),
        .write_data(data)
    );

    word_display word_display_inst(
        .h_cnt(h_cnt),
        .v_cnt(v_cnt),
        .clk(clk_25MHz),
        .rst(rst),
        .enable_word_display(enable_word_display),
        .pixel_data(word_pixel)
    );

    blk_mem_gen_0 blk_mem_gen_0_inst(
      .clka(clk_25MHz),
      .wea(write_enable),
      .addra(write_addr),
      .dina(data),
      .doutb(mem_pixel),
      .clkb(clk_25MHz),
      .enb(1'b1),
      .addrb(pixel_addr)
    ); 
    
    segment_display seg(
      .clk(clk_segment),
      .MOUSE_X_POS(MOUSE_X_POS),
      .MOUSE_Y_POS(MOUSE_Y_POS),
      .isX(isX),
      .AN(AN),
      .SEG(SEG)
    );

    vga_controller vga_inst(
      .pclk(clk_25MHz),
      .reset(rst),
      .hsync(hsync),
      .vsync(vsync),
      .valid(valid),
      .h_cnt(h_cnt),
      .v_cnt(v_cnt)
    );
    
    mouse mouse_ctrl_inst(
        .clk(clk),
        .h_cntr_reg(h_cnt),
        .v_cntr_reg(v_cnt),
        .enable_mouse_display(enable_mouse_display),
        .MOUSE_X_POS(MOUSE_X_POS),
        .MOUSE_Y_POS(MOUSE_Y_POS),
        .MOUSE_LEFT(MOUSE_LEFT),
        .MOUSE_MIDDLE(MOUSE_MIDDLE),
        .MOUSE_RIGHT(MOUSE_RIGHT),
        .MOUSE_NEW_EVENT(MOUSE_NEW_EVENT),
        .mouse_cursor_red(mouse_cursor_red),
        .mouse_cursor_green(mouse_cursor_green),
        .mouse_cursor_blue(mouse_cursor_blue),
        .PS2_CLK(PS2_CLK),
        .PS2_DATA(PS2_DATA)
    );

    always@(posedge clk)begin
        if(rst) begin
            isX <= 1'b1;
        end else begin
            isX <= isX_next;
        end
    end
    
    always@(*) begin
        isX_next = isX;
        if(MOUSE_LEFT) begin
            isX_next = 1'b1;
        end else if(MOUSE_RIGHT) begin
            isX_next = 1'b0;
        end
    end
      
endmodule


module extending_signal(clk, in, out);
    input clk;
    input in;
    output out;

    reg [2:0] counter;

    always @(posedge clk) begin
        if(in) begin
            counter <= 3'b111;
        end 
        else begin
            counter <= counter[2] ? counter - 1 : counter;
        end
    end
    assign out = counter[2];
endmodule