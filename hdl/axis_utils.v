`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: Dmitry Matyunin (https://github.com/mcjtag)
// 
// Create Date: 18.03.2021 18:40:04
// Design Name: 
// Module Name: axis_width_converter
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

module axis_width_converter #(
	parameter FPGA_VENDOR = "xilinx",
	parameter FPGA_FAMILY = "7series",
	parameter BIG_ENDIAN = 1,
	parameter WIDTH_IN = 8, 	// 8,16,32
	parameter WIDTH_OUT = 16 	// 8,16,32
)
(
	input wire s_axis_aclk,
	input wire s_axis_aresetn,
	input wire [WIDTH_IN-1:0]s_axis_tdata,
	input wire s_axis_tvalid,
	output wire s_axis_tready,
	input wire s_axis_tlast,
	input wire m_axis_aclk,
	output wire [WIDTH_OUT-1:0]m_axis_tdata,
	output wire m_axis_tvalid,
	input wire m_axis_tready,
	output wire m_axis_tlast
);

localparam IN_RATIO = (WIDTH_IN > WIDTH_OUT) ? (WIDTH_IN / WIDTH_OUT) : 1;
localparam OUT_RATIO = (WIDTH_OUT > WIDTH_IN) ? (WIDTH_OUT / WIDTH_IN) : 1;

wire [WIDTH_OUT+OUT_RATIO-1:0]dout;
reg [WIDTH_IN+IN_RATIO-1:0]din;
wire empty;
wire full;
wire rd_rst_busy;
wire wr_rst_busy;
wire rd_en;
wire rst;
wire rd_clk;
wire wr_clk;
wire wr_en;

reg [WIDTH_OUT-1:0]m_data;
reg m_last;

assign wr_clk = s_axis_aclk;
assign rd_clk = m_axis_aclk;
assign rst = ~s_axis_aresetn;

assign wr_en = s_axis_tvalid & s_axis_tready;
assign rd_en = m_axis_tvalid & m_axis_tready;

assign s_axis_tready = ~full & ~wr_rst_busy;
assign m_axis_tvalid = ~empty & ~rd_rst_busy;

assign m_axis_tdata = m_data;
assign m_axis_tlast = m_last;

/* DATA IN */
always @(*) begin
	if (BIG_ENDIAN) begin
		case (IN_RATIO)
		1: din <= {s_axis_tlast,s_axis_tdata};
		2: din <= {s_axis_tlast,{s_axis_tdata[WIDTH_IN/2-1-:WIDTH_IN/2],1'b0,s_axis_tdata[WIDTH_IN-1-:WIDTH_IN/2]}};
		4: din <= {s_axis_tlast,{s_axis_tdata[WIDTH_IN/4-1-:WIDTH_IN/4],1'b0,s_axis_tdata[WIDTH_IN/2-1-:WIDTH_IN/4],1'b0,s_axis_tdata[3*WIDTH_IN/4-1-:WIDTH_IN/4],1'b0,s_axis_tdata[WIDTH_IN-1-:WIDTH_IN/4]}};
		endcase
	end else begin
		case (IN_RATIO)
		1: din <= {s_axis_tlast,s_axis_tdata};
		2: din <= {s_axis_tlast,{s_axis_tdata[WIDTH_IN/2-1-:WIDTH_IN/2],1'b0,s_axis_tdata[WIDTH_IN-1-:WIDTH_IN/2]}};
		4: din <= {s_axis_tlast,{s_axis_tdata[WIDTH_IN-1-:WIDTH_IN/4],1'b0,s_axis_tdata[3*WIDTH_IN/4-1-:WIDTH_IN/4],1'b0,s_axis_tdata[WIDTH_IN/2-1-:WIDTH_IN/4],1'b0,s_axis_tdata[WIDTH_IN/4-1-:WIDTH_IN/4]}};
		endcase
	end
end

/* DATA OUT */
always @(*)begin
	case (OUT_RATIO)
	1: begin
		m_data <= dout[WIDTH_OUT-1:0];
		m_last <= dout[WIDTH_OUT];
	end
	2: begin
		if (BIG_ENDIAN) begin
			m_data <= {dout[WIDTH_IN-1-:WIDTH_IN],dout[WIDTH_IN*2-:WIDTH_IN]};
		end else begin
			m_data <= {dout[WIDTH_IN*2-:WIDTH_IN],dout[WIDTH_IN-1-:WIDTH_IN]};
		end
		m_last <= dout[WIDTH_IN*2+1] | dout[WIDTH_IN];
	end
	4: begin
		if (BIG_ENDIAN) begin
			m_data <= {dout[WIDTH_IN-1-:WIDTH_IN],dout[WIDTH_IN*2-:WIDTH_IN], dout[WIDTH_IN*3+1-:WIDTH_IN],dout[WIDTH_IN*4+2-:WIDTH_IN]};
		end else begin
			m_data <= {dout[WIDTH_IN*4+2-:WIDTH_IN],dout[WIDTH_IN*3+1-:WIDTH_IN],dout[WIDTH_IN*2-:WIDTH_IN],dout[WIDTH_IN-1-:WIDTH_IN]};
		end
		m_last <= dout[WIDTH_IN*4+3] | dout[WIDTH_IN*3+2] | dout[WIDTH_IN*2+1] | dout[WIDTH_IN];
	end
	endcase
end

arch_fifo_async #(
	.FPGA_VENDOR(FPGA_VENDOR),
	.FPGA_FAMILY(FPGA_FAMILY),
	.RD_DATA_WIDTH(WIDTH_OUT + OUT_RATIO),
	.WR_DATA_WIDTH(WIDTH_IN + IN_RATIO)
) arch_fifo_async_inst (
	.dout(dout),
	.empty(empty),
	.full(full),
	.rd_rst_busy(rd_rst_busy),
	.wr_rst_busy(wr_rst_busy),
	.din(din),
	.rd_clk(rd_clk),
	.rd_en(rd_en),
	.rst(rst),
	.wr_clk(wr_clk),
	.wr_en(wr_en)
);

endmodule
