`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/08/11 20:31:05
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


module eth_mac_rx #(
    parameter [47:0] LOCAL_MAC = 48'h02_00_00_00_00_01
)(
    input  wire        rx_clk,
    input  wire        rst_n,

    // From rgmii_rx
    input  wire [7:0]  rx_data,
    input  wire        rx_valid,
    input  wire        rx_error,

    // Ethernet header
    output reg  [47:0] dst_mac,
    output reg  [47:0] src_mac,
    output reg  [15:0] eth_type,

    // Payload output
    output reg  [7:0]  payload_data,
    output reg         payload_valid,

    // Frame status
    output reg         frame_start,
    output reg         frame_done,
    output reg         frame_error,
    output reg         crc_error
);

    // ============================================================
    // State machine
    // ============================================================

    localparam ST_IDLE     = 3'd0;
    localparam ST_PREAMBLE = 3'd1;
    localparam ST_FRAME    = 3'd2;
    localparam ST_END      = 3'd3;
    localparam ST_DROP     = 3'd4;

    reg [2:0] state;

    // ============================================================
    // Preamble
    // ============================================================

    reg [2:0] preamble_cnt;

    // ============================================================
    // Frame byte counter
    //
    // Ethernet frame after SFD:
    //
    // 0  ~ 5   : Destination MAC
    // 6  ~ 11  : Source MAC
    // 12 ~ 13  : EtherType
    // 14 ...   : Payload
    // last 4   : FCS
    //
    // ============================================================

    reg [15:0] frame_byte_cnt;

    // ============================================================
    // Four-byte pipeline
    //
    // We do not know that a byte belongs to FCS until rx_valid
    // goes low. Therefore every received byte is delayed by 4 bytes.
    //
    // When frame finishes:
    //
    // delay3 delay2 delay1 delay0
    //   =     received FCS bytes
    //
    // ============================================================

    reg [7:0] delay0;
    reg [7:0] delay1;
    reg [7:0] delay2;
    reg [7:0] delay3;

    reg [2:0] delay_count;

    // Number of bytes that have actually been released from
    // the four-byte delay pipeline.
    reg [15:0] data_byte_cnt;

    // ============================================================
    // CRC
    // ============================================================

    reg [31:0] crc_reg;

    wire [31:0] crc_next;

    assign crc_next = crc32_byte(crc_reg, delay3);

    // ============================================================
    // Ethernet CRC32
    //
    // Polynomial:
    //   0x04C11DB7 normal form
    //   0xEDB88320 reflected form
    //
    // Ethernet processes each byte LSB first.
    //
    // Initial value:
    //   0xFFFFFFFF
    //
    // ============================================================

    function [31:0] crc32_byte;
        input [31:0] crc_in;
        input [7:0]  data_in;

        integer i;
        reg [31:0] crc;
        reg [7:0]  data;
        begin
            crc  = crc_in;
            data = data_in;

            for (i = 0; i < 8; i = i + 1) begin
                if ((crc[0] ^ data[0]) == 1'b1)
                    crc = (crc >> 1) ^ 32'hEDB88320;
                else
                    crc = crc >> 1;

                data = data >> 1;
            end

            crc32_byte = crc;
        end
    endfunction

    // ============================================================
    // Main FSM
    // ============================================================

    always @(posedge rx_clk) begin
        if (!rst_n) begin

            state          <= ST_IDLE;

            preamble_cnt   <= 3'd0;

            frame_byte_cnt <= 16'd0;
            data_byte_cnt  <= 16'd0;

            delay0         <= 8'd0;
            delay1         <= 8'd0;
            delay2         <= 8'd0;
            delay3         <= 8'd0;
            delay_count    <= 3'd0;

            crc_reg        <= 32'hFFFFFFFF;

            dst_mac        <= 48'd0;
            src_mac        <= 48'd0;
            eth_type       <= 16'd0;

            payload_data   <= 8'd0;
            payload_valid  <= 1'b0;

            frame_start    <= 1'b0;
            frame_done     <= 1'b0;
            frame_error    <= 1'b0;
            crc_error      <= 1'b0;

        end
        else begin

            // Default pulse outputs
            frame_start   <= 1'b0;
            frame_done    <= 1'b0;
            payload_valid <= 1'b0;

            case (state)

                // =================================================
                // IDLE
                //
                // Wait for first 0x55.
                // =================================================

                ST_IDLE: begin

                    preamble_cnt   <= 3'd0;

                    frame_byte_cnt <= 16'd0;
                    data_byte_cnt  <= 16'd0;

                    delay_count    <= 3'd0;

                    crc_reg        <= 32'hFFFFFFFF;

                    frame_error    <= 1'b0;
                    crc_error      <= 1'b0;

                    if (rx_valid) begin
                        if (rx_error) begin
                            state <= ST_DROP;
                        end
                        else if (rx_data == 8'h55) begin
                            preamble_cnt <= 3'd1;
                            state        <= ST_PREAMBLE;
                        end
                    end
                end

                // =================================================
                // PREAMBLE
                //
                // Expected:
                //
                // 55 55 55 55 55 55 55 D5
                //
                // We already saw the first 55 in IDLE.
                // =================================================

                ST_PREAMBLE: begin

                    if (!rx_valid) begin

                        // Frame disappeared before SFD
                        state <= ST_IDLE;

                    end
                    else if (rx_error) begin

                        frame_error <= 1'b1;
                        state       <= ST_DROP;

                    end
                    else begin

                        if (preamble_cnt < 3'd7) begin

                            if (rx_data == 8'h55) begin
                                preamble_cnt <= preamble_cnt + 1'b1;
                            end
                            else begin
                                // Invalid preamble
                                frame_error <= 1'b1;
                                state       <= ST_DROP;
                            end

                        end
                        else begin

                            // Seven 0x55 have been received.
                            // Next byte must be SFD = D5.
                            if (rx_data == 8'hD5) begin

                                state          <= ST_FRAME;

                                frame_byte_cnt <= 16'd0;
                                data_byte_cnt  <= 16'd0;

                                delay_count    <= 3'd0;

                                crc_reg        <= 32'hFFFFFFFF;

                                dst_mac        <= 48'd0;
                                src_mac        <= 48'd0;
                                eth_type       <= 16'd0;

                                frame_start    <= 1'b1;

                            end
                            else begin

                                frame_error <= 1'b1;
                                state       <= ST_DROP;

                            end
                        end
                    end
                end

                // =================================================
                // FRAME
                //
                // Everything after SFD enters the four-byte pipeline.
                //
                // delay3 is released once at least four newer bytes
                // have already arrived.
                // =================================================

                ST_FRAME: begin

                    if (rx_valid) begin

                        if (rx_error) begin

                            frame_error <= 1'b1;
                            state       <= ST_DROP;

                        end
                        else begin

                            // -----------------------------------------
                            // Shift four-byte pipeline
                            // -----------------------------------------

                            delay3 <= delay2;
                            delay2 <= delay1;
                            delay1 <= delay0;
                            delay0 <= rx_data;

                            frame_byte_cnt <= frame_byte_cnt + 1'b1;

                            if (delay_count < 3'd4) begin

                                delay_count <= delay_count + 1'b1;

                            end
                            else begin

                                // -------------------------------------
                                // delay3 is now guaranteed NOT to be FCS
                                // -------------------------------------

                                crc_reg <= crc32_byte(crc_reg, delay3);

                                // -------------------------------------
                                // Parse Ethernet header
                                //
                                // data_byte_cnt counts bytes starting
                                // from destination MAC byte 0.
                                // -------------------------------------

                                case (data_byte_cnt)

                                    // Destination MAC
                                    16'd0:
                                        dst_mac[47:40] <= delay3;

                                    16'd1:
                                        dst_mac[39:32] <= delay3;

                                    16'd2:
                                        dst_mac[31:24] <= delay3;

                                    16'd3:
                                        dst_mac[23:16] <= delay3;

                                    16'd4:
                                        dst_mac[15:8] <= delay3;

                                    16'd5:
                                        dst_mac[7:0] <= delay3;


                                    // Source MAC
                                    16'd6:
                                        src_mac[47:40] <= delay3;

                                    16'd7:
                                        src_mac[39:32] <= delay3;

                                    16'd8:
                                        src_mac[31:24] <= delay3;

                                    16'd9:
                                        src_mac[23:16] <= delay3;

                                    16'd10:
                                        src_mac[15:8] <= delay3;

                                    16'd11:
                                        src_mac[7:0] <= delay3;


                                    // EtherType
                                    16'd12:
                                        eth_type[15:8] <= delay3;

                                    16'd13: begin
                                        eth_type[7:0] <= delay3;
                                        if({eth_type[15:8],delay3} != 16'h0806 && dst_mac != LOCAL_MAC)
                                            state       <= ST_DROP;
                                        end
                                    default: begin

                                        // Payload begins from byte 14
                                        payload_data  <= delay3;
                                        payload_valid <= 1'b1;

                                    end

                                endcase

                                data_byte_cnt <= data_byte_cnt + 1'b1;

                            end
                        end
                    end
                    else begin

                        // ---------------------------------------------
                        // rx_valid falling means frame has ended.
                        //
                        // The remaining four bytes in delay registers
                        // are received FCS.
                        // ---------------------------------------------

                        //state <= ST_END;
                            
                            
                        frame_done <= 1'b1;
    
                        // At least:
                        //
                        // 6 dst
                        // 6 src
                        // 2 type
                        // 46 payload
                        // 4 FCS
                        //
                        // = 64 bytes
                        //
                        // We only enforce existence of header + FCS here
                        // because runt frames may be useful for debugging.
                        //
                        if (frame_byte_cnt < 16'd18) begin
    
                            frame_error <= 1'b1;
                            crc_error   <= 1'b1;
    
                        end
                        else begin
    
                            // ---------------------------------------------
                            // CRC comparison
                            //
                            // crc_reg contains CRC state after all bytes
                            // except FCS.
                            //
                            // Ethernet transmits:
                            //
                            // ~crc_reg
                            //
                            // least significant byte first.
                            //
                            // delay3 = FCS byte 0
                            // delay2 = FCS byte 1
                            // delay1 = FCS byte 2
                            // delay0 = FCS byte 3
                            // ---------------------------------------------
    
                            if ({
                                    delay0,
                                    delay1,
                                    delay2,
                                    delay3
                                } != ~crc_reg) begin
    
                                crc_error   <= 1'b1;
                                frame_error <= 1'b1;
    
                            end
                            else begin
    
                                crc_error <= 1'b0;
    
                            end
                        end
    
                        state <= ST_IDLE;
    
                        end
                    end

                // =================================================
                // END
                //
                // Validate frame length and CRC.
                // =================================================

                /*ST_END: begin

                    frame_done <= 1'b1;
                    end
                */

                // =================================================
                // DROP
                //
                // Ignore the rest of the current frame.
                // Wait until rx_valid goes low.
                // =================================================

                ST_DROP: begin

                    payload_valid <= 1'b0;

                    if (!rx_valid) begin

                        frame_done  <= 1'b1;
                        state       <= ST_IDLE;

                    end
                end

                default: begin
                    state <= ST_IDLE;
                end

            endcase
        end
    end

endmodule
