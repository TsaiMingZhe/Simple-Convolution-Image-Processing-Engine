module filter3x3 (
    input clk,
    input rst_n,
    input [3:0] op_mode,
    input [5:0] pixel_0,
    input [5:0] pixel_1,
    input [5:0] pixel_2,
    input [5:0] pixel_3,
    output      o_valid,
    output      eff_bit,
    output[10:0]pixel_addr,
    output[3:0] count3x3,
    output      finish_flag
);  
    localparam idle = 3'd0;
    localparam set_addr_1 = 3'd1;
    localparam set_addr_2 = 3'd2;
    localparam set_addr_3 = 3'd3;
    localparam set_addr_4 = 3'd4;
    localparam process_end= 3'd5;
    reg [2:0]   state, next_state;
    reg [3:0]   count, o_count;
    reg [5:0]   origin;
    wire[5:0]   addr[8:0];
// output
    reg         eff_bit_w, eff_bit_r, o_valid_r, flag;
    reg [10:0]  pixel_addr_w, pixel_addr_r;
    reg [1:0]   count4__w, count4;  //for median top4 depth scan
    assign o_valid = o_valid_r;
    assign pixel_addr = pixel_addr_r;
    assign count3x3 = o_count;
    assign finish_flag = flag;
    assign eff_bit = eff_bit_r;
// effective bits
    wire[8:0]   eff;
    assign eff[0] = (|origin[5:3]) & (|origin[2:0]);    //000xxx or xxx000
    assign eff[1] = |origin[5:3];
    assign eff[2] = (|origin[5:3]) & (~&origin[2:0]);   //000xxx or xxx111
    assign eff[3] = |origin[2:0];
    assign eff[4] = 1'b1;
    assign eff[5] = ~&origin[2:0];
    assign eff[6] = (~&origin[5:3]) & (|origin[2:0]);   //111xxx or xxx000
    assign eff[7] = ~&origin[5:3];
    assign eff[8] = (~&origin[5:3]) & (~&origin[2:0]);  //111xxx or xxx111
// 9 address
    assign addr[0] = origin - 6'd9;
    assign addr[1] = origin - 6'd8;
    assign addr[2] = origin - 6'd7;
    assign addr[3] = origin - 6'd1;
    assign addr[4] = origin;
    assign addr[5] = origin + 6'd1;
    assign addr[6] = origin + 6'd7;
    assign addr[7] = origin + 6'd8;
    assign addr[8] = origin + 6'd9;
//
    always @(*) begin
        case (state)
            idle : begin
                next_state = (op_mode[3]) ? set_addr_1 : idle;
                origin = 0;
                pixel_addr_w = 0;
                eff_bit_w = 0;
                count4__w = (|op_mode[1:0]) ? 2'd0 : 2'd3;
            end
            set_addr_1 : begin
                next_state = (count[3]) ? set_addr_2 : set_addr_1;
                origin = pixel_0;
                pixel_addr_w = {count4, addr[count]};
                eff_bit_w = eff[count];
                count4__w = count4;
            end
            set_addr_2 : begin
                next_state = (count[3]) ? set_addr_3 : set_addr_2;
                origin = pixel_1;
                pixel_addr_w = {count4, addr[count]};
                eff_bit_w = eff[count];
                count4__w = count4;
            end
            set_addr_3 : begin
                next_state = (count[3]) ? set_addr_4 : set_addr_3;
                origin = pixel_2;
                pixel_addr_w = {count4, addr[count]};
                eff_bit_w = eff[count];
                count4__w = count4;
            end
            set_addr_4 : begin
                next_state = (count[3]) ? (count4 == 2'd3) ? process_end : set_addr_1 : set_addr_4;
                origin = pixel_3;
                pixel_addr_w = {count4, addr[count]};
                eff_bit_w = eff[count];
                count4__w = (count[3]) ? count4 + 1 : count4;
            end
            process_end : begin
                next_state = idle;
                origin = 0;
                pixel_addr_w = 0;
                eff_bit_w = 0;
                count4__w = count4;           
            end
            default : begin
                next_state = state;
                origin = 0;
                pixel_addr_w = pixel_addr_r;
                eff_bit_w = o_valid_r;
                count4__w = count4;
            end
        endcase
    end
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state <= idle;
            pixel_addr_r <= 0;
            o_valid_r <= 0;
            eff_bit_r <= 0;
            count <= 0;
            o_count <= 0;
            flag <= 0;
            // median
            count4 <= 0;
        end else begin
            state <= next_state;
            pixel_addr_r <= pixel_addr_w;
            o_valid_r <= o_count[3];
            eff_bit_r <= eff_bit_w;
            count <= (state == idle) ? 0 : 
                     (count[3]) ? 0 : count + 1;
            o_count <= count;
            flag <= (state == process_end);
            // median
            count4 <= count4__w;
        end
    end
endmodule