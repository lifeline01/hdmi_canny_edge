`timescale 1ns/1ps
module tb_edge_shape_mode;
    localparam integer W=320, H=180;
    reg clk=0, rst_n=0;
    reg de=0,hs=0,vs=0;
    reg [7:0] ir=8'hF0,ig=8'hF0,ib=8'hF0;
    wire ode,ohs,ovs;
    wire [7:0] orr,og,ob;
    integer x,y,yellow_count,out_pixels;

    always #5 clk=~clk;
    integer dk, det_frames;
    always @(posedge dut.u_shape_detector.frame_done) begin
        #1; det_frames=det_frames+1;
        $display("CANNY DETECTOR frame=%0d count=%0d",det_frames,dut.u_shape_detector.result_count);
        for(dk=0;dk<5;dk=dk+1) if(dut.u_shape_detector.result_valid[dk])
            $display(" det slot%0d cls=%0d box=(%0d,%0d)-(%0d,%0d)",dk,
                dut.u_shape_detector.result_class[dk],dut.u_shape_detector.result_x0[dk],
                dut.u_shape_detector.result_y0[dk],dut.u_shape_detector.result_x1[dk],dut.u_shape_detector.result_y1[dk]);
    end

    edge_detect_1ppc #(
        .IMAGE_WIDTH(W),.IMAGE_HEIGHT(H),.PIXEL_ALIGN(21),
        .ROI_MARGIN_X(16),.ROI_MARGIN_Y(8),.MIN_EDGE_PIX(32)
    ) dut (
        .clk(clk),.rst_n(rst_n),.mode_sel(3'd4),.threshold(11'd96),.selftest(1'b0),
        .in_de(de),.in_hs(hs),.in_vs(vs),.in_r(ir),.in_g(ig),.in_b(ib),
        .out_de(ode),.out_hs(ohs),.out_vs(ovs),.out_r(orr),.out_g(og),.out_b(ob),
        .dbg_edge_valid(),.dbg_shape_count()
    );

    always @(posedge clk) begin
        if (ode) begin
            out_pixels=out_pixels+1;
            if ((orr==8'hFF)&&(og==8'hC8)&&(ob==8'h00)) yellow_count=yellow_count+1;
        end
    end

    task send_frame;
        begin
            for (y=0;y<H;y=y+1) begin
                for (x=0;x<W;x=x+1) begin
                    @(negedge clk);
                    de=1; hs=(x==0); vs=(y==0);
                    ir=8'hF0; ig=8'hF0; ib=8'hF0;
                    if ((x>=40)&&(x<=280)&&(y>=30)&&(y<=150)) begin
                        ir=8'hDC; ig=8'h18; ib=8'h18;
                    end
                end
                @(negedge clk); de=0; hs=0; vs=0;
                repeat (20) @(negedge clk);
            end
            de=0; repeat (4600) @(negedge clk);
        end
    endtask

    initial begin
        yellow_count=0; out_pixels=0;
        det_frames=0;
        #20 rst_n=1;
        send_frame;
        wait(det_frames>=1);
        repeat (5) @(negedge clk);
        // A second matching frame confirms the temporal track.
        send_frame;
        wait(det_frames>=2);
        repeat (5) @(negedge clk);
        yellow_count=0; out_pixels=0;
        // The third frame displays the confirmed/stable result.
        send_frame;
        repeat (100) @(negedge clk);
        if (out_pixels < W*H-500) $fatal(1,"not enough output pixels: %0d",out_pixels);
        if (yellow_count < 200) $fatal(1,"mode 4 RECT box missing: %0d",yellow_count);
        $display("PASS edge mode 4: %0d yellow box pixels across %0d output pixels",yellow_count,out_pixels);
        $finish;
    end

    initial begin #10000000; $fatal(1,"timeout"); end
endmodule
