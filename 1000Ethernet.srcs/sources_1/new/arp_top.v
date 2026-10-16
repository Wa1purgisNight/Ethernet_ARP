`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/08/13 03:45:08
// Design Name: 
// Module Name: arp_top
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


module arp_top #(
    parameter integer CLK_FREQUENCY = 100_000_000,
    parameter integer MDC_FREQUENCY = 2_500_000,
    parameter [4:0]   PHY_ADDR      = 5'b00101,

    // FPGA Ethernet information
    parameter [47:0] LOCAL_MAC = 48'h02_00_00_00_00_01,
    parameter [31:0] LOCAL_IP  = 32'hC0_A8_01_7B      // 192.168.1.10
)(
    input  wire        clk_50M,
    input  wire        rst_n,

    //============================================================
    // PHY Reset
    //============================================================
    output wire        rst_out,

    //============================================================
    // PHY ID read
    //============================================================
    input  wire        phy_id_start,

    //============================================================
    // MDIO
    //============================================================
    output wire        phy_mdc,
    inout  wire        phy_mdio,

    //============================================================
    // RGMII RX
    //============================================================
    input  wire        tp_rgmii_rxc,
    input  wire [3:0]  tp_rgmii_rxd,
    input  wire        tp_rgmii_rx_ctl,

    //============================================================
    // RGMII TX
    //============================================================
    output wire        tp_rgmii_txc,
    output wire [3:0]  tp_rgmii_txd,
    output wire        tp_rgmii_tx_ctl
);


    //============================================================
    // Clock generation
    //============================================================


    wire locked_2;

    clk_wiz_1 u_clk_wiz_1 (
        .clk_in1  (tp_rgmii_rxc),
        .locked   (locked_2),
        .clk_out1 (clk_rx_125M)
    );

    wire clk;
    wire clk_125M;
    wire tx_clk_oddr;
    wire locked;

    clk_wiz_0 u_clk_wiz (
        .clk_in1  (clk_50M),
        .locked   (locked),
        .clk_out1 (clk),
        .clk_out2 (clk_125M),
        .clk_out3 (tx_clk_oddr)
    );
    



    //============================================================
    // MDIO command interface
    //============================================================

    wire        mdio_cmd_start;
    wire        mdio_cmd_rw;
    wire [4:0]  mdio_cmd_phy_addr;
    wire [4:0]  mdio_cmd_reg_addr;
    wire [15:0] mdio_cmd_write_data;


    //============================================================
    // MDIO Master return interface
    //============================================================

    wire [15:0] mdio_read_data;
    wire        mdio_busy;
    wire        mdio_write_done;
    wire        mdio_read_valid;
    wire        mdio_error;


    //============================================================
    // PHY ID
    //============================================================

    wire [15:0] phy_id1;
    wire [15:0] phy_id2;
    wire [31:0] phy_id;

    wire        phy_id_busy;
    wire        phy_id_valid;
    wire        phy_id_error;


    //============================================================
    // PHY reset
    //============================================================

    wire rst_complete;
    wire INITIAL_CONFIG_PULSE;


    //============================================================
    // MDIO tri-state
    //============================================================

    wire mdio_out;
    wire mdio_oe;
    wire mdio_in;


    IOBUF u_mdio_iobuf (
        .I  (mdio_out),
        .O  (mdio_in),
        .T  (~mdio_oe),
        .IO (phy_mdio)
    );


    //============================================================
    // phy_id_start rising edge detection
    //============================================================

    reg phy_id_start_d;

    wire phy_id_start_posedge;

    always @(posedge clk) begin
        if (!rst_n)
            phy_id_start_d <= 1'b0;
        else
            phy_id_start_d <= phy_id_start;
    end

    assign phy_id_start_posedge =
        phy_id_start & ~phy_id_start_d;


    //============================================================
    // PHY ID Reader
    //============================================================

    phy_id_reader #(
        .PHY_ADDR(PHY_ADDR)
    ) u_phy_id_reader (
        .clk             (clk),
        .rst_n           (rst_n),

        .start           (phy_id_start_posedge),

        .mdio_start      (mdio_cmd_start),
        .mdio_rw         (mdio_cmd_rw),
        .mdio_phy_addr   (mdio_cmd_phy_addr),
        .mdio_reg_addr   (mdio_cmd_reg_addr),
        .mdio_write_data (mdio_cmd_write_data),

        .mdio_read_data  (mdio_read_data),
        .mdio_busy       (mdio_busy),
        .mdio_write_done (mdio_write_done),
        .mdio_read_valid (mdio_read_valid),
        .mdio_error      (mdio_error),

        .phy_id1         (phy_id1),
        .phy_id2         (phy_id2),
        .phy_id          (phy_id),

        .busy            (phy_id_busy),
        .valid           (phy_id_valid),
        .error           (phy_id_error)
    );


    //============================================================
    // Clause 22 MDIO Master
    //============================================================

    mdio_master #(
        .CLK_FREQUENCY(CLK_FREQUENCY),
        .MDC_FREQUENCY(MDC_FREQUENCY)
    ) u_mdio_master (
        .clk        (clk),
        .rst_n      (rst_n),

        .start      (mdio_cmd_start),
        .rw         (mdio_cmd_rw),
        .phy_addr   (mdio_cmd_phy_addr),
        .reg_addr   (mdio_cmd_reg_addr),
        .write_data (mdio_cmd_write_data),

        .read_data  (mdio_read_data),
        .busy       (mdio_busy),
        .write_done (mdio_write_done),
        .read_valid (mdio_read_valid),
        .ta_error   (mdio_error),

        .mdc        (phy_mdc),

        .mdio_o     (mdio_out),
        .mdio_oe    (mdio_oe),
        .mdio_i     (mdio_in)
    );


    //============================================================
    // PHY reset controller
    //============================================================

    rst_sync #(
        .CLK_FREQUENCY      (CLK_FREQUENCY),
        .RST_HOLDTIME_ms    (10),
        .RST_RELEASETIME_ms (30)
    ) u_rst_sync (
        .clk                  (clk),
        .rst_start            (~rst_n),

        .rst_out              (rst_out),

        .rst_complete         (rst_complete),

        .INITIAL_CONFIG_PULSE (INITIAL_CONFIG_PULSE)
    );


    //============================================================
    //
    // RGMII RX
    //
    //============================================================

    wire       tp_rx_clk;
    wire [7:0] tp_rx_data;
    wire       tp_rx_valid;
    wire       tp_rx_error;


    rgmii_rx u_rgmii_rx (
        /*.pll_locked      (locked),
        .clk_200M        (clk_200M),*/

        .rgmii_rxc       (clk_rx_125M),
        .rgmii_rxd       (tp_rgmii_rxd),
        .rgmii_rx_ctl    (tp_rgmii_rx_ctl),

        .rx_clk          (tp_rx_clk),
        .rx_data_reg     (tp_rx_data),
        .rx_valid_reg    (tp_rx_valid),
        .rx_error_reg    (tp_rx_error)
    );


    //============================================================
    //
    // Ethernet MAC RX
    //
    //============================================================

    wire [47:0] mac_rx_dst_mac;
    wire [47:0] mac_rx_src_mac;
    wire [15:0] mac_rx_eth_type;

    wire [7:0]  mac_rx_payload_data;
    wire        mac_rx_payload_valid;

    wire        mac_rx_frame_start;
    wire        mac_rx_frame_done;
    wire        mac_rx_frame_error;
    wire        mac_rx_crc_error;


    eth_mac_rx #(
        .LOCAL_MAC(LOCAL_MAC)
    ) u_eth_mac_rx (
        .rx_clk          (tp_rx_clk),
        .rst_n           (rst_n),

        // From RGMII RX
        .rx_data         (tp_rx_data),
        .rx_valid        (tp_rx_valid),
        .rx_error        (tp_rx_error),

        // Ethernet header
        .dst_mac         (mac_rx_dst_mac),
        .src_mac         (mac_rx_src_mac),
        .eth_type        (mac_rx_eth_type),

        // Ethernet payload
        .payload_data    (mac_rx_payload_data),
        .payload_valid   (mac_rx_payload_valid),

        // Frame status
        .frame_start     (mac_rx_frame_start),
        .frame_done      (mac_rx_frame_done),
        .frame_error     (mac_rx_frame_error),
        .crc_error       (mac_rx_crc_error)
    );


    //============================================================
    //
    // ARP Engine -> Ethernet MAC TX
    //
    //============================================================

    wire        arp_tx_start;

    wire [47:0] arp_tx_dst_mac;
    wire [47:0] arp_tx_src_mac;
    wire [15:0] arp_tx_eth_type;

    wire [7:0]  arp_tx_payload_data;
    wire        arp_tx_payload_valid;

    wire        arp_tx_payload_ready;



    arp_engine #(
        .LOCAL_MAC (LOCAL_MAC),
        .LOCAL_IP  (LOCAL_IP)
    )
    u_arp_engine (
        .rx_clk             (tp_rx_clk),
        .rst_n              (rst_n),

        .rx_eth_type        (mac_rx_eth_type),
        .rx_payload_data    (mac_rx_payload_data),
        .rx_payload_valid   (mac_rx_payload_valid),

        .rx_frame_start     (mac_rx_frame_start),
        .rx_frame_done      (mac_rx_frame_done),
        .rx_frame_error     (mac_rx_frame_error),
        .rx_crc_error       (mac_rx_crc_error),

        .tx_clk             (clk_125M),

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


    //============================================================
    //
    // Ethernet MAC TX
    //
    //============================================================

    (* mark_debug = "true" *)wire [7:0] mac_tx_data;
    (* mark_debug = "true" *)wire       mac_tx_valid;
    (* mark_debug = "true" *)wire       mac_tx_error;

    wire       mac_tx_busy;
    wire       mac_tx_done;


    eth_mac_tx u_eth_mac_tx (
        .tx_clk           (clk_125M),
        .rst_n            (rst_n),

        //========================================================
        // Frame request from ARP
        //========================================================

        .tx_start         (arp_tx_start),

        .dst_mac          (arp_tx_dst_mac),
        .eth_type         (arp_tx_eth_type),

        //========================================================
        // Payload from ARP
        //========================================================

        .payload_data     (arp_tx_payload_data),
        .payload_valid    (arp_tx_payload_valid),
        .payload_last   (arp_tx_payload_last),

        .payload_ready    (mac_tx_payload_ready),

        //========================================================
        // Frame TX
        //========================================================

        .tx_data          (mac_tx_data),
        .tx_valid         (mac_tx_valid),
        .tx_error         (mac_tx_error),

        .tx_busy          (mac_tx_busy),
        .tx_done          (mac_tx_done)
    );


    /*eth_send_test u_eth_send_test(
        .rst_n(rst_n),
        
        .gmii_tx_clk(clk_125M),
        .gmii_tx_en(mac_tx_valid),
        .gmii_tx_er(mac_tx_error),
        .gmii_tx_data(mac_tx_data)

    );*/


    //============================================================
    //
    // RGMII TX
    //
    //============================================================

    rgmii_tx u_rgmii_tx (
        .tx_clk           (clk_125M),
        .tx_clk_oddr      (tx_clk_oddr),
        .tx_data          (mac_tx_data),
        .tx_valid         (mac_tx_valid),
        .tx_error         (mac_tx_error),

        .rgmii_txc        (tp_rgmii_txc),
        .rgmii_txd        (tp_rgmii_txd),
        .rgmii_tx_ctl     (tp_rgmii_tx_ctl)
    );


endmodule
