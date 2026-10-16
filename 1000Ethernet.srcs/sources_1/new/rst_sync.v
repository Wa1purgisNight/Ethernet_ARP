`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/08/01 17:15:40
// Design Name: 
// Module Name: rst_sync
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


module rst_sync #(
    // 输入时钟频率，单位：Hz
    parameter CLK_FREQUENCY = 100_000_000,
    parameter RST_HOLDTIME_ms = 10,
    parameter RST_RELEASETIME_ms = 30
)(
    input  wire clk,
    input  wire rst_start,

    // 连接 RTL8211F 的 PHYRSTB 引脚，低电平有效
    output reg  rst_out,

    // 完整复位流程结束脉冲，持续一个 clk 周期
    output reg  rst_complete,

    // PHY 寄存器初始化启动脉冲，持续一个 clk 周期
    output reg  INITIAL_CONFIG_PULSE
);

    /*
     * 向上取整，确保复位时间不小于数据手册要求。
     *
     * 10 ms = 1 / 100 s
     * 30 ms = 3 / 100 s
     */
    localparam RESET_LOW_CYCLES = (CLK_FREQUENCY / 1000) * RST_HOLDTIME_ms;
    localparam SETTLE_CYCLES    = (CLK_FREQUENCY / 1000) * RST_RELEASETIME_ms;

    localparam MAX_CYCLES =
        (RESET_LOW_CYCLES > SETTLE_CYCLES) ?
         RESET_LOW_CYCLES : SETTLE_CYCLES;

    /*
     * Verilog-2001 不支持 $clog2，因此自行定义函数。
     */
    function integer clog2;
        input integer value;
        integer temp;
        begin
            temp  = value - 1;
            clog2 = 0;

            while (temp > 0) begin
                temp  = temp >> 1;
                clog2 = clog2 + 1;
            end

            // 保证计数器位宽至少为1
            if (clog2 < 1)
                clog2 = 1;
        end
    endfunction

    localparam COUNTER_WIDTH = clog2(MAX_CYCLES);

    /*
     * 状态定义
     */
    localparam STATE_IDLE      = 2'd0;
    localparam STATE_RESET_LOW = 2'd1;
    localparam STATE_SETTLE    = 2'd2;

    reg [1:0] state;

    reg [COUNTER_WIDTH-1:0] cycle_counter;

    /*
     * rst_start 上升沿检测。
     *
     * 即使 rst_start 持续为高电平，也只会启动一次复位流程。
     */
    reg rst_start_d;

    wire rst_start_rise;

    assign rst_start_rise = rst_start & (~rst_start_d);

    /*
     * FPGA上电初始化。
     *
     * rst_out初始化为高电平，即默认不复位PHY。
     * Xilinx Vivado、Intel Quartus等FPGA工具通常支持该写法。
     */
    initial begin
        state                = STATE_IDLE;
        cycle_counter        = {COUNTER_WIDTH{1'b0}};
        rst_start_d          = 1'b0;
        rst_out              = 1'b1;
        rst_complete         = 1'b0;
        INITIAL_CONFIG_PULSE = 1'b0;
    end

    always @(posedge clk) begin
        /*
         * 保存上一周期的rst_start，用于上升沿检测。
         */
        rst_start_d <= rst_start;

        /*
         * 默认拉低，确保输出的是单周期脉冲。
         */
        rst_complete         <= 1'b0;
        INITIAL_CONFIG_PULSE <= 1'b0;

        case (state)

            /*
             * 空闲状态：
             * PHYRSTB保持高电平。
             */
            STATE_IDLE: begin
                rst_out       <= 1'b1;
                cycle_counter <= {COUNTER_WIDTH{1'b0}};

                if (rst_start_rise) begin
                    /*
                     * 检测到rst_start上升沿后，
                     * 立即将PHYRSTB拉低。
                     */
                    rst_out       <= 1'b0;
                    cycle_counter <= {COUNTER_WIDTH{1'b0}};
                    state         <= STATE_RESET_LOW;
                end
            end

            /*
             * PHY硬复位状态：
             * PHYRSTB至少保持低电平10 ms。
             */
            STATE_RESET_LOW: begin
                rst_out <= 1'b0;

                if (cycle_counter >= RESET_LOW_CYCLES - 1) begin
                    /*
                     * 10 ms计时结束，释放PHY复位。
                     */
                    rst_out       <= 1'b1;
                    cycle_counter <= {COUNTER_WIDTH{1'b0}};
                    state         <= STATE_SETTLE;
                end
                else begin
                    cycle_counter <= cycle_counter + 1'b1;
                end
            end

            /*
             * PHY内部电路稳定等待状态：
             * PHYRSTB保持高电平，并等待至少30 ms。
             */
            STATE_SETTLE: begin
                rst_out <= 1'b1;

                if (cycle_counter >= SETTLE_CYCLES - 1) begin
                    cycle_counter <= {COUNTER_WIDTH{1'b0}};

                    /*
                     * 30 ms等待结束。
                     * 两个信号均输出一个clk周期。
                     */
                    rst_complete         <= 1'b1;
                    INITIAL_CONFIG_PULSE <= 1'b1;

                    state <= STATE_IDLE;
                end
                else begin
                    cycle_counter <= cycle_counter + 1'b1;
                end
            end

            /*
             * 异常状态恢复。
             */
            default: begin
                state                <= STATE_IDLE;
                cycle_counter        <= {COUNTER_WIDTH{1'b0}};
                rst_out              <= 1'b1;
                rst_complete         <= 1'b0;
                INITIAL_CONFIG_PULSE <= 1'b0;
            end

        endcase
    end

endmodule
