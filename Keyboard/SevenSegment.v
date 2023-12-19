module SevenSegment(
    output reg [6:0] display,
    output reg [3:0] AN,
    input [7:0] ascii1,
    input [7:0] ascii2,
    input wire rst,
    input wire clk
    );
    
    reg [17:0] clk_divider;


    always @ (posedge clk, posedge rst) begin
        if (rst) begin
            clk_divider <= 18'b0;
            AN <= 4'b1110;
        end 
        else begin
            if(clk_divider == ~18'b0) begin
                AN <= {AN[2:0], AN[3]};
            end
            else begin
                AN <= AN;
            end
            clk_divider <= clk_divider + 18'b1;
        end
    end
    
    wire [6:0] decode [3:0];

    seven_seg_decoder decoder1(
        .in(ascii1[3:0]),
        .out(decode[0])
    );

    seven_seg_decoder decoder2(
        .in(ascii1[7:4]),
        .out(decode[1])
    );

    seven_seg_decoder decoder3(
        .in(ascii2[3:0]),
        .out(decode[2])
    );

    seven_seg_decoder decoder4(
        .in(ascii2[7:4]),
        .out(decode[3])
    );


    always @(*) begin
        case(AN) 
            4'b1110: display <= decode[0];
            4'b1101: display <= decode[1];
            4'b1011: display <= decode[2];
            4'b0111: display <= decode[3];
            default: display <= 7'b1111111;
        endcase
    end
endmodule


module seven_seg_decoder(in, out);
    input [3:0] in;
    output reg [6:0] out;
    
    always @(*) begin
        case(in)
            4'b0000: out = 7'b1000000;
            4'b0001: out = 7'b1111001;
            4'b0010: out = 7'b0100100;
            4'b0011: out = 7'b0110000;
            4'b0100: out = 7'b0011001;
            4'b0101: out = 7'b0010010;
            4'b0110: out = 7'b0000010;
            4'b0111: out = 7'b1111000;
            4'b1000: out = 7'b0000000;
            4'b1001: out = 7'b0010000;
            4'b1010: out = 7'b0001000;
            4'b1011: out = 7'b0000011;
            4'b1100: out = 7'b1000110;
            4'b1101: out = 7'b0100001;
            4'b1110: out = 7'b0000110;
            4'b1111: out = 7'b0001110;
        endcase
    end
endmodule