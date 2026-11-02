`timescale 1ns/1ps
module tb_median3x3;
    reg clk = 0;
    always #3.5 clk = ~clk;
    reg rst_n = 0, in_valid = 0;
    reg [7:0] p00,p01,p02,p10,p11,p12,p20,p21,p22;
    reg [10:0] in_x=0,in_y=0;
    reg in_ls=0,in_le=0;
    wire out_valid,out_ls,out_le;
    wire [7:0] out_gray;
    wire [10:0] out_x,out_y;
    reg [7:0] v[0:8];
    integer i,j,k,fail_cnt,checks;
    reg [7:0] want,tmp;

    median3x3 dut (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid),
        .p00(p00),.p01(p01),.p02(p02),.p10(p10),.p11(p11),.p12(p12),
        .p20(p20),.p21(p21),.p22(p22),.in_x(in_x),.in_y(in_y),
        .in_line_start(in_ls),.in_line_end(in_le),
        .out_valid(out_valid),.out_gray(out_gray),.out_x(out_x),.out_y(out_y),
        .out_line_start(out_ls),.out_line_end(out_le)
    );

    task run_case(input [7:0] a0,a1,a2,a3,a4,a5,a6,a7,a8);
        begin
            v[0]=a0;v[1]=a1;v[2]=a2;v[3]=a3;v[4]=a4;v[5]=a5;v[6]=a6;v[7]=a7;v[8]=a8;
            for (i=0;i<9;i=i+1)
                for (j=0;j<8-i;j=j+1)
                    if (v[j] > v[j+1]) begin tmp=v[j]; v[j]=v[j+1]; v[j+1]=tmp; end
            want=v[4];
            @(negedge clk); in_valid=1; in_ls=1;
            p00=a0;p01=a1;p02=a2;p10=a3;p11=a4;p12=a5;p20=a6;p21=a7;p22=a8;
            @(negedge clk); in_valid=0; in_ls=0;
            k=0;
            while (!out_valid && k<8) begin @(negedge clk); k=k+1; end
            checks=checks+1;
            if (out_gray!==want) begin
                fail_cnt=fail_cnt+1;
                $display("FAIL median got=%0d want=%0d",out_gray,want);
            end
            repeat(2) @(negedge clk);
        end
    endtask

    initial begin
        fail_cnt=0; checks=0;
        repeat(6) @(negedge clk); rst_n=1; repeat(4) @(negedge clk);
        run_case(1,2,3,4,5,6,7,8,9);
        run_case(9,1,8,2,7,3,6,4,5);
        run_case(0,255,0,255,0,255,0,255,0);
        run_case(255,255,255,255,1,255,255,255,255);
        run_case(0,0,0,0,254,0,0,0,0);
        run_case(17,250,3,99,42,128,7,201,64);
        if (fail_cnt==0) $display("RESULT : PASS (%0d median checks)",checks);
        else $display("RESULT : FAIL (%0d failures)",fail_cnt);
        $finish;
    end
endmodule
