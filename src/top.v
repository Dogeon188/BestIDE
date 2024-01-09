module top(
    input clk,
    input rst,
    input send,
    input clear_data,
    output [3:0] vgaRed,
    output [3:0] vgaGreen,
    output [3:0] vgaBlue,
    output hsync,
    output vsync,
    output RsTx,
    inout wire PS2_CLK,
    inout wire PS2_DATA
);

    wire clk_25MHz, clk_400Hz;
    wire clear_data_debounced, clear_data_onepulse;
    wire valid;
    wire [9:0] h_cnt; //640
    wire [8:0] v_cnt;  //480
    wire [9:0] pixel_addr = {v_cnt[4:0], h_cnt[4:0]};
    wire [9:0] write_addr;
    wire enable_mouse_display, enable_word_display;
    wire mouse_input_data;
    wire [9:0] MOUSE_X_POS , MOUSE_Y_POS;
    wire MOUSE_LEFT , MOUSE_MIDDLE , MOUSE_RIGHT , MOUSE_NEW_EVENT, MOUSE_RIGHT_onepulse;
    wire [3:0] mouse_cursor_red , mouse_cursor_green , mouse_cursor_blue;
    wire canvas_vga_pixel;
    wire [11:0] pixel_color;
    wire [0:15] font_pixels;
    wire [11:0] mouse_pixel = {mouse_cursor_red, mouse_cursor_green, mouse_cursor_blue};
    assign {vgaRed, vgaGreen, vgaBlue} = (valid==1'b1) ? pixel_color:12'h0;
    wire [8:0] writing_block_pos;
    wire block_editing;
    wire [7:0] UART_read_data;
    wire UART_read_en;
    wire [9:0] UART_read_addr; 
    wire ready_to_clear_canvas;
    wire [9:0] small_canvas_addr;
    wire [6:0] font_index;
    wire [9:0] read_out_canvas_addr;
    wire recognizer_read_in_data;
    wire mouse_write_enable;
    wire send_debounced, send_onepulse;
    wire rst_debounced, rst_onepulse, rst_extended;
    wire canvas_read_enable;
    assign small_canvas_addr = canvas_read_enable ? read_out_canvas_addr : write_addr;
    wire word_pixel = font_pixels[h_cnt[4:1]];
    wire [8:0] doc_a;
    wire [7:0] doc_d;
    wire doc_we;
    wire [7:0] text_write;
    wire canvas_write_enable = mouse_write_enable && ~canvas_read_enable;
    wire [7:0] doc_write_in_data;
    wire recognizer_pending;
    
    debounce debounce_rst(
        .clk(clk_400Hz),
        .in(rst),
        .out(rst_debounced)
    );

    debounce debounce_send(
        .clk(clk_400Hz),
        .in(send),
        .out(send_debounced)
    );
    
    onepulse onepulse_send(
        .clk(clk),
        .in(send_debounced),
        .out(send_onepulse)
    );

    onepulse onepulse_rst(
        .clk(clk),
        .in(rst_debounced),
        .out(rst_onepulse)
    );

    onepulse onepulse_MOUSE_RIGHT(
        .clk(clk),
        .in(MOUSE_RIGHT),
        .out(MOUSE_RIGHT_onepulse)
    );

    debounce debounce_clear_data(
        .clk(clk_400Hz),
        .in(clear_data),
        .out(clear_data_debounced)
    );

    onepulse onepulse_clear_data(
        .clk(clk),
        .in(clear_data_debounced),
        .out(clear_data_onepulse)
    );

    extending_signal extending_signal_rst(
        .clk(clk),
        .in(rst_onepulse),
        .out(rst_extended)
    );

    clock_divisor clk_wiz_0_inst(
        .clk(clk),
        .clk_25MHz(clk_25MHz),
        .clk_400Hz(clk_400Hz)
    );

    pixel_gen pixel_gen_inst(
        .valid(valid),
        .enable_mouse_display(enable_mouse_display),
        .enable_word_display(enable_word_display),
        .h_cnt(h_cnt),
        .v_cnt(v_cnt),
        .mouse_pixel(mouse_pixel),
        .word_pixel(word_pixel),
        .canvas_vga_pixel(canvas_vga_pixel),
        .pixel_color(pixel_color),
        .writing_block_pos(writing_block_pos),
        .MOUSE_X_POS_block(MOUSE_X_POS[9:5]),
        .MOUSE_Y_POS_block(MOUSE_Y_POS[8:5]),
        .editing(block_editing)
    );

    mouse_input mouse_input_inst(
        .clk(clk),
        .rst(rst_onepulse),
        .MOUSE_X_POS(MOUSE_X_POS),
        .MOUSE_Y_POS(MOUSE_Y_POS),
        .MOUSE_LEFT(MOUSE_LEFT & ~recognizer_pending),
        .MOUSE_MIDDLE(MOUSE_MIDDLE & ~recognizer_pending),
        .new_event(MOUSE_NEW_EVENT),
        .ready_to_clear_canvas(ready_to_clear_canvas),
        .write_addr(write_addr),
        .write_enable(mouse_write_enable),
        .write_data(mouse_input_data),
        .writing_block_pos(writing_block_pos),
        .editing(block_editing)
    );

    recognizer recognizer_inst(
        .clk(clk),
        .rst(rst_onepulse),
        .in_start(MOUSE_RIGHT_onepulse & block_editing),
        .read_data(recognizer_read_in_data),
        .read_addr(read_out_canvas_addr),
        .read_enable(canvas_read_enable),
        .result_valid(ready_to_clear_canvas),
        .result(doc_write_in_data),
        .pending(recognizer_pending)
    );

    text_editor text_editor_inst(
        .vga_block({v_cnt[8:5], h_cnt[9:5]}),
        .clk(clk),
        .rst(rst),
        .write_addr(writing_block_pos),
        .write_in_data(doc_write_in_data),
        .write_ready(ready_to_clear_canvas),
        .read_enable(UART_read_en),
        .read_out_addr(UART_read_addr),
        .clear_data(clear_data_onepulse || rst_onepulse),
        .enable_word_display(enable_word_display),
        .mouse_block_pos({MOUSE_Y_POS[8:5], MOUSE_X_POS[9:5]}),
        .a(doc_a),
        .MOUSE_MIDDLE(MOUSE_MIDDLE & ~recognizer_pending),
        .editing(block_editing),
        .text_write(text_write),
        .we(doc_we)
    );
    
    fonts fonts(
        .a({font_index, v_cnt[4:1]}),
        .spo(font_pixels)
    );

    document document(
        .a(doc_a),
        .d(text_write),
        .dpra({v_cnt[8:5], h_cnt[9:5]}),
        .we(doc_we),
        .spo(UART_read_data),
        .dpo(font_index),
        .clk(clk)
    );

    messenger messenger_inst(
        .clk(clk),
        .reset(rst_onepulse),
        .send(send_onepulse),
        .read_data(UART_read_data),
        .read_en(UART_read_en),
        .read_addr(UART_read_addr),
        .RsTx(RsTx)
    );

    small_canvas sc(
        .a(small_canvas_addr),
        .d(mouse_input_data),
        .dpra(pixel_addr),
        .clk(clk),
        .we(canvas_write_enable),
        .spo(recognizer_read_in_data),
        .dpo(canvas_vga_pixel)
    );
    
    vga_controller vga_inst(
      .pclk(clk_25MHz),
      .reset(rst_extended),
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
      
endmodule