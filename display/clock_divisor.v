module clock_divisor(clk17, clk1, clk);
input clk;
output clk1;
output clk17;

reg [17:0] num;
wire [17:0] next_num;

always @(posedge clk) begin
  num <= next_num;
end

assign next_num = num + 1'b1;
assign clk1 = num[1];
assign clk17 = num[17];

endmodule
