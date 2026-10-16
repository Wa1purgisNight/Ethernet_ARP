`timescale 1ns / 1ps

module mdio_master #(
    parameter integer CLK_FREQUENCY = 100_000_000,
    parameter integer MDC_FREQUENCY = 2_500_000
)(
    input  wire        clk,
    input  wire        rst_n,

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
    output reg         write_done,
    output reg         ta_error,

    output reg         mdc,
    input  wire        mdio_i,
    output reg         mdio_o,
    output reg         mdio_oe
    
    //debug接口
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

    localparam [3:0]
        ST_IDLE     = 4'd0,
        ST_PREAMBLE = 4'd1,
        ST_START    = 4'd2,
        ST_OP       = 4'd3,
        ST_PHY_ADDR = 4'd4,
        ST_REG_ADDR = 4'd5,
        ST_TA       = 4'd6,
        ST_DATA     = 4'd7;

    reg [3:0]  state;
    reg [6:0]  bit_count;
    reg [31:0] mdc_div_count;

    reg        rw_latched;
    reg [4:0]  phy_addr_latched;
    reg [4:0]  reg_addr_latched;
    reg [15:0] write_data_latched;
    reg [15:0] read_shift;


    function mdio_tx_bit;
        input [6:0] index;
        begin
            if (index <= 7'd31)
                /* Preamble */
                mdio_tx_bit = 1'b1;
            else if (index == 7'd32)
                /* Start bit 1 of "01" */
                mdio_tx_bit = 1'b0;
            else if (index == 7'd33)
                /* Start bit 2 of "01" */
                mdio_tx_bit = 1'b1;
            else if (index == 7'd34)
                /*
                 * Opcode MSB:
                 * write = 0
                 * read  = 1
                 */
                mdio_tx_bit = rw_latched;
            else if (index == 7'd35)
                /*
                 * Opcode LSB:
                 * write = 1
                 * read  = 0
                 */
                mdio_tx_bit = ~rw_latched;
            else if ((index >= 7'd36) && (index <= 7'd40))
                /*
                 * PHY address, MSB first.
                 *
                 * index 36 -> phy_addr[4]
                 * index 40 -> phy_addr[0]
                 */
                mdio_tx_bit = phy_addr_latched[7'd40 - index];
            else if ((index >= 7'd41) && (index <= 7'd45))
                /*
                 * Register address, MSB first.
                 *
                 * index 41 -> reg_addr[4]
                 * index 45 -> reg_addr[0]
                 */
                mdio_tx_bit = reg_addr_latched[7'd45 - index];
            else if (index == 7'd46)
                /*
                 * Write turnaround first bit.
                 *
                 * For read operations, MDIO is released instead.
                 */
                mdio_tx_bit = 1'b1;
            else if (index == 7'd47)
                /*
                 * Write turnaround second bit.
                 *
                 * Write TA = 10.
                 * For read operations, PHY drives this bit low.
                 */
                mdio_tx_bit = 1'b0;
            else if ((index >= 7'd48) && (index <= 7'd63))
                /*
                 * Write data, MSB first.
                 *
                 * index 48 -> write_data[15]
                 * index 63 -> write_data[0]
                 */
                mdio_tx_bit = write_data_latched[7'd63 - index];
            else
                mdio_tx_bit = 1'b1;
        end
    endfunction

    function [3:0] state_for_bit;
        input [6:0] index;
        begin
            if (index <= 7'd31)
                state_for_bit = ST_PREAMBLE;
            else if (index <= 7'd33)
                state_for_bit = ST_START;
            else if (index <= 7'd35)
                state_for_bit = ST_OP;
            else if (index <= 7'd40)
                state_for_bit = ST_PHY_ADDR;
            else if (index <= 7'd45)
                state_for_bit = ST_REG_ADDR;
            else if (index <= 7'd47)
                state_for_bit = ST_TA;
            else
                state_for_bit = ST_DATA;
        end
    endfunction

    always @(posedge clk) begin
        if (!rst_n) begin
            state              <= ST_IDLE;
            bit_count          <= 7'd0;
            mdc_div_count      <= 32'd0;

            rw_latched         <= 1'b0;
            phy_addr_latched   <= 5'd0;
            reg_addr_latched   <= 5'd0;
            write_data_latched <= 16'd0;

            read_shift         <= 16'd0;
            read_data          <= 16'd0;
            read_valid         <= 1'b0;
            busy               <= 1'b0;
            write_done         <= 1'b0;
            ta_error           <= 1'b0;

            mdc                <= 1'b0;
            mdio_o             <= 1'b1;
            mdio_oe            <= 1'b0;
        end
        else begin
            write_done <= 1'b0;
            read_valid <= 1'b0;

            if (state == ST_IDLE) begin
                busy          <= 1'b0;
                mdc           <= 1'b0;
                mdc_div_count <= 32'd0;
                mdio_oe       <= 1'b0;
                mdio_o        <= 1'b1;

                if (start) begin
                    rw_latched         <= rw;
                    phy_addr_latched   <= phy_addr;
                    reg_addr_latched   <= reg_addr;
                    write_data_latched <= write_data;

                    read_shift <= 16'd0;
                    ta_error   <= 1'b0;
                    busy       <= 1'b1;

                    state     <= ST_PREAMBLE;
                    bit_count <= 7'd0;
                    mdio_oe   <= 1'b1;
                    mdio_o    <= 1'b1;
                end
            end
            else begin
                busy <= 1'b1;  

                if (mdc_div_count == MDC_HALF_DIV - 1) begin
                    mdc_div_count <= 32'd0;

                    if (mdc == 1'b0) begin
                        mdc <= 1'b1;  //上升沿

                        /* Read TA second bit must be driven low by PHY. */
                        if (rw_latched &&
                            (state == ST_TA) &&
                            (bit_count == 7'd47) &&
                            (mdio_i != 1'b0)) begin

                            ta_error   <= 1'b1;
                            busy       <= 1'b0;
                            write_done <= 1'b1;
                            read_valid <= 1'b0;

                            state         <= ST_IDLE; 
                            mdc           <= 1'b0;  
                            mdc_div_count <= 32'd0;
                            mdio_oe       <= 1'b0;
                            mdio_o        <= 1'b1; 
                        end
                        else if (rw_latched &&
                                 (state == ST_DATA) &&
                                 (bit_count >= 7'd48) &&
                                 (bit_count <= 7'd63)) begin
                            read_shift <= {read_shift[14:0], mdio_i};
                        end
                    end
                    else begin
                        mdc <= 1'b0;  //下降

                        if (bit_count == 7'd63) begin
                            busy     <= 1'b0;
                            write_done <= 1'b1;
                            state    <= ST_IDLE;
                            mdio_oe  <= 1'b0;
                            mdio_o   <= 1'b1; 

                            if (rw_latched) begin
                                read_data  <= read_shift;
                                read_valid <= 1'b1;
                            end
                        end
                        else begin
                            bit_count <= bit_count + 7'd1;
                            state     <= state_for_bit(bit_count + 7'd1);

                            if (rw_latched &&
                                ((bit_count + 7'd1) >= 7'd46)) begin   //swith to input mode and phy ontput
                                mdio_oe <= 1'b0;
                                mdio_o  <= 1'b1; //原来是1
                            end
                            else begin
                                mdio_oe <= 1'b1;
                                mdio_o  <= mdio_tx_bit(bit_count + 7'd1);
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
