# Clock signal
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports clk]

#7 segment display
set_property PACKAGE_PIN W7 [get_ports {display[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {display[0]}]
set_property PACKAGE_PIN W6 [get_ports {display[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {display[1]}]
set_property PACKAGE_PIN U8 [get_ports {display[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {display[2]}]
set_property PACKAGE_PIN V8 [get_ports {display[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {display[3]}]
set_property PACKAGE_PIN U5 [get_ports {display[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {display[4]}]
set_property PACKAGE_PIN V5 [get_ports {display[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {display[5]}]
set_property PACKAGE_PIN U7 [get_ports {display[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {display[6]}]

#set_property PACKAGE_PIN V7 [get_ports dp]
#set_property IOSTANDARD LVCMOS33 [get_ports dp]

set_property PACKAGE_PIN U2 [get_ports {digit[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {digit[0]}]
set_property PACKAGE_PIN U4 [get_ports {digit[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {digit[1]}]
set_property PACKAGE_PIN V4 [get_ports {digit[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {digit[2]}]
set_property PACKAGE_PIN W4 [get_ports {digit[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {digit[3]}]


#Buttons
set_property PACKAGE_PIN U18 [get_ports rst]
set_property IOSTANDARD LVCMOS33 [get_ports rst]

#USB HID (PS/2)
set_property PACKAGE_PIN C17 [get_ports PS2_CLK]
set_property IOSTANDARD LVCMOS33 [get_ports PS2_CLK]
set_property PULLUP true [get_ports PS2_CLK]
set_property PACKAGE_PIN B17 [get_ports PS2_DATA]
set_property IOSTANDARD LVCMOS33 [get_ports PS2_DATA]
set_property PULLUP true [get_ports PS2_DATA]


set_property PACKAGE_PIN U16 [get_ports pulse_been_ready]
set_property IOSTANDARD LVCMOS33 [get_ports pulse_been_ready]

set_property IOSTANDARD LVCMOS33 [get_ports {ascii[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ascii[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ascii[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ascii[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ascii[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ascii[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ascii[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ascii[0]}]
set_property PACKAGE_PIN L1 [get_ports {ascii[7]}]
set_property PACKAGE_PIN P1 [get_ports {ascii[6]}]
set_property PACKAGE_PIN N3 [get_ports {ascii[5]}]
set_property PACKAGE_PIN P3 [get_ports {ascii[4]}]
set_property PACKAGE_PIN U3 [get_ports {ascii[3]}]
set_property PACKAGE_PIN W3 [get_ports {ascii[2]}]
set_property PACKAGE_PIN V3 [get_ports {ascii[1]}]
set_property PACKAGE_PIN V13 [get_ports {ascii[0]}]
