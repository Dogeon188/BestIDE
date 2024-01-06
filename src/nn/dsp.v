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

module relu (
    input wire signed [`DATSIZE - 1 : 0] in,
    output wire signed [`DATSIZE - 1 : 0] out
);
    assign out = (in[`DATSIZE - 1]) ? 0 : in;
endmodule
