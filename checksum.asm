;
; checksum.asm - the one's complement internet checksum.
;

%ifdef ELF_TYPE
  %define _ip_checksum ip_checksum
  section .note.GNU-stack noalloc noexec nowrite progbits
%endif

segment .text
        global  _ip_checksum
_ip_checksum:
        enter   4,0
        pusha

        mov     esi, [ebp+8]            ; ESI = pointer to header        
        mov     ecx, [ebp+12]           ; ECX = number of bytes to process

        xor     edx, edx                ; EDX = 32-bit accumulator
                                        ; clears edx to 0

.loop:
        ; Build a 16-bit big-endian word:
        ; word = (hdr[i] << 8) | hdr[i+1]

        movzx   eax, byte [esi]         ; grabs 1 byte from pointer, zero fill the rest
        shl     eax, 8                  ; move to upper half of 16-bit

        movzx   ebx, byte [esi+1]       ; grabs adjacent byte
        or      eax, ebx                ; merge into eax as 16-bit

        add     edx, eax                ; Add the word to the accumulator

        ; Move to the next word
        add     esi, 2                  ; move pointer forward by 2 bytes
        sub     ecx, 2                  ; decrement counter by 2
        jnz     .loop                   ; loop if not yet 0

.fold:
        ; Add the high 16 bits to the low 16 bits
        mov     eax, edx                ; copy the accumulator
        shr     eax, 16                 ; high 16 bits
        and     edx, 0xFFFF             ; mask to keep low 16 bits
        add     edx, eax                ; add high and low bits

        ; A second fold may be necessary
        cmp     edx, 0xFFFF             ; check if there's still overflow
        ja      .fold                   ; if edx is not zero

        ; One's complement of the 16-bit result
        mov     eax, edx                ; clean fold sum
        not     ax                      ; invert
        movzx   eax, ax                 ; erase upper half of inversion

        mov     [ebp-4], eax            ; Save result because popa restores EAX

        popa
       
        mov     eax, [ebp-4]            ; Restore checksum as return value

        leave
        ret
