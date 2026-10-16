`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/08/13 02:44:04
// Design Name: 
// Module Name: eth_mac_tx
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


module eth_mac_tx #(
    parameter [47:0] LOCAL_MAC = 48'h02_00_00_00_00_01
)(
    input  wire        tx_clk,
    input  wire        rst_n,

    // ============================================================
    // Upper-layer frame request
    // ============================================================

    input  wire        tx_start,

    input  wire [47:0] dst_mac,
    input  wire [15:0] eth_type,

    // ============================================================
    // Payload input
    // ============================================================

    input  wire [7:0]  payload_data,
    input  wire        payload_valid,
    input  wire        payload_last,

    output wire        payload_ready,

    // ============================================================
    // To rgmii_tx
    // ============================================================

    output reg  [7:0]  tx_data,
    output reg         tx_valid,
    output reg         tx_error,

    // ============================================================
    // Status
    // ============================================================

    output reg         tx_busy,
    output reg         tx_done
);


    // ============================================================
    // FSM
    // ============================================================

    localparam ST_IDLE     = 3'd0;
    localparam ST_PREAMBLE = 3'd1;
    localparam ST_SFD      = 3'd2;
    localparam ST_HEADER   = 3'd3;
    localparam ST_PAYLOAD  = 3'd4;
    localparam ST_PADDING  = 3'd5;
    localparam ST_FCS      = 3'd6;
    localparam ST_DONE     = 3'd7;

    reg [2:0] state;


    // ============================================================
    // Counters
    // ============================================================

    reg [2:0] preamble_cnt;
    reg [3:0] header_cnt;
    reg [2:0] fcs_cnt;

    /*
     * Count bytes from Destination MAC through Payload/Padding.
     *
     * Ethernet minimum:
     *
     * DST MAC           6
     * SRC MAC           6
     * EtherType         2
     * Payload + Pad    46
     * -------------------
     *                  60 bytes
     *
     * + FCS             4
     * -------------------
     *                  64 bytes
     *
     * Preamble + SFD are not counted.
     */
    reg [15:0] frame_byte_cnt;


    // ============================================================
    // Latched Ethernet header
    // ============================================================

    reg [47:0] dst_mac_reg;
    reg [15:0] eth_type_reg;


    // ============================================================
    // CRC
    // ============================================================

    reg [31:0] crc_reg;
    reg [31:0] fcs_reg;


    // ============================================================
    // Ethernet CRC32
    //
    // reflected polynomial:
    //
    // 0xEDB88320
    //
    // initial:
    //
    // 0xFFFFFFFF
    //
    // final:
    //
    // ~crc
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

                if (crc[0] ^ data[0])
                    crc = (crc >> 1) ^ 32'hEDB88320;
                else
                    crc = crc >> 1;

                data = data >> 1;

            end

            crc32_byte = crc;

        end

    endfunction


    // ============================================================
    // Ethernet Header byte generator
    //
    // 0 ~ 5   Destination MAC
    // 6 ~ 11  Source MAC = LOCAL_MAC
    // 12~13   EtherType
    // ============================================================

    reg [7:0] header_byte;

    always @(*) begin

        case (header_cnt)

            // Destination MAC
            4'd0:  header_byte = dst_mac_reg[47:40];
            4'd1:  header_byte = dst_mac_reg[39:32];
            4'd2:  header_byte = dst_mac_reg[31:24];
            4'd3:  header_byte = dst_mac_reg[23:16];
            4'd4:  header_byte = dst_mac_reg[15:8];
            4'd5:  header_byte = dst_mac_reg[7:0];

            // Source MAC
            4'd6:  header_byte = LOCAL_MAC[47:40];
            4'd7:  header_byte = LOCAL_MAC[39:32];
            4'd8:  header_byte = LOCAL_MAC[31:24];
            4'd9:  header_byte = LOCAL_MAC[23:16];
            4'd10: header_byte = LOCAL_MAC[15:8];
            4'd11: header_byte = LOCAL_MAC[7:0];

            // EtherType
            4'd12: header_byte = eth_type_reg[15:8];
            4'd13: header_byte = eth_type_reg[7:0];

            default:
                header_byte = 8'h00;

        endcase

    end


    // ============================================================
    // Payload handshake
    // ============================================================

    assign payload_ready = (state == ST_PAYLOAD);


    // ============================================================
    // Main FSM
    // ============================================================

    always @(posedge tx_clk) begin

        if (!rst_n) begin

            state <= ST_IDLE;

            tx_data  <= 8'h00;
            tx_valid <= 1'b0;
            tx_error <= 1'b0;

            tx_busy <= 1'b0;
            tx_done <= 1'b0;

            dst_mac_reg  <= 48'd0;
            eth_type_reg <= 16'd0;

            preamble_cnt <= 3'd0;
            header_cnt   <= 4'd0;
            fcs_cnt      <= 3'd0;

            frame_byte_cnt <= 16'd0;

            crc_reg <= 32'hFFFFFFFF;
            fcs_reg <= 32'd0;

        end

        else begin

            // pulse output
            tx_done <= 1'b0;

            case (state)

                // =================================================
                // IDLE
                // =================================================

                ST_IDLE: begin

                    tx_data  <= 8'h00;
                    tx_valid <= 1'b0;
                    tx_error <= 1'b0;

                    tx_busy <= 1'b0;

                    preamble_cnt  <= 3'd0;
                    header_cnt    <= 4'd0;
                    fcs_cnt       <= 3'd0;

                    frame_byte_cnt <= 16'd0;

                    crc_reg <= 32'hFFFFFFFF;

                    if (tx_start) begin

                        dst_mac_reg  <= dst_mac;
                        eth_type_reg <= eth_type;

                        tx_busy <= 1'b1;

                        state <= ST_PREAMBLE;

                    end

                end


                // =================================================
                // PREAMBLE
                //
                // 7 × 0x55
                // =================================================

                ST_PREAMBLE: begin

                    tx_valid <= 1'b1;
                    tx_data  <= 8'h55;

                    if (preamble_cnt == 3'd6) begin

                        preamble_cnt <= 3'd0;

                        state <= ST_SFD;

                    end

                    else begin

                        preamble_cnt <= preamble_cnt + 1'b1;

                    end

                end


                // =================================================
                // SFD
                //
                // D5
                // =================================================

                ST_SFD: begin

                    tx_valid <= 1'b1;
                    tx_data  <= 8'hD5;

                    header_cnt     <= 4'd0;
                    frame_byte_cnt <= 16'd0;

                    crc_reg <= 32'hFFFFFFFF;

                    state <= ST_HEADER;

                end


                // =================================================
                // Ethernet Header
                // =================================================

                ST_HEADER: begin

                    tx_valid <= 1'b1;

                    tx_data <= header_byte;

                    // CRC starts from Destination MAC
                    crc_reg <= crc32_byte(
                        crc_reg,
                        header_byte
                    );

                    frame_byte_cnt <= frame_byte_cnt + 1'b1;


                    if (header_cnt == 4'd13) begin

                        header_cnt <= 4'd0;

                        state <= ST_PAYLOAD;

                    end

                    else begin

                        header_cnt <= header_cnt + 1'b1;

                    end

                end


                // =================================================
                // Payload
                //
                // IMPORTANT:
                //
                // Ethernet transmission cannot pause once TX_EN is
                // asserted. Therefore payload_valid must remain
                // continuous while this state is active.
                // =================================================

                ST_PAYLOAD: begin

                    if (payload_valid) begin

                        tx_valid <= 1'b1;
                        tx_data  <= payload_data;

                        crc_reg <= crc32_byte(
                            crc_reg,
                            payload_data
                        );

                        frame_byte_cnt <= frame_byte_cnt + 1'b1;


                        if (payload_last) begin

                            /*
                             * frame_byte_cnt is the number of bytes
                             * before this current payload byte.
                             *
                             * Therefore +1 includes the current byte.
                             */

                            if ((frame_byte_cnt + 1'b1) < 16'd60) begin

                                state <= ST_PADDING;

                            end

                            else begin

                                /*
                                 * No padding required.
                                 *
                                 * Current byte is the last CRC-covered
                                 * Ethernet byte.
                                 */

                                fcs_reg <= ~crc32_byte(
                                    crc_reg,
                                    payload_data
                                );

                                fcs_cnt <= 3'd0;

                                state <= ST_FCS;

                            end

                        end

                    end

                    else begin

                        /*
                         * Ethernet does NOT support inserting idle
                         * cycles in the middle of a frame.
                         *
                         * This condition therefore means that the
                         * upstream protocol violated the interface.
                         */

                        tx_valid <= 1'b0;
                        tx_error <= 1'b1;

                        state <= ST_DONE;

                    end

                end


                // =================================================
                // Padding
                //
                // Pad with zero until:
                //
                // DST + SRC + TYPE + PAYLOAD + PAD = 60 bytes
                // =================================================

                ST_PADDING: begin

                    tx_valid <= 1'b1;
                    tx_data  <= 8'h00;

                    crc_reg <= crc32_byte(
                        crc_reg,
                        8'h00
                    );

                    frame_byte_cnt <= frame_byte_cnt + 1'b1;


                    /*
                     * If current count is 59,
                     *
                     * this cycle transmits byte 60.
                     */

                    if (frame_byte_cnt == 16'd59) begin

                        fcs_reg <= ~crc32_byte(
                            crc_reg,
                            8'h00
                        );

                        fcs_cnt <= 3'd0;

                        state <= ST_FCS;

                    end

                end


                // =================================================
                // FCS
                //
                // Ethernet sends CRC low byte first.
                //
                // fcs_reg[7:0]
                // fcs_reg[15:8]
                // fcs_reg[23:16]
                // fcs_reg[31:24]
                // =================================================

                ST_FCS: begin

                    tx_valid <= 1'b1;

                    case (fcs_cnt)

                        3'd0:
                            tx_data <= fcs_reg[7:0];

                        3'd1:
                            tx_data <= fcs_reg[15:8];

                        3'd2:
                            tx_data <= fcs_reg[23:16];

                        3'd3:
                            tx_data <= fcs_reg[31:24];

                        default:
                            tx_data <= 8'h00;

                    endcase


                    if (fcs_cnt == 3'd3) begin

                        fcs_cnt <= 3'd0;

                        state <= ST_DONE;

                    end

                    else begin

                        fcs_cnt <= fcs_cnt + 1'b1;

                    end

                end


                // =================================================
                // DONE
                // =================================================

                ST_DONE: begin

                    tx_valid <= 1'b0;
                    tx_data  <= 8'h00;

                    tx_busy <= 1'b0;
                    tx_done <= 1'b1;

                    state <= ST_IDLE;

                end


                default: begin

                    state <= ST_IDLE;

                    tx_valid <= 1'b0;
                    tx_busy  <= 1'b0;

                end

            endcase

        end

    end


endmodule