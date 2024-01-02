module text_editor(
    input [9:0] h_cnt,
    input [8:0] v_cnt,
    input clk, rst,
    input [8:0] write_addr,
    input [7:0] write_in_data,
    input write_ready, read_enable,
    input clear_data,
    output wire enable_word_display,
    output wire [8:0] a,
    output wire [7:0] text_write,
    output wire we
);

    reg [19:0] is_written [14:0];
    reg [8:0] counter;
    assign enable_word_display = is_written[v_cnt[8:5]][h_cnt[9:5]];
    wire [6:0] data;
    wire [0:15] pixels;
    wire [8:0] doc_addr = {v_cnt[8:5], h_cnt[9:5]};
    assign text_write = counter ? 8'd0 : write_in_data;
    assign we = clear_data || rst || counter || write_ready;
    assign a = we ? (clear_data || rst) ? 9'd0 : counter ? counter : write_addr : doc_addr;


    always @(posedge clk) begin
        if(rst || clear_data) begin
            counter <= ~9'd0;
        end
        else if (counter) begin
            counter <= counter - 1;
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
        else if (write_ready) begin
            is_written[write_addr[8:5]][write_addr[4:0]] <= 1;
        end
    end

endmodule