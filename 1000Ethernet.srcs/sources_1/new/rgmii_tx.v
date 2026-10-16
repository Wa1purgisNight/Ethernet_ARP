`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/08/11 18:11:48
// Design Name: 
// Module Name: rgmii_tx
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


module rgmii_tx (
    input  wire       tx_clk,
    input  wire       tx_clk_oddr,
    input  wire [7:0] tx_data,
    input  wire       tx_valid,
    input  wire       tx_error,

    output wire       rgmii_txc,
    output wire [3:0] rgmii_txd,
    output wire       rgmii_tx_ctl
);

    /*reg[7:0]  tx_data_d;
    reg       tx_valid_d;
    reg       tx_error_d;

    always@(posedge tx_clk) begin
        tx_data_d <= tx_data;
        tx_valid_d <= tx_valid;
        tx_error_d <= tx_error;
    end*/

    genvar i;

    generate
        for (i = 0; i < 4; i = i + 1) begin : GEN_TX_ODDR
            ODDR #(
                .DDR_CLK_EDGE("SAME_EDGE"),
                .INIT(1'b0),
                .SRTYPE("SYNC")
            ) u_oddr_txd (
                .Q (rgmii_txd[i]),
                .C (tx_clk),
                .CE(1'b1),

                /*
                 * Rising edge
                 */
                .D1(tx_data[i]),

                /*
                 * Falling edge
                 */
                .D2(tx_data[i+4]),

                .R (1'b0),
                .S (1'b0)
            );
        end
    endgenerate

    /*
     * TX_CTL:
     *
     * Rising  = TX_EN
     * Falling = TX_EN XOR TX_ER
     */
    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE"),
        .INIT(1'b0),
        .SRTYPE("SYNC")
    ) u_oddr_tx_ctl (
        .Q (rgmii_tx_ctl),
        .C (tx_clk),
        .CE(1'b1),
        .D1(tx_valid),
        .D2(tx_valid ^ tx_error),
        .R (1'b0),
        .S (1'b0)
    );

    /*
     * Forwarded RGMII TX clock.
     */
     
    /*wire clk_pll2oddr;
    wire locked_3;
    clk_wiz_2 u_clk_wiz_2 (
        .clk_in1  (tx_clk),
        .locked   (locked_3),
        .clk_out1 (clk_pll2oddr)
    );*/
     
    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE"),
        .INIT(1'b0),
        .SRTYPE("SYNC")
    ) u_oddr_txc (
        .Q (rgmii_txc),
        .C (tx_clk_oddr),
        .CE(1'b1),
        .D1(1'b1),
        .D2(1'b0),
        .R (1'b0),
        .S (1'b0)
    );

endmodule
