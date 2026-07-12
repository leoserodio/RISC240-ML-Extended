# RISC240-ML

## Overview

This project extends the Carnegie Mellon University RISC240 processor with custom vector and machine learning instructions. The processor was modified to support SIMD-style execution through a dedicated vector register file, vector ALU, dot-product unit, and accumulator while maintaining compatibility with the original scalar instruction set.

In addition to the hardware modifications, I developed a complete software toolchain for the processor, including a custom assembler, instruction-level simulator, and an automated RTL verification framework using Synopsys VCS. This verification flow allows assembly programs to be assembled, executed on the RTL, and automatically checked against expected architectural state before deploying the design to FPGA.

---

## What I Worked On

The goal of this project was to extend the original RISC240 architecture with machine learning acceleration while developing a complete verification flow to validate the processor before hardware implementation.

### `datapath.sv`

Modified the processor datapath to integrate the custom vector hardware, including:

- Vector register file
- Vector ALU
- Dot-product unit
- Accumulator
- Vector load/store datapaths
- Additional control signals for vector execution

### `controlpath.sv`

Extended the processor control FSM to support the custom vector instruction set by adding:

- Vector arithmetic states
- Vector load/store operations
- Dot-product execution
- Accumulator control
- Additional vector control signals

### `ML_alu.sv`

Implemented a dedicated vector ALU supporting:

- Vector addition
- Vector multiplication
- ReLU activation
- Pass-through operations

### `vector_regfile.sv`

Implemented an 8-entry, 64-bit vector register file providing:

- Two read ports
- One write port
- Parallel vector operand access
- Independent vector register addressing

### `dot_product_unit.sv`

Implemented an 8-lane signed dot-product engine using parallel multipliers with accumulation into a 32-bit result.

### `accumulator.sv`

Implemented a dedicated accumulator used by the dot-product instruction to support machine learning reduction operations.

### `MLASM.py`

Developed a custom assembler supporting both the original RISC240 instruction set and the new vector instructions. The assembler generates:

- `.hex` files for RTL simulation
- `.coe` files for Vivado Block Memory initialization
- Assembly listings
- Symbol tables

### `MLSIM.py`

Implemented an instruction-level simulator capable of executing assembled programs and displaying the processor's architectural state for software debugging.

### `verification/`

Developed an automated RTL verification framework consisting of:

- SystemVerilog testbench
- Python regression runner
- Automated architectural state checking
- 18 assembly test programs covering scalar and vector functionality

---

## Features

- 16-bit RISC240 processor
- 8 × 64-bit vector register file
- Custom SIMD instruction set
- Vector addition
- Vector multiplication
- ReLU activation
- Dot-product instruction with accumulator
- Vector load/store instructions
- Custom assembler
- Instruction-level simulator
- Automated RTL regression testing using Synopsys VCS
- Vivado-compatible memory generation
- FPGA-ready implementation

---

## Verification

The verification framework automatically executes assembly programs on the RTL using Synopsys VCS.

For each test:

1. Assemble the program into machine code.
2. Load the generated memory image into the RTL simulation.
3. Execute the processor until the `STOP` instruction.
4. Capture the final architectural state.
5. Compare register, vector register, accumulator, and memory contents against expected results.

The current regression suite contains **18 automated tests** covering both scalar and vector functionality.

---

## Technologies

- SystemVerilog
- Python
- Synopsys VCS
- Xilinx Vivado
- FPGA Design
- RTL Design
- Processor Design
- Computer Architecture
- SIMD
- Machine Learning Hardware Acceleration

---

## Repository Structure

```text
rtl/
    controlpath.sv
    datapath.sv
    alu.sv
    ML_alu.sv
    vector_regfile.sv
    dot_product_unit.sv
    accumulator.sv
    memory.sv
    RISC240.sv
    ...

assembler/
    MLASM.py
    MLSIM.py
    tests/

verification/
    risc240_tb.sv
    run_tests.py
    expected_results.json
```
