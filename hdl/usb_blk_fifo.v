`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: Dmitry Matyunin (https://github.com/mcjtag)
// 
// Create Date: 20.03.2021 09:43:49
// Design Name: 
// Module Name: usb_blk_fifo
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

module usb_blk_fifo #(
	parameter FPGA_VENDOR = "xilinx",
	parameter FPGA_FAMILY = "7series",
	parameter CLOCK_MODE = "ASYNC",
	parameter FIFO_PACKET = 0,
	parameter FIFO_DEPTH = 1024,
	parameter DATA_WIDTH = 8,
	parameter PROG_FULL_THRESHOLD = 64
)
(
	input wire s_aclk,
	input wire s_aresetn,
	input wire s_axis_tvalid,
	output wire s_axis_tready,
	input wire [7:0]s_axis_tdata,
	input wire s_axis_tlast,
	input wire m_aclk,
	output wire m_axis_tvalid,
	input wire m_axis_tready,
	output wire [7:0]m_axis_tdata,
	output wire m_axis_tlast,
	output wire axis_prog_full
);

arch_fifo_axis #(
	.FPGA_VENDOR(FPGA_VENDOR),
	.FPGA_FAMILY(FPGA_FAMILY),
	.CLOCK_MODE(CLOCK_MODE),
	.FIFO_PACKET(FIFO_PACKET),
	.FIFO_DEPTH(FIFO_DEPTH),
	.DATA_WIDTH(DATA_WIDTH),
	.PROG_FULL_THRESHOLD(PROG_FULL_THRESHOLD)
) arch_fifo_axis_inst (
	.s_aclk(s_aclk),
	.s_aresetn(s_aresetn),
	.s_axis_tvalid(s_axis_tvalid),
	.s_axis_tready(s_axis_tready),
	.s_axis_tdata(s_axis_tdata),
	.s_axis_tlast(s_axis_tlast),
	.m_aclk(m_aclk),
	.m_axis_tvalid(m_axis_tvalid),
	.m_axis_tready(m_axis_tready),
	.m_axis_tdata(m_axis_tdata),
	.m_axis_tlast(m_axis_tlast),
	.axis_prog_full(axis_prog_full)
);

endmodule
