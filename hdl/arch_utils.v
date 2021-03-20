`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: Dmitry Matyunin (https://github.com/mcjtag)
// 
// Create Date: 18.03.2021 19:32:35
// Design Name: 
// Module Name: arch_cdc_array, arch_cdc_reset, arch_fifo_axis, arch_fifo_async
// Project Name: axis_usbd
// Target Devices:
// Tool Versions:
// Description: architecture-dependent modules
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

//
// CDC Array
//
module arch_cdc_array #(
	parameter FPGA_VENDOR = "xilinx",
	parameter FPGA_FAMILY = "7series",
	parameter WIDTH = 2
)
(
	input wire src_clk,
	input wire [WIDTH-1:0]src_data,
	input wire dst_clk,
	output wire [WIDTH-1:0]dst_data
);

generate if ((FPGA_VENDOR == "xilinx") && (FPGA_FAMILY == "7series")) begin
	xpm_cdc_array_single #(
		.DEST_SYNC_FF(3),
		.INIT_SYNC_FF(0),
		.SIM_ASSERT_CHK(0),
		.SRC_INPUT_REG(1),
		.WIDTH(WIDTH)
	) xpm_cdc_array_single_inst (
		.dest_out(dst_data),
		.dest_clk(dst_clk),
		.src_clk(src_clk),
		.src_in(src_data)
	);
end else begin
	initial $error("Unsupported FPGA Vendor or Family!");
end endgenerate

endmodule

//
// CDC Reset
//
module arch_cdc_reset #(
	parameter FPGA_VENDOR = "xilinx",
	parameter FPGA_FAMILY = "7series"
)
(
	input wire src_rst,
	input wire dst_clk,
	output wire dst_rst
);

generate if ((FPGA_VENDOR == "xilinx") && (FPGA_FAMILY == "7series")) begin
	xpm_cdc_sync_rst #(
		.DEST_SYNC_FF(4),
		.INIT(1),
		.INIT_SYNC_FF(0),
		.SIM_ASSERT_CHK(0)
	) xpm_cdc_sync_rst_inst (
		.dest_rst(dst_rst),
		.dest_clk(dst_clk),
		.src_rst(src_rst)
	);
end else begin
	initial $error("Unsupported FPGA Vendor or Family!");
end endgenerate

endmodule

module arch_fifo_axis #(
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

generate if ((FPGA_VENDOR == "xilinx") && (FPGA_FAMILY == "7series")) begin
	localparam CLOCKING_MODE = (CLOCK_MODE == "ASYNC") ? "independent_clock" : "common_clock";
	localparam PACKET_FIFO = (FIFO_PACKET == 0) ? "false" : "true";
	localparam USE_ADV_FEATURES = (PROG_FULL_THRESHOLD != 0)? "1002" : "1000";

	xpm_fifo_axis #(
		.CDC_SYNC_STAGES(2),
		.CLOCKING_MODE(CLOCKING_MODE),
		.ECC_MODE("no_ecc"),
		.FIFO_DEPTH(FIFO_DEPTH),
		.FIFO_MEMORY_TYPE("auto"),
		.PACKET_FIFO(PACKET_FIFO),
		.PROG_EMPTY_THRESH(10),
		.PROG_FULL_THRESH(PROG_FULL_THRESHOLD),
		.RD_DATA_COUNT_WIDTH(1),
		.RELATED_CLOCKS(0),
		.TDATA_WIDTH(DATA_WIDTH),
		.TDEST_WIDTH(1),
		.TID_WIDTH(1),
		.TUSER_WIDTH(1),
		.USE_ADV_FEATURES(USE_ADV_FEATURES),
		.WR_DATA_COUNT_WIDTH(1)
	) xpm_fifo_axis_inst (
		.almost_empty_axis(),
		.almost_full_axis(),
		.dbiterr_axis(),
		.m_axis_tdata(m_axis_tdata),
		.m_axis_tdest(),
		.m_axis_tid(),
		.m_axis_tkeep(),
		.m_axis_tlast(m_axis_tlast),
		.m_axis_tstrb(),
		.m_axis_tuser(),
		.m_axis_tvalid(m_axis_tvalid),
		.prog_empty_axis(),
		.prog_full_axis(axis_prog_full),
		.rd_data_count_axis(),
		.s_axis_tready(s_axis_tready),
		.sbiterr_axis(),
		.wr_data_count_axis(),
		.injectdbiterr_axis(),
		.injectsbiterr_axis(),
		.m_aclk(m_aclk),
		.m_axis_tready(m_axis_tready),
		.s_aclk(s_aclk),
		.s_aresetn(s_aresetn),
		.s_axis_tdata(s_axis_tdata),
		.s_axis_tdest(),
		.s_axis_tid(),
		.s_axis_tkeep(),
		.s_axis_tlast(s_axis_tlast),
		.s_axis_tstrb(),
		.s_axis_tuser(),
		.s_axis_tvalid(s_axis_tvalid)
	);
end else begin
	initial $error("Unsupported FPGA Vendor or Family!");
end endgenerate

endmodule

module arch_fifo_async #(
	parameter FPGA_VENDOR = "xilinx",
	parameter FPGA_FAMILY = "7series",
	parameter RD_DATA_WIDTH = 8,
	parameter WR_DATA_WIDTH = 8
)
(
	output wire [RD_DATA_WIDTH-1:0]dout,
	output wire empty,
	output wire full,
	output wire rd_rst_busy,
	output wire wr_rst_busy,
	input wire [WR_DATA_WIDTH-1:0]din,
	input wire rd_clk,
	input wire rd_en,
	input wire rst,
	input wire wr_clk,
	input wire wr_en
);

generate if ((FPGA_VENDOR == "xilinx") && (FPGA_FAMILY == "7series")) begin
	xpm_fifo_async #(
		.CDC_SYNC_STAGES(4),
		.DOUT_RESET_VALUE("0"),
		.ECC_MODE("no_ecc"),
		.FIFO_MEMORY_TYPE("distributed"),
		.FIFO_READ_LATENCY(0),
		.FIFO_WRITE_DEPTH(16*4),
		.FULL_RESET_VALUE(0),
		.PROG_EMPTY_THRESH(),
		.PROG_FULL_THRESH(),
		.RD_DATA_COUNT_WIDTH(1),
		.READ_DATA_WIDTH(RD_DATA_WIDTH),
		.READ_MODE("fwft"),
		.RELATED_CLOCKS(0),
		.USE_ADV_FEATURES("0000"),
		.WAKEUP_TIME(0),
		.WRITE_DATA_WIDTH(WR_DATA_WIDTH),
		.WR_DATA_COUNT_WIDTH(1)
	) xpm_fifo_async_inst (
		.almost_empty(),
		.almost_full(),
		.data_valid(),
		.dbiterr(),
		.dout(dout),
		.empty(empty),
		.full(full),
		.overflow(),
		.prog_empty(),
		.prog_full(),
		.rd_data_count(),
		.rd_rst_busy(rd_rst_busy),
		.sbiterr(),
		.underflow(),
		.wr_ack(),
		.wr_data_count(),
		.wr_rst_busy(wr_rst_busy),
		.din(din),
		.injectdbiterr(),
		.injectsbiterr(),
		.rd_clk(rd_clk),
		.rd_en(rd_en),
		.rst(rst),
		.sleep(1'b0),
		.wr_clk(wr_clk),
		.wr_en(wr_en)
	);
end else begin
	initial $error("Unsupported FPGA Vendor or Family!");
end endgenerate

endmodule