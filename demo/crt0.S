	.section .boot, "ax", @progbits
	.global _start
_start:
	lui sp, %hi(_fstack)
	lui a0, %hi(_fbss)
	lui a1, %hi(_ebss)
	add sp, sp, %lo(_fstack)
	add a0, a0,%lo(_fbss)
	add a1, a1,%lo(_ebss)
	beq a0, a1, done
init:
	sw zero, 0(a0)
	add a0, a0, 4
	blt a0, a1, init
done:
	jal main
loopf:
	j loopf
