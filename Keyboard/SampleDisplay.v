module SampleDisplay(
    output wire [6:0] display,
    output wire [3:0] digit,
    output wire been_ready,
    inout wire PS2_DATA,
    inout wire PS2_CLK,
    input wire rst,
    input wire clk
    );
    
    parameter [8:0] LEFT_SHIFT_CODES  = 9'b0_0001_0010;
    parameter [8:0] RIGHT_SHIFT_CODES = 9'b0_0101_1001;
    parameter [8:0] KEY_CODES_00 = 9'b0_0100_0101; // 0 => 45
    parameter [8:0] KEY_CODES_01 = 9'b0_0001_0110; // 1 => 16
    parameter [8:0] KEY_CODES_02 = 9'b0_0001_1110; // 2 => 1E
    parameter [8:0] KEY_CODES_03 = 9'b0_0010_0110; // 3 => 26
    parameter [8:0] KEY_CODES_04 = 9'b0_0010_0101; // 4 => 25
    parameter [8:0] KEY_CODES_05 = 9'b0_0010_1110; // 5 => 2E
    parameter [8:0] KEY_CODES_06 = 9'b0_0011_0110; // 6 => 36
    parameter [8:0] KEY_CODES_07 = 9'b0_0011_1101; // 7 => 3D
    parameter [8:0] KEY_CODES_08 = 9'b0_0011_1110; // 8 => 3E
    parameter [8:0] KEY_CODES_09 = 9'b0_0100_0110; // 9 => 46

        
    parameter [8:0] KEY_CODES_10 = 9'b0_0111_0000; // right_0 => 70
    parameter [8:0] KEY_CODES_11 = 9'b0_0110_1001; // right_1 => 69
    parameter [8:0] KEY_CODES_12 = 9'b0_0111_0010; // right_2 => 72
    parameter [8:0] KEY_CODES_13 = 9'b0_0111_1010; // right_3 => 7A
    parameter [8:0] KEY_CODES_14 = 9'b0_0110_1011; // right_4 => 6B
    parameter [8:0] KEY_CODES_15 = 9'b0_0111_0011; // right_5 => 73
    parameter [8:0] KEY_CODES_16 = 9'b0_0111_0100; // right_6 => 74
    parameter [8:0] KEY_CODES_17 = 9'b0_0110_1100; // right_7 => 6C
    parameter [8:0] KEY_CODES_18 = 9'b0_0111_0101; // right_8 => 75
    parameter [8:0] KEY_CODES_19 = 9'b0_0111_1101; // right_9 => 7D

    parameter [8:0] KEY_CODES_A = 9'h01C; // A => 1C
    parameter [8:0] KEY_CODES_B = 9'h032; // B => 32
    parameter [8:0] KEY_CODES_C = 9'h021; // C => 21
    parameter [8:0] KEY_CODES_D = 9'h023; // D => 23
    parameter [8:0] KEY_CODES_E = 9'h024; // E => 24
    parameter [8:0] KEY_CODES_F = 9'h02B; // F => 2B
    parameter [8:0] KEY_CODES_G = 9'h034; // G => 34
    parameter [8:0] KEY_CODES_H = 9'h033; // H => 33
    parameter [8:0] KEY_CODES_I = 9'h043; // I => 43
    parameter [8:0] KEY_CODES_J = 9'h03B; // J => 3B
    parameter [8:0] KEY_CODES_K = 9'h042; // K => 42
    parameter [8:0] KEY_CODES_L = 9'h04B; // L => 4B
    parameter [8:0] KEY_CODES_M = 9'h03A; // M => 3A
    parameter [8:0] KEY_CODES_N = 9'h031; // N => 31
    parameter [8:0] KEY_CODES_O = 9'h044; // O => 44
    parameter [8:0] KEY_CODES_P = 9'h04D; // P => 4D
    parameter [8:0] KEY_CODES_Q = 9'h015; // Q => 15
    parameter [8:0] KEY_CODES_R = 9'h02D; // R => 2D
    parameter [8:0] KEY_CODES_S = 9'h01B; // S => 1B
    parameter [8:0] KEY_CODES_T = 9'h02C; // T => 2C
    parameter [8:0] KEY_CODES_U = 9'h03C; // U => 3C
    parameter [8:0] KEY_CODES_V = 9'h02A; // V => 2A
    parameter [8:0] KEY_CODES_W = 9'h01D; // W => 1D
    parameter [8:0] KEY_CODES_X = 9'h022; // X => 22
    parameter [8:0] KEY_CODES_Y = 9'h035; // Y => 35
    parameter [8:0] KEY_CODES_Z = 9'h01A; // Z => 1A

    
    reg [7:0] prev_ascii, next_prev_ascii;
    reg [7:0] ascii, next_ascii;
    reg [9:0] last_key;
    
    wire shift_down;
    wire [511:0] key_down;
    wire [8:0] last_change;
    
    assign shift_down = (key_down[LEFT_SHIFT_CODES] == 1'b1 || key_down[RIGHT_SHIFT_CODES] == 1'b1) ? 1'b1 : 1'b0;
    
    SevenSegment seven_seg (
        .display(display),
        .ascii1(prev_ascii),
        .ascii2(ascii),
        .rst(rst),
        .clk(clk)
    );
        
    KeyboardDecoder key_de (
        .key_down(key_down),
        .last_change(last_change),
        .key_valid(been_ready),
        .PS2_DATA(PS2_DATA),
        .PS2_CLK(PS2_CLK),
        .rst(rst),
        .clk(clk)
    );

    always @ (posedge clk, posedge rst) begin
        if (rst) begin
            ascii <= 8'h00;
            prev_ascii <= 8'h00;
        end 
        else begin
            ascii <= next_ascii;
            if(next_ascii != ascii) begin
                prev_ascii <= ascii;
            end
            else begin
                prev_ascii <= prev_ascii;
            end
        end
    end


    always @ (*) begin
        if(key_down[last_change] == 1'b1) begin
            case (last_change)
                KEY_CODES_00: next_ascii = shift_down ? 8'h29 : 8'h30;
                KEY_CODES_01: next_ascii = shift_down ? 8'h21 : 8'h31;
                KEY_CODES_02: next_ascii = shift_down ? 8'h40 : 8'h32;
                KEY_CODES_03: next_ascii = shift_down ? 8'h23 : 8'h33;
                KEY_CODES_04: next_ascii = shift_down ? 8'h24 : 8'h34;
                KEY_CODES_05: next_ascii = shift_down ? 8'h25 : 8'h35;
                KEY_CODES_06: next_ascii = shift_down ? 8'h5E : 8'h36;
                KEY_CODES_07: next_ascii = shift_down ? 8'h26 : 8'h37;
                KEY_CODES_08: next_ascii = shift_down ? 8'h2A : 8'h38;
                KEY_CODES_09: next_ascii = shift_down ? 8'h28 : 8'h39;
                KEY_CODES_10: next_ascii = shift_down ? 8'h5F : 8'h30;
                KEY_CODES_11: next_ascii = shift_down ? 8'h2B : 8'h31;
                KEY_CODES_12: next_ascii = shift_down ? 8'h3A : 8'h32;
                KEY_CODES_13: next_ascii = shift_down ? 8'h2A : 8'h33;
                KEY_CODES_14: next_ascii = shift_down ? 8'h3C : 8'h34;
                KEY_CODES_15: next_ascii = shift_down ? 8'h3E : 8'h35;
                KEY_CODES_16: next_ascii = shift_down ? 8'h3F : 8'h36;
                KEY_CODES_17: next_ascii = shift_down ? 8'h2D : 8'h37;
                KEY_CODES_18: next_ascii = shift_down ? 8'h3D : 8'h38;
                KEY_CODES_19: next_ascii = shift_down ? 8'h5F : 8'h39;
                KEY_CODES_A : next_ascii = shift_down ? 8'h41 : 8'h61;
                KEY_CODES_B : next_ascii = shift_down ? 8'h42 : 8'h62;
                KEY_CODES_C : next_ascii = shift_down ? 8'h43 : 8'h63;
                KEY_CODES_D : next_ascii = shift_down ? 8'h44 : 8'h64;
                KEY_CODES_E : next_ascii = shift_down ? 8'h45 : 8'h65;
                KEY_CODES_F : next_ascii = shift_down ? 8'h46 : 8'h66;
                KEY_CODES_G : next_ascii = shift_down ? 8'h47 : 8'h67;
                KEY_CODES_H : next_ascii = shift_down ? 8'h48 : 8'h68;
                KEY_CODES_I : next_ascii = shift_down ? 8'h49 : 8'h69;
                KEY_CODES_J : next_ascii = shift_down ? 8'h4A : 8'h6A;
                KEY_CODES_K : next_ascii = shift_down ? 8'h4B : 8'h6B;
                KEY_CODES_L : next_ascii = shift_down ? 8'h4C : 8'h6C;
                KEY_CODES_M : next_ascii = shift_down ? 8'h4D : 8'h6D;
                KEY_CODES_N : next_ascii = shift_down ? 8'h4E : 8'h6E;
                KEY_CODES_O : next_ascii = shift_down ? 8'h4F : 8'h6F;
                KEY_CODES_P : next_ascii = shift_down ? 8'h50 : 8'h70;
                KEY_CODES_Q : next_ascii = shift_down ? 8'h51 : 8'h71;
                KEY_CODES_R : next_ascii = shift_down ? 8'h52 : 8'h72;
                KEY_CODES_S : next_ascii = shift_down ? 8'h53 : 8'h73;
                KEY_CODES_T : next_ascii = shift_down ? 8'h54 : 8'h74;
                KEY_CODES_U : next_ascii = shift_down ? 8'h55 : 8'h75;
                KEY_CODES_V : next_ascii = shift_down ? 8'h56 : 8'h76;
                KEY_CODES_W : next_ascii = shift_down ? 8'h57 : 8'h77;
                KEY_CODES_X : next_ascii = shift_down ? 8'h58 : 8'h78;
                KEY_CODES_Y : next_ascii = shift_down ? 8'h59 : 8'h79;
                KEY_CODES_Z : next_ascii = shift_down ? 8'h5A : 8'h7A;
                default      : next_ascii = ascii;
            endcase
        end 
        else ascii = ascii;
    end
    
endmodule
