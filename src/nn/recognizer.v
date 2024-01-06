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
    reg [4:0] subcounter;
    reg [17:0] counter;
    parameter S_IDLE   = 4'b0000;
    parameter S_READ   = 4'b0001; parameter T_READ   = 18'd1023;  // input: (32, 32, 1)
    parameter S_CONV1  = 4'b0010; parameter T_CONV1  = 18'd16383; // output: (32, 32, 16)
    parameter S_POOL1  = 4'b0011; parameter T_POOL1  = 18'd4095;  // output: (16, 16, 16)
    parameter S_CONV2  = 4'b0100; parameter T_CONV2  = 18'd131071;  // output: (16, 16, 32)
    parameter S_POOL2  = 4'b0101; parameter T_POOL2  = 18'd2047; // output: (8, 8, 32)
    parameter S_CONV3  = 4'b0110; parameter T_CONV3  = 18'd131071; // output: (8, 8, 64)
    parameter S_POOL3  = 4'b0111; parameter T_POOL3  = 18'd255; // output: (256) <- maxpool(4,4) + flatten
    parameter S_DENSE2 = 4'b1000; parameter T_DENSE2 = 18'd0; // output: (96)
    parameter S_DENSE1 = 4'b1001; parameter T_DENSE1 = 18'd0; // output: (96)
    parameter S_DONE   = 4'b1111;

    // next state
    always @(*) begin
        case (state)
            S_IDLE:   state_next <= read_start ? S_READ : S_IDLE;
            S_READ:   state_next <= (read_addr == 10'd1023) ? S_CONV1 : S_READ;
            S_CONV1:  state_next <= ((counter == T_CONV1)  && (subcounter == subcounter_max)) ? S_POOL1  : S_CONV1;
            S_POOL1:  state_next <= ((counter == T_POOL1)  && (subcounter == subcounter_max)) ? S_CONV2  : S_POOL1;
            S_CONV2:  state_next <= ((counter == T_CONV2)  && (subcounter == subcounter_max)) ? S_POOL2  : S_CONV2;
            S_POOL2:  state_next <= ((counter == T_POOL2)  && (subcounter == subcounter_max)) ? S_CONV3  : S_POOL2;
            S_CONV3:  state_next <= ((counter == T_CONV3)  && (subcounter == subcounter_max)) ? S_POOL3  : S_CONV3;
            S_POOL3:  state_next <= ((counter == T_POOL3)  && (subcounter == subcounter_max)) ? S_DONE : S_POOL3;
            S_DENSE2: state_next <= ((counter == T_DENSE2) && (subcounter == subcounter_max)) ? S_DONE : S_DENSE2;
            // TODO: finish FSM
            default:   state_next <= S_IDLE;
        endcase
    end

    reg [4:0] subcounter_max;
    always @(*) begin
        case (state)
            S_IDLE:   subcounter_max <= 5'd0;
            S_READ:   subcounter_max <= 5'd0;
            S_CONV1:  subcounter_max <= 5'd11; // 2 read delay + 9 read & mult + 1 write delay
            S_POOL1:  subcounter_max <= 5'd4;
            S_CONV2:  subcounter_max <= 5'd11;
            S_POOL2:  subcounter_max <= 5'd4;
            S_CONV3:  subcounter_max <= 5'd11;
            S_POOL3:  subcounter_max <= 5'd17;
            // TODO: finish FSM
            S_DENSE2: subcounter_max <= 5'd0;
            S_DENSE1: subcounter_max <= 5'd0;
            default:  subcounter_max <= 5'd0;
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            subcounter <= 5'd0;
            counter <= 18'd0;
        end else begin
            state <= state_next;

            if (state != state_next) begin
                subcounter <= 5'd0;
                counter <= 18'd0;
            end else begin
                subcounter <= (subcounter == subcounter_max) ? 5'd0 : subcounter + 5'd1;
                counter <= (subcounter == subcounter_max) ? counter + 18'd1 : counter;
            end

            if (state_next == S_DONE) begin
                // TODO: show actual result
                result <= acc_out[0][7:0];
            end
        end
    end

    assign done = (state == S_DONE);

// dsp
    reg signed [`DATSIZE - 1 : 0] max_in [3:0];
    wire signed [`DATSIZE - 1 : 0] max_out;
    wire signed [`DATSIZE - 1 : 0] relu_out;
    reg signed [`DATSIZE - 1 : 0] relu_reg;
    reg signed [`DATSIZE - 1 : 0] max_out2;
    max_4 max_inst (
        .in0(max_in[0]),
        .in1(max_in[1]),
        .in2(max_in[2]),
        .in3(max_in[3]),
        .out(max_out)
    );
    relu relu_inst (
        .in(max_out),
        .out(relu_out)
    );
    always @(posedge clk) begin
        relu_reg <= relu_out;

        if (rst) begin
            max_out2 <= 22'd0;
        end else begin
            if (subcounter == subcounter_max) begin
                max_out2 <= 22'd0;
            end else begin
                if (subcounter[1:0] == 2'd0 && subcounter[4:0] != 5'd0) begin
                    max_out2 <= (relu_reg > max_out2) ? relu_reg : max_out2;
                end else begin
                    max_out2 <= max_out2;
                end
            end
        end
    end

    wire signed [(9 * `PARSIZE) - 1 : 0] read_conv_weights_flat;
    wire signed [`DATSIZE - 1 : 0] read_conv_weights [8:0];
    generate
        genvar i;
        for (i = 0; i < 9; i = i + 1) begin : read_conv_weights_gen
            assign read_conv_weights[i] = read_conv_weights_flat[(i + 1) * `PARSIZE - 1 -: `PARSIZE];
        end
    endgenerate

    wire signed [(8 * `PARSIZE) - 1 : 0] read_dense_weights_flat;
    wire signed [`DATSIZE - 1 : 0] read_dense_weights [7:0];
    generate
        for (i = 0; i < 8; i = i + 1) begin : read_dense_weights_gen
            assign read_dense_weights[i] = read_dense_weights_flat[(i + 1) * `PARSIZE - 1 -: `PARSIZE];
        end
    endgenerate

    reg signed [`DATSIZE - 1 : 0] acc_in [0 : 0];
    reg signed [`PARSIZE - 1 : 0] acc_weight [0 : 0];
    reg signed [`DATSIZE + `PARSIZE + 4 - 1 : 0] acc [0 : 0];
    wire signed [`DATSIZE + `PARSIZE + 4 - 1 : 0] acc_shift [0 : 0];
    wire signed [`DATSIZE - 1 : 0] acc_out [0 : 0];
    assign acc_shift[0] = acc[0] >>> `FPSHIFT;
    assign acc_out[0] = acc_shift[0][`DATSIZE - 1 : 0];

    always @(posedge clk) begin
        if (rst) begin
            acc[0] <= 22'd0;
        end else begin
            if ((subcounter == subcounter_max) && (
                (state == S_CONV1) ||
                (state == S_CONV2 && counter[3:0] == 4'd15) ||
                (state == S_CONV3 && counter[4:0] == 5'd31)
            )) begin
                acc[0] <= 22'd0;
            end else begin
                acc[0] <= acc[0] + (acc_in[0] * acc_weight[0]);
            end
        end
    end

// conv parameter memory
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
                pm_conv_weight_o <= {1'b0, counter[16:12]};
                pm_conv_weight_c <= {2'b0, counter[3:0]};
            end
            S_CONV3: begin // output (8, 8, 64)
                pm_conv_weight_en <= 1'b1;
                pm_conv_weight_o <= counter[16:11];
                pm_conv_weight_c <= {1'b0, counter[4:0]};
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
        .data(read_conv_weights_flat)
    );

    reg [5 : 0] pm_conv_bias_o;
    wire signed [`PARSIZE - 1 : 0] pm_conv_bias;
    always @(*) begin
        case (state)
            S_CONV1: begin // output (32, 32, 16)
                pm_conv_bias_o <= {2'b0, counter[13:10]};
            end
            S_CONV2: begin // output (16, 16, 32)
                pm_conv_bias_o <= {1'b0, counter[16:12]};
            end
            S_CONV3: begin // output (8, 8, 64)
                pm_conv_bias_o <= counter[16:11];
            end
            default: pm_conv_bias_o <= 6'd0;
        endcase
    end
    conv_biases conv_biases_inst (
        .state(state),
        .read_o(pm_conv_bias_o),
        .data(pm_conv_bias)
    );

// dense parameter memory
    reg pm_dense_weight_en;
    reg [6 : 0] pm_dense_weight_o;
    reg [7 : 0] pm_dense_weight_i;
    always @(*) begin
        case (state)
            S_DENSE2: begin // 256 -> 96
                pm_dense_weight_en <= 1'b1;
                pm_dense_weight_o <= counter[14:8];
                pm_dense_weight_i <= counter[7:0];
            end
            S_DENSE1: begin // 96 -> 96
                pm_dense_weight_en <= 1'b1;
                pm_dense_weight_o <= counter / 8'd96;
                pm_dense_weight_i <= counter % 8'd96;
            end
            default: begin
                pm_dense_weight_en <= 1'b0;
                pm_dense_weight_o <= 6'd0;
                pm_dense_weight_i <= 6'd0;
            end
        endcase
    end

    dense_weights dense_weights_inst (
        .clk(clk),
        .en(pm_dense_weight_en),
        .state(state),
        .read_o(pm_dense_weight_o),
        .read_i(pm_dense_weight_i),
        .data(read_dense_weights_flat)
    );

    reg [6 : 0] pm_dense_bias_o;
    wire signed [`PARSIZE - 1 : 0] pm_dense_bias;
    always @(*) begin
        case (state)
            S_DENSE2: begin // 256 -> 96
                pm_dense_bias_o <= counter[14:8];
            end
            S_DENSE1: begin // 96 -> 96
                pm_dense_bias_o <= counter / 8'd96;
            end
            default: pm_dense_bias_o <= 6'd0;
        endcase
    end
    dense_biases dense_biases_inst (
        .state(state),
        .read_o(pm_dense_bias_o),
        .data(pm_dense_bias)
    );

// feature map buffers
    reg fb_conv_write_en, fb_conv_read_en;
    reg [4 : 0] fb_conv_write_y, fb_conv_write_x;
    reg [5 : 0] fb_conv_write_c;
    reg signed [`DATSIZE - 1 : 0] fb_conv_write_data;
    reg [5 : 0] fb_conv_read_y, fb_conv_read_x, fb_conv_read_c;
    reg [3 : 0] fb_conv_read_s;
    wire signed [`DATSIZE - 1 : 0] fb_conv_read_data;

    always @(posedge clk) begin
        if (fb_conv_read_en && (subcounter[3:0] < 4'd10 && subcounter[3:0] != 4'd0)) begin
            acc_in[0] <= fb_conv_read_data;
            acc_weight[0] <= read_conv_weights[fb_conv_read_s - 4'd1];
        end else begin
            acc_in[0] <= 22'd0;
            acc_weight[0] <= 16'd0;
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

    // feat buf conv write
    always @(*) begin
        case (state)
            S_READ: begin // input (32, 32, 1)
                fb_conv_write_en <= 1'b1;
                fb_conv_write_y <= read_addr[9:5];
                fb_conv_write_x <= read_addr[4:0];
                fb_conv_write_c <= 6'd0;
                fb_conv_write_data <= read_data ? 22'd16384 : 22'd0; // 16384 = 2^14 -> 1
            end
            S_POOL1: begin // input (16, 16, 16)
                fb_conv_write_en <= (subcounter == subcounter_max);
                fb_conv_write_y <= {1'b0, counter[7:4]};
                fb_conv_write_x <= {1'b0, counter[3:0]};
                fb_conv_write_c <= {2'b0, counter[11:8]};
                fb_conv_write_data <= relu_reg;
            end
            S_POOL2: begin // input (8, 8, 32)
                fb_conv_write_en <= (subcounter == subcounter_max);
                fb_conv_write_y <= {2'b0, counter[5:3]};
                fb_conv_write_x <= {2'b0, counter[2:0]};
                fb_conv_write_c <= {1'b0, counter[10:6]};
                fb_conv_write_data <= relu_reg;
            end
            S_POOL3: begin // input (2, 2, 64)
                fb_conv_write_en <= (subcounter == subcounter_max);
                fb_conv_write_y <= {4'b0, counter[1]};
                fb_conv_write_x <= {4'b0, counter[0]};
                fb_conv_write_c <= counter[7:2];
                fb_conv_write_data <= max_out2;
            end
            default: begin
                fb_conv_write_en <= 1'b0;
                fb_conv_write_y <= 6'd0;
                fb_conv_write_x <= 6'd0;
                fb_conv_write_c <= 6'd0;
                fb_conv_write_data <= 22'd0;
            end
        endcase
    end

    // feat buf conv read
    always @(*) begin
        case (state)
            S_CONV1: begin // output (32, 32, 1)
                fb_conv_read_en <= (subcounter < subcounter_max);
                fb_conv_read_y <= {1'b0, counter[9:5]};
                fb_conv_read_x <= {1'b0, counter[4:0]};
                fb_conv_read_c <= 6'd0;
                fb_conv_read_s <= subcounter[3:0];
            end
            S_CONV2: begin // output (16, 16, 16)
                fb_conv_read_en <= (subcounter < subcounter_max);
                fb_conv_read_y <= {1'b0, counter[11:8]};
                fb_conv_read_x <= {1'b0, counter[7:4]};
                fb_conv_read_c <= {2'b0, counter[3:0]};
                fb_conv_read_s <= subcounter[3:0];
            end
            S_CONV3: begin // output (8, 8, 32)
                fb_conv_read_en <= (subcounter < subcounter_max);
                fb_conv_read_y <= {3'b0, counter[10:8]};
                fb_conv_read_x <= {3'b0, counter[7:5]};
                fb_conv_read_c <= {1'b0, counter[4:0]};
                fb_conv_read_s <= subcounter[3:0];
            end
            default: begin
                fb_conv_read_en <= 1'b0;
                fb_conv_read_y <= 6'd0;
                fb_conv_read_x <= 6'd0;
                fb_conv_read_c <= 6'd0;
                fb_conv_read_s <= 4'd0;
            end
        endcase
    end

    reg fb_pool_write_en, fb_pool_read_en;
    reg [5 : 0] fb_pool_write_y, fb_pool_write_x, fb_pool_write_c;
    reg signed [`DATSIZE - 1 : 0] fb_pool_write_data;
    reg [5 : 0] fb_pool_read_y, fb_pool_read_x, fb_pool_read_c;
    reg fb_pool_read_updown;
    wire signed [`DATSIZE - 1 : 0] fb_pool_read_data [1:0];

    always @(posedge clk) begin
        if (rst) begin
            max_in[0] <= 22'd0;
            max_in[1] <= 22'd0;
            max_in[2] <= 22'd0;
            max_in[3] <= 22'd0;
        end else if (subcounter[1:0] == 2'd1 || subcounter[1:0] == 2'd2) begin
            max_in[0] <= fb_pool_read_data[0];
            max_in[1] <= fb_pool_read_data[1];
            max_in[2] <= max_in[0];
            max_in[3] <= max_in[1];
        end else begin
            max_in[0] <= max_in[0];
            max_in[1] <= max_in[1];
            max_in[2] <= max_in[2];
            max_in[3] <= max_in[3];
        end
    end

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
        .read_data({fb_pool_read_data[1], fb_pool_read_data[0]})
    );

    // feat buf pool write
    always @(*) begin
        case (state)
            S_CONV1: begin // input (32, 32, 16)
                fb_pool_write_en <= (subcounter == subcounter_max);
                fb_pool_write_y <= {1'b0, counter[9:5]};
                fb_pool_write_x <= {1'b0, counter[4:0]};
                fb_pool_write_c <= {2'b0, counter[13:10]};
                fb_pool_write_data <= acc_out[0] + pm_conv_bias;
            end
            S_CONV2: begin // input (16, 16, 32)
                fb_pool_write_en <= (subcounter == subcounter_max) && (counter[3:0] == 4'd15);
                fb_pool_write_y <= {2'b0, counter[11:8]};
                fb_pool_write_x <= {2'b0, counter[7:4]};
                fb_pool_write_c <= {1'b0, counter[16:12]};
                fb_pool_write_data <= acc_out[0] + pm_conv_bias;
            end
            S_CONV3: begin // input (8, 8, 64)
                fb_pool_write_en <= (subcounter == subcounter_max) && (counter[4:0] == 5'd31);
                fb_pool_write_y <= {3'b0, counter[10:8]};
                fb_pool_write_x <= {3'b0, counter[7:5]};
                fb_pool_write_c <= counter[16:11];
                fb_pool_write_data <= acc_out[0] + pm_conv_bias;
            end
            default: begin
                fb_pool_write_en <= 1'b0;
                fb_pool_write_y <= 6'd0;
                fb_pool_write_x <= 6'd0;
                fb_pool_write_c <= 6'd0;
                fb_pool_write_data <= 22'd0;
            end
        endcase
    end

    // feat buf pool read
    always @(*) begin
        case (state)
            S_POOL1: begin // output (32, 32, 16) -> (16, 16, 16)
                fb_pool_read_en <= subcounter[1:0] == 2'd0 || subcounter[1:0] == 2'd1;
                fb_pool_read_y <= {2'b0, counter[7:4]};
                fb_pool_read_x <= {2'b0, counter[3:0]};
                fb_pool_read_c <= {2'b0, counter[11:8]};
                fb_pool_read_updown <= subcounter[0];
            end
            S_POOL2: begin // output (16, 16, 32)
                fb_pool_read_en <= subcounter[1:0] == 2'd0 || subcounter[1:0] == 2'd1;
                fb_pool_read_y <= {3'b0, counter[5:3]};
                fb_pool_read_x <= {3'b0, counter[2:0]};
                fb_pool_read_c <= {1'b0, counter[10:6]};
                fb_pool_read_updown <= subcounter[0];
            end
            S_POOL3: begin // output (8, 8, 64)
                fb_pool_read_en <= subcounter[1:0] == 2'd0 || subcounter[1:0] == 2'd1;
                fb_pool_read_y <= {4'b0, counter[1], subcounter[3]};
                fb_pool_read_x <= {4'b0, counter[0], subcounter[2]};
                fb_pool_read_c <= counter[7:2];
                fb_pool_read_updown <= subcounter[0];
            end
            default: begin
                fb_pool_read_en <= 1'b0;
                fb_pool_read_y <= 6'd0;
                fb_pool_read_x <= 6'd0;
                fb_pool_read_c <= 6'd0;
                fb_pool_read_updown <= 1'd0;
            end
        endcase
    end
endmodule
