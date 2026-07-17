# RISC240-ML

This project extends the Carnegie Mellon RISC240 processor by adding a custom vector instruction set for basic machine learning operations. I modified the processor by adding a vector register file, vector ALU, dot-product unit, and accumulator while keeping the original scalar processor working.

To make writing and testing programs easier, I also built a Python assembler and instruction-level simulator based on the concepts behind the `as240` assembler and `sim240` simulator used in CMU's 18-240 course. I used ChatGPT/Claude to help implement parts of the Python code, making sure I was checking everything against the ISA and my test programs throughout development. I also put together an automated verification flow using Synopsys VCS by having python call VCS on the afs machine and check register states (after a stop instruction) given by the testbench I created and the exepcted register states from a json.

## Main Changes

### Datapath

Most of the hardware work was done in `datapath.sv`, where I integrated the new vector hardware:

- Vector register file
- Vector ALU
- Dot-product unit
- Accumulator
- New datapaths and control signals for vector execution

### MAR & MDR
In addition, because of the RISC240 constraints (16-bit wide MAR and MDR), I had to find clever ways of loading and storing accumulator outputs (32-bit). This was done by inserting a new input to the MAR (via a mux),
which was "MAR + 2" so I was able to store the last 16 bits of the accumulator in the next memory address. 

The MDR input was also changed: I created a 4-input mux that took in a value from either the vector (from vector reg file), The lower 16 bits of the accumulator, the higher 16 bits of the accumulator, or from the normal data bus (as the RISC240 was originally). 

With these changes, I was able to preserve the bit widths of the MAR and MDR while integrating the ML-oriented logic of my new datapath additions. 

### Control Logic

I updated `controlpath.sv` with the additional states and control signals needed for the new instructions, including vector arithmetic, vector load/store operations, and dot-product execution.

### New Hardware Modules

- `ML_alu.sv` - performs vector addition, multiplication, ReLU, and pass-through operations
- `vector_regfile.sv` - 8-entry, 64-bit vector register file
- `vector_load_unit.sv` - loads four consecutive 16-bit memory words into a vector register
- `vector_store_unit.sv` - extracts vector elements for sequential memory stores
- `dot_product_unit.sv` - parallel 4-lane dot-product hardware
- `accumulator.sv` - 32-bit accumulator used by the dot-product instruction
- `int8_mult.sv` - signed 8-bit multiplier used by the dot-product unit
- `adder.sv` - parameterized adder used by the accumulator

### Assembler and Simulator

I wrote a Python assembler (`MLASM.py`) that supports both the original RISC240 instructions and the new vector instructions. It generates memory files for simulation and Vivado.

I also wrote an instruction-level simulator (`MLSIM.py`) so I could test assembly programs without running RTL every time. This will also come in handy when I start to create full ASM programs that execute more complex machine learning operations (such as doing a dot product of values stored in vector registers, accumulating the result, and storing it in memory). 

### Verification

To verify the processor, I wrote 18 assembly test programs covering both the original RISC240 instruction set and the new vector instructions. The verification flow automatically assembles each program, loads it into the RTL simulation, runs the processor in Synopsys VCS until the `STOP` instruction, and compares the final architectural state against the expected results (json). The way we know the current architectural state is by using hierarchal reference (dut.xxx.xxx etc), and comparing this value to the expected results in the json once the 'STOP' instruction is asserted. This is then repeated for all 19 tests (driven by python). 

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
