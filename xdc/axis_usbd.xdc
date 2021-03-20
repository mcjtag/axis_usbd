#
# AXIS USB HS Example Constraints
#

#set_property -dict {PACKAGE_PIN <PIN_NUMBER> IOSTANDARD LVCMOS33 SLEW FAST DRIVE 12} [get_ports {ulpi_data_io[0]}]
#set_property -dict {PACKAGE_PIN <PIN_NUMBER> IOSTANDARD LVCMOS33 SLEW FAST DRIVE 12} [get_ports {ulpi_data_io[1]}]
#set_property -dict {PACKAGE_PIN <PIN_NUMBER> IOSTANDARD LVCMOS33 SLEW FAST DRIVE 12} [get_ports {ulpi_data_io[2]}]
#set_property -dict {PACKAGE_PIN <PIN_NUMBER> IOSTANDARD LVCMOS33 SLEW FAST DRIVE 12} [get_ports {ulpi_data_io[3]}]
#set_property -dict {PACKAGE_PIN <PIN_NUMBER> IOSTANDARD LVCMOS33 SLEW FAST DRIVE 12} [get_ports {ulpi_data_io[4]}]
#set_property -dict {PACKAGE_PIN <PIN_NUMBER> IOSTANDARD LVCMOS33 SLEW FAST DRIVE 12} [get_ports {ulpi_data_io[5]}]
#set_property -dict {PACKAGE_PIN <PIN_NUMBER> IOSTANDARD LVCMOS33 SLEW FAST DRIVE 12} [get_ports {ulpi_data_io[6]}]
#set_property -dict {PACKAGE_PIN <PIN_NUMBER> IOSTANDARD LVCMOS33 SLEW FAST DRIVE 12} [get_ports {ulpi_data_io[7]}]
#set_property -dict {PACKAGE_PIN <PIN_NUMBER> IOSTANDARD LVCMOS33 SLEW FAST DRIVE 12} [get_ports ulpi_stp]
#set_property -dict {PACKAGE_PIN <PIN_NUMBER> IOSTANDARD LVCMOS33 SLEW FAST DRIVE 12} [get_ports ulpi_reset]
#set_property -dict {PACKAGE_PIN <PIN_NUMBER> IOSTANDARD LVCMOS33} [get_ports ulpi_dir]
#set_property -dict {PACKAGE_PIN <PIN_NUMBER> IOSTANDARD LVCMOS33} [get_ports ulpi_nxt]
#set_property -dict {PACKAGE_PIN <PIN_NUMBER> IOSTANDARD LVCMOS33} [get_ports ulpi_clk]
#
#create_clock -period 16.666 -name ulpi_clk60 [get_ports ulpi_clk]