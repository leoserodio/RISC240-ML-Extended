RISC240-ML

An extension of the Carnegie Mellon RISC240 processor with custom vector and machine learning instructions. The project adds a small SIMD execution unit, vector register file, dot-product hardware, and a complete software verification flow before FPGA deployment.

Features
16-bit RISC240 CPU
8 × 64-bit vector register file
Custom vector instruction set
VADD
VMUL
VRELU
VDOT
VLD
VST
VACLR
Dot-product accumulator
Custom assembler supporting scalar and vector instructions
Python instruction-level simulator
Automated RTL regression testing using VCS
FPGA-ready design for the Digilent Nexys A7
Project Structure
assembler/
    MLASM.py
    MLSIM.py
    tests/

rtl/
    controlpath.sv
    datapath.sv
    alu.sv
    ML_alu.sv
    vector_regfile.sv
    accumulator.sv
    memory.sv
    RISC240.sv
    ...

verification/
    risc240_tb.sv
    run_tests.py
    expected_results.json
Verification Flow

The verification flow uses three stages:

Assemble an assembly program into machine code (.hex)
Execute the RTL using Synopsys VCS
Compare the final architectural state against expected results
Assembly Program
        │
        ▼
     MLASM.py
        │
        ▼
     memory.hex
        │
        ▼
   VCS + RTL Simulation
        │
        ▼
  risc240_tb.sv
        │
        ▼
 rtl_state.txt
        │
        ▼
 expected_results.json
        │
        ▼
     PASS / FAIL

The regression framework automatically verifies:

General-purpose registers
Vector registers
Accumulator
Memory (when required)
Processor status after program execution
Running the Verification Suite

From the verification directory:

python3 run_tests.py

A successful run reports:

Passed: 18
Failed: 0
Total : 18
FPGA Deployment

Assembly programs are assembled into both:

.hex for RTL simulation
.coe for Vivado Block Memory initialization

The same programs used during simulation can therefore be executed on the FPGA without modification.

Future Improvements
Additional vector instructions
Matrix multiplication support
Quantized neural network kernels
Larger vector register file
Performance benchmarking
Expanded regression suite
Author

Leonardo Serodio
