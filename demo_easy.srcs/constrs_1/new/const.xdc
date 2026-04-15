## Clock signal (100 MHz oscillator)
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk }];

## Reset and Start Buttons
## rst_n is mapped to the Left Button (BTNL)
## start_btn is mapped to the Center Button (BTNC)
set_property -dict { PACKAGE_PIN P17   IOSTANDARD LVCMOS33 } [get_ports { rst }];
set_property -dict { PACKAGE_PIN N17   IOSTANDARD LVCMOS33 } [get_ports { start_btn }];

## LEDs
## led_done is mapped to LED 0 (rightmost LED)
set_property -dict { PACKAGE_PIN H17   IOSTANDARD LVCMOS33 } [get_ports { led_done }];

## USB-RS232 Interface
## This pin (D10) connects to the FTDI chip on the board, 
## which sends data over the USB cable to your PC's COM port.
## UART
set_property PACKAGE_PIN C4      [get_ports rx]
set_property IOSTANDARD LVCMOS33 [get_ports rx]
set_property PACKAGE_PIN D4      [get_ports uart_tx_pin]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx_pin]