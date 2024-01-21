module Register //modify bit & number
    #(parameter data_bit = 14, parameter reg_num = 64, parameter addr_num = 6)(
    input clk, 
    input rst_n,
    input we,
    input [addr_num-1:0] i_addr,
    input [data_bit-1:0] i_wdata,
    output[data_bit-1:0] o_rdata
    );//Register name(.clk(), .rst_n(), .we(), .i_addr(), .i_wdata(), .o_rdata());
    integer i;
    reg [data_bit-1:0] reg_w[reg_num-1:0], reg_r[reg_num-1:0];
    assign o_rdata = reg_r[i_addr];
    always @(*) begin
        for (i = 0;i < reg_num;i = i + 1) reg_w[i] = (we == 1 & i == i_addr) ? i_wdata : reg_r[i];
    end
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) for (i = 0;i < reg_num;i = i + 1) reg_r[i] <= 0;
        else for (i = 0;i < reg_num;i = i + 1) reg_r[i] <= reg_w[i];
    end
endmodule