`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/08/05 05:28:43
// Design Name: 
// Module Name: tb_phy_id_top
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


module tb_phy_id_top;

    /*
     * 为了加快仿真：
     *
     * 系统时钟：100 MHz
     * MDC时钟：10 MHz
     *
     * 上板时仍然可以使用2.5 MHz MDC。
     */
    localparam integer CLK_FREQUENCY = 100_000_000;
    localparam integer MDC_FREQUENCY = 10_000_000;

    localparam [4:0] PHY_ADDR = 5'd0;

    /*
     * 模拟PHY返回的ID
     */
    localparam [15:0] EXPECTED_PHY_ID1 = 16'h001C;
    localparam [15:0] EXPECTED_PHY_ID2 = 16'hC916;
    localparam [31:0] EXPECTED_PHY_ID  = {
        EXPECTED_PHY_ID1,
        EXPECTED_PHY_ID2
    };

    //reg clk;
    reg clk_50M;
    reg rst_n;
    reg phy_id_start;
    
    wire clk = dut.clk;
    
    wire rst_syn;
    wire rst_complete = dut.rst_complete;
    
    wire phy_mdc;
    tri  phy_mdio;

    wire [15:0] phy_id1 = dut.phy_id1;
    wire [15:0] phy_id2 = dut.phy_id2;
    wire [31:0] phy_id = dut.phy_id;

    wire phy_id_busy = dut.phy_id_busy;
    wire phy_id_valid = dut.phy_id_valid;
    wire phy_id_error = dut.phy_id_error;

    /*
     * PHY模型的MDIO驱动信号
     */
    reg phy_mdio_out;
    reg phy_mdio_oe;

    /*debug 信号*/
    /*wire[3:0] reader_state;
    wire[3:0] mdio_state;
    wire debug_mdio_busy;*/
    wire[1:0] state = dut.u_rst_sync.state;
    wire[31:0] cycles =  dut.u_rst_sync.SETTLE_CYCLES;
    wire[31:0] counter =  dut.u_rst_sync.cycle_counter;
    /*
     * PHY侧三态驱动：
     *
     * phy_mdio_oe = 1：PHY驱动MDIO
     * phy_mdio_oe = 0：PHY释放MDIO
     */
    assign phy_mdio = phy_mdio_oe
                    ? phy_mdio_out
                    : 1'bz;

    /*
     * MDIO总线需要上拉。
     *
     * 当FPGA和PHY都释放MDIO时，
     * 总线电平为1。
     */
    pullup (phy_mdio);

    /*
     * DUT
     */
    ethernet_top #(
        .CLK_FREQUENCY (CLK_FREQUENCY),
        .MDC_FREQUENCY (MDC_FREQUENCY),
        .PHY_ADDR      (PHY_ADDR)
    ) dut (
        .clk_50M          (clk_50M),
        .rst_n        (rst_n),
        
        .rst_out      (rst_syn),
        
        .phy_id_start (phy_id_start),

        .phy_mdc      (phy_mdc),
        .phy_mdio     (phy_mdio)

    );

    /*
     * 100 MHz系统时钟
     */
    initial begin
        clk_50M = 1'b0;
            fork 
                forever #10 clk_50M = ~clk_50M;
            join
    end

    /*
     * 产生一个系统时钟周期的启动脉冲
     */
    task start_phy_id_read;
        begin
            @(posedge clk);
            phy_id_start <= 1'b1;

            @(posedge clk);
            phy_id_start <= 1'b0;
        end
    endtask

    /*
     * 等待32位Clause 22前导码
     */
    task wait_for_preamble;

        integer preamble_count;

        begin
            preamble_count = 0;

            while (preamble_count < 32) begin
                @(posedge phy_mdc);

                if (phy_mdio === 1'b1) begin
                    preamble_count = preamble_count + 1;
                end
                else begin
                    preamble_count = 0;
                end
            end
        end

    endtask

    /*
     * 模拟PHY响应一次Clause 22读操作
     *
     * Clause 22读帧：
     *
     * PRE   ST  OP  PHYAD REGAD TA DATA
     * 32'b1 01  10   5     5   Z0 16
     */
    task respond_to_mdio_read;

        integer i;

        reg       sampled_bit;
        reg [1:0] start_bits;
        reg [1:0] opcode;
        reg [4:0] received_phy_addr;
        reg [4:0] received_reg_addr;
        reg [15:0] response_data;

        begin
            phy_mdio_oe  = 1'b0;
            phy_mdio_out = 1'b1;

            /*
             * 等待32位前导码
             */
            wait_for_preamble();

            /*
             * 读取ST = 01
             */
            @(posedge phy_mdc);
            start_bits[1] = phy_mdio;

            @(posedge phy_mdc);
            start_bits[0] = phy_mdio;

            /*
             * 读取OP = 10
             */
            @(posedge phy_mdc);
            opcode[1] = phy_mdio;

            @(posedge phy_mdc);
            opcode[0] = phy_mdio;

            /*
             * 读取PHY地址，MSB first
             */
            for (i = 4; i >= 0; i = i - 1) begin
                @(posedge phy_mdc);
                received_phy_addr[i] = phy_mdio;
            end

            /*
             * 读取寄存器地址，MSB first
             */
            for (i = 4; i >= 0; i = i - 1) begin
                @(posedge phy_mdc);
                received_reg_addr[i] = phy_mdio;
            end

            $display(
                "[%0t] PHY model received: ST=%b OP=%b PHY=%0d REG=%0d",
                $time,
                start_bits,
                opcode,
                received_phy_addr,
                received_reg_addr
            );

            /*
             * 检查Clause 22读命令格式
             */
            if (start_bits !== 2'b01) begin
                $display(
                    "[%0t] ERROR: Invalid start bits: %b",
                    $time,
                    start_bits
                );
            end

            if (opcode !== 2'b10) begin
                $display(
                    "[%0t] ERROR: Invalid read opcode: %b",
                    $time,
                    opcode
                );
            end

            if (received_phy_addr !== PHY_ADDR) begin
                $display(
                    "[%0t] ERROR: PHY address mismatch, expected=%0d received=%0d",
                    $time,
                    PHY_ADDR,
                    received_phy_addr
                );
            end

            /*
             * 根据寄存器地址选择返回数据
             */
            case (received_reg_addr)

                5'd2: begin
                    response_data = EXPECTED_PHY_ID1;
                end

                5'd3: begin
                    response_data = EXPECTED_PHY_ID2;
                end

                default: begin
                    response_data = 16'h0000;

                    $display(
                        "[%0t] WARNING: Unsupported register address %0d",
                        $time,
                        received_reg_addr
                    );
                end

            endcase

            /*
             * TA第1位：Z
             *
             * 在寄存器地址最后一位采样完成后的下降沿，
             * PHY仍然保持高阻。
             */
            @(negedge phy_mdc);
            phy_mdio_oe  = 1'b0;
            phy_mdio_out = 1'b1;

            /*
             * TA第2位：0
             *
             * PHY在下一个MDC下降沿输出0，
             * Master在随后的上升沿采样。
             */
            @(negedge phy_mdc);
            phy_mdio_oe  = 1'b1;
            phy_mdio_out = 1'b0;

            /*
             * 发送16位数据，MSB first
             *
             * PHY在MDC下降沿更新数据，
             * Master在MDC上升沿采样数据。
             */
            for (i = 15; i >= 0; i = i - 1) begin
                @(negedge phy_mdc);

                phy_mdio_oe  = 1'b1;
                phy_mdio_out = response_data[i];
            end

            /*
             * 数据最后一位在上升沿被Master采样后，
             * PHY在随后的下降沿释放MDIO。
             */
            @(negedge phy_mdc);

            phy_mdio_oe  = 1'b0;
            phy_mdio_out = 1'b1;

            $display(
                "[%0t] PHY model returned REG%0d = 0x%04h",
                $time,
                received_reg_addr,
                response_data
            );
        end

    endtask

    /*
     * PHY模型：
     *
     * phy_id_reader会连续读取两次：
     * 1. Register 2
     * 2. Register 3
     */
    initial begin
        phy_mdio_oe  = 1'b0;
        phy_mdio_out = 1'b1;

        /*
         * 等待复位释放
         */
        wait (rst_n === 1'b1);

        /*
         * 响应寄存器2读取
         */
        respond_to_mdio_read();

        /*
         * 响应寄存器3读取
         */
        respond_to_mdio_read();

        /*
         * 之后保持总线释放
         */
        phy_mdio_oe  = 1'b0;
        phy_mdio_out = 1'b1;
    end

    /*
     * 主测试流程
     */
    initial begin
        rst_n        = 1'b0;
        phy_id_start = 1'b0;

        /*
         * 保持复位若干系统时钟周期
         */
        repeat (10) begin
            @(posedge clk);
        end

        rst_n = 1'b1;

        repeat (5) begin
            @(posedge clk);
        end

        $display("");
        $display("========================================");
        $display("Start PHY ID read test");
        $display("Expected PHY ID = 0x%08h", EXPECTED_PHY_ID);
        $display("========================================");
        $display("");

        @(posedge dut.rst_complete);
        #1;
        
        start_phy_id_read();
        

        /*
         * 等待valid或error
         */
        wait (
            (dut.phy_id_valid === 1'b1) ||
            (dut.phy_id_error === 1'b1)
        );

        /*
         * 等待一个小时钟周期，
         * 避免与非阻塞赋值更新发生竞争。
         */
        @(posedge clk);
        #1;

        if (dut.phy_id_error === 1'b1) begin
            $display("");
            $display("========================================");
            $display("TEST FAILED: phy_id_error asserted");
            $display("PHY ID1 = 0x%04h", dut.phy_id1);
            $display("PHY ID2 = 0x%04h", dut.phy_id2);
            $display("PHY ID  = 0x%08h", dut.phy_id);
            $display("========================================");
            $display("");

            $stop;
        end
        else if (dut.phy_id !== EXPECTED_PHY_ID) begin
            $display("");
            $display("========================================");
            $display("TEST FAILED: PHY ID mismatch");
            $display("Expected PHY ID = 0x%08h", EXPECTED_PHY_ID);
            $display("Actual PHY ID   = 0x%08h", dut.phy_id);
            $display("PHY ID1         = 0x%04h", dut.phy_id1);
            $display("PHY ID2         = 0x%04h", dut.phy_id2);
            $display("========================================");
            $display("");

            $stop;
        end
        else begin
            $display("");
            $display("========================================");
            $display("TEST PASSED");
            $display("PHY ID1 = 0x%04h", dut.phy_id1);
            $display("PHY ID2 = 0x%04h", dut.phy_id2);
            $display("PHY ID  = 0x%08h", dut.phy_id);
            $display("========================================");
            $display("");

            repeat (10) begin
                @(posedge clk);
            end

            $finish;
        end
    end

    /*
     * 仿真超时保护
     */
    initial begin
        #100_000_000;

        $display("");
        $display("========================================");
        $display("TEST FAILED: Simulation timeout");
        $display("busy  = %b", dut.phy_id_busy);
        $display("valid = %b", dut.phy_id_valid);
        $display("error = %b", dut.phy_id_error);
        $display("ID1   = 0x%04h", dut.phy_id1);
        $display("ID2   = 0x%04h", dut.phy_id2);
        $display("========================================");
        $display("");

        $stop;
    end

endmodule
