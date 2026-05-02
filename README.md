# uart-spi-bridge-controller
SystemVerilog implementation of a configurable UART to SPI bridge with automated OVM/OOP-style testbench
# UART-to-SPI Bridge Controller

[![SystemVerilog](https://img.shields.io/badge/Language-SystemVerilog-blue.svg)](https://en.wikipedia.org/wiki/SystemVerilog)
[![Simulation](https://img.shields.io/badge/Tools-ModelSim%20%7C%20Questa-green.svg)](https://www.intel.com/content/www/us/en/software/programmable/quartus-prime/model-sim.html)

## Project Overview
This repository contains a high-performance, configurable **UART-to-SPI Bridge** implemented in SystemVerilog. The module acts as an intermediary, allowing a host (PC via UART) to control and communicate with SPI-based peripherals.

The design is focused on modularity, robust state-machine control, and industry-standard verification practices.

## Key Features
*   **Full-Duplex Communication:** Simultaneous data transmission and reception over SPI.
*   **Dynamic Configuration:** Support for adjustable SPI clock frequency (via clock dividers) and data packet lengths.
*   **Robust FSM Design:** A centralized finite state machine handles command parsing, SPI execution, and UART response (ACK/NACK) generation.
*   **Automated OOP Testbench:** Features a class-based verification environment with:
    *   Constrained randomization of commands.
    *   Scoreboard for automated data integrity checks (MOSI vs Expected).
    *   UART Monitor for response validation.

## Repository Structure
*   `src/` — Synthesizable RTL source files (UART RX/TX, SPI Master, Top Level).
*   `tb/` — SystemVerilog Testbench files and OOP classes.
*   `sim/` — Simulation scripts and TCL macros for ModelSim/QuestaSim.
*   `docs/` — Documentation, command tables, and simulation waveforms.

## Command Protocol
The controller uses a structured packet format: `[CMD] [LEN] [DATA...]`

| CMD Byte | Name | Description |
|:---:|:---|:---|
| **0x01** | **SET_DIV** | Updates the SPI clock divider (1 byte data). |
| **0x02** | **SPI_XFER** | Starts SPI transaction (N bytes data). |
| **0x03** | **CFG_SPI** | Configures SPI Mode (CPOL/CPHA) and bit order. |

## Verification Environment
The design was verified using an automated environment that mimics real-world communication stress-tests.

### Simulation Waveform Example
*(Tip: Add a screenshot of your wave from EDA Playground to the docs/ folder and link it here)*
![SPI Transaction Waveform](docs/waveforms.png)

## How to Run
To run the simulation in a local environment (ModelSim/QuestaSim):

1. Clone the repository.
2. Navigate to the `sim/` directory.
3. Execute the simulation script in your simulator console: do run.do.
Author: [SERGEY AZOV]
Candidate for Intern FPGA Design roles at YADRO.
