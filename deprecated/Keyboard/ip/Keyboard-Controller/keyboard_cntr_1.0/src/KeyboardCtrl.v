module KeyboardCtrl#(
   parameter SYSCLK_FREQUENCY_HZ = 100000000
)(
    output reg [7:0] key_in,
    output reg is_extend,
    output reg is_break,
    output reg valid,
    output err,
    inout PS2_DATA,
    inout PS2_CLK,
    input rst,
    input clk
);
//////////////////////////////////////////////////////////
// This Keyboard  Controller do not support lock LED control
//////////////////////////////////////////////////////////

    parameter RESET          = 3'd0;
    parameter SEND_CMD       = 3'd1;
    parameter WAIT_ACK       = 3'd2;
    parameter WAIT_KEYIN     = 3'd3;
    parameter GET_BREAK      = 3'd4;
    parameter GET_EXTEND     = 3'd5;
    parameter RESET_WAIT_BAT = 3'd6;
    
    parameter CMD_RESET           = 8'hFF; 
    parameter CMD_SET_STATUS_LEDS = 8'hED;
    parameter RSP_ACK             = 8'hFA;
    parameter RSP_BAT_PASS        = 8'hAA;
    
    parameter BREAK_CODE  = 8'hF0;
    parameter EXTEND_CODE = 8'hE0;
    parameter CAPS_LOCK   = 8'h58;
    parameter NUM_LOCK    = 8'h77;
    parameter SCR_LOCK    = 8'h7E;
    
    reg next_is_extend, next_is_break, next_valid;

    wire [7:0] rx_data;
    wire rx_valid;
    wire busy;
    
    reg [7:0] tx_data, next_tx_data;
    reg tx_valid, next_tx_valid;
    reg [2:0] state, next_state;
    reg [2:0] lock_status, next_lock_status;
    
    always @ (posedge clk, posedge rst)
        if(rst)
            key_in <= 0;
        else if(rx_valid)
            key_in <= rx_data;
        else
            key_in <= key_in;
    
    always @ (posedge clk, posedge rst)begin
        if(rst)begin
            state <= RESET;
            is_extend <= 1'b0;
            is_break <= 1'b1;
            valid <= 1'b0;
            lock_status <= 3'b0;
            tx_data <= 8'h00;
            tx_valid <= 1'b0;
        end else begin
            state <= next_state;
            is_extend <= next_is_extend;
            is_break <= next_is_break;
            valid <= next_valid;
            lock_status <= next_lock_status;
            tx_data <= next_tx_data;
            tx_valid <= next_tx_valid;
        end
    end
    always @ (*) begin
        case (state)
            RESET:    next_state = SEND_CMD;
            SEND_CMD: next_state = (busy == 1'b0) ? WAIT_ACK : SEND_CMD;
            WAIT_ACK: begin
                if(rx_valid == 1'b1) begin
                    if(rx_data == RSP_ACK && tx_data == CMD_RESET) begin
                        next_state = RESET_WAIT_BAT;
                    end else if(rx_data == RSP_ACK && tx_data == CMD_SET_STATUS_LEDS) begin
                        next_state = SEND_CMD;
                    end else begin
                        next_state = WAIT_KEYIN;
                    end
                end else begin
                    next_state = (err == 1'b1) ? RESET : WAIT_ACK;
                end
            end
            WAIT_KEYIN: begin
                if (rx_valid == 1'b1) begin
                    case (rx_data)
                        BREAK_CODE:  next_state = GET_BREAK;
                        EXTEND_CODE: next_state = GET_EXTEND;
                        default:     next_state = WAIT_KEYIN;
                    endcase
                end else begin
                    next_state = (err == 1'b1) ? RESET : WAIT_KEYIN;
                end
            end
            GET_BREAK: begin
                if (rx_valid == 1'b1)
                    next_state = WAIT_KEYIN;
                else
                    next_state = (err == 1'b1) ? RESET : GET_BREAK;
            end
            GET_EXTEND: begin
                if (rx_valid == 1'b1)
                    next_state = (rx_data == BREAK_CODE) ? GET_BREAK : WAIT_KEYIN;
                else
                    next_state = (err == 1'b1) ? RESET : GET_EXTEND;
            end
            RESET_WAIT_BAT: begin
                if (rx_valid == 1'b1)
                    next_state = (rx_data == RSP_BAT_PASS) ? WAIT_KEYIN : RESET;
                else
                    next_state = (err == 1'b1) ? RESET : RESET_WAIT_BAT;
            end
            default: next_state = RESET;
        endcase
    end
    always @ (*) begin
        next_tx_valid = 1'b0;
        case (state)
            RESET:    next_tx_valid = 1'b0;
            SEND_CMD: next_tx_valid = ~busy;
            default:  next_tx_valid = next_tx_valid;
        endcase
    end
    always @ (*) begin
        next_tx_data = tx_data;
        case (state)
            RESET:    next_tx_data = CMD_RESET;
            WAIT_ACK: next_tx_data = (rx_data == RSP_ACK && tx_data == CMD_SET_STATUS_LEDS) ? {5'b00000, lock_status} : next_tx_data;
            default:  next_tx_data = next_tx_data;
        endcase
    end
    always @ (*) begin
        next_lock_status = (state == RESET) ? 3'b0 : lock_status;
    end
    always @ (*) begin
        next_valid = 1'b0;
        case (state)
            RESET:      next_valid = 1'b0;
            WAIT_KEYIN: next_valid = (rx_valid == 1'b1 && rx_data != BREAK_CODE && rx_data != EXTEND_CODE) ? 1'b1 : next_valid;
            GET_BREAK:  next_valid = (rx_valid == 1'b1) ? 1'b1 : next_valid;
            GET_EXTEND: next_valid = (rx_valid == 1'b1 && rx_data != BREAK_CODE) ? 1'b1 : next_valid;
            default: next_valid = next_valid;
        endcase
    end
    always @ (*) begin
        next_is_break = ((state == RESET) || (state == GET_BREAK && rx_valid == 1'b1)) ? 1'b1 : 1'b0;
        next_is_extend = 1'b0;
        case (state)
            RESET:      next_is_extend = 1'b0;
            GET_BREAK:  next_is_extend = is_extend;
            GET_EXTEND: next_is_extend = (rx_valid == 1'b1) ? 1'b1 : next_is_extend;
            default:    next_is_extend = next_is_extend;
        endcase
    end

    Ps2Interface #(
      .SYSCLK_FREQUENCY_HZ(SYSCLK_FREQUENCY_HZ)
    ) Ps2Interface_i(
      .ps2_clk(PS2_CLK),
      .ps2_data(PS2_DATA),
      
      .clk(clk),
      .rst(rst),
      
      .tx_data(tx_data),
      .tx_valid(tx_valid),
      
      .rx_data(rx_data),
      .rx_valid(rx_valid),
      
      .busy(busy),
      .err(err)
    );
        
endmodule
