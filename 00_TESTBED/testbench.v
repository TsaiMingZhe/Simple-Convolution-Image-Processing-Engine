`timescale 1ns/1ps
`define CYCLE       4.5     // CLK period.
`define HCYCLE      (`CYCLE/2)
`define MAX_CYCLE   10000000
`define RST_DELAY   2
// Define patten path
    `ifdef tb1
        `define INFILE  "../00_TESTBED/PATTERN/indata1.dat"
        `define OPFILE  "../00_TESTBED/PATTERN/opmode1.dat"
        `define GOLDEN  "../00_TESTBED/PATTERN/golden1.dat"
        `define NUM     80
    `elsif tb2
        `define INFILE  "../00_TESTBED/PATTERN/indata2.dat"
        `define OPFILE  "../00_TESTBED/PATTERN/opmode2.dat"
        `define GOLDEN  "../00_TESTBED/PATTERN/golden2.dat"
        `define NUM     320
    `elsif tb3
        `define INFILE  "../00_TESTBED/PATTERN/indata3.dat"
        `define OPFILE  "../00_TESTBED/PATTERN/opmode3.dat"
        `define GOLDEN  "../00_TESTBED/PATTERN/golden3.dat"
        `define NUM     320
    `elsif tb4
        `define INFILE  "../00_TESTBED/PATTERN/indata4.dat"
        `define OPFILE  "../00_TESTBED/PATTERN/opmode4.dat"
        `define GOLDEN  "../00_TESTBED/PATTERN/golden4.dat"
        `define NUM     708
    `elsif tb0
        `define INFILE "../00_TESTBED/PATTERN/indata0.dat"
        `define OPFILE "../00_TESTBED/PATTERN/opmode0.dat"
        `define GOLDEN "../00_TESTBED/PATTERN/golden0.dat"
        `define NUM     1984
    `else //my test
        `define INFILE "../00_TESTBED/PATTERN/indata_x.dat"
        `define OPFILE "../00_TESTBED/PATTERN/opmode_x.dat"
        `define GOLDEN "../00_TESTBED/PATTERN/golden_x.dat"
        `define NUM     20
    `endif

//`define SDFFILE "../02_SYN/Netlist/core_syn.sdf"  // Modify your sdf file name
    `define SDFFILE "../04_APR/TEST/core_pr.sdf"
module testbed;

    reg         clk, rst_n;
    reg         op_valid;
    reg  [ 3:0] op_mode;
    wire        op_ready;
    reg         in_valid;
    reg  [ 7:0] in_data;
    wire        in_ready;
    wire        out_valid;
    wire [13:0] out_data;

    reg  [ 7:0] indata_mem [0:2047];
    reg  [ 3:0] opmode_mem [0:1023];
    reg  [13:0] golden_mem [0:4095];
    reg  [13:0] in_sum8[63:0], in_sum16[63:0], in_sum32[63:0];
    integer i, j, k, q, a, err;
// For gate-level simulation only
    
    `ifdef SDF
        initial $sdf_annotate(`SDFFILE, u_core);
        initial #1 $display("SDF File %s were used for this simulation.", `SDFFILE);
    `endif
    

core u_core (
	.i_clk       (clk),
	.i_rst_n     (rst_n),
	.i_op_valid  (op_valid),
	.i_op_mode   (op_mode),
    .o_op_ready  (op_ready),
	.i_in_valid  (in_valid),
	.i_in_data   (in_data),
	.o_in_ready  (in_ready),
	.o_out_valid (out_valid),
	.o_out_data  (out_data)
);
// Write out waveform file
    initial begin
    $fsdbDumpfile("core.fsdb");
    $fsdbDumpvars(0, "+mda");
    end
// Read in test pattern and golden pattern
    initial $readmemb(`INFILE, indata_mem);
    initial $readmemb(`OPFILE, opmode_mem);
    initial $readmemb(`GOLDEN, golden_mem);
// Clock generation
    initial clk = 1'b0;
    always begin #(`CYCLE/2) clk = ~clk; end
// Reset generation
    initial begin
        force clk =0;
        rst_n = 1; # (               0.25 * `CYCLE);
        rst_n = 0; # ((`RST_DELAY - 0.25) * `CYCLE);
        rst_n = 1;
        # `CYCLE;
        release clk;
        $display("Reset finish");
	 # (         `MAX_CYCLE * `CYCLE);
        $display("Error! Runtime exceeded!");
        $finish;
    end

//
    initial begin
        i = 0;
        j = 0;
        k = 0;
        err = 0;
        in_data = 0;
        in_valid = 0;
        op_valid = 0;
        op_mode = 0;
        for(q = 0; q < 64;q = q + 1) begin
            in_sum8[q] = 0;
            in_sum16[q] = 0;
            in_sum32[q] = 0;
        end
    end
    always begin //load in_data
        @(negedge clk)
        if (op_ready) begin
            @(negedge clk)
            op_valid = 1;
            op_mode = opmode_mem[i];
            @(negedge clk)
            op_valid = 0;
            op_mode = 0;
            if(op_mode == `LOAD)begin
                while (j < 2048) begin
                    in_valid = 1;
                    in_data = indata_mem[j]; //if(j<64) $display("%d",in_data);
                    in_sum8[j[5:0]] = (j < 512) ? in_sum8[j[5:0]] + indata_mem[j] : in_sum8[j[5:0]];
                    in_sum16[j[5:0]] = (j < 1024) ? in_sum16[j[5:0]] + indata_mem[j] : in_sum16[j[5:0]];
                    in_sum32[j[5:0]] = in_sum32[j[5:0]] + indata_mem[j];
                    j = (in_ready) ? j + 1 : j;
                    @(negedge clk);
                end
                i = i + 1;
                in_valid = 0;
                in_data = 0;
            end
            else i = i + 1;
        end
    end
    reg [5:0] origin[3:0];
    reg [12:0] kernel[3:0];
    integer x;
    always begin
        @(negedge clk)
        if (out_valid) begin
            if (out_data != golden_mem[k]) begin
                $display("No.%d error!!(op=%d), gold=%h , your=%h", k, opmode_mem[i-1], golden_mem[k], out_data);
                err = err + 1;
            end
            k = k + 1;
            if (k == `NUM - 1) begin 
                //$display("%b", $signed({14'h3f4b, 7'b0}) / $signed({14'h3f25}));//test gred (y/x)
                if (err == 0)   $display("~~~~~~~~~~~ALL PASS~~~~~~~~~~~");
                else            $display("check finish, error num:%d",err);
                //for(a=0;a<64;a=a+1) $display("sum[%d] = %h",a, in_sum8[a]);//test summary
                //for(a=0;a<64;a=a+1) $display("sum[%d] = %h",a, in_sum16[a]);//test summary
                //for(a=0;a<64;a=a+1) $display("sum[%d] = %h",a, in_sum32[a]);//test summary
                origin[0] = 6'd9;   origin[1] = origin[0] + 1;  origin[2] = origin[0] + 8;   origin[3] = origin[0] + 9;
                for (x = 0;x < 4;x = x + 1) begin
                    kernel[x] = (in_sum32[origin[x]-9]>>4) + (in_sum32[origin[x]-8]>>3) + (in_sum32[origin[x]-7]>>4) +
                                (in_sum32[origin[x]-1]>>3) + (in_sum32[origin[x]-0]>>2) + (in_sum32[origin[x]+1]>>3) +
                                (in_sum32[origin[x]+7]>>4) + (in_sum32[origin[x]+8]>>3) + (in_sum32[origin[x]+9]>>4) ;
                    //$display("kernel[%d] = %h", x, kernel[x]);                  
                end
                $finish;
            end
        end
    end

endmodule
