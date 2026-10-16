`timescale 1ns / 1ps

module tb_crc;

    // ============================================================
    // Method 1
    // ============================================================
    function [31:0] nextCRC32_D8;
        input [7:0] Data;
        input [31:0] crc;

        reg [7:0] d;
        reg [31:0] c;
        reg [31:0] newcrc;

        begin
            d = Data;
            c = crc;

            newcrc[0] = d[6] ^ d[0] ^ c[24] ^ c[30];
            newcrc[1] = d[7] ^ d[6] ^ d[1] ^ d[0] ^ c[24] ^ c[25] ^ c[30] ^ c[31];
            newcrc[2] = d[7] ^ d[6] ^ d[2] ^ d[1] ^ d[0] ^ c[24] ^ c[25] ^ c[26] ^ c[30] ^ c[31];
            newcrc[3] = d[7] ^ d[3] ^ d[2] ^ d[1] ^ c[25] ^ c[26] ^ c[27] ^ c[31];
            newcrc[4] = d[6] ^ d[4] ^ d[3] ^ d[2] ^ d[0] ^ c[24] ^ c[26] ^ c[27] ^ c[28] ^ c[30];
            newcrc[5] = d[7] ^ d[6] ^ d[5] ^ d[4] ^ d[3] ^ d[1] ^ d[0] ^
                        c[24] ^ c[25] ^ c[27] ^ c[28] ^ c[29] ^ c[30] ^ c[31];
            newcrc[6] = d[7] ^ d[6] ^ d[5] ^ d[4] ^ d[2] ^ d[1] ^
                        c[25] ^ c[26] ^ c[28] ^ c[29] ^ c[30] ^ c[31];
            newcrc[7] = d[7] ^ d[5] ^ d[3] ^ d[2] ^ d[0] ^
                        c[24] ^ c[26] ^ c[27] ^ c[29] ^ c[31];
            newcrc[8] = d[4] ^ d[3] ^ d[1] ^ d[0] ^
                        c[0] ^ c[24] ^ c[25] ^ c[27] ^ c[28];
            newcrc[9] = d[5] ^ d[4] ^ d[2] ^ d[1] ^
                        c[1] ^ c[25] ^ c[26] ^ c[28] ^ c[29];
            newcrc[10] = d[5] ^ d[3] ^ d[2] ^ d[0] ^
                         c[2] ^ c[24] ^ c[26] ^ c[27] ^ c[29];
            newcrc[11] = d[4] ^ d[3] ^ d[1] ^ d[0] ^
                         c[3] ^ c[24] ^ c[25] ^ c[27] ^ c[28];
            newcrc[12] = d[6] ^ d[5] ^ d[4] ^ d[2] ^ d[1] ^ d[0] ^
                         c[4] ^ c[24] ^ c[25] ^ c[26] ^ c[28] ^ c[29] ^ c[30];
            newcrc[13] = d[7] ^ d[6] ^ d[5] ^ d[3] ^ d[2] ^ d[1] ^
                         c[5] ^ c[25] ^ c[26] ^ c[27] ^ c[29] ^ c[30] ^ c[31];
            newcrc[14] = d[7] ^ d[6] ^ d[4] ^ d[3] ^ d[2] ^
                         c[6] ^ c[26] ^ c[27] ^ c[28] ^ c[30] ^ c[31];
            newcrc[15] = d[7] ^ d[5] ^ d[4] ^ d[3] ^
                         c[7] ^ c[27] ^ c[28] ^ c[29] ^ c[31];
            newcrc[16] = d[5] ^ d[4] ^ d[0] ^
                         c[8] ^ c[24] ^ c[28] ^ c[29];
            newcrc[17] = d[6] ^ d[5] ^ d[1] ^
                         c[9] ^ c[25] ^ c[29] ^ c[30];
            newcrc[18] = d[7] ^ d[6] ^ d[2] ^
                         c[10] ^ c[26] ^ c[30] ^ c[31];
            newcrc[19] = d[7] ^ d[3] ^
                         c[11] ^ c[27] ^ c[31];
            newcrc[20] = d[4] ^ c[12] ^ c[28];
            newcrc[21] = d[5] ^ c[13] ^ c[29];
            newcrc[22] = d[0] ^ c[14] ^ c[24];
            newcrc[23] = d[6] ^ d[1] ^ d[0] ^
                         c[15] ^ c[24] ^ c[25] ^ c[30];
            newcrc[24] = d[7] ^ d[2] ^ d[1] ^
                         c[16] ^ c[25] ^ c[26] ^ c[31];
            newcrc[25] = d[3] ^ d[2] ^
                         c[17] ^ c[26] ^ c[27];
            newcrc[26] = d[6] ^ d[4] ^ d[3] ^ d[0] ^
                         c[18] ^ c[24] ^ c[27] ^ c[28] ^ c[30];
            newcrc[27] = d[7] ^ d[5] ^ d[4] ^ d[1] ^
                         c[19] ^ c[25] ^ c[28] ^ c[29] ^ c[31];
            newcrc[28] = d[6] ^ d[5] ^ d[2] ^
                         c[20] ^ c[26] ^ c[29] ^ c[30];
            newcrc[29] = d[7] ^ d[6] ^ d[3] ^
                         c[21] ^ c[27] ^ c[30] ^ c[31];
            newcrc[30] = d[7] ^ d[4] ^
                         c[22] ^ c[28] ^ c[31];
            newcrc[31] = d[5] ^ c[23] ^ c[29];

            nextCRC32_D8 = newcrc;
        end
    endfunction


    // ============================================================
    // Method 2
    // Ethernet reflected CRC32
    // Polynomial = 0xEDB88320
    // ============================================================
    function [31:0] crc32_byte;
        input [31:0] crc_in;
        input [7:0]  data_in;

        integer i;
        reg [31:0] crc;
        reg [7:0]  data;

        begin
            crc  = crc_in;
            data = data_in;

            for (i = 0; i < 8; i = i + 1) begin
                if (crc[0] ^ data[0])
                    crc = (crc >> 1) ^ 32'hEDB88320;
                else
                    crc = crc >> 1;

                data = data >> 1;
            end

            crc32_byte = crc;
        end
    endfunction


    // ============================================================
    // Bit reversal
    // ============================================================
    function [7:0] reverse8;
        input [7:0] din;
        integer i;

        begin
            for (i = 0; i < 8; i = i + 1)
                reverse8[i] = din[7-i];
        end
    endfunction


    function [31:0] reverse32;
        input [31:0] din;
        integer i;

        begin
            for (i = 0; i < 32; i = i + 1)
                reverse32[i] = din[31-i];
        end
    endfunction


    // ============================================================
    // Test data
    // ============================================================
    reg [7:0] frame [0:59];

    reg [31:0] crc_method1;
    reg [31:0] crc_method2;

    reg [31:0] fcs_method1;
    reg [31:0] fcs_method2;

    integer i;


    initial begin

        // ========================================================
        // Ethernet ARP Reply
        //
        // Destination MAC : B0:25:AA:61:61:1F
        // Source MAC      : 02:00:00:00:00:01
        // EtherType       : 0806
        //
        // ARP:
        // HTYPE = 0001
        // PTYPE = 0800
        // HLEN  = 06
        // PLEN  = 04
        // OPER  = 0002
        //
        // Sender MAC = 02:00:00:00:00:01
        // Sender IP  = 192.168.1.123
        // Target MAC = B0:25:AA:61:61:1F
        // Target IP  = 192.168.1.10
        //
        // Ethernet minimum payload = 46 bytes
        // ARP payload = 28 bytes
        // Padding = 18 bytes
        //
        // Total before FCS = 60 bytes
        // ========================================================

        // Destination MAC
        frame[0]  = 8'hff;
        frame[1]  = 8'hff;
        frame[2]  = 8'hff;
        frame[3]  = 8'hff;
        frame[4]  = 8'hff;
        frame[5]  = 8'hff;

        // Source MAC
        frame[6]  = 8'hb0;
        frame[7]  = 8'h25;
        frame[8]  = 8'haa;
        frame[9]  = 8'h61;
        frame[10] = 8'h61;
        frame[11] = 8'h1f;

        // EtherType = ARP
        frame[12] = 8'h08;
        frame[13] = 8'h06;

        // ARP HTYPE = Ethernet
        frame[14] = 8'h00;
        frame[15] = 8'h01;

        // ARP PTYPE = IPv4
        frame[16] = 8'h08;
        frame[17] = 8'h00;

        // HLEN
        frame[18] = 8'h06;

        // PLEN
        frame[19] = 8'h04;

        // OPER = Reply
        frame[20] = 8'h00;
        frame[21] = 8'h01;

        // Sender MAC
        frame[22] = 8'hb0;
        frame[23] = 8'h25;
        frame[24] = 8'haa;
        frame[25] = 8'h61;
        frame[26] = 8'h61;
        frame[27] = 8'h1f;

        // Sender IP = 192.168.1.123
        frame[28] = 8'hC0;
        frame[29] = 8'hA8;
        frame[30] = 8'h01;
        frame[31] = 8'h0a;

        // Target MAC
        frame[32] = 8'h00;
        frame[33] = 8'h00;
        frame[34] = 8'h00;
        frame[35] = 8'h00;
        frame[36] = 8'h00;
        frame[37] = 8'h00;

        // Target IP = 192.168.1.10
        frame[38] = 8'hC0;
        frame[39] = 8'hA8;
        frame[40] = 8'h01;
        frame[41] = 8'h7b;
        
        frame[42] = 8'h00;
        frame[43] = 8'h00;
        frame[44] = 8'hff;
        frame[45] = 8'hff;
        frame[46] = 8'hff;
        frame[47] = 8'hff;
        frame[48] = 8'hff;
        frame[49] = 8'hff; 
        frame[50] = 8'h00;
        frame[51] = 8'h23;
        frame[52] = 8'hcd;
        frame[53] = 8'h76;
        frame[54] = 8'h63;
        frame[55] = 8'h1a;
        frame[56] = 8'h08;
        frame[57] = 8'h06;
        frame[58] = 8'h00;
        frame[59] = 8'h01;
        // Padding
        /*for (i = 42; i < 60; i = i + 1)
            frame[i] = 8'h00;*/


        // ========================================================
        // Initial CRC
        // ========================================================

        crc_method1 = 32'hFFFF_FFFF;
        crc_method2 = 32'hFFFF_FFFF;


        // ========================================================
        // Calculate CRC
        // ========================================================

        for (i = 0; i < 60; i = i + 1) begin

            // ----------------------------------------------------
            // Method 1
            // Your generated parallel CRC function
            // ----------------------------------------------------
            crc_method1 =
                nextCRC32_D8(
                    frame[i],
                    crc_method1
                );


            // ----------------------------------------------------
            // Method 2
            // Reflected Ethernet CRC
            //
            // Convert bit ordering so that it can be compared
            // directly with nextCRC32_D8
            // ----------------------------------------------------
            /*crc_method2 =
                reverse32(
                    crc32_byte(
                        reverse32(crc_method2),
                        reverse8(frame[i])
                    )
                );*/
            crc_method2 =
                    crc32_byte(
                        crc_method2,
                        frame[i]
                );


            $display(
                "%02d : data=%02h  crc1=%08h  crc2=%08h",
                i,
                frame[i],
                crc_method1,
                crc_method2
            );


            if (crc_method1 !== crc_method2)
                $display("ERROR: CRC mismatch at byte %0d", i);

        end


        // ========================================================
        // Final XOR
        // ========================================================

        fcs_method1 = ~crc_method1;
        fcs_method2 = ~crc_method2;


        $display("");
        $display("========================================");
        $display("CRC calculation finished");
        $display("========================================");

        $display("CRC1 before XOR = %08h", crc_method1);
        $display("CRC2 before XOR = %08h", crc_method2);

        $display("");

        $display("FCS1 = %08h", fcs_method1);
        $display("FCS2 = %08h", fcs_method2);


        if (fcs_method1 === fcs_method2)
            $display("CRC MATCH SUCCESSFULLY");
        else
            $display("CRC MISMATCH");


        // ========================================================
        // Actual Ethernet byte transmission order
        // ========================================================

        $display("");
        $display("FCS transmission bytes:");

        $display(
            "%02h %02h %02h %02h",
            fcs_method1[31:24],
            fcs_method1[23:16],
            fcs_method1[15:8],
            fcs_method1[7:0]
        );


        $finish;

    end

endmodule