`timescale 1ns/1ps
// Integration/regression test for the Canny edge_detect_1ppc replacement.
// A small 128x64 frame is sufficient to exercise every 3x3/5x5 line buffer.
module tb_edge_canny_integration;
    localparam integer W = 128;
    localparam integer H = 64;
    localparam integer NL = 36;
    localparam integer HB = 64;
    localparam integer VB = 6000;
    localparam integer FRAMES = 5;
    localparam integer MAXCAP = FRAMES * NL * W;

    reg clk = 1'b0;
    always #3.5 clk = ~clk;
    reg rst_n = 1'b0;
    reg [2:0] mode = 0;
    reg [10:0] threshold = 11'd96;
    reg in_de = 0, in_hs = 0, in_vs = 0;
    reg [7:0] in_r = 0, in_g = 0, in_b = 0;
    integer cur_frame = 0, cur_line = 0, out_slot = 0;
    reg out_de_d = 0;

    wire out_de, out_hs, out_vs;
    wire [7:0] out_r, out_g, out_b;
    edge_detect_1ppc #(.IMAGE_WIDTH(W), .IMAGE_HEIGHT(H)) dut (
        .clk(clk), .rst_n(rst_n),
        .mode_sel(mode), .threshold(threshold), .selftest(1'b0),
        .in_de(in_de), .in_hs(in_hs), .in_vs(in_vs),
        .in_r(in_r), .in_g(in_g), .in_b(in_b),
        .out_de(out_de), .out_hs(out_hs), .out_vs(out_vs),
        .out_r(out_r), .out_g(out_g), .out_b(out_b),
        .dbg_edge_valid(), .dbg_shape_count()
    );

    reg [23:0] cap [0:MAXCAP-1];
    reg        cap_edge [0:MAXCAP-1];
    integer cap_target;
    integer fail_cnt = 0, checks = 0;
    integer dy_min = 999, dy_max = -999, dy;

    function [7:0] src(input integer y, input integer x);
        reg [7:0] v;
        begin
            v = (x < 32) ? 8'd40 : 8'd200;
            if (y >= 16) v = v + 8'd70;
            if (x >= 90 && y >= 8 && y <= 22) v = 8'd240;
            src = v;
        end
    endfunction

    always @(negedge clk) begin
        #1;
        if (out_de) begin
            if (!out_de_d) out_slot = 0;
            if (cur_frame < FRAMES && cur_line < NL && out_slot < W) begin
                cap_target = (cur_frame*NL + cur_line)*W + out_slot;
                cap[cap_target] = {out_r,out_g,out_b};
                cap_edge[cap_target] = dut.edge_paint_q;
            end
            out_slot = out_slot + 1;
            if (dut.edge_valid) begin
                dy = cur_line - dut.edge_y;
                if (dy < dy_min) dy_min = dy;
                if (dy > dy_max) dy_max = dy;
            end
        end
        out_de_d = out_de;
    end

    task drive_frame(input integer f, input [1:0] m);
        integer y, x;
        begin
            @(negedge clk); in_vs = 1;
            repeat (16) @(negedge clk);
            cur_frame = f; mode = m;
            repeat (VB-16) @(negedge clk);
            @(negedge clk); in_vs = 0;
            for (y=0; y<NL; y=y+1) begin
                cur_line = y;
                for (x=0; x<W; x=x+1) begin
                    @(negedge clk);
                    in_de=1; in_hs=1;
                    in_r=src(y,x); in_g=in_r; in_b=in_r;
                end
                for (x=0; x<HB; x=x+1) begin
                    @(negedge clk); in_de=0; in_hs=0;
                end
            end
        end
    endtask

    integer f,y,x,base,edge_count,source_errors,shape_errors;
    reg red_exp;
    reg [23:0] exp_p;
    initial begin
        repeat(10) @(negedge clk); rst_n=1;
        repeat(10) @(negedge clk);
        drive_frame(0,2'd0); // bypass
        drive_frame(1,2'd1); // full binary edge
        drive_frame(2,2'd2); // split
        drive_frame(3,2'd3); // colour edge
        drive_frame(4,2'd1); // stability replay
        repeat(40) @(negedge clk);

        // Frame 0: source directly from debayer on the same five-line delay.
        source_errors=0;
        for (y=0;y<NL;y=y+1) for (x=0;x<W;x=x+1) begin
            base=(0*NL+y)*W+x;
            exp_p = (y<5) ? 24'h000000 : {src(y-5,x),src(y-5,x),src(y-5,x)};
            if (cap[base]!==exp_p) source_errors=source_errors+1;
        end
        checks=checks+1;
        if (source_errors!=0) begin fail_cnt=fail_cnt+1; $display("FAIL source mismatches=%0d",source_errors); end
        else $display("PASS source and five-line alignment");

        // Frame 1: every output channel must come from the same edge flag.
        shape_errors=0;
        for (y=8;y<NL;y=y+1) for (x=0;x<W;x=x+1) begin
            base=(1*NL+y)*W+x;
            exp_p = cap_edge[base] ? 24'hFFFFFF : 24'h000000;
            if (cap[base]!==exp_p) shape_errors=shape_errors+1;
        end
        checks=checks+1;
        if (shape_errors!=0) begin fail_cnt=fail_cnt+1; $display("FAIL full-edge pixel mismatches=%0d",shape_errors); end
        else $display("PASS full-screen binary edge exact");

        // Frames 1/2/3: processed data must be four lines behind live input.
        for (f=1;f<=3;f=f+1) begin
            shape_errors=0; edge_count=0;
            for (y=4;y<NL;y=y+1) for (x=8;x<W-4;x=x+1) begin
                base=(f*NL+y)*W+x;
                if (cap_edge[base]!==1'b0 && cap_edge[base]!==1'b1) shape_errors=shape_errors+1;
                if (cap_edge[base]) edge_count=edge_count+1;
            end
            checks=checks+1;
            if (edge_count<20 || shape_errors!=0) begin
                fail_cnt=fail_cnt+1;
                $display("FAIL frame%0d edge coverage=%0d unknown=%0d",f,edge_count,shape_errors);
            end else $display("PASS frame%0d Canny edge coverage=%0d",f,edge_count);
        end

        // Frame 2 left half must be the unfiltered colour source, line y-5.
        source_errors=0;
        for (y=8;y<NL;y=y+1) for (x=8;x<W/2;x=x+1) begin
            base=(2*NL+y)*W+x;
            exp_p={src(y-5,x),src(y-5,x),src(y-5,x)};
            if (cap[base]!==exp_p) source_errors=source_errors+1;
        end
        checks=checks+1;
        if (source_errors!=0) begin fail_cnt=fail_cnt+1; $display("FAIL split source mismatches=%0d",source_errors); end
        else $display("PASS split source is unfiltered and five-line delayed");

        // Frame 2 right half must be the same binary edge stream as mode 1.
        shape_errors=0;
        for (y=8;y<NL;y=y+1) for (x=W/2;x<W;x=x+1) begin
            base=(2*NL+y)*W+x;
            exp_p = cap_edge[base] ? 24'hFFFFFF : 24'h000000;
            if (cap[base]!==exp_p) shape_errors=shape_errors+1;
        end
        checks=checks+1;
        if (shape_errors!=0) begin fail_cnt=fail_cnt+1; $display("FAIL split edge mismatches=%0d",shape_errors); end
        else $display("PASS split right half binary edge exact");

        // Frame 3: pure-red edge over the unfiltered original picture.
        shape_errors=0; edge_count=0;
        for (y=8;y<NL;y=y+1) for (x=8;x<W-4;x=x+1) begin
            base=(3*NL+y)*W+x;
            red_exp = cap_edge[base] ||
                      ((x>0) && cap_edge[base-1]) ||
                      ((x>1) && cap_edge[base-2]);
            if (red_exp) begin
                edge_count=edge_count+1;
                if (cap[base]!==24'hFF0000) shape_errors=shape_errors+1;
            end else begin
                exp_p={src(y-5,x),src(y-5,x),src(y-5,x)};
                if (cap[base]!==exp_p) shape_errors=shape_errors+1;
            end
        end
        checks=checks+1;
        if (edge_count<20 || shape_errors!=0) begin
            fail_cnt=fail_cnt+1;
            $display("FAIL red-overlay coverage=%0d errors=%0d",edge_count,shape_errors);
        end else $display("PASS red edge overlay coverage=%0d",edge_count);

        // A one-pixel source edge must occupy three adjacent red pixels.
        shape_errors=0;
        for (y=20;y<30;y=y+1) begin
            base=(3*NL+y)*W;
            edge_count=0;
            for (x=0;x<W;x=x+1) begin
                if (cap[base+x]===24'hFF0000) edge_count=edge_count+1;
                else begin
                    if (edge_count>shape_errors) shape_errors=edge_count;
                    edge_count=0;
                end
            end
            if (edge_count>shape_errors) shape_errors=edge_count;
        end
        checks=checks+1;
        if (shape_errors<3) begin fail_cnt=fail_cnt+1; $display("FAIL red line maximum run=%0d",shape_errors); end
        else $display("PASS red line width is 3 pixels");

        // Replayed edge frame must match frame 1 sample for sample.
        shape_errors=0;
        for (y=4;y<NL;y=y+1) for (x=0;x<W;x=x+1) begin
            if (cap[(1*NL+y)*W+x]!==cap[(4*NL+y)*W+x]) shape_errors=shape_errors+1;
        end
        checks=checks+1;
        if (shape_errors!=0) begin fail_cnt=fail_cnt+1; $display("FAIL cross-frame instability=%0d",shape_errors); end
        else $display("PASS cross-frame edge output stable");

        $display("INFO live-input-line minus Canny-line: min=%0d max=%0d",dy_min,dy_max);
        checks=checks+1;
        if (dy_min!=5 || dy_max!=5) begin
            fail_cnt=fail_cnt+1; $display("FAIL expected five-line Canny latency");
        end else $display("PASS five-line Canny latency");

        if (fail_cnt==0) $display("RESULT : PASS (%0d integration checks)",checks);
        else $display("RESULT : FAIL (%0d failures)",fail_cnt);
        $finish;
    end
endmodule
