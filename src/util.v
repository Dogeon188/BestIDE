module debounce(clk, in, out);
    input clk, in;
    output out;

    reg [3:0] DFF;

    always @(posedge clk) begin
        DFF <= {DFF[2:0], in};
    end

    assign out = DFF[3] & DFF[2] & DFF[1] & DFF[0];
endmodule

module onepulse(clk, in, out);
    input clk, in;
    output out;

    reg A;

    always @(posedge clk) begin
        A <= in;
    end

    assign out = ~A & in;

endmodule

module clock_divisor(
    input wire clk,
    output wire clk_25MHz, // 2^-2
    output wire clk_2KHz   // 2^-16
);
    reg [15:0] num;

    always @(posedge clk) begin
        num <= num + 16'b1;
    end

    assign clk_25MHz = num[1];
    assign clk_2KHz = num[15];
endmodule

module extending_signal(clk, in, out);
    input clk;
    input in;
    output out;

    reg [2:0] counter;

    always @(posedge clk) begin
        if(in) begin
            counter <= 3'b111;
        end 
        else begin
            counter <= counter[2] ? counter - 1 : counter;
        end
    end
    assign out = counter[2];
endmodule