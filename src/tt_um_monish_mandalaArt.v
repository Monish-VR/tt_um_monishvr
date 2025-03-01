/*
 * Copyright (c) 2025 Monish V.R
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_monish_mandalaArt(
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
    // VGA Constants
    parameter SCREEN_WIDTH = 640;
    parameter SCREEN_HEIGHT = 480;
    parameter CENTER_X = SCREEN_WIDTH/2;
    parameter CENTER_Y = SCREEN_HEIGHT/2;

    // Core signals
    reg [9:0] pattern_counter;
    reg [7:0] color_counter;
    reg [15:0] glitter_counter;
    reg vsync_prev;
    wire hsync, vsync, video_active;
    wire [9:0] pix_x, pix_y;
    wire [1:0] R, G, B;

    // Pattern and color counters
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vsync_prev <= 0;
            pattern_counter <= 0;
            color_counter <= 0;
            glitter_counter <= 0;
        end else begin
            vsync_prev <= vsync;
            if (vsync && !vsync_prev) begin
                pattern_counter <= pattern_counter + 1;
                color_counter <= color_counter + 1;
                glitter_counter <= glitter_counter + 1;
            end
        end
    end

    // Distance approximation for octagonal shapes
    wire [9:0] delta_x = (pix_x > CENTER_X) ? (pix_x - CENTER_X) : (CENTER_X - pix_x);
    wire [9:0] delta_y = (pix_y > CENTER_Y) ? (pix_y - CENTER_Y) : (CENTER_Y - pix_y);
    wire [9:0] radius = (delta_x > delta_y) ? (delta_x + (delta_y >> 1)) : (delta_y + (delta_x >> 1));

    // Angle calculation with rotation
    wire [7:0] angle_odd = (delta_y[7:0] ^ delta_x[7:0]) + pattern_counter[3:0]; // Clockwise
    wire [7:0] angle_even = (delta_y[7:0] ^ delta_x[7:0]) - pattern_counter[3:0]; // Anti-clockwise

    // Layered pattern definitions with rotation
    wire layer1 = (radius < 40) & ((angle_odd[5] + delta_y[2]) % 2 == pattern_counter[5]);
    wire layer2 = (radius < 80 && radius >= 40) & ((angle_even[1] + radius[2]) % 2 == pattern_counter[1]);
    wire layer3 = (radius < 120 && radius >= 80) & ((angle_even[6] + radius[2]) % 3 == pattern_counter[2]);
    wire layer4 = (radius < 160 && radius >= 120) & ((angle_even[5] & radius[5]) ^ pattern_counter[3]);
    wire layer5 = (radius < 200 && radius >= 160) & ((delta_x[6] + delta_y[6]) == pattern_counter[4]);
    wire layer6 = (radius < 240 && radius >= 200) & ((angle_even[3] + radius[3]) % 3 == pattern_counter[2]);
    wire layer7 = (radius < 280 && radius >= 240) & ((angle_odd[4] ^ delta_x[4]) == pattern_counter[3]);

    // Glitter effect integration
    wire [9:0] corner_dist = (delta_x > delta_y) ? delta_x : delta_y;
    wire glitter = ((pix_x[3] ^ pix_y[3]) ^ glitter_counter[4]) & 
                   ((delta_x + delta_y + glitter_counter[5:0]) % 16 == 0) &
                   (corner_dist > (300 - glitter_counter[8:0]));

    // Color generation with glitter enhancement
    wire [5:0] base_color = {
        color_counter[7:6],
        color_counter[5:4],
        color_counter[3:2]
    };

    wire [5:0] color1 = base_color + 6'b110000;
    wire [5:0] color2 = base_color + 6'b001100;
    wire [5:0] color3 = base_color + 6'b000011;
    wire [5:0] color4 = base_color + 6'b110011;
    wire [5:0] color5 = base_color + 6'b111100;
    wire [5:0] color6 = base_color + 6'b011001;
    wire [5:0] color7 = base_color + 6'b101010;

    wire [5:0] final_color = video_active ? (
        (layer1 | glitter) ? color1 :
        (layer2 | glitter) ? color2 :
        (layer3 | glitter) ? color3 :
        (layer4 | glitter) ? color4 :
        (layer5 | glitter) ? color5 :
        (layer6 | glitter) ? color6 :
        (layer7 | glitter) ? color7 :
        6'b000000
    ) : 6'b000000;

    assign {R, G, B} = final_color;

    // Output assignments
    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
    assign uio_out = 8'b0;
    assign uio_oe = 8'b0;
    wire _unused_ok = &{ena, ui_in, uio_in};

    // VGA sync generator instantiation
    hvsync_generator hvsync_gen(
        .clk(clk),
        .reset(~rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(video_active),
        .hpos(pix_x),
        .vpos(pix_y)
    );
endmodule


module hvsync_generator(
    input  wire       clk,
    input  wire       reset,
    output wire       hsync,
    output wire       vsync,
    output wire       display_on,
    output wire [9:0] hpos,
    output wire [9:0] vpos
);
    // Horizontal timing parameters
    parameter H_DISPLAY = 640;
    parameter H_FRONT = 16;
    parameter H_SYNC = 96;
    parameter H_BACK = 48;
    parameter H_TOTAL = H_DISPLAY + H_FRONT + H_SYNC + H_BACK;

    // Vertical timing parameters
    parameter V_DISPLAY = 480;
    parameter V_FRONT = 10;
    parameter V_SYNC = 2;
    parameter V_BACK = 33;
    parameter V_TOTAL = V_DISPLAY + V_FRONT + V_SYNC + V_BACK;

    reg [9:0] h_count;
    reg [9:0] v_count;

    always @(posedge clk or posedge reset) begin
        if (reset)
            h_count <= 0;
        else if (h_count == H_TOTAL - 1)
            h_count <= 0;
        else
            h_count <= h_count + 1;
    end

    always @(posedge clk or posedge reset) begin
        if (reset)
            v_count <= 0;
        else if (h_count == H_TOTAL - 1) begin
            if (v_count == V_TOTAL - 1)
                v_count <= 0;
            else
                v_count <= v_count + 1;
        end
    end

    assign hsync = (h_count >= H_DISPLAY + H_FRONT) && 
                  (h_count < H_DISPLAY + H_FRONT + H_SYNC);
    assign vsync = (v_count >= V_DISPLAY + V_FRONT) && 
                  (v_count < V_DISPLAY + V_FRONT + V_SYNC);
    assign display_on = (h_count < H_DISPLAY) && (v_count < V_DISPLAY);
    assign hpos = h_count;
    assign vpos = v_count;
endmodule
