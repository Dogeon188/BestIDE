module recognizer(
    input clk, rst,
    input in_start,
    input read_data,
    output [9:0] read_addr,
    output wire read_enable, // enable read from canvas
    output wire result_valid,
    output wire [7:0] result,
    output reg pending // assert when reading canvas & processing
);

    reg [31:0] canvas [31:0];
    reg [9:0] counter;
    reg data_ready;
    always @(posedge clk) begin
        if(rst) begin
            counter <= 10'd0;
            data_ready <= 1'b0;
        end
        else if(in_start) begin
            canvas[read_addr[9:5]][read_addr[4:0]] <= read_data;
            counter <= 10'd1;
            data_ready <= 1'b0;
        end
        else if(counter) begin
            canvas[read_addr[9:5]][read_addr[4:0]] <= read_data;
            counter <= counter + 1;
            if(counter == ~10'd0) begin
                data_ready <= 1'b1;
            end
            else begin
                data_ready <= 1'b0;
            end
        end
        else begin
            counter <= 10'd0;
            data_ready <= 1'b0;
        end
    end

    always @(*) begin
        if(rst) pending = 1'b0;
        else if(in_start) pending = 1'b1;
        else if(data_ready) pending = 1'b0;
        else pending = pending;
    end


    assign ready_to_write = data_ready;
    assign write_data = 8'd65;
    assign read_enable = in_start || counter;
    assign read_addr = counter;
endmodule