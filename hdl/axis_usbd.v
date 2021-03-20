`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: Dmitry Matyunin (https://github.com/mcjtag)
// 
// Create Date: 20.03.2021 15:10:41
// Design Name: 
// Module Name: axis_usbd
// Project Name:  axis_usbd
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

module axis_usbd #(
	parameter FPGA_VENDOR = "xilinx",
	parameter FPGA_FAMILY = "7series",
	parameter integer HIGH_SPEED = 1,	/* 0 - Full-Speed, 1 - High-Speed */
	parameter [63:0]SERIAL = "AUBR0000",/* Serial NUmber */
	parameter CHANNEL_IN_ENABLE = 1,	/* 0 - Disable, 1 - Enable */
	parameter CHANNEL_OUT_ENABLE = 1,	/* 0 - Disable, 1 - Enable */
	parameter PACKET_MODE = 0,			/* 0 - Stream Mode, 1 - Packet Mode */
	parameter DATA_IN_WIDTH = 8,		/* 8, 16 or 32 */
	parameter DATA_OUT_WIDTH = 8,		/* 8, 16 or 32 */
	parameter DATA_IN_ENDIAN = 0,		/* 0 - Little Endian (LE), 1 - Big Endian (BE) */
	parameter DATA_OUT_ENDIAN = 0,		/* 0 - Little Endian (LE), 1 - Big Endian (BE) */
	parameter FIFO_IN_ENABLE = 1,		/* 0 - Disable, 1 - Enable */
	parameter FIFO_IN_PACKET = 0,		/* 0 - Stream, 1 - Packet */
	parameter FIFO_IN_DEPTH = 1024,		/* Depth: 16 to 4194304 */
	parameter FIFO_OUT_ENABLE = 1,		/* 0 - Disable, 1 - Enable */
	parameter FIFO_OUT_PACKET = 0,		/* 0 - Stream, 1 - Packet */
	parameter FIFO_OUT_DEPTH = 1024		/* Depth: 16 to 4194304 */
)
(
	/* UTMI Low Pin Interface Ports */
	input wire [7:0]ulpi_data_i,
	output wire [7:0]ulpi_data_o,
	output wire ulpi_data_t,
	input wire ulpi_dir,
	input wire ulpi_nxt,
	output wire ulpi_stp,
	output wire ulpi_reset,
	input wire ulpi_clk,
	/* AXI4-Stream Interface */
	input wire aclk,
	input wire aresetn,
	input wire s_axis_tvalid,
	output wire s_axis_tready,
	input wire s_axis_tlast,
	input wire [DATA_IN_WIDTH-1:0]s_axis_tdata,
	output wire m_axis_tvalid,
	input wire m_axis_tready,
	output wire [DATA_OUT_WIDTH-1:0]m_axis_tdata,
	output wire m_axis_tlast
);

function [15:0]config_channel;
	input integer enable;
	input integer width;
	input integer endian;
	input integer fifo_enable;
	input integer fifo_packet;
	input integer fifo_depth;
	reg [4:0]log_value;
	begin
	
	config_channel = 16'h0000;
	
	case (enable)
	0: config_channel[0] = 1'b0;
	1: config_channel[0] = 1'b1;
	default: config_channel[0] = 1'b0;
	endcase
	
	case (width)
	8:  config_channel[2:1] = 2'b01;
	16: config_channel[2:1] = 2'b10;
	32: config_channel[2:1] = 2'b11;
	default: config_channel[2:1] = 2'b00; 
	endcase
	
	case (endian)
	0: config_channel[3] = 1'b0;
	1: config_channel[3] = 1'b1;
	default: config_channel[3] = 1'b0;
	endcase
	
	case (fifo_enable)
	0: config_channel[4] = 1'b0;
	1: config_channel[4] = 1'b1;
	default: config_channel[4] = 1'b0;
	endcase
	
	case (fifo_packet)
	0: config_channel[5] = 1'b0;
	1: config_channel[5] = 1'b1;
	default: config_channel[5] = 1'b0;
	endcase
	
	log_value = $clog2(fifo_depth);
	config_channel[10:6] = log_value;
	
	end
endfunction

localparam DATA_WIDTH = 8;
localparam [15:0]CONFIG_CHAN_IN = config_channel(CHANNEL_IN_ENABLE, DATA_IN_WIDTH, DATA_IN_ENDIAN, FIFO_IN_ENABLE, FIFO_IN_PACKET, FIFO_IN_DEPTH);
localparam [15:0]CONFIG_CHAN_OUT = config_channel(CHANNEL_OUT_ENABLE, DATA_OUT_WIDTH, DATA_OUT_ENDIAN, FIFO_OUT_ENABLE, FIFO_OUT_PACKET, FIFO_OUT_DEPTH);

assign ulpi_data_t = ulpi_dir;

wire m_fifo_tvalid;
wire m_fifo_tready;
wire [DATA_IN_WIDTH-1:0]m_fifo_tdata;
wire m_fifo_tlast;

wire s_fifo_tvalid;
wire s_fifo_tready;
wire [DATA_OUT_WIDTH-1:0]s_fifo_tdata;
wire s_fifo_tlast;

wire m_awc_tvalid;
wire m_awc_tready;
wire [7:0]m_awc_tdata;
wire m_awc_tlast;

wire s_awc_tvalid;
wire s_awc_tready;
wire [7:0]s_awc_tdata;
wire s_awc_tlast;

generate if (CHANNEL_IN_ENABLE) begin : CHANNEL_IN
	if (FIFO_IN_ENABLE) begin : FIFO
		usb_blk_fifo #(
			.FPGA_VENDOR(FPGA_VENDOR),
			.FPGA_FAMILY(FPGA_FAMILY),
			.CLOCK_MODE("SYNC"),
			.FIFO_PACKET(PACKET_MODE & FIFO_IN_PACKET),
			.FIFO_DEPTH(FIFO_IN_DEPTH),
			.DATA_WIDTH(DATA_IN_WIDTH),
			.PROG_FULL_THRESHOLD(0)
		) usb_blk_fifo_inst (
			.s_aclk(aclk),
			.s_aresetn(aresetn),
			.s_axis_tvalid(s_axis_tvalid),
			.s_axis_tready(s_axis_tready),
			.s_axis_tdata(s_axis_tdata),
			.s_axis_tlast(s_axis_tlast),
			.m_aclk(aclk),
			.m_axis_tvalid(m_fifo_tvalid),
			.m_axis_tready(m_fifo_tready),
			.m_axis_tdata(m_fifo_tdata),
			.m_axis_tlast(m_fifo_tlast),
			.axis_prog_full()
		);
	end else begin
		assign m_fifo_tvalid = s_axis_tvalid;
		assign s_axis_tready = m_fifo_tready;
		assign m_fifo_tdata = s_axis_tdata;
		assign m_fifo_tlast = s_axis_tlast;
	end
	
	axis_width_converter #(
		.FPGA_VENDOR(FPGA_VENDOR),
		.FPGA_FAMILY(FPGA_FAMILY),
		.BIG_ENDIAN(DATA_IN_ENDIAN),
		.WIDTH_IN(DATA_IN_WIDTH),
		.WIDTH_OUT(DATA_WIDTH)
	) axis_width_converter_inst (
		.s_axis_aclk(aclk),
		.s_axis_aresetn(aresetn),
		.s_axis_tdata(m_fifo_tdata),
		.s_axis_tvalid(m_fifo_tvalid),
		.s_axis_tready(m_fifo_tready),
		.s_axis_tlast(m_fifo_tlast),
		.m_axis_aclk(aclk),
		.m_axis_tdata(m_awc_tdata),
		.m_axis_tvalid(m_awc_tvalid),
		.m_axis_tready(m_awc_tready),
		.m_axis_tlast(m_awc_tlast)
	);
end else begin
	assign m_awc_tvalid = 1'b0;
	assign s_axis_tready = 1'b0;
	assign m_awc_tdata = 0;
	assign m_awc_tlast = 1'b0;
end endgenerate

generate if (CHANNEL_OUT_ENABLE) begin : CHANNEL_OUT
	if (FIFO_OUT_ENABLE) begin : FIFO
		usb_blk_fifo #(
			.FPGA_VENDOR(FPGA_VENDOR),
			.FPGA_FAMILY(FPGA_FAMILY),
			.CLOCK_MODE("SYNC"),
			.FIFO_PACKET(PACKET_MODE & FIFO_OUT_PACKET),
			.FIFO_DEPTH(FIFO_OUT_DEPTH),
			.DATA_WIDTH(DATA_OUT_WIDTH),
			.PROG_FULL_THRESHOLD(0)
		) usb_blk_fifo_inst (
			.s_aclk(aclk),
			.s_aresetn(aresetn),
			.s_axis_tvalid(s_fifo_tvalid),
			.s_axis_tready(s_fifo_tready),
			.s_axis_tdata(s_fifo_tdata),
			.s_axis_tlast(s_fifo_tlast),
			.m_aclk(aclk),
			.m_axis_tvalid(m_axis_tvalid),
			.m_axis_tready(m_axis_tready),
			.m_axis_tdata(m_axis_tdata),
			.m_axis_tlast(m_axis_tlast),
			.axis_prog_full()
		);
	end else begin
		assign  m_axis_tvalid = s_fifo_tvalid;
		assign s_fifo_tready = m_axis_tready;
		assign m_axis_tdata = s_fifo_tdata;
		assign m_axis_tlast = s_fifo_tlast;
	end

	axis_width_converter #(
		.FPGA_VENDOR(FPGA_VENDOR),
		.FPGA_FAMILY(FPGA_FAMILY),
		.BIG_ENDIAN(DATA_OUT_ENDIAN),
		.WIDTH_IN(DATA_WIDTH),
		.WIDTH_OUT(DATA_OUT_WIDTH)
	) axis_width_converter_inst (
		.s_axis_aclk(aclk),
		.s_axis_aresetn(aresetn),
		.s_axis_tdata(s_awc_tdata),
		.s_axis_tvalid(s_awc_tvalid),
		.s_axis_tready(s_awc_tready),
		.s_axis_tlast(s_awc_tlast),
		.m_axis_aclk(aclk),
		.m_axis_tdata(s_fifo_tdata),
		.m_axis_tvalid(s_fifo_tvalid),
		.m_axis_tready(s_fifo_tready),
		.m_axis_tlast(s_fifo_tlast)
	);
end else begin
	assign m_axis_tvalid = 1'b0;
	assign s_awc_tready = 1'b0;
	assign m_axis_tdata = 0;
	assign m_axis_tlast = 1'b0;
end endgenerate

usb_ep1_bridge #(
	.FPGA_VENDOR(FPGA_VENDOR),
	.FPGA_FAMILY(FPGA_FAMILY),
	.HIGH_SPEED(HIGH_SPEED),
	.PACKET_MODE(PACKET_MODE),
	.CONFIG_CHAN({CONFIG_CHAN_OUT,CONFIG_CHAN_IN}),
	.SERIAL(SERIAL)
) usb_ep1_bridge_inst (
	.sys_clk(aclk),
	.ulpi_data_in(ulpi_data_i),
	.ulpi_data_out(ulpi_data_o),
	.ulpi_dir(ulpi_dir),
	.ulpi_nxt(ulpi_nxt),
	.ulpi_stp(ulpi_stp),
	.ulpi_reset(ulpi_reset),
	.ulpi_clk(ulpi_clk),
	.s_axis_tvalid(m_awc_tvalid),
	.s_axis_tready(m_awc_tready),
	.s_axis_tdata(m_awc_tdata),
	.s_axis_tlast(m_awc_tlast),
	.m_axis_tvalid(s_awc_tvalid),
	.m_axis_tready(s_awc_tready),
	.m_axis_tdata(s_awc_tdata),
	.m_axis_tlast(s_awc_tlast)
);

endmodule
