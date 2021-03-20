`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: Dmitry Matyunin (https://github.com/mcjtag)
// 
// Create Date: 20.03.2021 17:04:49
// Design Name: 
// Module Name: usb_ulpi
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
//  Copyright (c) 2021 Dmitry Matyunin
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

module usb_ulpi #(
	parameter integer HIGH_SPEED = 1
)
(
	input wire rst,
	/* ULPI PHY signals */
	input wire [7:0]ulpi_data_in,
	output wire [7:0]ulpi_data_out,
	input wire ulpi_dir,
	input wire ulpi_nxt,
	output wire ulpi_stp,
	output wire ulpi_reset,
	input wire ulpi_clk,
	/* RX AXI-Stream, first data is PID */
	output wire axis_rx_tvalid,
	input wire axis_rx_tready,
	output wire axis_rx_tlast,
	output wire [7:0]axis_rx_tdata,
	/* TX AXI-Stream, first data should be PID (in 4 least significant bits) */
	input wire axis_tx_tvalid,
	output wire axis_tx_tready,
	input wire axis_tx_tlast,
	input wire [7:0]axis_tx_tdata,
	output wire usb_vbus_valid,		/* VBUS has valid voltage */
	output wire usb_reset,			/* USB bus is in reset state */
	output wire usb_idle,			/* USB bus is in idle state */
	output wire usb_suspend			/* USB bus is in suspend state */
);

localparam integer SUSPEND_TIME = 190000;  	// ~3 ms
localparam integer RESET_TIME  = 190000; 	// ~3 ms
localparam integer CHIRP_K_TIME = 66000;  	// ~1 ms
localparam integer CHIRP_KJ_TIME = 120;    	// ~2 us
localparam integer SWITCH_TIME = 6000;   	// ~100 us 

localparam [3:0]
	STATE_INIT = 4'h0, 
	STATE_WRITE_REGA = 4'h1,
	STATE_WRITE_REGD = 4'h2,
	STATE_STP = 4'h3,
	STATE_RESET = 4'h4,
	STATE_SUSPEND = 4'h5,
	STATE_IDLE = 4'h6,
	STATE_TX = 4'h7,
	STATE_TX_LAST = 4'h8,
	STATE_CHIRP_START = 4'h9,
	STATE_CHIRP_STARTK = 4'hA,
	STATE_CHIRPK = 4'hB,
	STATE_CHIRPKJ = 4'hC,
	STATE_SWITCH_FSSTART = 4'hD,
	STATE_SWITCH_FS = 4'hE;

reg [3:0]state = STATE_INIT;
reg [3:0]state_after;

reg dir_d;
wire [3:0]tx_pid;
reg [7:0]reg_data;
reg [7:0]buf_data;
reg buf_last;
reg buf_valid;

wire tx_eop;
wire bus_tx_ready;

reg [2:0]chirp_kj_counter;
reg hs_enabled = 1'b0;

reg [1:0]usb_line_state;
reg [17:0]state_counter;

reg packet = 1'b0;
reg [7:0]packet_buf;

reg rx_tvalid;
reg rx_tlast;
reg [7:0]rx_tdata;
reg tx_ready;

reg usb_vbus_valid_out;
reg [7:0]ulpi_data_out_buf;
reg usb_reset_out;

assign axis_rx_tvalid = rx_tvalid;
assign axis_rx_tlast = rx_tlast;
assign axis_rx_tdata = rx_tdata;

assign ulpi_stp = ((ulpi_dir == 1'b1) && (axis_rx_tready == 1'b0)) ? 1'b1 : ((state == STATE_STP) ? 1'b1 : 1'b0);
assign ulpi_reset = rst;
assign bus_tx_ready = ((ulpi_dir == 1'b0) && (ulpi_dir == dir_d)) ? 1'b1 : 1'b0;
assign axis_tx_tready = tx_ready;
assign usb_idle = (state == STATE_IDLE) ? 1'b1 : 1'b0;
assign usb_suspend = (state == STATE_SUSPEND) ? 1'b1 : 1'b0;

assign usb_vbus_valid = usb_vbus_valid_out;
assign ulpi_data_out = ulpi_data_out_buf;
assign usb_reset = usb_reset_out;

always @(posedge ulpi_clk) begin
	if ((dir_d == ulpi_dir) && (ulpi_dir == 1'b1) && (ulpi_nxt == 1'b1)) begin
		packet_buf <= ulpi_data_in;
		if (packet == 1'b0) begin
			rx_tvalid <= 1'b0;
			packet <= 1'b1;
		end else begin
			rx_tdata <= packet_buf;
			rx_tvalid <= 1'b1;
		end
		rx_tlast <= 1'b0;
	end else if ((packet == 1'b1) && (dir_d == ulpi_dir) && ( ((ulpi_dir == 1'b1) && (ulpi_data_in[4] == 1'b0)) || (ulpi_dir == 1'b0) ) ) begin
		rx_tdata <= packet_buf;
        rx_tvalid <= 1'b1;
        rx_tlast <= 1'b1;
        packet <= 1'b0;
	end else begin
		rx_tvalid <= 1'b0;
		rx_tlast <= 1'b0;
	end
end

always @(posedge ulpi_clk) begin
	if ((dir_d == ulpi_dir) && (ulpi_dir == 1'b1) && (ulpi_nxt == 1'b0) && (ulpi_data_in[1:0] != usb_line_state)) begin
		if (state == STATE_CHIRPKJ) begin
			if (ulpi_data_in[1:0] == 2'b01) begin
				chirp_kj_counter <= chirp_kj_counter + 1;
			end
		end else begin
			chirp_kj_counter <= 0;
		end
		usb_line_state <= ulpi_data_in[1:0];
		state_counter <= 0;
	end else if (state == STATE_CHIRP_STARTK) begin
		state_counter <= 0;
	end else if (state == STATE_SWITCH_FSSTART) begin
		state_counter <= 0;
	end else begin
		state_counter <= state_counter + 1;
	end
end

always @(posedge ulpi_clk) begin
	dir_d <= ulpi_dir;
	if (dir_d == ulpi_dir) begin
		if ((ulpi_dir == 1'b1) && (ulpi_nxt == 1'b0)) begin
			if (ulpi_data_in[3:2] == 2'b11) begin
				usb_vbus_valid_out <= 1'b1;
			end else begin
				usb_vbus_valid_out <= 1'b0;
			end
		end else if (ulpi_dir == 1'b0) begin
			case (state)
			STATE_INIT: begin
				ulpi_data_out_buf <= 8'h8A;
				reg_data <= 8'h00;
				state <= STATE_WRITE_REGA;
				state_after <= STATE_SWITCH_FSSTART;
			end
			STATE_WRITE_REGA: begin
				if (ulpi_nxt == 1'b1) begin
					ulpi_data_out_buf <= reg_data;
					state <= STATE_WRITE_REGD;
				end
			end
			STATE_WRITE_REGD: begin
				if (ulpi_nxt == 1'b1) begin
					ulpi_data_out_buf <= 8'h00;
					state <= STATE_STP;
				end
			end
			STATE_RESET: begin
				usb_reset_out <= 1'b1;
				if ((hs_enabled == 1'b0) && (HIGH_SPEED == 1)) begin
					state <= STATE_CHIRP_START;
				end else if (HIGH_SPEED == 1) begin
					state <= STATE_SWITCH_FSSTART;
				end else begin
					if (usb_line_state != 2'b00) begin
						state <= STATE_IDLE;
					end
				end
			end
			STATE_SUSPEND: begin
				if (usb_line_state != 2'b01) begin
					state <= STATE_IDLE;
				end
			end
			STATE_STP: begin
				state <= state_after;
			end
			STATE_IDLE: begin
				usb_reset_out <= 1'b0;
				if ((usb_line_state == 2'b00) && (state_counter > RESET_TIME)) begin
					state <= STATE_RESET;
				end else if ((hs_enabled == 1'b0) && (usb_line_state == 2'b01) && (state_counter > SUSPEND_TIME)) begin
					state <= STATE_SUSPEND;
				end else if ((bus_tx_ready == 1'b1) && (axis_tx_tvalid == 1'b1)) begin
					ulpi_data_out_buf <= {4'b0100, axis_tx_tdata[3:0]};
					buf_valid <= 1'b0;
					if (axis_tx_tlast == 1'b1) begin
						state <= STATE_TX_LAST;
					end else begin
						state <= STATE_TX;
					end
				end
			end
			STATE_TX: begin
				if (ulpi_nxt == 1'b1) begin
					if ((axis_tx_tvalid == 1'b1) && (buf_valid == 1'b0)) begin
						ulpi_data_out_buf <= axis_tx_tdata;
						if (axis_tx_tlast == 1'b1) begin
							state <= STATE_TX_LAST;
						end
					end else if (buf_valid == 1'b1) begin
						ulpi_data_out_buf <= buf_data;
						buf_valid <= 1'b0;
						if (buf_last == 1'b1) begin
							state <= STATE_TX_LAST;
						end
					end else begin
						ulpi_data_out_buf <= 8'h00;
					end
				end else begin
					if ((axis_tx_tvalid == 1'b1) && (buf_valid == 1'b0)) begin
						buf_data <= axis_tx_tdata;
						buf_last <= axis_tx_tlast;
						buf_valid <= 1'b1;
					end
				end
			end
			STATE_TX_LAST: begin
				if (ulpi_nxt == 1'b1) begin
					ulpi_data_out_buf <= 8'h00;
					state_after <= STATE_IDLE;
					state <= STATE_STP;
				end
			end       
			STATE_CHIRP_START: begin
				reg_data <= 8'b0_1_0_10_1_00;
				ulpi_data_out_buf <= 8'h84;
				state <= STATE_WRITE_REGA;
				state_after <= STATE_CHIRP_STARTK;
			end
			STATE_CHIRP_STARTK: begin
				if (ulpi_nxt == 1'b1) begin
					ulpi_data_out_buf <= 8'h00;
					state <= STATE_CHIRPK;
				end else begin
					ulpi_data_out_buf <= 8'h40;
				end
			end
			STATE_CHIRPK: begin
				if (state_counter > CHIRP_K_TIME) begin
					ulpi_data_out_buf <= 8'h00;
					state <= STATE_STP;
					state_after <= STATE_CHIRPKJ;
				end
			end
			STATE_CHIRPKJ: begin 
				if ((chirp_kj_counter > 3) && (state_counter > CHIRP_KJ_TIME)) begin
					reg_data <= 8'b0_1_0_00_0_00;
					ulpi_data_out_buf <= 8'h84;
					state <= STATE_WRITE_REGA;
					state_after <= STATE_IDLE;
					hs_enabled <= 1'b1;
				end
			end
			STATE_SWITCH_FSSTART: begin
				reg_data <= 8'b0_1_0_00_1_01;
				ulpi_data_out_buf <= 8'h84;
				state <= STATE_WRITE_REGA;
				hs_enabled <= 1'b0;
				state_after <= STATE_SWITCH_FS;
			end
			STATE_SWITCH_FS: begin
				if (state_counter > SWITCH_TIME) begin
					if ((usb_line_state == 2'b00) && (HIGH_SPEED == 1)) begin
						state <= STATE_CHIRP_START;
					end else begin
						state <= STATE_IDLE;
					end
				end
			end
			endcase
		end
	end
end

always @(*) begin
	if ((bus_tx_ready == 1'b1) && (state == STATE_IDLE)) begin
		tx_ready <= 1'b1;
	end else if ((bus_tx_ready == 1'b1) && (state == STATE_TX) && (buf_valid == 1'b0)) begin
		tx_ready <= 1'b1;
	end else
		tx_ready <= 1'b0;
end

endmodule
