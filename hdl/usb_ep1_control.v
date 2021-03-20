`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: Dmitry Matyunin (https://github.com/mcjtag)
// 
// Create Date: 20.03.2021 12:46:03
// Design Name: 
// Module Name: usb_ep1_control
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

module usb_ep1_control #(
	parameter integer HIGH_SPEED = 1,
	parameter PACKET_MODE = 1,
	parameter [31:0]CONFIG_CHAN = 0
)
(
	input wire clk,
	input wire rst,
	/* Control Xfer */
	input wire [3:0]ctl_xfer_endpoint,
	input wire [7:0]ctl_xfer_type,
	input wire [7:0]ctl_xfer_request,
	input wire [15:0]ctl_xfer_value,
	input wire [15:0]ctl_xfer_index,
	input wire [15:0]ctl_xfer_length,
	output wire ctl_xfer_accept,
	input wire ctl_xfer,
	output wire ctl_xfer_done,
	input wire [7:0]ctl_xfer_data_out,
	input wire ctl_xfer_data_out_valid,
	output wire [7:0]ctl_xfer_data_in,
	output wire ctl_xfer_data_in_valid,
	output wire ctl_xfer_data_in_last,
	input wire ctl_xfer_data_in_ready,
	/* Bulk IN Flow Control */
	input wire tlp_blk_in_xfer,
	output wire tlp_blk_xfer_in_has_data,
	output wire [7:0]tlp_blk_xfer_in_data,
	output wire tlp_blk_xfer_in_data_valid,
	input wire tlp_blk_xfer_in_data_ready,
	output wire tlp_blk_xfer_in_data_last,
	output wire ep_blk_in_xfer,
	input wire ep_blk_xfer_in_has_data,
	input wire [7:0]ep_blk_xfer_in_data,
	input wire ep_blk_xfer_in_data_valid,
	output wire ep_blk_xfer_in_data_ready,
	input wire ep_blk_xfer_in_data_last,
	/* Bulk OUT Flow Control */	
	input wire tlp_blk_out_xfer,
	output wire tlp_blk_xfer_out_ready_read,
	input wire [7:0]tlp_blk_xfer_out_data,
	input wire tlp_blk_xfer_out_data_valid,
	output wire ep_blk_out_xfer,
	input wire ep_blk_xfer_out_ready_read,
	output wire [7:0]ep_blk_xfer_out_data,
	output wire ep_blk_xfer_out_data_valid,
	input wire ep_blk_xfer_out_data_ready,
	output wire ep_blk_xfer_out_data_last
);

localparam [2:0]
	STATE_IDLE = 0,
	STATE_CFG_GET = 1,
	STATE_REG_READ = 2,
	STATE_REG_WRITE = 3,
	STATE_WAIT = 4;
	
localparam [7:0]
	REQUEST_CFG_GET = 0,
	REQUEST_REG_OPER = 1;

localparam [15:0]
	REGADDR_TSR = 0,
	REGADDR_TLR = 1,
	REGADDR_RSR = 2;

localparam [47:0]CONFIG = {14'h0000, (PACKET_MODE == 1) ? 1'b1 : 1'b0, (HIGH_SPEED == 1) ? 1'b1 : 1'b0, CONFIG_CHAN};
	
reg [2:0]state;

reg xfer_accept;
reg xfer_done;
reg [7:0]xfer_data;
reg xfer_data_valid;
reg xfer_data_last;
reg [15:0]reg_addr;
reg [7:0]request;
reg [15:0]length;

reg [15:0]reg_tsr;
reg [15:0]reg_tlr;
reg [15:0]reg_rsr;

reg [7:0]reg_data_out;
integer byte_index;

/* Tx */
reg [15:0]tx_counter;
reg tx_last;

reg tsr_rdy;
reg tsr_lst;
reg tsr_flag_clr;

reg rsr_rdy;
reg rsr_lst;
reg rsr_flag_clr;

task XFER_ACCEPT;
	begin
		xfer_accept <= 1'b1;
		xfer_done <= 1'b0;
	end
endtask

task XFER_REJECT;
	begin
		xfer_accept <= 1'b0;
		xfer_done <= 1'b1;
	end
endtask

task XFER_FINISH;
	begin
		xfer_accept <= 1'b1;
		xfer_done <= 1'b1;
	end
endtask

assign ctl_xfer_accept = xfer_accept;
assign ctl_xfer_done = xfer_done;
assign ctl_xfer_data_in = (request == REQUEST_REG_OPER) ? reg_data_out : xfer_data;
assign ctl_xfer_data_in_valid = xfer_data_valid;
assign ctl_xfer_data_in_last = xfer_data_last;

assign tlp_blk_xfer_in_has_data = ep_blk_xfer_in_has_data;
assign tlp_blk_xfer_in_data = ep_blk_xfer_in_data;
assign tlp_blk_xfer_in_data_valid = ep_blk_xfer_in_data_valid;
assign tlp_blk_xfer_in_data_last = ep_blk_xfer_in_data_last;
assign ep_blk_in_xfer = tlp_blk_in_xfer;
assign ep_blk_xfer_in_data_ready = tlp_blk_xfer_in_data_ready;

assign tlp_blk_xfer_out_ready_read = ep_blk_xfer_out_ready_read;
assign ep_blk_out_xfer = tlp_blk_out_xfer;
assign ep_blk_xfer_out_data = tlp_blk_xfer_out_data;
assign ep_blk_xfer_out_data_valid = tlp_blk_xfer_out_data_valid;
assign ep_blk_xfer_out_data_last = tx_last;

always @(posedge clk) begin
	if (rst == 1'b1) begin
		state <= STATE_IDLE;
		xfer_accept <= 1'b0;
		xfer_done <= 1'b0;
		xfer_data <= 0;
		xfer_data_valid <= 1'b0;
		xfer_data_last <= 1'b0;
		reg_addr <= 0;
		byte_index <= 0;
	end else begin
		case (state)
		STATE_IDLE: begin
			if (ctl_xfer == 1'b1) begin
				xfer_data_valid <= 1'b0;
				xfer_data_last <= 1'b0;
				request <= ctl_xfer_request;
				byte_index <= 0;
				length <= ctl_xfer_length;
				case (ctl_xfer_request)
				REQUEST_CFG_GET: begin
					if (ctl_xfer_type[7] == 1'b1) begin
						state = STATE_CFG_GET;
					end else begin
						state = STATE_WAIT;
					end
					XFER_ACCEPT();
				end
				REQUEST_REG_OPER: begin
					reg_addr <= ctl_xfer_value;
					if (ctl_xfer_type[7] == 1'b1) begin
						state = STATE_REG_READ;
					end else begin
						state = STATE_REG_WRITE;
					end
					XFER_ACCEPT();
				end
				default: begin
					XFER_REJECT();
				end			
				endcase
			end else begin
				XFER_REJECT();
			end
		end
		STATE_CFG_GET: begin
			if (xfer_data_valid == 1'b0) begin
				xfer_data <= CONFIG[(byte_index + 1)*8-1-:8];
				xfer_data_valid <= 1'b1;
				xfer_data_last <= 1'b0;
			end else begin
				if (ctl_xfer_data_in_ready == 1'b1) begin
					if (byte_index == 4) begin
						xfer_data <= CONFIG[(byte_index + 2)*8-1-:8];
						xfer_data_last <= 1'b1;
					end else if (byte_index == 5) begin
						xfer_data_valid <= 1'b0;
						state = STATE_WAIT;
					end else begin
						xfer_data <= CONFIG[(byte_index + 2)*8-1-:8];
					end
					byte_index <= byte_index + 1;
				end
			end
		end
		STATE_REG_READ: begin
			if (xfer_data_valid == 1'b0) begin
				xfer_data_valid <= 1'b1;
				xfer_data_last <= 1'b0;
			end else begin
				if (ctl_xfer_data_in_ready == 1'b1) begin
					if (byte_index == 1) begin
						xfer_data_valid <= 1'b0;
						xfer_data_last <= 1'b0;
						state = STATE_WAIT;
					end else begin
						xfer_data_valid <= 1'b1;
						xfer_data_last <= 1'b1;
						byte_index <= byte_index + 1;
					end
				end
			end
		end
		STATE_REG_WRITE: begin
			if (ctl_xfer_data_out_valid == 1'b1) begin
				if (byte_index == 1) begin
					state <= STATE_WAIT;
				end else begin
					byte_index <= byte_index + 1;
				end
			end
		end
		STATE_WAIT: begin
			XFER_FINISH();
			if (ctl_xfer == 1'b0) begin
				state <= STATE_IDLE;
			end
		end
		default: begin
			state <= STATE_WAIT;
		end
		endcase
	end
end

/* Read Reg */
always @(*) begin
	if (state == STATE_REG_READ) begin
		case (reg_addr)
		REGADDR_TSR: reg_data_out <= reg_tsr[(byte_index+1)*8-1-:8];
		REGADDR_TLR: reg_data_out <= reg_tlr[(byte_index+1)*8-1-:8];
		REGADDR_RSR: reg_data_out <= reg_rsr[(byte_index+1)*8-1-:8];
		default: reg_data_out <= 0;
		endcase
	end else begin
		reg_data_out <= 0;
	end
end

/* Write Reg */
always @(posedge clk) begin
	if (rst == 1'b1) begin
		reg_tsr <= 0;
		reg_tlr <= 0;
		reg_rsr <= 0;
	end else begin
		if (state == STATE_REG_WRITE) begin
			if (ctl_xfer_data_out_valid == 1'b1) begin
				case (reg_addr)
				REGADDR_TSR: reg_tsr[(byte_index+1)*8-1-:8] <= ctl_xfer_data_out;
				REGADDR_TLR: reg_tlr[(byte_index+1)*8-1-:8] <= ctl_xfer_data_out;
				REGADDR_RSR: reg_rsr[(byte_index+1)*8-1-:8] <= ctl_xfer_data_out;
				default: begin
					reg_tsr <= {14'h0000,tsr_lst,tsr_rdy};
					reg_tlr <= reg_tlr;
					reg_rsr <= {14'h0000,rsr_lst,rsr_rdy};
				end
				endcase
			end
		end else begin
			reg_tsr <= {14'h0000,tsr_lst,tsr_rdy};
			reg_tlr <= reg_tlr;
			reg_rsr <= {14'h0000,rsr_lst,rsr_rdy};
		end
	end
end

/* TSR & RSR Clear */
always @(*) begin
	if (state == STATE_REG_WRITE) begin
		if (ctl_xfer_data_out_valid == 1'b1) begin
			case (reg_addr)
			REGADDR_TSR: tsr_flag_clr <= 1'b1;
			REGADDR_RSR: rsr_flag_clr <= 1'b1;
			default: begin
				tsr_flag_clr <= 1'b0;
				rsr_flag_clr <= 1'b0;
			end
			endcase
		end else begin
			tsr_flag_clr <= 1'b0;
			rsr_flag_clr <= 1'b0;
		end
	end else begin
		tsr_flag_clr <= 1'b0;
		rsr_flag_clr <= 1'b0;
	end 
end

/* TSR & RSR Bits */
always @(posedge clk) begin
	if (rst == 1'b1) begin
		tsr_rdy <= 1'b0;
		tsr_lst <= 1'b0;
	end else begin
		if (tsr_flag_clr) begin
			tsr_rdy <= 1'b0;
			tsr_lst <= 1'b0;
		end else begin
			if ((ep_blk_xfer_out_ready_read == 1'b1) && (ep_blk_xfer_out_data_ready == 1'b1)) begin
				tsr_rdy <= 1'b1;
			end
			if ((ep_blk_xfer_out_data_valid == 1'b1) && (ep_blk_xfer_out_data_ready == 1'b1) && (ep_blk_xfer_out_data_last == 1'b1)) begin
				tsr_lst <= (PACKET_MODE == 1) ? 1'b1 : 1'b0;
			end
		end
	end
end

always @(posedge clk) begin
	if (rst == 1'b1) begin
		rsr_rdy <= 1'b0;
		rsr_lst <= 1'b0;
	end else begin
		if (rsr_flag_clr) begin
			rsr_rdy <= 1'b0;
			rsr_lst <= 1'b0;
		end else begin
			if ((ep_blk_xfer_in_has_data == 1'b1) && (ep_blk_xfer_in_data_valid == 1'b1)) begin
				rsr_rdy <= 1'b1;
			end
			if ((ep_blk_xfer_in_data_valid == 1'b1) && (ep_blk_xfer_in_data_ready == 1'b1) && (ep_blk_xfer_in_data_last == 1'b1)) begin
				rsr_lst <= (PACKET_MODE == 1) ? 1'b1 : 1'b0;
			end
		end
	end
end

/* Tx Counter & Last */
always @(posedge clk) begin
	if (rst == 1'b1) begin
		tx_counter <= 0;
	end else begin
		if (PACKET_MODE == 1) begin
			if ((ep_blk_xfer_out_data_valid == 1'b1) && (ep_blk_xfer_out_data_ready == 1'b1)) begin
				if (tx_counter == (reg_tlr - 1)) begin
					tx_counter <= 0;
				end else begin
					tx_counter <= tx_counter + 1;
				end
			end
		end else begin
			tx_counter <= 0;
		end
	end
end

always @(*) begin
	if (PACKET_MODE == 1) begin
		tx_last <= (tx_counter == (reg_tlr - 1));
	end else begin
		tx_last <= 1'b0;
	end
end

endmodule
