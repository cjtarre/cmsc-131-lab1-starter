;
; encode.asm - build a 20-byte IPv4 header from the field struct.
;
; This is your starting point. It assembles and links as-is, so the build
; works before you write any code. Right now it writes nothing, so the
; twenty bytes driver.c saves are whatever the buffer held. Your job is to
; replace that with the construction described below.
;
; The contract, from driver.c:
;
;       unsigned char *hdr        [ebp+12]
;       struct ipv4_fields *in    [ebp+8]
;
; driver.c documents the struct layout:
;
;   +0 version   +4 ihl    +8 dscp   +12 ecn   +16 total_length
;   +20 identification    +24 flags  +28 fragment_offset
;   +32 ttl      +36 protocol       +40 checksum
;   +44 src[0..3]                   +48 dst[0..3]
;
; You write twenty bytes into hdr. Every multi-byte field goes out
; big-endian: the high byte first. The fragment offset's top five bits share
; byte 6 with the three flag bits. Its bottom eight bits are byte 7.
;
; The checksum is your job too. Bytes 10-11 must read as zero while the
; checksum is computed. Write them as zero, call ip_checksum over the
; finished header, and store its result into the field. The struct's
; checksum member is read on the decode path only. Don't copy it here.
;
; Do not clobber ebx, esi, edi, or ebp. C assumes they survive your call.
; Return in eax (driver.c ignores it here, so returning 0 is fine).
;

; Windows C puts a leading underscore on every exported name. Linux C does
; not. The Makefile passes -d ELF_TYPE on Linux. This block then respells
; the names below to match. asm_io.inc does the same for _asm_main in the
; bootcamp blocks. Leave this block alone.
%ifdef ELF_TYPE
  %define _ip_checksum ip_checksum
  %define _encode_header encode_header
  section .note.GNU-stack noalloc noexec nowrite progbits
%endif

; Byte 0 is always 0x45: version 4 in the top 4 bits, IHL 5 in the bottom 4 bits.
VERSION_IHL_BYTE equ 0x45
extern _ip_checksum

segment .text
        global  _encode_header
_encode_header:
        enter   0,0
        pusha

        mov     edi, [ebp+12]               ; edi = the 20-byte buffer
        mov     esi, [ebp+8]                ; esi = the struct

        ; byte 0 = version + IHL (fixed, see VERSION_IHL_BYTE)
        mov     byte [edi+0], VERSION_IHL_BYTE

        ; byte 1 = DSCP (6 bits) + ECN (2 bits)
        mov     eax, [esi+8]
        and     eax, 0x3F                   ; DSCP is 6 bits wide
        shl     eax, 2                      ; move it above ECN's 2 bits
        mov     ebx, [esi+12]
        and     ebx, 0x03                   ; ECN is 2 bits wide
        or      eax, ebx
        mov     [edi+1], al

        ; bytes 2-3 = total length (16 bits, big-endian)
        mov     eax, [esi+16]
        mov     ebx, eax
        and     eax, 0xFF                   ; low byte
        shl     eax, 8
        and     ebx, 0xFF00                 ; high byte
        shr     ebx, 8
        or      eax, ebx                    ; bytes swapped; the 16-bit store reverses them back
        mov     [edi+2], ax

        ; bytes 4-5 = identification (16 bits, big-endian)
        mov     eax, [esi+20]
        mov     ebx, eax
        and     eax, 0xFF
        shl     eax, 8
        and     ebx, 0xFF00
        shr     ebx, 8
        or      eax, ebx
        mov     [edi+4], ax

        ; bytes 6-7 = flags (3 bits) + fragment offset (13 bits)
        mov     eax, [esi+24]
        and     eax, 0x07                   ; flags are 3 bits wide
        shl     eax, 13                     ; move them above the offset's 13 bits
        mov     ebx, [esi+28]
        and     ebx, 0x1FFF                 ; offset is 13 bits wide
        or      eax, ebx
        mov     ebx, eax
        and     eax, 0xFF
        shl     eax, 8
        and     ebx, 0xFF00
        shr     ebx, 8
        or      eax, ebx
        mov     [edi+6], ax

        ; byte 8 = TTL (8 bits)
        mov     eax, [esi+32]
        mov     [edi+8], al

        ; byte 9 = protocol (8 bits)
        mov     eax, [esi+36]
        mov     [edi+9], al

        ; bytes 12-15 = source address (4 octets of 8 bits)
        mov     al, [esi+44]
        mov     [edi+12], al
        mov     al, [esi+45]
        mov     [edi+13], al
        mov     al, [esi+46]
        mov     [edi+14], al
        mov     al, [esi+47]
        mov     [edi+15], al

        ; bytes 16-19 = destination address (4 octets of 8 bits)
        mov     al, [esi+48]
        mov     [edi+16], al
        mov     al, [esi+49]
        mov     [edi+17], al
        mov     al, [esi+50]
        mov     [edi+18], al
        mov     al, [esi+51]
        mov     [edi+19], al

        ; bytes 10-11 = checksum, computed last
        mov     byte [edi+10], 0            ; must be zero while computing
        mov     byte [edi+11], 0
        push    dword 20                    ; second argument: length
        push    edi                         ; first argument: header pointer
        call    _ip_checksum
        add     esp, 8                      ; remove the two arguments
        mov     ebx, eax
        shr     ebx, 8                      ; high byte
        mov     [edi+10], bl                ; high byte goes first
        mov     [edi+11], al                ; then the low byte

        popa
        mov     eax, 0
        leave
        ret
