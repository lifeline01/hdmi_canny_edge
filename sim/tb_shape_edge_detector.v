`timescale 1ns/1ps
module tb_shape_edge_detector;
    localparam integer W=960,H=540;
    reg clk=0,rst_n=0,valid=0,edge_sig=0;
    reg [10:0] ix=0; reg [10:0] iy=0;
    wire [4:0] rv; wire [3:0] rc; wire [1:0] cls[0:4];
    wire [10:0] x0[0:4],y0[0:4],x1[0:4],y1[0:4];
    wire done;
    integer x,y,k;
    always #5 clk=~clk;
    function integer d2seg(input integer px,input integer py,input integer ax,input integer ay,input integer bx,input integer by);
        integer vx,vy,wx,wy,den,dot,qx,qy,dx,dy;
        begin
            vx=bx-ax; vy=by-ay; wx=px-ax; wy=py-ay;
            den=vx*vx+vy*vy; if(den==0) den=1;
            dot=vx*wx+vy*wy;
            if(dot<0) begin qx=ax; qy=ay; end
            else if(dot>den) begin qx=bx; qy=by; end
            else begin qx=ax+(vx*dot)/den; qy=ay+(vy*dot)/den; end
            dx=px-qx; dy=py-qy; d2seg=dx*dx+dy*dy;
        end
    endfunction
    function integer tri_edge(input integer px,input integer py);
        integer a,b,c;
        begin
            a=d2seg(px,py,350,350,500,400);
            b=d2seg(px,py,500,400,330,500);
            c=d2seg(px,py,330,500,350,350);
            if(a<b) tri_edge=(a<c)?a:c; else tri_edge=(b<c)?b:c;
        end
    endfunction
    shape_edge_detector #(.IMAGE_WIDTH(W),.IMAGE_HEIGHT(H),.ROI_MARGIN_X(24),
        .ROI_MARGIN_Y(12),.MIN_SIZE(16),.MIN_EDGE_PIX(64)) dut(
        .clk(clk),.rst_n(rst_n),.in_valid(valid),.in_edge(edge_sig),.in_x(ix),.in_y(iy),
        .in_frame_flush(1'b0),
        .result_valid(rv),.result_count(rc),.result_class(cls),
        .result_x0(x0),.result_y0(y0),.result_x1(x1),.result_y1(y1),.frame_done(done));
    initial begin
        #20 rst_n=1;
        for(y=0;y<H;y=y+1) begin
            for(x=0;x<W;x=x+1) begin
                @(negedge clk); valid=1; ix=x; iy=y;
                edge_sig=0;
                if(((x==100)||(x==260))&&(y>=80)&&(y<=200)) edge_sig=1;
                if(((y==80)||(y==200))&&(x>=100)&&(x<=260)) edge_sig=1;
                if(((x-650)*(x-650)+(y-200)*(y-200)>=4760) &&
                   ((x-650)*(x-650)+(y-200)*(y-200)<=5040)) edge_sig=1;
                if(tri_edge(x,y)<=4) edge_sig=1;
            end
        end
        // First pixel of the next frame closes the previous frame.
        @(negedge clk); valid=1; ix=0; iy=0; edge_sig=0;
        @(negedge clk); valid=0;
        wait(done==1'b1); repeat(5) @(negedge clk);
        $display("EDGE DETECT count=%0d",rc);
        for(k=0;k<5;k=k+1) if(rv[k]) $display(" slot%0d class=%0d box=(%0d,%0d)-(%0d,%0d)",
            k,cls[k],x0[k],y0[k],x1[k],y1[k]);
        if(rc!=3) $fatal(1,"expected three edge contours");
        $finish;
    end
    initial begin #20000000; $fatal(1,"timeout"); end
endmodule
