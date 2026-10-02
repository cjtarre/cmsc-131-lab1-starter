;
; decode.asm - extract every field from a 20-byte IPv4 header.
;
; This is your starting point. It assembles and links as-is, so the build
; works before you write any code. Right now it stores nothing, so renpkt
; prints the zeros driver.c put in the struct. Your job is to replace that
; with the extraction described below.
;
; The contract, from driver.c:
;
;       struct ipv4_fields *out   [ebp+12]
;       unsigned char *hdr        [ebp+8]
;
; hdr points at twenty bytes in network byte order. out points at the struct
; documented in driver.c. Its offsets are:
;
;   +0 version   +4 ihl    +8 dscp   +12 ecn   +16 total_length
;   +20 identification    +24 flags  +28 fragment_offset
;   +32 ttl      +36 protocol       +40 checksum
;   +44 src[0..3]                   +48 dst[0..3]
;
; Every int member is 4 bytes, so a plain 32-bit store fills one. The
; addresses are four single-byte stores each.
;
; Do not clobber ebx, esi, edi, or ebp. C assumes they survive your call.
; Return in eax (driver.c ignores it here, so returning 0 is fine).
;

; Windows C puts a leading underscore on every exported name. Linux C does
; not. The Makefile passes -d ELF_TYPE on Linux. This block then respells
; the names below to match. asm_io.inc does the same for _asm_main in the
; bootcamp blocks. Leave this block alone.
%ifdef ELF_TYPE
  %define _decode_header decode_header
  section .note.GNU-stack noalloc noexec nowrite progbits
%endif

segment .text
        global  _decode_header
_decode_header:
        enter   0,0
        pusha

        ;
        ; TODO: read the header and fill the struct.
        ;
        ; The field-by-field layout is the table in the manual. The notes
        ; that matter before you start:
        ;
        ;   * Every multi-byte field is big-endian, so load it byte by byte
        ;     and recombine. A single 16-bit load gives you the bytes
        ;     reversed.
        ;   * The fragment offset straddles a byte boundary. Its top five
        ;     bits live in byte 6 and its bottom eight in byte 7. Combine
        ;     both bytes into one word first, then shift and mask.
        ;   * The flags are the top three bits of the same word.
        ;   * Read and store the checksum field like any other field.
        ;     ip_checksum computes the VALID line separately.
        ;   * src and dst are four single-byte stores each. No shifting.
        ;
        ; Nothing here reads the file or prints. This routine only fills
        ; the struct, and driver.c does the rest.
        ;
;VERSION & IHL : BYTE 0
        ;load args
        mov     esi, [ebp+8] ; points to ipv4 header
        mov     edi, [ebp+12] ; points to output 

        ;extract byte 0
        mov     al, [esi]         ;al = byte 0

        ; get version
        movzx   eax, al           ;copy al to eax then zero extend
        shr     eax, 4            ;shift right to remove the IHL and get only the version
        mov     [edi+0], eax      ;store to output

        mov     al, [esi]         ;al = byte 0

        ; get IHL
        movzx   eax, al           ;copy al to eax then zero extend
        and     eax, 0x0F         ;mask and get only the 4 lower bits
        mov     [edi+4], eax      ;store to output



;DSCP & ECN : BYTE1
        ;extract byte1                  
        mov     al, [esi+1]       ;al = byte 1

        ;get DSCP 
        movzx   eax, al           ; copy al to eax then zero extend
        shr     eax, 2            ; shift right by 2 to remove ecn and get only dscp
        mov     [edi+8], eax      ; store to output

        ; get ECN
        mov     al, [esi+1]
        movzx   eax, al           ; copy al to eax then zero extend
        and     eax, 0x03         ; mask and get only the 2 lower bits
        mov     [edi+12], eax     ; store to output

;TOTAL LENGTH : BYTES 2&3
        ; extract bytes 2 and 3
        xor     eax, eax          ; remove garbage in eax
        mov     ah,[esi+2]       ; ah=byte 2
        mov     al, [esi+3]       ; al=byte 3
        mov     [edi+16], eax     ; store to output

;IDENTIFICATION : BYTES 4&5
        ; extract bytes 4 and 5
        xor     eax, eax          ;remove garbage in eax
        mov     ah, [esi+4]       ; ah=byte 4
        mov     al, [esi+5]       ; al =byte 5
        mov     [edi+20], eax     ; store to output

;FLAGS & FRAGMENT OFFSET : BYTES 6&7
        ; extract bytes 6 and 7
        xor     eax, eax          ; remove garbage in eax
        mov     ah, [esi+6]       ; ah=byte6
        mov     al, [esi+7]       ; al=byte 7

        ; get flags
        shr     eax, 13           ; shift right by 13 to keep top 3 bits as flags
        mov     [edi+24], eax     ; store to output

        ; get fragment offset
        xor     eax, eax          ; remove garbage in eax
        mov     ah, [esi+6]       ; ah=byte6
        mov     al, [esi+7]       ; al= byte7
        and     eax, 0x1FFF       ; mask top 3 bits to get only lower 13 bits
        mov     [edi+28], eax     ; store to output

;TTL : BYTE8
        mov     al, [esi+8]       ; al = byte 8
        movzx   eax, al           ; copy al to eax then zero extend
        mov     [edi+32], eax     ; store to output

;PROTOCOL : BYTE9
        mov     al, [esi+9]       ; al = byte 9
        movzx   eax, al           ; copy al to eax then zero extend
        mov     [edi+36], eax     ; store to output


;HEADER CHECKSUM : BYTES 10&11
        ; extract bytes 10 and 11
        xor     eax, eax          ; clear garbage in eax
        mov     ah, [esi+10]      ; ah = byte10
        mov     al, [esi+11]      ; al=byte 11 
        mov     [edi+40], eax     ; store to output

;SOURCE ADDRESS : BYTES 12-15
        ;direct extract octet then store to output since single byte arrays
        mov     al, [esi+12]      ; octet0
        mov     [edi+44], al      ; store to src[0]

        mov     al, [esi+13]      ; octet1
        mov     [edi+45], al      ;store to src[1]

        mov     al, [esi+14]      ; octet2
        mov     [edi+46], al      ;store to src[2]

        mov     al, [esi+15]      ; octet3
        mov     [edi+47], al      ;store to src[3]

        ;DESTINATION ADDRESS : BYTES 16 TO 19
        ;direct extract octet then store to output since single byte arrays

        mov     al, [esi+16]      ; octet0
        mov     [edi+48], al      ;store to dist[0]

        mov     al, [esi+17]      ; octet1
        mov     [edi+49], al      ;store to dist[1]

        mov     al, [esi+18]      ; octet2
        mov     [edi+ 50], al     ;store to dist[2]

        mov     al, [esi+19]      ; octet3  
        mov     [edi+51], al      ;store to dist[3]

        popa
        mov     eax, 0
        leave
        ret
