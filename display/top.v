module top(
    input clk,
    input rst,
    input send_data,
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
    wire [8:0] v_cnt;  //480
    wire [9:0] pixel_addr = {v_cnt[4:0], h_cnt[4:0]};
    wire [9:0] write_addr;
    wire enable_mouse_display, enable_word_display;
    wire mouse_input_data;
    wire [9:0] MOUSE_X_POS , MOUSE_Y_POS;
    wire MOUSE_LEFT , MOUSE_MIDDLE , MOUSE_RIGHT , MOUSE_NEW_EVENT, extended_MOUSE_NEW_EVENT;
    wire [3:0] mouse_cursor_red , mouse_cursor_green , mouse_cursor_blue;
    wire canvas_vga_pixel;
    wire [11:0] pixel_color;
    wire [0:15] font_pixels;
    wire [11:0] mouse_pixel = {mouse_cursor_red, mouse_cursor_green, mouse_cursor_blue};
    assign {vgaRed, vgaGreen, vgaBlue} = (valid==1'b1) ? pixel_color:12'h0;
    wire [4:0] writing_block_x_pos;
    wire [3:0] writing_block_y_pos;
    wire [7:0] UART_out_data;
    wire block_editing;
    wire [9:0] UART_out_addr = 0; 
    wire UART_enable_read = 0;
    wire UART_done = 0;
    wire ready_to_clear_canvas;
    wire [9:0] small_canvas_addr;
    wire [6:0] font_index;
    wire [9:0] read_out_canvas_addr;
    wire recognizer_read_in_data;
    wire mouse_write_enable;
    wire rst_debounced, rst_onepulse, rst_extending_signal;
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
        .canvas_vga_pixel(canvas_vga_pixel),
        .pixel_color(pixel_color),
        .writing_block_x_pos(writing_block_x_pos),
        .writing_block_y_pos(writing_block_y_pos),
        .MOUSE_X_POS(MOUSE_X_POS),
        .MOUSE_Y_POS(MOUSE_Y_POS),
        .editing(block_editing)
    );

    mouse_input mouse_input_inst(
        .clk(clk_25MHz),
        .rst(rst_extending_signal),
        .MOUSE_X_POS(MOUSE_X_POS),
        .MOUSE_Y_POS(MOUSE_Y_POS),
        .MOUSE_LEFT(MOUSE_LEFT & recognizer_pending),
        .MOUSE_RIGHT(MOUSE_RIGHT & recognizer_pending),
        .new_event(extended_MOUSE_NEW_EVENT),
        .ready_to_clear_canvas(ready_to_clear_canvas),
        .write_addr(write_addr),
        .write_enable(mouse_write_enable),
        .write_data(mouse_input_data),
        .writing_block_x_pos(writing_block_x_pos),
        .writing_block_y_pos(writing_block_y_pos),
        .editing(block_editing)
    );

    recognizer recognizer_inst(
        .clk(clk_25MHz),
        .rst(rst_extending_signal),
        .end_write(MOUSE_MIDDLE & block_editing),
        .read_in_data(recognizer_read_in_data),
        .read_addr(read_out_canvas_addr),
        .read_enable(canvas_read_enable),
        .ready_to_write(ready_to_clear_canvas),
        .write_data(doc_write_in_data),
        .recognizer_pending(recognizer_pending)
    );

    text_editor text_editor_inst(
        .vga_block({v_cnt[8:5], h_cnt[9:5]}),
        .clk(clk_25MHz),
        .rst(rst),
        .write_addr({writing_block_y_pos, writing_block_x_pos}),
        .write_in_data(doc_write_in_data),
        .write_ready(ready_to_clear_canvas),
        .read_enable(UART_enable_read),
        .read_out_addr(UART_out_addr),
        .clear_data(UART_done),
        .enable_word_display(enable_word_display),
        .mouse_block_pos({MOUSE_Y_POS[8:5], MOUSE_X_POS[9:5]}),
        .a(doc_a),
        .MOUSE_RIGHT(MOUSE_RIGHT & recognizer_pending),
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
        .spo(UART_out_data),
        .dpo(font_index),
        .clk(clk_25MHz)
    );

    small_canvas sc(
        .a(small_canvas_addr),
        .d(mouse_input_data),
        .dpra(pixel_addr),
        .clk(clk_25MHz),
        .we(canvas_write_enable),
        .spo(recognizer_read_in_data),
        .dpo(canvas_vga_pixel)
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