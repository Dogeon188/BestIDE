module UART_tx (
    input wire clk,
    input wire reset,
    input wire tx_data_valid,
    input wire [7:0] tx_data,
    output wire tx_out
);
    // UART internal state
    reg [2:0] state;
    reg [9:0] tx_shift_reg;
    reg [3:0] tx_bit_cnt;
    reg tx_start;
    reg tx_out_reg;

    parameter S_IDLE = 3'b000;
    parameter S_SEND = 3'b001;

    // Baud rate generator
    wire baud_clk;
    reg baud_en;  // Enable baud rate generator
    Baud_Gen bg (clk, reset, baud_en, baud_clk);

    // Initialize internal state and registers
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= 3'b000;
            tx_shift_reg <= 4'b0000;
            tx_start <= 1'b0;
            tx_out_reg <= 1'b1;
            tx_bit_cnt <= 4'b000;
            baud_en <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin  // Idle state
                    if (tx_data_valid) begin
                        state <= S_SEND;  // Start bit
                        tx_shift_reg <= {1'b1, tx_data, 1'b0};  // Add start and stop bits
                        tx_start <= 1'b1;
                        tx_out_reg <= 1'b1;
                        tx_bit_cnt <= 4'd10; // 1 start bit + 8 data bits + 1 stop bit
                        baud_en <= 1'b1;
                    end
                end
                S_SEND: begin  // Data bits
                    if (baud_clk) begin
                        tx_out_reg <= tx_shift_reg[0];  // Output LSB
                        tx_shift_reg <= {1'b0, tx_shift_reg[9:1]};  // Shift data bits
                        tx_bit_cnt <= tx_bit_cnt - 1'b1;
                    end

                    if (tx_bit_cnt == 3'b000) begin
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

    // Output the UART TX signal
    assign tx_out = tx_out_reg;
endmodule

module Baud_Gen (
    input wire clk, // 100 MHz
    input wire reset,
    input wire en,
    output wire baud
);
    // Baud rate generator
    reg [15:0] cnt;

    // wire [15:0] baud_rate = 16'd867;  // 115200 baud
    wire [15:0] baud_rate = 16'd433;  // 230400 baud

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            cnt <= 16'd0;
        end
        else if (en) begin
            if (cnt == baud_rate) begin
                cnt <= 16'd0;
            end else begin
                cnt <= cnt + 1'b1;
            end
        end
    end

    assign baud = (cnt == 1'b1) ? 1'b1 : 1'b0;
endmodule