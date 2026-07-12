# RISC240-ML ISA Extension Reference

## 1. Overview

RISC240-ML extends the original Carnegie Mellon RISC240 instruction set with a small vector execution subsystem intended for quantized machine-learning workloads.

The base scalar RISC240 ISA remains unchanged. This document only specifies the additional architectural state and instructions introduced by the RISC240-ML extension. The original RISC240 Reference Manual should be used for the scalar instruction set, addressing rules, condition codes, and general assembly-language format.

---

## 2. Added Architectural State

### Vector Registers

RISC240-ML adds eight 64-bit vector registers:

```text
v0, v1, v2, v3, v4, v5, v6, v7
```

Unlike scalar register `r0`, vector register `v0` is not hardwired to zero.

Each vector register may be interpreted in two ways:

- **Memory-transfer view:** four 16-bit words
- **Arithmetic view:** eight 8-bit elements

```text
63                                                        0
+--------+--------+--------+--------+--------+--------+--------+--------+
| byte 7 | byte 6 | byte 5 | byte 4 | byte 3 | byte 2 | byte 1 | byte 0 |
+--------+--------+--------+--------+--------+--------+--------+--------+
```

Vector arithmetic instructions operate independently on the eight 8-bit elements.

Vector load and store instructions transfer the same 64-bit value as four consecutive 16-bit memory words.

### Accumulator

RISC240-ML adds one signed 32-bit accumulator:

```text
ACC
```

The accumulator is used by the `VDOT` instruction and may be cleared with `VACLR`.

---

## 3. General Instruction Encoding

All instruction words remain 16 bits wide.

The new vector instructions use the same basic register-field locations as the scalar RISC240 instructions:

```text
15              9 8       6 5       3 2       0
+----------------+---------+---------+---------+
|  7-bit opcode  |   rd    |   rs1   |   rs2   |
+----------------+---------+---------+---------+
```

For vector arithmetic:

- `rd` selects the destination vector register
- `rs1` selects the first source vector register
- `rs2` selects the second source vector register

For vector memory instructions, scalar and vector register fields are used as described in the individual instruction definitions.

---

## 4. Opcode Summary

| Instruction | 7-bit opcode | Base instruction word |
|---|---:|---:|
| `VADD`  | `0110000` | `$6000` |
| `VMUL`  | `0110001` | `$6200` |
| `VRELU` | `0110010` | `$6400` |
| `VDOT`  | `0110011` | `$6600` |
| `VACLR` | `0110100` | `$6800` |
| `VLD`   | `0110101` | `$6A00` |
| `VST`   | `0111011` | `$7600` |

The base instruction word assumes all register fields are zero.

---

## 5. Vector Instructions

### `VADD vd, vs1, vs2`

Vector Addition

**Semantics**

```text
for i = 0 to 7:
    vd.byte[i] <- (vs1.byte[i] + vs2.byte[i]) mod 256
```

Each 8-bit element is added independently. Carry out from one element does not propagate into another element.

**Encoding**

```text
15              9 8       6 5       3 2       0
+----------------+---------+---------+---------+
|    0110000     |   vd    |   vs1   |   vs2   |
+----------------+---------+---------+---------+
```

**Condition Codes**

```text
ZCNV: not changed
```

**Nominal Cycles**

```text
5
```

---

### `VMUL vd, vs1, vs2`

Vector Multiplication

**Semantics**

```text
for i = 0 to 7:
    vd.byte[i] <- low_8_bits(vs1.byte[i] * vs2.byte[i])
```

Each pair of 8-bit elements is multiplied independently. The current implementation stores only the low eight bits of each product.

**Encoding**

```text
15              9 8       6 5       3 2       0
+----------------+---------+---------+---------+
|    0110001     |   vd    |   vs1   |   vs2   |
+----------------+---------+---------+---------+
```

**Condition Codes**

```text
ZCNV: not changed
```

**Nominal Cycles**

```text
5
```

---

### `VRELU vd, vs1`

Vector Rectified Linear Unit

**Semantics**

Each 8-bit element is interpreted as a signed two's-complement value.

```text
for i = 0 to 7:
    if vs1.byte[i][7] == 1:
        vd.byte[i] <- 0
    else:
        vd.byte[i] <- vs1.byte[i]
```

Negative elements are replaced with zero. Nonnegative elements pass through unchanged.

**Encoding**

```text
15              9 8       6 5       3 2       0
+----------------+---------+---------+---------+
|    0110010     |   vd    |   vs1   |   000   |
+----------------+---------+---------+---------+
```

**Condition Codes**

```text
ZCNV: not changed
```

**Nominal Cycles**

```text
5
```

---

### `VDOT vs1, vs2`

Signed Vector Dot Product and Accumulate

**Semantics**

Each vector is interpreted as eight signed 8-bit elements.

```text
dot <- 0

for i = 0 to 7:
    dot <- dot + signed(vs1.byte[i]) * signed(vs2.byte[i])

ACC <- ACC + dot
```

The eight signed products are accumulated into a signed 32-bit dot-product result, which is then added to `ACC`.

**Encoding**

```text
15              9 8       6 5       3 2       0
+----------------+---------+---------+---------+
|    0110011     |   000   |   vs1   |   vs2   |
+----------------+---------+---------+---------+
```

**Condition Codes**

```text
ZCNV: not changed
```

**Nominal Cycles**

```text
5
```

---

### `VACLR`

Clear Vector Accumulator

**Semantics**

```text
ACC <- 0
```

**Encoding**

```text
15              9 8       6 5       3 2       0
+----------------+---------+---------+---------+
|    0110100     |   000   |   000   |   000   |
+----------------+---------+---------+---------+
```

**Condition Codes**

```text
ZCNV: not changed
```

**Nominal Cycles**

```text
5
```

---

### `VLD vd, rs1, imm`

Vector Load

**Semantics**

```text
EA <- rs1 + imm

vd[15:0]  <- M[EA]
vd[31:16] <- M[EA + 2]
vd[47:32] <- M[EA + 4]
vd[63:48] <- M[EA + 6]
```

`VLD` loads one 64-bit vector from four consecutive 16-bit memory words.

The effective address is word-aligned using the normal RISC240 addressing rules.

**Encoding**

First word:

```text
15              9 8       6 5       3 2       0
+----------------+---------+---------+---------+
|    0110101     |   vd    |   rs1   |   000   |
+----------------+---------+---------+---------+
```

Second word:

```text
15                                                0
+--------------------------------------------------+
|                       imm                        |
+--------------------------------------------------+
```

**Condition Codes**

```text
ZCNV: not changed
```

**Nominal Cycles**

```text
16
```

---

### `VST rs1, vs2, imm`

Vector Store

**Semantics**

```text
EA <- rs1 + imm

M[EA]     <- vs2[15:0]
M[EA + 2] <- vs2[31:16]
M[EA + 4] <- vs2[47:32]
M[EA + 6] <- vs2[63:48]
```

`VST` stores one 64-bit vector into four consecutive 16-bit memory words.

The effective address is word-aligned using the normal RISC240 addressing rules.

**Encoding**

First word:

```text
15              9 8       6 5       3 2       0
+----------------+---------+---------+---------+
|    0111011     |   000   |   rs1   |   vs2   |
+----------------+---------+---------+---------+
```

Second word:

```text
15                                                0
+--------------------------------------------------+
|                       imm                        |
+--------------------------------------------------+
```

**Condition Codes**

```text
ZCNV: not changed
```

**Nominal Cycles**

```text
15
```

---

## 6. Assembly Examples

### Vector Addition

```asm
        LI      r1, $0100

        VLD     v1, r1, 0
        VLD     v2, r1, 8

        VADD    v3, v1, v2

        VST     r1, v3, 16
        STOP
```

This program:

1. Loads a vector from `$0100` into `v1`
2. Loads a vector from `$0108` into `v2`
3. Adds the vectors element by element
4. Stores the result beginning at `$0110`

### Dot Product

```asm
        LI      r1, $0100

        VLD     v1, r1, 0
        VLD     v2, r1, 8

        VACLR
        VDOT    v1, v2

        STOP
```

After execution, `ACC` contains the signed dot product of `v1` and `v2`.

---

## 7. Memory Layout Example

The following data defines two 64-bit vectors beginning at `$0100`.

```asm
        .ORG    $0100

        ; Vector 1
        .DW     $0201
        .DW     $0403
        .DW     $0605
        .DW     $0807

        ; Vector 2
        .DW     $0101
        .DW     $0101
        .DW     $0101
        .DW     $0101
```

After loading the first vector:

```text
v1 = $0807060504030201
```

The lowest-addressed memory word becomes bits `[15:0]` of the vector register.

---

## 8. Notes

- Scalar registers are named `r0` through `r7`.
- Vector registers are named `v0` through `v7`.
- Vector arithmetic operates on eight 8-bit elements.
- Vector memory operations transfer four 16-bit words.
- `VMUL` stores the low eight bits of each element product.
- `VRELU` and `VDOT` interpret each 8-bit element as signed two's-complement data.
- `VDOT` accumulates into `ACC`; use `VACLR` before a new independent dot product.
- The opcode values listed in this document come from the instruction-state encodings in `constants.sv`.
- Internal states such as `VLD1` through `VLD11` and `VST1` through `VST10` are microarchitectural FSM states, not programmer-visible instructions.
