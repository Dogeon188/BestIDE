module messenger (
    input wire clk,
    input wire reset,
    input wire send,
    input [7 : 0] read_data,
    output wire read_en,
    output wire [9 : 0] read_addr,
    output wire done,
    output wire RsTx
);
    parameter SIGACK = 8'hCC;
    parameter SIGEOF = 8'hDD;
    reg tx_data_valid;
    reg [7 : 0] tx_data;
    wire tx_ready;

    reg [3:0] read_y; // 0 ~ 14
    reg [4:0] read_x; // 0 ~ 19
    wire read_y_max = (read_y == 4'd14);
    wire read_x_max = (read_x == 5'd19);

    reg [3:0] state;
    parameter S_IDLE = 4'b0000;
    parameter S_ACK  = 4'b0001; // acknowledge aka starting byte
    parameter S_ACWT = 4'b0010; // sending acknowledge byte
    parameter S_READ = 4'b0011; // read data from document memory
    parameter S_SEND = 4'b0100; // sending document data
    parameter S_EOF  = 4'b0101; // EOF aka ending byte
    parameter S_EFWT = 4'b0110; // sending EOF byte
    parameter S_DONE = 4'b0111; // acknowledge done to top module

    always @(posedge clk) begin
        if (reset) begin
            state <= S_IDLE;
        end else begin
            case (state)
                S_IDLE: state <= (send) ? S_ACK : S_IDLE;
                S_ACK: state <= S_ACWT;
                S_ACWT: state <= (tx_ready) ? S_READ : S_ACWT;
                S_READ: state <= S_SEND;
                S_SEND: begin
                    if (tx_ready) begin
                        state <= (read_y_max && read_x_max) ? S_EOF : S_READ;
                    end else begin
                        state <= S_SEND;
                    end
                end
                S_EOF: state <= S_EFWT;
                S_EFWT: state <= (tx_ready) ? S_DONE : S_EFWT;
                S_DONE: state <= S_IDLE;
            endcase
        end
    end

    always @(*) begin
        case (state)
            S_ACK: begin
                tx_data_valid <= 1'b1;
                tx_data <= SIGACK;
            end
            S_READ: begin
                tx_data_valid <= 1'b1;
                tx_data <= read_data + 8'h20; // convert from internal (biased by 32) to ASCII
            end
            S_EOF: begin
                tx_data_valid <= 1'b1;
                tx_data <= SIGEOF;
            end
            default: begin
                tx_data_valid <= 1'b0;
                tx_data <= 8'd0;
            end
        endcase
    end

    always @(posedge clk) begin
        if (reset) begin
            read_y <= 4'd0;
            read_x <= 5'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    read_y <= 4'd0;
                    read_x <= 5'd0;
                end
                S_SEND: begin
                    if (tx_ready) begin
                        read_y <= (read_x_max) ? read_y + 1'b1 : read_y;
                        read_x <= (read_x_max) ? 5'd0          : read_x + 1'b1;
                    end else begin
                        read_y <= read_y;
                        read_x <= read_x;
                    end
                end
                default: begin
                    read_y <= read_y;
                    read_x <= read_x;
                end
            endcase
        end
    end

    assign done = state == S_DONE;
    assign read_en = state == S_READ;
    assign read_addr = {read_y, read_x};

    uart_top uart (
        .clk(clk),
        .reset(reset),
        // .rx_in(),
        // .rx_data_valid(),
        // .rx_data(),
        .tx_data_valid(tx_data_valid),
        .tx_data(tx_data),
        .tx_out(RsTx),
        .tx_ready(tx_ready)
    );
endmodule

module uart_top (
    input wire clk,
    input wire reset,
    // input wire rx_in,
    // output wire rx_data_valid,
    // output wire [7:0] rx_data,
    input wire tx_data_valid,
    input wire [7:0] tx_data,
    output wire tx_out,
    output wire tx_ready
);

    wire tx_baud_en, tx_baud;
    wire rx_baud_en, rx_baud;
    baud_gen bg (
        .clk(clk),
        .reset(reset),
        // .rx_en(rx_baud_en),
        // .rx_baud(rx_baud),
        .tx_en(tx_baud_en),
        .tx_baud(tx_baud)
    );

    // uart_rx rs_rx (
    //     .clk(clk),
    //     .reset(reset),
    //     .rx_in(rx_in),
    //     .baud_clk(rx_baud),
    //     .rx_data_valid(rx_data_valid),
    //     .rx_data(rx_data),
    //     .baud_en(rx_baud_en)
    // );

    uart_tx rs_tx (
        .clk(clk),
        .reset(reset),
        .tx_data_valid(tx_data_valid),
        .tx_data(tx_data),
        .baud_clk(tx_baud),
        .tx_out(tx_out),
        .baud_en(tx_baud_en),
        .tx_ready(tx_ready)
    );
endmodule

module uart_rx (
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

module uart_tx (
    input wire clk,
    input wire reset,
    input wire tx_data_valid,
    input wire [7:0] tx_data,
    input wire baud_clk,
    output reg tx_out,
    output reg baud_en,
    output wire tx_ready
);
    // UART internal state
    reg [1:0] state;
    reg [9:0] tx_shift_reg;
    reg [3:0] tx_bit_cnt;
    reg tx_out_reg;

    parameter S_IDLE = 2'b00;
    parameter S_SEND = 2'b01;
    // parameter S_REST = 2'b10;

    assign tx_ready = (state == S_IDLE);

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
                        baud_en <= 1'b1;
                        tx_out <= 1'b1;
                        tx_shift_reg <= {1'b1, tx_data, 1'b0};  // Add start and stop bits
                        tx_bit_cnt <= 4'd10; // 1 start bit + 8 data bits + 1 stop bit
                    end else begin
                        state <= S_IDLE;
                        baud_en <= 1'b0;
                        tx_out <= 1'b1;
                        tx_shift_reg <= 10'd0;
                        tx_bit_cnt <= 4'd0;
                    end
                end
                S_SEND: begin  // Sending data
                    if (baud_clk) begin
                        if (tx_bit_cnt == 4'd0) begin
                            state <= S_IDLE;
                            baud_en <= 1'b0;
                        end else begin
                            state <= S_SEND;
                            baud_en <= 1'b1;
                        end
                        tx_out <= tx_shift_reg[0];  // Output LSB
                        tx_shift_reg <= {1'b1, tx_shift_reg[9:1]};  // Shift data bits
                        tx_bit_cnt <= tx_bit_cnt - 1'b1;
                    end else begin
                        state <= S_SEND;
                        baud_en <= baud_en;
                        tx_out <= tx_out;
                        tx_shift_reg <= tx_shift_reg;
                        tx_bit_cnt <= tx_bit_cnt;
                    end

                end
            endcase
        end
    end
endmodule

// Baud rate generator
module baud_gen (
    input wire clk, // 100 MHz
    input wire reset,
    // input wire rx_en,
    // output wire rx_baud,
    input wire tx_en,
    output wire tx_baud
);
    // reg [8:0] rx_cnt;
    reg [8:0] tx_cnt;

    // parameter BPS115200 = 10'd867;
    parameter BPS230400 = 9'd433;
    parameter BPS460800 = 9'd216;
    
    parameter baud_rate = BPS230400;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            tx_cnt <= 9'd0;
            // rx_cnt <= 9'd0;
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

            // if (rx_en) begin
            //     if (rx_cnt == baud_rate) begin
            //         rx_cnt <= 9'd0;
            //     end else begin
            //         rx_cnt <= rx_cnt + 1'd1;
            //     end
            // end else begin
            //     rx_cnt <= 9'd0;
            // end
        end
    end

    assign tx_baud = (tx_cnt == 1'd1) ? 1'b1 : 1'b0;
    // assign rx_baud = (rx_cnt == 1'd1) ? 1'b1 : 1'b0;
endmodule