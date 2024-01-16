# BestIDE - A Hardware Design Project

This is the best human-friendly IDE (Integrated development harDware Equipment) for Python,  built for Basys 3 FPGA board.

The details of the CNN-based handwriting recognition model is at [Dogeon188/HandwritingRecognizeUnipen](https://github.com/Dogeon188/HandwritingRecognizeUnipen)

## Features

- Write your code with only you mouse (and some buttons)!
- Free you hands from keyboard!
- No more **typos**! (because you don't need to type anymore)

For more information, please refer to the [report](doc/report.pdf).

## How To Use

### Hardware Requirements

- A Basys 3 FPGA board
- A USB mouse
- A VGA monitor
- A Micro USB cable

### Software Requirements

- Python 3.12
  - PySerial
  - termcolor
  - Pygments

### Installation

1. Install Vivado 2020.2 or higher version
2. *[Optional]* Use Vivado to generate a bitstream file for the Basys 3 board. You can also use the bitstream file provided at [impl/top.bit](impl/top.bit)
3. Program the bitstream file to the Basys 3 board
4. Connect the Basys 3 board to your computer with the Micro USB cable
5. Connect the VGA monitor and the USB mouse to the Basys 3 board
6. Install the required Python packages
7. Run `python3 script/com.py` to start the IDE
