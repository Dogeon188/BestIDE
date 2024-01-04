`define DATSIZE 22
`define PARSIZE 16
`define FPSHIFT 14

module recognizer (
    input wire clk,
    input wire rst,
    input wire in_start,
    input wire read_data,
    output [9:0] read_addr,
    output wire read_enable, // enable read from canvas
    output wire result_valid,
    output reg [7:0] result,
    output wire pending // assert when reading canvas & processing
);
    // core
    wire core_done;
    wire [7:0] core_result;
    recognizer_core core_inst (
        .clk(clk),
        .rst(rst),
        .read_start(in_start),
        .read_data(read_data),
        .read_addr(read_addr),
        .done(core_done),
        .result(core_result)
    );

    // FSM
    reg [3:0] state;
    parameter S_IDLE = 4'd0;
    parameter S_READ = 4'd1;
    parameter S_PROC = 4'd2;
    parameter S_DONE = 4'd3;

    reg [9:0] counter;

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            counter <= 10'd0;
            result <= 8'd0;
        end else begin
            case (state)
                S_IDLE: state <= in_start ? S_READ : S_IDLE;
                S_READ: state <= (counter == 10'd1023) ? S_PROC : S_READ;
                S_PROC: state <= (core_done) ? S_DONE : S_PROC;
                S_DONE: state <= S_IDLE;
            endcase

            counter <= (state == S_READ) ? counter + 10'd1 : 10'd0;
            if (state == S_DONE) result <= core_result;
        end
    end

    assign read_addr = counter;
    assign read_enable = (state == S_READ);
    assign result_valid = (state == S_DONE);
    assign pending = (state == S_READ) || (state == S_PROC);
endmodule

module recognizer_core (
    input wire clk,
    input wire rst,
    input wire read_start,
    input wire read_data,
    input wire [9:0] read_addr,
    output wire done,
    output reg [7:0] result
);
    // FSM
    reg [3:0] state, state_next;
    reg [3:0] subcounter;
    reg [17:0] counter;
    parameter S_IDLE   = 4'b0000;
    parameter S_READ   = 4'b0001; parameter T_READ   = 18'd1023;  // input: (32, 32, 1)
    parameter S_CONV1  = 4'b0010; parameter T_CONV1  = 18'd16383; // output: (32, 32, 16)
    parameter S_POOL1  = 4'b0011; parameter T_POOL1  = 18'd4095;  // output: (16, 16, 16)
    parameter S_CONV2  = 4'b0100; parameter T_CONV2  = 18'd131071;  // output: (16, 16, 32)
    parameter S_POOL2  = 4'b0101; parameter T_POOL2  = 18'd2047; // output: (8, 8, 32)
    parameter S_CONV3  = 4'b0110; parameter T_CONV3  = 18'd131071; // output: (8, 8, 64)
    parameter S_POOL3  = 4'b0111; parameter T_POOL3  = 18'd1023; // output: (256) <- maxpool(4,4) + flatten
    parameter S_DENSE2 = 4'b1000; parameter T_DENSE2 = 18'd0; // output: (96)
    parameter S_DENSE1 = 4'b1001; parameter T_DENSE1 = 18'd0; // output: (96)
    parameter S_DONE   = 4'b1111;

    // - next state
    always @(*) begin
        case (state)
            S_IDLE:   state_next <= read_start ? S_READ : S_IDLE;
            S_READ:   state_next <= (read_addr == 10'd1023) ? S_CONV1 : S_READ;
            S_CONV1:  state_next <= (counter == T_CONV1) ? S_DONE : S_CONV1;
            // TODO: finish FSM
            default:   state_next <= S_IDLE;
        endcase
    end

    reg [3:0] subcounter_max;
    always @(*) begin
        case (state)
            S_IDLE:   subcounter_max <= 4'd0;
            S_READ:   subcounter_max <= 4'd0;
            S_CONV1:  subcounter_max <= 4'd10;
            default:  subcounter_max <= 4'd0;
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            subcounter <= 4'd0;
            counter <= 18'd0;
        end else begin
            state <= state_next;

            if (state != state_next) begin
                subcounter <= 4'd0;
                counter <= 18'd0;
            end else begin
                subcounter <= (subcounter == subcounter_max) ? 4'd0 : subcounter + 4'd1;
                counter <= (subcounter == subcounter_max) ? counter + 18'd1 : counter;
            end

            if (state_next == S_DONE) begin
                // TODO: show actual result
                result <= 8'd33;
            end
        end
    end

    assign done = (state == S_DONE);

// dsp
    reg signed [`DATSIZE - 1 : 0] max_in0, max_in1, max_in2, max_in3;
    wire signed [`DATSIZE - 1 : 0] max_out;
    max_4 max_inst (
        .in0(max_in0),
        .in1(max_in1),
        .in2(max_in2),
        .in3(max_in3),
        .out(max_out)
    );

    reg signed [`DATSIZE - 1 : 0] mult_in [8:0];
    wire signed [(9 * `PARSIZE) - 1 : 0] mult_weight;
    wire signed [`DATSIZE - 1 : 0] mult_out;
    vec_mult_9 vec_inst (
        .in0(mult_in[0]),
        .in1(mult_in[1]),
        .in2(mult_in[2]),
        .in3(mult_in[3]),
        .in4(mult_in[4]),
        .in5(mult_in[5]),
        .in6(mult_in[6]),
        .in7(mult_in[7]),
        .in8(mult_in[8]),
        .weight0(mult_weight[(1 * `PARSIZE) - 1 -: `PARSIZE]),
        .weight1(mult_weight[(2 * `PARSIZE) - 1 -: `PARSIZE]),
        .weight2(mult_weight[(3 * `PARSIZE) - 1 -: `PARSIZE]),
        .weight3(mult_weight[(4 * `PARSIZE) - 1 -: `PARSIZE]),
        .weight4(mult_weight[(5 * `PARSIZE) - 1 -: `PARSIZE]),
        .weight5(mult_weight[(6 * `PARSIZE) - 1 -: `PARSIZE]),
        .weight6(mult_weight[(7 * `PARSIZE) - 1 -: `PARSIZE]),
        .weight7(mult_weight[(8 * `PARSIZE) - 1 -: `PARSIZE]),
        .weight8(mult_weight[(9 * `PARSIZE) - 1 -: `PARSIZE]),
        .out(mult_out)
    );

// parameter memory
    reg pm_conv_weight_en;
    reg [5 : 0] pm_conv_weight_o, pm_conv_weight_c;
    always @(*) begin
        case (state)
            S_CONV1: begin // output (32, 32, 16)
                pm_conv_weight_en <= 1'b1;
                pm_conv_weight_o <= {2'b0, counter[13:10]};
                pm_conv_weight_c <= 6'b0;
            end
            S_CONV2: begin // output (16, 16, 32)
                pm_conv_weight_en <= 1'b1;
                // TODO
            end
            S_CONV3: begin // output (8, 8, 64)
                pm_conv_weight_en <= 1'b1;
                // TODO
            end
            default: begin
                pm_conv_weight_en <= 1'b0;
                pm_conv_weight_o <= 6'd0;
                pm_conv_weight_c <= 6'd0;
            end
        endcase
    end
    conv_weights conv_weights_inst (
        .clk(clk),
        .en(pm_conv_weight_en),
        .state(state),
        .read_o(pm_conv_weight_o),
        .read_c(pm_conv_weight_c),
        .data(mult_weight)
    );

    reg [5 : 0] pm_conv_bias_o;
    wire signed [`PARSIZE - 1 : 0] pm_conv_bias;
    always @(*) begin
        case (state)
            S_CONV1: begin // output (32, 32, 16)
                pm_conv_bias_o <= counter[13:10];
            end
            S_CONV2: begin // output (16, 16, 32)
                // TODO
            end
            S_CONV3: begin // output (8, 8, 64)
                // TODO
            end
            default: pm_conv_bias_o <= 6'd0;
        endcase
    end
    conv_biases conv_biases_inst (
        .state(state),
        .read_o(pm_conv_bias_o),
        .data(pm_conv_bias)
    );

// feature map buffers
    reg fb_conv_write_en, fb_conv_read_en;
    reg [4 : 0] fb_conv_write_y, fb_conv_write_x, fb_conv_write_c;
    reg signed [`DATSIZE - 1 : 0] fb_conv_write_data;
    reg [5 : 0] fb_conv_read_y, fb_conv_read_x, fb_conv_read_c;
    reg [3 : 0] fb_conv_read_s;
    wire signed [`DATSIZE - 1 : 0] fb_conv_read_data;

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 9; i = i + 1) begin
                mult_in[i] <= 22'd0;
            end
        end else begin
            if (fb_conv_read_en && (subcounter < 4'd10 && subcounter != 4'd0)) begin
                mult_in[subcounter - 4'd1] <= fb_conv_read_data;
            end
        end
    end

    feat_buf_conv feat_buf_conv_inst (
        .clk(clk),
        .state(state),
        .write_en(fb_conv_write_en),
        .write_y(fb_conv_write_y),
        .write_x(fb_conv_write_x),
        .write_c(fb_conv_write_c),
        .write_data(fb_conv_write_data),
        .read_en(fb_conv_read_en),
        .read_y(fb_conv_read_y),
        .read_x(fb_conv_read_x),
        .read_c(fb_conv_read_c),
        .read_s(fb_conv_read_s),
        .read_data(fb_conv_read_data)
    );

    always @(*) begin
        if (rst) begin
            fb_conv_write_en <= 1'b0;
            fb_conv_write_y <= 6'd0;
            fb_conv_write_x <= 6'd0;
            fb_conv_write_c <= 6'd0;
            fb_conv_write_data <= 22'd0;

            fb_conv_read_en <= 1'b0;
            fb_conv_read_y <= 6'd0;
            fb_conv_read_x <= 6'd0;
            fb_conv_read_c <= 6'd0;
            fb_conv_read_s <= 4'd0;
        end else begin
            case (state)
                S_READ: begin // input (32, 32, 1)
                    fb_conv_write_en <= 1'b1;
                    fb_conv_write_y <= read_addr[9:5];
                    fb_conv_write_x <= read_addr[4:0];
                    fb_conv_write_c <= 6'd0;
                    fb_conv_write_data <= read_data ? 22'd16384 : 22'd0; // 16384 = 2^14 -> 1

                    fb_conv_read_en <= 1'b0;
                    fb_conv_read_y <= 6'd0;
                    fb_conv_read_x <= 6'd0;
                    fb_conv_read_c <= 6'd0;
                    fb_conv_read_s <= 4'd0;
                end
                S_CONV1: begin // output (32, 32, 1)
                    fb_conv_write_en <= 1'b0;
                    fb_conv_write_y <= 6'd0;
                    fb_conv_write_x <= 6'd0;
                    fb_conv_write_c <= 6'd0;
                    fb_conv_write_data <= 22'd0;

                    fb_conv_read_en <= (subcounter <= 4'd9);
                    fb_conv_read_y <= {1'b0, counter[9:5]};
                    fb_conv_read_x <= {1'b0, counter[4:0]};
                    fb_conv_read_c <= 6'd0;
                    fb_conv_read_s <= subcounter[3:0];
                end
                // TODO: implement address calculation
                S_POOL1: begin // input (16, 16, 16)
                end
                S_CONV2: begin // output (16, 16, 16)
                end
                S_POOL2: begin // input (8, 8, 32)
                end
                S_CONV3: begin // output (8, 8, 32)
                end
                default: begin
                    fb_conv_write_en <= 1'b0;
                    fb_conv_write_y <= 6'd0;
                    fb_conv_write_x <= 6'd0;
                    fb_conv_write_c <= 6'd0;
                    fb_conv_write_data <= 22'd0;

                    fb_conv_read_en <= 1'b0;
                    fb_conv_read_y <= 6'd0;
                    fb_conv_read_x <= 6'd0;
                    fb_conv_read_c <= 6'd0;
                    fb_conv_read_s <= 4'd0;
                end
            endcase
        end
    end

    reg fb_pool_write_en, fb_pool_read_en;
    reg [5 : 0] fb_pool_write_y, fb_pool_write_x, fb_pool_write_c;
    reg signed [`DATSIZE - 1 : 0] fb_pool_write_data;
    reg [5 : 0] fb_pool_read_y, fb_pool_read_x, fb_pool_read_c;
    reg fb_pool_read_updown;
    wire signed [(2 * `DATSIZE) - 1 : 0] fb_pool_read_data;
    feat_buf_pool feat_buf_pool_inst (
        .clk(clk),
        .state(state),
        .write_en(fb_pool_write_en),
        .write_y(fb_pool_write_y),
        .write_x(fb_pool_write_x),
        .write_c(fb_pool_write_c),
        .write_data(fb_pool_write_data),
        .read_en(fb_pool_read_en),
        .read_y(fb_pool_read_y),
        .read_x(fb_pool_read_x),
        .read_c(fb_pool_read_c),
        .read_updown(fb_pool_read_updown),
        .read_data(fb_pool_read_data)
    );

    always @(*) begin
        if (rst) begin
            fb_pool_write_en <= 1'b0;
            fb_pool_write_y <= 6'd0;
            fb_pool_write_x <= 6'd0;
            fb_pool_write_c <= 6'd0;
            fb_pool_write_data <= 22'd0;

            fb_pool_read_en <= 1'b0;
            fb_pool_read_y <= 6'd0;
            fb_pool_read_x <= 6'd0;
            fb_pool_read_c <= 6'd0;
            fb_pool_read_updown <= 1'd0;
        end else begin
            case (state)
                S_CONV1: begin // input (32, 32, 16)
                    fb_pool_write_en <= (subcounter == 4'd10);
                    fb_pool_write_y <= {1'b0, counter[9:5]};
                    fb_pool_write_x <= {1'b0, counter[4:0]};
                    fb_pool_write_c <= {2'b0, counter[13:10]};
                    fb_pool_write_data <= mult_out + pm_conv_bias;

                    fb_pool_read_en <= 1'b0;
                    fb_pool_read_y <= 6'd0;
                    fb_pool_read_x <= 6'd0;
                    fb_pool_read_c <= 6'd0;
                    fb_pool_read_updown <= 1'd0;
                end
                // TODO: implement address calculation
                S_POOL1: begin // output (32, 32, 16)
                end
                S_CONV2: begin // input (16, 16, 32)
                end
                S_POOL2: begin // output (16, 16, 32)
                end
                S_CONV3: begin // input (8, 8, 64)
                end
                S_POOL3: begin // output (8, 8, 64)
                end
                default: begin
                    fb_pool_write_en <= 1'b0;
                    fb_pool_write_y <= 6'd0;
                    fb_pool_write_x <= 6'd0;
                    fb_pool_write_c <= 6'd0;
                    fb_pool_write_data <= 22'd0;

                    fb_pool_read_en <= 1'b0;
                    fb_pool_read_y <= 6'd0;
                    fb_pool_read_x <= 6'd0;
                    fb_pool_read_c <= 6'd0;
                    fb_pool_read_updown <= 1'd0;
                end
            endcase
        end
    end
endmodule
