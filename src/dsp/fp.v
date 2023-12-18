// fixed point format
//   8 bit fixed point format: SI.FFFFFF
//   1 sign bit, 1 integer bit, 6 fractional bits
//   range: -2(-128) to 1.984375(127)
//   conversion: fp = int(x * 64 + 0.5)

module Multiplier_Fixed8x8 (a, b, out);
    input signed [7:0] a;
    input signed [7:0] b;
    output signed [15:0] out;

    wire signed [15:0] temp;
    assign temp = a * b;
    assign out = temp >>> 6;
endmodule
