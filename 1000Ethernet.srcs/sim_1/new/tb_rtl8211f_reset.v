`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/08/01 17:46:37
// Design Name: 
// Module Name: tb_rtl8211f_reset
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


`timescale 1ns / 1ps

module tb_rtl8211f_reset;

    /*
     * 为了加快仿真：
     *
     * CLK_FREQUENCY = 1000 Hz
     *
     * RESET_LOW_CYCLES = 1000 / 100 = 10 cycles
     * SETTLE_CYCLES    = 1000 * 3 / 100 = 30 cycles
     */
    parameter TB_CLK_FREQUENCY = 125000;
    parameter half_CLK_Period = 500000000 / TB_CLK_FREQUENCY;
    reg clk;
    reg rst_start;

    wire rst_out;
    wire rst_complete;
    wire INITIAL_CONFIG_PULSE;

    /*
     * 被测模块实例化
     */
    rst_sync #(
        .CLK_FREQUENCY(TB_CLK_FREQUENCY)
    )
    dut (
        .clk                  (clk),
        .rst_start            (rst_start),
        .rst_out              (rst_out),
        .rst_complete         (rst_complete),
        .INITIAL_CONFIG_PULSE (INITIAL_CONFIG_PULSE)
    );

    /*
     * 100 MHz仿真时钟：
     * 周期10 ns
     */
    initial begin
        clk = 1'b0;

        forever begin
            #half_CLK_Period clk = ~clk;
        end
    end

    /*
     * 测试激励
     */
    initial begin
        rst_start = 1'b0;

        /*
         * 等待模块初始化稳定
         */
        repeat (5) @(posedge clk);

        /*
         * 测试1：
         * rst_start拉高一个时钟周期
         */
        $display("--------------------------------------------------");
        $display("[%0t] Test 1: Start PHY reset", $time);
        $display("--------------------------------------------------");

        @(negedge clk);
        rst_start = 1'b1;

        @(negedge clk);
        rst_start = 1'b0;

        /*
         * 等待复位完成
         */
        wait (rst_complete == 1'b1);

        $display("[%0t] Test 1 completed", $time);

        /*
         * 检查初始化脉冲是否同时出现
         */
        if (INITIAL_CONFIG_PULSE == 1'b1) begin
            $display("[%0t] PASS: INITIAL_CONFIG_PULSE asserted", $time);
        end
        else begin
            $display("[%0t] ERROR: INITIAL_CONFIG_PULSE not asserted", $time);
        end

        /*
         * 等待几个时钟周期
         */
        repeat (5) @(posedge clk);

        /*
         * 测试2：
         * rst_start保持多个周期，检查是否只启动一次
         */
        $display("--------------------------------------------------");
        $display("[%0t] Test 2: rst_start held high", $time);
        $display("--------------------------------------------------");

        @(negedge clk);
        rst_start = 1'b1;

        repeat (5) @(negedge clk);

        rst_start = 1'b0;

        wait (rst_complete == 1'b1);

        $display("[%0t] Test 2 completed", $time);

        repeat (5) @(posedge clk);

        /*
         * 测试3：
         * 在PHY复位过程中再次产生rst_start，
         * 模块应忽略该请求
         */
        $display("--------------------------------------------------");
        $display("[%0t] Test 3: rst_start during reset process", $time);
        $display("--------------------------------------------------");

        @(negedge clk);
        rst_start = 1'b1;

        @(negedge clk);
        rst_start = 1'b0;

        /*
         * 等待复位流程进入执行状态
         */
        repeat (5) @(posedge clk);

        /*
         * 再次触发rst_start
         */
        @(negedge clk);
        rst_start = 1'b1;

        @(negedge clk);
        rst_start = 1'b0;

        wait (rst_complete == 1'b1);

        $display("[%0t] Test 3 completed", $time);

        repeat (10) @(posedge clk);

        $display("--------------------------------------------------");
        $display("[%0t] All tests finished", $time);
        $display("--------------------------------------------------");

        $finish;
    end

    /*
     * 输出信号监视
     */
    initial begin
        $monitor(
            "[%0t] rst_start=%b rst_out=%b rst_complete=%b config_pulse=%b state=%b counter=%d",
            $time,
            rst_start,
            rst_out,
            rst_complete,
            INITIAL_CONFIG_PULSE,
            dut.state,
            dut.cycle_counter
        );
    end

    /*
     * 波形文件，适用于Icarus Verilog / GTKWave。
     * Questa或ModelSim可以忽略。
     */
    initial begin
        $dumpfile("rtl8211f_reset_tb.vcd");
        $dumpvars(0, tb_rtl8211f_reset);
    end

endmodule