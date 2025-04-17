# axis_usbd
AXI-Stream USB 2.0 HS Device Bridge (Verilog). 

This project based on [USBCore](https://github.com/ObKo/USBCore) project by ObKo. It was rewritten to Verilog, modified and fixed some bugs. Now, It works correctly with USB-hubs and so on.

## Parameters
* FPGA_VENDOR        - FPGA Vendor (default: "xilinx")
* FPGA_FAMILY        - FPGA Family (default: "7series")
* HIGH_SPEED         - Speed Selection (0 - Full-Speed, 1 - High-Speed)
* SERIAL             - Serieal Number
* CHANNEL_IN_ENABLE  - Input channel Flag (0 - Disable, 1 - Enable)
* CHANNEL_OUT_ENABLE - Output channel Flag (0 - Disable, 1 - Enable)
* PACKET_MODE        - Packet mode (0 - Stream Mode, 1 - Packet Mode)
* DATA_IN_WIDTH      - Input data width (8, 16 or 32)
* DATA_OUT_WIDTH     - Output data width (8, 16 or 32)
* DATA_IN_ENDIAN     - Input Endianness (0 - Little Endian, LE; 1 - Big Endian, BE)
*  DATA_OUT_ENDIAN   - Output Endianness (0 - Little Endian, LE; 1 - Big Endian, BE)
* FIFO_IN_ENABLE     - Input FIFO (0 - Disable, 1 - Enable)
* FIFO_IN_PACKET     - Input FIFO Packet Mode (0 - Stream, 1 - Packet)
* FIFO_IN_DEPTH      - Input FIFO Depth (16 to 4194304)
* FIFO_OUT_ENABLE    - Output FIFO (0 - Disable, 1 - Enable)
* FIFO_OUT_PACKET    - Output FIFO Packet Mode (0 - Stream, 1 - Packet)
* FIFO_OUT_DEPTH     - Output FIFO Depth (16 to 4194304)

## Ports
* ulpi_data_i   - ULPI data input
* ulpi_data_o   - ULPI data output
* ulpi_data_t   - ULPI data direction (io buffer control)
* ulpi_dir      - ULPI Direction
* ulpi_nxt      - ULPI Next
* ulpi_stp      - ULPI Stop
* ulpi_reset    - ULPI Reset
* ulpi_clk      - ULPI CLK (clock from USB PHY)
* aclk          - Fabric Clock (AXIS clock)
* aresetn       - Fabric Synchronous Reset
* s_axis_tvalid - AXIS Input Valid
* s_axis_tready - AXIS Output Ready
* s_axis_tlast  - AXIS Input Last (in Packet Mode)
* s_axis_tdata  - AXIS Input Data
* m_axis_tvalid - AXIS Output Valid
* m_axis_tready - AXIS Input Ready
* m_axis_tdata  - AXIS Output Last (in Packet Mode)
* m_axis_tlast  - AXIS Output Data

## Platform Compability
At this moment, `axis_usbd` supports only Xilinx 7-Series FPGA. If you have different FPGA Vendor and Family, please, append architecture-dependent modules to `arch_utils` (arch_cdc_array, arch_cdc_reset, arch_fifo_axis and arch_fifo_async) with your specific FPGA_VENDOR and FPGA_FAMILY.

## OS Driver
The `drv` folder contains some library source code and examples. Custom driver uses low-level `libusb` library. For Windows OS it is avalabe to use `WinUSB` library.

*P.S. Feel free to send me an e-mail. I`ll try to help you and answer all questions.* 