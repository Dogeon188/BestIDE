module UART_Top (
    input wire clk,
    input wire reset,
    input wire rx_in,
    output wire rx_data_valid,
    output wire [7:0] rx_data,
    input wire tx_data_valid,
    input wire [7:0] tx_data,
    output wire tx_out
);

    wire tx_baud_en, rx_baud_en;
    wire tx_baud, rx_baud;
    Baud_Gen bg (
        .clk(clk),
        .reset(reset),
        .tx_en(tx_baud_en),
        .rx_en(rx_baud_en),
        .tx_baud(tx_baud),
        .rx_baud(rx_baud)
    );

    UART_Rx rs_rx (
        .clk(clk),
        .reset(reset),
        .rx_in(rx_in),
        .baud_clk(rx_baud),
        .rx_data_valid(rx_data_valid),
        .rx_data(rx_data),
        .baud_en(rx_baud_en)
    );

    UART_Tx rs_tx (
        .clk(clk),
        .reset(reset),
        .tx_data_valid(tx_data_valid),
        .tx_data(tx_data),
        .baud_clk(tx_baud),
        .tx_out(tx_out),
        .baud_en(tx_baud_en)
    );
endmodule

module UART_Rx (
    input wire clk,
    input wire reset,
    input wire rx_in,
    input wire baud_clk,
    output wire rx_data_valid,
    output reg [7:0] rx_data,
    output reg baud_en
);
    // UART internal state
    reg [1:0] state;
    reg [8:0] rx_shift_reg;
    reg [3:0] rx_bit_cnt;

    parameter S_IDLE = 2'b00;
    parameter S_RECV = 2'b01;
    parameter S_SHOW = 2'b10;

    // Initialize internal state and registers
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= S_IDLE;
            rx_shift_reg <= 9'd0;
            rx_data <= 8'd0;
            rx_bit_cnt <= 4'b000;
            baud_en <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin  // Idle state
                    if (rx_in == 1'b0) begin  // Start receiving
                        state <= S_RECV;
                        rx_shift_reg <= 9'd0;
                        rx_data <= 8'd0;
                        rx_bit_cnt <= 4'd10; // 1 start bit + 8 data bits + 1 stop bit
                        baud_en <= 1'b1;
                    end
                end
                S_RECV: begin  // Receiving data
                    if (baud_clk) begin
                        rx_shift_reg <= {rx_in, rx_shift_reg[8:1]};  // Shift data bits
                        rx_bit_cnt <= rx_bit_cnt - 1'b1;
                    end

                    if (rx_bit_cnt == 4'd0) begin
                        state <= S_SHOW;
                        rx_data <= rx_shift_reg[7:0];  // Remove start and stop bits
                        baud_en <= 1'b0;
                    end else begin
                        state <= S_RECV;
                        baud_en <= 1'b1;
                    end
                end
                S_SHOW: begin  // Show received data
                    state <= S_IDLE;
                    baud_en <= 1'b0;
                end
            endcase
        end
    end

    assign rx_data_valid = (state == S_SHOW) ? 1'b1 : 1'b0;
endmodule

module UART_Tx (
    input wire clk,
    input wire reset,
    input wire tx_data_valid,
    input wire [7:0] tx_data,
    input wire baud_clk,
    output reg tx_out,
    output reg baud_en
);
    // UART internal state
    reg state;
    reg [9:0] tx_shift_reg;
    reg [3:0] tx_bit_cnt;
    reg tx_out_reg;

    parameter S_IDLE = 1'b0;
    parameter S_SEND = 1'b1;

    // Initialize internal state and registers
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= S_IDLE;
            tx_shift_reg <= 10'd0;
            tx_out <= 1'b1;
            tx_bit_cnt <= 4'b000;
            baud_en <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin  // Idle state
                    if (tx_data_valid) begin  // Start transmitting
                        state <= S_SEND;
                        tx_shift_reg <= {1'b1, tx_data, 1'b0};  // Add start and stop bits
                        tx_out <= 1'b1;
                        tx_bit_cnt <= 4'd10; // 1 start bit + 8 data bits + 1 stop bit
                        baud_en <= 1'b1;
                    end
                end
                S_SEND: begin  // Sending data
                    if (baud_clk) begin
                        tx_out <= tx_shift_reg[0];  // Output LSB
                        tx_shift_reg <= {1'b1, tx_shift_reg[9:1]};  // Shift data bits
                        tx_bit_cnt <= tx_bit_cnt - 1'b1;
                    end

                    if (tx_bit_cnt == 4'd0) begin
                        state <= S_IDLE;
                        baud_en <= 1'b0;
                    end else begin
                        state <= S_SEND;
                        baud_en <= 1'b1;
                    end
                end
            endcase
        end
    end
endmodule

module Baud_Gen (
    input wire clk, // 100 MHz
    input wire reset,
    input wire tx_en,
    input wire rx_en,
    output wire tx_baud,
    output wire rx_baud
);
    // Baud rate generator
    reg [8:0] tx_cnt, rx_cnt;

    // parameter BPS115200 = 10'd867;
    parameter BPS230400 = 9'd433;
    parameter BPS460800 = 9'd216;
    parameter BPStest   = 9'd4;
    
    parameter baud_rate = BPS230400;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            tx_cnt <= 9'd0;
            rx_cnt <= 9'd0;
        end else begin
            if (tx_en) begin
                if (tx_cnt == baud_rate) begin
                    tx_cnt <= 9'd0;
                end else begin
                    tx_cnt <= tx_cnt + 1'd1;
                end
            end else begin
                tx_cnt <= 9'd0;
            end

            if (rx_en) begin
                if (rx_cnt == baud_rate) begin
                    rx_cnt <= 9'd0;
                end else begin
                    rx_cnt <= rx_cnt + 1'd1;
                end
            end else begin
                rx_cnt <= 9'd0;
            end
        end
    end

    assign tx_baud = (tx_cnt == 1'd1) ? 1'b1 : 1'b0;
    assign rx_baud = (rx_cnt == 1'd1) ? 1'b1 : 1'b0;
endmodule