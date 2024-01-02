module recognizer(
    input clk, rst,
    input end_write,
    input read_in_data,
    output [9:0] read_addr,
    output wire read_enable,
    output wire ready_to_write,
    output wire [7:0] write_data
);

    reg [31:0] canvas [31:0];
    reg [9:0] counter;
    reg data_ready;
    always @(posedge clk) begin
        if(rst) begin
            counter <= 10'd0;
            data_ready <= 1'b0;
        end
        else if(end_write) begin
            canvas[read_addr[9:5]][read_addr[4:0]] <= read_in_data[7:0];
            counter <= 10'd1;
            data_ready <= 1'b0;
        end
        else if(counter) begin
            canvas[read_addr[9:5]][read_addr[4:0]] <= read_in_data[7:0];
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


    assign ready_to_write = data_ready;
    assign write_data = 8'd65;
    assign read_enable = end_write || counter;
    assign read_addr = counter;


endmodule