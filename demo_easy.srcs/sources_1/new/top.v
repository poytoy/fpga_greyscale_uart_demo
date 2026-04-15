module fpga_top (
    input  wire clk,         // 100MHz from Pin E3
    input  wire rst,         // Map to BTNL (Active High)
    input  wire start_btn,   // Map to BTNC (Active High)
    output wire uart_tx_pin, // Map to Pin D10
    output wire led_done     // Map to LD0
);

    // --- Signal Declarations ---
    wire rst_n = !rst;       // Processor and UART expect Active Low
    wire proc_done;
    
    // UART signals
    reg        tx_start;     // Pulsed to start transmission
    reg [7:0]  tx_byte;      // Data byte for UART
    wire       tx_busy;      // High while UART is sending
    wire       tx_ready = !tx_busy; // Handshake for our FSM
    
    // BRAM/Pixel signals
    reg  [16:0] tx_addr;
    wire [15:0] pixel_to_send;

    // --- 1. Processing Logic & Output BRAM ---
    // This module contains your BRAM and logic. 
    // It exposes Port B of the BRAM through uart_read signals.
    bram_ip_processor processor_inst (
        .clk(clk), 
        .rst_n(rst_n),
        .start(start_btn), 
        .done(proc_done),
        .uart_read_addr(tx_addr[15:0]),
        .uart_read_data(pixel_to_send)
    );

    // --- 2. UART Transmitter ---
    // Note: CLOCKS_PER_PULSE = 100MHz / 115200 baud = 868
    transmitter #(.CLOCKS_PER_PULSE(868)) uart_inst (
        .clk(clk),
        .rstn(rst_n),
        .data_in(tx_byte),
        .data_en(tx_start), // Pulsed high to start
        .tx(uart_tx_pin),
        .tx_busy(tx_busy)
    );

    // --- 3. UART Transmission FSM ---
    localparam TX_IDLE      = 3'd0, 
               TX_WAIT_PROC = 3'd1, 
               TX_FETCH     = 3'd2, // Buffer cycle for BRAM latency
               TX_SEND_HIGH = 3'd3, 
               TX_SEND_LOW  = 3'd4, 
               TX_NEXT      = 3'd5;

    reg [2:0] tx_state;

    always @(posedge clk) begin
        if (!rst_n) begin
            tx_state <= TX_IDLE;
            tx_addr  <= 0;
            tx_start <= 0;
            tx_byte  <= 0;
        end else begin
            case (tx_state)
                TX_IDLE: begin
                    tx_addr <= 0;
                    if (start_btn) tx_state <= TX_WAIT_PROC;
                end

                TX_WAIT_PROC: begin
                    if (proc_done) tx_state <= TX_FETCH;
                end

                TX_FETCH: begin
                    // BRAM Port B needs 1 cycle to output data after addr changes
                    // We wait here to ensure 'pixel_to_send' is stable.
                    if (tx_ready) tx_state <= TX_SEND_HIGH;
                end

                TX_SEND_HIGH: begin
                    if (tx_ready && !tx_start) begin
                        tx_byte  <= pixel_to_send[15:8]; // High Byte
                        tx_start <= 1'b1;                // Pulse enable
                        tx_state <= TX_SEND_LOW;
                    end else begin
                        tx_start <= 1'b0;
                    end
                end

                TX_SEND_LOW: begin
                    // Pull tx_start low as soon as UART becomes busy
                    if (tx_busy) tx_start <= 1'b0;

                    if (tx_ready && !tx_start) begin
                        tx_byte  <= pixel_to_send[7:0];  // Low Byte
                        tx_start <= 1'b1;
                        tx_state <= TX_NEXT;
                    end
                end

                TX_NEXT: begin
                    if (tx_busy) tx_start <= 1'b0;

                    if (tx_ready && !tx_start) begin
                        if (tx_addr < 65535) begin
                            tx_addr  <= tx_addr + 1;
                            tx_state <= TX_FETCH; // Go back to fetch next pixel
                        end else begin
                            tx_state <= TX_IDLE;  // Image finished
                        end
                    end
                end
                
                default: tx_state <= TX_IDLE;
            endcase
        end
    end

    assign led_done = proc_done;

endmodule