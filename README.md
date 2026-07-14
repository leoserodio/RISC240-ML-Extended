# RISC240-ML

This project extends the CMU RISC240 processor by adding a custom vector instruction set for basic machine learning operations. I modified the processor by adding a vector register file, vector ALU, dot-product unit, and accumulator while keeping the original scalar processor working.

To make writing and testing programs easier, I also built a Python assembler and instruction-level simulator based on the concepts behind the `as240` assembler and `sim240` simulator used in CMU's 18-240 course. I used ChatGPT to help implement parts of the Python code while checking everything against the ISA and my test programs throughout development. I also put together an automated verification flow using Synopsys VCS so I could quickly test hardware changes before synthesizing the design.

## Main Changes

### Datapath

Most of the hardware work was done in `datapath.sv`, where I integrated the new vector hardware:

- Vector register file
- Vector ALU
- Dot-product unit
- Accumulator
- New datapaths and control signals for vector execution

### Control Logic

I updated `controlpath.sv` with the additional states and control signals needed for the new instructions, including vector arithmetic, vector load/store operations, and dot-product execution.

### New Hardware Modules

I added several new modules:

- `ML_alu.sv` - vector addition, multiplication, ReLU, and pass-through operations
- `vector_regfile.sv` - 8-entry, 64-bit vector register file
- `dot_product_unit.sv` - parallel dot-product hardware
- `accumulator.sv` - accumulator used by the dot-product instruction

### Assembler and Simulator

I wrote a Python assembler (`MLASM.py`) that supports both the original RISC240 instructions and the new vector instructions. It generates memory files for simulation and Vivado.

I also wrote an instruction-level simulator (`MLSIM.py`) so I could test assembly programs without running RTL every time.

### Verification

To verify the processor, I wrote 18 assembly test programs covering both the original RISC240 instruction set and the new vector instructions. The verification flow automatically assembles each program, loads it into the RTL simulation, runs the processor in Synopsys VCS until the `STOP` instruction, and compares the final architectural state against the expected results.

## Future Work

The next step for this project is to build a small library of complete assembly programs that use the custom vector instruction set. Instead of only testing individual instructions, these programs will implement larger machine learning operations that can be reused as software libraries.

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