set_property IOSTANDARD SSTL18_I [get_ports {tp_rgmii_rxd[*]}]
set_property IOSTANDARD SSTL18_I [get_ports {tp_rgmii_txd[*]}]

## Clock
set_property PACKAGE_PIN U18 [get_ports clk_50M]
set_property IOSTANDARD LVCMOS33 [get_ports clk_50M]
##create_clock -period 20.000 [get_ports clk_50M]

## reset
set_property PACKAGE_PIN T19 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

## Button
set_property PACKAGE_PIN P15 [get_ports phy_id_start]
set_property IOSTANDARD LVCMOS33 [get_ports phy_id_start]

## PHY MDIO
set_property PACKAGE_PIN R17 [get_ports phy_mdc]
set_property IOSTANDARD LVCMOS33 [get_ports phy_mdc]

set_property PACKAGE_PIN R19 [get_ports phy_mdio]
set_property IOSTANDARD LVCMOS33 [get_ports phy_mdio]

set_property PACKAGE_PIN G17 [get_ports rst_out]
set_property IOSTANDARD SSTL18_I [get_ports rst_out]

## RGMII RX
set_property PACKAGE_PIN M15 [get_ports {tp_rgmii_rxd[0]}]
set_property PACKAGE_PIN M17 [get_ports {tp_rgmii_rxd[1]}]
set_property PACKAGE_PIN M14 [get_ports {tp_rgmii_rxd[2]}]
set_property PACKAGE_PIN N16 [get_ports {tp_rgmii_rxd[3]}]

set_property PACKAGE_PIN H16 [get_ports tp_rgmii_rxc]
set_property IOSTANDARD SSTL18_I [get_ports tp_rgmii_rxc]

set_property PACKAGE_PIN M18 [get_ports tp_rgmii_rx_ctl]
set_property IOSTANDARD SSTL18_I [get_ports tp_rgmii_rx_ctl]

## RGMII TX
set_property PACKAGE_PIN J16 [get_ports {tp_rgmii_txd[0]}]
set_property PACKAGE_PIN G18 [get_ports {tp_rgmii_txd[1]}]
set_property PACKAGE_PIN K16 [get_ports {tp_rgmii_txd[2]}]
set_property PACKAGE_PIN J15 [get_ports {tp_rgmii_txd[3]}]

set_property PACKAGE_PIN H17 [get_ports tp_rgmii_txc]
set_property IOSTANDARD SSTL18_I [get_ports tp_rgmii_txc]

set_property PACKAGE_PIN G14 [get_ports tp_rgmii_tx_ctl]
set_property IOSTANDARD SSTL18_I [get_ports tp_rgmii_tx_ctl]












