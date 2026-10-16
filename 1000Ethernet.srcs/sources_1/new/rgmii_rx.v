`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/08/09 15:31:22
// Design Name: 
// Module Name: rgmii_rx
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


module rgmii_rx (
    /*input  wire       clk_200M,
    input  wire       pll_locked,*/
    
    input  wire       rgmii_rxc,
    input  wire [3:0] rgmii_rxd,
    input  wire       rgmii_rx_ctl,

    output wire       rx_clk,
    output reg[7:0]   rx_data_reg, //将对应的rx_data, valid 和 error打一拍到寄存器再输出
    output reg        rx_valid_reg,
    output reg        rx_error_reg
);

    wire [7:0] rx_data;
    wire       rx_valid;
    wire       rx_error;
    wire [3:0] rxd_rise;
    wire [3:0] rxd_fall;
    wire       ctl_rise;
    wire       ctl_fall;
    
    
    /*reg [4:0] cnt = 0;
    reg idelay_rst = 1'b1;
    
    always @(posedge clk_200M) begin
        if (!pll_locked) begin
            cnt        <= 0;
            idelay_rst <= 1'b1;
        end
        else if (cnt != 5'd31) begin
            cnt        <= cnt + 1'b1;
            idelay_rst <= 1'b1;
        end
        else begin
            idelay_rst <= 1'b0;
        end
    end    
    
    IDELAYCTRL u_idelayctrl (
    .REFCLK(clk_200M),
    .RST   (idelay_rst),
    .RDY   (idelay_rdy)
    );*/

/* Clock */
    assign rx_clk = rgmii_rxc;

/* Data */
    /*wire [3:0] rxd_delay;
    wire       rx_ctl_delay;

    genvar j;
    generate
        for (j = 0; j < 4; j = j + 1) begin : GEN_RXD_IDELAY
    
            IDELAYE2 #(
                .CINVCTRL_SEL("FALSE"),
                .DELAY_SRC("IDATAIN"),
                .HIGH_PERFORMANCE_MODE("TRUE"),
                .IDELAY_TYPE("FIXED"),
                .IDELAY_VALUE(0),          // 先试 8 tap
                .PIPE_SEL("FALSE"),
                .REFCLK_FREQUENCY(200.0),
                .SIGNAL_PATTERN("DATA")
            ) u_idelay_rxd (
                .DATAOUT     (rxd_delay[j]),
    
                .IDATAIN     (rgmii_rxd[j]),
                .DATAIN      (1'b0),
    
                .C           (1'b0),
                .CE          (1'b0),
                .INC         (1'b0),
                .LD          (1'b0),
                .LDPIPEEN    (1'b0),
    
                .CNTVALUEIN  (5'd0),
                .CNTVALUEOUT (),
    
                .CINVCTRL    (1'b0),
                .REGRST      (1'b0)
            );
    
        end
    endgenerate*/


    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : GEN_RX_IDDR
            IDDR #(
                .DDR_CLK_EDGE("SAME_EDGE"), //SAME_EDGE_PIPELINED
                .INIT_Q1(1'b0),
                .INIT_Q2(1'b0),
                .SRTYPE("SYNC")
            ) u_iddr_rxd (
                .Q1(rxd_fall[i]), //调换过来了
                .Q2(rxd_rise[i]),
                .C (rgmii_rxc),
                .CE(1'b1),
                .D (rgmii_rxd[i]),
                .R (1'b0),
                .S (1'b0)
            );
        end
    endgenerate


/* CTL Signal*/
    /*IDELAYE2 #(
        .CINVCTRL_SEL("FALSE"),
        .DELAY_SRC("IDATAIN"),
        .HIGH_PERFORMANCE_MODE("TRUE"),
        .IDELAY_TYPE("FIXED"),
        .IDELAY_VALUE(0),
        .PIPE_SEL("FALSE"),
        .REFCLK_FREQUENCY(200.0),
        .SIGNAL_PATTERN("DATA")
    ) u_idelay_rx_ctl (
        .DATAOUT     (rx_ctl_delay),
    
        .IDATAIN     (rgmii_rx_ctl),
        .DATAIN      (1'b0),
    
        .C           (1'b0),
        .CE          (1'b0),
        .INC         (1'b0),
        .LD          (1'b0),
        .LDPIPEEN    (1'b0),
    
        .CNTVALUEIN  (5'd0),
        .CNTVALUEOUT (),
    
        .CINVCTRL    (1'b0),
        .REGRST      (1'b0)
    );*/


    IDDR #(
        .DDR_CLK_EDGE("SAME_EDGE"),
        .INIT_Q1(1'b0),
        .INIT_Q2(1'b0),
        .SRTYPE("SYNC")
    ) u_iddr_rx_ctl (
        .Q1(ctl_fall),
        .Q2(ctl_rise),
        .C (rgmii_rxc),
        .CE(1'b1),
        .D (rgmii_rx_ctl),
        .R (1'b0),
        .S (1'b0)
    );

    /*
     * RGMII:
     * Rising edge  = RXD[3:0]
     * Falling edge = RXD[7:4]
     */
    assign rx_data = {rxd_fall, rxd_rise};

    /*
     * RX_CTL:
     * Rising  = RX_DV
     * Falling = RX_DV XOR RX_ER
     *
     * Therefore:
     * RX_ER = rise XOR fall
     */
    assign rx_valid = ctl_rise;
    assign rx_error = ctl_rise ^ ctl_fall;
    
    
    
    always @(posedge rgmii_rxc) begin
        rx_data_reg  <= rx_data;
        rx_valid_reg <= rx_valid;
        rx_error_reg <= rx_error;
    end

endmodule
