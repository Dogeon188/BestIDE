
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
    // recognizer_core core_inst (
    //     .clk(clk),
    //     .rst(rst),
    //     .read_start(in_start),
    //     .read_data(read_data),
    //     .read_addr(read_addr),
    //     .result(result),
    //     .pending(pending)
    // );
    assign core_done = 1'b1;
    assign core_result = 8'd64;

    // FSM
    reg [3:0] state;
    parameter S_IDLE = 4'd0;
    parameter S_READ = 4'd1;
    parameter S_PROC = 4'd2;
    parameter S_DONE = 4'd3;

    reg [9:0] counter;
    wire [9:0] counter_next = (state == S_READ) ? counter + 10'd1 : 10'd0;

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

            counter <= counter_next;
            result <= (state == S_DONE) ? 8'b0 : core_result;
        end
    end

    assign read_addr = counter;
    assign read_enable = (state == S_READ);
    assign result_valid = (state == S_DONE);
    assign pending = (state == S_READ) || (state == S_PROC);
endmodule