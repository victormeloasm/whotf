; whotf_tiny — handcrafted overlapping-header ELF64 for Linux x86-64
; FASM build: fasm whotf_tiny.asm whotf_tiny && chmod +x whotf_tiny
;
; Effective UID -> matching local /etc/passwd username + newline.
; No libc, no linker, no external programs. No NSS/LDAP support.
; Strictly size-focused: the ELF program header starts at offset 0x38,
; overlapping the last eight bytes of the ELF file header.
;
; IMPORTANT: the overlap sets e_shnum=5 even though e_shoff=0.
; Linux executes this file, but some ELF inspection tools report a
; malformed/missing section table. This is deliberate, NOT a fully
; ELF-spec-conforming header. See note in explanation.

format binary
use64
ELF_BASE = 0x400000
org ELF_BASE

; ELF64 file header (0x00..0x3f)
    db 0x7f, 'ELF', 2, 1, 1, 0
    rb 8
    dw 2, 62                  ; ET_EXEC, EM_X86_64
    dd 1                      ; EV_CURRENT
    dq start                  ; e_entry
    dq phdr - ELF_BASE        ; e_phoff = 0x38
    dq 0                      ; e_shoff
    dd 0                      ; e_flags
    dw 64, 56                 ; e_ehsize, e_phentsize

; The following eight bytes are BOTH:
;   e_phnum=1, e_shentsize=0, e_shnum=5, e_shstrndx=0
; AND p_type=PT_LOAD, p_flags=PF_R|PF_X of the program header.
phdr:
    dd 1, 5                   ; PT_LOAD, R|X
    dq 0                      ; p_offset
    dq ELF_BASE               ; p_vaddr
    dq ELF_BASE               ; p_paddr
    dq image_end - ELF_BASE   ; p_filesz
    dq image_end - ELF_BASE   ; p_memsz
    dq 0x1000                 ; p_align

; Entry = file offset 0x70 = virtual address 0x400070
start:
    push 107                  ; sys_geteuid
    pop rax
    syscall
    mov ebp, eax              ; effective UID

    mov edi, passwd           ; statically linked ET_EXEC, address fits 32-bit
    xor esi, esi              ; O_RDONLY
    push 2                    ; sys_open
    pop rax
    syscall
    test eax, eax
    js failed
    mov ebx, eax              ; fd

    sub rsp, 264              ; 1-byte read + up to 255-byte username + LF

reset_line:
    lea r9, [rsp+1]           ; end of buffered username
    xor r8d, r8d              ; colon count
    xor r10d, r10d            ; parsed UID

read_one:
    xor eax, eax              ; sys_read
    mov edi, ebx              ; fd
    mov rsi, rsp              ; temporary 1-byte buffer
    push 1
    pop rdx
    syscall
    dec eax                   ; require exactly one byte (including EOF check)
    jne failed

    mov al, [rsp]
    cmp al, 10
    je reset_line
    cmp al, ':'
    je next_colon

    test r8d, r8d
    jz append_name            ; field 0: username
    cmp r8d, 2
    jne read_one              ; ignore password and remaining fields

    sub al, '0'               ; field 2: decimal UID
    cmp al, 9
    ja read_one
    imul r10d, r10d, 10
    movzx eax, al
    add r10d, eax
    jmp read_one

append_name:
    lea rdx, [rsp+256]
    cmp r9, rdx               ; bounds check: max 255 bytes
    jae failed
    mov [r9], al
    inc r9
    jmp read_one

next_colon:
    inc r8d
    cmp r8d, 3
    jne read_one
    cmp r10d, ebp
    jne read_one

    mov byte [r9], 10         ; append newline
    mov rdx, r9
    sub rdx, rsp              ; name size + newline
    push 1                    ; sys_write
    pop rax
    push 1                    ; stdout
    pop rdi
    lea rsi, [rsp+1]
    syscall
    xor edi, edi              ; success
    jmp exit

failed:
    push 1                    ; failure exit code
    pop rdi
exit:
    push 60                   ; sys_exit
    pop rax
    syscall

passwd db '/etc/passwd', 0
image_end:
