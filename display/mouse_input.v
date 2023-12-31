module mouse_input(
    input clk, rst,
    input [9 : 0] MOUSE_X_POS, MOUSE_Y_POS,
    input MOUSE_LEFT, MOUSE_RIGHT,
    input new_event,
    input end_of_editing,
    output [9:0] write_addr,
    output wire write_enable,
    output wire write_data,
    output reg [4:0] writing_x, writing_y,
    output reg editing
);
    
    wire [9:0] write_addr_x, write_addr_y;
    always @(posedge clk) begin
        if(end_of_editing) begin
            editing <= 1'b0;
        end
        else if(new_event) begin
            editing <= 1'b1;
        end
        else begin
            editing <= editing;
        end
    end

    always @(posedge clk) begin
        if(editing) begin
            writing_x <= writing_x;
            writing_y <= writing_y;
        end
        else if(new_event && (MOUSE_LEFT || MOUSE_RIGHT)) begin
            writing_x <= MOUSE_X_POS[9:5];
            writing_y <= MOUSE_Y_POS[9:5];
        end
        else begin
            writing_x <= writing_x;
            writing_y <= writing_y;
        end
    end
    
    wire write_en;

    assign write_enable = write_en && write_addr_x[9:5] == writing_x && write_addr_y[9:5] == writing_y;
    assign write_addr = {write_addr_y[4:0], write_addr_x[4:0]};

    canva_input cv(
        .clk(clk),
        .rst(rst),
        .MOUSE_X_POS(MOUSE_X_POS[9:0]),
        .MOUSE_Y_POS(MOUSE_Y_POS[9:0]),
        .MOUSE_LEFT(MOUSE_LEFT),
        .MOUSE_RIGHT(MOUSE_RIGHT),
        .new_event(new_event),
        .write_addr_x(write_addr_x),
        .write_addr_y(write_addr_y),
        .write_enable(write_en),
        .write_data(write_data)
    );
endmodule


module canva_input(
    input clk, rst,
    input [9:0] MOUSE_X_POS, MOUSE_Y_POS,
    input MOUSE_LEFT, MOUSE_RIGHT,
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
    assign write_enable = (MOUSE_LEFT || MOUSE_RIGHT);
    assign write_data = MOUSE_LEFT && !rst;
    wire _start = (MOUSE_LEFT || MOUSE_RIGHT) && (MOUSE_X_POS != end_x_pos || MOUSE_Y_POS != end_y_pos);
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
        endcase
    end
endmodule