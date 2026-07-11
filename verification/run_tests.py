#!/usr/bin/env python3
"""
run_tests.py

Python 3.6-compatible VCS regression driver for the current RISC240GPU layout.

This version DOES NOT run MLASM.py on AFS.
It uses the existing .hex files already present beside each .asm test.

Expected layout:

RISC240GPU/
├── assembler/
│   └── tests/
│       ├── test01_add.asm
│       ├── test01_add.hex
│       ├── test02_sub.asm
│       ├── test02_sub.hex
│       └── ...
├── rtl/
│   ├── constants.sv
│   ├── library.sv
│   ├── adder.sv
│   ├── alu.sv
│   ├── regfile.sv
│   ├── vector_regfile.sv
│   ├── ML_alu.sv
│   ├── dot_product_unit.sv
│   ├── vector_load_unit.sv
│   ├── vector_store_unit.sv
│   ├── accumulator.sv
│   ├── datapath.sv
│   ├── controlpath.sv
│   ├── memory.sv
│   └── RISC240.sv
└── verification/
    ├── risc240_tb.sv
    ├── expected_results.json
    └── run_tests.py
"""

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Tuple


SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent

RTL_DIR = PROJECT_ROOT / "rtl"
DEFAULT_TEST_DIR = PROJECT_ROOT / "assembler" / "tests"

EXPECTED_FILE = SCRIPT_DIR / "expected_results.json"
TB_FILE = SCRIPT_DIR / "risc240_tb.sv"

BUILD_DIR = SCRIPT_DIR / "build"
SIMV = BUILD_DIR / "simv"


RTL_FILES = [
    "constants.sv",
    "library.sv",
    "adder.sv",
    "alu.sv",
    "regfile.sv",
    "vector_regfile.sv",
    "ML_alu.sv",
    "dot_product_unit.sv",
    "vector_load_unit.sv",
    "vector_store_unit.sv",
    "accumulator.sv",
    "datapath.sv",
    "controlpath.sv",
    "memory.sv",
    "RISC240.sv",
]


class RegressionError(Exception):
    pass


def run_command(command, cwd, description):
    # type: (List[str], Path, str) -> subprocess.CompletedProcess
    result = subprocess.run(
        command,
        cwd=str(cwd),
        universal_newlines=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )

    if result.returncode != 0:
        raise RegressionError(
            "{} failed with exit code {}\n{}".format(
                description,
                result.returncode,
                result.stdout or "",
            )
        )

    return result


def check_inputs(test_dir):
    # type: (Path) -> None
    missing = []

    if not test_dir.exists():
        missing.append(str(test_dir))

    if not TB_FILE.exists():
        missing.append(str(TB_FILE))

    if not EXPECTED_FILE.exists():
        missing.append(str(EXPECTED_FILE))

    for filename in RTL_FILES:
        path = RTL_DIR / filename

        if not path.exists():
            missing.append(str(path))

    if missing:
        raise RegressionError(
            "Missing required files:\n  {}".format(
                "\n  ".join(missing)
            )
        )


def compile_rtl(force=False):
    # type: (bool) -> None
    BUILD_DIR.mkdir(parents=True, exist_ok=True)

    if SIMV.exists() and not force:
        print("Using existing VCS build: {}".format(SIMV))
        return

    sources = [
        str(RTL_DIR / filename)
        for filename in RTL_FILES
    ]
    sources.append(str(TB_FILE))

    command = [
        "vcs",
        "-full64",
        "-sverilog",
        "-timescale=1ns/1ps",
        "+v2k",
        "+incdir+{}".format(RTL_DIR),
        "-debug_access+all",
        "-top",
        "risc240_tb",
        "-o",
        str(SIMV),
    ] + sources

    print("Compiling RTL with VCS...")
    print("RTL include directory: {}".format(RTL_DIR))

    result = run_command(
        command=command,
        cwd=BUILD_DIR,
        description="VCS compilation",
    )

    if result.stdout:
        print(result.stdout)


def get_existing_hex(source):
    # type: (Path) -> Path
    """
    Return the already-generated .hex file beside the .asm file.

    No assembler is run on AFS.
    """
    hex_path = source.with_suffix(".hex")

    if not hex_path.exists():
        raise RegressionError(
            "missing preassembled hex file: {}\n"
            "Assemble this test on your local machine and copy the .hex "
            "file to AFS beside the .asm file.".format(hex_path)
        )

    print("Using existing machine code: {}".format(hex_path))
    return hex_path


def parse_state(path):
    # type: (Path) -> Dict[str, str]
    if not path.exists():
        raise RegressionError(
            "RTL did not create state dump {}".format(path)
        )

    state = {}  # type: Dict[str, str]

    for line_number, raw in enumerate(
        path.read_text(encoding="utf-8").splitlines(),
        start=1,
    ):
        text = raw.strip()

        if not text:
            continue

        if "=" not in text:
            raise RegressionError(
                "{}:{}: malformed state line '{}'".format(
                    path,
                    line_number,
                    text,
                )
            )

        key, value = text.split("=", 1)
        state[key.strip().upper()] = value.strip().upper()

    return state


def compare_state(actual, expected):
    # type: (Dict[str, str], Dict[str, str]) -> List[str]
    failures = []  # type: List[str]

    expected_with_invariants = {
        "R0": "0000",
    }
    expected_with_invariants.update(expected)

    for key, expected_value in expected_with_invariants.items():
        normalized_key = str(key).upper()
        normalized_expected = str(expected_value).upper()
        actual_value = actual.get(normalized_key)

        if actual_value is None:
            failures.append(
                "{}: missing from RTL state dump".format(
                    normalized_key
                )
            )

        elif actual_value != normalized_expected:
            failures.append(
                "{}: expected {}, got {}".format(
                    normalized_key,
                    normalized_expected,
                    actual_value,
                )
            )

    return failures


def run_one_test(
    source,
    expected,
    max_cycles,
    keep_output,
):
    # type: (Path, Dict[str, str], int, bool) -> Tuple[bool, str]
    test_name = source.stem
    test_build = BUILD_DIR / test_name

    if test_build.exists():
        shutil.rmtree(str(test_build))

    test_build.mkdir(parents=True, exist_ok=True)

    hex_path = get_existing_hex(source)

    shutil.copy2(
        str(hex_path),
        str(test_build / "memory.hex"),
    )

    state_path = test_build / "rtl_state.txt"
    log_path = test_build / "simulation.log"

    result = subprocess.run(
        [
            str(SIMV),
            "+STATE={}".format(state_path),
            "+MAX_CYCLES={}".format(max_cycles),
        ],
        cwd=str(test_build),
        universal_newlines=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )

    log_path.write_text(
        result.stdout or "",
        encoding="utf-8",
    )

    if result.returncode != 0:
        return (
            False,
            "simulation exited with code {}; see {}".format(
                result.returncode,
                log_path,
            ),
        )

    actual = parse_state(state_path)

    failures = compare_state(
        actual=actual,
        expected=expected,
    )

    if failures:
        return (
            False,
            "{}; see {}".format(
                "; ".join(failures),
                state_path,
            ),
        )

    if not keep_output:
        shutil.rmtree(str(test_build))

    return True, "architectural state matched"


def main():
    # type: () -> int
    parser = argparse.ArgumentParser(
        description="Run RISC240 VCS RTL regression tests using existing .hex files"
    )

    parser.add_argument(
        "--tests",
        type=Path,
        default=DEFAULT_TEST_DIR,
        help="test directory (default: {})".format(
            DEFAULT_TEST_DIR
        ),
    )

    parser.add_argument(
        "--test",
        help="run one test by stem, such as test01_add",
    )

    parser.add_argument(
        "--rebuild",
        action="store_true",
        help="force VCS recompilation",
    )

    parser.add_argument(
        "--keep-output",
        action="store_true",
        help="keep state and log files for passing tests",
    )

    parser.add_argument(
        "--max-cycles",
        type=int,
        default=50000,
        help="RTL cycle timeout per test",
    )

    args = parser.parse_args()
    test_dir = args.tests.resolve()

    try:
        check_inputs(test_dir)

        expected_all = json.loads(
            EXPECTED_FILE.read_text(
                encoding="utf-8"
            )
        )

        compile_rtl(
            force=args.rebuild
        )

        if args.test:
            sources = [
                test_dir / "{}.asm".format(args.test)
            ]
        else:
            sources = sorted(
                test_dir.glob("test*.asm")
            )

        if not sources:
            raise RegressionError(
                "no assembly tests found in {}".format(
                    test_dir
                )
            )

        passed = 0
        failed = 0

        for source in sources:
            test_name = source.stem

            if not source.exists():
                print(
                    "FAIL  {}: .asm file not found".format(
                        test_name
                    )
                )
                failed += 1
                continue

            expected = expected_all.get(test_name)

            if expected is None:
                print(
                    "FAIL  {}: no entry in expected_results.json".format(
                        test_name
                    )
                )
                failed += 1
                continue

            try:
                ok, message = run_one_test(
                    source=source,
                    expected=expected,
                    max_cycles=args.max_cycles,
                    keep_output=args.keep_output,
                )

            except Exception as exc:
                ok = False
                message = str(exc)

            if ok:
                print(
                    "PASS  {}: {}".format(
                        test_name,
                        message,
                    )
                )
                passed += 1

            else:
                print(
                    "FAIL  {}: {}".format(
                        test_name,
                        message,
                    )
                )
                failed += 1

        print("")
        print("Passed: {}".format(passed))
        print("Failed: {}".format(failed))
        print("Total : {}".format(passed + failed))

        return 0 if failed == 0 else 1

    except (
        RegressionError,
        OSError,
        ValueError,
    ) as exc:
        print(
            "error: {}".format(exc),
            file=sys.stderr,
        )
        return 2


if __name__ == "__main__":
    sys.exit(main())
