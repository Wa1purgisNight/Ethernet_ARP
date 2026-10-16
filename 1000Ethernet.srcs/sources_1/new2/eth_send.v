`timescale 1ns/1ns
module eth_send(
	rst_n,
	
	tx_go,
	data_length,
	
	des_mac,
	src_mac,
	type_length,
	CRC_Result,
	CRC_EN,
	
	//����fifo
	fifo_rdreq,
	fifo_rddata,
	fifo_rdclk,
	
	//GMII �ӿ��ź�	
	gmii_tx_clk,
	gmii_tx_en,
	gmii_tx_er,
	gmii_tx_data
);

	input rst_n; //��λ����
	input tx_go; //���������źţ���ʱ�����ڸ�����ʹ��һ�η���
	
	input [47:0]des_mac; //Ŀ��MAC��ַ
	input [47:0]src_mac; //����/ԴMAC��ַ
	input [15:0]type_length;	//����֡����
	input [31:0]CRC_Result;	//CRCУ����
	input [15:0]data_length;	//���ݳ���
	
	output CRC_EN;
	
	output fifo_rdreq;	//fifo��ȡ����	
	input [7:0]fifo_rddata;	//fifo��ȡ����������
	output fifo_rdclk;	//fifo��ʱ��
	
	//GMII �ӿ��ź�	
	input gmii_tx_clk; //GMII�ӿڷ���ʱ�ӣ�125MHz
	output reg gmii_tx_en;	//GMII�ӿڷ�������ʹ���źţ��ߵ�ƽ��Ч
	output reg gmii_tx_er = 1'b0;	//���ʹ��������ƻ����ݰ�����
	output reg [7:0]gmii_tx_data;	//GMII�ӿ��������ߣ�FPGAͨ���������߽���Ҫ���͵����������͸�PHYоƬ

	reg [5:0] cnt;		//���л�������������̫��֡����ϵͳʹ���������л���ʽ���
	reg en_tx;	//�ڲ�������֡����ʹ���źţ��ߵ�ƽʱ������ͨ��MII�ӿ��ͳ�
	wire en_tx_data;	//����MAC֡�����ݲ���ʹ���źţ�һ��������MAC֡�������ݺ�MAC֡ͷ�Լ���β��У�鲿�֣����ź����ڱ�ʶ֡�����ݶβ���
	reg [15:0]data_num;	//�����͵�����֡�����ݲ�������
	
	reg [47:0]r_des_mac; //Ŀ��MAC��ַ
	reg [15:0]r_type_length;	//����֡����
	
	assign fifo_rdreq = en_tx_data;	//fifo������fifo��Ҫ����Ϊshow aheadģʽ
	
	assign fifo_rdclk = gmii_tx_clk;	//fifo��ʱ��
	
	always@(posedge gmii_tx_clk)
	if(tx_go)
		r_des_mac <= des_mac;
	else
		r_des_mac <= r_des_mac;
		
	always@(posedge gmii_tx_clk)
	if(tx_go)
		r_type_length <= type_length;
	else
		r_type_length <= r_type_length;
	
	//���ݷ��������źŲ����ڲ�����ʹ���ź�
	always@(posedge gmii_tx_clk or negedge rst_n)
	if(!rst_n)
		en_tx <= #1  1'd0;
	else if(tx_go)
		en_tx <= #1  1'd1;
	else if(cnt >= 27)//һ֡���ݷ�����ɣ����㷢��ʹ���ź�
		en_tx <= #1  1'd0;
	
	//�����л�������
	always@(posedge gmii_tx_clk or negedge rst_n)
	if(!rst_n)
		cnt <= #1  6'd0;
	else if(en_tx)begin
		if(!en_tx_data) 
			cnt <= #1  cnt + 6'd1;
		else	//�ڷ�������֡�е����ݲ���ʱ����������ͣ
			cnt <= #1  cnt;
	end
	else
		cnt <= #1  6'd0;		
	
	//֡�����ݷ���ʹ���ź�
	assign en_tx_data = (cnt == 23) && (data_num > 1);
	
	//���������ݼ�������ÿ����һ�����ݶ��е����ݣ�����������1.
	always@(posedge gmii_tx_clk or negedge rst_n)
	if(!rst_n)
		data_num <= #1  0;
	else if(tx_go)
		data_num <= #1  data_length;
	else if(en_tx_data)
		data_num <= #1  data_num - 1'b1;
	else
		data_num <= #1  data_num;
		
	assign CRC_EN = ((cnt > 9) && (cnt <= 24));
	
	//���л����֣����ݲ�ͬ��ʱ�̣��л�MII�ӿ��������ϵ����ݣ�����ǰ���롢�ָ�����Ŀ�ĵ�ַ��Դ��ַ����̫��֡����/���ȡ����ݶ����ݡ���βCRCУ��ֵ
	always@(posedge gmii_tx_clk or negedge rst_n)
	if(!rst_n)
		gmii_tx_data <= #1  8'd0;
	else begin
		case(cnt)
			1, 2, 3, 4, 5, 6, 7:
				gmii_tx_data <= #1  8'h55;	//ǰ����
				
			8: gmii_tx_data <= #1  8'hd5;	//�ָ���
			
			//Ŀ��MAC��ַ
			9: gmii_tx_data <= #1  r_des_mac[47:40];
			10: gmii_tx_data <= #1  r_des_mac[39:32];
			11: gmii_tx_data <= #1  r_des_mac[31:24];
			12: gmii_tx_data <= #1  r_des_mac[23:16];
			13: gmii_tx_data <= #1  r_des_mac[15:8];
			14: gmii_tx_data <= #1  r_des_mac[7:0];

			//ԴMAC��ַ
			15: gmii_tx_data <= #1  src_mac[47:40];
			16: gmii_tx_data <= #1  src_mac[39:32];
			17: gmii_tx_data <= #1  src_mac[31:24];
			18: gmii_tx_data <= #1  src_mac[23:16];
			19: gmii_tx_data <= #1  src_mac[15:8];
			20: gmii_tx_data <= #1  src_mac[7:0];
			
			//��̫��֡����/����
			21: gmii_tx_data <= #1  r_type_length[15:8];
			22: gmii_tx_data <= #1  r_type_length[7:0];
			
			//��������
			23: gmii_tx_data <= #1  fifo_rddata;
			
			//����CRC У����
			24: gmii_tx_data <= #1  CRC_Result[31:24];
			25: gmii_tx_data <= #1  CRC_Result[23:16];
			26: gmii_tx_data <= #1  CRC_Result[15:8];
			27: gmii_tx_data <= #1  CRC_Result[7:0];
	
			28: gmii_tx_data <= #1  8'd0;
			default: gmii_tx_data <= #1  8'd0;
		endcase
	end
	
	//MII���ݷ���ʹ���ź�
	always@(posedge gmii_tx_clk or negedge rst_n)
	if(!rst_n)
		gmii_tx_en <= #1  1'b0;
	else if((cnt >= 1) && (cnt <= 27))
		gmii_tx_en <= #1  1'b1;
	else
		gmii_tx_en <= #1  1'b0;

endmodule
