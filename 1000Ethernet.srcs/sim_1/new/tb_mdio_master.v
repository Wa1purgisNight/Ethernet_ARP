`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/08/01 19:12:11
// Design Name: 
// Module Name: tb_mdio_master
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


module tb_mdio_master;

    /*
     * 100 MHz system clock
     * 2.5 MHz MDC
     */
    localparam integer CLK_FREQUENCY = 100_000_000;
    localparam integer MDC_FREQUENCY = 2_500_000;

    localparam [4:0] TEST_PHY_ADDR = 5'd1;
    localparam [4:0] TEST_REG_ADDR = 5'd2;

    localparam [15:0] TEST_WRITE_DATA = 16'hA55A;
    localparam [15:0] TEST_READ_DATA  = 16'h001C;

    reg clk;
    reg rst;

    reg        start;
    reg        rw;
    reg [4:0]  phy_addr;
    reg [4:0]  reg_addr;
    reg [15:0] write_data;

    wire [15:0] read_data;
    wire        read_valid;
    wire        busy;
    wire        done;
    wire        ta_error;

    wire mdc;
    wire mdio_i;
    wire mdio_o;
    wire mdio_oe;

    /*
     * Shared MDIO bus.
     *
     * FPGA master drives through mdio_oe.
     * PHY model drives through phy_mdio_oe.
     */
    tri mdio;

    reg phy_mdio_o;
    reg phy_mdio_oe;

    assign mdio = mdio_oe     ? mdio_o     : 1'bz;
    assign mdio = phy_mdio_oe ? phy_mdio_o : 1'bz;

    /*
     * MDIO normally has an external pull-up resistor.
     */
    pullup(mdio);

    assign mdio_i = mdio;

    /*
     * DUT
     */
    mdio_master #(
        .CLK_FREQUENCY (CLK_FREQUENCY),
        .MDC_FREQUENCY (MDC_FREQUENCY)
    ) dut (
        .clk        (clk),
        .rst        (rst),

        .start      (start),
        .rw         (rw),
        .phy_addr   (phy_addr),
        .reg_addr   (reg_addr),
        .write_data (write_data),

        .read_data  (read_data),
        .read_valid (read_valid),
        .busy       (busy),
        .done       (done),
        .ta_error   (ta_error),

        .mdc        (mdc),
        .mdio_i     (mdio_i),
        .mdio_o     (mdio_o),
        .mdio_oe    (mdio_oe)
    );

    /*
     * Generate 100 MHz clock.
     */
    initial begin
        clk = 1'b0;

        forever begin
            #5 clk = ~clk;
        end
    end

    /*
     * Capture a complete Clause 22 frame as seen on MDIO.
     *
     * The master changes MDIO after MDC falling edges.
     * Data is therefore sampled at MDC rising edges.
     */
    reg [63:0] captured_frame;
    integer captured_bit_count;

    always @(posedge mdc) begin
        if (busy) begin
            captured_frame = {
                captured_frame[62:0],
                mdio
            };

            captured_bit_count = captured_bit_count + 1;
        end
    end

    /*
     * PHY model for read transaction.
     *
     * The PHY starts driving during the read turnaround field:
     *
     * Frame bit 46: Z
     * Frame bit 47: 0
     * Frame bit 48: DATA[15]
     * ...
     * Frame bit 63: DATA[0]
     *
     * We update PHY output on MDC falling edges so that the
     * signal is stable before the following MDC rising edge.
     */
    integer phy_frame_index;
    reg     phy_read_active;

    always @(negedge mdc) begin
        if (!busy) begin
            phy_frame_index <= 0;
            phy_mdio_oe     <= 1'b0;
            phy_mdio_o      <= 1'b1;
        end
        else if (phy_read_active) begin
            /*
             * The current bit has just completed.
             * Prepare the next frame bit.
             */
            phy_frame_index <= phy_frame_index + 1;

            if ((phy_frame_index + 1) == 46) begin
                /*
                 * First turnaround bit: high impedance.
                 */
                phy_mdio_oe <= 1'b0;
                phy_mdio_o  <= 1'b1;
            end
            else if ((phy_frame_index + 1) == 47) begin
                /*
                 * Second turnaround bit: PHY drives zero.
                 */
                phy_mdio_oe <= 1'b1;
                phy_mdio_o  <= 1'b0;
            end
            else if (((phy_frame_index + 1) >= 48) &&
                     ((phy_frame_index + 1) <= 63)) begin
                /*
                 * Return read data MSB first.
                 *
                 * frame 48 -> TEST_READ_DATA[15]
                 * frame 63 -> TEST_READ_DATA[0]
                 */
                phy_mdio_oe <= 1'b1;
                phy_mdio_o  <=
                    TEST_READ_DATA[63 - (phy_frame_index + 1)];
            end
            else begin
                phy_mdio_oe <= 1'b0;
                phy_mdio_o  <= 1'b1;
            end
        end
        else begin
            phy_frame_index <= phy_frame_index + 1;
            phy_mdio_oe     <= 1'b0;
            phy_mdio_o      <= 1'b1;
        end
    end

    /*
     * Apply one-cycle start pulse.
     */
    task start_transaction;
        input        transaction_rw;
        input [4:0]  transaction_phy_addr;
        input [4:0]  transaction_reg_addr;
        input [15:0] transaction_write_data;

        begin
            @(posedge clk);

            while (busy) begin
                @(posedge clk);
            end

            rw         <= transaction_rw;
            phy_addr   <= transaction_phy_addr;
            reg_addr   <= transaction_reg_addr;
            write_data <= transaction_write_data;
            start      <= 1'b1;

            @(posedge clk);

            start <= 1'b0;
        end
    endtask

    /*
     * Wait for transaction completion.
     */
    task wait_transaction_done;
        begin
            while (!done) begin
                @(posedge clk);
            end

            /*
             * Allow nonblocking assignments to settle.
             */
            #1;
        end
    endtask

    /*
     * Check write frame.
     */
    task check_write_frame;
        reg [63:0] expected_frame;

        begin
            expected_frame = {
                32'hFFFF_FFFF,
                2'b01,
                2'b01,
                TEST_PHY_ADDR,
                TEST_REG_ADDR,
                2'b10,
                TEST_WRITE_DATA
            };

            if (captured_bit_count !== 64) begin
                $display(
                    "ERROR: Write frame bit count is %0d, expected 64",
                    captured_bit_count
                );
                $stop;
            end

            if (captured_frame !== expected_frame) begin
                $display("ERROR: Write frame mismatch");
                $display("Expected: %016h", expected_frame);
                $display("Captured: %016h", captured_frame);
                $stop;
            end
            else begin
                $display(
                    "PASS: Write frame = %016h",
                    captured_frame
                );
            end
        end
    endtask

    /*
     * Check the master-controlled part of the read frame.
     *
     * During TA and data fields, the value on the shared MDIO line
     * comes from the PHY model, so only bits 63:18 of the captured
     * shift register correspond to the master's 46-bit header.
     */
    task check_read_header;
        reg [45:0] expected_header;
        reg [45:0] captured_header;

        begin
            expected_header = {
                32'hFFFF_FFFF,
                2'b01,
                2'b10,
                TEST_PHY_ADDR,
                TEST_REG_ADDR
            };

            captured_header = captured_frame[63:18];

            if (captured_bit_count !== 64) begin
                $display(
                    "ERROR: Read frame bit count is %0d, expected 64",
                    captured_bit_count
                );
                $stop;
            end

            if (captured_header !== expected_header) begin
                $display("ERROR: Read frame header mismatch");
                $display(
                    "Expected header: %012h",
                    expected_header
                );
                $display(
                    "Captured header: %012h",
                    captured_header
                );
                $stop;
            end
            else begin
                $display(
                    "PASS: Read header = %012h",
                    captured_header
                );
            end
        end
    endtask

    /*
     * Test sequence
     */
    initial begin
        rst          = 1'b1;
        start        = 1'b0;
        rw           = 1'b0;
        phy_addr     = 5'd0;
        reg_addr     = 5'd0;
        write_data   = 16'h0000;

        phy_mdio_o   = 1'b1;
        phy_mdio_oe  = 1'b0;
        phy_read_active = 1'b0;
        phy_frame_index = 0;

        captured_frame     = 64'd0;
        captured_bit_count = 0;

        /*
         * Reset DUT.
         */
        repeat (10) begin
            @(posedge clk);
        end

        rst <= 1'b0;

        repeat (5) begin
            @(posedge clk);
        end

        /*
         * ---------------------------------------------------------
         * Test 1: Clause 22 write transaction
         * ---------------------------------------------------------
         */
        $display("");
        $display("========================================");
        $display("Starting Clause 22 write transaction");
        $display("PHY address : %0d", TEST_PHY_ADDR);
        $display("REG address : %0d", TEST_REG_ADDR);
        $display("Write data  : %04h", TEST_WRITE_DATA);
        $display("========================================");

        captured_frame     = 64'd0;
        captured_bit_count = 0;
        phy_read_active    = 1'b0;
        phy_frame_index    = 0;

        start_transaction(
            1'b0,
            TEST_PHY_ADDR,
            TEST_REG_ADDR,
            TEST_WRITE_DATA
        );

        wait_transaction_done();

        check_write_frame();

        if (ta_error !== 1'b0) begin
            $display(
                "ERROR: ta_error asserted during write transaction"
            );
            $stop;
        end

        /*
         * ---------------------------------------------------------
         * Test 2: Clause 22 read transaction
         * ---------------------------------------------------------
         */
        repeat (10) begin
            @(posedge clk);
        end

        $display("");
        $display("========================================");
        $display("Starting Clause 22 read transaction");
        $display("PHY address : %0d", TEST_PHY_ADDR);
        $display("REG address : %0d", TEST_REG_ADDR);
        $display("PHY response: %04h", TEST_READ_DATA);
        $display("========================================");

        captured_frame     = 64'd0;
        captured_bit_count = 0;
        phy_read_active    = 1'b1;
        phy_frame_index    = 0;

        start_transaction(
            1'b1,
            TEST_PHY_ADDR,
            TEST_REG_ADDR,
            16'h0000
        );

        wait_transaction_done();

        phy_read_active = 1'b0;
        phy_mdio_oe     = 1'b0;

        check_read_header();

        if (!read_valid) begin
            $display(
                "ERROR: read_valid was not asserted with done"
            );
            $stop;
        end

        if (ta_error !== 1'b0) begin
            $display(
                "ERROR: ta_error asserted during valid read"
            );
            $stop;
        end

        if (read_data !== TEST_READ_DATA) begin
            $display("ERROR: Read data mismatch");
            $display("Expected: %04h", TEST_READ_DATA);
            $display("Received: %04h", read_data);
            $stop;
        end
        else begin
            $display(
                "PASS: Read data = %04h",
                read_data
            );
        end

        $display("");
        $display("========================================");
        $display("All MDIO Master tests passed");
        $display("========================================");

        #1000;
        $finish;
    end

    /*
     * Simulation timeout.
     */
    initial begin
        #1_000_000;

        $display("ERROR: Simulation timeout");
        $stop;
    end

endmodule