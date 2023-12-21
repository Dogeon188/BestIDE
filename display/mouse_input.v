module mouse_input(
    input clk, 
    input MOUSE_X_POS, MOUSE_Y_POS, MOUSE_LEFT, MOUSE_RIGHT,
    output reg [18:0] write_addr,
    output write_enable,
    output write_data
    );
    parameter WAIT = 2'b00, WRITE1 = 2'b01, WRITE2 = 2'b11, DONE = 2'b10;

    reg [1:0] state, state_next;
    reg [9:0] prev_mouse_x, prev_mouse_y, next_prev_mouse_x, next_prev_mouse_y;
    reg [9:0] count, next_count;
    reg [9:0] end_mouse_x, end_mouse_y, next_end_mouse_x, next_end_mouse_y;
    wire [9:0] abs_delta_x, abs_delta_y;
    wire x_is_larger;
    reg done;
    assign abs_delta_x = (MOUSE_X_POS - end_mouse_x) ? (MOUSE_X_POS - end_mouse_x) : (end_mouse_x - MOUSE_X_POS);
    assign abs_delta_y = (MOUSE_Y_POS - end_mouse_y) ? (MOUSE_Y_POS - end_mouse_y) : (end_mouse_y - MOUSE_Y_POS);
    always @ (posedge clk) begin
        state <= state_next;
        prev_mouse_x <= next_prev_mouse_x;
        prev_mouse_y <= next_prev_mouse_y;
        end_mouse_x <= next_end_mouse_x;
        end_mouse_y <= next_end_mouse_y;
        count <= next_count;
    end
    assign write_enable = MOUSE_LEFT || MOUSE_RIGHT;
    assign write_data = MOUSE_LEFT;
    assign x_is_larger = (abs_delta_x > abs_delta_y) ? 1 : 0;
    always @(*) begin
        case(state)
            WAIT: begin
                if(MOUSE_LEFT || MOUSE_RIGHT) begin
                    state_next = (abs_delta_x || abs_delta_y) ? WRITE1 : WAIT;
                    next_end_mouse_x = MOUSE_X_POS;
                    next_end_mouse_y = MOUSE_Y_POS;
                    next_count = 0;
                    next_prev_mouse_x = (abs_delta_x || abs_delta_y) ? next_prev_mouse_x : MOUSE_X_POS;
                    next_prev_mouse_y =(abs_delta_x || abs_delta_y) ? next_prev_mouse_y : MOUSE_Y_POS;
                    write_addr = MOUSE_X_POS + MOUSE_Y_POS * 640;
                end
                else begin
                    state_next = WAIT;
                    next_end_mouse_x = MOUSE_X_POS;
                    next_end_mouse_y = MOUSE_Y_POS;
                    next_count = 0;
                    next_prev_mouse_x = MOUSE_X_POS;
                    next_prev_mouse_y = MOUSE_Y_POS;
                    write_addr = write_addr;
                end
            end
            WRITE1: begin
                if(x_is_larger) begin
                    state_next = (count == abs_delta_x) ? DONE : WRITE2;
                    next_count = count;
                    write_addr = (prev_mouse_x + count) + (prev_mouse_y * count * abs_delta_y / abs_delta_x) * 640;
                    next_prev_mouse_x = prev_mouse_x;
                    next_prev_mouse_y = prev_mouse_y;
                    next_end_mouse_x = end_mouse_x;
                    next_end_mouse_y = end_mouse_y;
                end
                else begin
                    state_next = (count == abs_delta_y) ? DONE : WRITE2;
                    next_count = count;
                    write_addr = (prev_mouse_x + count * abs_delta_x / abs_delta_y) + (prev_mouse_y + count) * 640;
                    next_prev_mouse_x = prev_mouse_x;
                    next_prev_mouse_y = prev_mouse_y;
                    next_end_mouse_x = end_mouse_x;
                    next_end_mouse_y = end_mouse_y;
                end
            end
            WRITE2: begin
                if(x_is_larger) begin
                    state_next = WRITE1;
                    next_count = count + 1;
                    write_addr = (prev_mouse_x + count) + (prev_mouse_y * count * abs_delta_y / abs_delta_x + 1) * 640;
                    next_prev_mouse_x = prev_mouse_x;
                    next_prev_mouse_y = prev_mouse_y;
                    next_end_mouse_x = end_mouse_x;
                    next_end_mouse_y = end_mouse_y;
                end
                else begin
                    state_next = WRITE2;
                    next_count = count + 1;
                    write_addr = (prev_mouse_x + count * abs_delta_x / abs_delta_y + 1) + (prev_mouse_y + count) * 640;
                    next_prev_mouse_x = prev_mouse_x;
                    next_prev_mouse_y = prev_mouse_y;
                    next_end_mouse_x = end_mouse_x;
                    next_end_mouse_y = end_mouse_y;
                end
            end
            DONE: begin
                state_next = WAIT;
                next_count = 0;
                write_addr = write_addr;
                next_prev_mouse_x = end_mouse_x;
                next_prev_mouse_y = end_mouse_y;
                next_end_mouse_x = end_mouse_x;
                next_end_mouse_y = end_mouse_y;
            end
        endcase
    end
endmodule