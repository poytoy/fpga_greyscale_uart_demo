module bram_ip_processor #(
    parameter IMG_W = 256,
    parameter IMG_H = 256,
    localparam TOTAL_PX = IMG_W * IMG_H
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    output reg         done,
    
    // --- ADD THESE FOR UART READBACK ---
    input  wire [15:0] uart_read_addr,
    output wire [15:0] uart_read_data
);

    // --- Counters: Use 17 bits to prevent rollover at 65536 ---
    reg [16:0] in_bram_addr;
    reg [16:0] out_bram_addr;
    reg [16:0] write_count;  // Tracks actual writes to memory

    // --- BRAM Signals ---
    wire [15:0] in_bram_dout;
    reg         in_bram_en;
    reg  [15:0] out_bram_dina;
    reg         out_bram_we;
    
    // --- Pipeline Alignment ---
    reg [1:0] wr_en_pipe; // 2-bit shift register for safer latency handling

    // --- BRAM Instantiations ---
    blk_mem_gen_0 input_bram (.clka(clk), .ena(in_bram_en), .wea(1'b0), .addra(in_bram_addr[15:0]), .dina(16'h0), .douta(in_bram_dout));
    // --- Updated Output BRAM Instantiation ---
    blk_mem_gen_1 output_bram (
            // Port A: Written by the processing logic
            .clka(clk),
            .ena(1'b1),
            .wea(out_bram_we),
            .addra(out_bram_addr[15:0]),
            .dina(out_bram_dina),
            
            // Port B: Read by the UART FSM in fpga_top
            .clkb(clk),
            .enb(1'b1),
            .addrb(uart_read_addr),
            .doutb(uart_read_data)
        );
    
    // --- FSM ---
    localparam IDLE=0, RUN=1, FINISH=2;
    reg [1:0] state;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            in_bram_addr <= 0;
            out_bram_addr <= 0;
            write_count <= 0;
            wr_en_pipe <= 0;
            done <= 0;
            out_bram_we <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    in_bram_addr <= 0;
                    out_bram_addr <= 0;
                    write_count <= 0;
                    if (start) begin
                        state <= RUN;
                        in_bram_en <= 1'b1;
                    end
                end

                RUN: begin
                    // 1. Read Address Logic
                    if (in_bram_addr < TOTAL_PX - 1)
                        in_bram_addr <= in_bram_addr + 1;
                    else
                        in_bram_en <= 1'b0;

                    // 2. Latency Shift Register (Ensures data is valid before we write)
                    wr_en_pipe <= {wr_en_pipe[0], in_bram_en};

                    // 3. Write Logic (Wait for valid pipe)
                    if (wr_en_pipe[0]) begin // Use bit 0 or 1 depending on BRAM latency
                        out_bram_we   <= 1'b1;
                        out_bram_dina <= 16'hFFFF - in_bram_dout;
                        out_bram_addr <= write_count;
                        write_count   <= write_count + 1;
                    end else begin
                        out_bram_we <= 1'b0;
                    end

                    // 4. Exit Condition (Wait until ALL pixels are written)
                    if (write_count == TOTAL_PX) begin
                        state <= FINISH;
                        in_bram_en <= 1'b0;
                        out_bram_we <= 1'b0;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    if (!start) state <= FINISH;
                end
            endcase
        end
    end
endmodule