`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: Dmitry Matyunin (https://github.com/mcjtag)
// 
// Create Date: 20.03.2021 10:41:24
// Design Name: 
// Module Name: usb_blk_ep_out_ctl
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

module usb_blk_ep_out_ctl #(
	parameter FPGA_VENDOR = "xilinx",
	parameter FPGA_FAMILY = "7series"
)
(
	input wire rst,
	input wire usb_clk,
	input wire axis_clk,
	input wire blk_out_xfer,
	output wire blk_xfer_out_ready_read,
	input wire [7:0]blk_xfer_out_data,
	output wire blk_xfer_out_data_ready,
	input wire blk_xfer_out_data_valid,
	input wire blk_xfer_out_data_last,
	output wire [7:0]axis_tdata,
	output wire axis_tvalid,
	input wire axis_tready,
	output wire axis_tlast
);

wire s_axis_tvalid;
wire s_axis_tready;
wire [7:0]s_axis_tdata;
wire prog_full;
reg blk_xfer_out_ready_read_out;

assign blk_xfer_out_ready_read = blk_xfer_out_ready_read_out;

/* Full Latch */
always @(posedge usb_clk) begin
	blk_xfer_out_ready_read_out <= ~prog_full;
end

usb_blk_fifo #(
	.FPGA_VENDOR(FPGA_VENDOR),
	.FPGA_FAMILY(FPGA_FAMILY),
	.CLOCK_MODE("ASYNC"),
	.FIFO_PACKET(0),
	.FIFO_DEPTH(1024),
	.DATA_WIDTH(8),
	.PROG_FULL_THRESHOLD(960)
) usb_blk_out_fifo (
	.m_aclk(axis_clk),
	.s_aclk(usb_clk),
	.s_aresetn(~rst),
	.s_axis_tvalid(blk_xfer_out_data_valid),
	.s_axis_tready(blk_xfer_out_data_ready),
	.s_axis_tdata(blk_xfer_out_data),
	.s_axis_tlast(blk_xfer_out_data_last),
	.m_axis_tvalid(axis_tvalid),
    .m_axis_tready(axis_tready),
    .m_axis_tdata(axis_tdata),
    .m_axis_tlast(axis_tlast),
    .axis_prog_full(prog_full)
);

endmodule
