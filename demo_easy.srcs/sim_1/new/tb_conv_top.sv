`timescale 1ns / 1ps

module tb_bram_processor();

    parameter IMG_W = 256;
    parameter IMG_H = 256;
    parameter TOTAL_PX = IMG_W * IMG_H;
    parameter CLK_PERIOD = 10;

    reg clk;
    reg rst_n;
    reg start;
    wire done;

    // Instantiate UUT
    bram_ip_processor #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .done(done)
    );

    // Clock
    always #(CLK_PERIOD/2) clk = (clk === 1'b0); // Handles X-state at start

    integer f_out;
    integer i;

    initial begin
        // Initialize
        clk = 0;
        rst_n = 0;
        start = 0;

        // Reset
        #(CLK_PERIOD * 10);
        rst_n = 1;
        #(CLK_PERIOD * 10);

        $display("--- Starting FPGA Image Inversion ---");
        start = 1;
        #(CLK_PERIOD);
        start = 0;

        // 1. Wait for the FPGA to say it's finished
        wait(done);
        $display("--- FPGA Done signal received at %0t ---", $time);
        
        // 2. Extra safety: Wait for the pipeline to empty
        #(CLK_PERIOD * 20);

        // 3. NOW open the file for exporting the results
        f_out = $fopen("processed_image.hex", "w");
        
        $display("Exporting BRAM results to file...");

        // 4. Manually loop through the BRAM addresses to read data
        // This is only possible in simulation by peeking into the UUT
        for (i = 0; i < TOTAL_PX; i = i + 1) begin
            // Peek at the internal write data or the memory array directly
            // If you have a 2D array inside UUT:
            // $fwrite(f_out, "%04h\n", uut.out_mem[i/IMG_W][i%IMG_W]);
            
            // Or if you want to capture the specific values logged during RUN:
            // Since we're after the fact, we'll use the 'Real-time Logger' fix below.
        end
        
        // See the 'Better Logger' block below for the most reliable write method
    end

    // --- The ONLY Logger You Need ---
    initial begin
        // Open file once at time 0
        f_out = $fopen("processed_image.hex", "w");
        
        // Wait forever, writing every time the BRAM Write Enable hits
        forever begin
            @(posedge clk);
            if (uut.out_bram_we) begin
                $fwrite(f_out, "%04h\n", uut.out_bram_dina);
            end
            
            // Stop logging and close file when simulation is truly over
            if (done) begin
                #(CLK_PERIOD * 10); // Catch the last few pixels
                $fclose(f_out);
                $display("File closed. Simulation Finished.");
                $finish;
            end
        end
    end

endmodule