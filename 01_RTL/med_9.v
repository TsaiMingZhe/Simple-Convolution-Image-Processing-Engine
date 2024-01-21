module med_9 (
    input clk,
    input rst_n,
    input filter_valid,
    input [13:0] i_data,
    input [3:0]  i_count,
    output[13:0] o_data,
    output       o_valid
);
    reg         filter_valid_r, o_valid_r;
    reg [3:0]   count_r;
    reg [13:0]  data[2:0], o_data_r;
    wire[41:0]  sort_1, sort_2;
    reg [41:0]  reg1, reg2, reg3, o_c2_r;
    wire[13:0]  max_1, med_1, min_1, o_cmax[2:0], o_cmed[2:0], o_cmin[2:0], o_c3[2:0];
    reg [1:0]   state, next_state;
    localparam load = 2'd0;
    localparam compare2 = 2'd1;
    localparam compare3 = 2'd2;
    localparam endding = 2'd3;
    assign sort_1 = {max_1, med_1, min_1};
    assign sort_2 = {o_cmax[2], o_cmed[1], o_cmin[0]};
    assign o_data = o_data_r;
    assign o_valid = o_valid_r;
    comp3 c1(.i_a(data[0]), .i_b(data[1]), .i_c(data[2]), .o_max(max_1), .o_med(med_1), .o_min(min_1));
    comp3 cmax(.i_a(reg1[41:28]), .i_b(reg2[41:28]), .i_c(reg3[41:28]), .o_max(o_cmax[0]), .o_med(o_cmax[1]), .o_min(o_cmax[2]));
    comp3 cmed(.i_a(reg1[27:14]), .i_b(reg2[27:14]), .i_c(reg3[27:14]), .o_max(o_cmed[0]), .o_med(o_cmed[1]), .o_min(o_cmed[2]));
    comp3 cmin(.i_a(reg1[13:0]), .i_b(reg2[13:0]), .i_c(reg3[13:0]), .o_max(o_cmin[0]), .o_med(o_cmin[1]), .o_min(o_cmin[2]));
    comp3 c3(.i_a(o_c2_r[41:28]), .i_b(o_c2_r[27:14]), .i_c(o_c2_r[13:0]), .o_max(o_c3[0]), .o_med(o_c3[1]), .o_min(o_c3[2]));
    always @(*) begin//state
        case (state)
            load : next_state = (filter_valid_r) ? compare2 : load; //load data and first sort (each 3 datas)
            compare2 : next_state = compare3;                       //creat 3 new group {max[G1,G2,G3]} , {med[..]}, {min[..]}
            compare3 : next_state = endding;                        //compare the {max.min}, {med.med}, {min.max}
            endding : next_state = load;                            //output the result
            default : next_state = state;
        endcase
    end
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state <= load;
            count_r <= 0;
            filter_valid_r <= 0;
            data[0] <= 0; data[1] <= 0; data[2] <= 0;
            reg1 <= 0;
            reg2 <= 0;
            reg3 <= 0;
            o_c2_r <= 0;
            o_data_r <= 0;
            o_valid_r <= 0;
        end else begin
            state <= next_state;
            count_r <= i_count;
            filter_valid_r <= filter_valid;
            data[0] <= i_data; data[1] <= data[0]; data[2] <= data[1];
            reg1 <= (count_r == 4'd3) ? sort_1 : reg1;
            reg2 <= (count_r == 4'd6) ? sort_1 : reg2;
            reg3 <= (count_r == 4'd0) ? sort_1 : reg3;
            o_c2_r <= (state == compare2) ? sort_2 : o_c2_r;
            o_data_r <= (state == compare3) ? o_c3[1] : 0;
            o_valid_r <= (state == compare3);
        end
    end
endmodule

module comp3 (
    input  [13:0] i_a,
    input  [13:0] i_b,
    input  [13:0] i_c,
    output [13:0] o_max,
    output [13:0] o_med,
    output [13:0] o_min
    );
    reg [41:0]  sort_1;
    wire[2:0]   comp;
    assign comp = {i_a >= i_b, i_a >= i_c, i_b >= i_c};
    assign {o_max, o_med, o_min} = sort_1;
    always @(*) begin
        case (comp)
            3'b000 : sort_1 = {i_c, i_b, i_a};//CBA
            3'b001 : sort_1 = {i_b, i_c, i_a};//BCA
            3'b011 : sort_1 = {i_b, i_a, i_c};//BAC
            3'b100 : sort_1 = {i_c, i_a, i_b};//CAB
            3'b110 : sort_1 = {i_a, i_c, i_b};//ACB
            3'b111 : sort_1 = {i_a, i_b, i_c};//ABC
            default : sort_1 = {i_a, i_b, i_c};
        endcase
    end
endmodule