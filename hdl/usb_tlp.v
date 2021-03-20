`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: Dmitry Matyunin (https://github.com/mcjtag)
// 
// Create Date: 20.03.2021 18:07:34
// Design Name: 
// Module Name: usb_tlp
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

module usb_tlp #(
	parameter [15:0]VENDOR_ID = 16'hFACE,
	parameter [15:0]PRODUCT_ID = 16'h0BDE,
	parameter MANUFACTURER_LEN = 0,
	parameter MANUFACTURER = "",
	parameter PRODUCT_LEN = 0,
	parameter PRODUCT = "",
	parameter SERIAL_LEN = 0,
	parameter SERIAL = "",
	parameter CONFIG_DESC_LEN = 18,
	parameter CONFIG_DESC = {
		/* Interface descriptor */
		8'h00,			/* iInterface */
		8'h00,			/* bInterfaceProtocol */
		8'h00,			/* bInterfaceSubClass */
		8'h00,			/* bInterfaceClass */
		8'h00,			/* bNumEndpoints = 0 */
		8'h00,			/* bAlternateSetting */
		8'h00,			/* bInterfaceNumber = 0 */
		8'h04,			/* bDescriptorType = Interface Descriptor */
		8'h09,			/* bLength = 9 */
		/* Configuration Descriptor */
		8'h32,			/* bMaxPower = 100 mA */
		8'hC0,			/* bmAttributes = Self-powered */
		8'h00,			/* iConfiguration */
		8'h01,			/* bConfigurationValue */
		8'h01,			/* bNumInterfaces = 1 */
		16'h0012,		/* wTotalLength = 18 */
		8'h02,			/* bDescriptionType = Configuration Descriptor */
		8'h09			/* bLength = 9 */
	},
	parameter integer HIGH_SPEED = 1
)
(
	input wire [7:0]ulpi_data_in,
	output wire [7:0]ulpi_data_out,
	input wire ulpi_dir,
	input wire ulpi_nxt,
	output wire ulpi_stp,
	output wire ulpi_reset,
	input wire ulpi_clk60,
	output wire usb_clk,
	output wire usb_reset,

	output wire usb_idle,
	output wire usb_suspend,
	output wire usb_configured,
	output wire usb_crc_error,
	// Pulse when SOF packet received
	output wire usb_sof,

	// Control transfer signals
	output wire [3:0]ctl_xfer_endpoint,
	output wire [7:0]ctl_xfer_type,
	output wire [7:0]ctl_xfer_request,
	output wire [15:0]ctl_xfer_value,
	output wire [15:0]ctl_xfer_index,
	output wire [15:0]ctl_xfer_length,
	input wire ctl_xfer_accept,
	output wire ctl_xfer,
	input wire ctl_xfer_done,

	output wire [7:0]ctl_xfer_data_out,
	output wire ctl_xfer_data_out_valid,

	input wire [7:0]ctl_xfer_data_in,
	input wire ctl_xfer_data_in_valid,
	input wire ctl_xfer_data_in_last,
	output wire ctl_xfer_data_in_ready,

	// Bulk transfer signals
	output wire [3:0]blk_xfer_endpoint,
	output wire blk_in_xfer,
	output wire blk_out_xfer,

	// Has complete packet
	input wire blk_xfer_in_has_data,
	input wire [7:0]blk_xfer_in_data,
	input wire blk_xfer_in_data_valid,
	output wire blk_xfer_in_data_ready,
	input wire blk_xfer_in_data_last,

	// Can accept full packet
	input wire blk_xfer_out_ready_read,
	output wire [7:0]blk_xfer_out_data,
	output wire blk_xfer_out_data_valid
);

wire axis_rx_tvalid;
wire axis_rx_tready;
wire axis_rx_tlast;
wire [7:0]axis_rx_tdata;

wire axis_tx_tvalid;
wire axis_tx_tready;
wire axis_tx_tlast;
wire [7:0]axis_tx_tdata;
wire usb_vbus_valid;

wire [1:0]trn_type;
wire [6:0]trn_address;
wire [3:0]trn_endpoint;
wire trn_start;

wire [1:0]rx_trn_data_type;
wire rx_trn_end;
wire [7:0]rx_trn_data;
wire rx_trn_valid;

wire [1:0]rx_trn_hsk_type;
wire rx_trn_hsk_received;

wire [1:0]tx_trn_hsk_type;
wire tx_trn_send_hsk;
wire tx_trn_hsk_sended;

wire [1:0]tx_trn_data_type;
wire tx_trn_data_start;

wire [7:0]tx_trn_data;
wire tx_trn_data_valid;
wire tx_trn_data_ready;
wire tx_trn_data_last;

wire [3:0]ctl_xfer_endpoint_int;
wire [7:0]ctl_xfer_type_int;
wire [7:0]ctl_xfer_request_int;
wire [15:0]ctl_xfer_value_int;
wire [15:0]ctl_xfer_index_int;
wire [15:0]ctl_xfer_length_int;
wire ctl_xfer_accept_int;
wire ctl_xfer_int;
wire ctl_xfer_done_int;
  
wire ctl_xfer_accept_std;
wire ctl_xfer_std;
wire ctl_xfer_done_std;

wire [7:0]ctl_xfer_data_out_int;
wire ctl_xfer_data_out_valid_int;

wire [7:0]ctl_xfer_data_in_int;
wire ctl_xfer_data_in_valid_int;
wire ctl_xfer_data_in_last_int;
wire ctl_xfer_data_in_ready_int;
  
wire [7:0]ctl_xfer_data_in_std;
wire ctl_xfer_data_in_valid_std;
wire ctl_xfer_data_in_last_std;

wire [7:0]current_configuration;
wire usb_reset_int;
wire usb_crc_error_int;
wire standart_request;
wire [6:0]device_address;

assign usb_clk = ulpi_clk60;
assign usb_reset = usb_reset_int;
assign usb_crc_error = usb_crc_error_int;
assign ctl_xfer_endpoint = ctl_xfer_endpoint_int;
assign ctl_xfer_type = ctl_xfer_type_int;
assign ctl_xfer_request = ctl_xfer_request_int;
assign ctl_xfer_value = ctl_xfer_value_int;
assign ctl_xfer_index = ctl_xfer_index_int;
assign ctl_xfer_length = ctl_xfer_length_int;

assign ctl_xfer_accept_int = (standart_request == 1'b1) ? ctl_xfer_accept_std : ctl_xfer_accept;
assign ctl_xfer = (standart_request == 1'b0) ? ctl_xfer_int : 1'b0;
assign ctl_xfer_done_int = (standart_request == 1'b1) ? ctl_xfer_done_std : ctl_xfer_done;
assign ctl_xfer_data_out = ctl_xfer_data_out_int;
assign ctl_xfer_data_out_valid = (standart_request == 1'b0) ? ctl_xfer_data_out_valid_int : 1'b0;
assign ctl_xfer_data_in_int = (standart_request == 1'b1) ? ctl_xfer_data_in_std : ctl_xfer_data_in;
assign ctl_xfer_data_in_valid_int = (standart_request == 1'b1) ? ctl_xfer_data_in_valid_std : ctl_xfer_data_in_valid;
assign ctl_xfer_data_in_last_int = (standart_request == 1'b1) ? ctl_xfer_data_in_last_std : ctl_xfer_data_in_last;
assign ctl_xfer_data_in_ready = (standart_request == 1'b0) ? ctl_xfer_data_in_ready_int : 1'b0;

usb_ulpi #(
	.HIGH_SPEED(HIGH_SPEED)
) usb_ulpi_inst (
	.rst(1'b0),
	.ulpi_data_in(ulpi_data_in),
	.ulpi_data_out(ulpi_data_out),
	.ulpi_dir(ulpi_dir),
	.ulpi_nxt(ulpi_nxt),
	.ulpi_stp(ulpi_stp),
	.ulpi_reset(ulpi_reset),
	.ulpi_clk(ulpi_clk60),
	.axis_rx_tvalid(axis_rx_tvalid),
	.axis_rx_tready(axis_rx_tready),
	.axis_rx_tlast(axis_rx_tlast),
	.axis_rx_tdata(axis_rx_tdata),
	.axis_tx_tvalid(axis_tx_tvalid),
	.axis_tx_tready(axis_tx_tready),
	.axis_tx_tlast(axis_tx_tlast),
	.axis_tx_tdata(axis_tx_tdata),
	.usb_vbus_valid(usb_vbus_valid),
	.usb_reset(usb_reset_int),
	.usb_idle(usb_idle),
	.usb_suspend(usb_suspend)
);

usb_packet usb_packet_inst (
	.rst(usb_reset_int),
	.clk(ulpi_clk60),
	.axis_rx_tvalid(axis_rx_tvalid),
	.axis_rx_tready(axis_rx_tready),
	.axis_rx_tlast(axis_rx_tlast),
	.axis_rx_tdata(axis_rx_tdata),
	.axis_tx_tvalid(axis_tx_tvalid),
	.axis_tx_tready(axis_tx_tready),
	.axis_tx_tlast(axis_tx_tlast),
	.axis_tx_tdata(axis_tx_tdata),
	.trn_type(trn_type),
	.trn_address(trn_address),
	.trn_endpoint(trn_endpoint),
	.trn_start(trn_start),
	.rx_trn_data_type(rx_trn_data_type),
	.rx_trn_end(rx_trn_end),
	.rx_trn_data(rx_trn_data),
	.rx_trn_valid(rx_trn_valid),
	.rx_trn_hsk_type(rx_trn_hsk_type),
	.rx_trn_hsk_received(rx_trn_hsk_received),
	.tx_trn_hsk_type(tx_trn_hsk_type),
	.tx_trn_send_hsk(tx_trn_send_hsk),
	.tx_trn_hsk_sended(tx_trn_hsk_sended),
	.tx_trn_data_type(tx_trn_data_type),
	.tx_trn_data_start(tx_trn_data_start),
	.tx_trn_data(tx_trn_data),
	.tx_trn_data_valid(tx_trn_data_valid),
	.tx_trn_data_ready(tx_trn_data_ready),
	.tx_trn_data_last(tx_trn_data_last),
	.start_of_frame(usb_sof),
	.crc_error(usb_crc_error_int),
	.device_address(device_address)
);

usb_xfer #(
	.HIGH_SPEED(HIGH_SPEED)
) usb_xfer_inst (
	.rst(usb_reset_int),
	.clk(ulpi_clk60),
	.trn_type(trn_type),
	.trn_address(trn_address),
	.trn_endpoint(trn_endpoint),
	.trn_start(trn_start),
	.rx_trn_data_type(rx_trn_data_type),
	.rx_trn_end(rx_trn_end),
	.rx_trn_data(rx_trn_data),
	.rx_trn_valid(rx_trn_valid),
	.rx_trn_hsk_type(rx_trn_hsk_type),
	.rx_trn_hsk_received(rx_trn_hsk_received),
	.tx_trn_hsk_type(tx_trn_hsk_type),
	.tx_trn_send_hsk(tx_trn_send_hsk),
	.tx_trn_hsk_sended(tx_trn_hsk_sended),
	.tx_trn_data_type(tx_trn_data_type),
	.tx_trn_data_start(tx_trn_data_start),
	.tx_trn_data(tx_trn_data),
	.tx_trn_data_valid(tx_trn_data_valid),
	.tx_trn_data_ready(tx_trn_data_ready),
	.tx_trn_data_last(tx_trn_data_last),
	.crc_error(usb_crc_error_int),
	.ctl_xfer_endpoint(ctl_xfer_endpoint_int),
	.ctl_xfer_type(ctl_xfer_type_int),
	.ctl_xfer_request(ctl_xfer_request_int),
	.ctl_xfer_value(ctl_xfer_value_int),
	.ctl_xfer_index(ctl_xfer_index_int),
	.ctl_xfer_length(ctl_xfer_length_int),
	.ctl_xfer_accept(ctl_xfer_accept_int),
	.ctl_xfer(ctl_xfer_int),
	.ctl_xfer_done(ctl_xfer_done_int),
	.ctl_xfer_data_out(ctl_xfer_data_out_int),
	.ctl_xfer_data_out_valid(ctl_xfer_data_out_valid_int),
	.ctl_xfer_data_in(ctl_xfer_data_in_int),
	.ctl_xfer_data_in_valid(ctl_xfer_data_in_valid_int),
	.ctl_xfer_data_in_last(ctl_xfer_data_in_last_int),
	.ctl_xfer_data_in_ready(ctl_xfer_data_in_ready_int),
	.blk_xfer_endpoint(blk_xfer_endpoint),
	.blk_in_xfer(blk_in_xfer),
	.blk_out_xfer(blk_out_xfer),
	.blk_xfer_in_has_data(blk_xfer_in_has_data),
	.blk_xfer_in_data(blk_xfer_in_data),
	.blk_xfer_in_data_valid(blk_xfer_in_data_valid),
	.blk_xfer_in_data_ready(blk_xfer_in_data_ready),
	.blk_xfer_in_data_last(blk_xfer_in_data_last),
	.blk_xfer_out_ready_read(blk_xfer_out_ready_read),
	.blk_xfer_out_data(blk_xfer_out_data),
	.blk_xfer_out_data_valid(blk_xfer_out_data_valid)
);

usb_std_request #(
	.VENDOR_ID(VENDOR_ID),
	.PRODUCT_ID(PRODUCT_ID),
	.MANUFACTURER_LEN(MANUFACTURER_LEN),
	.MANUFACTURER(MANUFACTURER),
	.PRODUCT_LEN(PRODUCT_LEN),
	.PRODUCT(PRODUCT),
	.SERIAL_LEN(SERIAL_LEN),
	.SERIAL(SERIAL),
	.CONFIG_DESC_LEN(CONFIG_DESC_LEN),
	.CONFIG_DESC(CONFIG_DESC),
	.HIGH_SPEED(HIGH_SPEED)
)  usb_std_request_inst (
	.rst(usb_reset_int),
	.clk(ulpi_clk60),
	.ctl_xfer_endpoint(ctl_xfer_endpoint_int),
	.ctl_xfer_type(ctl_xfer_type_int),
	.ctl_xfer_request(ctl_xfer_request_int),
	.ctl_xfer_value(ctl_xfer_value_int),
	.ctl_xfer_index(ctl_xfer_index_int),
	.ctl_xfer_length(ctl_xfer_length_int),
	.ctl_xfer_accept(ctl_xfer_accept_std),
	.ctl_xfer(ctl_xfer_int),
	.ctl_xfer_done(ctl_xfer_done_std),
	.ctl_xfer_data_out(ctl_xfer_data_out_int),
	.ctl_xfer_data_out_valid(ctl_xfer_data_out_valid_int),
	.ctl_xfer_data_in(ctl_xfer_data_in_std),
	.ctl_xfer_data_in_valid(ctl_xfer_data_in_valid_std),
	.ctl_xfer_data_in_last(ctl_xfer_data_in_last_std),
	.ctl_xfer_data_in_ready(ctl_xfer_data_in_ready_int),
	.device_address(device_address),
	.current_configuration(current_configuration),
	.configured(usb_configured),
	.standart_request(standart_request)
);

endmodule
