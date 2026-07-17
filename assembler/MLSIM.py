#!/usr/bin/env python3
"""
MLSIM.py - Instruction-set simulator for the RISC240 + vector/ML extension.

This is an architectural simulator, not a cycle-accurate RTL simulator.
It models the programmer-visible state:

    R0-R7          16-bit scalar registers (R0 is hardwired to zero)
    V0-V7          64-bit vector registers
    PC             16-bit byte address
    Z, C, N, V     scalar condition codes
    ACC            signed 32-bit dot-product accumulator
    memory         32K x 16-bit words (64 KiB byte-addressed space)

Vector arithmetic follows the supplied RTL:
    VADD   8 lanes x 8-bit, low 8 bits retained
    VMUL   8 lanes x 8-bit, low 8 bits retained
    VRELU  8 signed 8-bit lanes, negatives replaced with zero
    VDOT   signed int8 dot product, accumulated into signed 32-bit ACC
    VLD    loads four consecutive 16-bit words into one 64-bit vector
    VST    stores one 64-bit vector as four consecutive 16-bit words
    ACCST  stores ACC as two consecutive 16-bit words

Usage:
    python MLSIM.py program.hex
    python MLSIM.py program.hex --run
    python MLSIM.py program.hex --max-steps 10000
"""

from __future__ import annotations

import argparse
import re
import shlex
import sys
from dataclasses import dataclass
from pathlib import Path


VERSION = "1.1"
MEMORY_BYTES = 0x10000
MEMORY_WORDS = MEMORY_BYTES // 2


OPCODES: dict[str, int] = {
    "ADD":   0b000_0000,
    "SUB":   0b000_1000,
    "ADDI":  0b001_1000,
    "AND":   0b100_1000,
    "NOT":   0b100_0000,
    "OR":    0b101_0000,
    "XOR":   0b101_1000,
    "SLT":   0b010_1000,
    "SLTI":  0b010_1001,
    "SLL":   0b110_0000,
    "SLLI":  0b110_0001,
    "SRA":   0b111_1000,
    "SRAI":  0b111_1001,
    "SRL":   0b111_0000,
    "SRLI":  0b111_0001,
    "MV":    0b001_0000,
    "LW":    0b001_0100,
    "SW":    0b001_1100,
    "BRA":   0b111_1100,
    "BRN":   0b100_1100,
    "BRZ":   0b110_0100,
    "BRC":   0b101_0100,
    "BRV":   0b101_1100,
    "BRNZ":  0b110_1100,
    "STOP":  0b111_1111,
    "VADD":  0b011_0000,
    "VMUL":  0b011_0001,
    "VRELU": 0b011_0010,
    "VDOT":  0b011_0011,
    "VACLR": 0b011_0100,
    "VLD":   0b011_0101,
    "VST":   0b011_1011,
    "ACCST": 0b010_0001,
}

MNEMONIC_BY_OPCODE = {value: name for name, value in OPCODES.items()}

TWO_WORD_INSTRUCTIONS = {
    "ADDI",
    "SLTI",
    "SLLI",
    "SRAI",
    "SRLI",
    "LW",
    "SW",
    "BRA",
    "BRN",
    "BRZ",
    "BRC",
    "BRV",
    "BRNZ",
    "VLD",
    "VST",
    "ACCST",
}


class SimulationError(Exception):
    """Raised when the simulated program performs an invalid operation."""


@dataclass
class Flags:
    z: int = 0
    c: int = 0
    n: int = 0
    v: int = 0

    def text(self) -> str:
        return f"Z={self.z} C={self.c} N={self.n} V={self.v}"


@dataclass
class DecodedInstruction:
    pc: int
    word: int
    opcode: int
    mnemonic: str
    rd: int
    rs1: int
    rs2: int
    immediate: int | None

    @property
    def size(self) -> int:
        return 4 if self.immediate is not None else 2


def u8(value: int) -> int:
    return value & 0xFF


def s8(value: int) -> int:
    value &= 0xFF
    return value - 0x100 if value & 0x80 else value


def u16(value: int) -> int:
    return value & 0xFFFF


def s16(value: int) -> int:
    value &= 0xFFFF
    return value - 0x10000 if value & 0x8000 else value


def u32(value: int) -> int:
    return value & 0xFFFF_FFFF


def s32(value: int) -> int:
    value &= 0xFFFF_FFFF
    return value - 0x1_0000_0000 if value & 0x8000_0000 else value


def parse_int(token: str) -> int:
    token = token.strip()

    if token.startswith("$"):
        return int(token[1:], 16)

    return int(token, 0)


class RISC240Simulator:
    def __init__(self) -> None:
        self.initial_memory = [0] * MEMORY_WORDS
        self.memory = [0] * MEMORY_WORDS
        self.scalar = [0] * 8
        self.vector = [0] * 8
        self.pc = 0
        self.flags = Flags()
        self.acc = 0
        self.halted = False
        self.steps = 0
        self.last_instruction: DecodedInstruction | None = None

    # ------------------------------------------------------------------
    # Loading and reset
    # ------------------------------------------------------------------

    def load_hex(self, path: Path) -> None:
        words: list[int] = []

        for line_number, raw in enumerate(
            path.read_text(encoding="utf-8").splitlines(),
            start=1,
        ):
            text = raw.split(";", 1)[0].strip()

            if not text:
                continue

            if not re.fullmatch(r"[0-9A-Fa-f]{1,4}", text):
                raise SimulationError(
                    f"{path}:{line_number}: invalid hex word '{text}'"
                )

            words.append(int(text, 16))

        if len(words) > MEMORY_WORDS:
            raise SimulationError(
                f"program contains {len(words)} words; memory holds "
                f"{MEMORY_WORDS}"
            )

        self.initial_memory = [0] * MEMORY_WORDS
        self.initial_memory[:len(words)] = words
        self.reset()

    def load_coe(self, path: Path) -> None:
        text = path.read_text(encoding="utf-8")
        text = re.sub(r";[^\n]*", "", text)

        radix_match = re.search(
            r"memory_initialization_radix\s*=\s*(\d+)\s*;",
            text,
            re.IGNORECASE,
        )

        if radix_match is None:
            raise SimulationError("COE file is missing initialization radix")

        radix = int(radix_match.group(1))

        vector_match = re.search(
            r"memory_initialization_vector\s*=\s*(.*?)\s*;",
            text,
            re.IGNORECASE | re.DOTALL,
        )

        if vector_match is None:
            raise SimulationError("COE file is missing initialization vector")

        tokens = [
            token.strip()
            for token in vector_match.group(1).split(",")
            if token.strip()
        ]

        try:
            words = [int(token, radix) & 0xFFFF for token in tokens]
        except ValueError as exc:
            raise SimulationError(f"invalid COE value: {exc}") from exc

        if len(words) > MEMORY_WORDS:
            raise SimulationError(
                f"program contains {len(words)} words; memory holds "
                f"{MEMORY_WORDS}"
            )

        self.initial_memory = [0] * MEMORY_WORDS
        self.initial_memory[:len(words)] = words
        self.reset()

    def load_program(self, path: Path) -> None:
        suffix = path.suffix.lower()

        if suffix == ".hex":
            self.load_hex(path)
        elif suffix == ".coe":
            self.load_coe(path)
        else:
            raise SimulationError(
                "MLSIM currently accepts .hex or .coe program images"
            )

    def reset(self) -> None:
        self.memory = self.initial_memory.copy()
        self.scalar = [0] * 8
        self.vector = [0] * 8
        self.pc = 0
        self.flags = Flags()
        self.acc = 0
        self.halted = False
        self.steps = 0
        self.last_instruction = None

    # ------------------------------------------------------------------
    # Memory and register helpers
    # ------------------------------------------------------------------

    def check_address(self, address: int) -> int:
        address &= 0xFFFF

        if address & 1:
            raise SimulationError(
                f"unaligned 16-bit memory access at ${address:04X}"
            )

        return address

    def read_word(self, address: int) -> int:
        address = self.check_address(address)
        return self.memory[address // 2]

    def write_word(self, address: int, value: int) -> None:
        address = self.check_address(address)
        self.memory[address // 2] = u16(value)

    def read_scalar(self, index: int) -> int:
        if index == 0:
            return 0
        return self.scalar[index]

    def write_scalar(self, index: int, value: int) -> None:
        if index != 0:
            self.scalar[index] = u16(value)

        self.scalar[0] = 0

    def vector_bytes(self, index: int) -> list[int]:
        value = self.vector[index]
        return [(value >> (8 * lane)) & 0xFF for lane in range(8)]

    def vector_words(self, index: int) -> list[int]:
        value = self.vector[index]
        return [(value >> (16 * lane)) & 0xFFFF for lane in range(4)]

    def pack_vector_bytes(self, lanes: list[int]) -> int:
        value = 0

        for lane, element in enumerate(lanes):
            value |= u8(element) << (8 * lane)

        return value & 0xFFFF_FFFF_FFFF_FFFF

    def pack_vector_words(self, lanes: list[int]) -> int:
        value = 0

        for lane, element in enumerate(lanes):
            value |= u16(element) << (16 * lane)

        return value & 0xFFFF_FFFF_FFFF_FFFF

    # ------------------------------------------------------------------
    # Scalar ALU behavior
    # ------------------------------------------------------------------

    def update_flags(self, result: int, carry: int = 0, overflow: int = 0) -> None:
        result = u16(result)
        self.flags = Flags(
            z=int(result == 0),
            c=int(bool(carry)),
            n=int(bool(result & 0x8000)),
            v=int(bool(overflow)),
        )

    def alu_add(self, a: int, b: int) -> int:
        total = a + b
        result = u16(total)
        carry = int(total > 0xFFFF)
        overflow = int(
            bool((a & 0x8000) and (b & 0x8000) and not (result & 0x8000))
            or bool(
                not (a & 0x8000)
                and not (b & 0x8000)
                and (result & 0x8000)
            )
        )
        self.update_flags(result, carry, overflow)
        return result

    def alu_sub(self, a: int, b: int) -> int:
        result = u16(a - b)

        # This intentionally matches the supplied RTL:
        # C = (inB >= inA)
        carry = int(b >= a)

        overflow = int(
            bool((a & 0x8000) and not (b & 0x8000) and not (result & 0x8000))
            or bool(
                not (a & 0x8000)
                and (b & 0x8000)
                and (result & 0x8000)
            )
        )

        self.update_flags(result, carry, overflow)
        return result

    def update_logic_flags(self, result: int) -> int:
        result = u16(result)
        self.update_flags(result, 0, 0)
        return result

    @staticmethod
    def signed_less_than(a: int, b: int) -> int:
        return int(s16(a) < s16(b))

    @staticmethod
    def logical_left(a: int, amount: int) -> int:
        if amount >= 16:
            return 0
        return u16(a << amount)

    @staticmethod
    def logical_right(a: int, amount: int) -> int:
        if amount >= 16:
            return 0
        return u16(a >> amount)

    @staticmethod
    def arithmetic_right(a: int, amount: int) -> int:
        if amount >= 16:
            return 0xFFFF if a & 0x8000 else 0
        return u16(s16(a) >> amount)

    # ------------------------------------------------------------------
    # Decode and disassembly
    # ------------------------------------------------------------------

    def decode(self, address: int | None = None) -> DecodedInstruction:
        pc = self.pc if address is None else u16(address)
        word = self.read_word(pc)
        opcode = (word >> 9) & 0x7F
        rd = (word >> 6) & 0x07
        rs1 = (word >> 3) & 0x07
        rs2 = word & 0x07

        mnemonic = MNEMONIC_BY_OPCODE.get(opcode)

        if mnemonic is None:
            raise SimulationError(
                f"unknown opcode {opcode:07b} at PC=${pc:04X} "
                f"(word=${word:04X})"
            )

        immediate = (
            self.read_word(u16(pc + 2))
            if mnemonic in TWO_WORD_INSTRUCTIONS
            else None
        )

        return DecodedInstruction(
            pc=pc,
            word=word,
            opcode=opcode,
            mnemonic=mnemonic,
            rd=rd,
            rs1=rs1,
            rs2=rs2,
            immediate=immediate,
        )

    def format_instruction(self, instruction: DecodedInstruction) -> str:
        m = instruction.mnemonic
        rd = instruction.rd
        rs1 = instruction.rs1
        rs2 = instruction.rs2
        imm = instruction.immediate

        if m in {
            "ADD", "SUB", "AND", "OR", "XOR",
            "SLT", "SLL", "SRA", "SRL",
        }:
            return f"{m} R{rd}, R{rs1}, R{rs2}"

        if m in {"ADDI", "SLTI", "SLLI", "SRAI", "SRLI"}:
            assert imm is not None
            return f"{m} R{rd}, R{rs1}, ${imm:04X}"

        if m in {"MV", "NOT"}:
            return f"{m} R{rd}, R{rs1}"

        if m == "LW":
            assert imm is not None
            return f"LW R{rd}, R{rs1}, ${imm:04X}"

        if m == "SW":
            assert imm is not None
            return f"SW R{rs1}, R{rs2}, ${imm:04X}"

        if m in {"BRA", "BRN", "BRZ", "BRC", "BRV", "BRNZ"}:
            assert imm is not None
            return f"{m} ${imm:04X}"

        if m in {"VADD", "VMUL"}:
            return f"{m} V{rd}, V{rs1}, V{rs2}"

        if m == "VRELU":
            return f"VRELU V{rd}, V{rs1}"

        if m == "VDOT":
            return f"VDOT V{rs1}, V{rs2}"

        if m == "VACLR":
            return "VACLR"

        if m == "VLD":
            assert imm is not None
            return f"VLD V{rd}, R{rs1}, ${imm:04X}"

        if m == "VST":
            assert imm is not None
            return f"VST R{rs1}, V{rs2}, ${imm:04X}"

        if m == "ACCST":
            assert imm is not None
            return f"ACCST R{rs1}, ${imm:04X}"

        return m

    # ------------------------------------------------------------------
    # Instruction execution
    # ------------------------------------------------------------------

    def step(self, trace: bool = False) -> DecodedInstruction:
        if self.halted:
            raise SimulationError("processor is halted")

        instruction = self.decode()
        self.last_instruction = instruction

        if trace:
            print(
                f"PC=${instruction.pc:04X}  "
                f"{self.format_instruction(instruction)}"
            )

        m = instruction.mnemonic
        rd = instruction.rd
        rs1 = instruction.rs1
        rs2 = instruction.rs2
        imm = instruction.immediate

        a = self.read_scalar(rs1)
        b = self.read_scalar(rs2)

        # Default sequential PC. Two-word instructions skip their immediate.
        next_pc = u16(self.pc + instruction.size)

        if m == "ADD":
            self.write_scalar(rd, self.alu_add(a, b))

        elif m == "SUB":
            self.write_scalar(rd, self.alu_sub(a, b))

        elif m == "ADDI":
            assert imm is not None
            self.write_scalar(rd, self.alu_add(a, imm))

        elif m == "AND":
            self.write_scalar(rd, self.update_logic_flags(a & b))

        elif m == "NOT":
            self.write_scalar(rd, self.update_logic_flags(~a))

        elif m == "OR":
            self.write_scalar(rd, self.update_logic_flags(a | b))

        elif m == "XOR":
            self.write_scalar(rd, self.update_logic_flags(a ^ b))

        elif m == "SLT":
            # The RTL loads flags from A-B, then writes the comparison result
            # without updating flags.
            self.alu_sub(a, b)
            self.write_scalar(rd, self.signed_less_than(a, b))

        elif m == "SLTI":
            assert imm is not None
            self.alu_sub(a, imm)
            self.write_scalar(rd, self.signed_less_than(a, imm))

        elif m == "SLL":
            result = self.logical_left(a, b)
            self.write_scalar(rd, self.update_logic_flags(result))

        elif m == "SLLI":
            assert imm is not None
            result = self.logical_left(a, imm)
            self.write_scalar(rd, self.update_logic_flags(result))

        elif m == "SRA":
            result = self.arithmetic_right(a, b)
            self.write_scalar(rd, self.update_logic_flags(result))

        elif m == "SRAI":
            assert imm is not None
            result = self.arithmetic_right(a, imm)
            self.write_scalar(rd, self.update_logic_flags(result))

        elif m == "SRL":
            result = self.logical_right(a, b)
            self.write_scalar(rd, self.update_logic_flags(result))

        elif m == "SRLI":
            assert imm is not None
            result = self.logical_right(a, imm)
            self.write_scalar(rd, self.update_logic_flags(result))

        elif m == "MV":
            # MV does not load condition codes in the supplied control path.
            self.write_scalar(rd, a)

        elif m == "LW":
            assert imm is not None
            address = u16(a + imm)
            value = self.read_word(address)
            self.write_scalar(rd, value)
            self.update_logic_flags(value)

        elif m == "SW":
            assert imm is not None
            address = u16(a + imm)
            self.write_word(address, b)

        elif m == "BRA":
            assert imm is not None
            next_pc = imm

        elif m == "BRN":
            assert imm is not None
            if self.flags.n:
                next_pc = imm

        elif m == "BRZ":
            assert imm is not None
            if self.flags.z:
                next_pc = imm

        elif m == "BRC":
            assert imm is not None
            if self.flags.c:
                next_pc = imm

        elif m == "BRV":
            assert imm is not None
            if self.flags.v:
                next_pc = imm

        elif m == "BRNZ":
            assert imm is not None

            # This matches the supplied RTL exactly:
            # if (N | Z) branch is taken.
            if self.flags.n or self.flags.z:
                next_pc = imm

        elif m == "VADD":
            lhs = self.vector_bytes(rs1)
            rhs = self.vector_bytes(rs2)
            result = [u8(x + y) for x, y in zip(lhs, rhs)]
            self.vector[rd] = self.pack_vector_bytes(result)

        elif m == "VMUL":
            lhs = self.vector_bytes(rs1)
            rhs = self.vector_bytes(rs2)
            result = [u8(x * y) for x, y in zip(lhs, rhs)]
            self.vector[rd] = self.pack_vector_bytes(result)

        elif m == "VRELU":
            source = self.vector_bytes(rs1)
            result = [0 if s8(value) < 0 else value for value in source]
            self.vector[rd] = self.pack_vector_bytes(result)

        elif m == "VDOT":
            lhs = self.vector_bytes(rs1)
            rhs = self.vector_bytes(rs2)
            dot = sum(s8(x) * s8(y) for x, y in zip(lhs, rhs))
            self.acc = s32(self.acc + dot)

        elif m == "VACLR":
            self.acc = 0

        elif m == "VLD":
            assert imm is not None
            base = u16(a + imm)
            words = [
                self.read_word(u16(base + 2 * lane))
                for lane in range(4)
            ]
            self.vector[rd] = self.pack_vector_words(words)

        elif m == "VST":
            assert imm is not None
            base = u16(a + imm)
            words = self.vector_words(rs2)

            for lane, value in enumerate(words):
                self.write_word(u16(base + 2 * lane), value)


        elif m == "ACCST":
            assert imm is not None
            base = u16(a + imm)
            acc_bits = u32(self.acc)
            self.write_word(base, acc_bits & 0xFFFF)
            self.write_word(u16(base + 2), (acc_bits >> 16) & 0xFFFF)

        elif m == "STOP":
            self.halted = True
            next_pc = self.pc

        else:
            raise SimulationError(f"execution not implemented for {m}")

        self.pc = u16(next_pc)
        self.scalar[0] = 0
        self.steps += 1

        return instruction

    def run(
        self,
        max_steps: int = 100_000,
        trace: bool = False,
    ) -> int:
        executed = 0

        while not self.halted:
            if executed >= max_steps:
                raise SimulationError(
                    f"maximum step count ({max_steps}) reached at "
                    f"PC=${self.pc:04X}"
                )

            self.step(trace=trace)
            executed += 1

        return executed

    # ------------------------------------------------------------------
    # Debug display
    # ------------------------------------------------------------------

    def print_registers(self) -> None:
        for base in (0, 4):
            print(
                "  ".join(
                    f"R{index}=${self.read_scalar(index):04X}"
                    for index in range(base, base + 4)
                )
            )

    def print_vectors(self, index: int | None = None) -> None:
        indices = range(8) if index is None else [index]

        for register in indices:
            byte_lanes = self.vector_bytes(register)
            signed_lanes = [s8(value) for value in byte_lanes]
            word_lanes = self.vector_words(register)

            print(
                f"V{register}=${self.vector[register]:016X}  "
                f"bytes=[{' '.join(f'{x:02X}' for x in byte_lanes)}]  "
                f"signed={signed_lanes}  "
                f"words=[{' '.join(f'{x:04X}' for x in word_lanes)}]"
            )

    def print_state(self) -> None:
        status = "HALTED" if self.halted else "RUNNING"
        print(
            f"PC=${self.pc:04X}  ACC={self.acc} "
            f"(${u32(self.acc):08X})  {self.flags.text()}  {status}"
        )
        self.print_registers()

    def dump_memory(self, start: int, count: int = 8) -> None:
        start = self.check_address(start)

        for offset in range(count):
            address = u16(start + 2 * offset)
            print(f"${address:04X}: ${self.read_word(address):04X}")

    def disassemble(self, start: int | None = None, count: int = 8) -> None:
        address = self.pc if start is None else self.check_address(start)

        for _ in range(count):
            instruction = self.decode(address)
            print(
                f"${address:04X}: ${instruction.word:04X}  "
                f"{self.format_instruction(instruction)}"
            )
            address = u16(address + instruction.size)


HELP_TEXT = """
Commands:
    step [n]              Execute one or n instructions
    run [n]               Run until STOP, or for at most n instructions
    trace [n]             Run with instruction trace
    regs                  Show scalar registers
    vregs [index]         Show all vector registers or one V-register
    acc                   Show accumulator
    flags                 Show Z/C/N/V flags
    state                 Show PC, ACC, flags, and scalar registers
    mem address [count]   Dump memory words
    disasm [address] [n]  Disassemble instructions
    setr index value      Set scalar register R1-R7
    setv index value      Set an entire 64-bit vector value
    setm address value    Set one 16-bit memory word
    reset                 Restore initial program image and reset CPU
    help                  Show this command list
    quit                  Exit
"""


def repl(simulator: RISC240Simulator) -> None:
    print(f"MLSIM v{VERSION}")
    print("Type 'help' for commands.")
    simulator.print_state()

    while True:
        try:
            raw = input("mlsim> ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            return

        if not raw:
            continue

        try:
            parts = shlex.split(raw)
            command = parts[0].lower()
            args = parts[1:]

            if command in {"quit", "exit", "q"}:
                return

            if command in {"help", "h", "?"}:
                print(HELP_TEXT)

            elif command in {"step", "s"}:
                count = parse_int(args[0]) if args else 1

                for _ in range(count):
                    instruction = simulator.step(trace=True)

                    if simulator.halted:
                        print("Processor halted.")
                        break

            elif command == "run":
                limit = parse_int(args[0]) if args else 100_000
                executed = simulator.run(max_steps=limit)
                print(f"Processor halted after {executed} instruction(s).")

            elif command == "trace":
                limit = parse_int(args[0]) if args else 100_000
                executed = simulator.run(max_steps=limit, trace=True)
                print(f"Processor halted after {executed} instruction(s).")

            elif command in {"regs", "r"}:
                simulator.print_registers()

            elif command in {"vregs", "vr"}:
                index = parse_int(args[0]) if args else None

                if index is not None and not 0 <= index <= 7:
                    raise SimulationError("vector register index must be 0-7")

                simulator.print_vectors(index)

            elif command == "acc":
                print(f"ACC={simulator.acc} (${u32(simulator.acc):08X})")

            elif command == "flags":
                print(simulator.flags.text())

            elif command == "state":
                simulator.print_state()

            elif command == "mem":
                if not args:
                    raise SimulationError("usage: mem address [count]")

                start = parse_int(args[0])
                count = parse_int(args[1]) if len(args) > 1 else 8
                simulator.dump_memory(start, count)

            elif command in {"disasm", "d"}:
                start = parse_int(args[0]) if args else simulator.pc
                count = parse_int(args[1]) if len(args) > 1 else 8
                simulator.disassemble(start, count)

            elif command == "setr":
                if len(args) != 2:
                    raise SimulationError("usage: setr index value")

                index = parse_int(args[0])
                value = parse_int(args[1])

                if not 0 <= index <= 7:
                    raise SimulationError("scalar register index must be 0-7")

                simulator.write_scalar(index, value)

            elif command == "setv":
                if len(args) != 2:
                    raise SimulationError("usage: setv index value")

                index = parse_int(args[0])
                value = parse_int(args[1])

                if not 0 <= index <= 7:
                    raise SimulationError("vector register index must be 0-7")

                simulator.vector[index] = (
                    value & 0xFFFF_FFFF_FFFF_FFFF
                )

            elif command == "setm":
                if len(args) != 2:
                    raise SimulationError("usage: setm address value")

                simulator.write_word(
                    parse_int(args[0]),
                    parse_int(args[1]),
                )

            elif command == "reset":
                simulator.reset()
                print("Simulator reset.")

            else:
                print(f"Unknown command '{command}'. Type 'help'.")

        except (SimulationError, ValueError) as exc:
            print(f"error: {exc}")


def build_argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="RISC240 + vector/ML ISA simulator",
    )

    parser.add_argument(
        "program",
        type=Path,
        help="program image generated by MLASM (.hex or .coe)",
    )

    parser.add_argument(
        "--run",
        action="store_true",
        help="run immediately until STOP instead of entering the debugger",
    )

    parser.add_argument(
        "--trace",
        action="store_true",
        help="print every instruction while running",
    )

    parser.add_argument(
        "--max-steps",
        type=int,
        default=100_000,
        help="maximum instructions before stopping an automatic run",
    )

    parser.add_argument(
        "--version",
        action="version",
        version=f"MLSIM {VERSION}",
    )

    return parser


def main() -> int:
    parser = build_argument_parser()
    args = parser.parse_args()

    if not args.program.exists():
        print(
            f"error: program file not found: {args.program}",
            file=sys.stderr,
        )
        return 2

    simulator = RISC240Simulator()

    try:
        simulator.load_program(args.program)

        if args.run:
            executed = simulator.run(
                max_steps=args.max_steps,
                trace=args.trace,
            )

            print(
                f"Program halted after {executed} instruction(s)."
            )
            simulator.print_state()
            simulator.print_vectors()
        else:
            repl(simulator)

    except (SimulationError, OSError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())