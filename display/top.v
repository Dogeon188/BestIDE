module top(
   input clk,
   input rst,
   input end_of_editing,
   output [3:0] vgaRed,
   output [3:0] vgaGreen,
   output [3:0] vgaBlue,
   output hsync,
   output vsync,
   output [3:0]AN,
   output [6:0]SEG,
   inout wire PS2_CLK,
   inout wire PS2_DATA
);

    wire clk_25MHz, clk_segment;
    wire valid;
    reg isX, isX_next;
    wire [9:0] h_cnt; //640
    wire [9:0] v_cnt;  //480
    wire [9:0] pixel_addr = {v_cnt[4:0], h_cnt[4:0]};
    wire [9:0] write_addr;
    wire enable_mouse_display, enable_word_display;
    wire mouse_input_data;
    wire [9:0] MOUSE_X_POS , MOUSE_Y_POS;
    wire MOUSE_LEFT , MOUSE_MIDDLE , MOUSE_RIGHT , MOUSE_NEW_EVENT, extended_MOUSE_NEW_EVENT;
    wire [3:0] mouse_cursor_red , mouse_cursor_green , mouse_cursor_blue;
    wire mem_pixel, word_pixel;
    wire [11:0] pixel;
    wire [11:0] mouse_pixel = {mouse_cursor_red, mouse_cursor_green, mouse_cursor_blue};
    assign {vgaRed, vgaGreen, vgaBlue} = (valid==1'b1) ? pixel:12'h0;
    wire [4:0] writing_x, writing_y;
    wire [7:0] read_out_data;
    wire editing;
    wire ready_to_clear;
    wire [9:0] a_port;
    wire [9:0] read_out_canvas_addr;
    wire spo;
    wire rst_debounced, rst_onepulse, rst_extending_signal;
    assign a_port = write_enable ? write_addr : read_out_canvas_addr;

    extending_signal extending_signal_inst(
        .clk(~clk),
        .in(MOUSE_NEW_EVENT),
        .out(extended_MOUSE_NEW_EVENT)
    );

    debounce debounce_inst(
        .clk(clk),
        .in(rst),
        .out(rst_debounced)
    );

    onepulse onepulse_inst(
        .clk(clk),
        .in(rst_debounced),
        .out(rst_onepulse)
    );

    extending_signal extending_signal_inst2(
        .clk(~clk),
        .in(rst_onepulse),
        .out(rst_extending_signal)
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
        .pixel(pixel),
        .writing_x(writing_x),
        .writing_y(writing_y),
        .editing(editing)
    );

    mouse_input mouse_input_inst(
        .clk(clk_25MHz),
        .rst(rst_extending_signal),
        .MOUSE_X_POS(MOUSE_X_POS),
        .MOUSE_Y_POS(MOUSE_Y_POS),
        .MOUSE_LEFT(MOUSE_LEFT),
        .MOUSE_RIGHT(MOUSE_RIGHT),
        .new_event(extended_MOUSE_NEW_EVENT),
        .ready_to_clear(ready_to_clear),
        .write_addr(write_addr),
        .write_enable(write_enable),
        .write_data(mouse_input_data),
        .writing_x(writing_x),
        .writing_y(writing_y),
        .editing(editing)
    );

    word_display word_display_inst(
        .h_cnt(h_cnt),
        .v_cnt(v_cnt),
        .clk(clk_25MHz),
        .rst(rst),
        .write_addr({write_addr_y[3:0], write_addr_x}),
        .write_in_data(0),
        .write_ready(0),
        .read_enable(0),
        .read_addr(0),
        .clear_data(1'b0),
        .pixel_data(word_pixel),
        .enable_word_display(enable_word_display),
        .read_out_data(read_out_data)
    );

    small_canva sc(
        .a(write_addr),
        .d(mouse_input_data),
        .dpra(pixel_addr),
        .clk(clk_25MHz),
        .we(write_enable),
        .spo(spo),
        .dpo(mem_pixel)
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
      .reset(rst_extending_signal),
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

module debounce(clk, in, out);
    input clk, in;
    output out;

    reg [3:0] DFF;

    always @(posedge clk) begin
        DFF <= {DFF[2:0], in};
    end

    assign out = DFF[3] & DFF[2] & DFF[1] & DFF[0];
endmodule

module onepulse(clk, in, out);
    input clk, in;
    output out;

    reg A;

    always @(posedge clk) begin
        A <= in;
    end

    assign out = ~A & in;

endmodule