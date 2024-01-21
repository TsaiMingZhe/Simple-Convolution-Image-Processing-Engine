`timescale 1ns/1ps
module core (
	input         i_clk,
	input         i_rst_n,
	input         i_op_valid,
	input  [ 3:0] i_op_mode,
    output        o_op_ready,
	input         i_in_valid,
	input  [ 7:0] i_in_data,
	output        o_in_ready,
	output        o_out_valid,
	output [13:0] o_out_data
	);
// output ///////////////////////////////////////////////////////////////////////////////////////////
	reg			o_op_ready_w, o_op_ready_r, o_in_ready_w, o_in_ready_r, o_out_valid_w, o_out_valid_r;
	reg	[13:0]	o_out_data_w, o_out_data_r;
	assign o_op_ready = o_op_ready_r;
	assign o_in_ready = o_in_ready_r;
	assign o_out_data = o_out_data_r;
	assign o_out_valid = o_out_valid_r;
// wire & reg ///////////////////////////////////////////////////////////////////////////////////////
	reg [3:0]	state, next_state;
	reg [5:0]	origin, origin_w, depth, depth_w;
	reg [10:0]	load_cnt, sram_addr;
	reg [7:0]	pixel_cnt;
	wire		filter_valid, filter_flag, eff_bit;
	wire[7:0]	Q_out, pixel_range;
	wire[5:0]	pixel[3:0];
	wire[10:0]	pixel_addr;
	wire[13:0]	reg_in8, reg_in16, reg_in32, o_sum08, o_sum16, o_sum32, depth_sum;
	wire[3:0]	count3x3;
// convolution
	reg [5:0]	reg_addr;
	reg [17:0]	conv_sum, conv_sum_w;
// medium
	wire[13:0] 	o_med, i_eff;
	wire	   	med_valid;
	reg  		eff_bit_r;
// gradient
	reg [3:0]	op_mode_r;
	wire[13:0]	o_grad;
	wire		grad_finish, grad_valid;
// submodule ////////////////////////////////////////////////////////////////////////////////////////
	sram_4096x8 sram(.CLK(i_clk), .CEN(1'b0), .WEN(~i_in_valid), .A({1'b0, sram_addr}), .D(i_in_data), .Q(Q_out));
	Register sum8(.clk(i_clk), .rst_n(i_rst_n), .we(i_in_valid & ~|load_cnt[10:9]), .i_addr(reg_addr), .i_wdata(reg_in8), .o_rdata(o_sum08));
	Register sum16(.clk(i_clk), .rst_n(i_rst_n), .we(i_in_valid & ~load_cnt[10]), .i_addr(reg_addr), .i_wdata(reg_in16), .o_rdata(o_sum16));
	Register sum32(.clk(i_clk), .rst_n(i_rst_n), .we(i_in_valid), .i_addr(reg_addr), .i_wdata(reg_in32), .o_rdata(o_sum32));
	filter3x3 filter(
		.clk(i_clk), .rst_n(i_rst_n), .op_mode(i_op_mode), .count3x3(count3x3), 
		.pixel_0(pixel[0]), .pixel_1(pixel[1]), .pixel_2(pixel[2]), .pixel_3(pixel[3]),
		.o_valid(filter_valid), .pixel_addr(pixel_addr), .finish_flag(filter_flag), .eff_bit(eff_bit));	
	med_9 med9(.clk(i_clk), .rst_n(i_rst_n), .filter_valid(filter_valid), .i_data(i_eff), .i_count(count3x3), .o_data(o_med), .o_valid(med_valid));
	gradient g(.clk(i_clk), .rst_n(i_rst_n), .op_mode(op_mode_r), .filter_valid(filter_valid), .i_data(i_eff), .i_count(count3x3), .o_data(o_grad), .o_valid(grad_valid), .finish_flag(grad_finish));
// other ////////////////////////////////////////////////////////////////////////////////////////////
	assign reg_in8 = o_sum08 + i_in_data;
	assign reg_in16 = o_sum16 + i_in_data;
	assign reg_in32 = o_sum32 + i_in_data;
	assign {pixel[0], pixel[1], pixel[2], pixel[3]} = {origin, origin + 6'd1, origin + 6'd8, origin + 6'd9};
	assign pixel_range = {depth, 2'b00} - 1'b1;
	assign depth_sum = (depth[5]) ? o_sum32 : (depth[4]) ? o_sum16 : o_sum08;
	assign i_eff = (eff_bit_r) ? Q_out : 1'b0;
// convolution (Rounding)  14Q4
	wire[17:0]	div04, div08, div16;
	assign div04 = {2'b0, depth_sum, 2'b0};
	assign div08 = {3'b0, depth_sum, 1'b0};
	assign div16 = {4'b0, depth_sum};

	always @(*) begin //state coltrol
		case (state)
			`init : next_state = `idle;
			`idle : next_state = `ready;
			`ready : next_state = `get_op;
			`get_op : begin
				case (i_op_mode)
					`LOAD : next_state = `loading;
					`DISPLAY : next_state = `display;
					`CONVOLUTION : next_state = `conv;
					`MEDIAN : next_state = `med;
					`GRADIENT : next_state = `grad;
					default : next_state = `idle;
				endcase
			end
			`conv : next_state = (filter_flag) ? `idle : `conv;
			`med : next_state = (filter_flag) ? `latency_med : `med;
			`grad : next_state = (filter_flag) ? `latency_grad : `grad;
			`loading : next_state = (load_cnt == 12'd2047) ? `idle : `loading;
			`display : next_state = (pixel_cnt < pixel_range) ? `display : `latency;
			`latency : next_state = `idle;
			`latency_med : next_state = (med_valid) ? `idle : `latency_med;
			`latency_grad : next_state = (grad_finish) ? `idle : `latency_grad;
			default : next_state = state;
		endcase
	end
	always @(*) begin//shift & scale
		if(state == `get_op)begin
			case (i_op_mode)
				`L_SHIFT : origin_w = (origin[2:0] == 3'b000) ? origin : origin - 6'd1;
				`R_SHIFT : origin_w = (origin[2:0] == 3'b110) ? origin : origin + 6'd1;
				`U_SHIFT : origin_w = (origin[5:3] == 3'b000) ? origin : origin - 6'd8;
				`D_SHIFT : origin_w = (origin[5:3] == 3'b110) ? origin : origin + 6'd8;
				default  : origin_w = origin;
			endcase
			case (i_op_mode)
				`DEPTH_UP 	: depth_w = (depth[5]) ? depth : depth << 1;
				`DEPTH_DOWN : depth_w = (depth[3]) ? depth : depth >> 1;
				default 	: depth_w = depth;
			endcase
		end else begin
			origin_w = origin;
			depth_w = depth;
		end
	end
	always @(*) begin //sram addr & sum reg addr control
		case (state)
			`loading : begin
				sram_addr = {1'b0, load_cnt};
				reg_addr = load_cnt[5:0];
			end
			`display : begin
				sram_addr = {pixel_cnt[6:2], pixel[pixel_cnt[1:0]]};
				reg_addr = 0;
			end
			`conv : begin
				sram_addr = 0;
				reg_addr = pixel_addr[5:0];
			end
			`med : begin
				sram_addr = pixel_addr;
				reg_addr = 0;
			end
			`grad : begin
				sram_addr = pixel_addr;
				reg_addr = 0;
			end
			default : begin
				sram_addr = 0;
				reg_addr = 0;
			end
		endcase
	end
	always @(*) begin //output data & valid
		case (state)
			`display : begin
				if (|pixel_cnt) begin
					o_out_valid_w = 1'b1;
					o_out_data_w = Q_out;
				end else begin
					o_out_valid_w = 1'b0;
					o_out_data_w = 1'b0;
				end
			end
			`latency : begin
				o_out_valid_w = 1'b1;
				o_out_data_w = Q_out;				
			end
			`conv : begin
				o_out_valid_w = filter_valid;
				o_out_data_w = conv_sum[17:4] + conv_sum[3];
			end
			`med : begin
				o_out_valid_w = med_valid;
				o_out_data_w = o_med;
			end
			`latency_med : begin
				o_out_valid_w = med_valid;
				o_out_data_w = o_med;
			end
			`grad : begin
				o_out_valid_w = grad_valid;
				o_out_data_w = o_grad;
			end
			`latency_grad : begin
				o_out_valid_w = grad_valid;
				o_out_data_w = o_grad;				
			end
			default : begin
				o_out_valid_w = 0;
				o_out_data_w = 0;
			end
		endcase
	end
	always @(*) begin //kernel
		if (state == `conv & eff_bit) begin
		case (count3x3)
			4'd0 : conv_sum_w = div16;
			4'd1 : conv_sum_w = conv_sum + div08;
			4'd2 : conv_sum_w = conv_sum + div16;
			4'd3 : conv_sum_w = conv_sum + div08;
			4'd4 : conv_sum_w = conv_sum + div04;
			4'd5 : conv_sum_w = conv_sum + div08;
			4'd6 : conv_sum_w = conv_sum + div16;
			4'd7 : conv_sum_w = conv_sum + div08;
			4'd8 : conv_sum_w = conv_sum + div16;
			default : conv_sum_w = conv_sum;
		endcase			
		end else conv_sum_w = (|count3x3) ? conv_sum : 0;
	end
	always @(posedge i_clk or negedge i_rst_n) begin
		if (~i_rst_n) begin
			state <= `init;
			depth <= 6'd32;
			origin <= 1'b0;
			load_cnt <= 1'b0;
			pixel_cnt <= 1'b0;
			o_op_ready_r <= 1'b0;
			o_in_ready_r <= 1'b0;
			o_out_data_r <= 1'b0;
			o_out_valid_r <= 1'b0;
			conv_sum <= 1'b0;
			eff_bit_r <= 1'b0;
			op_mode_r <= 1'b0;
		end else begin
			state <= next_state;
			depth <= depth_w;
			origin <= origin_w;
			load_cnt <= (state == `loading) ? load_cnt + 1 : load_cnt;
			pixel_cnt <= (state != `display) ? 0 : 
						 (pixel_cnt < pixel_range) ? pixel_cnt + 1 : 0;
			o_op_ready_r <= (state == `idle) ? 1 : 0;
			o_in_ready_r <= (state == `init) ? 1 : o_in_ready_r;
			o_out_data_r <= o_out_data_w;
			o_out_valid_r <= o_out_valid_w;
			conv_sum <= conv_sum_w;
			eff_bit_r <= eff_bit;
			op_mode_r <= (state == `get_op) ? i_op_mode : op_mode_r;
		end
	end
endmodule
