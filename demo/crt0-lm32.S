	.section .boot, "ax", @progbits
	.global _start
_start:
	xor r0, r0, r0
	mvhi sp, hi(_fstack)
	mvhi r1, hi(_fbss)
	mvhi r2, hi(_ebss)
	ori  sp, sp, lo(_fstack)
	ori  r1, r1, lo(_fbss)
	ori  r2, r2, lo(_ebss)
	be r1, r2, done
init:
	sw (r1+0), r0
	addi r1, r1, 4
	bg r2, r1, init
done:
	calli main
loopf:
	bi loopf
