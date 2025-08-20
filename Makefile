.PHONY: print

print: asm.o main.c
	gcc -no-pie -g -O0 main.c asm.o && ./a.out

asm.o: asm.s
	nasm -f elf64 -g -l asm.lst asm.s