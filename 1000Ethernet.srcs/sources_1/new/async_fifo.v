`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/08/13 14:19:23
// Design Name: 
// Module Name: async_fifo
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


module async_fifo #(
    parameter DATA_WIDTH = 80,
    parameter ADDR_WIDTH = 2       // depth = 2^ADDR_WIDTH
)(
    input  wire                  wr_clk,
    input  wire                  wr_rst_n,
    input  wire [DATA_WIDTH-1:0] wr_data,
    input  wire                  wr_en,
    output wire                  full,

    input  wire                  rd_clk,
    input  wire                  rd_rst_n,
    output reg  [DATA_WIDTH-1:0] rd_data,
    input  wire                  rd_en,
    output wire                  empty,
    output reg                   rd_valid
);

    localparam PTR_WIDTH = ADDR_WIDTH + 1;
    localparam DEPTH     = (1 << ADDR_WIDTH);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // ============================================================
    // Write pointer
    // ============================================================

    reg [PTR_WIDTH-1:0] wr_bin;
    reg [PTR_WIDTH-1:0] wr_gray;

    // ============================================================
    // Read pointer
    // ============================================================

    reg [PTR_WIDTH-1:0] rd_bin;
    reg [PTR_WIDTH-1:0] rd_gray;

    // ============================================================
    // Synchronizers
    // ============================================================

    reg [PTR_WIDTH-1:0] rd_gray_sync1;
    reg [PTR_WIDTH-1:0] rd_gray_sync2;

    reg [PTR_WIDTH-1:0] wr_gray_sync1;
    reg [PTR_WIDTH-1:0] wr_gray_sync2;


    // ============================================================
    // Binary -> Gray
    // ============================================================

    wire [PTR_WIDTH-1:0] wr_bin_inc;
    wire [PTR_WIDTH-1:0] wr_gray_inc;

    wire [PTR_WIDTH-1:0] rd_bin_inc;
    wire [PTR_WIDTH-1:0] rd_gray_inc;

    assign wr_bin_inc  = wr_bin + 1'b1;
    assign wr_gray_inc = (wr_bin_inc >> 1) ^ wr_bin_inc;

    assign rd_bin_inc  = rd_bin + 1'b1;
    assign rd_gray_inc = (rd_bin_inc >> 1) ^ rd_bin_inc;


    // ============================================================
    // EMPTY
    // ============================================================

    assign empty = (rd_gray == wr_gray_sync2);


    // ============================================================
    // FULL
    //
    // Gray pointer MSB inversion
    // ADDR_WIDTH >= 2
    // ============================================================

    assign full =
        (wr_gray ==
        {
            ~rd_gray_sync2[PTR_WIDTH-1:PTR_WIDTH-2],
             rd_gray_sync2[PTR_WIDTH-3:0]
        });


    // ============================================================
    // Write domain
    // ============================================================

    always @(posedge wr_clk or negedge wr_rst_n) begin

        if (!wr_rst_n) begin

            wr_bin  <= {PTR_WIDTH{1'b0}};
            wr_gray <= {PTR_WIDTH{1'b0}};

        end

        else begin

            if (wr_en && !full) begin

                mem[wr_bin[ADDR_WIDTH-1:0]] <= wr_data;

                wr_bin  <= wr_bin_inc;
                wr_gray <= wr_gray_inc;

            end

        end

    end


    // ============================================================
    // Read domain
    // ============================================================

    always @(posedge rd_clk or negedge rd_rst_n) begin

        if (!rd_rst_n) begin

            rd_bin   <= {PTR_WIDTH{1'b0}};
            rd_gray  <= {PTR_WIDTH{1'b0}};

            rd_data  <= {DATA_WIDTH{1'b0}};
            rd_valid <= 1'b0;

        end

        else begin

            rd_valid <= 1'b0;

            if (rd_en && !empty) begin

                rd_data <= mem[rd_bin[ADDR_WIDTH-1:0]];

                rd_bin  <= rd_bin_inc;
                rd_gray <= rd_gray_inc;

                rd_valid <= 1'b1;

            end

        end

    end


    // ============================================================
    // Synchronize READ pointer -> WRITE domain
    // ============================================================

    always @(posedge wr_clk or negedge wr_rst_n) begin

        if (!wr_rst_n) begin

            rd_gray_sync1 <= {PTR_WIDTH{1'b0}};
            rd_gray_sync2 <= {PTR_WIDTH{1'b0}};

        end

        else begin

            rd_gray_sync1 <= rd_gray;
            rd_gray_sync2 <= rd_gray_sync1;

        end

    end


    // ============================================================
    // Synchronize WRITE pointer -> READ domain
    // ============================================================

    always @(posedge rd_clk or negedge rd_rst_n) begin

        if (!rd_rst_n) begin

            wr_gray_sync1 <= {PTR_WIDTH{1'b0}};
            wr_gray_sync2 <= {PTR_WIDTH{1'b0}};

        end

        else begin

            wr_gray_sync1 <= wr_gray;
            wr_gray_sync2 <= wr_gray_sync1;

        end

    end

endmodule
