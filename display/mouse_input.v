module mouse_input(
    input clk, 
    input MOUSE_X_POS, MOUSE_Y_POS, MOUSE_LEFT, MOUSE_RIGHT,
    output [18:0] write_addr,
    output write_enable,
    output write_data
    );
    parameter WAIT = 2'b00, WRITE1 = 2'b01, WRITE2 = 2'b11;

    reg [1:0] state, state_next;
    reg [9:0] prev_mouse_x, prev_mouse_y;
    reg [9:0] current_mouse_x, current_mouse_y;
    reg [9:0] end_mouse_x, end_mouse_y;
    wire [9:0] abs_delta_x, abs_delta_y;
    reg done, x_is_larger;
    always @ (posedge clk) begin
        state <= state_next;
        prev_mouse_x <= current_mouse_x;
        prev_mouse_y <= current_mouse_y;
    end
    assign write_addr = current_mouse_x + current_mouse_y * 640;
    assign write_enable = state[0];
    assign write_data = MOUSE_LEFT;
    assign abs_delta_x = (prev_mouse_x - MOUSE_X_POS) ? prev_mouse_x - MOUSE_X_POS : MOUSE_X_POS - prev_mouse_x;
    assign abs_delta_y = (prev_mouse_y - MOUSE_Y_POS) ? prev_mouse_y - MOUSE_Y_POS : MOUSE_Y_POS - prev_mouse_y;
    always @ (*) begin
        case (state)
            WAIT: begin
                if(MOUSE_LEFT || MOUSE_RIGHT) begin
                    if(abs_delta_x != 0 || abs_delta_y != 0) begin
                        state_next = WRITE1;
                        end_mouse_x = MOUSE_X_POS;
                        end_mouse_y = MOUSE_Y_POS;
                        current_mouse_x = current_mouse_x;
                        current_mouse_y = current_mouse_y;
                        done = 0;
                        x_is_larger = abs_delta_x > abs_delta_y;
                    end
                    else begin
                        state_next = WAIT;
                        end_mouse_x = end_mouse_x;
                        end_mouse_y = end_mouse_y;
                        current_mouse_x = current_mouse_x;
                        current_mouse_y = current_mouse_y;
                        done = 1;
                        x_is_larger = 0;
                    end
                end
                else begin
                    state_next = WAIT;
                    end_mouse_x = end_mouse_x;
                    end_mouse_y = end_mouse_y;
                    current_mouse_x = MOUSE_X_POS;
                    current_mouse_y = MOUSE_Y_POS;
                    done = 1;
                    x_is_larger = 0;
                end
            end
            WRITE1: begin
                if(x_is_larger) begin
                    if(prev_mouse_x == end_mouse_x) begin
                        state_next = WAIT;
                        end_mouse_x = end_mouse_x;
                        end_mouse_y = end_mouse_y;
                        current_mouse_x = prev_mouse_x;
                        current_mouse_y = prev_mouse_y;
                        done = 1;
                        x_is_larger = 0;
                    end
                    else begin
                        state_next = WRITE2;
                        end_mouse_x = end_mouse_x;
                        end_mouse_y = end_mouse_y;
                        current_mouse_x = prev_mouse_x + 1;
                        current_mouse_y = prev_mouse_y + 1;
                        done = 0;
                        x_is_larger = 1;
                    end
                end
                else begin
                    if(prev_mouse_y == end_mouse_y) begin
                        state_next = WAIT;
                        end_mouse_x = end_mouse_x;
                        end_mouse_y = end_mouse_y;
                        current_mouse_x = current_mouse_x;
                        current_mouse_y = current_mouse_y;
                        done = 1;
                        x_is_larger = 0;
                    end
                    else begin
                        state_next = WRITE2;
                        end_mouse_x = end_mouse_x;
                        end_mouse_y = end_mouse_y;
                        current_mouse_x = prev_mouse_x + 1;
                        current_mouse_y = current_mouse_y + 1;
                        done = 0;
                        done = 0;
                        x_is_larger = 0;
                    end
                end
            end
            WRITE2: begin
                if(x_is_larger) begin
                    state_next = WRITE1;
                    end_mouse_x = end_mouse_x;
                    end_mouse_y = end_mouse_y;
                    current_mouse_x = current_mouse_x;
                    current_mouse_y = current_mouse_y - 1;
                    done = 0;
                    x_is_larger = 1;
                end
                else begin
                    state_next = WRITE1;
                    end_mouse_x = end_mouse_x;
                    end_mouse_y = end_mouse_y;
                    current_mouse_x = current_mouse_x - 1;
                    current_mouse_y = current_mouse_y;
                    done = 0;
                    x_is_larger = 0;
                end
            end
        endcase
    end

endmodule