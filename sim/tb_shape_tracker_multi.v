`timescale 1ns/1ps
module tb_shape_tracker_multi;
    reg clk=0,rst_n=0,fd=0;
    reg [4:0] rv;
    reg [1:0] rcl[0:4];
    reg [10:0] rx0[0:4],ry0[0:4],rx1[0:4],ry1[0:4];
    wire [4:0] ov;
    wire [3:0] oc;
    wire [1:0] ocl[0:4];
    wire [10:0] ox0[0:4],oy0[0:4],ox1[0:4],oy1[0:4];
    integer k;
    always #5 clk=~clk;
    shape_tracker dut(.clk(clk),.rst_n(rst_n),.frame_done(fd),
        .raw_valid(rv),.raw_class(rcl),
        .raw_x0(rx0),.raw_y0(ry0),.raw_x1(rx1),.raw_y1(ry1),
        .out_valid(ov),.out_count(oc),.out_class(ocl),
        .out_x0(ox0),.out_y0(oy0),.out_x1(ox1),.out_y1(oy1));
    task pulse_frame; begin @(negedge clk);fd=1; @(negedge clk);fd=0; repeat(70) @(negedge clk); end endtask
    initial begin
        rv=5'b11111; rcl[0]=1; rcl[1]=2; rcl[2]=3; rcl[3]=1; rcl[4]=3;
        rx0[0]=100; ry0[0]=100; rx1[0]=220; ry1[0]=220;
        rx0[1]=400; ry0[1]=100; rx1[1]=540; ry1[1]=240;
        rx0[2]=700; ry0[2]=100; rx1[2]=850; ry1[2]=260;
        rx0[3]=100; ry0[3]=500; rx1[3]=260; ry1[3]=660;
        rx0[4]=500; ry0[4]=500; rx1[4]=680; ry1[4]=680;
        #20 rst_n=1; pulse_frame; pulse_frame;
        if(oc!=5) $fatal(1,"expected five tracked outputs, got %0d",oc);
        for(k=0;k<5;k=k+1) if(!ov[k]) $fatal(1,"track %0d missing",k);
        $display("PASS shape tracker handles five simultaneous targets");
        $finish;
    end
endmodule
