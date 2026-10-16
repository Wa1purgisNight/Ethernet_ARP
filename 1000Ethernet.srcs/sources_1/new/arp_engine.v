`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/08/13 03:05:25
// Design Name: 
// Module Name: arp_engine
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


module arp_engine #(
    parameter [47:0] LOCAL_MAC = 48'h02_00_00_00_00_01,
    parameter [31:0] LOCAL_IP  = 32'hC0_A8_01_7B
)(
    // ============================================================
    // RX clock domain
    // ============================================================

    input  wire        rx_clk,
    input  wire        rst_n,

    // From eth_mac_rx
    input  wire [15:0] rx_eth_type,

    input  wire [7:0]  rx_payload_data,
    input  wire        rx_payload_valid,

    input  wire        rx_frame_start,
    input  wire        rx_frame_done,

    input  wire        rx_frame_error,
    input  wire        rx_crc_error,


    // ============================================================
    // TX clock domain
    // ============================================================

    input  wire        tx_clk,

    // To eth_mac_tx
    output reg         tx_start,

    output reg  [47:0] tx_dst_mac,
    output reg  [15:0] tx_eth_type,

    output reg  [7:0]  tx_payload_data,
    output reg         tx_payload_valid,
    output reg         tx_payload_last,

    // From eth_mac_tx
    input  wire        tx_payload_ready,

    input  wire        tx_busy,
    input  wire        tx_done
);


    // ============================================================
    // ARP packet format
    //
    // Byte
    //
    //  0~1   HTYPE
    //  2~3   PTYPE
    //  4     HLEN
    //  5     PLEN
    //  6~7   OPER
    //  8~13  SHA
    // 14~17  SPA
    // 18~23  THA
    // 24~27  TPA
    //
    // Total = 28 bytes
    // ============================================================


    // ============================================================
    // RX parser registers
    // ============================================================

    reg [5:0] arp_rx_cnt;

    reg [15:0] arp_htype;
    reg [15:0] arp_ptype;

    reg [7:0] arp_hlen;
    reg [7:0] arp_plen;

    reg [15:0] arp_oper;

    reg [47:0] arp_sha;
    reg [31:0] arp_spa;

    reg [47:0] arp_tha;
    reg [31:0] arp_tpa;

    reg arp_complete;
    
    

    // ============================================================
    // RX -> TX asynchronous FIFO
    //
    // FIFO data:
    //
    // [79:32] = requesting PC MAC
    // [31:0]  = requesting PC IP
    // ============================================================

    reg  [79:0] arp_fifo_wr_data;
    reg         arp_fifo_wr_en;
    wire        arp_fifo_full;

    wire [79:0] arp_fifo_rd_data;
    reg         arp_fifo_rd_en;
    wire        arp_fifo_empty;
    wire        arp_fifo_rd_valid;


    async_fifo #(
        .DATA_WIDTH (80),
        .ADDR_WIDTH (2)
    )
    u_arp_request_fifo (
        // RX domain
        .wr_clk   (rx_clk),
        .wr_rst_n (rst_n),

        .wr_data  (arp_fifo_wr_data),
        .wr_en    (arp_fifo_wr_en),
        .full     (arp_fifo_full),

        // TX domain
        .rd_clk   (tx_clk),
        .rd_rst_n (rst_n),

        .rd_data  (arp_fifo_rd_data),
        .rd_en    (arp_fifo_rd_en),
        .empty    (arp_fifo_empty),
        .rd_valid (arp_fifo_rd_valid)
    );


    // ============================================================
    // RX ARP parser
    // ============================================================

    always @(posedge rx_clk) begin

        if (!rst_n) begin

            arp_rx_cnt <= 6'd0;

            arp_htype <= 16'd0;
            arp_ptype <= 16'd0;

            arp_hlen <= 8'd0;
            arp_plen <= 8'd0;

            arp_oper <= 16'd0;

            arp_sha <= 48'd0;
            arp_spa <= 32'd0;

            arp_tha <= 48'd0;
            arp_tpa <= 32'd0;

            arp_complete <= 1'b0;

            arp_fifo_wr_data <= 80'd0;
            arp_fifo_wr_en   <= 1'b0;

        end

        else begin

            // ====================================================
            // FIFO write enable is a one-cycle pulse
            // ====================================================

            arp_fifo_wr_en <= 1'b0;


            // ====================================================
            // New Ethernet frame
            // ====================================================

            if (rx_frame_start) begin
                arp_rx_cnt <= 6'd0;

                arp_htype <= 16'd0;
                arp_ptype <= 16'd0;

                arp_hlen <= 8'd0;
                arp_plen <= 8'd0;

                arp_oper <= 16'd0;

                arp_sha <= 48'd0;
                arp_spa <= 32'd0;

                arp_tha <= 48'd0;
                arp_tpa <= 32'd0;

                arp_complete <= 1'b0;

            end


            // ====================================================
            // Parse ARP payload
            // ====================================================

            if (rx_payload_valid) begin

                case (arp_rx_cnt)

                    // HTYPE
                    6'd0:
                        arp_htype[15:8] <= rx_payload_data;

                    6'd1:
                        arp_htype[7:0] <= rx_payload_data;


                    // PTYPE
                    6'd2:
                        arp_ptype[15:8] <= rx_payload_data;

                    6'd3:
                        arp_ptype[7:0] <= rx_payload_data;


                    // HLEN
                    6'd4:
                        arp_hlen <= rx_payload_data;


                    // PLEN
                    6'd5:
                        arp_plen <= rx_payload_data;


                    // OPER
                    6'd6:
                        arp_oper[15:8] <= rx_payload_data;

                    6'd7:
                        arp_oper[7:0] <= rx_payload_data;


                    // SHA
                    6'd8:
                        arp_sha[47:40] <= rx_payload_data;

                    6'd9:
                        arp_sha[39:32] <= rx_payload_data;

                    6'd10:
                        arp_sha[31:24] <= rx_payload_data;

                    6'd11:
                        arp_sha[23:16] <= rx_payload_data;

                    6'd12:
                        arp_sha[15:8] <= rx_payload_data;

                    6'd13:
                        arp_sha[7:0] <= rx_payload_data;


                    // SPA
                    6'd14:
                        arp_spa[31:24] <= rx_payload_data;

                    6'd15:
                        arp_spa[23:16] <= rx_payload_data;

                    6'd16:
                        arp_spa[15:8] <= rx_payload_data;

                    6'd17:
                        arp_spa[7:0] <= rx_payload_data;


                    // THA
                    6'd18:
                        arp_tha[47:40] <= rx_payload_data;

                    6'd19:
                        arp_tha[39:32] <= rx_payload_data;

                    6'd20:
                        arp_tha[31:24] <= rx_payload_data;

                    6'd21:
                        arp_tha[23:16] <= rx_payload_data;

                    6'd22:
                        arp_tha[15:8] <= rx_payload_data;

                    6'd23:
                        arp_tha[7:0] <= rx_payload_data;


                    // TPA
                    6'd24:
                        arp_tpa[31:24] <= rx_payload_data;

                    6'd25:
                        arp_tpa[23:16] <= rx_payload_data;

                    6'd26:
                        arp_tpa[15:8] <= rx_payload_data;

                    6'd27: begin

                        arp_tpa[7:0] <= rx_payload_data;

                        arp_complete <= 1'b1;

                    end


                    // Ethernet padding:
                    // ignored
                    default: begin
                    end

                endcase


                // Only count first 28 ARP bytes.
                if (arp_rx_cnt < 6'd28)
                    arp_rx_cnt <= arp_rx_cnt + 1'b1;

            end


            // ====================================================
            // Ethernet frame finished
            //
            // CRC result is known only at frame_done.
            //
            // Only valid ARP requests are inserted into FIFO.
            // ====================================================

            if (rx_frame_done) begin
                
                if (
                    // Ethernet frame valid
                    (!rx_frame_error)          &&
                    (!rx_crc_error)            &&

                    // ARP EtherType
                    (rx_eth_type == 16'h0806) &&

                    // Full ARP header received
                    arp_complete             &&

                    // HTYPE = Ethernet
                    (arp_htype == 16'h0001)  &&

                    // PTYPE = IPv4
                    (arp_ptype == 16'h0800)  &&

                    // HLEN = 6
                    (arp_hlen == 8'd6)       &&

                    // PLEN = 4
                    (arp_plen == 8'd4)       &&

                    // OPER = ARP Request
                    (arp_oper == 16'h0001)   &&

                    // Request is asking for our IP
                    (arp_tpa == LOCAL_IP)    &&

                    // FIFO has space
                    (!arp_fifo_full)
                ) begin

                    // ------------------------------------------------
                    // Save requesting PC information into async FIFO.
                    //
                    // SHA = PC MAC
                    // SPA = PC IP
                    // ------------------------------------------------

                    arp_fifo_wr_data <= {
                        arp_sha,
                        arp_spa
                    };

                    arp_fifo_wr_en <= 1'b1;

                end

            end

        end

    end


    // ============================================================
    // TX-side state
    // ============================================================

    reg [47:0] target_mac;
    reg [31:0] target_ip;

    reg reply_pending;
    reg reply_active;

    reg fifo_read_pending;

    reg [5:0] arp_tx_cnt;


    // ============================================================
    // TX control
    // ============================================================

    always @(posedge tx_clk) begin

        if (!rst_n) begin

            target_mac <= 48'd0;
            target_ip  <= 32'd0;

            reply_pending <= 1'b0;
            reply_active  <= 1'b0;

            fifo_read_pending <= 1'b0;

            arp_fifo_rd_en <= 1'b0;

            tx_start <= 1'b0;

            tx_dst_mac   <= 48'd0;
            tx_eth_type  <= 16'h0806;

            arp_tx_cnt <= 6'd0;

        end

        else begin

            // ====================================================
            // Pulse signals default low
            // ====================================================

            tx_start       <= 1'b0;
            arp_fifo_rd_en <= 1'b0;


            // ====================================================
            // Fetch next ARP request from asynchronous FIFO
            //
            // Only one request is held locally at a time.
            // ====================================================

            if (
                !reply_pending      &&
                !reply_active       &&
                !fifo_read_pending  &&
                !arp_fifo_empty
            ) begin

                arp_fifo_rd_en <= 1'b1;

                fifo_read_pending <= 1'b1;

            end


            // ====================================================
            // FIFO returned one request
            // ====================================================

            if (arp_fifo_rd_valid) begin

                target_mac <= arp_fifo_rd_data[79:32];
                target_ip  <= arp_fifo_rd_data[31:0];

                reply_pending <= 1'b1;

                fifo_read_pending <= 1'b0;

            end


            // ====================================================
            // Start ARP Reply Ethernet frame
            // ====================================================

            if (
                reply_pending &&
                !tx_busy      &&
                !reply_active
            ) begin

                // Ethernet destination = requesting PC
                tx_dst_mac <= target_mac;

                // EtherType = ARP
                tx_eth_type <= 16'h0806;

                arp_tx_cnt <= 6'd0;

                tx_start <= 1'b1;

                reply_pending <= 1'b0;
                reply_active  <= 1'b1;

            end


            // ====================================================
            // Advance payload byte counter only after handshake
            // ====================================================

            if (
                reply_active       &&
                tx_payload_valid   &&
                tx_payload_ready   &&
                (arp_tx_cnt < 6'd28)
            ) begin

                arp_tx_cnt <= arp_tx_cnt + 1'b1;

            end


            // ====================================================
            // Ethernet MAC finished frame transmission
            // ====================================================

            if (tx_done) begin

                reply_active <= 1'b0;

                arp_tx_cnt <= 6'd0;

            end

        end

    end


    // ============================================================
    // ARP Reply payload generator
    //
    // ARP Reply:
    //
    // HTYPE = 0001
    // PTYPE = 0800
    // HLEN  = 06
    // PLEN  = 04
    // OPER  = 0002
    //
    // SHA = FPGA MAC
    // SPA = FPGA IP
    //
    // THA = requesting PC MAC
    // TPA = requesting PC IP
    //
    // Total = 28 bytes
    // ============================================================

    always @(*) begin

        tx_payload_data  = 8'h00;
        tx_payload_valid = 1'b0;
        tx_payload_last  = 1'b0;


        // ========================================================
        // IMPORTANT:
        //
        // valid does NOT depend on ready.
        //
        // If ready = 0, current data and counter remain unchanged.
        // ========================================================

        if (
            reply_active &&
            (arp_tx_cnt < 6'd28)
        ) begin

            tx_payload_valid = 1'b1;


            case (arp_tx_cnt)

                // =============================================
                // HTYPE = Ethernet = 0001
                // =============================================

                6'd0:
                    tx_payload_data = 8'h00;

                6'd1:
                    tx_payload_data = 8'h01;


                // =============================================
                // PTYPE = IPv4 = 0800
                // =============================================

                6'd2:
                    tx_payload_data = 8'h08;

                6'd3:
                    tx_payload_data = 8'h00;


                // =============================================
                // HLEN = 6
                // =============================================

                6'd4:
                    tx_payload_data = 8'h06;


                // =============================================
                // PLEN = 4
                // =============================================

                6'd5:
                    tx_payload_data = 8'h04;


                // =============================================
                // OPER = ARP Reply = 0002
                // =============================================

                6'd6:
                    tx_payload_data = 8'h00;

                6'd7:
                    tx_payload_data = 8'h02;


                // =============================================
                // SHA = FPGA MAC
                // =============================================

                6'd8:
                    tx_payload_data = LOCAL_MAC[47:40];

                6'd9:
                    tx_payload_data = LOCAL_MAC[39:32];

                6'd10:
                    tx_payload_data = LOCAL_MAC[31:24];

                6'd11:
                    tx_payload_data = LOCAL_MAC[23:16];

                6'd12:
                    tx_payload_data = LOCAL_MAC[15:8];

                6'd13:
                    tx_payload_data = LOCAL_MAC[7:0];


                // =============================================
                // SPA = FPGA IP
                // =============================================

                6'd14:
                    tx_payload_data = LOCAL_IP[31:24];

                6'd15:
                    tx_payload_data = LOCAL_IP[23:16];

                6'd16:
                    tx_payload_data = LOCAL_IP[15:8];

                6'd17:
                    tx_payload_data = LOCAL_IP[7:0];


                // =============================================
                // THA = PC MAC
                // =============================================

                6'd18:
                    tx_payload_data = target_mac[47:40];

                6'd19:
                    tx_payload_data = target_mac[39:32];

                6'd20:
                    tx_payload_data = target_mac[31:24];

                6'd21:
                    tx_payload_data = target_mac[23:16];

                6'd22:
                    tx_payload_data = target_mac[15:8];

                6'd23:
                    tx_payload_data = target_mac[7:0];


                // =============================================
                // TPA = PC IP
                // =============================================

                6'd24:
                    tx_payload_data = target_ip[31:24];

                6'd25:
                    tx_payload_data = target_ip[23:16];

                6'd26:
                    tx_payload_data = target_ip[15:8];

                6'd27: begin

                    tx_payload_data = target_ip[7:0];

                    tx_payload_last = 1'b1;

                end


                default:
                    tx_payload_data = 8'h00;

            endcase

        end

    end


endmodule
