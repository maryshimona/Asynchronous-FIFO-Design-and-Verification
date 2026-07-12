# Asynchronous-FIFO-Design-and-Verification
Design and verification of an asynchronous FIFO using Verilog HDL with separate read and write clock domains.

## Overview

This project presents the design and verification of an **Asynchronous First-In First-Out (FIFO)** memory using **Verilog HDL**. The FIFO enables reliable data transfer between two independent clock domains, making it a fundamental building block in modern **System-on-Chip (SoC)** and **ASIC/FPGA** designs.

The project focuses on **Clock Domain Crossing (CDC)** techniques using **Gray-code pointer synchronization** and **two-stage flip-flop synchronizers** to minimize metastability issues during cross-domain communication.

---

## Objectives

* Design an asynchronous FIFO capable of operating with independent read and write clocks.
* Implement safe Clock Domain Crossing (CDC) techniques.
* Verify FIFO functionality under various operating conditions.
* Analyze FIFO behavior through simulation using Xilinx Vivado.

---

## Features

* Independent read and write clock domains
* Parameterized FIFO design
* Full and Empty flag generation
* Overflow protection
* Underflow protection
* Gray-code read and write pointers
* Two-stage synchronizers for metastability reduction
* Active-low asynchronous reset
* Extra pointer bit for Full/Empty distinction
* Self-checking verification environment

---

## FIFO Specifications

| Parameter     | Value                   |
| ------------- | ----------------------- |
| Data Width    | 8 bits                  |
| Address Width | 4 bits                  |
| FIFO Depth    | 16 Entries              |
| Read Clock    | ~77 MHz (13 ns)         |
| Write Clock   | 100 MHz (10 ns)         |
| Reset Type    | Active-Low Asynchronous |
| Design Style  | Parameterized           |

---

## Design Architecture

The asynchronous FIFO consists of six major modules:

### 1. async_fifo

Top-level module integrating all FIFO components.

### 2. fifo_mem

Dual-port FIFO memory implementing synchronous write and asynchronous read operations.

### 3. wptr_full

Write pointer generation and FULL flag logic using binary and Gray-code pointers.

### 4. rptr_empty

Read pointer generation and EMPTY flag logic.

### 5. sync_r2w

Two-flip-flop synchronizer transferring read pointer information into the write clock domain.

### 6. sync_w2r

Two-flip-flop synchronizer transferring write pointer information into the read clock domain.

---

## Clock Domain Crossing Technique

To ensure reliable communication between asynchronous clock domains, the design employs:

* Gray-code pointer conversion
* Two-stage flip-flop synchronizers
* Pointer synchronization across domains
* Metastability mitigation techniques

This methodology significantly reduces synchronization errors and ensures robust FIFO operation.

---

## Project Structure

```text
Asynchronous-FIFO-Design-and-Verification
│
├── rtl/
│   └── async_fifo.v
│
├── testbench/
│   └── tb_async_fifo.v
│
├── images/
│   ├── synthesis_design.png
│   ├── implementation_design.png
│   ├── simulation_results.png
│   └── results.png
│
├── README.md
└── LICENSE
```

---

## Tools Used

* Verilog HDL
* Xilinx Vivado 2025.2
* XSim Simulator

---

## Verification Environment

A self-checking testbench was developed to validate FIFO functionality.

### Test Cases Executed

| Test Case | Description                   | Status |
| --------- | ----------------------------- | ------ |
| TC0       | Reset Verification            | ✅ PASS |
| TC1       | Sequential Write and Read     | ✅ PASS |
| TC2       | FIFO Full Condition           | ✅ PASS |
| TC3       | Write While Full              | ✅ PASS |
| TC4       | FIFO Empty Condition          | ✅ PASS |
| TC5       | Read While Empty              | ✅ PASS |
| TC6       | Simultaneous Read and Write   | ✅ PASS |
| TC7       | Back-to-Back Burst Operations | ✅ PASS |
| TC8       | Mid-Operation Reset Recovery  | ✅ PASS |

### Final Result

```text
pass_count = 8
fail_count = 0
```

---

## Simulation Setup

* Simulation Time: ~50 µs
* Write Clock Frequency: 100 MHz
* Read Clock Frequency: ~77 MHz
* Independent asynchronous clock domains intentionally chosen to validate CDC behavior.

---

## RTL Synthesis Design

![Synthesis Design](images/synthesis_design.png)

---

## Implementation Design

![Implementation Design](images/implementation_design.png)

---

## Simulation Results

![Simulation Results](images/simulation_results.png)

---

## Test Results

![Results](images/results.png)

---

## Key Learning Outcomes

* Verilog RTL Design Methodology
* Clock Domain Crossing (CDC)
* Gray-Code Synchronization
* Metastability Prevention Techniques
* Self-Checking Testbench Development
* FPGA Design Flow using Vivado

---

## Future Improvements

* FPGA hardware implementation on Basys-3 or Artix-7 boards
* Support for programmable FIFO thresholds
* Error detection and reporting mechanisms
* UVM-based verification environment
* Formal verification of CDC properties

---

## Author

**Mary Shimona**
Electronics Engineering (VLSI Design and Technology)
IIT Madras BS in Data Science and Applications
