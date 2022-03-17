.include "m8def.inc" 

.def temp    = r16                        // simbolic names to registers
.def timer_0 = r17
.def timer_2 = r18

.equ BITRATE = 9600 
.equ BAUD = 8000000 / (16 * BITRATE) - 1  // to reg UBRR (Uart Baud rate reg)

.equ TIMER_INT_1 = 0x02
.equ TIMER_INT_2 = 0x01

.macro TIMER_INT
		ldi r21, 0xFF
		ldi r22, @0
		sub r21, r22
		out @1, r21
.endm

	.dseg                                // data seg

	.cseg                                // program seg
	.org 0                               // reset initial address 
		rjmp Reset 
	.org $004
		rjmp TIM0_OVF 
	.org $009
		rjmp TIM2_OVF
	.org $00b
		rjmp USART_RXC
	.org $00d  
		rjmp USART_TXC



Reset: 
	ldi temp, high(RAMEND)				// stack init, where u can put all interrupts
	out SPH, temp						// RAMEND - the tip of the stack
	ldi temp, low(RAMEND)
	out SPL, temp 

	ldi temp, high(BAUD) 
	out UBRRH, temp      
	ldi temp, low(BAUD)
	out UBRRL, temp 

	ldi temp, 0b11011000                // enable RXCIE, TXCIE, RXEN, TXEN
	out UCSRB, temp      

	ldi temp, 0b10000110				// enable URSEL & UCSZ (8 bit)
	out UCSRC, temp						

	ldi temp, 0xff						// out PORTD
	out DDRD, temp 

	ldi temp, 0b00000101				// CS1 - divider on 1024
	out TCCR2, temp
	out TCCR0, temp    

	ldi temp, 0b01000001
	out TIMSK, temp					    // in TIMSK enable TOIE1
	out TIFR, temp					    // in TOV1 enable TIFR 		

	TIMER_INT TIMER_INT_1, TCNT0	
	TIMER_INT TIMER_INT_2, TCNT2     
	
		
sei

main: 
	rjmp main

TIM0_OVF:     
cli  
	ldi	ZL, LOW(2*ping)
	ldi	ZH, HIGH(2*ping)

	rcall puts

	TIMER_INT TIMER_INT_1, TCNT0 
sei 
reti        
 
TIM2_OVF:
cli 
	ldi	ZL, LOW(2*pong)
	ldi	ZH, HIGH(2*pong)
	 
	rcall puts
	//rcall substruction

	TIMER_INT TIMER_INT_2, TCNT2
sei                 
reti            
         

USART_RXC:
	cli				   // disable interrupts
	sbis UCSRA, RXC      // wait for data to be received
		rjmp UCSRA
	sei	
reti			   // enable interrupts


USART_TXC:
	cli				   // disable interrupts
	sbis UCSRA, UDRE      // wait for data to be received
		rjmp USART_RXC 
	sei				   // enable interrupts
reti


puts:	
	lpm	r19, Z+				// load character from pmem
	cpi	r19, 0				// check if null
	breq puts_end			// branch if null

puts_wait:
	sbis UCSRA, UDRE
	rjmp puts_wait

	out	UDR, r19			// transmit character
	rjmp puts				// repeat loop

puts_end:
	reti	


substruction:
	sbis UCSRA, UDRE
	rjmp substruction

	ldi r21, TIMER_INT_1
	ldi r22, TIMER_INT_2
	sub r21, r22

	out	UDR, r21
reti
	


ping: .db "ping\n\r", 0
pong: .db "pong\n\r", 0