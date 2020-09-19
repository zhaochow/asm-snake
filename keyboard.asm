/*
 * keyboard.asm
 *
 *  Created: 08-04-18 22:38:43
 *   Author: Zhao CHOW
 */ 


; Keyboard definitions
.EQU NbOfCol = 4			; Define the number of columns of the keyboard to 4

; Mapping of the computed button number with the actual displayed number
KeyMapping:
.DB    7,		8,		9,	 0x0F, \
	   4,		5,		6,	 0x0E, \
	   1,		2,		3,	 0x0D, \
	0x0A,		0,	 0x0B,	 0x0C

; ########################################################################################
; Get the keyboard column number (rows as outputs, columns as inputs)
; Input(s): /
; Output(s): R0 = keyboard column number
GetColNb:
; Save register(s) to be used on the stack
PUSH R16

; Configure pins
LDI R16,0b00001111			; Attention: generate intermediate state
OUT PORTD,R16				; Enable pull-up resistor for inputs and set outputs LOW
LDI R16,0b11110000
OUT DDRD,R16				; Set PD 7 to 4 as outputs, 3 to 0 as inputs
CLR R16						; (NOP) for synchronisation between assignments and readings

; Use R16 as the column number for the keyboard
SBIS PIND,3					; Skip next instruction if PD3 is HIGH (col 1 not pressed)
	LDI R16,1
SBIS PIND,2					; Skip next instruction if PD2 is HIGH (col 2 not pressed)
	LDI R16,2
SBIS PIND,1					; Skip next instruction if PD1 is HIGH (col 3 not pressed)
	LDI R16,3
SBIS PIND,0					; Skip next instruction if PD0 is HIGH (col 4 not pressed)
	LDI R16,4
MOV R0,R16					; Copy column number to R0

; Restore register(s) from the stack (reverse order)
POP R16
RET							; Return from subroutine

; ########################################################################################
; Get the keyboard column number (columns as outputs, rows as inputs)
; Input(s): /
; Output(s): R0 = keyboard row number
GetRowNb:
; Save register(s) to be used on the stack
PUSH R16

; Configure pins
LDI R16,0b11110000			; Attention: generate intermediate state
OUT PORTD,R16				; Enable pull-up resistor for inputs and set outputs LOW
LDI R16,0b00001111
OUT DDRD,R16				; Set PD 7 to 4 as inputs, 3 to 0 as outputs
CLR R16						; (NOP) for synchronisation between assignments and readings

; Use R16 as the row number for the keyboard
SBIS PIND,7					; Skip next instruction if PD7 is HIGH (row 1 not pressed)
	LDI R16,1
SBIS PIND,6					; Skip next instruction if PD6 is HIGH (row 2 not pressed)
	LDI R16,2
SBIS PIND,5					; Skip next instruction if PD5 is HIGH (row 3 not pressed)
	LDI R16,3
SBIS PIND,4					; Skip next instruction if PD4 is HIGH (row 4 not pressed)
	LDI R16,4
MOV R0,R16					; Copy row number to R0

; Restore register(s) from the stack (reverse order)
POP R16
RET							; Return from subroutine

; ########################################################################################
; Return the button number: -1 no button pressed, otherwise value corresponds to the
; displayed value on the board
; Input(s): /
; Output(s): R0 = button number
GetBtnNb:
; Save register(s) to be used on the stack
PUSH R16
PUSH R17

; ####################
LDI R16,0					; Load 0 to R16 for further compare
LDI R17,-1					; Set button number to -1 (no button pressed default value)

RCALL GetColNb				; Get the keyboard column number (output in R0)
MOV R3,R0					; Copy for later button number computation
MOV R0,R17					; Reset R0 to no button pressed

CP R3,R16
BREQ GetBtnNbEnd			; If no column pressed, end function

	; ####################
	RCALL GetRowNb				; Get the keyboard row number (output in R0)
	MOV R2,R0					; Copy for later button number computation
	MOV R0,R17					; Reset R0 to no button pressed

	CP R2,R16
	BREQ GetBtnNbEnd			; If no row pressed, end function

		; ####################
		DEC R2						; Decrement for button number computation
		LDI R16,NbOfCol
		MUL R2,R16					; Multiply row number by NbOfCol (4) -> result in R1:R0
		ADD R0,R3					; Add previous result with column number to R0 (= btn number)
		DEC R0						; Decrement to get offset in KeyMapping
		TST R0						; Test if zero or minus (negative)
		BRMI GetBtnNbEnd			; If minus => End

			LDI ZL,low(KeyMapping<<1)	; Bit 0 of Z used to select byte (0 = low, 1 = high)
			LDI ZH,high(KeyMapping<<1)
			ADD ZL,R0					; Add offset low byte (only 16 elements so no carry)
			LPM R0,Z					; Read a byte

GetBtnNbEnd:
; Restore register(s) from the stack (reverse order)
POP R17
POP R16
RET							; Return from subroutine