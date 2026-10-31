`timescale 1ns / 1ps

module system_tb;
    reg clk, reset;
    
    // Cycle counting variables
    integer cycle_counter = 0;
    integer start_cycle = 0;
    
    system uut (.clk(clk), .reset(reset));

    always #2 clk = ~clk;

    // Tick the counter upwards continuously
    always @(posedge clk) begin
        cycle_counter = cycle_counter + 1;
    end

    initial begin
        $dumpfile("system_wave.vcd");
        $dumpvars(0, system_tb);

        clk = 0; reset = 1;
        #20 reset = 0;

        #500000 $display("TIMEOUT: CPU trapped or stuck."); $finish; 
    end
    
// The Wiretap Stopwatch
    always @(posedge clk) begin
        // Catch START
        if (uut.mem_valid && uut.mem_wstrb != 0 && uut.mem_addr == 32'h40000010) begin
            start_cycle = cycle_counter;
        end
            
        // Catch SOFTWARE DONE
        if (uut.mem_valid && uut.mem_wstrb != 0 && uut.mem_addr == 32'h40000014) begin
            $display("\n----------------------------------------");
            $display("RISC-V Software Execution: %0d clock cycles", (cycle_counter - start_cycle));
            $display("----------------------------------------\n");
            $finish;
        end
        
        // Catch HARDWARE DONE (Reads directly from your Coprocessor!)
        if (uut.coproc_done == 1) begin
            $display("\n----------------------------------------");
            $display("AI Coprocessor Execution: %0d clock cycles", (cycle_counter - start_cycle));
            $display("----------------------------------------\n");
            $finish;
        end
    end
endmodule