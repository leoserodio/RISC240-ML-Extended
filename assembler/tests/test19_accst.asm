; ============================================================
; test19_accst.asm
;
; Verifies ACCST:
;   1. Positive 32-bit accumulator result
;   2. Low/high word memory ordering
;   3. Base + immediate addressing
;   4. Negative 32-bit accumulator result
;   5. VACLR between independent dot products
;
; Expected:
;
;   Positive dot:
;       8 * (127 * 127) = 129032 = $0001F808
;
;       M[$0204] = $F808
;       M[$0206] = $0001
;
;   Negative dot:
;       8 * (-128 * 127) = -130048 = $FFFE0400
;
;       M[$0208] = $0400
;       M[$020A] = $FFFE
; ============================================================

        LI      R1, $0100      ; Input vector A
        LI      R2, $0108      ; Input vector B
        LI      R3, $0110      ; Negative input vector
        LI      R4, $0200      ; Result memory base

; ------------------------------------------------------------
; Positive ACCST test
; ------------------------------------------------------------

        VLD     V1, R1, 0      ; V1 = eight signed 127 values
        VLD     V2, R2, 0      ; V2 = eight signed 127 values

        VACLR
        VDOT    V1, V2         ; ACC = $0001F808

        ACCST   R4, 4          ; Store at $0204 and $0206

; ------------------------------------------------------------
; Negative ACCST test
; ------------------------------------------------------------

        VLD     V3, R3, 0      ; V3 = eight signed -128 values

        VACLR
        VDOT    V3, V2         ; ACC = $FFFE0400

        ACCST   R4, 8          ; Store at $0208 and $020A

        STOP

; ------------------------------------------------------------
; Test data
; ------------------------------------------------------------

        .ORG    $0100

; Eight signed 127 values
VECTOR_POS_A:
        .DW     $7F7F
        .DW     $7F7F
        .DW     $7F7F
        .DW     $7F7F

; Eight signed 127 values
VECTOR_POS_B:
        .DW     $7F7F
        .DW     $7F7F
        .DW     $7F7F
        .DW     $7F7F

; Eight signed -128 values
VECTOR_NEG:
        .DW     $8080
        .DW     $8080
        .DW     $8080
        .DW     $8080

; ------------------------------------------------------------
; Result area
; ------------------------------------------------------------

        .ORG    $0200

RESULTS:
        .DW     $0000          ; $0200 untouched
        .DW     $0000          ; $0202 untouched

        .DW     $0000          ; $0204 positive low
        .DW     $0000          ; $0206 positive high

        .DW     $0000          ; $0208 negative low
        .DW     $0000          ; $020A negative high