RISC240 VCS RTL REGRESSION SETUP
================================

1. IMPORTANT: simulation mode
-----------------------------

In constants.sv, comment out this line before compiling with VCS:

    `define synthesis

It must look like:

    //`define synthesis

Otherwise RISC240_top will compile its FPGA-board ports and memorySystem will
select the synthesis memory instead of memory_simulation.

2. Recommended project layout
-----------------------------

RISC240GPU/
├── constants.sv
├── library.sv
├── alu.sv
├── regfile.sv
├── adder.sv                (adder module could be inside accumulator if you want)
├── vector_regfile.sv
├── ML_alu.sv
├── dot_product_unit.sv
├── vector_load_unit.sv
├── vector_store_unit.sv
├── accumulator.sv
├── datapath.sv
├── controlpath.sv
├── memory.sv
├── RISC240.sv
├── assembler/
│   └── MLASM.py
├── tests/
│   ├── test01_add.asm
│   ├── ...
│   └── test18_vector_integration.asm
└── verification/
    ├── risc240_tb.sv
    ├── expected_results.json
    └── run_tests.py

3. Copy these generated files
-----------------------------

Put:
    risc240_tb.sv
    expected_results.json
    run_tests.py

inside:
    RISC240GPU/verification/

4. Run on the AFS machine MAKING SURE YOU HAVE ASSEMBLED THE TESTS ON YOUR MACHINE (created .hex)
-------------------------

From the project root:

    cd verification
    python3 run_tests.py --keep-output

After the first compile, future runs can use:

    python3 run_tests.py

Run one test:

    python3 run_tests.py --test test01_add --rebuild --keep-output

Keep logs and state dumps even for passing tests:

    python3 run_tests.py --keep-output

5. How it works
---------------

For each test, run_tests.py:

    - runs MLASM.py on the .asm file
    - copies the generated .hex to build/<test>/memory.hex
    - runs the VCS executable in that directory
    - risc240_tb.sv waits for STOP/STOP1
    - the testbench writes scalar registers, vector registers, ACC, flags,
      and test memory into rtl_state.txt
    - Python compares rtl_state.txt to expected_results.json

6. First run recommendation
---------------------------

Start with:

    python3 run_tests.py --test test01_add --rebuild --keep-output

Then inspect:

    verification/build/test01_add/simulation.log
    verification/build/test01_add/rtl_state.txt

Only after test01 passes should you run the full suite.


AFTER EVERY RTL CHANGE:

cd ~/private/RISC240GPU/verification (or wherever you will run vcs)
python3 run_tests.py
