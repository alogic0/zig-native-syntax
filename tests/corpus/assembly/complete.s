# Assembly corpus
.macro save reg
  push \reg
.endm
.section .text
.globl start
start:
  mov $42, %rax
  add %rbx, %rax
  call render
  jmp .done
message: .ascii "x\n<&>"
.done:
  ret
