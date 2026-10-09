;
; encode.asm - build a 20-byte IPv4 header from the field struct.
;
; Reads the fields from the ipv4_fields struct (driver.c) and writes them
; into a 20-byte buffer in network byte order, then computes and inserts
; the header checksum.
;
; Contract (cdecl, from driver.c):
;       struct ipv4_fields *in    [ebp+8]
;       unsigned char *hdr        [ebp+12]
;
; Register plan (note: the opposite of decode.asm):
;   esi = pointer to the input struct
;   edi = pointer to the 20-byte output buffer
;   eax, ebx = scratch for building each value
;

%ifdef ELF_TYPE
  %define _ip_checksum ip_checksum
  %define _encode_header encode_header
  section .note.GNU-stack noalloc noexec nowrite progbits
%endif

; ---- Byte positions inside the 20-byte header ----
HDR_VER_IHL     equ 0       ; version + IHL share byte 0
HDR_DSCP_ECN    equ 1       ; DSCP + ECN share byte 1
HDR_TOTAL_LEN   equ 2       ; bytes 2-3
HDR_ID          equ 4       ; bytes 4-5
HDR_FLAGS_FRAG  equ 6       ; bytes 6-7: flags + fragment offset share a word
HDR_TTL         equ 8
HDR_PROTOCOL    equ 9
HDR_CHECKSUM    equ 10      ; bytes 10-11
HDR_SRC         equ 12      ; bytes 12-15
HDR_DST         equ 16      ; bytes 16-19
HDR_LEN         equ 20      ; the base header is always 20 bytes

; ---- Offsets inside struct ipv4_fields (from driver.c) ----
; The eleven int members are 4 bytes each, so they sit at multiples of 4.
; The src and dst arrays are single bytes and start right after, at +44.
F_DSCP          equ 8
F_ECN           equ 12
F_TOTAL_LEN     equ 16
F_ID            equ 20
F_FLAGS         equ 24
F_FRAG_OFFSET   equ 28
F_TTL           equ 32
F_PROTOCOL      equ 36
F_SRC           equ 44
F_DST           equ 48
; version, ihl, and checksum are never read: the encoder always writes
; version 4 / IHL 5 and computes its own checksum.

; ---- Constants, with the reason for each ----
VERSION_IHL_BYTE equ 0x45   ; version 4 in the top 4 bits, IHL 5 in the bottom 4
DSCP_MASK       equ 0x3F    ; 6 one-bits: DSCP is 6 bits wide
DSCP_SHIFT      equ 2       ; moves DSCP above the 2 ECN bits
ECN_MASK        equ 0x03    ; 2 one-bits: ECN is 2 bits wide
FLAGS_MASK      equ 0x07    ; 3 one-bits: flags are 3 bits wide
FLAGS_SHIFT     equ 13      ; moves flags above the 13-bit fragment offset
FRAG_MASK       equ 0x1FFF  ; 13 one-bits: the offset is 13 bits wide
BYTE_BITS       equ 8       ; bits in one byte
LOW_BYTE_MASK   equ 0xFF    ; keeps the low byte of a 16-bit value
HIGH_BYTE_MASK  equ 0xFF00  ; keeps the high byte of a 16-bit value

extern _ip_checksum

segment .text
        global  _encode_header
_encode_header:
        enter   0,0
        pusha

        ; load arguments
        mov     edi, [ebp+12]                       ; edi = the 20-byte buffer
        mov     esi, [ebp+8]                        ; esi = the struct

; VERSION & IHL : BYTE 0
        ; always 4 and 5 in this activity, so one fixed byte is written
        mov     byte [edi + HDR_VER_IHL], VERSION_IHL_BYTE

; DSCP & ECN : BYTE 1
        mov     eax, [esi + F_DSCP]
        and     eax, DSCP_MASK                      ; keep only 6 bits
        shl     eax, DSCP_SHIFT                     ; make room for ECN below
        mov     ebx, [esi + F_ECN]
        and     ebx, ECN_MASK                       ; keep only 2 bits
        or      eax, ebx                            ; DSCP on top, ECN on bottom
        mov     [edi + HDR_DSCP_ECN], al

; TOTAL LENGTH : BYTES 2-3
        ; the network wants the high byte first, so ah is stored first
        mov     eax, [esi + F_TOTAL_LEN]
        mov     [edi + HDR_TOTAL_LEN], ah           ; high byte
        mov     [edi + HDR_TOTAL_LEN + 1], al       ; low byte

; IDENTIFICATION : BYTES 4-5
        mov     eax, [esi + F_ID]
        mov     [edi + HDR_ID], ah                  ; high byte
        mov     [edi + HDR_ID + 1], al              ; low byte

; FLAGS & FRAGMENT OFFSET : BYTES 6-7
        ; build one 16-bit word first: flags on top, offset below
        mov     eax, [esi + F_FLAGS]
        and     eax, FLAGS_MASK                     ; keep only 3 bits
        shl     eax, FLAGS_SHIFT                    ; put them above the 13 offset bits
        mov     ebx, [esi + F_FRAG_OFFSET]
        and     ebx, FRAG_MASK                      ; keep only 13 bits
        or      eax, ebx                            ; the combined word
        mov     [edi + HDR_FLAGS_FRAG], ah          ; high byte
        mov     [edi + HDR_FLAGS_FRAG + 1], al      ; low byte

; TTL : BYTE 8
        mov     eax, [esi + F_TTL]
        mov     [edi + HDR_TTL], al                 ; TTL is 8 bits, so al holds all of it

; PROTOCOL : BYTE 9
        mov     eax, [esi + F_PROTOCOL]
        mov     [edi + HDR_PROTOCOL], al

; SOURCE ADDRESS : BYTES 12-15
        ; octets are single bytes, so they copy straight across
        mov     al, [esi + F_SRC]
        mov     [edi + HDR_SRC], al
        mov     al, [esi + F_SRC + 1]
        mov     [edi + HDR_SRC + 1], al
        mov     al, [esi + F_SRC + 2]
        mov     [edi + HDR_SRC + 2], al
        mov     al, [esi + F_SRC + 3]
        mov     [edi + HDR_SRC + 3], al

; DESTINATION ADDRESS : BYTES 16-19
        mov     al, [esi + F_DST]
        mov     [edi + HDR_DST], al
        mov     al, [esi + F_DST + 1]
        mov     [edi + HDR_DST + 1], al
        mov     al, [esi + F_DST + 2]
        mov     [edi + HDR_DST + 2], al
        mov     al, [esi + F_DST + 3]
        mov     [edi + HDR_DST + 3], al

; HEADER CHECKSUM : BYTES 10-11 (computed last)
        ; the checksum field must read as zero while it is being computed
        mov     byte [edi + HDR_CHECKSUM], 0
        mov     byte [edi + HDR_CHECKSUM + 1], 0
        push    dword HDR_LEN                       ; second argument: length
        push    edi                                 ; first argument: header pointer
        call    _ip_checksum
        add     esp, 8                              ; cdecl: the caller removes its arguments
        ; the result comes back in ax: ah is the high byte, al is the low byte
        mov     [edi + HDR_CHECKSUM], ah            ; high byte goes first
        mov     [edi + HDR_CHECKSUM + 1], al        ; then the low byte

        popa
        mov     eax, 0                              ; set after popa so it isn't overwritten
        leave
        ret