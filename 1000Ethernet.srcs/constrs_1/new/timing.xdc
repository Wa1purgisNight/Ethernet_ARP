create_generated_clock -name clk_mdc -source [get_pins u_clk_wiz/inst/clk_out1] -divide_by 40 -add -master_clock clk_out1_clk_wiz_0 [get_ports *mdc*]
set_output_delay -clock [get_clocks clk_mdc] -max -add_delay 10.000 [get_ports -filter { NAME =~  "*mdio*" && DIRECTION == "INOUT" }]
set_output_delay -clock [get_clocks clk_mdc] -min -add_delay -10.000 [get_ports -filter { NAME =~  "*mdio*" && DIRECTION == "INOUT" }]
set_input_delay -clock [get_clocks clk_mdc] -max -add_delay 300.000 [get_ports -filter { NAME =~  "*mdio*" && DIRECTION == "INOUT" }]
set_input_delay -clock [get_clocks clk_mdc] -min -add_delay 0.000 [get_ports -filter { NAME =~  "*mdio*" && DIRECTION == "INOUT" }]

set_multicycle_path -setup -end -from [get_clocks clk_mdc] -to [get_clocks -of_objects [get_pins u_clk_wiz/inst/plle2_adv_inst/CLKOUT0]] 40
set_multicycle_path -hold -end -from [get_clocks clk_mdc] -to [get_clocks -of_objects [get_pins u_clk_wiz/inst/plle2_adv_inst/CLKOUT0]] 39
set_multicycle_path -setup -start -from [get_clocks -of_objects [get_pins u_clk_wiz/inst/plle2_adv_inst/CLKOUT0]] -to [get_clocks clk_mdc] 40
set_multicycle_path -hold -start -from [get_clocks -of_objects [get_pins u_clk_wiz/inst/plle2_adv_inst/CLKOUT0]] -to [get_clocks clk_mdc] 39
set _xlnx_shared_i0 [all_registers]
set_false_path -from [get_ports *start*] -to $_xlnx_shared_i0
set_false_path -from [get_ports rst_n] -to $_xlnx_shared_i0
set_false_path -to [get_ports rst_out]



set_property PHASESHIFT_MODE LATENCY [get_cells u_clk_wiz/inst/plle2_adv_inst]
set_property PHASESHIFT_MODE LATENCY [get_cells u_clk_wiz_1/inst/plle2_adv_inst]

set_input_delay -clock [get_clocks tp_rgmii_rxc] -max -add_delay -1.500 [get_ports {tp_rgmii_rx_ctl {tp_rgmii_rxd[0]} {tp_rgmii_rxd[1]} {tp_rgmii_rxd[2]} {tp_rgmii_rxd[3]}}]
set_input_delay -clock [get_clocks tp_rgmii_rxc] -clock_fall -max -add_delay -1.500 [get_ports {tp_rgmii_rx_ctl {tp_rgmii_rxd[0]} {tp_rgmii_rxd[1]} {tp_rgmii_rxd[2]} {tp_rgmii_rxd[3]}}]
set_input_delay -clock [get_clocks tp_rgmii_rxc] -min -add_delay -2.500 [get_ports {tp_rgmii_rx_ctl {tp_rgmii_rxd[0]} {tp_rgmii_rxd[1]} {tp_rgmii_rxd[2]} {tp_rgmii_rxd[3]}}]
set_input_delay -clock [get_clocks tp_rgmii_rxc] -clock_fall -min -add_delay -2.500 [get_ports {tp_rgmii_rx_ctl {tp_rgmii_rxd[0]} {tp_rgmii_rxd[1]} {tp_rgmii_rxd[2]} {tp_rgmii_rxd[3]}}]



set_false_path -setup -fall_from [get_clocks tp_rgmii_rxc] -fall_to [get_clocks tp_rgmii_rxc]
set_false_path -setup -rise_from [get_clocks tp_rgmii_rxc] -rise_to [get_clocks tp_rgmii_rxc]
set_false_path -hold -rise_from [get_clocks tp_rgmii_rxc] -fall_to [get_clocks tp_rgmii_rxc]
set_false_path -hold -fall_from [get_clocks tp_rgmii_rxc] -rise_to [get_clocks tp_rgmii_rxc]


















set_false_path -from [get_clocks -of_objects [get_pins u_clk_wiz/inst/plle2_adv_inst/CLKOUT1]] -to [get_clocks -of_objects [get_pins u_clk_wiz_1/inst/plle2_adv_inst/CLKOUT0]]
set_false_path -from [get_clocks -of_objects [get_pins u_clk_wiz_1/inst/plle2_adv_inst/CLKOUT0]] -to [get_clocks -of_objects [get_pins u_clk_wiz/inst/plle2_adv_inst/CLKOUT1]]



set_multicycle_path -setup -from [get_pins u_mdio_master/mdio_oe_reg/C] -to [get_pins u_mdio_master/mdio_oe_reg/D] 40
set_multicycle_path -hold -from [get_pins u_mdio_master/mdio_oe_reg/C] -to [get_pins u_mdio_master/mdio_oe_reg/D] 39






create_generated_clock -name tp_rgmii_txc -source [get_pins u_rgmii_tx/u_oddr_txc/C] -multiply_by 1 [get_ports tp_rgmii_txc]
set_output_delay -clock [get_clocks tp_rgmii_txc] -max -add_delay 0.500 [get_ports {tp_rgmii_tx_ctl {tp_rgmii_txd[0]} {tp_rgmii_txd[1]} {tp_rgmii_txd[2]} {tp_rgmii_txd[3]}}]
set_output_delay -clock [get_clocks tp_rgmii_txc] -clock_fall -max -add_delay 0.500 [get_ports {tp_rgmii_tx_ctl {tp_rgmii_txd[0]} {tp_rgmii_txd[1]} {tp_rgmii_txd[2]} {tp_rgmii_txd[3]}}]
set_output_delay -clock [get_clocks tp_rgmii_txc] -min -add_delay -0.500 [get_ports {tp_rgmii_tx_ctl {tp_rgmii_txd[0]} {tp_rgmii_txd[1]} {tp_rgmii_txd[2]} {tp_rgmii_txd[3]}}]
set_output_delay -clock [get_clocks tp_rgmii_txc] -clock_fall -min -add_delay -0.500 [get_ports {tp_rgmii_tx_ctl {tp_rgmii_txd[0]} {tp_rgmii_txd[1]} {tp_rgmii_txd[2]} {tp_rgmii_txd[3]}}]
set_false_path -setup -rise_from [get_clocks tp_rgmii_txc] -rise_to [get_clocks tp_rgmii_txc]
set_false_path -setup -fall_from [get_clocks tp_rgmii_txc] -fall_to [get_clocks tp_rgmii_txc]
set_false_path -hold -rise_from [get_clocks tp_rgmii_txc] -fall_to [get_clocks tp_rgmii_txc]
set_false_path -hold -fall_from [get_clocks tp_rgmii_txc] -rise_to [get_clocks tp_rgmii_txc]







