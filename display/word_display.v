module word_display(
    input [9:0] h_cnt, v_cnt,
    input clk, rst,
    output wire pixel_data,
    output wire enable_word_display
);

assign enable_word_display = 1;
wire [7:0] data;
wire [0:15] pixels;
wire [8:0] doc_addr = h_cnt[9:5] + v_cnt[9:5] * 9'd20;

fonts fonts(
    .a({data, v_cnt[4:1]}),
    .spo(pixels)
);

document document(
    .a(0),
    .d(0),
    .dpra(doc_addr),
    .we(0),
    .dpo(data),
    .clk(clk)
);


assign pixel_data = pixels[h_cnt[4:1]];

endmodule


