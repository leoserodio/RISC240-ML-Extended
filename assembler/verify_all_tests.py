#!/usr/bin/env python3
"""
verify_all_tests.py

Assembles every test with MLASM.py, runs it with MLSIM.py, and verifies
the final state (reg vals).

Place this script in the same directory as:
    MLASM.py
    MLSIM.py
    tests/
"""

from __future__ import annotations

import argparse
import importlib.util
import subprocess
import sys
from pathlib import Path
from typing import Any, Callable


ROOT = Path(__file__).resolve().parent
TESTS = ROOT / "tests"


def load_module(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def assemble(assembler: Path, source: Path) -> Path:
    result = subprocess.run(
        [sys.executable, str(assembler), str(source)],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )

    if result.returncode != 0:
        raise RuntimeError(
            f"Assembler failed for {source.name}\n"
            f"{result.stdout}{result.stderr}"
        )

    hex_path = source.with_suffix(".hex")
    if not hex_path.exists():
        raise RuntimeError(f"Assembler did not create {hex_path.name}")
    return hex_path


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def reg(sim: Any, index: int) -> int:
    return sim.read_scalar(index)


def mem(sim: Any, address: int) -> int:
    return sim.read_word(address)


def verify_test(name: str, sim: Any) -> None:
    if name == "test01_add":
        require(reg(sim, 1) == 0x000A, "R1 should be $000A")
        require(reg(sim, 2) == 0x0014, "R2 should be $0014")
        require(reg(sim, 3) == 0x001E, "R3 should be $001E")

    elif name == "test02_sub":
        require(reg(sim, 3) == 0x0020, "R3 should be $0020")

    elif name == "test03_logic":
        require(reg(sim, 3) == 0x0000, "R3 should be $0000")
        require(reg(sim, 4) == 0x0FFF, "R4 should be $0FFF")
        require(reg(sim, 5) == 0x0FFF, "R5 should be $0FFF")
        require(reg(sim, 6) == 0xFF0F, "R6 should be $FF0F")

    elif name == "test04_shifts":
        require(reg(sim, 2) == 0x0020, "R2 should be $0020")
        require(reg(sim, 3) == 0x0008, "R3 should be $0008")
        require(reg(sim, 5) == 0xC000, "R5 should be $C000")

    elif name == "test05_compare":
        require(reg(sim, 3) == 1, "R3 should be 1")
        require(reg(sim, 4) == 0, "R4 should be 0")
        require(reg(sim, 5) == 1, "R5 should be 1")
        require(reg(sim, 6) == 0, "R6 should be 0")

    elif name == "test06_memory":
        require(reg(sim, 3) == 0x04D2, "R3 should be $04D2")
        require(mem(sim, 0x0100) == 0x04D2, "memory[$0100] should be $04D2")

    elif name == "test07_bra":
        require(reg(sim, 1) == 1, "R1 should remain 1")
        require(reg(sim, 2) == 5, "R2 should be 5")

    elif name == "test08_brz_taken":
        require(reg(sim, 2) == 0, "R2 should remain 0")
        require(reg(sim, 3) == 5, "R3 should be 5")

    elif name == "test09_brn_taken":
        require(reg(sim, 2) == 0, "R2 should remain 0")
        require(reg(sim, 3) == 5, "R3 should be 5")

    elif name == "test10_brc_taken":
        require(reg(sim, 3) == 0, "R3 should wrap to 0")
        require(reg(sim, 4) == 0, "R4 should remain 0")
        require(reg(sim, 5) == 5, "R5 should be 5")

    elif name == "test11_brv_taken":
        require(reg(sim, 3) == 0x8000, "R3 should be $8000")
        require(reg(sim, 4) == 0, "R4 should remain 0")
        require(reg(sim, 5) == 5, "R5 should be 5")

    elif name == "test12_brnz_current_rtl":
        require(reg(sim, 2) == 0, "R2 should remain 0")
        require(reg(sim, 3) == 5, "R3 should be 5")

    elif name == "test13_vector_add":
        require(sim.vector[3] == 0x0908070605040302, "V3 vector-add result mismatch")

    elif name == "test14_vector_mul":
        require(sim.vector[3] == 0x100E0C0A08060402, "V3 vector-multiply result mismatch")

    elif name == "test15_vector_relu":
        require(sim.vector[2] == 0x7F00000100550000, "V2 ReLU result mismatch")

    elif name == "test16_vector_dot":
        require(sim.acc == 16, "ACC should be 16")

    elif name == "test17_vector_load_store":
        require(sim.vector[1] == 0x4444333322221111, "V1 load result mismatch")
        expected = [0x1111, 0x2222, 0x3333, 0x4444]
        actual = [mem(sim, 0x0108 + 2 * i) for i in range(4)]
        require(actual == expected, f"stored words mismatch: {actual!r}")

    elif name == "test18_vector_integration":
        require(sim.vector[3] == 0x0809060704050203, "V3 add result mismatch")
        require(sim.vector[4] == 0x0809060704050203, "V4 ReLU result mismatch")
        require(sim.acc == 36, "ACC should be 36")
        expected = [0x0203, 0x0405, 0x0607, 0x0809]
        actual = [mem(sim, 0x0110 + 2 * i) for i in range(4)]
        require(actual == expected, f"integration store mismatch: {actual!r}")

    elif name == "test19_accst":
        require(sim.acc == -130048, "ACC should be -130048 ($FFFE0400)")

        require(
            mem(sim, 0x0200) == 0x0000,
            "memory[$0200] should remain $0000",
        )
        require(
            mem(sim, 0x0202) == 0x0000,
            "memory[$0202] should remain $0000",
        )
        require(
            mem(sim, 0x0204) == 0xF808,
            "memory[$0204] should be $F808",
        )
        require(
            mem(sim, 0x0206) == 0x0001,
            "memory[$0206] should be $0001",
        )
        require(
            mem(sim, 0x0208) == 0x0400,
            "memory[$0208] should be $0400",
        )
        require(
            mem(sim, 0x020A) == 0xFFFE,
            "memory[$020A] should be $FFFE",
        )

    else:
        raise AssertionError(f"No verifier exists for {name}")

    require(sim.halted, "processor should be halted")
    require(reg(sim, 0) == 0, "R0 must remain hardwired to zero")


def initialize_vector_test(name: str, sim: Any) -> None:
    if name == "test13_vector_add":
        sim.vector[1] = 0x0807060504030201
        sim.vector[2] = 0x0101010101010101

    elif name == "test14_vector_mul":
        sim.vector[1] = 0x0807060504030201
        sim.vector[2] = 0x0202020202020202

    elif name == "test15_vector_relu":
        sim.vector[1] = 0x7F80FF01AA5500FE

    elif name == "test16_vector_dot":
        sim.vector[1] = 0x0101010101010101
        sim.vector[2] = 0x0202020202020202


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--trace", action="store_true")
    parser.add_argument("--max-steps", type=int, default=100_000)
    args = parser.parse_args()

    assembler = ROOT / "MLASM.py"
    simulator_path = ROOT / "MLSIM.py"

    if not assembler.exists() or not simulator_path.exists():
        print(
            "error: place MLASM.py and MLSIM.py beside this script",
            file=sys.stderr,
        )
        return 2

    mlsim = load_module("mlsim_module", simulator_path)
    sources = sorted(TESTS.glob("test*.asm"))

    if not sources:
        print("error: no tests found", file=sys.stderr)
        return 2

    passed = 0
    failed = 0

    for source in sources:
        name = source.stem

        try:
            hex_path = assemble(assembler, source)
            sim = mlsim.RISC240Simulator()
            sim.load_program(hex_path)
            initialize_vector_test(name, sim)
            sim.run(max_steps=args.max_steps, trace=args.trace)
            verify_test(name, sim)
            print(f"PASS  {name}")
            passed += 1

        except Exception as exc:
            print(f"FAIL  {name}: {exc}")
            failed += 1

    print()
    print(f"Passed: {passed}")
    print(f"Failed: {failed}")
    print(f"Total : {passed + failed}")

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
