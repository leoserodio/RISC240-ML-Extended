; Quick end-to-end program:
; Load two vectors, add them, store the result at $0110, and stop.

        LI    R1, $0100
        VLD   V1, R1, 0
        VLD   V2, R1, 8
        VADD  V3, V1, V2
        VST   R1, V3, 16
        STOP

        .ORG  $0100
        .DW   $0102
        .DW   $0304
        .DW   $0506
        .DW   $0708

        .DW   $0101
        .DW   $0101
        .DW   $0101
        .DW   $0101
