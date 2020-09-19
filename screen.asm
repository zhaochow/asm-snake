/*
 * screen.asm
 *
 *  Created: 08-04-18 22:56:19
 *   Author: Zhao CHOW
 */ 

; ########################################################################################
; Screen initialization
; Input(s): /
; Output(s): /
ScreenInit:
; Save register(s) to be used on the stack
PUSH R16
PUSH R2
PUSH R3

; Configure output pins
SBI DDRB,3					; Pin PB3 is an output
CBI PORTB,3					; Initial reset PB3
SBI DDRB,4					; Pin PB4 is an output
CBI PORTB,4					; Initial reset PB4
SBI DDRB,5					; Pin PB5 is an output
CBI PORTB,5					; Initial reset PB5

; Load default screen
LDI R16,low(StartScreen)
MOV R2,R16					; Input of LoadScreenImage
LDI R16,high(StartScreen)
MOV R3,R16					; Input of LoadScreenImage
RCALL LoadScreenImage

; Restore register(s) from the stack (reverse order)
POP R3
POP R2
POP R16
RET

; ########################################################################################
; Write R3 column bits for display
; Input(s): R2 = display byte, R3 = number column bits
; Output(s): /
WriteBits:
; Save register(s) to be used on the stack
PUSH R16
PUSH R2

MOV R16,R3					; Use R16 as a counter

WriteBitsLoop:
	CBI PORTB,3					; Set column bit to LOW (default)
	SBRC R2,0					; Set column bit to HIGH according to display byte
	SBI PORTB,3
	SBI PORTB,5					; Shift once at the rising edge of PB5
	CBI PORTB,5					; Make PB5 ready for the next rising edge
	LSR R2						; Shift right display byte to check next bit
	DEC R16						; Decrement counter
BRNE WriteBitsLoop			; Loop back until counter is 0

; Restore register(s) from the stack (reverse order)
POP R2
POP R16
RET							; Return from subroutine

; ########################################################################################
; Display screen according to data in SRAM
; Input(s): /
; Output(s): /
Display:
; Save register(s) to be used on the stack
PUSH R16
PUSH R17
PUSH R18
PUSH YL
PUSH YH

; ####################
LDI R18,1					; Use R18 as a row counter
LDI YL,ScreenL				; Load first address of screen from SRAM
LDI YH,ScreenH
ADIW YL,40					; Start at beginning of 2nd row in lower half

; ####################
; Set the 80 column bits
ColBits:
	LDI R16,10					; Use R16 as a 10 bytes counter
	ColLoop:
		CPI R16,5
		BRNE Write
		SBIW YL,30					; If byte number 5, jump to upper half

		Write:
		LD R2,-Y					; Pre decrement and load byte from SRAM (input of WriteBits)
		LDI R17,8
		MOV R3,R17					; Number of column bits to write (input of WriteBits)
		RCALL WriteBits

		DEC R16						; Decrement counter R16
	BRNE ColLoop				; Loop back until counter is 0
	ADIW YL,45					; Jump to next row in lower half

	; ####################
	; Set the 8 row bits
	RowBits:
	LDI R16,8					; Use R16 as a counter, 8 times
	RowLoop:
		CP R16,R18					; Compare R16 with current row
		BREQ ActiveRow				; If R16 = current row -> activate row
		CBI PORTB,3					; Else set 1 row bit to LOW
		RJMP RowEnd

		ActiveRow:
		SBI PORTB,3					; Set 1 row bit to HIGH
		RJMP RowEnd

		RowEnd:
		SBI PORTB,5					; Shift once at the rising edge of PB5
		CBI PORTB,5					; Make PB5 ready for the next rising edge
		DEC R16						; Decrement counter R16
	BRNE RowLoop				; Loop back until counter is 0

	; ####################
	; Need to wait some time before setting PB4 to have a strong light
	RCALL Delay
	RCALL Delay
	SBI PORTB,4					; Shift registers latch (for at least 100 us)
	RCALL Delay
	RCALL Delay
	CBI PORTB,4					; Enable the current row

	INC R18						; Increment row counter
	SBRS R18,3					; Skip next instruction if current row = 8 (non-existant row)
RJMP ColBits				; Repeat until all 7 rows are done

; ####################
; Restore register(s) from the stack (reverse order)
POP YH
POP YL
POP R18
POP R17
POP R16
RET							; Return from subroutine

; ########################################################################################
; Set 1 screen bit
; Input(s): R2 = desired row (0-13), R3 = desired column (0-39)
; Output(s): /
SetScreenBit:
; Save register(s) to be used on the stack
PUSH YL
PUSH YH

; R2 & R3 are inputs of GetByteAndMask
RCALL GetByteAndMask		; Get correct byte (R0), mask (R1) and byte address (Y)

OR R0,R1					; Set only the correct bit
ST Y,R0						; Store back byte

; Restore register(s) from the stack (reverse order)
POP YH
POP YL
RET							; Return from subroutine

; ########################################################################################
; Clear 1 screen bit
; Input(s): R2 = desired row (0-13), R3 = desired column (0-39)
; Output(s): /
ClearScreenBit:
; Save register(s) to be used on the stack
PUSH R16
PUSH YL
PUSH YH

; R2 & R3 are inputs of GetByteAndMask
RCALL GetByteAndMask		; Get correct byte (R0), mask (R1) and byte address (Y)

LDI R16,0xFF				; Mask for flipping the bits in a byte
EOR R1,R16					; Flip the bits of R1
AND R0,R1					; Clear only the correct bit
ST Y,R0						; Store back byte

; Restore register(s) from the stack (reverse order)
POP YH
POP YL
POP R16
RET							; Return from subroutine

; ########################################################################################
; Get 1 screen bit
; Input(s): R2 = desired row (0-13), R3 = desired column (0-39)
; Output(s): R0 = desired screen bit
GetScreenBit:
; Save register(s) to be used on the stack
PUSH YL
PUSH YH

; R2 & R3 are inputs of GetByteAndMask
RCALL GetByteAndMask		; Get correct byte (R0), mask (R1) and byte address (Y)

GetScreenBitLoop:
	SBRC R1,7					; Skip next instruction if bit 7 cleared
	RJMP GetScreenBitEnd		; Desired bit at bit 7 -> next part
	LSL R0
	LSL R1
RJMP GetScreenBitLoop		; Shift left until desired bit at bit 7

GetScreenBitEnd:
BST R0,7					; Store bit 7 of R0 in T
CLR R0						; Clear R0
BLD R0,0					; Load T in bit 0 of R0

; Restore register(s) from the stack (reverse order)
POP YH
POP YL
RET							; Return from subroutine

; ########################################################################################
; Return the screen byte containing the desired bit and the mask for retrieving it with
; the AND operator
; !!! SENSITIVE TO Y
; Input(s): R2 = desired row (0-13), R3 = desired column (0-39)
; Output(s): R0 = desired byte, R1 = mask, Y = corresponding byte address
GetByteAndMask:
; Save register(s) to be used on the stack
PUSH R16
PUSH R2						; Save input for restore
PUSH R3 					; Save input for restore

LDI YL,ScreenL				; Load 1st address of screen in SRAM
LDI YH,ScreenH

; ####################
; Go to the correct row
GetByteAndMaskRow:
	TST R2						; Test if R2 = 0
	BREQ GetByteAndMaskP2		; If correct row, go to next part
	ADIW Y,5					; Else go to next row (5 bytes = 40 bits)
	DEC R2
RJMP GetByteAndMaskRow		; Loop until correct row

; ####################
; Go to the correct byte containing the desired column (Decrease until column < 8)
GetByteAndMaskP2:
LDI R16,8					; Use as decrement
GetByteAndMaskCol:
	CP R3,R16
	BRLO GetByteAndMaskP3		; If column < 8, go to next part
	SUB R3,R16					; Else decrease of 8
	ADIW Y,1					; Increment address byte
RJMP GetByteAndMaskCol		; Loop until correct byte

; Get mask for column bit
GetByteAndMaskP3:
LDI R16,0b10000000			; Mask for selecting correct column bit
GetByteAndMaskColMask:
	TST R3						; Test if R3 = 0
	BREQ GetByteAndMaskEnd		; If correct column bit -> End
	LSR R16						; Else shift right mask
	DEC R3						; Decrement R3
RJMP GetByteAndMaskColMask	; Loop until correct column bit

GetByteAndMaskEnd:
LD R0,Y						; Load screen byte
MOV R1,R16					; Copy mask to R1
; Restore register(s) from the stack (reverse order)
POP R3
POP R2
POP R16
RET							; Return from subroutine

; ########################################################################################
; Load image in Program memory to display
; Input(s): R2 = low address byte of image, R3 = high address byte of image
; Output(s): /
LoadScreenImage:
; Save register(s) to be used on the stack
PUSH R16
PUSH R17
PUSH R2						; Save input for restore
PUSH R3 					; Save input for restore
PUSH YL
PUSH YH
PUSH ZL
PUSH ZH

LDI YL,ScreenL				; Load screen address in SRAM
LDI YH,ScreenH

CLC							; Make sure carry is cleared for next instruction
ROL R2						; Shift left low byte with old bit 7 in carry
ROL R3						; Shift left high byte with new bit 0 from carry
MOV ZL,R2					; Bit 0 of Z used to select byte (0 = low, 1 = high)
MOV ZH,R3
LDI R16,ScreenLength

LoadScreenImageLoop:
	LPM R17,Z+					; Read 1 byte from image in Program memory
	ST Y+,R17					; Store the byte to SRAM
	DEC R16
BRNE LoadScreenImageLoop	; Loop until all bytes are written

; Restore register(s) from the stack (reverse order)
POP ZH
POP ZL
POP YH
POP YL
POP R3
POP R2
POP R17
POP R16
RET							; Return from subroutine

; ########################################################################################

.EQU ScreenL = 0x00			; Start of StartScreen in SRAM
.EQU ScreenH = 0x01
.EQU ScreenLength = 70		; Number of bytes of the screen

StartScreen:
;     1    2        3    4        5        6    7        8
.DB 0b00000000, 0b00000000, 0b00000000, 0b00000000, 0b00000000, \
	0b00000000, 0b00000000, 0b00000000, 0b00000000, 0b00000000, \
	0b00000000, 0b00000000, 0b00000000, 0b00000000, 0b00000000, \
	0b00000000, 0b00000000, 0b00000000, 0b00000000, 0b00000000, \
	0b00000000, 0b00000000, 0b00000000, 0b00000000, 0b00000000, \
	0b00000000, 0b00000000, 0b00000000, 0b00000000, 0b00000000, \
	0b00000000, 0b00000000, 0b00000000, 0b00000000, 0b00000000, \
																\
	0b00000000, 0b00000000, 0b00000000, 0b00000000, 0b00000000, \
	0b00000000, 0b00000000, 0b00000000, 0b00000000, 0b00000000, \
	0b00000000, 0b00000000, 0b00000000, 0b00000000, 0b00000000, \
	0b00000000, 0b00000000, 0b00000000, 0b00000000, 0b00000000, \
	0b00000000, 0b00000000, 0b00000000, 0b00000000, 0b00000000, \
	0b00000000, 0b00000000, 0b00000000, 0b00000000, 0b00000000, \
	0b00000000, 0b00000000, 0b00000000, 0b00000000, 0b00000000