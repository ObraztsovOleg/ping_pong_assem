# ping_pong_assem
You can test this project in the proteus software. Just launch the Atmego8 simulation with 8 MHz in proteus and load the firmware to it. Be happy)

# Let's take a look
TIM0_OVF:
				
            cli                     // 1 cycle
	    sbrc status, 0          // 1/2/3 cycles
            rjmp pass_ping          // 2 cycles

            sbrc status, 1          // 1/2/3 cycles
            rjmp printY_1           // 2 cycles

            print_string ping       // summary - 81 cycles
            rjmp pass_ping          // 2 cycles

            printY_1:
            ldi	YL, LOW(str_1)      // 1 cycle
            ldi	YH, HIGH(str_1)     // 1 cycle

            rcall puts_Y            // 3 cycles

            pass_ping:

            out TCNT0, timer_1_reg  // 1 cycle
            sei                     // 1 cycle

            reti                    // 4 cycles
            
When it's interrupt the TIM0 is enabled. Then code start execution on TIM0_OVF label. Les's calculate a word printing time. 
     - Initialy, I'll compute printing a world of "ping\n\r\0". Before we achive the print_string line, the timer will clock 1 + 3 + 3 = 7 cycles. 
    - Then it's macro will execute the code inner it in 1 + 1 + 3 + (3 + 1 + 1 + 3 + 1 + 2) * 6 (bites "p + i + n + g + \n + \r" ) + 3 + 1 + 2 + 4 = 81 cycles.
    - Finally, it will end execution of the timer code in 2 + 1 + 1 + 4 = 8 cycles.
    
Summary, les's compute the time that programm will spend on timer interrupt execution in case "ping\n\r\0" printing:
    7 + 81 + 8 = 96 cycles. That's 96 / 8 000 000 = 12 мks.
    
The timer prescaler is set to 8. That means the minimum output time will be in 12 tacts of one of the timer with this prescaler. So, the mininum range between two timers should be 12 tacts or 96 cycles or 12 mks in other case it will be an ERROR.

