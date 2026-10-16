`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/08/05 05:15:59
// Design Name: 
// Module Name: phy_id_reader
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


module phy_id_reader #(
    parameter [4:0] PHY_ADDR = 5'b00101
)(
    input  wire        clk,
    input  wire        rst_n,

    // 拉高一个clk周期，开始读取PHY ID
    input  wire        start,

    /*
     * 连接到MDIO Master的命令接口
     */
    output reg         mdio_start,
    output reg         mdio_rw,
    output reg  [4:0]  mdio_phy_addr,
    output reg  [4:0]  mdio_reg_addr,
    output reg  [15:0] mdio_write_data,

    /*
     * 来自MDIO Master的响应接口
     */
    input  wire [15:0] mdio_read_data,
    input  wire        mdio_busy,
    input  wire        mdio_write_done,
    input  wire        mdio_read_valid,
    input  wire        mdio_error,

    /*
     * PHY ID读取结果
     */
    output reg  [15:0] phy_id1,
    output reg  [15:0] phy_id2,
    output wire [31:0] phy_id,

    output reg         busy,
    output reg         valid,
    output reg         error
    
    //debug接口

);
    /*
     * Clause 22寄存器地址
     */
    localparam [4:0] REG_PHY_ID1 = 5'd2;
    localparam [4:0] REG_PHY_ID2 = 5'd3;
    localparam [4:0] REG_BMCR = 5'd9;
    /*
     * 状态定义
     */
    localparam [3:0] STATE_IDLE      = 4'd0;
    localparam [3:0] STATE_START_ID1 = 4'd1;
    localparam [3:0] STATE_WAIT_ID1  = 4'd2;
    localparam [3:0] STATE_START_ID2 = 4'd3;
    localparam [3:0] STATE_WAIT_ID2  = 4'd4;
    localparam [3:0] STATE_WR_BMCR   = 4'd5;
    localparam [3:0] STATE_WAIT_BMCR = 4'd6;
    localparam [3:0] STATE_RD_BMCR   = 4'd7;
    localparam [3:0] STATE_WAIT_BMCR2= 4'd8;
    localparam [3:0] STATE_DONE      = 4'd9;
    localparam [3:0] STATE_ERROR     = 4'd10;

    reg [3:0] state;

    assign phy_id = {phy_id1, phy_id2};

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= STATE_IDLE;

            mdio_start      <= 1'b0;
            mdio_rw         <= 1'b1;
            mdio_phy_addr   <= PHY_ADDR;
            mdio_reg_addr   <= 5'd0;
            mdio_write_data <= 16'd0;

            phy_id1 <= 16'd0;
            phy_id2 <= 16'd0;

            busy  <= 1'b0;
            valid <= 1'b0;
            error <= 1'b0;
        end
        else begin
            /*
             * 脉冲信号默认拉低
             */
            mdio_start <= 1'b0;
            valid      <= 1'b0;

            case (state)

                /*
                 * 等待外部启动
                 */
                STATE_IDLE: begin
                    busy  <= 1'b0;
                    error <= 1'b0;

                    if (start) begin
                        phy_id1 <= 16'd0;
                        phy_id2 <= 16'd0;

                        busy  <= 1'b1;
                        state <= STATE_START_ID1;
                    end
                end

                /*
                 * 发起寄存器2读取
                 */
                STATE_START_ID1: begin
                    busy <= 1'b1;

                    if (!mdio_busy) begin
                        mdio_rw         <= 1'b1;
                        mdio_phy_addr   <= PHY_ADDR;
                        mdio_reg_addr   <= REG_PHY_ID1;
                        mdio_write_data <= 16'd0;
                        mdio_start      <= 1'b1;

                        state <= STATE_WAIT_ID1;
                    end
                end

                /*
                 * 等待寄存器2读取完成
                 */
                STATE_WAIT_ID1: begin
                    busy <= 1'b1;

                    if (mdio_read_valid) begin
                        if (mdio_error) begin
                            state <= STATE_ERROR;
                        end
                        else begin
                            phy_id1 <= mdio_read_data;
                            state   <= STATE_START_ID2;
                        end
                    end
                end

                /*
                 * 发起寄存器3读取
                 */
                STATE_START_ID2: begin
                    busy <= 1'b1;

                    if (!mdio_busy) begin
                        mdio_rw         <= 1'b1;
                        mdio_phy_addr   <= PHY_ADDR;
                        mdio_reg_addr   <= REG_PHY_ID2;
                        mdio_write_data <= 16'd0;
                        mdio_start      <= 1'b1;

                        state <= STATE_WAIT_ID2;
                    end
                end

                /*
                 * 等待寄存器3读取完成
                 */
                STATE_WAIT_ID2: begin
                    busy <= 1'b1;

                    if (mdio_read_valid) begin
                        if (mdio_error) begin
                            state <= STATE_ERROR;
                        end
                        else begin
                            phy_id2 <= mdio_read_data;
                            state   <= STATE_WR_BMCR;
                        end
                    end
                end

                /*
                 * 发起寄存器0写
                 */
                STATE_WR_BMCR: begin
                    busy <= 1'b1;

                    if (!mdio_busy) begin
                        mdio_rw         <= 1'b0;
                        mdio_phy_addr   <= PHY_ADDR;
                        mdio_reg_addr   <= REG_BMCR;
                        mdio_write_data <= 16'h0200;
                        mdio_start      <= 1'b1;

                        state <= STATE_WAIT_BMCR;
                    end
                end

                /*
                 * 等待寄存器0写完成
                 */
                STATE_WAIT_BMCR: begin
                    busy <= 1'b1;

                    if (mdio_write_done) begin //这里改成mdio_write_done
                        if (mdio_error) begin
                            state <= STATE_ERROR;
                        end
                        else begin
                            state   <= STATE_RD_BMCR;
                        end
                    end
                end
                
                                /*
                 * 发起寄存器0读取
                 */
                STATE_RD_BMCR: begin
                    busy <= 1'b1;

                    if (!mdio_busy) begin
                        mdio_rw         <= 1'b1;
                        mdio_phy_addr   <= PHY_ADDR;
                        mdio_reg_addr   <= REG_BMCR;
                        mdio_write_data <= 16'd0;
                        mdio_start      <= 1'b1;

                        state <= STATE_WAIT_BMCR2;
                    end
                end

                /*
                 * 等待寄存器0读取完成
                 */
                STATE_WAIT_BMCR2: begin
                    busy <= 1'b1;

                    if (mdio_read_valid) begin
                        if (mdio_error) begin
                            state <= STATE_ERROR;
                        end
                        else begin
                            phy_id2 <= mdio_read_data;
                            state   <= STATE_DONE;
                        end
                    end
                end

                /*
                 * 两个寄存器均读取完成
                 */
                STATE_DONE: begin
                    busy  <= 1'b0;
                    valid <= 1'b1;
                    state <= STATE_IDLE;
                end

                /*
                 * 任意一次MDIO访问出现错误
                 */
                STATE_ERROR: begin
                    busy  <= 1'b0;
                    error <= 1'b1;
                    state <= STATE_IDLE;
                end

                default: begin
                    state <= STATE_IDLE;
                end

            endcase
        end
    end

endmodule