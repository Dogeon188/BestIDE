module mouse_input(
    input clk, rst,
    input [9 : 0] MOUSE_X_POS, MOUSE_Y_POS,
    input Mouse_write,clear_block,
    input new_event,
    input ready_to_clear_canvas,
    output [9:0] write_addr,
    output wire write_enable,
    output wire write_data,
    output wire [8:0] writing_block_pos,
    output reg editing
);
    reg [9:0] counter;
    reg [4:0] writing_block_x_pos;
    reg [3:0] writing_block_y_pos;
    assign writing_block_pos = {writing_block_y_pos, writing_block_x_pos};
    always @(posedge clk) begin
        if(rst) begin
            counter <= 10'b0;
        end
        else if(ready_to_clear_canvas || clear_block) begin
            counter <= ~10'b0;
        end
        else if(counter) begin
            counter <= counter - 1;
        end
    end

    wire [9:0] write_addr_x, write_addr_y;
    always @(posedge clk) begin
        if(ready_to_clear_canvas || counter || clear_block) begin
            editing <= 1'b0;
        end
        else if(editing) begin
            editing <= 1'b1;
        end
        else if(new_event && Mouse_write) begin
            editing <= 1'b1;
        end
        else begin
            editing <= editing;
        end
    end

    always @(posedge clk) begin
        if(editing) begin
            writing_block_x_pos <= writing_block_x_pos;
            writing_block_y_pos <= writing_block_y_pos;
        end
        else if(new_event && Mouse_write && counter == 10'd0) begin
            writing_block_x_pos <= MOUSE_X_POS[9:5];
            writing_block_y_pos <= MOUSE_Y_POS[9:5];
        end
        else begin
            writing_block_x_pos <= writing_block_x_pos;
            writing_block_y_pos <= writing_block_y_pos;
        end
    end
    
    wire write_en;

    assign write_enable = ready_to_clear_canvas || clear_block || counter || (write_en && write_addr_x[9:5] == writing_block_x_pos && write_addr_y[9:5] == writing_block_y_pos);
    assign write_addr = (ready_to_clear_canvas || clear_block) ? 0 : counter ? counter : {write_addr_y[4:0], write_addr_x[4:0]};
    wire canva_write;
    assign write_data = canva_write & ~clear_block & ~ready_to_clear_canvas && (counter == 0);
    canva_input cv(
        .clk(clk),
        .rst(rst),
        .MOUSE_X_POS(MOUSE_X_POS[9:0]),
        .MOUSE_Y_POS(MOUSE_Y_POS[9:0]),
        .Mouse_write(Mouse_write),
        .new_event(new_event),
        .write_addr_x(write_addr_x),
        .write_addr_y(write_addr_y),
        .write_enable(write_en),
        .write_data(canva_write)
    );
endmodule


module canva_input(
    input clk, rst,
    input [9:0] MOUSE_X_POS, MOUSE_Y_POS,
    input Mouse_write,
    input new_event,
    output [9:0] write_addr_x, write_addr_y,
    output wire write_enable,
    output wire write_data
    );

    reg [1:0] state, next_state;
    parameter WAIT = 2'b00, WRITE = 2'b01, DONE = 2'b10;
    reg [9:0] pre_x_pos, next_pre_x_pos;
    reg [8:0] pre_y_pos, next_pre_y_pos;
    reg [9:0] end_x_pos, next_end_x_pos;
    reg [8:0] end_y_pos, next_end_y_pos;
    reg [9:0] draw_x_pos, next_draw_x_pos;
    reg [9:0] draw_y_pos, next_draw_y_pos;
    reg signed [10:0] delta_x, next_delta_x;
    reg signed [9:0] delta_y, next_delta_y;
    wire [9:0] abs_delta_x;
    wire [8:0] abs_delta_y;
    reg signed [9:0] D, next_D;
    assign abs_delta_x = next_delta_x < 0 ? -next_delta_x : next_delta_x;
    assign abs_delta_y = next_delta_y < 0 ? -next_delta_y : next_delta_y;
    assign write_addr_x = draw_x_pos;
    assign write_addr_y = draw_y_pos;
    always @ (posedge clk) begin
        if(rst) begin
            state <= WAIT;
            pre_x_pos <= 0;
            pre_y_pos <= 0;
            end_x_pos <= 0;
            end_y_pos <= 0;
            delta_x <= 0;
            delta_y <= 0;
            D <= 0;
            draw_x_pos <= 0;
            draw_y_pos <= 0;
        end
        else begin
            state <= next_state;
            pre_x_pos <= next_pre_x_pos;
            pre_y_pos <= next_pre_y_pos;
            end_x_pos <= next_end_x_pos;
            end_y_pos <= next_end_y_pos;
            delta_x <= next_delta_x;
            delta_y <= next_delta_y;
            D <= next_D;
            draw_x_pos <= next_draw_x_pos;
            draw_y_pos <= next_draw_y_pos;
        end
    end
    assign write_enable = Mouse_write;
    assign write_data = Mouse_write;
    wire _start = Mouse_write && (MOUSE_X_POS != end_x_pos || MOUSE_Y_POS != end_y_pos);
    always @(*) begin
        case(state) 
        WAIT: begin
            if(new_event) begin
                next_state = _start ? WRITE : WAIT;
                next_pre_x_pos = _start ? pre_x_pos : MOUSE_X_POS;
                next_pre_y_pos = _start ? pre_y_pos : MOUSE_Y_POS;
                next_end_x_pos = MOUSE_X_POS;
                next_end_y_pos = MOUSE_Y_POS;
                next_delta_x = MOUSE_X_POS - pre_x_pos;
                next_delta_y = MOUSE_Y_POS - pre_y_pos;
                next_D = (abs_delta_x > abs_delta_y) ? (abs_delta_y << 1) - abs_delta_x : (abs_delta_x << 1) - abs_delta_y;
                next_draw_x_pos = pre_x_pos;
                next_draw_y_pos = pre_y_pos;
            end
            else begin
                next_state = WAIT;
                next_pre_x_pos = pre_x_pos;
                next_pre_y_pos = pre_y_pos;
                next_end_x_pos = end_x_pos;
                next_end_y_pos = end_y_pos;
                next_delta_x = delta_x;
                next_delta_y = delta_y;
                next_D = D;
                next_draw_x_pos = pre_x_pos;
                next_draw_y_pos = pre_y_pos;
            end
        end
        WRITE: begin
            if(abs_delta_x > abs_delta_y) begin
                if(delta_x < 0) begin
                    next_state = (draw_x_pos - 1) == end_x_pos ? DONE : WRITE;
                    next_draw_x_pos = draw_x_pos - 1;
                    if(D > 0) begin
                        next_draw_y_pos = delta_y < 0 ? draw_y_pos - 1 : draw_y_pos + 1;
                        next_D = D + (abs_delta_y << 1) - (abs_delta_x << 1);
                    end
                    else begin
                        next_draw_y_pos = draw_y_pos;
                        next_D = D + (abs_delta_y << 1);
                    end
                end
                else begin
                    next_state = (draw_x_pos + 1) == end_x_pos ? DONE : WRITE;
                    next_draw_x_pos = draw_x_pos + 1;
                    if(D > 0) begin
                        next_draw_y_pos = delta_y < 0 ? draw_y_pos - 1 : draw_y_pos + 1;
                        next_D = D + (abs_delta_y << 1) - (abs_delta_x << 1);
                    end
                    else begin
                        next_draw_y_pos = draw_y_pos;
                        next_D = D + (abs_delta_y << 1);
                    end
                end
            end
            else begin
                if(delta_y < 0) begin
                    next_state = (draw_y_pos - 1) == end_y_pos ? DONE : WRITE;
                    next_draw_y_pos = draw_y_pos - 1;
                    if(D > 0) begin
                        next_draw_x_pos = delta_x < 0 ? draw_x_pos - 1 : draw_x_pos + 1;
                        next_D = D + (abs_delta_x << 1) - (abs_delta_y << 1);
                    end
                    else begin
                        next_draw_x_pos = draw_x_pos;
                        next_D = D + (abs_delta_x << 1);
                    end
                end
                else begin
                    next_state = (draw_y_pos + 1) == end_y_pos ? DONE : WRITE;
                    next_draw_y_pos = draw_y_pos + 1;
                    if(D > 0) begin
                        next_draw_x_pos = delta_x < 0 ? draw_x_pos - 1 : draw_x_pos + 1;
                        next_D = D + (abs_delta_x << 1) - (abs_delta_y << 1);
                    end
                    else begin
                        next_draw_x_pos = draw_x_pos;
                        next_D = D + (abs_delta_x << 1);
                    end
                end
            end
            next_pre_x_pos = pre_x_pos;
            next_pre_y_pos = pre_y_pos;
            next_delta_x = delta_x;
            next_delta_y = delta_y;
            next_end_x_pos = end_x_pos;
            next_end_y_pos = end_y_pos;
        end
        DONE: begin
            next_state = WAIT;
            next_pre_x_pos = end_x_pos;
            next_pre_y_pos = end_y_pos;
            next_end_x_pos = end_x_pos;
            next_end_y_pos = end_y_pos;
            next_delta_x = 0;
            next_delta_y = 0;
            next_D = 0;
            next_draw_x_pos = end_x_pos;
            next_draw_y_pos = end_y_pos;
        end
        default: begin
            next_state = WAIT;
            next_pre_x_pos = end_x_pos;
            next_pre_y_pos = end_y_pos;
            next_end_x_pos = end_x_pos;
            next_end_y_pos = end_y_pos;
            next_delta_x = 0;
            next_delta_y = 0;
            next_D = 0;
            next_draw_x_pos = end_x_pos;
            next_draw_y_pos = end_y_pos;
        end
        endcase
    end
endmodule