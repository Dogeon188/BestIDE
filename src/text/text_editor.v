module text_editor(
    input [8:0] vga_block,
    input clk, rst,
    input [8:0] write_addr,
    input [7:0] write_in_data,
    input write_ready, read_enable,
    input [8:0] read_out_addr,
    input clear_data,
    input clear_block,
    input editing,
    input [8:0] mouse_block_pos,
    output wire enable_word_display,
    output reg [8:0] a,
    output reg [7:0] text_write,
    output wire we
);

    reg [19:0] is_written [14:0];
    reg [8:0] counter;
    assign enable_word_display = is_written[vga_block[8:5]][vga_block[4:0]];
    assign we = !read_enable && (clear_block|| clear_data || rst || counter || write_ready);
    always @(*) begin
        if(we) begin
            if(clear_data || rst) begin
                a = 9'd0;
                text_write = 8'd0;
            end
            else if (counter) begin
                a = counter;
                text_write = 8'd0;
            end
            else if (write_ready) begin
                a = write_addr;
                text_write = write_in_data;
            end
            else if (!editing) begin
                a = mouse_block_pos;
                text_write = 8'd0;
            end
            else if(clear_block) begin
                a = write_addr;
                text_write = 8'd0;
            end
            else begin
                a = mouse_block_pos;
                text_write = write_in_data;
            end
        end
        else begin
            a = read_out_addr;
            text_write = 8'd0;
        end
    end

    always @(posedge clk) begin
        if(rst || clear_data) begin
            counter <= 9'd1;
        end
        else if (counter) begin
            counter <= counter + 1;
        end
        else begin
            counter <= 9'd0;
        end
    end

    always @(posedge clk) begin
        if(rst || clear_data) begin
            is_written[0] <= 20'd0;
            is_written[1] <= 20'd0;
            is_written[2] <= 20'd0;
            is_written[3] <= 20'd0;
            is_written[4] <= 20'd0;
            is_written[5] <= 20'd0;
            is_written[6] <= 20'd0;
            is_written[7] <= 20'd0;
            is_written[8] <= 20'd0;
            is_written[9] <= 20'd0;
            is_written[10] <= 20'd0;
            is_written[11] <= 20'd0;
            is_written[12] <= 20'd0;
            is_written[13] <= 20'd0;
            is_written[14] <= 20'd0;
        end
        else if (clear_block) begin
            if(editing) begin
                is_written[write_addr[8:5]][write_addr[4:0]] <= 0;
            end
            else begin
                is_written[mouse_block_pos[8:5]][mouse_block_pos[4:0]] <= 0;
            end
        end
        else if (write_ready) begin
            is_written[write_addr[8:5]][write_addr[4:0]] <= 1;
        end
    end

endmodule