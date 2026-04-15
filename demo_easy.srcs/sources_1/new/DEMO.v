module basic_img_proc #(
    parameter IMG_W = 8,
    parameter IMG_H = 8,
    localparam TOTAL_PX = IMG_W * IMG_H
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    output reg         done,

    // Input BRAM Interface (Port B of a DP-BRAM)
    output reg  [$clog2(TOTAL_PX)-1:0] rd_addr,
    input  wire [7:0]                  rd_data,
    output reg                         rd_en

    // Output Storage: 2D Register Array
    // Accessed as out_mem[row][col]
    );

    // FSM States
    localparam IDLE   = 2'd0,
               RUN    = 2'd1,
               FINISH = 2'd2;
    reg [7:0] out_mem [0:IMG_H-1][0:IMG_W-1]
    reg [1:0] state;
    reg [7:0] pipeline_reg;
    reg       wr_en_d1;      // Delayed write enable to match 1-cycle latency
    reg [$clog2(IMG_W)-1:0] col_ptr;
    reg [$clog2(IMG_H)-1:0] row_ptr;

    // --- Control Logic & Address Generation ---
    always @(posedge clk) begin
        if (!rst_n) begin
            state    <= IDLE;
            rd_addr  <= 0;
            rd_en    <= 0;
            wr_en_d1 <= 0;
            col_ptr  <= 0;
            row_ptr  <= 0;
            done     <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    rd_addr <= 0;
                    if (start) begin
                        state <= RUN;
                        rd_en <= 1'b1;
                    end
                end

                RUN: begin
                    // Read Address Logic
                    if (rd_addr < TOTAL_PX - 1) begin
                        rd_addr <= rd_addr + 1;
                    end else begin
                        rd_en   <= 1'b0;
                    end

                    // The write signal must lag the read signal by 1 cycle
                    wr_en_d1 <= rd_en;

                    // Coordinate Tracking for the 2D Array
                    if (wr_en_d1) begin
                        if (col_ptr == IMG_W - 1) begin
                            col_ptr <= 0;
                            if (row_ptr == IMG_H - 1) begin
                                state <= FINISH;
                            end else begin
                                row_ptr <= row_ptr + 1;
                            end
                        end else begin
                            col_ptr <= col_ptr + 1;
                        end
                    end
                end

                FINISH: begin
                    wr_en_d1 <= 0;
                    done     <= 1'b1;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end

    // --- Processing Logic & 2D Array Write ---
    // This happens exactly 1 cycle after the address was set
    always @(posedge clk) begin
        if (wr_en_d1) begin
            // Grayscale Inversion: 255 - pixel
            out_mem[row_ptr][col_ptr] <= 8'd255 - rd_data;
        end
    end

endmodule