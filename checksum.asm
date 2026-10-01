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
        enter   0,0
        pusha

        ; ESI = pointer to header
        mov     esi, [ebp+8]

        ; ECX = number of bytes to process
        mov     ecx, [ebp+12]

        ; EDX = 32-bit accumulator
        xor     edx, edx

.loop:
        ; Build a 16-bit big-endian word:
        ; word = (hdr[i] << 8) | hdr[i+1]

        movzx   eax, byte [esi]
        shl     eax, 8

        movzx   ebx, byte [esi+1]
        or      eax, ebx

        ; Add the word to the accumulator
        add     edx, eax

        ; Move to the next word
        add     esi, 2
        sub     ecx, 2
        jnz     .loop

        popa
        mov     eax, 0
        leave
        ret