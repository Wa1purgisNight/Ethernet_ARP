`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/08/11 18:19:42
// Design Name: 
// Module Name: eth_mac_rx
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module eth_mac_rx_lite (
    input  wire       rx_clk,
    input  wire       rst_n,

    input  wire [7:0] rx_data,
    input  wire       rx_valid,
    input  wire       rx_error,

    output reg  [7:0] frame_data,
    output reg        frame_valid,
    output reg        frame_start,
    output reg        frame_end,
    output reg        frame_error
);

    localparam ST_IDLE     = 2'd0;
    localparam ST_PREAMBLE = 2'd1;
    localparam ST_FRAME    = 2'd2;
    localparam ST_DROP     = 2'd3;

    reg [1:0] state;

    reg [3:0] preamble_cnt;
    reg       first_byte;

    always @(posedge rx_clk or negedge rst_n) begin

        if (!rst_n) begin

            state        <= ST_IDLE;
            preamble_cnt <= 4'd0;
            first_byte   <= 1'b0;

            frame_data   <= 8'd0;
            frame_valid  <= 1'b0;
            frame_start  <= 1'b0;
            frame_end    <= 1'b0;
            frame_error  <= 1'b0;

        end
        else begin

            // pulse-type outputs
            frame_valid <= 1'b0;
            frame_start <= 1'b0;
            frame_end   <= 1'b0;

            case (state)

                //================================================
                // IDLE
                //================================================
                ST_IDLE: begin

                    preamble_cnt <= 4'd0;
                    first_byte   <= 1'b0;
                    frame_error  <= 1'b0;

                    if (rx_valid) begin

                        if (rx_error) begin

                            frame_error <= 1'b1;
                            state       <= ST_DROP;

                        end
                        else if (rx_data == 8'h55) begin

                            preamble_cnt <= 4'd1;
                            state        <= ST_PREAMBLE;

                        end

                    end

                end


                //================================================
                // PREAMBLE
                //
                // Expected:
                //
                // 55 55 55 55 55 55 55 D5
                //
                //================================================
                ST_PREAMBLE: begin

                    if (!rx_valid) begin

                        state        <= ST_IDLE;
                        preamble_cnt <= 4'd0;

                    end
                    else if (rx_error) begin

                        frame_error <= 1'b1;
                        state       <= ST_DROP;

                    end
                    else if (rx_data == 8'h55) begin

                        if (preamble_cnt < 4'd7)
                            preamble_cnt <= preamble_cnt + 1'b1;

                    end
                    else if ((rx_data == 8'hD5) &&
                             (preamble_cnt >= 4'd7)) begin

                        // SFD detected
                        first_byte <= 1'b1;
                        state      <= ST_FRAME;

                    end
                    else begin

                        // malformed preamble
                        state <= ST_DROP;

                    end

                end


                //================================================
                // FRAME
                //
                // Output:
                //
                // DA
                // SA
                // EtherType/Length
                // Payload
                // FCS
                //
                //================================================
                ST_FRAME: begin

                    if (!rx_valid) begin

                        frame_end  <= 1'b1;
                        first_byte <= 1'b0;
                        state      <= ST_IDLE;

                    end
                    else if (rx_error) begin

                        frame_error <= 1'b1;
                        first_byte  <= 1'b0;
                        state       <= ST_DROP;

                    end
                    else begin

                        frame_data  <= rx_data;
                        frame_valid <= 1'b1;

                        if (first_byte) begin
                            frame_start <= 1'b1;
                            first_byte  <= 1'b0;
                        end

                    end

                end


                //================================================
                // DROP
                //================================================
                ST_DROP: begin

                    first_byte <= 1'b0;

                    if (!rx_valid) begin
                        state <= ST_IDLE;
                    end

                end


                default: begin

                    state <= ST_IDLE;

                end

            endcase

        end

    end

endmodule