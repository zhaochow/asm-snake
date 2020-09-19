/*
 * utilities.asm
 *
 *  Created: 08-04-18 18:54:35
 *   Author: Zhao CHOW
 */ 

; Use following registers for the pseudo-random generator
.DEF RandomSeed = R10
.DEF RandomSeed2 = R11
.DEF RandomSeed3 = R12
.DEF RandomSeed4 = R13
.DEF RandomSeed5 = R14
.DEF RandomSeed6 = R15

; ########################################################################################
; Delay subroutine
Delay:
; Save register(s) to be used on the stack
PUSH R16

LDI R16,0xFF				; Set R16 as a counter
DelayLoop:
	DEC R16						; Decrement counter
BRNE DelayLoop				; Loop until counter is 0

; Restore register(s) from the stack (reverse order)
POP R16
RET							; Return from subroutine

; ########################################################################################
; Generate pseudo-random bits using linear feedback shift registers (n = 47, k = 47,42).
; Input(s): R2 = nb bits (1-31)
; Output(s): R0 = random bits
RandBits:
; Save register(s) to be used on the stack
PUSH R16
PUSH R17

LDI R16,0
MOV R0,R16					; Reset R0
BST RandomSeed,0			; Save k = 1 in T
BLD R0,0					; Copy T to bit 0 output byte

RandBitsLoop:
	DEC R2
	BREQ RandBitsEnd			; Finish if R2 = 0
	; Right shift registers
	LSR RandomSeed6
	ROR RandomSeed5
	ROR RandomSeed4
	ROR RandomSeed3
	ROR RandomSeed2
	ROR RandomSeed

	BLD RandomSeed6,6			; Copy T to k = 47
	LDI R17,0					; Reset R17
	BLD R17,1					; Copy T to bit 1 of R17
	EOR RandomSeed6,R17			; XOR k = 42

	BST RandomSeed,0			; Save k = 1 in T
	LSL R0						; Left shift output byte
	BLD R0,0					; Copy T to bit 0 output byte
RJMP RandBitsLoop

RandBitsEnd:
; Restore register(s) from the stack (reverse order)
POP R17
POP R16
RET

; ########################################################################################
; Return a random row of the display (between 0 and 13)
; Input(s): /
; Output(s): R0 = random row (0-13)
RandRow:
; Save register(s) to be used on the stack
PUSH R16
PUSH R2						; Make sure R2 is not changed due to this function

LDI R16,4
MOV R2,R16					; Input of RandBits
RCALL RandBits				; Get R2 random bits in R0
MOV R16,R0					; Copy bits to R16
CPI R16,14
BRLO RandRowEnd				; If < 14 => End
SUBI R16,8					; Else decrease of 8
MOV R0,R16					; Copy to output R0

RandRowEnd:
; Restore register(s) from the stack (reverse order)
POP R2
POP R16
RET

; ########################################################################################
; Return a random column of the display (between 0 and 39)
; Input(s): /
; Output(s): R0 = random column (0-39)
RandCol:
; Save register(s) to be used on the stack
PUSH R16
PUSH R2 					; Make sure R2 is not changed due to this function

LDI R16,6
MOV R2,R16					; Input of RandBits
RCALL RandBits				; Get R2 random bits in R0
MOV R16,R0					; Copy bits to R16
CPI R16,40
BRLO RandColEnd				; If < 40 => End
SUBI R16,32					; Else decrease of 32
MOV R0,R16					; Copy to output R0

RandColEnd:
; Restore register(s) from the stack (reverse order)
POP R2
POP R16
RET