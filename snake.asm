/*
 * snake.asm
 *
 *  Created: 23/04/2018 14:06:36
 *   Author: Zhao CHOW
 */ 

.EQU UP = 1
.EQU DOWN = 2
.EQU LEFT = 3
.EQU RIGHT = 4
.DEF SnakeDirection = R24	; Use R24 for the snake direction
.DEF SnakeStop = R25		; Use R25 for the game stop status

.EQU FoodL = 0x00			; SRAM address for food, 2 byte food 2 bytes timer counter
.EQU FoodH = 0x03
.EQU SnakeTimerCntH = 0x85
.EQU SnakeTimerCntL = 0xEE

; ########################################################################################
; Snake initialization
; Input(s): /
; Output(s): /
SnakeInit:
; Save register(s) to be used on the stack
PUSH R16
PUSH ZL
PUSH ZH
PUSH YL
PUSH YH

; Load snake game start
LDI R16,low(SnakeGameStart)
MOV R2,R16					; Copy low byte of start screen (input of LoadScreenImage)
LDI R16,high(SnakeGameStart)
MOV R3,R16					; Copy high byte of start screen (input of LoadScreenImage)
RCALL LoadScreenImage		; Load game start screen

LDI SnakeStop,1				; Set stop status to 1 (True)

; Restore register(s) from the stack (reverse order)
POP YH
POP YL
POP ZH
POP ZL
POP R16
RET							; Return from subroutine

; ########################################################################################
; Start snake game
; Input(s): /
; Output(s): /
SnakeStartGame:
; Save register(s) to be used on the stack
PUSH R16
PUSH ZL
PUSH ZH
PUSH YL
PUSH YH

RCALL ScreenInit			; Reset screen to default

; ####################
LDI YL,SnakeL				; Load address of snake in SRAM
LDI YH,SnakeH
LDI ZL,low(SnakeStart<<1)	; Bit 0 of Z used to select byte (0 = low, 1 = high)
LDI ZH,high(SnakeStart<<1)

LPM R16,Z+					; Load snake length
ST Y+,R16					; Store snake length in SRAM
; Store every point of snake
SnakeStartLoop:
	LPM R2,Z+					; Read row byte and post increment
	ST Y+,R2					; Store row byte in SRAM
	LPM R3,Z+					; Read column byte and post increment
	ST Y+,R3					; Store column byte
	DEC R16
BRNE SnakeStartLoop			; Loop for all the snake's points

SBIC PINB,0					; If PB0 (switch) is cleared, skip next intruction
RJMP SnakeStartP22			; Else go to next sub part

; Load snake game without walls (switch low)
LDI R16,low(SnakeNoWalls)
MOV R2,R16					; Copy low byte of start screen (input of LoadScreenImage)
LDI R16,high(SnakeNoWalls)
MOV R3,R16					; Copy high byte of start screen (input of LoadScreenImage)
RJMP SnakeStartP23			; Go to next part

; Load snake game with walls (switch high)
SnakeStartP22:
LDI R16,low(SnakeWalls)
MOV R2,R16					; Copy low byte of start screen (input of LoadScreenImage)
LDI R16,high(SnakeWalls)
MOV R3,R16					; Copy high byte of start screen (input of LoadScreenImage)

SnakeStartP23:
RCALL LoadScreenImage		; Load game start screen

LDI SnakeDirection,RIGHT	; Set default snake direction to RIGHT
LDI SnakeStop,0				; Set stop status to 0 (False)

IN RandomSeed,TCNT0			; Get the first random seed for the pseudo-random generator

RCALL SnakeGenFood			; Generate food
LDI YL,FoodL				; Load address of food in SRAM
LDI YH,FoodH
LDI R16,SnakeTimerCntH		; Store Timer1 counter
STD Y+2,R16
LDI R16,SnakeTimerCntL
STD Y+3,R16

; ####################
; Restore register(s) from the stack (reverse order)
POP YH
POP YL
POP ZH
POP ZL
POP R16
RET							; Return from subroutine

; ########################################################################################
; Move the snake 1 bit UP
; Input(s): /
; Output(s): /
SnakeMoveUp:
; Save register(s) to be used on the stack
PUSH R16

RCALL GetSnakeHead			; Get snake head, R0 = row, R1 = column
MOV R16,R0					; Copy row to R16

DEC R16						; Decrement row
BRGE SnakeMoveUpP2			; If row >= 0, go to next part
	LDI R16,13					; Else row = 13

SnakeMoveUpP2:
MOV R2,R16					; Copy new row to R2 (input of SnakeUpdate)
MOV R3,R1					; Copy column to R3 (input of SnakeUpdate)
RCALL SnakeUpdate			; Update the snake

; ####################
; Restore register(s) from the stack (reverse order)
POP R16
RET							; Return from subroutine

; ########################################################################################
; Move the snake 1 bit DOWN
; Input(s): /
; Output(s): /
SnakeMoveDown:
; Save register(s) to be used on the stack
PUSH R16

RCALL GetSnakeHead			; Get snake head, R0 = row, R1 = column
MOV R16,R0					; Copy row to R16

INC R16						; Increment row
CPI R16,14
BRLO SnakeMoveDownP2		; If row < 14, go to next part
	LDI R16,0					; Else row = 0

SnakeMoveDownP2:
MOV R2,R16					; Copy new row to R2 (input of SnakeUpdate)
MOV R3,R1					; Copy column to R3 (input of SnakeUpdate)
RCALL SnakeUpdate			; Update the snake

; ####################
; Restore register(s) from the stack (reverse order)
POP R16
RET							; Return from subroutine

; ########################################################################################
; Move the snake 1 bit LEFT
; Input(s): /
; Output(s): /
SnakeMoveLeft:
; Save register(s) to be used on the stack
PUSH R16

RCALL GetSnakeHead			; Get snake head, R0 = row, R1 = column
MOV R16,R1					; Copy column to R16

DEC R16						; Decrement column
BRGE SnakeMoveLeftP2		; If column >= 0, go to next part
	LDI R16,39					; Else column = 39

SnakeMoveLeftP2:
MOV R2,R0					; Copy row to R2 (input of SnakeUpdate)
MOV R3,R16					; Copy new column to R3 (input of SnakeUpdate)
RCALL SnakeUpdate			; Update the snake

; ####################
; Restore register(s) from the stack (reverse order)
POP R16
RET							; Return from subroutine

; ########################################################################################
; Move the snake 1 bit RIGHT
; Input(s): /
; Output(s): /
SnakeMoveRight:
; Save register(s) to be used on the stack
PUSH R16

RCALL GetSnakeHead			; Get snake head, R0 = row, R1 = column
MOV R16,R1					; Copy column to R16

INC R16						; Increment column
CPI R16,40
BRLO SMRUpdate				; If column < 40, go to next part
	LDI R16,0					; Else column = 0

SMRUpdate:
MOV R2,R0					; Copy row to R2 (input of SnakeUpdate)
MOV R3,R16					; Copy new column to R3 (input of SnakeUpdate)
RCALL SnakeUpdate			; Update the snake

; ####################
; Restore register(s) from the stack (reverse order)
POP R16
RET							; Return from subroutine

; ########################################################################################
; Get the row and column of the snake head
; Input(s): /
; Output(s): R0 = row of head, R1 = column of head
GetSnakeHead:
; Save register(s) to be used on the stack
PUSH R16
PUSH YL
PUSH YH

LDI YL,SnakeL				; Load address of snake in SRAM
LDI YH,SnakeH

LD R16,Y+					; Load snake length
DEC R16						; Do not take the head itself
GetSnakeHeadLoop:
	ADIW Y,2					; Increase of 2
	DEC R16
BRNE GetSnakeHeadLoop		; Loop until at head

LD R0,Y+					; Get row of snake head
LD R1,Y						; Get column snake head

; ####################
; Restore register(s) from the stack (reverse order)
POP YH
POP YL
POP R16
RET							; Return from subroutine

; ########################################################################################
; Update the snake (increase the length if encounter with food, trigger stop status if
; encounter with itself, otherwise update position)
; Input(s): R2 = new head row, R3 new head col
; Output(s): /
SnakeUpdate:
; Save register(s) to be used on the stack
PUSH R16
PUSH R17
PUSH R18
PUSH YL
PUSH YH

; ####################
; Increase length if encounter with food
LDI YL,FoodL				; Get food position (row and column)
LDI YH,FoodH
LD R16,Y+					; Food row
LD R17,Y					; Food column

; Check if new head = food, if not go to next part
CP R2,R16
BRNE SnakeUpdateP2			; Check row
CP R3,R17
BRNE SnakeUpdateP2			; Check column

	; New head = food so increase snake length
	LDI YL,SnakeL				; Load address of snake
	LDI YH,SnakeH
	LD R16,Y					; Load snake length
	INC R16						; Increase snake length
	ST Y+,R16					; Store back snake length

	DEC R16						; Do not take the head itself
	SnakeUpdateP11:				; Go to new head
		ADIW Y,2					; Increase of 2
		DEC R16
	BRNE SnakeUpdateP11			; Loop until at head
	ST Y+,R2					; Add new head
	ST Y+,R3

	RCALL SnakeGenFood			; Generate new food
	LDI YL,FoodL				; Load address of food in SRAM
	LDI YH,FoodH
	LDD R16,Y+2					; Load Timer1 Counter High Byte
	CPI R16,0xB2
	BRGE SnakeUpdateP12			; After 9 times increasing by 5, increment by 1
	LDI R18,5					; Increase Timer1 Counter by 5
	RJMP SnakeUpdateP13

	SnakeUpdateP12:
	LDI R18,1					; Increase Timer1 Counter by 1

	SnakeUpdateP13:
	ADD R16,R18
	STD Y+2,R16					; Store back Timer1 Counter High Byte
	RJMP SnakeUpdateEnd			; Finish update

; ####################
; Trigger stop status if encounter with itself or obstacle
SnakeUpdateP2:
; R2 & R3 are inputs of GetScreenBit
RCALL GetScreenBit			; Get screen bit at new head position (R0 = 0 or 1)
TST R0
BREQ SnakeUpdateP3			; If bit = 0 (nothing at new head position), go to next part
	LDI SnakeStop,1				; Else set stop status
	LDI R16,low(SnakeGameOver)	; Set Game Over screen
	MOV R2,R16					; Input of LoadScreenImage
	LDI R16,high(SnakeGameOver)
	MOV R3,R16					; Input of LoadScreenImage
	RCALL LoadScreenImage
	RJMP SnakeUpdateEnd			; Finish update

; ####################
; Update position
SnakeUpdateP3:
LDI YL,SnakeL				; Load address of snake
LDI YH,SnakeH

MOV R16,R2					; Copy new head row
MOV R17,R3					; Copy new head column
LDD R2,Y+1					; Load row of snake tail (input of ClearScreenBit)
LDD R3,Y+2					; Load column of snake tail (input of ClearScreenBit)
RCALL ClearScreenBit		; Clear snake tail
MOV R2,R16					; Copy back new head row
MOV R3,R17					; Copy back new head column

LD R16,Y+					; Load snake length
DEC R16						; Do not take the head itself

; Shift all snake points
SnakeUpdateP31:
	LDD R17,Y+2					; Load row of next snake point
	ST Y+,R17					; Store to previous snake point
	LDD R17,Y+2					; Load column of next snake point
	ST Y+,R17					; Store to previous snake point
	DEC R16
BRNE SnakeUpdateP31			; Loop for all snake points

ST Y+,R2					; Store new head
ST Y,R3
RCALL SetScreenBit			; Set the screen bit for the new head

; ####################
SnakeUpdateEnd:
; Restore register(s) from the stack (reverse order)
POP YH
POP YL
POP R18
POP R17
POP R16
RET							; Return from subroutine

; ########################################################################################
; Main function of this snake game. Move the snake continuously and change its direction
; according to the pressed button. Stop the game when the snake encounters itself.
; Input(s): R2 = button number
; Output(s): /
SnakeMain:
; Save register(s) to be used on the stack
PUSH R16
PUSH R17
PUSH R2						; Save input for restore
PUSH YL
PUSH YH

MOV R16,R2					; Copy button number to R16

; ####################
; Check if game has stopped
TST SnakeStop
BREQ SnakeDirectionUp		; If game is not stopped, go to next part
	CPI R16,0x0A				; Else check if user want to retry
	BRNE SnakeMainEnd			; If user do no want to retry, end function
		RCALL SnakeStartGame		; Else start snake game
		RJMP SnakeMainEnd			; End function

; ####################
; Change direction if button pressed (cannot go in opposite direction as currently)
SnakeDirectionUp:
CPI R16,0x03
BREQ SnakeMainP21			; If button 3 (go UP) is pressed, go to sub part
CPI JoystickUD,0x3F
BRSH SnakeDirectionDown		; If JoystickUD >= 63, Joystick not up
SnakeMainP21:
CPI SnakeDirection,DOWN
BREQ SnakeGoUp				; If previously going DOWN, go to next part
	LDI SnakeDirection,UP		; Else change direction to UP
	RJMP SnakeGoUp				; Go to next part

SnakeDirectionDown:
CPI R16,0x0B
BREQ SnakeMainP22			; If button B (go DOWN) is pressed, go to sub part
CPI JoystickUD,0xC0
BRLO SnakeDirectionLeft		; Else if JoystickUD < 192, Joystick not down
SnakeMainP22:
CPI SnakeDirection,UP
BREQ SnakeGoUp				; If previously going UP, go to next part
	LDI SnakeDirection,DOWN		; Else change direction to DOWN
	RJMP SnakeGoUp				; Go to next part

SnakeDirectionLeft:
CPI R16,0x00
BREQ SnakeMainP23			; If button 0 (go LEFT) is pressed, go to sub part
CPI JoystickLR,0x3F
BRSH SnakeDirectionRight	; Else if JoystickUD >= 63, Joystick not left
SnakeMainP23:
CPI SnakeDirection,RIGHT
BREQ SnakeGoUp				; If previously going RIGHT, go to next part
	LDI SnakeDirection,LEFT		; Else change direction to LEFT
	RJMP SnakeGoUp				; Go to next part

SnakeDirectionRight:
CPI R16,0x0C
BREQ SnakeMainP24			; If button C (go RIGHT) is pressed, go to sub part
CPI JoystickLR,0xC0
BRLO SnakeGoUp				; Else if JoystickUD < 192, Joystick not right
SnakeMainP24:
CPI SnakeDirection,LEFT
BREQ SnakeGoUp				; If previously going LEFT, go to next part
	LDI SnakeDirection,RIGHT	; Else change direction to RIGHT

; ####################
; Move snake according to direction
SnakeGoUp:
CPI SnakeDirection,UP
BRNE SnakeGoDown			; If direction is not UP, go to next direction
	RCALL SnakeMoveUp			; Else move snake UP
	RJMP SnakeMainP4			; Go to next part

SnakeGoDown:
CPI SnakeDirection,DOWN
BRNE SnakeGoLeft			; If direction is not DOWN, go to next direction
	RCALL SnakeMoveDown			; Else move snake DOWN
	RJMP SnakeMainP4			; Go to next part

SnakeGoLeft:
CPI SnakeDirection,LEFT
BRNE SnakeGoRight			; If direction is not LEFT, go to next direction
	RCALL SnakeMoveLeft			; Else move snake LEFT
	RJMP SnakeMainP4			; Go to next part

SnakeGoRight:
CPI SnakeDirection,RIGHT
BRNE SnakeMainP4			; If direction is not RIGHT, go to next part
	RCALL SnakeMoveRight		; Else move snake RIGHT

; ####################
; Refresh food bit for display if game continues
SnakeMainP4:
TST SnakeStop
BRNE SnakeMainEnd			; If game is stopped, end function
	LDI YL,FoodL				; Get food position (row and column)
	LDI YH,FoodH
	LD R2,Y+					; Food row (input of SetScreenBit)
	LD R3,Y						; Food column (input of SetScreenBit)
	RCALL SetScreenBit			; Set food bit for display

; ####################
SnakeMainEnd:
; Restore register(s) from the stack (reverse order)
POP YH
POP YL
POP R2
POP R17
POP R16
RET							; Return from subroutine

; ########################################################################################
; Generate a new food at a random position
; Input(s): /
; Output(s): /
SnakeGenFood:
; Save register(s) to be used on the stack
PUSH R2						; Make sure R2 is not changed due to this function
PUSH R3						; Make sure R3 is not changed due to this function
PUSH YL
PUSH YH

LDI YL,FoodL				; Load address of food in SRAM
LDI YH,FoodH

SnakeGenFoodP1:
	RCALL RandRow				; Get a random row 0-13 in R0
	MOV R2,R0					; Copy row to R2 (input of GetScreenBit)
	RCALL RandCol				; Get a random column 0-39 in R0
	MOV R3,R0					; Copy column to R3 (input of GetScreenBit)

	; R2 & R3 are inputs of GetScreenBit
	RCALL GetScreenBit			; Get screen bit at new food position (R0 = 0 or 1)
	TST R0
BRNE SnakeGenFoodP1			; If bit = 1 (something at new food position), generate again

; R2 & R3 are inputs of SetScreenBit
ST Y+,R2					; Store row in SRAM
ST Y,R3						; Store column in SRAM
RCALL SetScreenBit			; Set the corresponding screen bit

; ####################
; Restore register(s) from the stack (reverse order)
POP YH
POP YL
POP R3
POP R2
RET							; Return from subroutine

; ########################################################################################

; SRAM address of snake (contains length, tail, ... head)
.EQU SnakeL = 0x00
.EQU SnakeH = 0x02

; Default information of snake: length, row,col, row,col ... (from tail to head)
SnakeStart:
.DB 4, 6,18, 6,19, 6,20, 6,21, 0

; Screen at game start, corresponding to values of SnakeStart (without walls)
SnakeNoWalls:
;     1    2        3    4        5        6    7        8
.DB 0b00000000, 0b00000000, 0b00000000, 0b00000000, 0b00000000, \
	0b00000000, 0b00000000, 0b00000000, 0b00000000, 0b00000000, \
	0b00000000, 0b00000000, 0b00000000, 0b00000000, 0b00000000, \
	0b00000000, 0b00000000, 0b00000000, 0b00000000, 0b00000000, \
	0b00000000, 0b00000000, 0b00000000, 0b00000000, 0b00000000, \
	0b00000000, 0b00000000, 0b00000000, 0b00000000, 0b00000000, \
	0b00000000, 0b00000000, 0b00111100, 0b00000000, 0b00000000, \
																\
	0b00000000, 0b00000000, 0b00000000, 0b00000000, 0b00000000, \
	0b00000000, 0b00000000, 0b00000000, 0b00000000, 0b00000000, \
	0b00000000, 0b00000000, 0b00000000, 0b00000000, 0b00000000, \
	0b00000000, 0b00000000, 0b00000000, 0b00000000, 0b00000000, \
	0b00000000, 0b00000000, 0b00000000, 0b00000000, 0b00000000, \
	0b00000000, 0b00000000, 0b00000000, 0b00000000, 0b00000000, \
	0b00000000, 0b00000000, 0b00000000, 0b00000000, 0b00000000

; Screen at game start, corresponding to values of SnakeStart (with walls)
SnakeWalls:
;     1    2        3    4        5        6    7        8
.DB 0b11111111, 0b11111111, 0b11111111, 0b11111111, 0b11111111, \
	0b10000000, 0b00000000, 0b00000000, 0b00000000, 0b00000001, \
	0b10000000, 0b00000000, 0b00000000, 0b00000000, 0b00000001, \
	0b10000000, 0b00000000, 0b00000000, 0b00000000, 0b00000001, \
	0b10000000, 0b00000000, 0b00000000, 0b00000000, 0b00000001, \
	0b10000000, 0b00000000, 0b00000000, 0b00000000, 0b00000001, \
	0b10000000, 0b00000000, 0b00111100, 0b00000000, 0b00000001, \
																\
	0b10000000, 0b00000000, 0b00000000, 0b00000000, 0b00000001, \
	0b10000000, 0b00000000, 0b00000000, 0b00000000, 0b00000001, \
	0b10000000, 0b00000000, 0b00000000, 0b00000000, 0b00000001, \
	0b10000000, 0b00000000, 0b00000000, 0b00000000, 0b00000001, \
	0b10000000, 0b00000000, 0b00000000, 0b00000000, 0b00000001, \
	0b10000000, 0b00000000, 0b00000000, 0b00000000, 0b00000001, \
	0b11111111, 0b11111111, 0b11111111, 0b11111111, 0b11111111

; Screen when game start
SnakeGameStart:
;     1    2        3    4        5        6    7        8
.DB 0b00000001, 0b11011100, 0b01100111, 0b00111000, 0b00000000, \
	0b00000010, 0b00001000, 0b10010100, 0b10010000, 0b00000000, \
	0b00000010, 0b00001000, 0b10010100, 0b10010000, 0b00000000, \
	0b00000001, 0b10001000, 0b10010100, 0b10010000, 0b00000000, \
	0b00000000, 0b01001000, 0b11110111, 0b00010000, 0b00000000, \
	0b00000000, 0b01001000, 0b10010100, 0b10010000, 0b00000000, \
	0b00000011, 0b10001000, 0b10010100, 0b10010000, 0b00000000, \
																\
	0b00000000, 0b00001100, 0b01100100, 0b10111100, 0b00000000, \
	0b00000000, 0b00010010, 0b10010111, 0b10100000, 0b00000000, \
	0b00000000, 0b00010000, 0b10010100, 0b10100000, 0b00000000, \
	0b00000000, 0b00010110, 0b10010100, 0b10111100, 0b00000000, \
	0b00000000, 0b00010010, 0b11110100, 0b10100000, 0b00000000, \
	0b00000000, 0b00010010, 0b10010100, 0b10100000, 0b00000000, \
	0b00000000, 0b00001100, 0b10010100, 0b10111100, 0b00000000

; Screen when game over
SnakeGameOver:
;     1    2        3    4        5        6    7        8
.DB 0b00000000, 0b00001100, 0b01100100, 0b10111100, 0b00000000, \
	0b00000000, 0b00010010, 0b10010111, 0b10100000, 0b00000000, \
	0b00000000, 0b00010000, 0b10010100, 0b10100000, 0b00000000, \
	0b00000000, 0b00010110, 0b10010100, 0b10111100, 0b00000000, \
	0b00000000, 0b00010010, 0b11110100, 0b10100000, 0b00000000, \
	0b00000000, 0b00010010, 0b10010100, 0b10100000, 0b00000000, \
	0b00000000, 0b00001100, 0b10010100, 0b10111100, 0b00000000, \
																\
	0b00000000, 0b00011110, 0b10010111, 0b10111000, 0b00000000, \
	0b00000000, 0b00010010, 0b10010100, 0b00100100, 0b00000000, \
	0b00000000, 0b00010010, 0b10010100, 0b00100100, 0b00000000, \
	0b00000000, 0b00010010, 0b10010111, 0b10100100, 0b00000000, \
	0b00000000, 0b00010010, 0b10010100, 0b00111000, 0b00000000, \
	0b00000000, 0b00010010, 0b10010100, 0b00100100, 0b00000000, \
	0b00000000, 0b00011110, 0b01100111, 0b10100100, 0b00000000
