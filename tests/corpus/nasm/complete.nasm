; NASM corpus
section .text
global start
start:
  mov rax, 42
  add rax, rbx
message: db "x\n<&>"
  ret
