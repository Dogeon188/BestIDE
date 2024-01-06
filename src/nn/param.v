`define DATSIZE 22
`define PARSIZE 16
`define FPSHIFT 14

module conv_weights (
    input wire clk,
    input wire en,
    input wire [3 : 0] state,
    input wire [5 : 0] read_c, read_o,
    output wire signed [9 * `PARSIZE - 1 : 0] data
);
    // write address conversion
    parameter SHIFT_CONV1 = 12'd0;
    parameter SHIFT_CONV2 = 12'd16;
    parameter SHIFT_CONV3 = 12'd16 + 12'd512;

    reg _en;
    reg [11 : 0] addr;
    always @(*) begin
        if (!en) begin
            _en <= 1'b0;
            addr <= 12'b0;
        end else begin
            case (state)
                4'b0010: begin // CONV1, (32, 32) 1 -> 16
                    _en <= 1'b1;
                    addr <= SHIFT_CONV1 + {read_o[3 : 0]/*, 0'b0*/};
                end
                4'b0100: begin // CONV2, (16, 16) 16 -> 32
                    _en <= 1'b1;
                    addr <= SHIFT_CONV2 + {read_o[4 : 0], read_c[3 : 0]};
                end
                4'b0110: begin // CONV3, (8, 8) 32 -> 64
                    _en <= 1'b1;
                    addr <= SHIFT_CONV3 + {read_o[5 : 0], read_c[4 : 0]};
                end
                default: begin
                    _en <= 1'b0;
                    addr <= 12'b0;
                end
            endcase
        end
    end

    wire [9 * `PARSIZE - 1 : 0] doutb; // not used
    mem_conv_w mem (
        .clka(clk),
        .ena(_en),
        .addra(addr),
        .douta(data),
        .clkb(clk),
        .enb(1'b0),
        .addrb(12'b0),
        .doutb(doutb)
    );
endmodule

module conv_biases (
    input wire [3 : 0] state,
    input wire [5 : 0] read_o,
    output wire signed [`PARSIZE - 1 : 0] data
);
    // write address conversion
    parameter SHIFT_CONV1 = 7'd0;
    parameter SHIFT_CONV2 = 7'd16;
    parameter SHIFT_CONV3 = 7'd16 + 7'd32;
    reg [6 : 0] addr;

    always @(*) begin
        case (state)
            4'b0010: begin // CONV1, (32, 32) 1 -> 16
                addr <= SHIFT_CONV1 + read_o[3 : 0];
            end
            4'b0100: begin // CONV2, (16, 16) 16 -> 32
                addr <= SHIFT_CONV2 + read_o[4 : 0];
            end
            4'b0110: begin // CONV3, (8, 8) 32 -> 64
                addr <= SHIFT_CONV3 + read_o[5 : 0];
            end
            default: begin
                addr <= 7'b0;
            end
        endcase
    end

    mem_conv_b mem (
        .a(addr),
        .spo(data)
    );
endmodule

module dense_weights (
    input wire clk,
    input wire en,
    input wire [3 : 0] state,
    input wire [6 : 0] read_o,
    input wire [7 : 0] read_i,
    output wire signed [`PARSIZE - 1 : 0] data
);
    // write address conversion
    parameter SHIFT_DENSE2 = 16'd0;
    parameter SHIFT_DENSE1 = 16'd24576;

    reg _en;
    reg [15 : 0] addr;
    always @(*) begin
        if (!en) begin
            _en <= 1'b0;
            addr <= 16'b0;
        end else begin
            case (state)
                // TODO: check if this is correct
                4'b1000: begin // DENSE2, 256 -> 96
                    _en <= 1'b1;
                    addr <= SHIFT_DENSE2 + {1'b0, read_o[6 : 0], read_i[7 : 0]};
                end
                4'b1001: begin // DENSE1, 96 -> 96
                    _en <= 1'b1;
                    addr <= SHIFT_DENSE1 + read_o[6 : 0] * 16'd96 + read_i[6 : 0];
                end
                default: begin
                    _en <= 1'b0;
                    addr <= 16'b0;
                end
            endcase
        end
    end

    wire [`PARSIZE - 1 : 0] doutb; // not used
    mem_dense_w mem (
        .clka(clk),
        .ena(_en),
        .addra(addr),
        .douta(data),
        .clkb(clk),
        .enb(1'b0),
        .addrb(16'b0),
        .doutb(doutb)
    );
endmodule

module dense_biases (
    input wire [3 : 0] state,
    input wire [6 : 0] read_o,
    output wire signed [`PARSIZE - 1 : 0] data
);
    // write address conversion
    parameter SHIFT_DENSE2 = 8'd0;
    parameter SHIFT_DENSE1 = 8'd96;
    reg [7 : 0] addr;

    always @(*) begin
        case (state)
            4'b1000: begin // DENSE2, 256 -> 96
                addr <= SHIFT_DENSE2 + read_o[6 : 0];
            end
            4'b1001: begin // DENSE1, 96 -> 96
                addr <= SHIFT_DENSE1 + read_o[6 : 0];
            end
            default: begin
                addr <= 8'b0;
            end
        endcase
    end

    mem_dense_b mem (
        .a(addr),
        .spo(data)
    );
endmodule
