`timescale 1ns/1ps
module tb_shape_tracker;
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

    task pulse_frame;
        begin
            @(negedge clk); fd=1;
            @(negedge clk); fd=0; repeat(20) @(negedge clk);
        end
    endtask

    task det(input [1:0] c,input [10:0] a,input [10:0] b,
             input [10:0] d,input [10:0] e);
        begin
            rv=5'b00001; rcl[0]=c;
            rx0[0]=a; ry0[0]=b; rx1[0]=d; ry1[0]=e;
        end
    endtask

    initial begin
        rv=0; fd=0;
        for(k=0;k<5;k=k+1) begin
            rcl[k]=0; rx0[k]=0; ry0[k]=0; rx1[k]=0; ry1[k]=0;
        end
        repeat(4) @(negedge clk); rst_n=1;
        det(2'd3,200,300,500,700); pulse_frame;
        if (ov!=0) $fatal(1,"new detection was not confirmed");
        det(2'd3,200,300,500,700); pulse_frame;
        if ((oc!=1)||(ox0[0]!=200)||(oy0[0]!=300)||(ox1[0]!=500)||(oy1[0]!=700))
            $fatal(1,"confirmed box wrong");

        // One map-cell bbox jitter plus a single-frame class error must not move
        // or relabel the displayed result.
        for(k=0;k<20;k=k+1) begin
            det((k==7)?2'd1:2'd3,
                200+((k%2)*8),300+(((k>>1)%2)*8),
                500-((k%2)*8),700-(((k>>2)%2)*8));
            pulse_frame;
            if ((oc!=1)||(ox0[0]!=200)||(oy0[0]!=300)||
                (ox1[0]!=500)||(oy1[0]!=700)||(ocl[0]!=2'd3))
                $fatal(1,"temporal filter jittered at frame %0d",k);
        end

        // A deliberate move larger than the deadband must update immediately
        // instead of converging to a permanent 20-pixel offset.
        det(2'd3,300,400,600,800); pulse_frame;
        if ((oc!=1)||(ox0[0]!=300)||(oy0[0]!=400)||(ox1[0]!=600)||(oy1[0]!=800))
            $fatal(1,"deliberate target move did not update");
        $display("PASS deliberate target move updates immediately");

        // A persistent class change must be accepted only after ten frame
        // observations. Intermittent classification noise decays the counter.
        for(k=0;k<8;k=k+1) begin
            det(2'd1,300,400,600,800); pulse_frame;
            if (ocl[0]!=2'd3) $fatal(1,"class switched too early at frame %0d",k);
        end
        det(2'd3,300,400,600,800); pulse_frame;
        det(2'd1,300,400,600,800); pulse_frame;
        det(2'd1,300,400,600,800); pulse_frame;
        det(2'd1,300,400,600,800); pulse_frame;
        if (ocl[0]!=2'd1) $fatal(1,"confirmed class change was not accepted");
        $display("PASS class hysteresis accepts persistent change after confirmation");

        for(k=0;k<3;k=k+1) begin
            rv=0; pulse_frame;
            if (oc!=1) $fatal(1,"box was not held through short dropout");
        end
        for(k=0;k<6;k=k+1) begin rv=0; pulse_frame; end
        if (oc!=0) $fatal(1,"expired track still visible");
        $display("PASS shape tracker confirmation, jitter rejection, class hold and dropout hold");
        $finish;
    end
endmodule
