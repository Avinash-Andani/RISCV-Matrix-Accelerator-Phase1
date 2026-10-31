module system (
    input clk,
    input reset,
    input [31:0] data_in,
    output [31:0] data_out
);
    wire mem_valid;
    reg  mem_ready; 
    wire [31:0] mem_addr, mem_wdata;
    reg  [31:0] mem_rdata;
    wire [3:0]  mem_wstrb;

    picorv32 #(
        .ENABLE_MUL(1), 
        .COMPRESSED_ISA(1), 
        .ENABLE_FAST_MUL(0)
    ) cpu (
        .clk(clk), 
        .resetn(~reset), 
        .mem_valid(mem_valid), 
        .mem_ready(mem_ready),
        .mem_addr(mem_addr), 
        .mem_wdata(mem_wdata), 
        .mem_wstrb(mem_wstrb), 
        .mem_rdata(mem_rdata)
    );

    // 32-bit Synchronous Block RAM (1024 words = 4KB)
    (* ram_style = "block" *) reg [31:0] memory [0:1023]; 

    // Pre-loaded 32-bit RISC-V instructions compiled from main_hardware.c
    integer i;
    initial begin
        for (i = 0; i < 1024; i = i + 1) memory[i] = 32'h00000013; // NOP
        
        memory[0]  = 32'hff000113; // li sp, 0xFF0
        memory[1]  = 32'h400007b7; // lui a5, 0x40000 (0x40000000)
        memory[2]  = 32'h00100713; // li a4, 1
        memory[3]  = 32'h00e7a823; // sw a4, 16(a5)   -> OUT_START = 1
        memory[4]  = 32'h08040737; // lui a4, 0x08040
        memory[5]  = 32'h60270713; // addi a4, a4, 0x602 (0x08040602)
        memory[6]  = 32'h00e7a023; // sw a4, 0(a5)    -> HW_MATRIX_DATA = 0x08040602
        memory[7]  = 32'h07030737; // lui a4, 0x07030
        memory[8]  = 32'h50170713; // addi a4, a4, 0x501 (0x07030501)
        memory[9]  = 32'h00e7a023; // sw a4, 0(a5)    -> HW_MATRIX_DATA = 0x07030501
        memory[10] = 32'h00100713; // li a4, 1
        memory[11] = 32'h00e7a223; // sw a4, 4(a5)    -> HW_START_CMD = 1
        memory[12] = 32'h0000006f; // j .             -> while(1)
    end

    wire coproc_done;
    wire [31:0] out_00, out_01, out_10, out_11;
    reg coproc_start, coproc_wr_en;
    reg [7:0] a_in_0, a_in_1, b_in_0, b_in_1;

    coprocessor coproc (
        .clk(clk), .rst(reset),
        .start(coproc_start), .wr_en(coproc_wr_en), .done(coproc_done),
        .a_in_0(a_in_0), .a_in_1(a_in_1), .b_in_0(b_in_0), .b_in_1(b_in_1),
        .out_00(out_00), .out_01(out_01), .out_10(out_10), .out_11(out_11)
    );

    assign data_out = out_00;

    wire [9:0] word_addr = mem_addr[11:2];

    always @(posedge clk) begin
        coproc_start <= 0; 
        coproc_wr_en <= 0;
        mem_ready    <= 0;

        if (reset) begin
            a_in_0 <= 0; a_in_1 <= 0;
            b_in_0 <= 0; b_in_1 <= 0;
        end else if (mem_valid && !mem_ready) begin
            mem_ready <= 1; // 1-cycle bus handshake completion

            if (mem_addr < 32'h0000_1000) begin
                mem_rdata <= memory[word_addr];
                if (mem_wstrb[0]) memory[word_addr][7:0]   <= mem_wdata[7:0];
                if (mem_wstrb[1]) memory[word_addr][15:8]  <= mem_wdata[15:8];
                if (mem_wstrb[2]) memory[word_addr][23:16] <= mem_wdata[23:16];
                if (mem_wstrb[3]) memory[word_addr][31:24] <= mem_wdata[31:24];
            end
            else if (mem_addr == 32'h4000_0000 && mem_wstrb != 0) begin
                b_in_1 <= mem_wdata[31:24]; 
                a_in_1 <= mem_wdata[23:16];
                b_in_0 <= mem_wdata[15:8];  
                a_in_0 <= mem_wdata[7:0];
                coproc_wr_en <= 1;          
            end
            else if (mem_addr == 32'h4000_0004 && mem_wstrb != 0) begin
                coproc_start <= mem_wdata[0];
            end
        end
    end
endmodule