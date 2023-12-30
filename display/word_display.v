module word_display(
    input [9:0] h_cnt, v_cnt,
    output wire pixel_data,
    output wire enable_word_display
);

assign enable_word_display = ~h_cnt[9];

wire [15:0] pixels;

dist_mem_gen_0 dist_mem_gen_0_inst(
    .A({v_cnt[8:5],h_cnt[8:5],v_cnt[4:1]}),
    .SPO(pixels)
);



assign pixel_data = pixels[h_cnt[4:1]];

endmodule


