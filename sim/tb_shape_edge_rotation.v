`timescale 1ns/1ps

// Directed rotation sweep for the full-resolution contour classifier.
// The stimulus contains only Canny-style one-pixel contours.  Each shape is
// fed in a separate frame so a classification failure identifies the exact
// rotation instead of being hidden by multi-target bookkeeping.
module tb_shape_edge_rotation;
    localparam integer W = 320;
    localparam integer H = 240;
    localparam integer ROI_X = 12;
    localparam integer ROI_Y = 12;

    reg clk = 0;
    reg rst_n = 0;
    reg valid = 0;
    reg edge_sig = 0;
    reg [10:0] ix = 0;
    reg [10:0] iy = 0;
    wire [4:0] rv;
    wire [3:0] rc;
    wire [1:0] cls [0:4];
    wire [10:0] x0 [0:4], y0 [0:4], x1 [0:4], y1 [0:4];
    wire done;

    integer x, y, k, test_no;
    integer shape_kind;             // 1=rect, 2=triangle, 3=circle
    integer vx [0:3], vy [0:3];
    integer expected;
    integer errors;

    always #5 clk = ~clk;

    function integer d2seg(input integer px, input integer py,
                           input integer ax, input integer ay,
                           input integer bx, input integer by);
        integer vx0, vy0, wx, wy, den, dot, qx, qy, dx, dy;
        begin
            vx0 = bx-ax; vy0 = by-ay; wx = px-ax; wy = py-ay;
            den = vx0*vx0 + vy0*vy0;
            if (den == 0) den = 1;
            dot = vx0*wx + vy0*wy;
            if (dot < 0) begin qx=ax; qy=ay; end
            else if (dot > den) begin qx=bx; qy=by; end
            else begin qx=ax+(vx0*dot)/den; qy=ay+(vy0*dot)/den; end
            dx=px-qx; dy=py-qy;
            d2seg=dx*dx+dy*dy;
        end
    endfunction

    function integer poly_edge(input integer px, input integer py,
                               input integer count);
        integer n, da, db;
        begin
            poly_edge = 1;
            for (n=0; n<count; n=n+1) begin
                da = d2seg(px,py,vx[n],vy[n],vx[(n+1)%count],vy[(n+1)%count]);
                if (da <= 4) poly_edge = 0;
            end
        end
    endfunction

    task set_rectangle(input integer angle_deg, input integer hw, input integer hh);
        begin
            // Pre-rotated integer vertices avoid simulator-dependent signed
            // shift behaviour while retaining exact 15-degree steps.
            if ((angle_deg == 45) && (hh == 58)) begin
                vx[0]=160; vy[0]=38; vx[1]=242; vy[1]=120; vx[2]=160; vy[2]=202; vx[3]=78; vy[3]=120;
            end else begin
                case(angle_deg)
                    0:  begin vx[0]=96; vy[0]=78; vx[1]=224; vy[1]=78; vx[2]=224; vy[2]=162; vx[3]=96; vy[3]=162; end
                    15: begin vx[0]=109; vy[0]=63; vx[1]=233; vy[1]=96; vx[2]=211; vy[2]=177; vx[3]=87; vy[3]=144; end
                    30: begin vx[0]=126; vy[0]=52; vx[1]=236; vy[1]=116; vx[2]=194; vy[2]=188; vx[3]=84; vy[3]=124; end
                    45: begin vx[0]=144; vy[0]=45; vx[1]=235; vy[1]=136; vx[2]=176; vy[2]=195; vx[3]=85; vy[3]=104; end
                    60: begin vx[0]=164; vy[0]=44; vx[1]=228; vy[1]=154; vx[2]=156; vy[2]=196; vx[3]=92; vy[3]=86; end
                    75: begin vx[0]=184; vy[0]=47; vx[1]=217; vy[1]=171; vx[2]=136; vy[2]=193; vx[3]=103; vy[3]=69; end
                    default: begin vx[0]=96; vy[0]=78; vx[1]=224; vy[1]=78; vx[2]=224; vy[2]=162; vx[3]=96; vy[3]=162; end
                endcase
            end
            shape_kind=1; expected=1;
        end
    endtask

    task set_triangle(input integer angle_deg, input integer radius);
        begin
            case(angle_deg)
                0:   begin vx[0]=232; vy[0]=120; vx[1]=124; vy[1]=182; vx[2]=124; vy[2]=58; end
                30:  begin vx[0]=222; vy[0]=156; vx[1]=98;  vy[1]=156; vx[2]=160; vy[2]=48; end
                60:  begin vx[0]=196; vy[0]=182; vx[1]=88;  vy[1]=120; vx[2]=196; vy[2]=58; end
                90:  begin vx[0]=160; vy[0]=192; vx[1]=98;  vy[1]=84;  vx[2]=222; vy[2]=84; end
                120: begin vx[0]=124; vy[0]=182; vx[1]=124; vy[1]=58;  vx[2]=232; vy[2]=120; end
                150: begin vx[0]=98;  vy[0]=156; vx[1]=160; vy[1]=48;  vx[2]=222; vy[2]=156; end
                default: begin vx[0]=232; vy[0]=120; vx[1]=124; vy[1]=182; vx[2]=124; vy[2]=58; end
            endcase
            shape_kind=2; expected=3;
        end
    endtask

    task set_circle;
        begin shape_kind=3; expected=2; end
    endtask

    shape_edge_detector #(
        .IMAGE_WIDTH(W), .IMAGE_HEIGHT(H),
        .ROI_MARGIN_X(ROI_X), .ROI_MARGIN_Y(ROI_Y),
        .MIN_SIZE(16), .MIN_EDGE_PIX(32), .FRAME_FLUSH_CLKS(64)
    ) dut (
        .clk(clk), .rst_n(rst_n), .in_valid(valid), .in_edge(edge_sig),
        .in_x(ix), .in_y(iy), .in_frame_flush(1'b0),
        .result_valid(rv), .result_count(rc), .result_class(cls),
        .result_x0(x0), .result_y0(y0), .result_x1(x1), .result_y1(y1),
        .frame_done(done)
    );

    task run_frame;
        integer dx, dy, edge_count;
        begin
            edge_count=0;
            for (y=0; y<H; y=y+1) begin
                for (x=0; x<W; x=x+1) begin
                    @(negedge clk);
                    valid=1; ix=x; iy=y; edge_sig=0;
                    if (shape_kind == 1)
                        edge_sig = !poly_edge(x,y,4);
                    else if (shape_kind == 2)
                        edge_sig = !poly_edge(x,y,3);
                    else begin
                        dx=x-160; dy=y-120;
                        if ((dx*dx+dy*dy >= 69*69) &&
                            (dx*dx+dy*dy <= 71*71)) edge_sig=1;
                    end
                    // Real Canny contours contain short dropouts.  Keep the
                    // connected component intact but create deterministic
                    // one-to-five-pixel gaps on every side.
                    if ((test_no >= 15) && edge_sig &&
                        (((x*7 + y*11 + test_no*13) % 43) < 11))
                        edge_sig=0;
                    if (edge_sig) edge_count=edge_count+1;
                end
            end
            @(negedge clk); valid=1; ix=0; iy=0; edge_sig=0;
            @(negedge clk); valid=0;
            k=0;
            while (!done && k < 20000) begin @(negedge clk); k=k+1; end
            if (!done) $fatal(1,"detector timeout");
            repeat(8) @(negedge clk);
            if ((rc !== 1) || (rv[0] !== 1) || (cls[0] !== expected[1:0])) begin
                $display("FAIL test=%0d kind=%0d edges=%0d verts=(%0d,%0d)(%0d,%0d)(%0d,%0d)(%0d,%0d) expected=%0d got_count=%0d got_class=%0d box=(%0d,%0d)-(%0d,%0d) fill=%0d area=%0d odiff=%0d bw=%0d bh=%0d calc=%0d/%0d/%0d/%0d/%0d",
                         test_no,shape_kind,edge_count,
                         vx[0],vy[0],vx[1],vy[1],vx[2],vy[2],vx[3],vy[3],
                         expected,rc,cls[0],x0[0],y0[0],x1[0],y1[0],
                         dut.f_fill,dut.f_box_area,dut.f_odiff,dut.f_bw,dut.f_bh,
                         dut.f_fill_x16,dut.f_area_x11,dut.f_area_x14,
                         dut.f_bw_x20,dut.f_bh_x17);
                for (k=1;k<16;k=k+1)
                    if (dut.final_valid[k])
                        $display("  raw label %0d count=%0d fill=%0d box=(%0d,%0d)-(%0d,%0d)",
                                 k,dut.final_count[k],dut.final_fill[k],
                                 dut.final_x0[k],dut.final_y0[k],
                                 dut.final_x1[k],dut.final_y1[k]);
                errors=errors+1;
            end
        end
    endtask

    initial begin
        errors=0; test_no=0;
        for(k=0;k<4;k=k+1) begin vx[k]=0; vy[k]=0; end
        #20 rst_n=1;

        set_rectangle(0,64,42);  test_no=test_no+1; run_frame;
        set_rectangle(15,64,42); test_no=test_no+1; run_frame;
        set_rectangle(30,64,42); test_no=test_no+1; run_frame;
        set_rectangle(45,64,42); test_no=test_no+1; run_frame;
        set_rectangle(60,64,42); test_no=test_no+1; run_frame;
        set_rectangle(75,64,42); test_no=test_no+1; run_frame;
        set_rectangle(45,58,58); test_no=test_no+1; run_frame;

        set_triangle(0,72);   test_no=test_no+1; run_frame;
        set_triangle(30,72);  test_no=test_no+1; run_frame;
        set_triangle(60,72);  test_no=test_no+1; run_frame;
        set_triangle(90,72);  test_no=test_no+1; run_frame;
        set_triangle(120,72); test_no=test_no+1; run_frame;
        set_triangle(150,72); test_no=test_no+1; run_frame;

        set_circle; test_no=test_no+1; run_frame;

        set_rectangle(0,64,42);  test_no=test_no+1; run_frame;
        set_rectangle(15,64,42); test_no=test_no+1; run_frame;
        set_rectangle(45,58,58); test_no=test_no+1; run_frame;
        set_rectangle(75,64,42); test_no=test_no+1; run_frame;
        set_triangle(0,72);   test_no=test_no+1; run_frame;
        set_triangle(30,72);  test_no=test_no+1; run_frame;
        set_triangle(90,72);  test_no=test_no+1; run_frame;
        set_triangle(150,72); test_no=test_no+1; run_frame;
        if (errors != 0) $fatal(1,"rotation classifier failures=%0d of %0d",errors,test_no);
        $display("PASS shape classifier across %0d rotations",test_no);
        $finish;
    end
endmodule
