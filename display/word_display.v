module word_display(
    input [9:0] h_cnt, v_cnt,
    input clk, rst,
    input [9:0] write_addr,
    input [7:0] write_in_data,
    input write_ready, read_enable,
    input [9:0] read_addr,
    input clear_data,
    output wire pixel_data,
    output wire enable_word_display,
    output wire [7:0] read_out_data
);

assign enable_word_display = written[v_cnt[9:5]][h_cnt[9:5]];
wire [6:0] data;
wire [0:15] pixels;
wire [8:0] doc_addr = {v_cnt[8:5], h_cnt[9:5]};
wire [7:0] d = counter ? 8'd0 : write_in_data;
reg [19:0] written [14:0];

reg [8:0] counter;

wire we = clear_data || rst || counter || write_ready;
wire [8:0] a = we ? (clear_data || rst) ? 9'd0 : counter ? counter : write_addr : doc_addr;


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
        written[0] <= 20'd0;
        written[1] <= 20'd0;
        written[2] <= 20'd0;
        written[3] <= 20'd0;
        written[4] <= 20'd0;
        written[5] <= 20'd0;
        written[6] <= 20'd0;
        written[7] <= 20'd0;
        written[8] <= 20'd0;
        written[9] <= 20'd0;
        written[10] <= 20'd0;
        written[11] <= 20'd0;
        written[12] <= 20'd0;
        written[13] <= 20'd0;
        written[14] <= 20'd0;
    end
    else if (write_ready) begin
        written[write_addr[9:5]][write_addr[4:0]] <= 1;
    end
end

fonts fonts(
    .addra({data, v_cnt[4:1]}),
    .douta(pixels),
    .clka(clk)
);

document document(
    .a(a),
    .d(d),
    .dpra(read_addr),
    .we(we),
    .spo(data),
    .dpo(read_out_data),
    .clk(clk)
);

assign pixel_data = pixels[h_cnt[4:1]];

endmodule