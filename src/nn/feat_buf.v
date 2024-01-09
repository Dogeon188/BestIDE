`define DATSIZE 22
`define PARSIZE 16
`define FPSHIFT 14

/*
    Wrapper for mem_feat_buf_conv
    Data width: 22 bits
    Capacity: 4096
    Read width: 1 x 22 bits
    Read latency: 1
*/
module feat_buf_conv (
    input wire clk,
    input wire [3 : 0] state,
    input wire write_en, // when state is READ(00), POOL1(01), POOL2(10)
    input wire [4 : 0] write_y,
    input wire [4 : 0] write_x,
    input wire [5 : 0] write_c,
    input wire [`DATSIZE - 1 : 0] write_data,
    input wire read_en, // when state is CONV1(01), CONV2(10), CONV3(11)
    input wire [5 : 0] read_y,
    input wire [5 : 0] read_x,
    input wire [7 : 0] read_c,
    input wire [3 : 0] read_s, // shift, [[0, 1, 2], [3, *4*, 5], [6, 7, 8]]
    output wire signed [`DATSIZE - 1 : 0] read_data
);
    // write address conversion
    reg [11 : 0] write_addr;
    reg _write_en;
    always @(*) begin
        if (!write_en) begin
            write_addr <= 12'b0;
            _write_en <= 1'b0;
        end else begin
            case (state)
                4'b0001: begin // READ,  (32, 32, 1)
                    write_addr <= {2'b0, write_y[4:0], write_x[4:0]};
                    _write_en <= 1'b1;
                end
                4'b0011: begin // POOL1, (16, 16, 16)
                    write_addr <= {write_c[3:0], write_y[3:0], write_x[3:0]};
                    _write_en <= 1'b1;
                end
                4'b0101: begin // POOL2, (8, 8, 32)
                    write_addr <= {1'b0, write_c[4:0], write_y[2:0], write_x[2:0]};
                    _write_en <= 1'b1;
                end
                4'b0111: begin // POOL3, (2, 2, 64)
                    write_addr <= {4'b0, write_y[0], write_x[0], write_c[5:0]};
                    _write_en <= 1'b1;
                end 
                default: begin
                    write_addr <= 12'b0;
                    _write_en <= 1'b0;
                end
            endcase
        end
    end

    // read shift conversion
    reg signed [5 : 0] read_s_y, read_s_x;
    always @(*) begin
        case (read_s)
            4'd0:    begin read_s_y <= -6'sd1; read_s_x <= -6'sd1; end
            4'd1:    begin read_s_y <= -6'sd1; read_s_x <=  6'sd0; end
            4'd2:    begin read_s_y <= -6'sd1; read_s_x <=  6'sd1; end
            4'd3:    begin read_s_y <=  6'sd0; read_s_x <= -6'sd1; end
            4'd4:    begin read_s_y <=  6'sd0; read_s_x <=  6'sd0; end
            4'd5:    begin read_s_y <=  6'sd0; read_s_x <=  6'sd1; end
            4'd6:    begin read_s_y <=  6'sd1; read_s_x <= -6'sd1; end
            4'd7:    begin read_s_y <=  6'sd1; read_s_x <=  6'sd0; end
            4'd8:    begin read_s_y <=  6'sd1; read_s_x <=  6'sd1; end
            default: begin read_s_y <=  6'sd0; read_s_x <=  6'sd0; end
        endcase
    end

    wire signed [5 : 0] _read_y, _read_x;
    assign _read_y = read_y + read_s_y;
    assign _read_x = read_x + read_s_x;

    // read address conversion
    reg [11 : 0] read_addr;
    reg _read_en;
    always @(*) begin
        if (!read_en) begin
            _read_en <= 1'b0;
            read_addr <= 12'b0;
        end else begin
            case (state)
                4'b0010: begin // CONV1, (32, 32, 1)
                    // 32 will overflow to -31
                    _read_en <= _read_y >= 6'sd0 && _read_x >= 6'sd0;
                    read_addr <= {2'b0, _read_y[4:0], _read_x[4:0]};
                end
                4'b0100: begin // CONV2, (16, 16, 16)
                    _read_en <= _read_y >= 6'sd0 && _read_y < 6'sd16 && _read_x >= 6'sd0 && _read_x < 6'sd16;
                    read_addr <= {read_c[3:0], _read_y[3:0], _read_x[3:0]};
                end
                4'b0110: begin // CONV3, (8, 8, 32)
                    _read_en <= _read_y >= 6'sd0 && _read_y < 6'sd8 && _read_x >= 6'sd0 && _read_x < 6'sd8;
                    read_addr <= {1'b0, read_c[4:0], _read_y[2:0], _read_x[2:0]};
                end
                4'b1000: begin // DENSE2, (256)
                    _read_en <= 1'b1;
                    read_addr <= {5'b0, read_c[7:0]};
                end
                default: begin
                    _read_en <= 1'b0;
                    read_addr <= 12'b0;
                end
            endcase
        end
    end

    reg read_valid;
    always @(posedge clk) begin
        read_valid <= _read_en;
    end
    wire signed [`DATSIZE - 1 : 0] _read_data;
    assign read_data = read_valid ? _read_data : 0;
    mem_feat_buf_conv mem (
        .clka(clk),
        .ena(_write_en),
        .wea(_write_en),
        .addra(write_addr),
        .dina(write_data),
        .clkb(clk),
        .enb(_read_en),
        .addrb(read_addr),
        .doutb(_read_data)
    );
endmodule

/*
    Wrapper for mem_feat_buf_pool
    Data width: 22 bits
    Capacity: 16384
    Read width: 2 x 22 bits
    Read latency: 1
*/
module feat_buf_pool (
    input wire clk,
    input wire [3 : 0] state,
    input wire write_en, // when state is CONV1(01), CONV2(10), CONV3(11)
    input wire [4 : 0] write_y,
    input wire [4 : 0] write_x,
    input wire [6 : 0] write_c,
    input wire [`DATSIZE - 1 : 0] write_data,
    input wire read_en, // when state is POOL1(01), POOL2(10), POOL3(00)
    input wire [5 : 0] read_y, read_x, // pooled x & y
    input wire [5 : 0] read_c,
    input wire read_updown, // 0: up, 1: down
    output wire signed [(2 * `DATSIZE) - 1 : 0] read_data
);
    // write address conversion
    reg [13 : 0] write_addr;
    reg _write_en;
    always @(*) begin
        if (!write_en) begin
            write_addr <= 12'b0;
            _write_en <= 1'b0;
        end else begin
            case (state)
                4'b0010: begin // CONV1, (32, 32, 16)
                    write_addr <= {write_c[3:0], write_y[4:0], write_x[4:0]};
                    _write_en <= 1'b1;
                end
                4'b0100: begin // CONV2, (16, 16, 32)
                    write_addr <= {1'b0, write_c[4:0], write_y[3:0], write_x[3:0]};
                    _write_en <= 1'b1;
                end
                4'b0110: begin // CONV3, (8, 8, 64)
                    write_addr <= {2'b0, write_c[5:0], write_y[2:0], write_x[2:0]};
                    _write_en <= 1'b1;
                end
                4'b1000: begin // DENSE2, (96)
                    write_addr <= {7'b0, write_c[6:0]};
                    _write_en <= 1'b1;
                end
                default: begin
                    write_addr <= 13'b0;
                    _write_en <= 1'b0;
                end
            endcase
        end
    end

    // read address conversion
    reg [12 : 0] read_addr;
    reg _read_en;
    always @(*) begin
        if (!read_en) begin
            _read_en <= 1'b0;
            read_addr <= 12'b0;
        end else begin
            case (state)
                4'b0011: begin // POOL1, (32, 32, 16)
                    _read_en <= 1'b1;
                    read_addr <= {read_c[3:0], read_y[3:0], read_updown, read_x[3:0]};
                end
                4'b0101: begin // POOL2, (16, 16, 32)
                    _read_en <= 1'b1;
                    read_addr <= {1'b0, read_c[4:0], read_y[2:0], read_updown, read_x[2:0]};
                end
                4'b0111: begin // POOL3, (8, 8, 64)
                    _read_en <= 1'b1;
                    read_addr <= {2'b0, read_c[5:0], read_y[1:0], read_updown, read_x[1:0]};
                end
                4'b1001: begin // DENSE1, (96)
                    _read_en <= 1'b1;
                    read_addr <= {6'b0, read_c[5:0]};
                end
                default: begin
                    _read_en <= 1'b0;
                    read_addr <= 12'b0;
                end
            endcase
        end
    end

    mem_feat_buf_pool mem (
        .clka(clk),
        .ena(_write_en),
        .wea(_write_en),
        .addra(write_addr),
        .dina(write_data),
        .clkb(clk),
        .enb(_read_en),
        .addrb(read_addr),
        .doutb(read_data)
    );
endmodule