`timescale 1ns/1ps
module tb_shape_overlay;
    reg [10:0] x,y;
    reg [4:0] vv;
    reg [1:0] cls [0:4];
    reg [10:0] x0 [0:4], y0 [0:4], x1 [0:4], y1 [0:4];
    reg [7:0] ir,ig,ib;
    wire [7:0] orr,og,ob;
    integer white_count, black_count;

    shape_overlay dut(.x(x),.y(y),.result_valid(vv),.result_class(cls),
        .result_x0(x0),.result_y0(y0),.result_x1(x1),.result_y1(y1),
        .in_r(ir),.in_g(ig),.in_b(ib),.out_r(orr),.out_g(og),.out_b(ob));

    initial begin
        vv=5'b00001; cls[0]=2'd1; x0[0]=10; y0[0]=10; x1[0]=50; y1[0]=40;
        ir=8'hAA; ig=8'h55; ib=8'h11;
        x=10; y=20; #1;
        if (!(orr==8'hFF && og==8'hC8 && ob==8'h00)) $fatal(1,"RECT border colour failed");
        x=11;y=12;#1;
        if (!(orr==8'hFF && og==8'hC8)) $fatal(1,"3-pixel border failed");
        x=13;y=14;#1;
        if (orr==8'hFF && og==8'hC8 && ob==8'h00) $fatal(1,"label interior incorrectly outside label");

        vv=1; x=60;y=60;#1;
        if (orr!=8'hAA || og!=8'h55 || ob!=8'h11) $fatal(1,"outside annotation changed source");

        white_count=0; black_count=0;
        for (y=14;y<21;y=y+1) for (x=14;x<38;x=x+1) begin
            #1;
            if (orr==8'h00 && og==8'h00 && ob==8'h00) black_count=black_count+1;
            if (orr==8'hFF && og==8'hFF && ob==8'hFF) white_count=white_count+1;
        end
        if (black_count<40 || white_count<20) $fatal(1,"label glyph/background missing");
        $display("PASS shape overlay border and RECT glyph (%0d black, %0d white)",black_count,white_count);
        $finish;
    end
endmodule
