MLASM + MLSIM AUTOMATED TEST RUNNER

SETUP
-----
Put these files/folders together:

    MLASM.py
    MLSIM.py
    verify_all_tests.py
    run_all_tests.ps1
    run_all_tests.bat
    run_quick_program.ps1
    tests/

RUN ALL TESTS
-------------
PowerShell:

    .\run_all_tests.ps1

If PowerShell blocks scripts:

    powershell -ExecutionPolicy Bypass -File .\run_all_tests.ps1

Command Prompt:

    run_all_tests.bat

Direct Python:

    python verify_all_tests.py

A successful result ends with:

    Passed: 18
    Failed: 0
    Total : 18

RUN THE QUICK PROGRAM
---------------------

    .\run_quick_program.ps1

Or manually:

    python MLASM.py tests\quick_program.asm
    python MLSIM.py tests\quick_program.hex

Inside MLSIM:

    run
    vregs 3
    mem $0110 4

Expected quick-program result:

    V3 bytes = 03 02 05 04 07 06 09 08
    memory:
        $0110 = $0203
        $0112 = $0405
        $0114 = $0607
        $0116 = $0809
