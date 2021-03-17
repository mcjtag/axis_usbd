`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: Dmitry Matyunin (https://github.com/mcjtag)
// 
// Create Date: 10.12.2019 14:55:14
// Design Name: 
// Module Name: usb_std_request
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

module usb_std_request #(
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
		8'h00,		/* iInterface */
		8'h00,		/* bInterfaceProtocol */
		8'h00,		/* bInterfaceSubClass */
		8'h00,		/* bInterfaceClass */
		8'h00,		/* bNumEndpoints = 0 */
		8'h00,		/* bAlternateSetting */
		8'h00,		/* bInterfaceNumber = 0 */
		8'h04,		/* bDescriptorType = Interface Descriptor */
		8'h09,		/* bLength = 9 */
		/* Configuration Descriptor */
		8'h32,		/* bMaxPower = 100 mA */
		8'hC0,		/* bmAttributes = Self-powered */
		8'h00,		/* iConfiguration */
		8'h01,		/* bConfigurationValue */
		8'h01,		/* bNumInterfaces = 1 */
		16'h0012,	/* wTotalLength = 18 */
		8'h02,		/* bDescriptionType = Configuration Descriptor */
		8'h09		/* bLength = 9 */
	},
	parameter integer HIGH_SPEED = 1
)
(
	input wire rst,
	input wire clk,
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
	output wire [6:0]device_address,
	output wire [7:0]current_configuration,
	output wire configured,
	output wire standart_request
);

function [(2+2*MANUFACTURER_LEN)*8-1:0]desc_manufacturer;
	input [MANUFACTURER_LEN*8-1:0]str;
	integer i;
	begin
		desc_manufacturer[8*(0+1)-1-:8] = 2+2*MANUFACTURER_LEN;
		desc_manufacturer[8*(1+1)-1-:8] = 8'h03;
		for (i = 0; i < MANUFACTURER_LEN; i = i + 1) begin
			desc_manufacturer[8*(2+2*i+1)-1-:8] = str[8*(MANUFACTURER_LEN-i)-1-:8];
			desc_manufacturer[8*(3+2*i+1)-1-:8] = 8'h00;
		end
	end
endfunction

function [(2+2*PRODUCT_LEN)*8-1:0]desc_product;
	input [PRODUCT_LEN*8-1:0]str;
	integer i;
	begin
		desc_product[8*(0+1)-1-:8] = 2+2*PRODUCT_LEN;
		desc_product[8*(1+1)-1-:8] = 8'h03;
		for (i = 0; i < PRODUCT_LEN; i = i + 1) begin
			desc_product[8*(2+2*i+1)-1-:8] = str[8*(PRODUCT_LEN-i)-1-:8];
			desc_product[8*(3+2*i+1)-1-:8] = 8'h00;
		end
	end
endfunction

function [(2+2*SERIAL_LEN)*8-1:0]desc_serial;
	input [SERIAL_LEN*8-1:0]str;
	integer i;
	begin
		desc_serial[8*(0+1)-1-:8] = 2+2*SERIAL_LEN;
		desc_serial[8*(1+1)-1-:8] = 8'h03;
		for (i = 0; i < SERIAL_LEN; i = i + 1) begin
			desc_serial[8*(2+2*i+1)-1-:8] = str[8*(SERIAL_LEN-i)-1-:8];
			desc_serial[8*(3+2*i+1)-1-:8] = 8'h00;
		end
	end
endfunction

/* Full Speed Descriptor */
localparam DEVICE_DESC_FS = {
	8'h01,                             	  		/* bNumConfigurations = 1 */
	(SERIAL_LEN == 0) ? 8'h00 : 8'h03,    		/* iSerialNumber */
	(PRODUCT_LEN == 0) ? 8'h00 : 8'h02,			/* iProduct */
	(MANUFACTURER_LEN == 0) ? 8'h00 : 8'h01,  	/* iManufacturer */
	16'h0000,									/* bcdDevice */
	PRODUCT_ID,									/* idProduct */
	VENDOR_ID,									/* idVendor */
	8'h40,	                              		/* bMaxPacketSize = 64 */
	8'h00,	                              		/* bDeviceProtocol */
	8'h00,                              		/* bDeviceSubClass */
	8'hFF,                              		/* bDeviceClass = None */
	16'h0110,									/* bcdUSB = USB 1.1 */
	8'h01,                         				/* bDescriptionType = Device Descriptor */
	8'h12					                    /* bLength = 18 */
};

/* High Speed Descriptor */
localparam DEVICE_DESC_HS = {
	8'h01,										/* bNumConfigurations = 1 */
	(SERIAL_LEN == 0) ? 8'h00 : 8'h03,			/* iSerialNumber */
	(PRODUCT_LEN == 0) ? 8'h00 : 8'h02,			/* iProduct */
	(MANUFACTURER_LEN == 0) ? 8'h00 : 8'h01,	/* iManufacturer */
	16'h0000,									/* bcdDevice */ 
	PRODUCT_ID,									/* idProduct */
	VENDOR_ID,									/* idVendor */
	8'h40,										/* bMaxPacketSize = 64 */
	8'h00,										/* bDeviceProtocol */
	8'h00,										/* bDeviceSubClass */
	8'hFF,										/* bDeviceClass = None */
	16'h0200,									/* bcdUSB = USB 2.0 */
	8'h01,										/* bDescriptionType = Device Descriptor */
	8'h12										/* bLength = 18 */
};

localparam DEVICE_DESC = (HIGH_SPEED == 1) ? DEVICE_DESC_HS : DEVICE_DESC_FS;

localparam [4*8-1:0]STR_DESC = {
    16'h0409,
	8'h03,										/* bDescriptorType = String Descriptor */
	8'h04										/* bLength = 4 */
};

localparam MANUFACTURER_STR_DESC = desc_manufacturer(MANUFACTURER);
localparam PRODUCT_STR_DESC = desc_product(PRODUCT);
localparam SERIAL_STR_DESC = desc_serial(SERIAL);

localparam DEVICE_DESC_LEN = 18;
localparam STR_DESC_LEN = 4;
localparam MANUFACTURER_STR_DESC_LEN = 2 + 2*MANUFACTURER_LEN;
localparam PRODUCT_STR_DESC_LEN = 2 + 2*PRODUCT_LEN;
localparam SERIAL_STR_DESC_LEN = 2 + 2*SERIAL_LEN;

localparam DESC_SIZE_STR = DEVICE_DESC_LEN + CONFIG_DESC_LEN + STR_DESC_LEN + MANUFACTURER_STR_DESC_LEN + PRODUCT_STR_DESC_LEN + SERIAL_STR_DESC_LEN;
localparam DESC_SIZE_NOSTR = DEVICE_DESC_LEN + CONFIG_DESC_LEN;
localparam DESC_HAS_STRINGS = (MANUFACTURER_LEN > 0) || (PRODUCT_LEN > 0) || (SERIAL_LEN > 0);
localparam DESC_SIZE = (DESC_HAS_STRINGS) ? DESC_SIZE_STR : DESC_SIZE_NOSTR;
localparam USB_DESC = (DESC_HAS_STRINGS) ? {SERIAL_STR_DESC,PRODUCT_STR_DESC,MANUFACTURER_STR_DESC,STR_DESC,CONFIG_DESC,DEVICE_DESC} : {CONFIG_DESC,DEVICE_DESC};

localparam DESC_CONFIG_START = DEVICE_DESC_LEN;
localparam DESC_STRING_START = DEVICE_DESC_LEN + CONFIG_DESC_LEN;

localparam [1:0]
	STATE_IDLE = 2'd0, 
	STATE_GET_DESC = 2'd01,
	STATE_SET_CONF = 2'd02,
	STATE_SET_ADDR = 2'd03;

reg [1:0]state;
reg [7:0]mem_addr;
reg [7:0]max_mem_addr;
reg [2:0]req_type;

/* Request types:
	000 - None
	001 - Get device descriptor
	010 - Set address
	011 - Get configuration descriptor
	100 - Set configuration
	101 - Get string descriptor
*/

reg [6:0]device_address_int;
reg [7:0]current_configuration_int;
reg configured_int;

wire is_std_req;
wire is_dev_req;
wire handle_req;

assign device_address = device_address_int;
assign current_configuration = current_configuration_int;
assign configured = configured_int;

assign is_std_req = ((ctl_xfer_endpoint == 4'h0) && (ctl_xfer_type[6:5] == 2'b00)) ? 1'b1 : 1'b0;
assign is_dev_req = (ctl_xfer_type[4:0] == 5'b00000) ? 1'b1 : 1'b0;
assign handle_req = is_std_req & is_dev_req;
assign standart_request = is_std_req;
assign ctl_xfer_data_in_valid = (state == STATE_GET_DESC) ? 1'b1 : 1'b0;
assign ctl_xfer_data_in = USB_DESC[8*(mem_addr+1)-1-:8];
assign ctl_xfer_data_in_last = ((state == STATE_GET_DESC) && (mem_addr == max_mem_addr)) ? 1'b1 : 1'b0;
assign ctl_xfer_done = 1'b1;
assign ctl_xfer_accept = (req_type == 3'b000) ? 1'b0 : 1'b1;

always @(posedge clk) begin
	if (rst == 1'b1) begin
	
	end else begin
		if (state == STATE_IDLE) begin
			if (ctl_xfer == 1'b1) begin
				if (req_type == 3'b011) begin
					mem_addr <= DESC_CONFIG_START;
					max_mem_addr <= DESC_STRING_START - 1;
				end else if (DESC_HAS_STRINGS && (req_type == 3'b101)) begin
					if (ctl_xfer_value[7:0] == 8'h00) begin
						mem_addr <= DESC_STRING_START;
						max_mem_addr <= DESC_STRING_START + STR_DESC_LEN - 1;
					end else if (ctl_xfer_value[7:0] == 8'h01) begin
						mem_addr <= DESC_STRING_START + STR_DESC_LEN;
						max_mem_addr <= DESC_STRING_START + STR_DESC_LEN + MANUFACTURER_STR_DESC_LEN - 1;
					end else if (ctl_xfer_value[7:0] == 8'h02) begin
						mem_addr <= DESC_STRING_START + STR_DESC_LEN + MANUFACTURER_STR_DESC_LEN;
						max_mem_addr <= DESC_STRING_START + STR_DESC_LEN + MANUFACTURER_STR_DESC_LEN + PRODUCT_STR_DESC_LEN - 1;
					end else if (ctl_xfer_value[7:0] == 8'h03) begin
						mem_addr <= DESC_STRING_START + STR_DESC_LEN + MANUFACTURER_STR_DESC_LEN + PRODUCT_STR_DESC_LEN;
						max_mem_addr <= DESC_SIZE - 1;
					end
				end else begin
					mem_addr <= 0;
					max_mem_addr <= DESC_CONFIG_START - 1;
				end
			end else begin
				mem_addr <= 0;
			end
		end else if ((state == STATE_GET_DESC) && (ctl_xfer_data_in_ready == 1'b1)) begin
			if (mem_addr != max_mem_addr) begin
				mem_addr <= mem_addr + 1;
			end
		end
	end
end

always @(posedge clk) begin
	if (rst == 1'b1) begin
		state <= STATE_IDLE;
		device_address_int <= 0;
		configured_int <= 1'b0;
	end else begin
		case (state)
		STATE_IDLE: begin
			if (ctl_xfer == 1'b1) begin
				if ((req_type == 3'b001) || (req_type == 3'b011) || (req_type == 3'b101)) begin
					state <= STATE_GET_DESC;
				end else if (req_type == 3'b010) begin
					state <= STATE_SET_ADDR;
				end else if (req_type == 3'b100) begin
					current_configuration_int <= ctl_xfer_value[7:0];
					state <= STATE_SET_CONF;
				end
			end
		end
		STATE_SET_ADDR: begin
			if (ctl_xfer == 1'b0) begin
				state <= STATE_IDLE;
				device_address_int <= ctl_xfer_value[6:0];
			end
		end
		STATE_GET_DESC: begin
			if (ctl_xfer == 1'b0) begin
				state <= STATE_IDLE;
			end
		end
		STATE_SET_CONF: begin
			if (ctl_xfer == 1'b0) begin
				configured_int <= 1'b1;
				state <= STATE_IDLE;
			end
		end
        endcase
	end
end

always @(*) begin
	if ((handle_req == 1'b1) && (ctl_xfer_request == 8'h06) && (ctl_xfer_value[15:8] == 8'h01)) begin
		req_type <= 3'b001;
	end else if ((handle_req == 1'b1) && (ctl_xfer_request == 8'h05)) begin
		req_type <= 3'b010;
	end else if ((handle_req == 1'b1) && (ctl_xfer_request == 8'h06) && (ctl_xfer_value[15:8] == 8'h02)) begin
		req_type <= 3'b011;
	end else if ((handle_req == 1'b1) && (ctl_xfer_request == 8'h09)) begin
		req_type <= 3'b100;
	end else if ((handle_req == 1'b1) && (ctl_xfer_request == 8'h06) && (ctl_xfer_value[15:8] == 8'h03)) begin
		req_type <= 3'b101;
	end else begin
		req_type <= 3'b000;
	end
end

endmodule
