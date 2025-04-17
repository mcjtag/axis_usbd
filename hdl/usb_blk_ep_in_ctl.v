`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: Dmitry Matyunin (https://github.com/mcjtag)
// 
// Create Date: 20.03.2021 17:36:30
// Design Name: 
// Module Name: usb_blk_ep_in_ctl
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

module usb_blk_ep_in_ctl #(
	parameter FPGA_VENDOR = "xilinx",
	parameter FPGA_FAMILY = "7series"
)
(
	input wire rst,
	input wire usb_clk,
	input wire axis_clk,
	input wire blk_in_xfer,
	output wire blk_xfer_in_has_data,
	output wire [7:0]blk_xfer_in_data,
	output wire blk_xfer_in_data_valid,
	input wire blk_xfer_in_data_ready,
	output wire blk_xfer_in_data_last,
	input wire [7:0]axis_tdata,
	input wire axis_tvalid,
	output wire axis_tready,
	input wire axis_tlast
);

localparam [0:0]
	STATE_IDLE = 0,
	STATE_XFER = 1;

reg [0:0]state;
wire s_axis_tvalid;
wire s_axis_tready;
wire [7:0]s_axis_tdata;
wire s_axis_tlast;
wire m_axis_tvalid;
wire m_axis_tready;
wire [7:0]m_axis_tdata;
wire m_axis_tlast;
wire prog_full;
wire was_last_usb;
wire prog_full_usb;
reg was_last;
reg blk_xfer_in_has_data_out;
wire axis_rst;

assign blk_xfer_in_has_data = blk_xfer_in_has_data_out;

assign s_axis_tdata = axis_tdata;
assign s_axis_tvalid = axis_tvalid;
assign axis_tready = s_axis_tready;
assign s_axis_tlast = axis_tlast;

assign blk_xfer_in_data = m_axis_tdata;
assign blk_xfer_in_data_valid = m_axis_tvalid;
assign m_axis_tready = blk_xfer_in_data_ready;
assign blk_xfer_in_data_last = m_axis_tlast;

always @(posedge usb_clk) begin
	if (rst == 1'b1) begin
		state <= STATE_IDLE;
		blk_xfer_in_has_data_out <= 1'b0;
	end else begin
		case (state)
		STATE_IDLE: begin
			if ((was_last_usb == 1'b1) || ((prog_full_usb == 1'b1) && (m_axis_tvalid == 1'b1))) begin
				blk_xfer_in_has_data_out <= 1'b1;
			end
			if (blk_in_xfer == 1'b1) begin
				state <= STATE_XFER;
			end
		end
		STATE_XFER: begin
			if (blk_in_xfer == 1'b0) begin
				blk_xfer_in_has_data_out <= 1'b0;
				state <= STATE_IDLE;
			end
		end
		endcase
	end
end

always @(posedge axis_clk) begin
	if (axis_rst == 1'b1) begin
		was_last <= 1'b0;
	end else begin
		if ((s_axis_tvalid == 1'b1) && (s_axis_tready == 1'b1) && (s_axis_tlast == 1'b1)) begin
			was_last <= 1'b1;
		end else if ((s_axis_tvalid == 1'b1) && (s_axis_tready == 1'b1) && (s_axis_tlast == 1'b0)) begin
			was_last <= 1'b0;
		end
	end
end

usb_blk_fifo #(
	.FPGA_VENDOR(FPGA_VENDOR),
	.FPGA_FAMILY(FPGA_FAMILY),
	.CLOCK_MODE("ASYNC"),
	.FIFO_PACKET(0),
	.FIFO_DEPTH(1024),
	.DATA_WIDTH(8),
	.PROG_FULL_THRESHOLD(512)
) usb_blk_in_fifo (
	.m_aclk(usb_clk),
	.s_aclk(axis_clk),
	.s_aresetn(~axis_rst),
	.s_axis_tvalid(s_axis_tvalid),
	.s_axis_tready(s_axis_tready),
	.s_axis_tdata(s_axis_tdata),
	.s_axis_tlast(s_axis_tlast),
	.m_axis_tvalid(m_axis_tvalid),
	.m_axis_tready(m_axis_tready),
	.m_axis_tdata(m_axis_tdata),
	.m_axis_tlast(m_axis_tlast),
	.axis_prog_full(prog_full)
);

arch_cdc_array #(
	.FPGA_VENDOR(FPGA_VENDOR),
	.FPGA_FAMILY(FPGA_FAMILY),
	.WIDTH(2)
) arch_cdc_array_inst (
	.src_clk(axis_clk),
	.src_data({prog_full,was_last}),
	.dst_clk(usb_clk),
	.dst_data({prog_full_usb,was_last_usb})
);

arch_cdc_reset #(
	.FPGA_VENDOR(FPGA_VENDOR),
	.FPGA_FAMILY(FPGA_FAMILY)
) arch_cdc_reset_inst (
	.src_rst(rst),
	.dst_clk(axis_clk),
	.dst_rst(axis_rst)
);

endmodule
