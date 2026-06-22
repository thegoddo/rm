section .data ; initialized data (takes space)

  v_flag_str db "-v", 0 ; 0 for null terminator string
  i_flag_str db "-i", 0

  usage_msg db "the usage: ./rm <file1> <file2>...", 0 ; let's say this starts at address 1000
  ; The string takes up 23 bytes of memory

  ; $ defines the current address
  usage_msg_len equ $ - usage_msg ; The CPU is now at address 1023, $(current address) - ; usage_msg address

  deleted_msg db "deleted", 0
  deleted_msg_len equ $ - deleted_msg
  fstat_fail_msg db "fstat failed"
  fstat_fail_len equ $ - fstat_fail_msg
  newline db 10
  question_message db "do you want to delete this :", 0
  question_message_len equ $ - question_message

extern strcmp

section .bss  ; unitialized data (doen't take space)

  response resb 2
  v_flag resb 1
  i_flag resb 1

  


section .text ; CPU execute (takes space)

global _start

_start:
  mov rdi, [rsp] ; the argc
  lea rsi, [rsp + 16] ; the argv
  cmp rdi, 1
  je print_usage
  jmp program_end

  call main

; ###################### main function ############################
main:
  push rbp
  mov rbp, rsp
  
  ; big space between rsp and rbp
  sub rsp, 200; big value for saving struct info

  mov [rbp - 8], rdi; saving the argc
  mov [rbp - 16], rsi ; saving the argv
  ; linux system store argc in rdi
  ; linux system store argv in rsi
  ; so rbp - 8 is, go 8 word below and save rdi there
  ; so rbp - 16 is, go 16 words below and rsi there

  ; setting arguments for check_flag function
  mov rdi, [rbp - 8] ; passing the argc
  mov rsi, [rbp - 16]; passing the argv
  call check_flags

  mov r12, [rbp - 16]
  ; rax = 1 * 8 = 8, r12 + 8 = next argument
  ; rax = 2 * 8 = 16, r12 + 16 = second next argument
  imul rax, rax, 8 ; imul is signed multiply, multiply the third value to second and store in first. rax = rax * 8
  add r12, rax

delete_loop:
  mov rax, [r12]
  cmp rax, 0
  je delete_end
  ; call fstat syscall

  mov rax, 262  ; fstat syscall number
  mov rdi, -100 ; AT_FDCWD - use current directory
  mov rsi, [r12] ; file path (char *)
  mov rdx, [rsp + 48]  ; struct stat *
  mov r10, -0x100    ; behviour flags, watch don't follow any symlink like lstat
  syscall
  cmp rax, 0
  jne print_error
  mov eax, dword [rdx + 24]
  and rax, 0xF000
  cmp rax, 0x8000 ; this for a file
  je this_is_file
  cmp rax, 0x4000 ; this for dir
  je this_is_dir

this_is_dir:
  cmp byte [v_flag], 1
  je call_check_answer_dir

call_check_answer_dir:
  call check_answer
  cmp rax, 1
  je delete_dir
  jmp skip_delete


this_is_file:
  cmp byte i_flag, 1
  je call_check_answer_file

call_check_answer_file:
  call check_answer
  cmp rax, 1
  je delete_file
  jmp skip_delete

delete_file:
  mov rax, 87
  mov rdi, [r12]
  syscall
  cmp byte [v_flag], 1
  je print_deleted
  jmp skip_delete

delete_dir:
  mov rax, 40
  mov rdi, [r12]
  syscall
  cmp byte [v_flag] , 1
	je print_deleted
	jmp skip_delete

print_deleted:
  mov rax, 1
  mov rdi, 1
  mov rsi, deleted_msg
  mov rdx, deleted_msg_len
  syscall


  mov rdi, [r12]
  call strlen
  mov rdx, rax
  ; print the name of the element deleted
  mov rax, 1
  mov rdi, 1
  mov rsi, [r12]
  ; rdx has already the len
  syscall

  ; print new_line
  mov rax, 1
  mov rdi, 1
  mov rsi, new_line
  mov rdx, 1
  syscall

  ; increment r12 and jmp again to the looop
  add r12, 8
  jmp delete_loop
  

delete_end:
  jmp program_end

skip_delete:
  ; increment the r12 and jmp again to the loop
  add r12, 8
  jmp delete_loop

print_error:
  mov rax, 1
  mov rdi, 1
  mov rsi, fstat_fail_msg 
  mov rdx, fstat_fail_len
  syscall
  jmp skip_delete

print_usage:
  mov rax, 1
  mov rdi, 1
  mov rsi, usage_msg
  mov rdx, usage_msg_len
  syscall

program_end:
  mov rax, 60
  mov rdi, 0
  syscall




; ################## check flags function #######################
check_flags:
  push rbp
  mov rbp, rsp
  sub rsp, 48

  mov [rbp - 8], rdi; argc
  mov [rbp - 16], rsi ; argv

  mov r14, 0
  mov r12, [rbp - 16]
  mov r9, [rbp - 8]

check_loop:
  cmp r14, r9
  je check_done

  mov rdi, [r12]
  mov rsi, i_flag_str
  call strcmp
  cmp rax, 0
  je set_i_flag

  mov rdi, [r12]
  mov rsi, v_flag_str
  call strcmp
  ; strcmp returns its result in RAX:
    ; RAX = 0 if strings match
    ; RAX = negative if string1 < string2
    ; RAX = positive if string1 > string2
  cmp rax, 0
  je set_v_flag

  jmp check_done

set_i_flag:
  mov byte [i_flag], 1
  inc r14
  add r12, 8
  jmp check_loop

set_v_flag:
  mov byte [v_flag], 1
  inc r14
  add r12, 8
  jmp check_loop

check_done:
  mov rax, r14
  add rsp, 48
  pop rbp
  ret

; #################check answer##################
check_answer:
  ; question message
  mov rax, 1
  mov rdi, 1
  mov rsi, question_message
  mov rdx, question_message_len
  syscall
  
  mov rdi, [r12]
  call strlen
  mov rdx, rax,

  mov rax, 1
  mov rdi, 1
  mov rsi, [r12]
  ; rdx already set to len
  syscall

  ; get the answer
  mov rdi, 0
  mov rdi, 0
  mov rsi, response
  mov rdx, 1
  syscall

  cmp byte [response], 'y'
  je set_rax_1
  jmp set_rax_0

set_rax_1:
  mov rax, 1
  jmp check_answer_end

set_rax_0:
  mov rax, 0
  jmp check_answer_end

check_answer_end:
  ret

