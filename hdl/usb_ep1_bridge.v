`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: Dmitry Matyunin (https://github.com/mcjtag)
// 
// Create Date: 20.03.2021 16:16:06
// Design Name: 
// Module Name: usb_ep1_bridge
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

module usb_ep1_bridge #(
	parameter FPGA_VENDOR = "xilinx",
	parameter FPGA_FAMILY = "7series",
	parameter integer HIGH_SPEED = 1,
	parameter PACKET_MODE = 1,
	parameter [31:0]CONFIG_CHAN = 0,
	parameter [63:0]SERIAL = "AUBR0000"
)
(
	input wire sys_clk,
	/* ULPI */
	input wire [7:0]ulpi_data_in,
	output wire [7:0]ulpi_data_out,
	input wire ulpi_dir,
	input wire ulpi_nxt,
	output wire ulpi_stp,
	output wire ulpi_reset,
	input wire ulpi_clk,
	/* AXIS */
	input wire s_axis_tvalid,
	output wire s_axis_tready,
	input wire [7:0]s_axis_tdata,
	input wire s_axis_tlast,
	output wire m_axis_tvalid,
	input wire m_axis_tready,
	output wire [7:0]m_axis_tdata,
	output wire m_axis_tlast
);

localparam CONFIG_DESC_LEN = 9;
localparam INTERFACE_DESC_LEN = 9;
localparam EP1_IN_DESC_LEN = 7;
localparam EP1_OUT_DESC_LEN = 7;

localparam CONFIG_DESC = {
	8'h32,			// bMaxPower = 100 mA
	8'hC0,			// bmAttributes = Self-powered
	8'h00,			// iConfiguration
	8'h01,			// bConfigurationValue
	8'h01,			// bNumInterfaces = 1
	16'h0020,		// wTotalLength = 32
	8'h02,			// bDescriptionType = Configuration Descriptor
	8'h09			// bLength = 9
};

localparam INTERFACE_DESC = {
	8'h00,			// iInterface
	8'h00,			// bInterfaceProtocol
	8'h00,			// bInterfaceSubClass
	8'h00,			// bInterfaceClass
	8'h02,			// bNumEndpoints = 2
	8'h00,			// bAlternateSetting
	8'h00,			// bInterfaceNumber = 0
	8'h04,			// bDescriptorType = Interface Descriptor
	8'h09			// bLength = 9
};

localparam EP1_IN_DESC = {
	8'h00,			// bInterval
	16'h0200,		// wMaxPacketSize = 512 bytes
	8'h02,			// bmAttributes = Bulk
	8'h81,			// bEndpointAddress = IN1
	8'h05,			// bDescriptorType = Endpoint Descriptor
	8'h07			// bLength = 7
};

localparam EP1_OUT_DESC = {
	8'h00,			// bInterval
	16'h0200,		// wMaxPacketSize = 512 bytes
	8'h02,			// bmAttributes = Bulk
	8'h01,			// bEndpointAddress = OUT1
	8'h05,			// bDescriptorType = Endpoint Descriptor
	8'h07			// bLength = 7
};

wire usb_clk;
wire usb_reset;

wire usb_idle;
wire usb_suspend;
wire usb_configured;
wire usb_crc_error;
wire usb_sof;
  
wire [3:0]ctl_xfer_endpoint;
wire [7:0]ctl_xfer_type;
wire [7:0]ctl_xfer_request;
wire [15:0]ctl_xfer_value;
wire [15:0]ctl_xfer_index;
wire [15:0]ctl_xfer_length;
wire ctl_xfer_accept;
wire ctl_xfer;
wire ctl_xfer_done;

wire [7:0]ctl_xfer_data_out;
wire ctl_xfer_data_out_valid;

wire [7:0]ctl_xfer_data_in;
wire ctl_xfer_data_in_valid;
wire ctl_xfer_data_in_last;
wire ctl_xfer_data_in_ready;

wire [3:0]blk_xfer_endpoint;

wire tlp_blk_in_xfer;
wire tlp_blk_out_xfer;
wire tlp_blk_xfer_in_has_data;
wire [7:0]tlp_blk_xfer_in_data;
wire tlp_blk_xfer_in_data_valid;
wire tlp_blk_xfer_in_data_ready;
wire tlp_blk_xfer_in_data_last;
wire tlp_blk_xfer_out_ready_read;
wire [7:0]tlp_blk_xfer_out_data;
wire tlp_blk_xfer_out_data_valid;

wire ep_blk_in_xfer;
wire ep_blk_xfer_in_has_data;
wire [7:0]ep_blk_xfer_in_data;
wire ep_blk_xfer_in_data_valid;
wire ep_blk_xfer_in_data_ready;
wire ep_blk_xfer_in_data_last;
wire ep_blk_out_xfer;
wire ep_blk_xfer_out_ready_read;
wire [7:0]ep_blk_xfer_out_data;
wire ep_blk_xfer_out_data_ready;
wire ep_blk_xfer_out_data_valid;
wire ep_blk_xfer_out_data_last;

wire [7:0]ep1_in_axis_tdata;
wire ep1_in_axis_tvalid;
wire ep1_in_axis_tready;
wire ep1_in_axis_tlast;

wire [7:0]ep1_out_axis_tdata;
wire ep1_out_axis_tvalid;
wire ep1_out_axis_tready;
wire ep1_out_axis_tlast;

assign ep1_in_axis_tdata = s_axis_tdata;
assign ep1_in_axis_tvalid = s_axis_tvalid;
assign s_axis_tready = ep1_in_axis_tready;
assign ep1_in_axis_tlast = s_axis_tlast;

assign m_axis_tvalid = ep1_out_axis_tvalid;
assign ep1_out_axis_tready = m_axis_tready;
assign m_axis_tdata = ep1_out_axis_tdata;
assign m_axis_tlast = ep1_out_axis_tlast;

usb_tlp #(
	.VENDOR_ID(16'hFACE),
	.PRODUCT_ID(16'h0BDE),
	.MANUFACTURER_LEN(7),
	.MANUFACTURER("mc.jtag"),
	.PRODUCT_LEN(15),
	.PRODUCT("AXIS USB Bridge"),
	.SERIAL_LEN(8),
	.SERIAL(SERIAL),
	.CONFIG_DESC_LEN(CONFIG_DESC_LEN + INTERFACE_DESC_LEN + EP1_IN_DESC_LEN + EP1_OUT_DESC_LEN),
	.CONFIG_DESC({EP1_OUT_DESC,EP1_IN_DESC,INTERFACE_DESC,CONFIG_DESC}),
	.HIGH_SPEED(HIGH_SPEED)
) usb_tlp_inst (
	.ulpi_data_in(ulpi_data_in),
	.ulpi_data_out(ulpi_data_out),
	.ulpi_dir(ulpi_dir),
	.ulpi_nxt(ulpi_nxt),
	.ulpi_stp(ulpi_stp),
	.ulpi_reset(ulpi_reset),
	.ulpi_clk60(ulpi_clk),
	.usb_clk(usb_clk),
	.usb_reset(usb_reset),
	.usb_idle(usb_idle),
	.usb_suspend(usb_suspend),
	.usb_configured(usb_configured),
	.usb_crc_error(usb_crc_error),
	.usb_sof(usb_sof),
	.ctl_xfer_endpoint(ctl_xfer_endpoint),
	.ctl_xfer_type(ctl_xfer_type),
	.ctl_xfer_request(ctl_xfer_request),
	.ctl_xfer_value(ctl_xfer_value),
	.ctl_xfer_index(ctl_xfer_index),
	.ctl_xfer_length(ctl_xfer_length),
	.ctl_xfer_accept(ctl_xfer_accept),
	.ctl_xfer(ctl_xfer),
	.ctl_xfer_done(ctl_xfer_done),
	.ctl_xfer_data_out(ctl_xfer_data_out),
	.ctl_xfer_data_out_valid(ctl_xfer_data_out_valid),
	.ctl_xfer_data_in(ctl_xfer_data_in),
	.ctl_xfer_data_in_valid(ctl_xfer_data_in_valid),
	.ctl_xfer_data_in_last(ctl_xfer_data_in_last),
	.ctl_xfer_data_in_ready(ctl_xfer_data_in_ready),
	.blk_xfer_endpoint(blk_xfer_endpoint),
	.blk_in_xfer(tlp_blk_in_xfer),
	.blk_out_xfer(tlp_blk_out_xfer),
	.blk_xfer_in_has_data(tlp_blk_xfer_in_has_data),
	.blk_xfer_in_data(tlp_blk_xfer_in_data),
	.blk_xfer_in_data_valid(tlp_blk_xfer_in_data_valid),
	.blk_xfer_in_data_ready(tlp_blk_xfer_in_data_ready),
	.blk_xfer_in_data_last(tlp_blk_xfer_in_data_last),
	.blk_xfer_out_ready_read(tlp_blk_xfer_out_ready_read),
	.blk_xfer_out_data(tlp_blk_xfer_out_data),
	.blk_xfer_out_data_valid(tlp_blk_xfer_out_data_valid)
);

usb_ep1_control #(
	.HIGH_SPEED(HIGH_SPEED),
	.PACKET_MODE(PACKET_MODE),
	.CONFIG_CHAN(CONFIG_CHAN)
) usb_ep1_control_inst (
	.clk(usb_clk),
	.rst(usb_reset),
	.ctl_xfer_endpoint(ctl_xfer_endpoint),
	.ctl_xfer_type(ctl_xfer_type),
	.ctl_xfer_request(ctl_xfer_request),
	.ctl_xfer_value(ctl_xfer_value),
	.ctl_xfer_index(ctl_xfer_index),
	.ctl_xfer_length(ctl_xfer_length),
	.ctl_xfer_accept(ctl_xfer_accept),
	.ctl_xfer(ctl_xfer),
	.ctl_xfer_done(ctl_xfer_done),
	.ctl_xfer_data_out(ctl_xfer_data_out),
	.ctl_xfer_data_out_valid(ctl_xfer_data_out_valid),
	.ctl_xfer_data_in(ctl_xfer_data_in),
	.ctl_xfer_data_in_valid(ctl_xfer_data_in_valid),
	.ctl_xfer_data_in_last(ctl_xfer_data_in_last),
	.ctl_xfer_data_in_ready(ctl_xfer_data_in_ready),
	.tlp_blk_in_xfer(tlp_blk_in_xfer),
	.tlp_blk_xfer_in_has_data(tlp_blk_xfer_in_has_data),
	.tlp_blk_xfer_in_data(tlp_blk_xfer_in_data),
	.tlp_blk_xfer_in_data_valid(tlp_blk_xfer_in_data_valid),
	.tlp_blk_xfer_in_data_ready(tlp_blk_xfer_in_data_ready),
	.tlp_blk_xfer_in_data_last(tlp_blk_xfer_in_data_last),
	.ep_blk_in_xfer(ep_blk_in_xfer),
	.ep_blk_xfer_in_has_data(ep_blk_xfer_in_has_data),
	.ep_blk_xfer_in_data(ep_blk_xfer_in_data),
	.ep_blk_xfer_in_data_valid(ep_blk_xfer_in_data_valid),
	.ep_blk_xfer_in_data_ready(ep_blk_xfer_in_data_ready),
	.ep_blk_xfer_in_data_last(ep_blk_xfer_in_data_last),
	.tlp_blk_out_xfer(tlp_blk_out_xfer),
	.tlp_blk_xfer_out_ready_read(tlp_blk_xfer_out_ready_read),
	.tlp_blk_xfer_out_data(tlp_blk_xfer_out_data),
	.tlp_blk_xfer_out_data_valid(tlp_blk_xfer_out_data_valid),
	.ep_blk_out_xfer(ep_blk_out_xfer),
	.ep_blk_xfer_out_ready_read(ep_blk_xfer_out_ready_read),
	.ep_blk_xfer_out_data(ep_blk_xfer_out_data),
	.ep_blk_xfer_out_data_ready(ep_blk_xfer_out_data_ready),
	.ep_blk_xfer_out_data_valid(ep_blk_xfer_out_data_valid),
	.ep_blk_xfer_out_data_last(ep_blk_xfer_out_data_last)
);

usb_blk_ep_in_ctl #(
	.FPGA_VENDOR(FPGA_VENDOR),
	.FPGA_FAMILY(FPGA_FAMILY)
) usb_blk_ep_in_ctl_inst (
	.rst(usb_reset),
	.usb_clk(usb_clk),
	.axis_clk(sys_clk),
	.blk_in_xfer(ep_blk_in_xfer),
	.blk_xfer_in_has_data(ep_blk_xfer_in_has_data),
	.blk_xfer_in_data(ep_blk_xfer_in_data),
	.blk_xfer_in_data_valid(ep_blk_xfer_in_data_valid),
	.blk_xfer_in_data_ready(ep_blk_xfer_in_data_ready),
	.blk_xfer_in_data_last(ep_blk_xfer_in_data_last),
	.axis_tdata(ep1_in_axis_tdata),
	.axis_tvalid(ep1_in_axis_tvalid),
	.axis_tready(ep1_in_axis_tready),
	.axis_tlast(ep1_in_axis_tlast)
);

usb_blk_ep_out_ctl #(
	.FPGA_VENDOR(FPGA_VENDOR),
	.FPGA_FAMILY(FPGA_FAMILY)
) usb_blk_ep_out_ctl_inst (
	.rst(usb_reset),
	.usb_clk(usb_clk),
	.axis_clk(sys_clk),
	.blk_out_xfer(ep_blk_out_xfer),
	.blk_xfer_out_ready_read(ep_blk_xfer_out_ready_read),
	.blk_xfer_out_data_ready(ep_blk_xfer_out_data_ready),
	.blk_xfer_out_data_last(ep_blk_xfer_out_data_last),
	.blk_xfer_out_data(ep_blk_xfer_out_data),
	.blk_xfer_out_data_valid(ep_blk_xfer_out_data_valid),
	.axis_tdata(ep1_out_axis_tdata),
	.axis_tvalid(ep1_out_axis_tvalid),
	.axis_tready(ep1_out_axis_tready),
	.axis_tlast(ep1_out_axis_tlast)
);

endmodule
