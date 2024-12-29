# Cellular Automaton FPGA
This project implements a configurable FPGA-accelerated Cellular Automaton.
The user can preconfigure the size, transition function and a few other parameters of the Automaton using a python script.
Each Cell of the Automaton is then implemented in the FPGA's logic and runs in parallel with the other ones.
After being loaded to the FPGA, the Automaton can be controlled and analyzed through a Wishbone bus connected to a UART interface.
The target device of the project is [FPGA board CYC1000](https://wiki.trenz-electronic.de/display/PD/TEI0003+Getting+Started) by Trenz Electronic.

## Top level diagram
```
         +----+----+
UART <---| UART2WB |
PORT --->| MASTER  |
         +---------+
              ↕
      +=======+======+ WISHBONE BUS
      ↕              ↕
+-----+-----+   +----+----+
| CELLULAR  |   | SYSTEM  |
| AUTOMATON |   | MODULE  |
+-----------+   +---------+
      ↓
     LEDs
```
## Main modules description

* UART2WB MASTER - Transmits the Wishbone requests and responses via UART interface (Wishbone bus master module).
* SYSTEM MODULE - Basic system control and status registers (version, debug space etc.) accessible via Wishbone bus.
* CELLULAR AUTOMATON - The automaton itself.

## Cell architecture

The original intention was to utilize the FPGA logic resources as much as possible by mapping each cell's transition function directly to VHDL.
This way, the Automaton was able to calculate new generation in every clock cycle.
However, this had a drastic effect on the design's complexity.
When attempting to create a Cellular Automaton with 3-bit state and 9-connected neighbouring, the generated VHDL package with the transition function had over 800 MB and could not be synthesized in Quartus due to lack of RAM space.

For this reason the project instead implements the Cell's transition function using an N-way associative memory, which only contains transition rules explicitely given by the user's configuration.
All other rules are implicitly set to 'no state change'.
The downside of this solution is, that each generation requires multiple-cycle comparison of the associative memory with the current input vector.
The total number of cycles needed for each transition is dependent on the number of explicit rules given by the user and the number N of parallel ways of the associative memory.
This number is given as parameter to the configuration script and allows for variable trade-off between the Automaton speed and resource consumption.
Higher values of N lead to higher number of input vector comparison blocks in each Cell, but also lower number of cycles needed to compare all the rules.

## Resource usage summary

Automat configuration | LUT | FF | Fmax
:---:|:---:|:---:|:---:
GoF_10x6_4 | 2377 | 625 | 105.9 MHz
GoF_20x12_4 | 2209 | 625 | 81.3 MHz
GoF_10x6_8 | 3791 | 655 | 96.3 MHz
Test_Glider4_12x8_4 | 1211 | 549 | 108.8 MHz
Test_Glider8_12x8_4 | 2355 | 659 | 80.4 MHz

*Implementation was performed using Quartus Prime Lite Edition 18.1.0 for FPGA Intel Cyclone 10 LP 10CL025YU256C8G.*

# Configurations description:

* GoF_10x6_4 - Game of Life (228 explicit rules; 9-connected neighbouring; 1-bit state). Automaton size 10x6. 4-way associative ROM. 60 cycles per generation.
* GoF_20x12_4 - Game of Life. Automaton size 20x12.
* GoF_10x6_8 - Game of Life. 8-way associative ROM. 32 cycles per generation.
* Test_Glider4_12x8_4 - Testing Glider 4 (7 explicit rules, 5-connected neighbouring; 2-bit state). Automaton size 12x8. 4-way associative ROM. 5 cycles per generation.
* Test_Glider8_12x8_4 - Testing Glider 8 (25 explicit rules, 9-connected neighbouring; 3-bit state). Automaton size 12x8. 4-way associative ROM. 10 cycles per generation.

# CYC1000 top limit CA configuration

The project also contains a few example configurations using the [Conway's Game of Life](https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life) rules to test the CYC1000 FPGA limitations.
These designs were tested on 50 MHz frequency.

CA size | Parallel ROM ways | FPFA resources usage [%] | Computation speed [generations per second]
:---:|:---:|:---:|:---:
50x50 | 1 | ~95 | ~220 000
32x32 | 7 | ~98 | ~1 380 000
16x16 | 16 | ~99 | ~2 470 000

## Address space
```
0xOOOO - 0x7FFF -- System module
0x8000 -- Automaton - Control (start / stop / reset) register
0x8001 -- Automaton - Generations limit register
0x8001 -- Automaton - Generations limit register
0x8000 -- Automaton - Control Register (R/W)
                      Write 0 to Stop
                      Write 1 to Start/Resume
                      Write 2 to Reset and Stop
0x8001 -- Automaton - Generations Limit Register (R/W)
                      Write number of generations to count (Only when stopped)
                      Write 0 for unlimited counting
0x8002 -- Automaton - Current Generation Register (R/-)
                      Index of generation after last Control Register Reset
                      Might overflow when Generations Limit is set to 0
0x0003 -- Automaton - Configured Column Size Register (R/-)
0x0004 -- Automaton - Configured Row Size Register (R/-)
0x8003-0xBFFF -- Automaton - 0xDEADCAFE
0xC000-0xFFFF -- Automaton - Cells' States (R/-)
                             Read current Cell's State (anytime)
                             0xDEADBEEF when out of bounds
```

## Demonstration

A short demonstration video can be found on YouTube [here](https://www.youtube.com/watch?v=hjwHe8eW5a8).

## License
The Cellular Automaton FPGA is available under the MIT license (MIT). Please read [LICENSE file](LICENSE).
Some components used in this project have been adopted from project [RMII Firewall FPGA](https://github.com/jakubcabal/rmii-firewall-fpga) by Jakub Cabal.