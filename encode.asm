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

; Load args
        mov     edi, [ebp+12]           ; edi = the 20-byte buffer
        mov     esi, [ebp+8]            ; esi = the struct

; BYTE 0 (Version & IHL) version + IHL 
; fixed, see VERSION_IHL_BYTE
        mov     byte [edi+0], VERSION_IHL_BYTE

; BYTE 1 (DSCP & ECN)
; 6 bits and 2 bits respectively
        mov     eax, [esi+8]            ; loads DSCP field
        and     eax, 0x3F               ; mask to keep 6 low bits
        shl     eax, 2                  ; make room for ECN bits

        mov     ebx, [esi+12]           ; loads ECN field
        and     ebx, 0x03               ; mask to keep 2 low bits
        or      eax, ebx                ; combines masked ECN into shifted DSCP
        mov     [edi+1], al             ; write into buffer

; BYTE 2 & 3 (TOTAL LENGTH)
; 16 bits, write into big endian form
        mov     eax, [esi+16]           ; loads total length
        mov     ebx, eax                ; copy it to ebx

        and     eax, 0xFF               ; isolate low byte
        shl     eax, 8                  ; shift to high byte
        
        and     ebx, 0xFF00             ; isolate high byte     (can be skipped actually)
        shr     ebx, 8                  ; shift to low byte     (shr already pushes out the bits)

        ; byte swap
        or      eax, ebx                ; the 16-bit store reverses them back
        mov     [edi+2], ax             ; write into buffer

; BYTE 4 & 5 (IDENTIFICATION)
; 16 bits, write into big endian form
; same process as TOTAL LENGTH
        mov     eax, [esi+20]           
        mov     ebx, eax

        and     eax, 0xFF
        shl     eax, 8
        
        and     ebx, 0xFF00
        shr     ebx, 8
        
        ; byte swap
        or      eax, ebx
        mov     [edi+4], ax

; BYTE 6 & 7 (FLAGS & FRAGMENT OFFSET)
; 3 bits reserved for flags, 13 bits for frag offset
        mov     eax, [esi+24]           ; loads flags
        and     eax, 0x07               ; mask to keep lower 3 bits
        shl     eax, 13                 ; move them for offset's 13 bits

        mov     ebx, [esi+28]           ; loads fragment offset
        and     ebx, 0x1FFF             ; mask to keep lower 13 bits
        
        or      eax, ebx                ; merge into 16-bit
        mov     ebx, eax                ; make a copy

        ; then byte swap procedure as before
        and     eax, 0xFF
        shl     eax, 8

        and     ebx, 0xFF00
        shr     ebx, 8
        
        or      eax, ebx
        mov     [edi+6], ax             ; write into buffer

; BYTE 8 (TTL)
; 8 bits
        mov     eax, [esi+32]           ; loads TTL
        mov     [edi+8], al             ; write directly into buffer

; BYTE 9 (PROTOCOL)
; 8 bits
        mov     eax, [esi+36]           ; loads protocol
        mov     [edi+9], al             ; write directly into buffer

; BYTES 12 - 15 (SOURCE ADDRESS)
; 4 octets of 8 bits
; loads and writes into buffer, one byte at a time
; assumes it is already in big endian order
        mov     al, [esi+44]            
        mov     [edi+12], al
        mov     al, [esi+45]
        mov     [edi+13], al
        mov     al, [esi+46]
        mov     [edi+14], al
        mov     al, [esi+47]
        mov     [edi+15], al

; BYTES 16 - 19 (DESTINATION ADDRESS)
; 4 octets of 8 bits
; same behavior as SOURCE ADDRESS
        mov     al, [esi+48]
        mov     [edi+16], al
        mov     al, [esi+49]
        mov     [edi+17], al
        mov     al, [esi+50]
        mov     [edi+18], al
        mov     al, [esi+51]
        mov     [edi+19], al

; BYTES 10 & 11 (HEADER CHECKSUM)
; computed last
        mov     byte [edi+10], 0        ; clear out checksum field
        mov     byte [edi+11], 0        ; must be zero while computing

        push    dword 20                ; second argument: length
        push    edi                     ; first argument: header pointer

        call    _ip_checksum            ; computes checksum, returns into eax
        add     esp, 8                  ; clean stack pointer (discards the two args)

        mov     ebx, eax                ; copy for extraction
        shr     ebx, 8                  ; high byte

        mov     [edi+10], bl            ; high byte goes first
        mov     [edi+11], al            ; then the low byte

        popa
        mov     eax, 0
        leave
        ret
