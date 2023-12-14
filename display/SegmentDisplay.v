module segment_display(
  input clk,
  input [9:0] MOUSE_X_POS,
  input [9:0] MOUSE_Y_POS,
  input isX,
  output reg [3:0] AN,
  output reg [6:0] SEG
);

reg [3:0] AN_next;
wire [9:0] display_value;
wire [3:0] DIGIT0, DIGIT1, DIGIT2;
wire [3:0] value;

assign display_value = (isX) ? MOUSE_X_POS: MOUSE_Y_POS;
assign DIGIT0 = display_value % 10;
assign DIGIT1 = ( display_value / 10 ) % 10;
assign DIGIT2 = ( display_value / 100 ) % 10;

always@(posedge clk)begin
  AN <= AN_next;
end

always@(*)begin
  AN_next = 4'b1110;
  if(AN==4'b1110) begin
    AN_next = 4'b1101;
  end else if(AN==4'b1101) begin
    AN_next = 4'b1011;
  end else if(AN==4'b1011) begin
    AN_next = 4'b1110;
  end
end

assign value = (AN==4'b1110) ? DIGIT0:
               (AN==4'b1101) ? DIGIT1:
               (AN==4'b1011) ? DIGIT2:
                              4'b1111;

always@(*)begin
  case(value)
    4'd0: SEG = 7'b0000001;
    4'd1: SEG = 7'b1001111;
    4'd2: SEG = 7'b0010010;
    4'd3: SEG = 7'b0000110;
    4'd4: SEG = 7'b1001100;
    4'd5: SEG = 7'b0100100;
    4'd6: SEG = 7'b0100000;
    4'd7: SEG = 7'b0001111;
    4'd8: SEG = 7'b0000000;
    4'd9: SEG = 7'b0000100;
    default: SEG = 7'b1111111;
  endcase
end


endmodule