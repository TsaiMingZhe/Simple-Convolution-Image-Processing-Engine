module gradient (
    input clk,
    input rst_n,
    input filter_valid,
    input [3:0]  op_mode,
    input [13:0] i_data,
    input [3:0]  i_count,
    output[13:0] o_data,
    output       o_valid,
    output       finish_flag
);
    integer i;
    reg         filter_valid_r, o_valid_r, o_valid_w, flag;
    reg [3:0]   count_r;
    reg [13:0]  o_data_r, o_data_w;
    reg [1:0]   store_cnt;
    reg [2:0]   state, next_state;
    localparam load = 3'd0;
    localparam get_angle = 3'd1;
    localparam store = 3'd2;
    localparam comp0 = 3'd3;
    localparam comp1 = 3'd4;
    localparam comp2 = 3'd5;
    localparam comp3 = 3'd6;
    localparam idle = 3'd7;
    assign o_data = o_data_r;
    assign o_valid = o_valid_r;
    assign finish_flag = flag;
    reg         G_sign;
    wire[13:0]  in_m1_2s, in_m2_2s, in_m2, Gx_abs, Gy_abs;
    reg [20:0]  x_225, x_675;
    reg [20:0]  y;
    reg [13:0]  x_data, y_data, x_sum, y_sum, Gxy, G_w[3:0], G[3:0];
    reg [1:0]   angle, angle_w, A_w[3:0], A[3:0];
    assign in_m2 = i_data << 1;
    assign in_m1_2s = ~i_data + 1'b1;
    assign in_m2_2s = ~in_m2 + 1'b1;
    assign Gx_abs = (x_sum[13]) ? ~x_sum + 1'b1 : x_sum;
    assign Gy_abs = (y_sum[13]) ? ~y_sum + 1'b1 : y_sum;
    always @(*) begin//state
        case (state)
            idle : next_state = (op_mode == `GRADIENT) ? load : idle;
            load : next_state = (filter_valid_r) ? get_angle : load;
            get_angle : next_state = (op_mode == `GRADIENT) ? store : idle;
            store : next_state = (&store_cnt) ? comp0 : load; //store_cnt = 3, ....
            comp0 : next_state = comp1;
            comp1 : next_state = comp2;
            comp2 : next_state = comp3;
            comp3 : next_state = idle;
            default : next_state = state;
        endcase
    end
    always @(*) begin//kernel
        case (count_r)
            4'd0 : begin x_data = in_m1_2s;     y_data = in_m1_2s;  end
            4'd1 : begin x_data = 0;            y_data = in_m2_2s;  end
            4'd2 : begin x_data = i_data;       y_data = in_m1_2s;  end
            4'd3 : begin x_data = in_m2_2s;     y_data = 0;         end
            4'd4 : begin x_data = 0;            y_data = 0;         end
            4'd5 : begin x_data = in_m2;        y_data = 0;         end
            4'd6 : begin x_data = in_m1_2s;     y_data = i_data;    end
            4'd7 : begin x_data = 0;            y_data = in_m2;     end
            4'd8 : begin x_data = i_data;       y_data = i_data;    end
            default : begin x_data = 0;         y_data = 0;         end
        endcase
    end
    always @(*) begin//arctan, get angle
        if (state == get_angle) begin
            if (G_sign)
                angle_w = (y < x_225) ? `angle0 : (y > x_675) ? `angle90 : `angle135;
            else
                angle_w = (y < x_225) ? `angle0 : (y > x_675) ? `angle90 : `angle45;
        end else angle_w = angle;
    end
    always @(*) begin//store {G[3:0],angle[3:0]}
        if (state == store) begin
            for (i = 0;i < 4;i = i + 1) begin
                G_w[i] = (i == store_cnt) ? Gxy : G[i];
                A_w[i] = (i == store_cnt) ? angle : A[i];
            end
        end else begin
            for (i = 0;i < 4;i = i + 1) begin
                G_w[i] = G[i];
                A_w[i] = A[i];
            end
        end
    end
    always @(*) begin//compare
        case (state)
            comp0 : begin//G0 compare
                o_valid_w = 1;
                case (A[0])
                    `angle0   : o_data_w = (G[0] < G[1]) ? 0 : G[0];
                    `angle45  : o_data_w = (G[0] < G[3]) ? 0 : G[0];
                    `angle90  : o_data_w = (G[0] < G[2]) ? 0 : G[0];
                    default   : o_data_w = G[0];
                endcase
            end
            comp1 : begin//G1 compare
                o_valid_w = 1;
                case (A[1])
                    `angle0   : o_data_w = (G[1] < G[0]) ? 0 : G[1];
                    `angle90  : o_data_w = (G[1] < G[3]) ? 0 : G[1];
                    `angle135 : o_data_w = (G[1] < G[2]) ? 0 : G[1];
                    default   : o_data_w = G[1];
                endcase                
            end
            comp2 : begin//G2 compare
                o_valid_w = 1;
                case (A[2])
                    `angle0   : o_data_w = (G[2] < G[3]) ? 0 : G[2];
                    `angle90  : o_data_w = (G[2] < G[0]) ? 0 : G[2];
                    `angle135 : o_data_w = (G[2] < G[1]) ? 0 : G[2];
                    default   : o_data_w = G[2];
                endcase                
            end
            comp3 : begin//G3 compare
                o_valid_w = 1;
                case (A[3])
                    `angle0   : o_data_w = (G[3] < G[2]) ? 0 : G[3];
                    `angle45  : o_data_w = (G[3] < G[0]) ? 0 : G[3];
                    `angle90  : o_data_w = (G[3] < G[1]) ? 0 : G[3];
                    default   : o_data_w = G[3];
                endcase                
            end
            default : begin
                o_valid_w = 0;
                o_data_w = 0;
            end
        endcase
    end
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state <= idle;
            count_r <= 0;
            filter_valid_r <= 0;
            x_sum <= 0;  
            y_sum <= 0;
            Gxy <= 0;
            o_data_r <= 0;
            o_valid_r <= 0;
            angle <= 0;
            store_cnt <= 0;
            for (i = 0;i < 4;i = i + 1) begin
                G[i] <= 0;  A[i] <= 0;
            end
            flag <= 0;
            G_sign <= 0;
            x_225 <= 0;
            x_675 <= 0;
            y <= 0;
        end else begin
            state <= next_state;
            count_r <= i_count;
            filter_valid_r <= filter_valid;
            x_sum <= (filter_valid_r) ? x_data : x_sum + x_data;    
            y_sum <= (filter_valid_r) ? y_data : y_sum + y_data;
            Gxy <= (filter_valid_r) ? Gx_abs + Gy_abs : Gxy;
            o_data_r <= o_data_w;
            o_valid_r <= o_valid_w;
            angle <= angle_w;
            store_cnt <= (state == store) ? store_cnt + 1 : store_cnt;
            for (i = 0;i < 4;i = i + 1) begin
                G[i] <= G_w[i];  A[i] <= A_w[i];
            end
            flag <= (state == comp3);
            G_sign <= (filter_valid_r) ? x_sum[13] ^ y_sum[13] : G_sign;
            x_225 <= (filter_valid_r) ? Gx_abs * `tan_225 : x_225;
            x_675 <= (filter_valid_r) ? Gx_abs * `tan_675 : x_675;
            y <= (filter_valid_r) ? {Gy_abs, 7'b0} : y;
        end
    end 
endmodule