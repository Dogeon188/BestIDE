`define DATSIZE 22
`define PARSIZE 16
`define FPSHIFT 14

module max_4 (
    input wire signed [`DATSIZE - 1 : 0] in0, in1, in2, in3,
    output wire signed [`DATSIZE - 1 : 0] out
);
    wire signed [`DATSIZE - 1 : 0] max01, max23;
    assign max01 = (in0 > in1) ? in0 : in1;
    assign max23 = (in2 > in3) ? in2 : in3;
    assign out = (max01 > max23) ? max01 : max23;
endmodule

module vec_mult_9 (
    input wire signed [`DATSIZE - 1 : 0] in0,
    input wire signed [`DATSIZE - 1 : 0] in1,
    input wire signed [`DATSIZE - 1 : 0] in2,
    input wire signed [`DATSIZE - 1 : 0] in3,
    input wire signed [`DATSIZE - 1 : 0] in4,
    input wire signed [`DATSIZE - 1 : 0] in5,
    input wire signed [`DATSIZE - 1 : 0] in6,
    input wire signed [`DATSIZE - 1 : 0] in7,
    input wire signed [`DATSIZE - 1 : 0] in8,
    input wire signed [`PARSIZE - 1 : 0] weight0,
    input wire signed [`PARSIZE - 1 : 0] weight1,
    input wire signed [`PARSIZE - 1 : 0] weight2,
    input wire signed [`PARSIZE - 1 : 0] weight3,
    input wire signed [`PARSIZE - 1 : 0] weight4,
    input wire signed [`PARSIZE - 1 : 0] weight5,
    input wire signed [`PARSIZE - 1 : 0] weight6,
    input wire signed [`PARSIZE - 1 : 0] weight7,
    input wire signed [`PARSIZE - 1 : 0] weight8,
    output wire signed [`DATSIZE - 1 : 0] out
);
    // add 4 bits to prevent overflow
    wire signed [`DATSIZE + `PARSIZE - 1 + 4 : 0] p0, p1, p2, p3, p4, p5, p6, p7, p8;
    assign p0 = in0 * weight0;
    assign p1 = in1 * weight1;
    assign p2 = in2 * weight2;
    assign p3 = in3 * weight3;
    assign p4 = in4 * weight4;
    assign p5 = in5 * weight5;
    assign p6 = in6 * weight6;
    assign p7 = in7 * weight7;
    assign p8 = in8 * weight8;

    wire signed [`DATSIZE + `PARSIZE - 1 + 4 : 0] sum, sum_shift;
    assign sum = p0 + p1 + p2 + p3 + p4 + p5 + p6 + p7 + p8;
    assign sum_shift = sum >>> `FPSHIFT;
    assign out = sum_shift[`DATSIZE - 1 : 0];
endmodule