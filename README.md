# RISC240-ML

This project extends the CMU RISC240 processor with custom vector instructions for simple machine learning operations. The processor was modified to support SIMD-style execution by adding a vector register file, vector ALU, dot-product unit, and accumulator while keeping the original scalar instruction set intact.

To make it easier to develop and test new instructions, I also built a custom assembler and instruction-level simulator in Python based on the concepts of the `as240` assembler and `sim240` simulator used in CMU's 18-240 course. I used ChatGPT to help implement parts of the Python code while verifying the assembler and simulator throughout development. The project also includes an automated RTL verification flow using Synopsys VCS.

## My Contributions

The focus of this project was extending the RISC240 architecture with vector hardware and creating a workflow for writing, testing, and verifying new instructions before running them on the FPGA.

### `datapath.sv`

Modified the processor datapath to add:

- Vector register file
- Vector ALU
- Dot-product unit
- Accumulator
- Additional datapaths and control signals for vector execution

### `controlpath.sv`

Extended the control FSM to support the new instruction set by adding states for:

- Vector arithmetic
- Vector load and store operations
- Dot-product execution
- Accumulator control

### `ML_alu.sv`

Implemented a vector ALU supporting:

- Vector addition
- Vector multiplication
- ReLU activation
- Pass-through operations

### `vector_regfile.sv`

Designed an 8-entry, 64-bit vector register file with two read ports and one write port for parallel operand access.

### `dot_product_unit.sv`

Implemented an 8-lane signed dot-product unit that performs parallel multiplication and accumulates the result.

### `accumulator.sv`

Added an accumulator used by the dot-product instruction.

### `MLASM.py`

Built a Python assembler based on the ideas behind CMU's `as240` assembler. It supports both the original RISC240 instructions and the custom vector instructions, generating memory images for simulation and FPGA synthesis.

### `MLSIM.py`

Built an instruction-level simulator, inspired by CMU's `sim240`, to execute assembled programs and inspect the processor state during software development.

### `verification/`

Created an automated verification flow that:

- Assembles test programs
- Runs RTL simulations using Synopsys VCS
- Compares the final processor state against expected results

The current test suite contains 18 assembly programs covering both the original processor and the new vector instructions.

## Results

- Extended the RISC240 processor with custom SIMD instructions
- Added vector arithmetic and dot-product hardware
- Built a custom assembler and instruction-level simulator
- Automated RTL verification using Synopsys VCS
- Successfully synthesized the design for FPGA implementation

## Tools Used

- SystemVerilog
- Python
- Synopsys VCS
- Xilinx Vivado
- FPGA Design
- RTL Design
- Computer Architecture

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