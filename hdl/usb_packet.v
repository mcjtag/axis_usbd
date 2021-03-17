`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: Dmitry Matyunin (https://github.com/mcjtag)
// 
// Create Date: 11.12.2019 10:06:42
// Design Name: 
// Module Name: usb_packet
// Project Name: axis_usbd
// Target Devices:
// Tool Versions:
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// Based on project 'https://github.com/ObKo/USBCore'
// License: MIT
//  Copyright (c) 2019 Dmitry Matyunin
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
// 
//////////////////////////////////////////////////////////////////////////////////

module usb_packet (
	input wire rst,
	input wire clk,
	input wire axis_rx_tvalid,
	output wire axis_rx_tready,
	input wire axis_rx_tlast,
	input wire [7:0]axis_rx_tdata,
	output wire axis_tx_tvalid,
	input wire axis_tx_tready,
	output wire axis_tx_tlast,
	output wire [7:0]axis_tx_tdata,
	output wire [1:0]trn_type,
	output wire [6:0]trn_address,
	output wire [3:0]trn_endpoint,
	output wire trn_start,
	/* DATA0/1/2 MDATA */
	output wire [1:0]rx_trn_data_type,
	output wire rx_trn_end,
	output wire [7:0]rx_trn_data,
	output wire rx_trn_valid,
	output wire [1:0]rx_trn_hsk_type,
	output wire rx_trn_hsk_received,
	/* 00 - ACK, 10 - NAK, 11 - STALL, 01 - NYET */
	input wire [1:0]tx_trn_hsk_type,
	input wire tx_trn_send_hsk,
	output wire tx_trn_hsk_sended,
	/* DATA0/1/2 MDATA */
	input wire [1:0]tx_trn_data_type,
	input wire tx_trn_data_start,
	input wire [7:0]tx_trn_data,
	input wire tx_trn_data_valid,
	output wire tx_trn_data_ready,
	input wire tx_trn_data_last,
	output wire start_of_frame,
	output wire crc_error,
	input wire [6:0]device_address
);

function [4:0]crc5;
	input [10:0]data;
	begin
		crc5[4] = ~(1'b1 ^ data[10] ^ data[7] ^ data[5] ^ data[4] ^ data[1] ^ data[0]);
		crc5[3] = ~(1'b1 ^ data[9] ^ data[6] ^ data[4] ^ data[3] ^ data[0]);
		crc5[2] = ~(1'b1 ^ data[10] ^ data[8] ^ data[7] ^ data[4] ^ data[3] ^ data[2] ^ data[1] ^ data[0]);
		crc5[1] = ~(1'b0 ^ data[9] ^ data[7] ^ data[6] ^ data[3] ^ data[2] ^ data[1] ^ data[0]);
		crc5[0] = ~(1'b1 ^ data[8] ^ data[6] ^ data[5] ^ data[2] ^ data[1] ^ data[0]);
	end
endfunction

function [15:0]crc16;
	input [7:0]d;
	input [15:0]c;
	begin
		crc16[0] = d[0] ^ d[1] ^ d[2] ^ d[3] ^ d[4] ^ d[5] ^ d[6] ^ d[7] ^ c[8] ^ c[9] ^ c[10] ^ c[11] ^ c[12] ^ c[13] ^ c[14] ^ c[15];
    	crc16[1] = d[0] ^ d[1] ^ d[2] ^ d[3] ^ d[4] ^ d[5] ^ d[6] ^ c[9] ^ c[10] ^ c[11] ^ c[12] ^ c[13] ^ c[14] ^ c[15];
    	crc16[2] = d[6] ^ d[7] ^ c[8] ^ c[9];
    	crc16[3] = d[5] ^ d[6] ^ c[9] ^ c[10];
    	crc16[4] = d[4] ^ d[5] ^ c[10] ^ c[11];
    	crc16[5] = d[3] ^ d[4] ^ c[11] ^ c[12];
    	crc16[6] = d[2] ^ d[3] ^ c[12] ^ c[13];
    	crc16[7] = d[1] ^ d[2] ^ c[13] ^ c[14];
    	crc16[8] = d[0] ^ d[1] ^ c[0] ^ c[14] ^ c[15];
    	crc16[9] = d[0] ^ c[1] ^ c[15];
    	crc16[10] = c[2];
    	crc16[11] = c[3];
    	crc16[12] = c[4];
    	crc16[13] = c[5];
    	crc16[14] = c[6];
    	crc16[15] = d[0] ^ d[1] ^ d[2] ^ d[3] ^ d[4] ^ d[5] ^ d[6] ^ d[7] ^ c[7] ^ c[8] ^ c[9] ^ c[10] ^ c[11] ^ c[12] ^ c[13] ^ c[14] ^ c[15];
	end
endfunction

localparam  [2:0]
	STATE_RX_IDLE = 3'd0,
	STATE_RX_SOF = 3'd1,
	STATE_RX_SOFCRC = 3'd2,
	STATE_RX_TOKEN = 3'd3,
	STATE_RX_TOKEN_CRC = 3'd4,
	STATE_RX_DATA = 3'd5,
	STATE_RX_DATA_CRC = 3'd6;

localparam [2:0]
	STATE_TX_IDLE = 3'd0,
	STATE_TX_HSK = 3'd1,
	STATE_TX_HSK_WAIT = 3'd2,
	STATE_TX_DATA_PID = 3'd3,
	STATE_TX_DATA = 3'd4,
	STATE_TX_DATA_CRC1 = 3'd5,
	STATE_TX_DATA_CRC2 = 3'd6;

reg [2:0]rx_state;
reg [2:0]tx_state;

wire [4:0]rx_crc5;
wire [3:0]rx_pid;
reg [10:0]rx_counter;
reg [10:0]token_data;
reg [4:0]token_crc5;
reg [15:0]rx_crc16;
wire [15:0]rx_data_crc;
reg [15:0]tx_crc16;
wire [15:0]tx_crc16_r;
reg [7:0]rx_buf1;
reg [7:0]rx_buf2;
reg tx_zero_packet;
reg sof_flag;
reg crc_err_flag;
reg trn_start_out;
reg rx_trn_end_out;
reg rx_trn_hsk_received_out;
reg [1:0]trn_type_out;
reg [1:0]rx_trn_data_type_out;
reg [1:0]rx_trn_hsk_type_out;
wire rx_valid;

reg [7:0]tx_tdata;
reg tx_tvalid;
reg tx_tlast;

assign rx_trn_data = rx_buf1;
assign rx_trn_valid = ((rx_state == STATE_RX_DATA) && (axis_rx_tvalid == 1'b1) && (rx_counter > 1)) ? rx_valid : 1'b0;
assign rx_crc5 = crc5(token_data);
assign rx_data_crc = {rx_buf2, rx_buf1};
assign trn_address = token_data[6:0];
assign trn_endpoint = token_data[10:7];

assign start_of_frame = sof_flag;
assign crc_error = crc_err_flag;
assign trn_start = trn_start_out;
assign rx_trn_end = rx_valid ? rx_trn_end_out : 1'b0;
assign rx_trn_hsk_received = rx_valid ? rx_trn_hsk_received_out : 1'b0;
assign trn_type = trn_type_out;
assign rx_trn_data_type = rx_trn_data_type_out;
assign rx_trn_hsk_type = rx_trn_hsk_type_out;
assign rx_valid = (trn_address == device_address) ? 1'b1 : 1'b0;

assign tx_trn_data_ready = (tx_state == STATE_TX_DATA) ? axis_tx_tready : 1'b0;
assign tx_trn_hsk_sended = (tx_state == STATE_TX_HSK_WAIT) ? 1'b1 : 1'b0;
assign tx_crc16_r = ~ {tx_crc16[0], tx_crc16[1], tx_crc16[2], tx_crc16[3], tx_crc16[4], tx_crc16[5], tx_crc16[6], tx_crc16[7],
                       tx_crc16[8], tx_crc16[9], tx_crc16[10], tx_crc16[11], tx_crc16[12], tx_crc16[13], tx_crc16[14], tx_crc16[15]};
assign rx_pid = axis_rx_tdata[3:0];
assign axis_rx_tready = 1'b1;

assign axis_tx_tdata = tx_tdata;
assign axis_tx_tvalid = tx_tvalid;
assign axis_tx_tlast = tx_tlast;

/* Rx Counter */
always @(posedge clk) begin
	if (rx_state == STATE_RX_IDLE) begin
		rx_counter <= 0;
	end else if (axis_rx_tvalid == 1'b1) begin
		rx_counter <= rx_counter + 1;
	end
end

/* Rx Data CRC Calculation */
always @(posedge clk) begin
	if (rx_state == STATE_RX_IDLE) begin
		rx_crc16 <= 16'hFFFF;
	end else if ((rx_state == STATE_RX_DATA) && (axis_rx_tvalid == 1'b1) && (rx_counter > 1)) begin
		rx_crc16 <= crc16(rx_buf1, rx_crc16);
	end
end

/* Tx data CRC Calculation */
always @(posedge clk) begin
	if (tx_state == STATE_TX_IDLE) begin
		tx_crc16 <= 16'hFFFF;
	end else if ((tx_state == STATE_TX_DATA) && (axis_tx_tready == 1'b1) && (tx_trn_data_valid == 1'b1)) begin
		tx_crc16 <= crc16(tx_trn_data, tx_crc16);
	end
end

/* Rx FSM */
always @(posedge clk) begin
	if (rst == 1'b1) begin
		sof_flag <= 1'b0;
		crc_err_flag <= 1'b0;
		trn_start_out <= 1'b0;
		rx_trn_end_out <= 1'b0;
		rx_trn_hsk_received_out <= 1'b0;
		rx_state <= STATE_RX_IDLE;
	end else begin
		case (rx_state)
		STATE_RX_IDLE: begin
			sof_flag <= 1'b0;
			crc_err_flag <= 1'b0;
			trn_start_out <= 1'b0;
			rx_trn_end_out <= 1'b0;
			rx_trn_hsk_received_out <= 1'b0;
		
			if ((axis_rx_tvalid == 1'b1) && (rx_pid == ~axis_rx_tdata[7:4])) begin
				if (rx_pid == 4'b0101) begin
					rx_state <= STATE_RX_SOF;
				end else if (rx_pid[1:0] == 2'b01) begin
					trn_type_out <= rx_pid[3:2];
					rx_state <= STATE_RX_TOKEN;
				end else if (rx_pid[1:0] == 2'b11) begin
					rx_trn_data_type_out <= rx_pid[3:2];
					rx_state <= STATE_RX_DATA;
				end else if (rx_pid[1:0] == 2'b10) begin
					rx_trn_hsk_type_out <= rx_pid[3:2];
					rx_trn_hsk_received_out <= 1'b1;
				end
			end
		end
		STATE_RX_SOF: begin
			if (axis_rx_tvalid == 1'b1) begin
				if (rx_counter == 0) begin
					token_data[7:0] <= axis_rx_tdata;
				end else if (rx_counter == 1) begin
					token_data[10:8] <= axis_rx_tdata[2:0];
					token_crc5 <= axis_rx_tdata[7:3];
				end
				if (axis_rx_tlast == 1'b1) begin
					rx_state <= STATE_RX_SOFCRC;
				end
			end
		end
		STATE_RX_SOFCRC: begin
			if (token_crc5 != rx_crc5) begin
				crc_err_flag <= 1'b1;
			end else begin
				sof_flag <= 1'b1;
			end
			rx_state <= STATE_RX_IDLE;
		end
		STATE_RX_TOKEN: begin
			if (axis_rx_tvalid == 1'b1) begin
				if (rx_counter == 0) begin
					token_data[7:0] <= axis_rx_tdata;
				end else if (rx_counter == 1) begin
					token_data[10:8] <= axis_rx_tdata[2:0];
					token_crc5 <= axis_rx_tdata[7:3];
				end
				if (axis_rx_tlast == 1'b1) begin
					rx_state <= STATE_RX_TOKEN_CRC;
				end
			end
		end
		STATE_RX_TOKEN_CRC: begin
			if (device_address == token_data[6:0]) begin
				if (token_crc5 == rx_crc5) begin
					trn_start_out <= 1'b1;
				end else begin
					crc_err_flag <= 1'b1;
				end
			end
			rx_state <= STATE_RX_IDLE;
		end
		STATE_RX_DATA: begin
			if (axis_rx_tvalid == 1'b1) begin
				if (rx_counter == 0) begin
					rx_buf1 <= axis_rx_tdata;
				end else if (rx_counter == 1) begin
					rx_buf2 <= axis_rx_tdata;
				end else begin
					rx_buf1 <= rx_buf2;
					rx_buf2 <= axis_rx_tdata;
				end
				if (axis_rx_tlast == 1'b1) begin
					rx_state <= STATE_RX_DATA_CRC;
				end
			end
		end
		STATE_RX_DATA_CRC: begin
			rx_trn_end_out <= 1'b1;
			if (rx_data_crc != rx_crc16) begin
				crc_err_flag <= 1'b1;
			end
			rx_state <= STATE_RX_IDLE;
		end
        endcase
	end
end

/* Tx FSM */
always @(posedge clk) begin
	if (rst == 1'b1) begin
		tx_state <= STATE_TX_IDLE;
	end else begin
		case (tx_state) 
		STATE_TX_IDLE: begin
			if (tx_trn_send_hsk == 1'b1) begin
				tx_state <= STATE_TX_HSK;
			end else if (tx_trn_data_start == 1'b1) begin
				if ((tx_trn_data_last == 1'b1) && (tx_trn_data_valid == 1'b0)) begin
					tx_zero_packet <= 1'b1;
				end else begin
					tx_zero_packet <= 1'b0;
				end
				tx_state <= STATE_TX_DATA_PID;
			end
		end
		STATE_TX_HSK: begin
			if (axis_tx_tready == 1'b1) begin
				tx_state <= STATE_TX_HSK_WAIT;
			end
		end
		STATE_TX_HSK_WAIT: begin
			if (tx_trn_send_hsk == 1'b0) begin
				tx_state <= STATE_TX_IDLE;
			end
		end
		STATE_TX_DATA_PID: begin
			if (axis_tx_tready == 1'b1) begin
				if (tx_zero_packet == 1'b1) begin
					tx_state <= STATE_TX_DATA_CRC1;
				end else begin
					tx_state <= STATE_TX_DATA;
				end
			end
		end
		STATE_TX_DATA: begin
			if ((axis_tx_tready == 1'b1) && (tx_trn_data_valid == 1'b1)) begin
				if (tx_trn_data_last == 1'b1) begin
					tx_state <= STATE_TX_DATA_CRC1;
				end
			end else if (tx_trn_data_valid == 1'b0) begin
				tx_state <= STATE_TX_DATA_CRC2;
			end
		end
		STATE_TX_DATA_CRC1: begin
			if (axis_tx_tready == 1'b1) begin
				tx_state <= STATE_TX_DATA_CRC2;
			end
		end
		STATE_TX_DATA_CRC2: begin
			if (axis_tx_tready == 1'b1) begin
				tx_state <= STATE_TX_IDLE;
			end
		end
        endcase
	end
end

always @(*) begin
	if (tx_state == STATE_TX_DATA_PID) begin
		tx_tdata <= {(~{tx_trn_data_type,2'b11}),{tx_trn_data_type,2'b11}};
	end else if (tx_state == STATE_TX_HSK) begin
		tx_tdata <= {(~{tx_trn_hsk_type,2'b10}),tx_trn_hsk_type,2'b10};
	end else if ((tx_state == STATE_TX_DATA_CRC1) || ((tx_state == STATE_TX_DATA) && (tx_trn_data_valid == 1'b0))) begin
		tx_tdata <= tx_crc16_r[7:0];
	end else if (tx_state == STATE_TX_DATA_CRC2) begin
		tx_tdata <= tx_crc16_r[15:8];
	end else begin
		tx_tdata <= tx_trn_data;
	end

	if ((tx_state == STATE_TX_DATA_PID) || (tx_state == STATE_TX_HSK) || (tx_state == STATE_TX_DATA_CRC1) ||
	    (tx_state == STATE_TX_DATA_CRC2) || (tx_state == STATE_TX_DATA)) begin
		tx_tvalid <= 1'b1;
	end else begin
		tx_tvalid <= 1'b0;
	end
	
	if ((tx_state == STATE_TX_HSK) || (tx_state == STATE_TX_DATA_CRC2)) begin
		tx_tlast <= 1'b1;
	end else begin
		tx_tlast <= 1'b0;
	end
end

endmodule
