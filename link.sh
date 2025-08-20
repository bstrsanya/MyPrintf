#!/bin/bash

var1="${1%.s}"
var2="${2%.c}"

nasm -f elf64 -o "${var1}.o" "${var1}.s"
gcc -c -o "${var2}.o" "${var2}.c"
gcc -o "$3" "${var2}.o" "${var1}.o"
