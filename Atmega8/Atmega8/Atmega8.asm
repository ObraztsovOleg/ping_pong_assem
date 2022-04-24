.include "m8def.inc" 

.def			temp = r16                        // simbolic names to registers
.def			count_i = r22
.def			count_j = r23
.def			timer_1_reg = r24
.def			timer_2_reg = r25
.def			status = r20

.equ			BITRATE = 9600 
.equ			BAUD = 8000000 / (16 * BITRATE) - 1  // to reg UBRR (Uart Baud rate reg)
.equ			num_of_var_bytes = 20
.equ			num_of_str_1_bytes = 20
.equ			num_of_str_2_bytes = 20

.macro print_string
				ldi	ZL, LOW(2*@0)   // 1 cycle
				ldi	ZH, HIGH(2*@0)  // 1 cycle
				rcall puts			// 3 cycles

				.endmacro

.macro degree
				mov	r18, @0

				ldi temp, @1
				ldi r17, 1

				one_time:
				cpi r18, 0
				breq @2

				mul r17, temp
				dec r18
				mov r17, r0

				rjmp one_time

				.endmacro

.macro change_timer
				print_string @0

				rcall start_p_X_reg
				ldi count_j, 0
				rcall getc

				ldi r21, 0x00
				rcall start_p_X_reg
				rcall check_num

				mov @1, r21

				cbr status, 0x01
				rcall start_p_X_reg

				sei
				reti

				.endmacro

.macro change_string
				print_string @0
				rcall start_p_X_reg
				rcall getc_str

				ldi count_j, 0

				ldi	YL, LOW(@1)
				ldi	YH, HIGH(@1)

				rcall start_p_X_reg

				one_more_time:

					ld r19, X+
					inc count_i
					st Y+, r19
					inc count_j

				cpi r19, 0
				brne one_more_time
				
				rcall start_p_X_reg
				rcall start_p_Y_reg

				cbr status, 0x01
				sbr status, @2

				reti

				.endmacro

.dseg

.org			SRAM_START
var:			.byte num_of_var_bytes
str_1:			.byte num_of_str_1_bytes
str_2:			.byte num_of_str_2_bytes

.cseg

.org 0			rjmp Reset
.org $004		rjmp TIM2_OVF
.org $009		rjmp TIM0_OVF
.org $00b		rjmp USART_RXC
.org $00d		rjmp USART_TXC


Reset:			ldi temp, high(RAMEND)				// stack init, where u can put all interrupts
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

				ldi temp, 0b00000101
				out TCCR0, temp
				ldi temp, 0b00000111
				out TCCR2, temp  

				ldi temp, 0b01000001
				out TIMSK, temp
				out TIFR, temp

				ldi timer_1_reg, 0xFF
				out TCNT0, timer_1_reg
				ldi timer_2_reg, 0xFF
				out TCNT2, timer_2_reg

				ldi	XL, LOW(var)
				ldi	XH, HIGH(var)

				ldi status, 0x00
				ldi count_i, 0x00
				ldi count_j, 0x00

				sei

main:			rjmp main
           
TIM0_OVF:		cli 
				
				sbrc status, 0
				rjmp pass_ping
					
				sbrc status, 1
				rjmp printY_1

				print_string ping
				rjmp pass_ping

				printY_1:
				ldi	YL, LOW(str_1)
				ldi	YH, HIGH(str_1)

				rcall puts_Y

				pass_ping:

				out TCNT0, timer_1_reg
				sei
                
				reti

TIM2_OVF:		cli 

				sbrc status, 0
				rjmp pass_pong
					
				sbrc status, 2
				rjmp printY_2

				print_string pong
				rjmp pass_pong

				printY_2:
				ldi	YL, LOW(str_2)
				ldi	YH, HIGH(str_2)

				rcall puts_Y

				pass_pong:

				out TCNT2, timer_2_reg
				sei
				                
				reti

puts_Y:			ld	r19, Y+	
				inc count_j
				cpi	r19, 0
				breq puts_end_Y

puts_wait_Y:	sbis UCSRA, UDRE
				rjmp puts_wait_Y

				out	UDR, r19
				rjmp puts_Y

puts_end_Y:		ret

puts:			lpm	r19, Z+ 		  // 3 cycles
				cpi	r19, 0			  // 1 cycle
				breq puts_end		  // 1/2 cycles

puts_wait:		sbis UCSRA, UDRE	  // 1/2/3 cycles
				rjmp puts_wait		  // 2 cycles

				out	UDR, r19		  // 1 cycle
				rjmp puts			  // 2 cycles

puts_end:		ret					  // 4 cycles

putc:			sbis UCSRA, UDRE
				rjmp putc

				out	UDR, r17

				ret

timers_sum:		ldi r17, 0x00
				ldi r16, 0x00
				mov r19, timer_1_reg
				mov r18, timer_2_reg

				add r19, r18
				adc r17, r16
				rcall putc

				mov r17, r19
				rcall putc

				cbr status, 0x01
				sei
				reti

USART_RXC:		cli
				sbis UCSRA, RXC
				rjmp USART_RXC

				sbr status, 0x01

				in r19, UDR

				cpi r19, $6d          // ASCII m
				breq print_out_menu

				cpi r19, $73          // ASCII s
				breq timers_sum

				st X+, r19
				inc count_i

				out UDR, r19

				cpi r19, $0D
				breq check_input

				sei	
				reti

print_out_menu: print_string change_timer_1
				print_string change_timer_2
				print_string reset_timers
				print_string change_str_timer_1
				print_string change_str_timer_2

				sei
				reti

USART_TXC:		cli				      // disable interrupts
				sbis UCSRA, UDRE      // wait for data to be received
				rjmp USART_TXC

				sei				      // enable interrupts
				reti

getc_str:		sbis UCSRA, RXC
				rjmp getc_str

				in r19, UDR

				cpi r19, $0D
				breq end_getc_str

				out UDR, r19

				st X+, r19
				inc count_i

				rjmp getc_str

end_getc_str:	ldi r19, 0
				st X+, r19
				inc count_i

				ret

str_1_changing:	change_string str_1_chang_input, str_1, 0x02

check_input:	rcall start_p_X_reg
				
				ld r19, X+
				inc count_i

				cpi r19, '1'
				breq timer_1_chang

				cpi r19, '2'
				breq timer_2_chang

				cpi r19, '3'
				breq reseting_timers

				cpi r19, '4'
				breq str_1_changing

				cpi r19, '5'
				breq str_2_changing

				cbr status, 0x01
				rcall start_p_X_reg

				sei
				reti

reseting_timers:
				print_string reset_input
				ldi timer_1_reg, 0xFF
				out TCNT0, timer_1_reg
				ldi timer_2_reg, 0xFF
				out TCNT2, timer_2_reg

				cbr status, 0x01
				rcall start_p_X_reg

				sei
				reti

timer_1_chang:	change_timer time_1_input, timer_1_reg

timer_2_chang:	change_timer time_2_input, timer_2_reg

str_2_changing: change_string str_2_chang_input, str_2, 0x04

check_num:		cpi count_j, 4
				brsh print_error

				ld r19, X+
				inc count_i
				dec count_j

				degree count_j, 10, end_degree
				end_degree:

				mul r17, r19
				mov r17, r0
				add r21, r17
				brcs print_error

				cpi count_j, 0
				breq end_check_num

				rjmp check_num

end_check_num:	ret
				
start_p_X_reg:	cpi count_i, 0
				breq end_start_p_X_reg

				ld r19, -X
				dec count_i

				rjmp start_p_X_reg

end_start_p_X_reg:
				ret

start_p_Y_reg:	cpi count_j, 0
				breq end_start_p_Y_reg

				ld r19, -Y
				dec count_j

				rjmp start_p_Y_reg

end_start_p_Y_reg:
				ret

getc:			sbis UCSRA, RXC
				rjmp getc

				in r19, UDR

				cpi r19, $0D
				breq end_getc
		
				cpi r19, 0x3A
				brsh print_error

				out UDR, r19

				ldi temp, 48
				sub r19, temp

				st X+, r19
				inc count_i
				inc count_j

				rjmp getc

end_getc:		ret

print_error:	print_string error

				cbr status, 0x01
				rcall start_p_X_reg

				reti

ping:               .db "ping\n\r", 0
pong:               .db "pong\n\r", 0

// Menu
change_timer_1:     .db "1. Change TIMER_1\n\r", 0
change_timer_2:     .db "2. Change TIMER_2\n\r", 0
reset_timers:       .db "3. RESET TIMERS 1, 2\n\r", 0
change_str_timer_1: .db "4. Change TIMER_1_STR\n\r", 0
change_str_timer_2: .db "5. Change TIMER_2_STR\n\r", 0

// Timer 1 changing string
time_1_input:		.db "Type TIMER_1_INTERVAL:\n\r", 0

// Timer 2 changing string
time_2_input:		.db "Type TIMER_2_INTERVAL:\n\r", 0

// Timers reseting string
reset_input:		.db "RESETING TIMERS...:\n\r", 0

// String 1 changing string
str_1_chang_input:	.db "Type STR_1:\n\r", 0

// String 2 changing string
str_2_chang_input:	.db "Type STR_2:\n\r", 0

error:				.db "ERROR", 0