#!/usr/bin/env python3
"""
MLASM.py - Assembler for the RISC240 ISA plus custom vector/ML instructions.

Supported scalar instructions:
    ADD, SUB, ADDI, LI, AND, NOT, OR, XOR
    SLT, SLTI, SLL, SLLI, SRA, SRAI, SRL, SRLI
    MV, LW, SW
    BRA, BRN, BRZ, BRC, BRV, BRNZ
    STOP

Supported vector/ML instructions:
    VADD  vd, vs1, vs2
    VMUL  vd, vs1, vs2
    VRELU vd, vs1
    VDOT  vs1, vs2
    VACLR
    VLD   vd, rs1, imm
    VST   rs1, vs2, imm
    ACCST rs1, imm

Pseudo-operations:
    .ORG address
    .DW value
    label .EQU value

Convenience pseudo-instructions:
    NOP
    CLR rd
    J address

Register aliases:
    SP = R7

Notes:
    - RISC240 addresses are byte addresses.
    - Each emitted 16-bit word advances the current address by 2 bytes.
    - Hexadecimal values may use the native RISC240 form, such as $0100.
    - Comments begin with a semicolon.
"""

from __future__ import annotations

import argparse
import difflib
import re
import sys
from dataclasses import dataclass
from pathlib import Path


VERSION = "1.2"


# ---------------------------------------------------------------------------
# ISA definitions
# ---------------------------------------------------------------------------

OPCODES: dict[str, int] = {
    # Scalar instructions
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

    # Vector / ML instructions
    "VADD":  0b011_0000,
    "VMUL":  0b011_0001,
    "VRELU": 0b011_0010,
    "VDOT":  0b011_0011,
    "VACLR": 0b011_0100,
    "VLD":   0b011_0101,
    "VST":   0b011_1011,
    "ACCST": 0b010_0001,
}

PSEUDO_OPS = {".ORG", ".DW", ".EQU"}
PSEUDO_INSTRUCTIONS = {"NOP", "CLR", "J"}
MNEMONICS = set(OPCODES) | {"LI"} | PSEUDO_OPS | PSEUDO_INSTRUCTIONS

REGISTER_ALIASES: dict[str, str] = {
    "SP": "R7",
}

THREE_REGISTER_OPS = {
    "ADD",
    "SUB",
    "AND",
    "OR",
    "XOR",
    "SLT",
    "SLL",
    "SRA",
    "SRL",
}

IMMEDIATE_OPS = {
    "ADDI",
    "SLTI",
    "SLLI",
    "SRAI",
    "SRLI",
}

BRANCH_OPS = {
    "BRA",
    "BRN",
    "BRZ",
    "BRC",
    "BRV",
    "BRNZ",
}

VECTOR_THREE_REGISTER_OPS = {
    "VADD",
    "VMUL",
}


# ---------------------------------------------------------------------------
# Data structures and errors
# ---------------------------------------------------------------------------

class AsmError(Exception):
    """Assembler error with source context."""


@dataclass
class Line:
    number: int
    raw: str
    label: str | None
    opcode: str | None
    operands: list[str]
    address: int | None = None


@dataclass
class Word:
    address: int
    value: int
    line: Line
    description: str


def error(line: Line, message: str) -> AsmError:
    return AsmError(
        f"line {line.number}: {message}\n"
        f"    {line.raw}"
    )


def unknown_instruction_error(line: Line, mnemonic: str) -> AsmError:
    suggestions = difflib.get_close_matches(
        mnemonic,
        sorted(MNEMONICS),
        n=1,
        cutoff=0.6,
    )

    message = f"unknown instruction '{mnemonic}'"

    if suggestions:
        message += f". Did you mean '{suggestions[0]}'?"

    return error(line, message)


# ---------------------------------------------------------------------------
# Parsing helpers
# ---------------------------------------------------------------------------

def strip_comment(text: str) -> str:
    return text.split(";", 1)[0].rstrip()


def split_operands(text: str) -> list[str]:
    if not text.strip():
        return []

    return [
        operand.strip()
        for operand in text.split(",")
        if operand.strip()
    ]


def normalize_memory_operands(operands: list[str]) -> list[str]:
    """
    Accept both of these forms:

        LW  r1, r2, $0004
        LW  r1, $0004(r2)

    This also works for VLD and VST where the second form is applicable.
    """
    if len(operands) != 2:
        return operands

    match = re.fullmatch(
        r"(.+)\(\s*([rRvV][0-7]|[sS][pP])\s*\)",
        operands[1],
    )

    if match is None:
        return operands

    immediate = match.group(1).strip()
    base_register = match.group(2).strip()

    return [
        operands[0],
        base_register,
        immediate,
    ]


def parse_source(text: str) -> list[Line]:
    parsed_lines: list[Line] = []

    for number, raw in enumerate(text.splitlines(), start=1):
        body = strip_comment(raw)

        if not body.strip():
            parsed_lines.append(
                Line(
                    number=number,
                    raw=raw,
                    label=None,
                    opcode=None,
                    operands=[],
                )
            )
            continue

        leading_whitespace = body[:1].isspace()
        tokens = body.strip().split(None, 2)

        label: str | None = None
        opcode: str | None = None
        operand_text = ""

        if tokens[0].endswith(":"):
            label = tokens[0][:-1].upper()

            if len(tokens) >= 2:
                opcode = tokens[1].upper()

            if len(tokens) >= 3:
                operand_text = tokens[2]

        elif not leading_whitespace and tokens[0].upper() not in MNEMONICS:
            label = tokens[0].upper()

            if len(tokens) >= 2:
                opcode = tokens[1].upper()

            if len(tokens) >= 3:
                operand_text = tokens[2]

        else:
            opcode = tokens[0].upper()
            operand_text = body.strip()[len(tokens[0]):].strip()

        operands = normalize_memory_operands(
            split_operands(operand_text)
        )

        parsed_lines.append(
            Line(
                number=number,
                raw=raw,
                label=label,
                opcode=opcode,
                operands=operands,
            )
        )

    return parsed_lines


# ---------------------------------------------------------------------------
# Validation and value helpers
# ---------------------------------------------------------------------------

def parse_number(token: str) -> int | None:
    token = token.strip()

    if re.fullmatch(r"\$[0-9A-Fa-f]{1,4}", token):
        return int(token[1:], 16)

    if re.fullmatch(r"0[xX][0-9A-Fa-f]+", token):
        return int(token, 16)

    if re.fullmatch(r"-?\d+", token):
        return int(token, 10)

    return None


def require_operands(line: Line, count: int) -> None:
    if len(line.operands) != count:
        raise error(
            line,
            (
                f"{line.opcode} expects {count} operand(s), "
                f"got {len(line.operands)}"
            ),
        )


def parse_register(token: str, prefix: str, line: Line) -> int:
    normalized = token.upper()

    if prefix.upper() == "R":
        normalized = REGISTER_ALIASES.get(normalized, normalized)

    match = re.fullmatch(
        rf"{prefix}([0-7])",
        normalized,
        re.IGNORECASE,
    )

    if match is None:
        aliases = ""

        if prefix.upper() == "R":
            aliases = " or alias SP"

        raise error(
            line,
            f"expected {prefix}0-{prefix}7{aliases}, got '{token}'",
        )

    return int(match.group(1))


def encode_instruction(
    opcode: int,
    rd: int = 0,
    rs1: int = 0,
    rs2: int = 0,
) -> int:
    return (
        ((opcode & 0x7F) << 9)
        | ((rd & 0x07) << 6)
        | ((rs1 & 0x07) << 3)
        | (rs2 & 0x07)
    )


def instruction_size(opcode: str, line: Line) -> int:
    if opcode in {"J"}:
        return 4

    if opcode in {"NOP", "CLR"}:
        return 2

    if (
        opcode in IMMEDIATE_OPS
        or opcode in {"LI", "LW", "SW", "VLD", "VST", "ACCST"}
        or opcode in BRANCH_OPS
    ):
        return 4

    if opcode in OPCODES:
        return 2

    raise unknown_instruction_error(line, opcode)


def resolve_value(
    token: str,
    labels: dict[str, int],
    equates: dict[str, str],
    line: Line,
    resolving: set[str] | None = None,
) -> int:
    numeric_value = parse_number(token)

    if numeric_value is not None:
        return numeric_value

    symbol = token.upper()

    if symbol in labels:
        return labels[symbol]

    if symbol in equates:
        if resolving is None:
            resolving = set()

        if symbol in resolving:
            raise error(
                line,
                f"circular .EQU definition involving '{symbol}'",
            )

        resolving.add(symbol)

        value = resolve_value(
            equates[symbol],
            labels,
            equates,
            line,
            resolving,
        )

        resolving.remove(symbol)
        return value

    raise error(
        line,
        f"unknown value or label '{token}'",
    )


def validate_word_value(
    value: int,
    line: Line,
    description: str,
) -> int:
    if value < -32768 or value > 0xFFFF:
        raise error(
            line,
            (
                f"{description} value {value} is outside the supported "
                "16-bit range (-32768 through 65535)"
            ),
        )

    return value & 0xFFFF


def validate_address(
    value: int,
    line: Line,
    description: str,
    require_alignment: bool = True,
) -> int:
    if value < 0 or value > 0xFFFF:
        raise error(
            line,
            f"{description} ${value:X} is outside the 16-bit address space",
        )

    if require_alignment and (value & 1):
        raise error(
            line,
            f"{description} ${value:04X} is not word-aligned",
        )

    return value


# ---------------------------------------------------------------------------
# First pass
# ---------------------------------------------------------------------------

def first_pass(
    lines: list[Line],
) -> tuple[dict[str, int], dict[str, str]]:
    labels: dict[str, int] = {}
    equates: dict[str, str] = {}
    used_addresses: dict[int, Line] = {}
    address = 0

    for line in lines:
        opcode = line.opcode

        if opcode == ".EQU":
            if line.label is None:
                raise error(
                    line,
                    ".EQU requires a label",
                )

            require_operands(line, 1)

            if line.label in labels or line.label in equates:
                raise error(
                    line,
                    f"duplicate symbol '{line.label}'",
                )

            equates[line.label] = line.operands[0]
            continue

        if opcode == ".ORG":
            require_operands(line, 1)

            origin = parse_number(line.operands[0])

            if origin is None:
                raise error(
                    line,
                    ".ORG requires a numeric address",
                )

            address = validate_address(
                origin,
                line,
                ".ORG address",
            )

            line.address = address

            if line.label is not None:
                if line.label in labels or line.label in equates:
                    raise error(
                        line,
                        f"duplicate symbol '{line.label}'",
                    )

                labels[line.label] = address

            continue

        if line.label is not None:
            if line.label in labels or line.label in equates:
                raise error(
                    line,
                    f"duplicate symbol '{line.label}'",
                )

            labels[line.label] = address

        line.address = address

        if opcode is None:
            continue

        if opcode == ".DW":
            require_operands(line, 1)
            byte_count = 2
        else:
            byte_count = instruction_size(opcode, line)

        for word_address in range(address, address + byte_count, 2):
            if word_address in used_addresses:
                previous_line = used_addresses[word_address]

                raise error(
                    line,
                    (
                        f"address ${word_address:04X} overlaps "
                        f"line {previous_line.number}"
                    ),
                )

            used_addresses[word_address] = line

        address += byte_count

        if address > 0x10000:
            raise error(
                line,
                "program exceeds the 16-bit address space",
            )

    return labels, equates


# ---------------------------------------------------------------------------
# Instruction encoding
# ---------------------------------------------------------------------------

def emit_instruction(
    line: Line,
    labels: dict[str, int],
    equates: dict[str, str],
) -> list[tuple[int, str]]:
    mnemonic = line.opcode
    operands = line.operands

    if mnemonic is None:
        raise error(
            line,
            "internal error: missing instruction mnemonic",
        )

    if mnemonic == "NOP":
        require_operands(line, 0)

        return [
            (
                encode_instruction(
                    OPCODES["ADD"],
                    0,
                    0,
                    0,
                ),
                "NOP/ADD",
            )
        ]

    if mnemonic == "CLR":
        require_operands(line, 1)

        rd = parse_register(operands[0], "R", line)

        return [
            (
                encode_instruction(
                    OPCODES["MV"],
                    rd,
                    0,
                    0,
                ),
                "CLR/MV",
            )
        ]

    if mnemonic == "J":
        require_operands(line, 1)

        target = validate_address(
            resolve_value(
                operands[0],
                labels,
                equates,
                line,
            ),
            line,
            "jump target",
        )

        return [
            (
                encode_instruction(OPCODES["BRA"]),
                "J/BRA",
            ),
            (
                target,
                "jump target",
            ),
        ]

    if mnemonic in THREE_REGISTER_OPS:
        require_operands(line, 3)

        rd = parse_register(operands[0], "R", line)
        rs1 = parse_register(operands[1], "R", line)
        rs2 = parse_register(operands[2], "R", line)

        return [
            (
                encode_instruction(
                    OPCODES[mnemonic],
                    rd,
                    rs1,
                    rs2,
                ),
                mnemonic,
            )
        ]

    if mnemonic in IMMEDIATE_OPS:
        require_operands(line, 3)

        rd = parse_register(operands[0], "R", line)
        rs1 = parse_register(operands[1], "R", line)
        immediate = validate_word_value(
            resolve_value(
                operands[2],
                labels,
                equates,
                line,
            ),
            line,
            "immediate",
        )

        return [
            (
                encode_instruction(
                    OPCODES[mnemonic],
                    rd,
                    rs1,
                    0,
                ),
                mnemonic,
            ),
            (
                immediate,
                "immediate",
            ),
        ]

    if mnemonic == "LI":
        require_operands(line, 2)

        rd = parse_register(operands[0], "R", line)
        immediate = validate_word_value(
            resolve_value(
                operands[1],
                labels,
                equates,
                line,
            ),
            line,
            "immediate",
        )

        return [
            (
                encode_instruction(
                    OPCODES["ADDI"],
                    rd,
                    0,
                    0,
                ),
                "LI/ADDI",
            ),
            (
                immediate,
                "immediate",
            ),
        ]

    if mnemonic in {"MV", "NOT"}:
        require_operands(line, 2)

        rd = parse_register(operands[0], "R", line)
        rs1 = parse_register(operands[1], "R", line)

        return [
            (
                encode_instruction(
                    OPCODES[mnemonic],
                    rd,
                    rs1,
                    0,
                ),
                mnemonic,
            )
        ]

    if mnemonic == "LW":
        require_operands(line, 3)

        rd = parse_register(operands[0], "R", line)
        rs1 = parse_register(operands[1], "R", line)
        immediate = validate_word_value(
            resolve_value(
                operands[2],
                labels,
                equates,
                line,
            ),
            line,
            "immediate",
        )

        return [
            (
                encode_instruction(
                    OPCODES[mnemonic],
                    rd,
                    rs1,
                    0,
                ),
                mnemonic,
            ),
            (
                immediate,
                "immediate",
            ),
        ]

    if mnemonic == "SW":
        require_operands(line, 3)

        rs1 = parse_register(operands[0], "R", line)
        rs2 = parse_register(operands[1], "R", line)
        immediate = validate_word_value(
            resolve_value(
                operands[2],
                labels,
                equates,
                line,
            ),
            line,
            "immediate",
        )

        return [
            (
                encode_instruction(
                    OPCODES[mnemonic],
                    0,
                    rs1,
                    rs2,
                ),
                mnemonic,
            ),
            (
                immediate,
                "immediate",
            ),
        ]


    if mnemonic == "ACCST":
        require_operands(line, 2)

        rs1 = parse_register(operands[0], "R", line)
        immediate = validate_word_value(
            resolve_value(operands[1], labels, equates, line),
            line,
            "immediate",
        )

        return [
            (
                encode_instruction(OPCODES[mnemonic], 0, rs1, 0),
                mnemonic,
            ),
            (
                immediate,
                "immediate",
            ),
        ]

    if mnemonic in BRANCH_OPS:
        require_operands(line, 1)

        target = validate_address(
            resolve_value(
                operands[0],
                labels,
                equates,
                line,
            ),
            line,
            "branch target",
        )

        return [
            (
                encode_instruction(OPCODES[mnemonic]),
                mnemonic,
            ),
            (
                target,
                "branch target",
            ),
        ]

    if mnemonic == "STOP":
        require_operands(line, 0)

        return [
            (
                encode_instruction(OPCODES[mnemonic]),
                mnemonic,
            )
        ]

    if mnemonic in VECTOR_THREE_REGISTER_OPS:
        require_operands(line, 3)

        vd = parse_register(operands[0], "V", line)
        vs1 = parse_register(operands[1], "V", line)
        vs2 = parse_register(operands[2], "V", line)

        return [
            (
                encode_instruction(
                    OPCODES[mnemonic],
                    vd,
                    vs1,
                    vs2,
                ),
                mnemonic,
            )
        ]

    if mnemonic == "VRELU":
        require_operands(line, 2)

        vd = parse_register(operands[0], "V", line)
        vs1 = parse_register(operands[1], "V", line)

        return [
            (
                encode_instruction(
                    OPCODES[mnemonic],
                    vd,
                    vs1,
                    0,
                ),
                mnemonic,
            )
        ]

    if mnemonic == "VDOT":
        require_operands(line, 2)

        vs1 = parse_register(operands[0], "V", line)
        vs2 = parse_register(operands[1], "V", line)

        return [
            (
                encode_instruction(
                    OPCODES[mnemonic],
                    0,
                    vs1,
                    vs2,
                ),
                mnemonic,
            )
        ]

    if mnemonic == "VACLR":
        require_operands(line, 0)

        return [
            (
                encode_instruction(OPCODES[mnemonic]),
                mnemonic,
            )
        ]

    if mnemonic == "VLD":
        require_operands(line, 3)

        vd = parse_register(operands[0], "V", line)
        rs1 = parse_register(operands[1], "R", line)
        immediate = validate_word_value(
            resolve_value(
                operands[2],
                labels,
                equates,
                line,
            ),
            line,
            "immediate",
        )

        return [
            (
                encode_instruction(
                    OPCODES[mnemonic],
                    vd,
                    rs1,
                    0,
                ),
                mnemonic,
            ),
            (
                immediate,
                "immediate",
            ),
        ]

    if mnemonic == "VST":
        require_operands(line, 3)

        rs1 = parse_register(operands[0], "R", line)
        vs2 = parse_register(operands[1], "V", line)
        immediate = validate_word_value(
            resolve_value(
                operands[2],
                labels,
                equates,
                line,
            ),
            line,
            "immediate",
        )

        return [
            (
                encode_instruction(
                    OPCODES[mnemonic],
                    0,
                    rs1,
                    vs2,
                ),
                mnemonic,
            ),
            (
                immediate,
                "immediate",
            ),
        ]

    raise unknown_instruction_error(line, mnemonic)


# ---------------------------------------------------------------------------
# Second pass
# ---------------------------------------------------------------------------

def second_pass(
    lines: list[Line],
    labels: dict[str, int],
    equates: dict[str, str],
) -> list[Word]:
    words: list[Word] = []
    used_addresses: dict[int, Line] = {}
    address = 0

    def add_word(
        value: int,
        line: Line,
        description: str,
    ) -> None:
        nonlocal address

        if address & 1:
            raise error(
                line,
                f"internal error: unaligned address ${address:04X}",
            )

        if address in used_addresses:
            previous_line = used_addresses[address]

            raise error(
                line,
                (
                    f"address ${address:04X} already used "
                    f"by line {previous_line.number}"
                ),
            )

        used_addresses[address] = line

        words.append(
            Word(
                address=address,
                value=value & 0xFFFF,
                line=line,
                description=description,
            )
        )

        address += 2

    for line in lines:
        mnemonic = line.opcode

        if mnemonic is None or mnemonic == ".EQU":
            continue

        if mnemonic == ".ORG":
            address = validate_address(
                resolve_value(
                    line.operands[0],
                    labels,
                    equates,
                    line,
                ),
                line,
                ".ORG address",
            )
            continue

        if mnemonic == ".DW":
            require_operands(line, 1)

            value = validate_word_value(
                resolve_value(
                    line.operands[0],
                    labels,
                    equates,
                    line,
                ),
                line,
                ".DW",
            )

            add_word(
                value,
                line,
                ".DW",
            )

            continue

        encoded_words = emit_instruction(
            line,
            labels,
            equates,
        )

        for value, description in encoded_words:
            add_word(
                value,
                line,
                description,
            )

    return sorted(
        words,
        key=lambda word: word.address,
    )


# ---------------------------------------------------------------------------
# Output generation
# ---------------------------------------------------------------------------

def dense_memory(words: list[Word]) -> list[int]:
    last_word_index = max(
        (
            word.address // 2
            for word in words
        ),
        default=0,
    )

    memory = [0] * (last_word_index + 1)

    for word in words:
        memory[word.address // 2] = word.value

    return memory


def write_coe(
    path: Path,
    memory: list[int],
) -> None:
    with path.open(
        "w",
        encoding="utf-8",
        newline="\n",
    ) as file:
        file.write(
            f"; Generated by MLASM v{VERSION}\n"
        )
        file.write(
            "memory_initialization_radix=16;\n"
        )
        file.write(
            "memory_initialization_vector =\n"
        )

        for index, value in enumerate(memory):
            terminator = (
                ";"
                if index == len(memory) - 1
                else ","
            )

            file.write(
                f"{value:04X}{terminator}\n"
            )


def write_hex(
    path: Path,
    memory: list[int],
) -> None:
    with path.open(
        "w",
        encoding="utf-8",
        newline="\n",
    ) as file:
        for value in memory:
            file.write(
                f"{value:04X}\n"
            )


def write_binary(
    path: Path,
    memory: list[int],
) -> None:
    with path.open("wb") as file:
        for value in memory:
            file.write(
                value.to_bytes(
                    2,
                    byteorder="big",
                    signed=False,
                )
            )


def write_list(
    path: Path,
    lines: list[Line],
    words: list[Word],
    labels: dict[str, int],
    equates: dict[str, str],
) -> None:
    words_by_line: dict[int, list[Word]] = {}

    for word in words:
        words_by_line.setdefault(
            word.line.number,
            [],
        ).append(word)

    with path.open(
        "w",
        encoding="utf-8",
        newline="\n",
    ) as file:
        file.write(
            f"MLASM v{VERSION} listing\n"
        )
        file.write(
            "Address  Word  Description     Source\n"
        )
        file.write(
            "=======  ====  ===============  ========================================\n"
        )

        for line in lines:
            line_words = words_by_line.get(
                line.number,
                [],
            )

            if not line_words:
                file.write(
                    f"                              {line.raw}\n"
                )
                continue

            for index, word in enumerate(line_words):
                source_text = (
                    line.raw
                    if index == 0
                    else ""
                )

                file.write(
                    f"{word.address:04X}     "
                    f"{word.value:04X}  "
                    f"{word.description:<15}  "
                    f"{source_text}\n"
                )

        file.write(
            "\nSymbols\n"
        )
        file.write(
            "=======\n"
        )

        for name, value in sorted(labels.items()):
            file.write(
                f"{name:<24} ${value:04X}\n"
            )

        for name in sorted(equates):
            value = validate_word_value(
                resolve_value(
                    equates[name],
                    labels,
                    equates,
                    Line(
                        number=0,
                        raw="",
                        label=None,
                        opcode=None,
                        operands=[],
                    ),
                ),
                Line(
                    number=0,
                    raw="",
                    label=None,
                    opcode=None,
                    operands=[],
                ),
                ".EQU",
            )

            file.write(
                f"{name:<24} ${value:04X}  (.EQU)\n"
            )


def write_outputs(
    output_base: Path,
    lines: list[Line],
    words: list[Word],
    labels: dict[str, int],
    equates: dict[str, str],
) -> tuple[Path, Path, Path, Path]:
    coe_path = output_base.with_suffix(".coe")
    hex_path = output_base.with_suffix(".hex")
    binary_path = output_base.with_suffix(".bin")
    list_path = output_base.with_suffix(".list")

    memory = dense_memory(words)

    write_coe(
        coe_path,
        memory,
    )

    write_hex(
        hex_path,
        memory,
    )

    write_binary(
        binary_path,
        memory,
    )

    write_list(
        list_path,
        lines,
        words,
        labels,
        equates,
    )

    return (
        coe_path,
        hex_path,
        binary_path,
        list_path,
    )


# ---------------------------------------------------------------------------
# Built-in self-tests
# ---------------------------------------------------------------------------

def run_self_tests() -> None:
    test_program = """
        .ORG $0000
START   LI    R1, $0100
        CLR   R2
        NOP
        VLD   V1, R1, $0000
        VLD   V2, $0008(R1)
        VADD  V3, V1, V2
        VST   SP, V3, $0010
        J     DONE
DONE    STOP
"""

    lines = parse_source(test_program)
    labels, equates = first_pass(lines)
    words = second_pass(lines, labels, equates)

    actual = [word.value for word in words]

    expected = [
        encode_instruction(OPCODES["ADDI"], 1, 0, 0),
        0x0100,
        encode_instruction(OPCODES["MV"], 2, 0, 0),
        encode_instruction(OPCODES["ADD"], 0, 0, 0),
        encode_instruction(OPCODES["VLD"], 1, 1, 0),
        0x0000,
        encode_instruction(OPCODES["VLD"], 2, 1, 0),
        0x0008,
        encode_instruction(OPCODES["VADD"], 3, 1, 2),
        encode_instruction(OPCODES["VST"], 0, 7, 3),
        0x0010,
        encode_instruction(OPCODES["BRA"], 0, 0, 0),
        0x001A,
        encode_instruction(OPCODES["STOP"], 0, 0, 0),
    ]

    if actual != expected:
        raise AssertionError(
            "self-test failed:\n"
            f"expected: {[f'{value:04X}' for value in expected]}\n"
            f"actual:   {[f'{value:04X}' for value in actual]}"
        )

    try:
        bad_lines = parse_source("        VMAD V1, V2, V3\n")
        first_pass(bad_lines)
    except AsmError as exception:
        if "Did you mean" not in str(exception):
            raise AssertionError(
                "unknown-opcode suggestion self-test failed"
            ) from exception
    else:
        raise AssertionError(
            "unknown opcode was not rejected"
        )

    try:
        overlap_program = """
            .ORG $0000
            ADD R1, R2, R3
            .ORG $0000
            SUB R1, R2, R3
        """
        overlap_lines = parse_source(overlap_program)
        first_pass(overlap_lines)
    except AsmError:
        pass
    else:
        raise AssertionError(
            "overlapping .ORG regions were not rejected"
        )

    print(f"MLASM v{VERSION} self-tests passed")


# ---------------------------------------------------------------------------
# Command-line interface
# ---------------------------------------------------------------------------

def build_argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="RISC240 + ML/vector assembler",
    )

    parser.add_argument(
        "source",
        nargs="?",
        type=Path,
        help="input assembly file",
    )

    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="output base name",
    )

    parser.add_argument(
        "--self-test",
        action="store_true",
        help="run built-in assembler tests and exit",
    )

    parser.add_argument(
        "--version",
        action="version",
        version=f"MLASM {VERSION}",
    )

    return parser


def main() -> int:
    parser = build_argument_parser()
    arguments = parser.parse_args()

    if arguments.self_test:
        try:
            run_self_tests()
        except (AsmError, AssertionError) as exception:
            print(
                f"self-test error: {exception}",
                file=sys.stderr,
            )
            return 1

        return 0

    if arguments.source is None:
        parser.error(
            "the following arguments are required: source "
            "(unless --self-test is used)"
        )

    source_path: Path = arguments.source

    if not source_path.exists():
        print(
            f"error: file not found: {source_path}",
            file=sys.stderr,
        )
        return 2

    output_base = (
        arguments.output
        if arguments.output is not None
        else source_path.with_suffix("")
    )

    try:
        source_text = source_path.read_text(
            encoding="utf-8",
        )

        lines = parse_source(
            source_text,
        )

        labels, equates = first_pass(
            lines,
        )

        words = second_pass(
            lines,
            labels,
            equates,
        )

        output_paths = write_outputs(
            output_base,
            lines,
            words,
            labels,
            equates,
        )

    except (AsmError, OSError) as exception:
        print(
            f"error: {exception}",
            file=sys.stderr,
        )
        return 1

    instruction_count = sum(
        1
        for line in lines
        if (
            line.opcode is not None
            and line.opcode not in PSEUDO_OPS
        )
    )

    byte_count = len(words) * 2

    program_end = (
        max(word.address for word in words) + 2
        if words
        else 0
    )

    print()
    print(f"MLASM v{VERSION}")
    print("Assembly successful")
    print()
    print(f"Instructions : {instruction_count}")
    print(f"Words        : {len(words)}")
    print(f"Bytes        : {byte_count}")
    print(f"Program end  : ${program_end:04X}")
    print(f"Labels       : {len(labels)}")
    print(f"Equates      : {len(equates)}")
    print()

    for path in output_paths:
        print(f"Wrote {path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())