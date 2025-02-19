`timescale 1ns/1ps

module tb;

    // Testbench signals
    reg [7:0] ui_in;
    wire [7:0] uo_out;
    reg [7:0] uio_in;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;
    reg clk, rst_n;
    reg ena;
    
    // Instantiate the FIFO module
    tt_um_monishvr_fifo uut (
        .ui_in(ui_in),
        .uo_out(uo_out),
        .uio_in(uio_in),
        .uio_out(uio_out),
        .uio_oe(uio_oe),
        .ena(ena),
        .clk(clk),
        .rst_n(rst_n)
    );
    
    // Clock generation
    always #5 clk = ~clk;
    
    initial begin
        // Initialize signals
        clk = 0;
        rst_n = 0;
        ena = 1;
        ui_in = 0;
        uio_in = 0;
        
        // Reset sequence
        #10 rst_n = 1;
        #10 rst_n = 0;
        
        // Write data to FIFO
        ui_in[2] = 1;  // Write enable
        ui_in[3] = 0;  // Read disable
        ui_in[7:4] = 4'b1010; // Data to be written
        #10 ui_in[2] = 0; // Disable write
        
        // Read data from FIFO
        #20 ui_in[2] = 0;  // Write disable
        ui_in[3] = 1;  // Read enable
        #10 ui_in[3] = 0; // Disable read
        
        // Additional test cases
        #20 ui_in[2] = 1; ui_in[7:4] = 4'b1100; #10 ui_in[2] = 0; // Write another data
        #20 ui_in[3] = 1; #10 ui_in[3] = 0; // Read again
        
        // Finish simulation
        #50;
        $stop;
    end
    
    // Monitor output
    // initial begin
    //     $monitor("Time=%0t, Write=%b, Read=%b, Data In=%b, Data Out=%b, Full=%b, Empty=%b", 
    //              $time, ui_in[2], ui_in[3], ui_in[7:4], uo_out[5:2], uo_out[0], uo_out[1]);
    // end

endmodule
