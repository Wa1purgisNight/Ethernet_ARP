`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/08/05 05:23:55
// Design Name: 
// Module Name: ehternet_top
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


module ethernet_top #(
    parameter integer CLK_FREQUENCY = 100_000_000,
    parameter integer MDC_FREQUENCY = 2_500_000,
    parameter [4:0]   PHY_ADDR      = 5'b00101
)(
    input  wire        clk_50M,
    input  wire        rst_n,
    
    // 同步复位接口
    // 连接 RTL8211F 的 PHYRSTB 引脚，低电平有效
    output wire  rst_out,

    
    // 拉高一个clk周期，启动PHY ID读取
    input  wire        phy_id_start,
    

    // PHY管理接口
    output wire        phy_mdc,
    inout  wire        phy_mdio,
    
    //rgmii rx接口
    input  wire       tp_rgmii_rxc,
    input  wire [3:0] tp_rgmii_rxd,
    input  wire       tp_rgmii_rx_ctl


);
    //PLL时钟生成
    
    wire clk, clk_200M, locked;
    clk_wiz_0 u_clk_wiz (
        .clk_in1(clk_50M),
        .locked(locked),
        .clk_out1(clk),
        .clk_out2(clk_200M)
    );
    
    /*wire rgmii_rxc, locked_1;
    clk_wiz_1 u_clk_wiz_1 (
        .clk_in1(tp_rgmii_rxc),
        .locked(locked_1),
        .clk_out1(rgmii_rxc)
    );*/
    
    /*debug 信号*/
    //assign debug_mdio_busy = mdio_busy;
    //wire[3:0]        reader_state;
    //wire[3:0]        mdio_state;
    /*
     * phy_id_reader与mdio_master之间的命令接口
     */
    wire        mdio_cmd_start;
    wire        mdio_cmd_rw;
    wire [4:0]  mdio_cmd_phy_addr;
    wire [4:0]  mdio_cmd_reg_addr;
    wire [15:0] mdio_cmd_write_data;

    /*
     * mdio_master返回接口
     */
    wire [15:0] mdio_read_data;
    wire        mdio_busy;
    wire        mdio_write_done;
    wire        mdio_read_valid;
    wire        mdio_error;
    
     // 读取结果
    wire [15:0] phy_id1;
    wire [15:0] phy_id2;
    wire [31:0] phy_id;
    wire        phy_id_busy;
    wire        phy_id_valid;
    wire        phy_id_error;

    /*同步复位信号*/
   // 完整复位流程结束脉冲，持续一个 clk 周期
    wire  rst_complete;
    // PHY 寄存器初始化启动脉冲，持续一个 clk 周期
    wire  INITIAL_CONFIG_PULSE;
    /*
     * MDIO三态控制信号
     */
    wire        mdio_out;
    wire        mdio_oe;
    wire        mdio_in;

    /*
     * MDIO三态输出
     *
     * mdio_oe = 1：
     * FPGA驱动phy_mdio，输出mdio_out
     *
     * mdio_oe = 0：
     * FPGA释放phy_mdio，由PHY驱动
     */
    
    /*
     * 无论FPGA还是PHY驱动MDIO，
     * mdio_master都可以通过mdio_in读取引脚电平
     */
     
    /*assign phy_mdio = mdio_oe ? mdio_out : 1'bz;
    assign mdio_in = phy_mdio;*/
    IOBUF u_mdio_iobuf (
        .I  (mdio_out),
        .O  (mdio_in),
        .T  (~mdio_oe),
        .IO (phy_mdio)
    );
    
    reg phy_id_start_d;   
    wire phy_id_start_posedge;
    always @(posedge clk) begin
        if (!rst_n) begin
            phy_id_start_d <= 1'b0;
        end
        else begin
            phy_id_start_d <= phy_id_start;
        end
    end
    assign phy_id_start_posedge = phy_id_start & ~phy_id_start_d;    //上升沿检测，防止一个start触发多次
 
    /*
     * PHY ID读取控制器
     *
     * 依次读取Clause 22寄存器2和寄存器3
     */
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

    /*
     * Clause 22 MDIO Master
     */
    mdio_master #(
        .CLK_FREQUENCY(CLK_FREQUENCY),
        .MDC_FREQUENCY(MDC_FREQUENCY)
    ) u_mdio_master (
        .clk        (clk),
        .rst_n      (rst_n),

        /*
         * 上层命令接口
         */
        .start      (mdio_cmd_start),
        .rw         (mdio_cmd_rw),
        .phy_addr   (mdio_cmd_phy_addr),
        .reg_addr   (mdio_cmd_reg_addr),
        .write_data (mdio_cmd_write_data),

        /*
         * 命令执行结果
         */
        .read_data  (mdio_read_data),
        .busy       (mdio_busy),
        .write_done (mdio_write_done),
        .read_valid (mdio_read_valid),
        .ta_error      (mdio_error),

        /*
         * PHY接口
         */
        .mdc        (phy_mdc),
        .mdio_o   (mdio_out),
        .mdio_oe    (mdio_oe), //~mdio_oe?
        .mdio_i    (mdio_in)
    );


    rst_sync #(
    // 输入时钟频率，单位：Hz
        .CLK_FREQUENCY(CLK_FREQUENCY),
        .RST_HOLDTIME_ms(10),
        .RST_RELEASETIME_ms(30)
    )u_rst_sync(
    .clk(clk),
    .rst_start(~rst_n),

    // 连接 RTL8211F 的 PHYRSTB 引脚，低电平有效
    .rst_out(rst_out),

    // 完整复位流程结束脉冲，持续一个 clk 周期
    .rst_complete(rst_complete),

    // PHY 寄存器初始化启动脉冲，持续一个 clk 周期
    .INITIAL_CONFIG_PULSE(INITIAL_CONFIG_PULSE)
);

    wire       tp_rx_clk;
    /*(* mark_debug = "true" *)*/ wire [7:0] tp_rx_data;
    /*(* mark_debug = "true" *)*/ wire       tp_rx_valid;
    /*(* mark_debug = "true" *)*/ wire       tp_rx_error;


    rgmii_rx u_rgmii_rx(
        .pll_locked(locked),
        .clk_200M(clk_200M),
        .rgmii_rxc(tp_rgmii_rxc),
        .rgmii_rxd(tp_rgmii_rxd),
        .rgmii_rx_ctl(tp_rgmii_rx_ctl),
    
        .rx_clk(tp_rx_clk),
        .rx_data_reg(tp_rx_data),
        .rx_valid_reg(tp_rx_valid),
        .rx_error_reg(tp_rx_error)
    );
endmodule
