section .text

global my_printf   

BIN_SYSTEM          equ 1
OCT_SYSTEM          equ 3
DEC_SYSTEM          equ 10
HEX_SYSTEM          equ 4
SIZE_STACK_CELL     equ 8
SHIFT_POINTER_STACK equ 64
SIZE_BUFFER         equ 32                      ; forbidden to make the buffer smaller than 32 bits
MASK_BIN_SYSTEM     equ 0b1
MASK_OCT_SYSTEM     equ 0b111
MASK_HEX_SYSTEM     equ 0b1111
ERROR_PRINTF        equ -1

;------------------------------------------------
;       MACROS (output and clean buffer)
;       Entry: None
;       Exit : r15 = addr begin buffer
;       Destr: rax rsi rdi
;------------------------------------------------

%macro OUTPUT_BUFFER 0
                push rcx
                push rsi
                push rdi

                mov rcx, r15                    
                sub rcx, buffer
                add r13, rcx
                inc rcx                         ; rcx = len str for input

                mov rdx, rcx                    ; rdx = len str for input
                mov rax, 0x01                   ; number func output (write = 01)
                mov rdi, 1                      ; stdout
                mov rsi, buffer                 ; rsi = addr for buffer
                syscall

                mov r15, buffer                 ; r15 = addr begin buffer

                pop rdi
                pop rsi
                pop rcx
%endmacro

;------------------------------------------------
;       Push argument and save registers
;       Entry: None
;       Exit : None
;       Destr: r10
;------------------------------------------------

my_printf:
                pop r10                         ; save addr return

                push r9                         ; 6 arg
                push r8                         ; 5 arg
                push rcx                        ; 4 arg
                push rdx                        ; 3 arg
                push rsi                        ; 2 arg
                push rdi                        ; 1 arg

                push rbp                        ;save registers
                push rbx 
                push r12 
                push r13 
                push r14 
                push r15

                call printf                     ; main func 

                pop r15                         ; recovery registers
                pop r14
                pop r13
                pop r12
                pop rbx
                pop rbp

                pop rdi                        
                pop rsi
                pop rdx
                pop rcx
                pop r8
                pop r9

                push r10                        ; recovery addr return      
                           
                ret

;------------------------------------------------
;       Main func. Output string
;       Entry: None
;       Exit : None
;       Destr: rax rcx rdi rsi r14 r15
;------------------------------------------------

printf:
                xor r13, r13                    ; count output smb
                cld                             ; flag DF = 0

                mov r15, buffer                 ; r15 = addr buffer for output
                mov r14, rdi                    ; r14 = first arg (format line)
                mov rbp, rsp                    ; rbp = rsp
                add rbp, SHIFT_POINTER_STACK    ; rbp = addr second arg (int stack)

                call my_strlen                  ; rcx = len format str from [rdi]

        .begin:
                mov rdi, r15                    ; rdi = current pointer on buffer 
                mov rsi, r14                    ; rsi = current pointer on format str

        .copy:
                lodsb                           ; al = ds:[rsi++]
                cmp al, '%'                     ; if (al == '%')
                je .switch                      ;       jmp .switch
                stosb                           ; es:[rdi++] = al
                loop .copy                      ; if (--rcx) jmp .copy
                push rcx                        ; save rcx
                jmp .end_switch                 ; if (rcx == 0) jmp. end_switch

        .switch:
                lodsb                           ; al = ds:[rsi++] - symbol after '%'
                sub rcx, 2                      ; skip '%' and symbol after '%'
                push rcx                        ; save rcx

                mov r14, rsi                    ; update current pointer on format str
                mov r15, rdi                    ; update current pointer on buffer

                cmp al, 'b'                     ; check al
                jl .error_case                  ; 'b' <= al <= 'x'
                cmp al, 'x'
                jg .error_case

                jmp qword [jmp_table_specifier + (rax - 'b') * 8]       ; jump on this label

        .error_case:
                cmp al, '%'                     ; if (al == '%')
                je print_percent                ;       jmp .case_percent

                mov rax, ERROR_PRINTF
                ret
                
        .end_switch:
                pop rcx                         ; if (rcx != 0)
                cmp rcx, 0                      ;       jmp .begin
                jne .begin
                
                OUTPUT_BUFFER                   ; macros

                mov rcx, r15                    ; rcx = current pointer on buffer 
                sub rcx, buffer                 ; rcx = length of the filled buffer
                add rcx, r13                    ; rcx += r13 (already printed smb);
                inc rcx                         ; rcx++
                mov rax, rcx                    ; rax = number output argument

                ret

;------------------------------------------------
;       Count length str
;       Entry: rdi - addr str
;       Exit : rcx - len str
;       Destr: rax
;------------------------------------------------

my_strlen:
                xor rax, rax                    ; rax = 0 ('\0')
                xor rcx, rcx                    ; rcx = 0
                dec rcx                         ; rcx = 0xFF...FF
                repne scasb                     ; while (rcx-- && byte [rdi++] != al) 
                neg rcx                         ; rcx = -rcx
                sub rcx, 2                      ; rcx -= 2

                ret

;------------------------------------------------
;       Parsing decimal number system
;       Entry: rbp - current value on stack
;              r15 - current pointer on buffer
;       Exit : None
;       Destr: rax rbx rcx rdx rdi 
;------------------------------------------------

print_dec:      
                mov rax, [rbp]                  ; rax - number argument 
                mov rdi, r15                    ; rdi - current pointer on buffer 

                cmp eax, 0                      ; if (eax > 0)
                jge .positive_num               ;       jmp .positive_num

                neg eax                         ; processing negative num
                mov byte [rdi], '-'             ; eax = -eax
                inc rdi                         ; putchar ('-') in buffer

        .positive_num:
                xor rcx, rcx                    ; rcx = 0
                mov ebx, DEC_SYSTEM             ; ebx = radix decimal

        .get_digit:
                xor edx, edx                    ; edx = 0
                div ebx                         ; eax = eax // ebx                        
                push rdx                        ; edx = eax % ebx
                inc rcx                         ; number of digits ++
                cmp eax, 0                      ; if (eax > 0)
                jg .get_digit                   ;       jmp .get_digit

                mov rax, SIZE_BUFFER
                sub rax, r15
                add rax, buffer                 ; rax = free space in buffer

                cmp rcx, rax                    ; if (len num >= free space)
                jge .output_buf                 ;       jmp .OUTPUT_BUFFER 
                jmp .put_digit
        
        .output_buf:
                OUTPUT_BUFFER                   ; macros 
                mov rdi, r15                    ; update rdi

        .put_digit:
                pop rax                         ; get digit
                add al, '0'                     ; digit -> ASCII code digit
                stosb                           ; es:[rdi++] = al
                loop .put_digit                 ; if (--rcx) jmp .put_digit

                mov r15, rdi                    ; update current pointer on buffer
                add rbp, SIZE_STACK_CELL        ; shift up rbp in stack

                jmp printf.end_switch           ; return

;------------------------------------------------
;       Parsing line of symbols
;       Entry: rbp - current value on stack
;              r15 - current pointer on buffer
;       Exit : None
;       Destr: rcx rsi rdi
;------------------------------------------------

print_str:
                mov rdi, [rbp]                  ; rdi = addr input str
                call my_strlen                  ; rcx = len input str

                cmp rcx, SIZE_BUFFER            ; if (len str >= SIZE_BUFFER)
                jge .output_buf_str             ;       jmp .output_buffer_str

                mov rax, SIZE_BUFFER            
                sub rax, r15
                add rax, buffer                 ; rax = free space in buffer

                cmp rcx, rax                    ; if (len str >= free space)
                jge .output_buf                 ;       jmp .OUTPUT_BUFFER

                jmp .write_buffer

        .output_buf_str:
                OUTPUT_BUFFER                   ; macros 
                                
                mov rsi, [rbp]                  ; rsi = addr for buffer
                mov rdx, rcx                    ; rdx = len str for input
                mov rax, 0x01                   ; number func output (write = 01)
                mov rdi, 1                      ; stdout
                syscall

                add rbp, SIZE_STACK_CELL        ; update current pointer on buffer

                jmp printf.end_switch           ; return

        .output_buf:
                OUTPUT_BUFFER                   ; macros
                
        .write_buffer:
                mov rsi, [rbp]                  ; rsi = addr input str
                mov rdi, r15                    ; rdi = current pointer on buffer 
                rep movsb                       ; [rdi++] = [rsi++]
                add rbp, SIZE_STACK_CELL        ; shift up rbp in stack
                mov r15, rdi                    ; update current pointer on buffer

                jmp printf.end_switch           ; return

;------------------------------------------------
;       Print symbol '%'
;       Entry: r15 - current pointer on buffer
;       Exit : None
;       Destr: rsi rdi
;------------------------------------------------

print_percent:
                mov rax, SIZE_BUFFER
                sub rax, r15
                add rax, buffer                 ; rax = free space in buffer

                mov rcx, 1                      ; 1 symbol
                cmp rcx, rax                    ; if (len num >= free space)
                jge .output_buf                 ;       jmp .OUTPUT_BUFFER 
                jmp .put_smb

        .output_buf:
                OUTPUT_BUFFER                   ; macros 
                
        .put_smb:
                mov rdi, '%'
                mov rsi, r15                    ; rsi = current pointer on buffer 
                mov [rsi], rdi                  ; [rsi] = ASCII code symbol
                inc r15                         ; update current pointer on buffer

                jmp printf.end_switch           ; return

;------------------------------------------------
;       Print one char-symbol in buffer
;       Entry: r15 - current pointer on buffer
;       Exit : None
;       Destr: rsi rdi
;------------------------------------------------

print_char:
                mov rax, SIZE_BUFFER
                sub rax, r15
                add rax, buffer                 ; rax = free space in buffer

                mov rcx, 1                      ; 1 symbol
                cmp rcx, rax                    ; if (len num >= free space)
                jge .output_buf                 ;       jmp .OUTPUT_BUFFER 
                jmp .put_smb

        .output_buf:
                OUTPUT_BUFFER                   ; macros 
                
        .put_smb:
                mov rdi, [rbp]                  ; rdi = symbol for print
                mov rsi, r15                    ; rsi = current pointer on buffer 
                mov [rsi], rdi                  ; [rsi] = ASCII code symbol
                inc r15                         ; update current pointer on buffer
                add rbp, SIZE_STACK_CELL        ; shift up rbp in stack

                jmp printf.end_switch           ; return

;------------------------------------------------
;       Print in different number systems
;       Entry: None
;       Exit : None
;       Destr: rcx
;------------------------------------------------

print_bin:
                mov ecx, BIN_SYSTEM      
                mov r11, MASK_BIN_SYSTEM                
                jmp print_bin_oct_hex           
print_oct:                                      
                mov ecx, OCT_SYSTEM             ; in these three functions
                mov r11, MASK_OCT_SYSTEM        ; we pass the values of 
                jmp print_bin_oct_hex           ; different number systems 
print_hex:                                      ; and call the general function
                mov ecx, HEX_SYSTEM
                mov r11, MASK_HEX_SYSTEM
                jmp print_bin_oct_hex

;------------------------------------------------
;       Print address
;       Entry: r15 - current pointer on buffer
;       Exit : None
;       Destr: rcx rsi
;------------------------------------------------

print_addr:
                mov rax, SIZE_BUFFER
                sub rax, r15
                add rax, buffer                 ; rax = free space in buffer

                mov rcx, 2                      ; 2 symbols '0x'
                cmp rcx, rax                    ; if (len num >= free space)
                jge .output_buf                 ;       jmp .OUTPUT_BUFFER 
                jmp .put_smb

        .output_buf:
                OUTPUT_BUFFER                   ; macros 
                
        .put_smb:
                mov rsi, r15                    ; rsi = current pointer on buffer 
                mov byte [rsi], '0'             ; mov "0x" in buffer
                inc rsi 
                mov byte [rsi], 'x'
                add r15, 2                      ; update current pointer on buffer
                mov ecx, HEX_SYSTEM             ; hex system
                mov r11, MASK_HEX_SYSTEM

                jmp print_bin_oct_hex           ; print value address

;------------------------------------------------
;       Passing the num of printed smb to arg
;       Entry: r15 - current pointer on buffer
;              rbp - current value on stack
;       Exit : None
;       Destr: rcx rsi
;------------------------------------------------

print_n:
                mov rcx, r15                    ; rcx = current pointer on buffer 
                sub rcx, buffer                 ; rcx = length of the filled buffer
                add rcx, r13                    ; rcx += r13 (already printed smb);
                mov rsi, [rbp]                  ; rsi = addr argument
                mov [rsi], rcx                  ; argument = rcx
                add rbp, SIZE_STACK_CELL        ; shift up rbp in stack

                jmp printf.end_switch           ; return

;------------------------------------------------
;       Parsing bin/oct/hex number system
;       Entry: rdi - ASCII code symbol
;              r15 - current pointer on buffer
;              rcx - log_2(number system)
;              r11 - mask number system 
;       Exit : None
;       Destr: rax rbx
;------------------------------------------------

print_bin_oct_hex:
                mov rax, [rbp]                  ; rax - number argument 
                mov rdi, r15                    ; rdi - current pointer on buffer 

                xor rbx, rbx                    ; rbx = 0

        .get_digit:
                mov rdx, rax                    ; rdx = rax
                and rdx, r11                    ; edx = last bits number
                push rdx                        ; save digit
                inc rbx                         ; counter++ (rbx)
                shr rax, cl                     ; eax = eax // (2 ^ cl)
                cmp rax, 0                      ; if (eax > 0)
                jg .get_digit                   ;       jump .get_digit

                mov rcx, rbx                    ; rcx = numbers of digit

                mov rax, SIZE_BUFFER
                sub rax, r15
                add rax, buffer                 ; rax = free space in buffer

                cmp rcx, rax                    ; if (len num >= free space)
                jge .output_buf                 ;       jmp .OUTPUT_BUFFER 
                jmp .put_digit
        
        .output_buf:
                OUTPUT_BUFFER                   ; macros 
                mov rdi, r15                    ; update rdi
                
        .put_digit:
                pop rax                         ; get digit

                cmp al, 10                      ; if (digit < 10)
                jl .dec                         ;       jump .dec
                jmp .hex                        ; else
                                                ;       jump .hex        
        .dec:        
                add al, '0'                     ; digit_dec -> ASCII code digit
                jmp .end
        .hex:
                add al, 'a' - 10                ; digit_hex -> ASCII code digit
        .end:
                stosb                           ; es:[rdi++] = al
                loop .put_digit                 ; if (--rcx) jmp .put_digit

                mov r15, rdi                    ; update current pointer on buffer
                add rbp, SIZE_STACK_CELL        ; shift up rbp in stack

                jmp printf.end_switch           ; return

section .rodata

jmp_table_specifier:
                dq print_bin
                dq print_char
                dq print_dec
                times 'n' - 'd' - 1 dq printf.error_case
                dq print_n
                dq print_oct
                dq print_addr
                times 's' - 'p' - 1 dq printf.error_case
                dq print_str
                times 'x' - 's' - 1 dq printf.error_case
                dq print_hex

section .data

buffer: db SIZE_BUFFER dup(0)


