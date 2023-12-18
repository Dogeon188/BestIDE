

// module Conv2D_top

module Conv2D_3x3_8bit (in, kernel, out);
    input [71:0] in;
    input [71:0] kernel;
    output signed [15:0] out;

    wire signed [7:0] in_array [8:0];
    wire signed [7:0] kernel_array [8:0];

    // Map the input and kernel to the arrays
    genvar i;
    generate
        for (i = 0; i < 9; i = i + 1) begin
            assign in_array[i] = in[(i+1)*8-1 -: 8];
            assign kernel_array[i] = kernel[(i+1)*8-1 -: 8];
        end
    endgenerate

    // Convolution
    wire signed [15:0] conv [8:0];
    genvar j;
    generate
        for (j = 0; j < 9; j = j + 1) begin
            Multiplier_Fixed8x8 mult (
                .a(in_array[j]),
                .b(kernel_array[j]),
                .out(conv[j])
            );
        end
    endgenerate

    // Summation
    assign out = conv[0] + conv[1] + conv[2] + conv[3] + conv[4] + conv[5] + conv[6] + conv[7] + conv[8];
endmodule

