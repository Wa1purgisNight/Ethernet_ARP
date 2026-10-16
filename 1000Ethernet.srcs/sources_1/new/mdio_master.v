`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/08/01 18:51:56
// Design Name: 
// Module Name: mdio_master
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


module mdio_master #(
    parameter integer CLK_FREQUENCY = 100_000_000,
    parameter integer MDC_FREQUENCY = 2_500_000
)(
    input  wire        clk,
    input  wire        rst,

    /*
     * Transaction interface
     *
     * rw = 0: write
     * rw = 1: read
     *
     * start should be asserted for one clk cycle.
     * A new transaction is accepted only when busy = 0.
     */
    input  wire        start,
    input  wire        rw,
    input  wire [4:0]  phy_addr,
    input  wire [4:0]  reg_addr,
    input  wire [15:0] write_data,

    output reg  [15:0] read_data,
    output reg         read_valid,
    output reg         busy,
    output reg         done,
    output reg         ta_error,

    /*
     * MDIO physical interface
     */
    output reg         mdc,
    input  wire        mdio_i,
    output reg         mdio_o,
    output reg         mdio_oe
);

    /*
     * MDC half-period divider.
     *
     * For:
     * CLK_FREQUENCY = 100 MHz
     * MDC_FREQUENCY = 2.5 MHz
     *
     * MDC_HALF_DIV = 100 MHz / (2 * 2.5 MHz) = 20
     */
    localparam integer MDC_HALF_DIV_CALC =
        CLK_FREQUENCY / (2 * MDC_FREQUENCY);

    localparam integer MDC_HALF_DIV =
        (MDC_HALF_DIV_CALC < 1) ? 1 : MDC_HALF_DIV_CALC;

    /*
     * Clause 22 frame bit index:
     *
     *  0 ... 31 : PREAMBLE, 32'b1
     * 32 ... 33 : START,    2'b01
     * 34 ... 35 : OP
     *             write = 2'b01
     *             read  = 2'b10
     * 36 ... 40 : PHY address
     * 41 ... 45 : Register address
     * 46 ... 47 : Turnaround
     *             write = 2'b10
     *             read  = 2'bZ0
     * 48 ... 63 : 16-bit data
     */
    reg [6:0] bit_count;

    reg [31:0] mdc_div_count;

    reg        rw_latched;
    reg [4:0]  phy_addr_latched;
    reg [4:0]  reg_addr_latched;
    reg [15:0] write_data_latched;

    reg [15:0] read_shift;

    /*
     * Return the MDIO output value for a particular frame bit.
     *
     * This function is used only when the MDIO master is driving
     * the MDIO bus. During a read turnaround/data field, mdio_oe
     * is deasserted instead.
     */
    function mdio_tx_bit;
        input [6:0] index;
        begin
            if (index <= 7'd31) begin
                /* Preamble */
                mdio_tx_bit = 1'b1;
            end
            else if (index == 7'd32) begin
                /* Start bit 1 of "01" */
                mdio_tx_bit = 1'b0;
            end
            else if (index == 7'd33) begin
                /* Start bit 2 of "01" */
                mdio_tx_bit = 1'b1;
            end
            else if (index == 7'd34) begin
                /*
                 * Opcode MSB:
                 * write = 0
                 * read  = 1
                 */
                mdio_tx_bit = rw_latched;
            end
            else if (index == 7'd35) begin
                /*
                 * Opcode LSB:
                 * write = 1
                 * read  = 0
                 */
                mdio_tx_bit = ~rw_latched;
            end
            else if ((index >= 7'd36) &&
                     (index <= 7'd40)) begin
                /*
                 * PHY address, MSB first.
                 *
                 * index 36 -> phy_addr[4]
                 * index 40 -> phy_addr[0]
                 */
                mdio_tx_bit =
                    phy_addr_latched[7'd40 - index];
            end
            else if ((index >= 7'd41) &&
                     (index <= 7'd45)) begin
                /*
                 * Register address, MSB first.
                 *
                 * index 41 -> reg_addr[4]
                 * index 45 -> reg_addr[0]
                 */
                mdio_tx_bit =
                    reg_addr_latched[7'd45 - index];
            end
            else if (index == 7'd46) begin
                /*
                 * Write turnaround first bit.
                 *
                 * For read operations, MDIO is released instead.
                 */
                mdio_tx_bit = 1'b1;
            end
            else if (index == 7'd47) begin
                /*
                 * Write turnaround second bit.
                 *
                 * Write TA = 10.
                 * For read operations, PHY drives this bit low.
                 */
                mdio_tx_bit = 1'b0;
            end
            else if ((index >= 7'd48) &&
                     (index <= 7'd63)) begin
                /*
                 * Write data, MSB first.
                 *
                 * index 48 -> write_data[15]
                 * index 63 -> write_data[0]
                 */
                mdio_tx_bit =
                    write_data_latched[7'd63 - index];
            end
            else begin
                mdio_tx_bit = 1'b1;
            end
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            mdc                <= 1'b0;
            mdio_o             <= 1'b1;
            mdio_oe            <= 1'b0;

            read_data          <= 16'h0000;
            read_shift         <= 16'h0000;
            read_valid         <= 1'b0;

            busy               <= 1'b0;
            done               <= 1'b0;
            ta_error           <= 1'b0;

            bit_count          <= 7'd0;
            mdc_div_count      <= 32'd0;

            rw_latched         <= 1'b0;
            phy_addr_latched   <= 5'd0;
            reg_addr_latched   <= 5'd0;
            write_data_latched <= 16'h0000;
        end
        else begin
            /*
             * Pulse outputs default to zero.
             */
            done       <= 1'b0;
            read_valid <= 1'b0;

            if (!busy) begin
                /*
                 * Keep MDC low while idle.
                 */
                mdc           <= 1'b0;
                mdc_div_count <= 32'd0;

                /*
                 * Release MDIO while idle.
                 * External pull-up keeps the line high.
                 */
                mdio_oe <= 1'b0;
                mdio_o  <= 1'b1;

                if (start) begin
                    rw_latched         <= rw;
                    phy_addr_latched   <= phy_addr;
                    reg_addr_latched   <= reg_addr;
                    write_data_latched <= write_data;

                    read_shift <= 16'h0000;
                    ta_error   <= 1'b0;

                    bit_count <= 7'd0;
                    busy      <= 1'b1;

                    /*
                     * First preamble bit must already be valid
                     * before the first rising edge of MDC.
                     */
                    mdio_oe <= 1'b1;
                    mdio_o  <= 1'b1;
                end
            end
            else begin
                /*
                 * Generate MDC only while a transaction is active.
                 */
                if (mdc_div_count == MDC_HALF_DIV - 1) begin
                    mdc_div_count <= 32'd0;

                    if (mdc == 1'b0) begin
                        /*
                         * MDC rising edge.
                         *
                         * PHY samples master-driven MDIO here.
                         * During a read transaction, the master
                         * samples PHY-driven MDIO here.
                         */
                        mdc <= 1'b1;

                        if (rw_latched) begin
                            /*
                             * Read turnaround:
                             *
                             * bit 46 = Z
                             * bit 47 = PHY drives 0
                             */
                            if (bit_count == 7'd47) begin
                                if (mdio_i != 1'b0)
                                    ta_error <= 1'b1;
                            end

                            /*
                             * Read 16-bit data, MSB first.
                             */
                            if ((bit_count >= 7'd48) &&
                                (bit_count <= 7'd63)) begin
                                read_shift <= {
                                    read_shift[14:0],
                                    mdio_i
                                };
                            end
                        end
                    end
                    else begin
                        /*
                         * MDC falling edge.
                         *
                         * Change MDIO output only after the falling
                         * edge, providing setup time before the next
                         * rising edge.
                         */
                        mdc <= 1'b0;

                        if (bit_count == 7'd63) begin
                            /*
                             * The final data bit was sampled on the
                             * preceding MDC rising edge.
                             */
                            busy    <= 1'b0;
                            done    <= 1'b1;
                            mdio_oe <= 1'b0;

                            if (rw_latched) begin
                                read_data  <= read_shift;
                                read_valid <= 1'b1;
                            end
                        end
                        else begin
                            bit_count <= bit_count + 7'd1;

                            /*
                             * For a read transaction, release MDIO
                             * starting from the first turnaround bit.
                             */
                            if (rw_latched &&
                                ((bit_count + 7'd1) >= 7'd46)) begin
                                mdio_oe <= 1'b0;
                                mdio_o  <= 1'b1;
                            end
                            else begin
                                mdio_oe <= 1'b1;
                                mdio_o  <= mdio_tx_bit(
                                    bit_count + 7'd1
                                );
                            end
                        end
                    end
                end
                else begin
                    mdc_div_count <= mdc_div_count + 32'd1;
                end
            end
        end
    end

endmodule
