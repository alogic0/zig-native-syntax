; NASM corpus
%define COUNT 42
%macro save 1
  push %1
%endmacro
bits 64
section .text
global start
extern render
start:
  mov rax, COUNT
  add rax, rbx
  mov rcx, [rax + 8]
  call render
  jmp .done
message: db "x\n<&>"
.done:
  ret
