// opcode definition
`define LOAD        0
`define R_SHIFT     1
`define L_SHIFT     2
`define U_SHIFT     3
`define D_SHIFT     4
`define DEPTH_DOWN  5
`define DEPTH_UP    6
`define DISPLAY     7
`define CONVOLUTION 8
`define MEDIAN      9
`define GRADIENT    10

// FSM states
`define init        0
`define idle        1
`define ready       2
`define get_op      3
`define loading     4
`define display     5
`define latency     6
`define conv        7
`define med         8
`define latency_med 9
`define grad        10
`define latency_grad 11

// tangent approx. value
`define tan_225     14'b0000000_0110101//+0.414
`define tan_675     14'b0000010_0110101//+2.414
`define tan_1125    14'b1111101_1001011//-2.414
`define tan_1575    14'b1111111_1001011//-0.414
// angle
`define angle0          0
`define angle45         1
`define angle90         2
`define angle135        3
