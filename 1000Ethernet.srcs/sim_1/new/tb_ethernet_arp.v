`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/08/13 03:11:48
// Design Name: 
// Module Name: tb_ethernet_arp
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


module tb_ethernet_arp;

    // ============================================================
    // Parameters
    // ============================================================

    localparam [47:0] LOCAL_MAC = 48'h02_00_00_00_00_01;
    localparam [31:0] LOCAL_IP  = 32'hC0_A8_01_0A;   // 192.168.1.10


    // ============================================================
    // Reset / Clock
    // ============================================================

    reg rst_n;
    reg clk_200M;
    reg tx_clk;


    // ============================================================
    // RGMII RX
    // ============================================================

    reg        rgmii_rxc;
    wire       rgmii_rxc_rc;
    reg [3:0]  rgmii_rxd;
    reg        rgmii_rx_ctl;

    wire       rx_clk;
    wire [7:0] rx_data;
    wire       rx_dv;
    wire       rx_er;


    // ============================================================
    // eth_mac_rx
    // ============================================================

    wire [47:0] dst_mac;
    wire [47:0] src_mac;
    wire [15:0] eth_type;

    wire [7:0] frame_data;
    wire       frame_valid;

    wire       frame_start;
    wire       frame_end;
    wire       frame_error;
    wire       crc_error;


    // ============================================================
    // arp_engine -> eth_mac_tx
    // ============================================================

    wire        arp_tx_start;
    wire [47:0] arp_tx_dst_mac;
    wire [15:0] arp_tx_eth_type;

    wire [7:0]  arp_tx_payload_data;
    wire        arp_tx_payload_valid;
    wire        arp_tx_payload_last;


    // ============================================================
    // eth_mac_tx -> arp_engine
    // ============================================================

    wire mac_tx_payload_ready;
    wire mac_tx_busy;
    wire mac_tx_done;


    // ============================================================
    // eth_mac_tx output
    //
    // 暂时不连接 rgmii_tx
    // ============================================================

    wire [7:0] mac_tx_data;
    wire       mac_tx_valid;
    wire       mac_tx_error;


    // ============================================================
    // RGMII RX
    // ============================================================

    rgmii_rx u_rgmii_rx (
        .clk_200M       (clk_200M),
        .pll_locked     (rst_n),

        .rgmii_rxc      (rgmii_rxc_rc),
        .rgmii_rxd      (rgmii_rxd),
        .rgmii_rx_ctl   (rgmii_rx_ctl),

        .rx_clk         (rx_clk),
        .rx_data_reg    (rx_data),
        .rx_valid_reg   (rx_dv),
        .rx_error_reg   (rx_er)
    );


    // ============================================================
    // Ethernet MAC RX
    // ============================================================

    eth_mac_rx #(
        .LOCAL_MAC (LOCAL_MAC)
    )
    u_eth_mac_rx (
        .rx_clk         (rx_clk),
        .rst_n          (rst_n),

        .rx_data        (rx_data),
        .rx_valid       (rx_dv),
        .rx_error       (rx_er),

        .dst_mac        (dst_mac),
        .src_mac        (src_mac),
        .eth_type       (eth_type),

        .payload_data   (frame_data),
        .payload_valid  (frame_valid),

        .frame_start    (frame_start),
        .frame_done     (frame_end),
        .frame_error    (frame_error),
        .crc_error      (crc_error)
    );


    // ============================================================
    // ARP Engine
    // ============================================================

    arp_engine #(
        .LOCAL_MAC (LOCAL_MAC),
        .LOCAL_IP  (LOCAL_IP)
    )
    u_arp_engine (
        .rx_clk             (rx_clk),
        .rst_n              (rst_n),

        .rx_eth_type        (eth_type),
        .rx_payload_data    (frame_data),
        .rx_payload_valid   (frame_valid),

        .rx_frame_start     (frame_start),
        .rx_frame_done      (frame_end),
        .rx_frame_error     (frame_error),
        .rx_crc_error       (crc_error),

        .tx_clk             (tx_clk),

        .tx_start           (arp_tx_start),
        .tx_dst_mac         (arp_tx_dst_mac),
        .tx_eth_type        (arp_tx_eth_type),

        .tx_payload_data    (arp_tx_payload_data),
        .tx_payload_valid   (arp_tx_payload_valid),
        .tx_payload_last    (arp_tx_payload_last),

        .tx_payload_ready   (mac_tx_payload_ready),
        .tx_busy            (mac_tx_busy),
        .tx_done            (mac_tx_done)
    );


    // ============================================================
    // Ethernet MAC TX
    // ============================================================

    eth_mac_tx #(
        .LOCAL_MAC (LOCAL_MAC)
    )
    u_eth_mac_tx (
        .tx_clk         (tx_clk),
        .rst_n          (rst_n),

        .tx_start       (arp_tx_start),

        .dst_mac        (arp_tx_dst_mac),
        .eth_type       (arp_tx_eth_type),

        .payload_data   (arp_tx_payload_data),
        .payload_valid  (arp_tx_payload_valid),
        .payload_last   (arp_tx_payload_last),

        .payload_ready  (mac_tx_payload_ready),

        .tx_data        (mac_tx_data),
        .tx_valid       (mac_tx_valid),
        .tx_error       (mac_tx_error),

        .tx_busy        (mac_tx_busy),
        .tx_done        (mac_tx_done)
    );


    // ============================================================
    // Clocks
    // ============================================================

    // 200 MHz
    initial begin
        clk_200M = 1'b0;
        forever #2.5 clk_200M = ~clk_200M;
    end


    // RGMII RX Clock = 125 MHz
    initial begin
        rgmii_rxc = 1'b0;
        forever #4 rgmii_rxc = ~rgmii_rxc;
    end


    // TX Clock = 125 MHz
    initial begin
        tx_clk = 1'b0;
        #7
        forever #4 tx_clk = ~tx_clk;
    end


    // 模拟 RGMII RX 2ns clock skew
    assign #2 rgmii_rxc_rc = rgmii_rxc;


    // ============================================================
    // Send RGMII Byte
    // ============================================================

    task send_rgmii_byte;

        input [7:0] data;
        input       dv;
        input       er;

        begin

            @(posedge rgmii_rxc);

            rgmii_rxd    = data[3:0];
            rgmii_rx_ctl = dv;

            @(negedge rgmii_rxc);

            rgmii_rxd    = data[7:4];
            rgmii_rx_ctl = dv ^ er;

        end

    endtask


    // ============================================================
    // ARP Request
    // ============================================================

    reg [7:0] arp_frame [0:71];

    integer i;


    initial begin

        // --------------------------------------------------------
        // Preamble
        // --------------------------------------------------------

        arp_frame[0] = 8'h55;
        arp_frame[1] = 8'h55;
        arp_frame[2] = 8'h55;
        arp_frame[3] = 8'h55;
        arp_frame[4] = 8'h55;
        arp_frame[5] = 8'h55;
        arp_frame[6] = 8'h55;

        // SFD
        arp_frame[7] = 8'hD5;


        // --------------------------------------------------------
        // Ethernet Header
        // --------------------------------------------------------

        // DST = Broadcast
        arp_frame[8]  = 8'hFF;
        arp_frame[9]  = 8'hFF;
        arp_frame[10] = 8'hFF;
        arp_frame[11] = 8'hFF;
        arp_frame[12] = 8'hFF;
        arp_frame[13] = 8'hFF;

        // SRC = PC MAC = 12:34:56:78:9A:BC
        arp_frame[14] = 8'h12;
        arp_frame[15] = 8'h34;
        arp_frame[16] = 8'h56;
        arp_frame[17] = 8'h78;
        arp_frame[18] = 8'h9A;
        arp_frame[19] = 8'hBC;

        // EtherType = ARP
        arp_frame[20] = 8'h08;
        arp_frame[21] = 8'h06;


        // --------------------------------------------------------
        // ARP Request
        // --------------------------------------------------------

        // HTYPE = Ethernet
        arp_frame[22] = 8'h00;
        arp_frame[23] = 8'h01;

        // PTYPE = IPv4
        arp_frame[24] = 8'h08;
        arp_frame[25] = 8'h00;

        // HLEN = 6
        arp_frame[26] = 8'h06;

        // PLEN = 4
        arp_frame[27] = 8'h04;

        // OPER = Request
        arp_frame[28] = 8'h00;
        arp_frame[29] = 8'h01;


        // SHA = PC MAC
        arp_frame[30] = 8'h12;
        arp_frame[31] = 8'h34;
        arp_frame[32] = 8'h56;
        arp_frame[33] = 8'h78;
        arp_frame[34] = 8'h9A;
        arp_frame[35] = 8'hBC;


        // SPA = PC IP = 192.168.1.100
        arp_frame[36] = 8'hC0;
        arp_frame[37] = 8'hA8;
        arp_frame[38] = 8'h01;
        arp_frame[39] = 8'h64;


        // THA = Unknown
        arp_frame[40] = 8'h00;
        arp_frame[41] = 8'h00;
        arp_frame[42] = 8'h00;
        arp_frame[43] = 8'h00;
        arp_frame[44] = 8'h00;
        arp_frame[45] = 8'h00;


        // TPA = FPGA IP = 192.168.1.10
        arp_frame[46] = 8'hC0;
        arp_frame[47] = 8'hA8;
        arp_frame[48] = 8'h01;
        arp_frame[49] = 8'h0A;


        // --------------------------------------------------------
        // Ethernet Padding
        // --------------------------------------------------------

        for (i = 50; i <= 67; i = i + 1)
            arp_frame[i] = 8'h00;


        // --------------------------------------------------------
        // FCS
        //
        // CRC = 32'h4D87AB87
        // wire order = 87 AB 87 4D
        // --------------------------------------------------------

        arp_frame[68] = 8'h87;
        arp_frame[69] = 8'hAB;
        arp_frame[70] = 8'h87;
        arp_frame[71] = 8'h4D;

    end


    // ============================================================
    // Test
    // ============================================================

    initial begin

        rst_n        = 1'b0;
        rgmii_rxd    = 4'h0;
        rgmii_rx_ctl = 1'b0;

        #100;

        rst_n = 1'b1;

        #200;


        // --------------------------------------------------------
        // Idle
        // --------------------------------------------------------

        repeat (5)
            send_rgmii_byte(8'h00, 1'b0, 1'b0);


        // --------------------------------------------------------
        // Send ARP Request
        // --------------------------------------------------------

        for (i = 0; i < 72; i = i + 1)
            send_rgmii_byte(
                arp_frame[i],
                1'b1,
                1'b0
            );


        // --------------------------------------------------------
        // End frame / Idle
        // --------------------------------------------------------

        repeat (10)
            send_rgmii_byte(8'h00, 1'b0, 1'b0);


        // 等待 ARP Reply 完成
        wait(mac_tx_done);

        #100;

        $stop;

    end


endmodule
