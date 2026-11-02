`timescale 1ns/1ps
// Directed self-checking testbench for the one-pass Canny pipeline.
// The image contains:
//   - a strong vertical edge at x=24
//   - a strong horizontal edge at y=32, x=2..18
//   - two strong diagonal edges in the right-hand region
//   - a weak vertical edge at x=44 seeded by a short strong segment, which
//     must propagate down the page through causal hysteresis
//   - a weak but isolated vertical edge at x=64, which must be removed
//   - an isolated bright dot at (80,10), which must also be removed
module tb_canny_pipeline;
    localparam integer W = 128;
    localparam integer NL = 48;
    localparam integer HB = 12;

    reg clk = 1'b0;
    always #3.5 clk = ~clk;

    reg rst_n = 1'b0;
    reg in_valid = 1'b0;
    reg [7:0] in_gray = 8'd0;
    reg [10:0] in_x = 0, in_y = 0;
    reg in_ls = 1'b0, in_le = 1'b0;
    reg [10:0] threshold = 11'd96; // LOW=24, HIGH=36 in 8-bit magnitude domain

    wire out_valid, out_edge, out_ls, out_le;
    wire [10:0] out_x, out_y;

    canny_pipeline #(.IMAGE_WIDTH(W)) dut (
        .clk(clk), .rst_n(rst_n),
        .in_valid(in_valid), .in_gray(in_gray), .in_x(in_x), .in_y(in_y),
        .in_line_start(in_ls), .in_line_end(in_le), .threshold(threshold),
        .out_valid(out_valid), .out_edge(out_edge),
        .out_x(out_x), .out_y(out_y), .out_line_start(out_ls), .out_line_end(out_le)
    );

    reg emap [0:NL-1][0:W-1];
    integer in_cycle [0:NL-1][0:W-1];
    integer i, j, x, y, fail_cnt, checks;
    integer n24, n44, n64, n_h, n_diag;
    integer cyc = 0, lat, lat_min = 9999, lat_max = -1;
    always @(posedge clk) cyc <= cyc + 1;

    function [7:0] image_pixel(input integer py, input integer px);
        reg [7:0] v;
        integer d;
        begin
            v = (px < 24) ? 8'd40 : 8'd200;

            // Weak vertical boundary, with a short strong seed at rows 16..19.
            if (px >= 44 && py >= 16) begin
                if (py <= 19) v = 8'd40;
                else          v = 8'd88;
            end

            // Completely isolated weak boundary, never connected to a seed.
            if (px >= 64 && py >= 8 && py < 13) v = 8'd120;

            // Strong horizontal step in the left region.
            if (px < 20 && py >= 32) v = 8'd200;

            // Two strong diagonal boundaries.
            if (py <= 30) begin
                d = px - py;
                if (px >= 92) begin
                    v = 8'd40;
                    if (d >= 96 && d <= 100) v = 8'd220;
                end
            end

            // One isolated hot pixel must be removed by smoothing/NMS/threshold.
            if (px == 80 && py == 10) v = 8'd255;
            image_pixel = v;
        end
    endfunction

    always @(negedge clk) begin
        if (out_valid && out_x < W && out_y < NL) begin
            emap[out_y][out_x] = out_edge;
            lat = cyc - in_cycle[out_y][out_x];
            if (lat < lat_min) lat_min = lat;
            if (lat > lat_max) lat_max = lat;
        end
    end

    task drive_frame;
        integer py, px;
        begin
            for (py = 0; py < NL; py = py + 1) begin
                for (px = 0; px < W; px = px + 1) begin
                    @(negedge clk);
                    in_valid = 1'b1;
                    in_x = px; in_y = py;
                    in_ls = (px == 0); in_le = (px == W-1);
                    in_gray = image_pixel(py, px);
                    in_cycle[py][px] = cyc + 1;
                end
                repeat (HB) begin
                    @(negedge clk);
                    in_valid = 1'b0; in_ls = 1'b0; in_le = 1'b0;
                end
            end
        end
    endtask

    task check_zero_window(input integer y0, input integer y1,
                           input integer x0, input integer x1);
        integer py, px, cnt;
        begin
            cnt = 0;
            for (py = y0; py <= y1; py = py + 1)
                for (px = x0; px <= x1; px = px + 1)
                    if (emap[py][px]) cnt = cnt + 1;
            checks = checks + 1;
            if (cnt != 0) begin
                fail_cnt = fail_cnt + 1;
                $display("FAIL zero-edge window y%0d..%0d x%0d..%0d: %0d pixels survived",
                         y0,y1,x0,x1,cnt);
                for (py = y0; py <= y1; py = py + 1)
                    for (px = x0; px <= x1; px = px + 1)
                        if (emap[py][px]) $display("  survivor y=%0d x=%0d", py, px);
            end else begin
                $display("PASS zero-edge window y%0d..%0d x%0d..%0d",
                         y0,y1,x0,x1);
            end
        end
    endtask

    initial begin
        fail_cnt = 0; checks = 0;
        for (y = 0; y < NL; y = y + 1)
            for (x = 0; x < W; x = x + 1)
                emap[y][x] = 1'b0;

        repeat (8) @(negedge clk);
        rst_n = 1'b1;
        repeat (8) @(negedge clk);

        drive_frame();
        repeat (24) @(negedge clk);

        // A strong vertical edge must be present as one thin ridge per row.
        checks = checks + 1;
        for (y = 24; y <= 42; y = y + 1) begin
            n24 = 0;
            for (x = 21; x <= 27; x = x + 1) n24 = n24 + emap[y][x];
            if (n24 != 1) begin
                fail_cnt = fail_cnt + 1;
                $display("FAIL strong vertical line y=%0d width=%0d", y, n24);
            end
        end
        $display("INFO strong vertical checked y=24..42");

        // Strong horizontal edge, allowing the NMS ridge to land on y=32/33.
        n_h = 0;
        for (y = 30; y <= 34; y = y + 1)
            for (x = 4; x <= 18; x = x + 1) n_h = n_h + emap[y][x];
        checks = checks + 1;
        if (n_h < 10) begin fail_cnt = fail_cnt + 1; $display("FAIL horizontal edge pixels=%0d", n_h); end
        else $display("PASS horizontal edge pixels=%0d", n_h);

        // The weak edge below the seed must remain connected row to row.
        n44 = 0;
        for (y = 22; y <= 42; y = y + 1) begin
            j = 0;
            for (x = 42; x <= 46; x = x + 1) j = j + emap[y][x];
            if (j != 0) n44 = n44 + 1;
        end
        checks = checks + 1;
        if (n44 < 16) begin fail_cnt = fail_cnt + 1; $display("FAIL connected weak rows=%0d (want >=16)", n44); end
        else $display("PASS connected weak hysteresis rows=%0d", n44);

        check_zero_window(8, 12, 62, 66);
        check_zero_window(8, 13, 78, 82);

        // Both diagonal boundaries should survive continuously.
        checks = checks + 1;
        for (y = 8; y <= 20; y = y + 1) begin
            n_diag = 0;
            for (x = 92; x < W; x = x + 1) n_diag = n_diag + emap[y][x];
            if (n_diag < 2) begin
                fail_cnt = fail_cnt + 1;
                $display("FAIL diagonal rows y=%0d edge pixels=%0d", y, n_diag);
            end
        end
        $display("INFO diagonal rows checked y=8..20 (endpoints intentionally trimmed)");

        $display("");
        $display("INFO pipeline latency from gray input to registered output: min=%0d max=%0d clocks",
                 lat_min, lat_max);
        checks = checks + 1;
        if (lat_min != lat_max) begin
            fail_cnt = fail_cnt + 1;
            $display("FAIL pipeline latency is not constant");
        end
        if (fail_cnt == 0) $display("RESULT : PASS (%0d directed checks)", checks);
        else               $display("RESULT : FAIL (%0d failures)", fail_cnt);
        $finish;
    end
endmodule
