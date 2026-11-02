`timescale 1ns/1ps
module tb_ui_modes;
    reg clk=0,rst_n=0;
    reg [2:0] key=3'b111;
    wire [2:0] mode;
    wire [10:0] threshold;
    wire [2:0] press;
    integer k;
    always #5 clk=~clk;
    ui_control #(.DEBOUNCE_BITS(1),.MODE_DEF(3'd0)) dut(
        .clk(clk),.rst_n(rst_n),.key(key),.mode_sel(mode),
        .threshold(threshold),.key_press(press));
    task press_key1;
        begin
            key[0]=0; repeat(12) @(negedge clk);
            key[0]=1; repeat(12) @(negedge clk);
        end
    endtask
    initial begin
        repeat(4) @(negedge clk); rst_n=1; repeat(4) @(negedge clk);
        $display("INFO reset mode=%b",mode);
        if (mode!=0) $fatal(1,"mode reset");
        for (k=1;k<=4;k=k+1) begin
            press_key1;
            if (mode!=k[2:0]) $fatal(1,"expected mode %0d got %0d",k,mode);
        end
        press_key1;
        if (mode!=0) $fatal(1,"mode wrap");
        $display("PASS ui modes 0-1-2-3-4-0");
        $finish;
    end
endmodule
