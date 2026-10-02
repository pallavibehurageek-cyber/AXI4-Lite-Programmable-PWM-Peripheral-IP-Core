AXI4-Lite Programmable PWM Peripheral IP Core

A synthesizable Verilog RTL implementation of a programmable PWM peripheral controlled through an AXI4-Lite memory-mapped interface.

The design integrates an AXI4-Lite slave interface with a configurable PWM engine, automatic breathing mode, status monitoring, and interrupt generation. The project demonstrates the implementation and verification of a custom memory-mapped hardware IP block at RTL level.

Overview

The AXI4-Lite Programmable PWM Peripheral IP Core is designed as a reusable hardware peripheral that can be controlled by an AXI4-Lite master.

Configuration values are written to memory-mapped registers through AXI4-Lite transactions. The PWM datapath then generates the corresponding output waveform.

The design demonstrates the complete path from:

AXI4-Lite Transaction
        ↓
Register Interface
        ↓
Control / Configuration
        ↓
PWM Processing Engine
        ↓
Programmable PWM Output
        ↓
Status / Interrupt

Key Features

- Synthesizable Verilog RTL
- AXI4-Lite slave interface
- AW, W, B, AR and R channel support
- Explicit FSM-based read and write transaction handling
- Memory-mapped register architecture
- Byte-strobe ("WSTRB") aware register writes
- Programmable PWM duty cycle
- Configurable PWM period
- Fixed-duty-cycle operating mode
- Automatic breathing-mode operation
- Automatic duty-cycle ramping
- Sticky overflow status flag
- Write-1-to-clear status mechanism
- Level-triggered "PWM_IRQ" output
- Self-checking RTL testbench
- Simulation waveform analysis

Architecture

                     AXI4-Lite Master
                            │
             ┌──────────────▼──────────────┐
             │      AXI4-Lite Slave        │
             │                              │
             │  Write FSM   │   Read FSM   │
             │              │               │
             └──────────────┬──────────────┘
                            │
                            ▼
                  ┌───────────────────┐
                  │ Control / Status  │
                  │    Registers      │
                  └─────────┬─────────┘
                            │
                            ▼
                  ┌───────────────────┐
                  │    PWM Engine     │
                  │                   │
                  │  Fixed Mode       │
                  │  Breathing Mode   │
                  └─────────┬─────────┘
                            │
                            ▼
                       PWM Output
                            │
                            └──────► PWM_IRQ

AXI4-Lite Interface

The peripheral implements the five fundamental AXI4-Lite channels:

Channel| Function
"AW"| Write address
"W"| Write data
"B"| Write response
"AR"| Read address
"R"| Read data

The write and read paths use explicit finite-state-machine control to manage the corresponding AXI4-Lite transactions.

Byte-enable information is handled through "WSTRB", allowing individual bytes of a register to be selectively written.

Register Map

Address| Register| Bits| Description
"0x0"| "CONTROL"| "[0]"| PWM enable
"0x0"| "CONTROL"| "[1]"| Operating mode
"0x4"| "DUTY"| "[7:0]"| PWM duty-cycle value
"0x8"| "STATUS"| "[0]"| Busy/status indication
"0x8"| "STATUS"| "[1]"| Overflow flag
"0xC"| "PERIOD"| "[15:0]"| PWM period in clock cycles

CONTROL — "0x0"

Bit 0 → PWM Enable
Bit 1 → Mode Select

Mode selection:

0 → Fixed PWM
1 → Breathing PWM

DUTY — "0x4"

The 8-bit duty-cycle register controls the PWM output level.

0   → Minimum duty
255 → Maximum duty

STATUS — "0x8"

Bit 0 → Busy / status indication
Bit 1 → Overflow flag

The overflow indication is implemented as a sticky status condition and supports write-1-to-clear behavior.

PERIOD — "0xC"

The 16-bit period register determines the PWM period in clock cycles.

Changing the period modifies the PWM timing, while the duty-cycle register controls the proportion of the period during which the output remains active.

PWM Operation

PWM generates a periodic digital waveform by comparing a counter against the programmed duty-cycle value.

        One PWM Period
<────────────────────────>

HIGH    ┌──────────┐
        │          │
────────┘          └────────────

        ← Duty →

The duty cycle determines the average ON time of the output.

Fixed Mode

In fixed mode, the programmed duty-cycle value remains constant.

    ┌───────┐       ┌───────┐
    │       │       │       │
────┘       └───────┘       └────

Breathing Mode

In breathing mode, the duty cycle automatically changes over time.

Duty
100%                 /\
                    /  \
                   /    \
                  /      \
                 /        \
0%  ____________/          \________
                         Time

This produces a gradual fade-in/fade-out effect without requiring continuous software updates.

Interrupt Generation

The peripheral provides a "PWM_IRQ" output associated with the controller's status condition.

The status register allows the controlling system to observe the corresponding condition.

PWM Event
    │
    ▼
Status Flag
    │
    ▼
 PWM_IRQ

Verification

A dedicated self-checking testbench is included to verify the RTL implementation.

The verification environment exercises the peripheral through AXI4-Lite transactions and observes the resulting register and PWM behavior.

The testbench covers:

- Reset operation
- AXI4-Lite write transactions
- AXI4-Lite read transactions
- Register programming
- PWM enable/disable
- Duty-cycle configuration
- PWM period configuration
- Fixed PWM operation
- Breathing-mode operation
- Status behavior
- Interrupt behavior
- PWM waveform generation

Simulation Flow

                 Reset
                   │
                   ▼
          Configure CONTROL
                   │
                   ▼
           Configure PERIOD
                   │
                   ▼
             Configure DUTY
                   │
                   ▼
              Enable PWM
                   │
          ┌────────┴────────┐
          ▼                 ▼
      Fixed Mode       Breathing Mode
          │                 │
          ▼                 ▼
   Constant Duty      Duty Ramping
          │                 │
          └────────┬────────┘
                   ▼
             Status Logic
                   │
                   ▼
                PWM_IRQ

Simulation Waveforms

The repository contains waveform captures from RTL simulation.

AXI4-Lite PWM Transactions

"AXI4-Lite PWM Transactions" (pwm_transaction_waveforms.png)

Complete PWM Peripheral Simulation

"Complete PWM Peripheral Simulation" (pwm_peripheral_simulation.png)

The waveforms provide visual evidence of the AXI4-Lite transactions, register activity, and generated PWM behavior.

Project Structure

AXI4-Lite-Programmable-PWM-Peripheral-IP/
│
├── axi_pwm_peripheral.v
├── tb_axi_pwm_peripheral.v
├── pwm_transaction_waveforms.png
├── pwm_peripheral_simulation.png
└── README.md

RTL Design

"axi_pwm_peripheral.v"

Main synthesizable RTL module containing:

- AXI4-Lite slave interface
- Read/write FSMs
- Memory-mapped registers
- PWM generation
- Breathing-mode control
- Status logic
- Interrupt generation

"tb_axi_pwm_peripheral.v"

Self-checking simulation testbench responsible for:

- Generating clock and reset
- Driving AXI4-Lite transactions
- Programming peripheral registers
- Checking peripheral behavior
- Capturing simulation waveforms

"pwm_transaction_waveforms.png"

Waveform capture demonstrating AXI4-Lite transactions and associated PWM activity.

"pwm_peripheral_simulation.png"

Extended waveform capture showing the overall simulated peripheral behavior.

Tools Used

- Verilog HDL
- Icarus Verilog
- GTKWave

Design Concepts Demonstrated

This project demonstrates practical experience with:

- AXI4-Lite protocol
- RTL finite-state-machine design
- Memory-mapped hardware peripherals
- Register-transfer-level design
- PWM generation
- Configurable digital hardware
- Byte-strobe handling
- Status-register design
- Interrupt generation
- Self-checking verification
- RTL simulation
- Waveform debugging

Potential Extensions

The IP can be extended with:

- Multiple independent PWM channels
- Configurable PWM prescaler
- Programmable breathing rate
- Additional status registers
- Multiple interrupt sources
- Software-controlled fade profiles
- FPGA hardware validation
- Integration with a RISC-V or ARM-based SoC

Author

Pallavi Behura

Electronics & Communication Engineering

Focus Areas: RTL Design | Digital Hardware | Embedded Systems | RF & Antenna Engineering