; 
; Perso.asm
;
; Created: 10-04-18 15:33:49
; Author : Zhao CHOW
;

.INCLUDE "m328pdef.inc"		; Load addresses of (I/O) registers

.ORG 0x0000
RJMP init					; First instruction that is executed by the microcontroller
.ORG 0x001A
RJMP Timer1InterruptStart	; First instruction executed by the Timer1 Interrupt
.ORG 0x002A
RJMP ADCInterruptStart		; First instruction executed by the ADC Interrupt

.INCLUDE "keyboard.asm"
.INCLUDE "screen.asm"
.INCLUDE "utilities.asm"
.INCLUDE "snake.asm"

; R0,R1 are used as subroutine output registers (used freely, interrupts need to save them)
; R2,R3 are used as subroutine input registers (used freely, interrupts need to save them)
; R16,R17,R18 are mostly used for temporary computations

; Keyboard definitions
.DEF BtnNb = R19			; Define R19 as the pressed keyboard button

; Joystick definitions
.DEF JoystickUD = R20		; Use R20 for the ADC converted value of the Joystick UP/DOWN
.DEF JoystickLR = R21		; Use R21 for the ADC converted value of the Joystick LEFT/RIGHT

; #################################################################
init:
; Configure output pins
CBI DDRB,0					; Pin PB0 is an input
SBI PORTB,0					; Enable the pull-up resistor (Output HIGH -> switch LOW)

RCALL ScreenInit			; Screen initialization
RCALL SnakeInit				; Snake initialization
RCALL TimersInit			; Timers initialization
RCALL ADCInit				; ADC initialization

; #################################################################
main:
RCALL Display				; Refresh screen
RCALL GetBtnNb				; Get button number in R0
MOV BtnNb,R0				; Load button number to BtnNb for others to use

RJMP main					; Repeat the whole loop







; ########################################################################################
; Timer(s) initialization
; Input(s): /
; Output(s): /
TimersInit:
; Save register(s) to be used on the stack
PUSH R16

; ####################
; Timer0 used for the random seed
LDI R16,0b00000011
OUT TCCR0B,R16				; Init Timer0 with prescaler 64
LDI R16,0
OUT TCNT0,R16				; Init Timer0 Counter to 0

; ####################
; Timer1
LDI R16,0b00000011
STS TCCR1B,R16				; Init Timer1 with prescaler 64
; Start Counter at 34 286 (8 Hz)
LDI R16,0x85
STS TCNT1H,R16				; Init Timer1 Counter high byte
LDI R16,0xEE
STS TCNT1L,R16				; Init Timer1 Counter low byte

; ####################
SEI							; Set Global Interrupt Enable bit
LDI R16,0b00000001
STS TIMSK1,R16				; Set Timer1 Overflow Interrupt Enable bit

; Restore register(s) from the stack (reverse order)
POP R16
RET							; Return from subroutine

; ########################################################################################
; Execute the snake logic
Timer1InterruptStart:
; Save register(s) to be used on the stack
PUSH R16
IN R16,SREG					; Get Flag Status Register
PUSH R16
PUSH R0
PUSH R1
PUSH R2
PUSH R3
PUSH YL
PUSH YH

MOV R2,BtnNb				; Copy button number (input of SnakeMain)
RCALL SnakeMain				; Execute snake logic

; Set Timer1 counter
LDI YL,FoodL				; Load address of food in SRAM
LDI YH,FoodH
LDD R16,Y+2
STS TCNT1H,R16				; Init Timer1 Counter high byte
LDD R16,Y+3
STS TCNT1L,R16				; Init Timer1 Counter low byte

; Restore register(s) from the stack (reverse order)
POP YH
POP YL
POP R3
POP R2
POP R1
POP R0
POP R16
OUT SREG,R16
POP R16
RETI						; Return from interrupt

; ########################################################################################
; Initialize the ADC. Start convervion on ADC0
; Input(s): /
; Output(s): /
ADCInit:
; Save register(s) to be used on the stack
PUSH R16

LDI R16,0b01100000			; Voltage reference AVCC, Left Adjust Result, ADC0 selection
STS ADMUX,R16

SEI							; Set Global Interrupt Enable bit
LDI R16,0b11001111			; ADC Enable, Start Conversion, Interrupt Enable, Prescaler 128
STS ADCSRA,R16

; Restore register(s) from the stack (reverse order)
POP R16
RET

; ########################################################################################
; Convert the values of the Joystick. Start a new conversion at the end of the interrupt
ADCInterruptStart:
; Save register(s) to be used on the stack
PUSH R16
IN R16,SREG
PUSH R16
PUSH R17

LDS R16,ADMUX				; Load ADC Multiplexer Selection Register
BST R16,0					; Store bit 0 of ADMUX in T flag
BRTS ADCInterruptP12		; If T flag set, ADC1
	LDS JoystickLR,ADCH			; Else ADC0, load 8 bits result (left adjusted) in JoystickLR
	RJMP ADCInterruptP2			; Go to next part

	ADCInterruptP12:
	LDS JoystickUD,ADCH			; ADC1, load 8 bits result (left adjusted) in JoystickUD

; Switch ADC input channel (between ADC0 and ADC1) and start conversion
ADCInterruptP2:
LDI R17,0b00000001			; Load bit 0 flipping mask
EOR R16,R17					; Flip bit 0 of ADMUX (switch between ADC0 and ADC1)
STS ADMUX,R16				; Store back ADMUX
LDI R17,0b01000000			; Load bit 6 setting mask
LDS R16,ADCSRA				; Load ADC Control and Status Register A
OR R16,R17					; Set bit 6 of ADCSRA (Start Conversion bit)
STS ADCSRA,R16				; Store back ADCSRA

; Restore register(s) from the stack (reverse order)
POP R17
POP R16
OUT SREG,R16
POP R16
RETI						; Return from interrupt