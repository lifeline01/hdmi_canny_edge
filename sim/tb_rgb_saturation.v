`timescale 1ns/1ps
module tb_rgb_saturation;
    reg [7:0] r,g,b; wire [7:0] ro,go,bo;
    integer i,fail_cnt;
    rgb_saturation dut(.in_r(r),.in_g(g),.in_b(b),.out_r(ro),.out_g(go),.out_b(bo));
    initial begin
        fail_cnt=0;
        for(i=0;i<256;i=i+1) begin
            r=i;g=i;b=i;#1;
            if(ro!==i || go!==i || bo!==i) fail_cnt=fail_cnt+1;
        end
        r=150;g=50;b=50;#1;
        if(ro<=r || go>=g || bo>=b) fail_cnt=fail_cnt+1;
        r=0;g=0;b=0;#1; if(ro!==0||go!==0||bo!==0) fail_cnt=fail_cnt+1;
        r=255;g=255;b=255;#1; if(ro!==255||go!==255||bo!==255) fail_cnt=fail_cnt+1;
        if(fail_cnt==0) $display("RESULT : PASS saturation enhancement");
        else $display("RESULT : FAIL saturation enhancement (%0d)",fail_cnt);
        $finish;
    end
endmodule
