;****************************************************************************
;*               Lab Project: Robot Guidance Challenge                      *
;*                                                                          *
;*                                                                          *
;* Date: December 1, 2023                                                   *
;* EEBOT#: 31445                                                            *
;* Authors: Zoravar Multani, Andrew Le, Taha Ghori						              *
;****************************************************************************
              
               XDEF Entry, _Startup     ; External definitions for Entry and _Startup
               ABSENTRY Entry           ; Absolute entry point at Entry
               INCLUDE 'derivative.inc' ; Include file for derivative-specific information

;*******************************************************************
;* Path Detection Threshold Values 																 *
;*******************************************************************       
A_PTH_THRSH      EQU $CA    ; Lowest threshold value for sensor A
B_PTH_THRSH      EQU $CC    ; Lowest threshold value for sensor B      
C_PTH_THRSH      EQU $CA    ; Lowest threshold value for sensor C
D_PTH_THRSH      EQU $CC    ; Lowest threshold value for sensor D

E_PTH_THRSH      EQU $90   ; Threshold value for Sensors E and F, shift right
F_PTH_THRSH      EQU $65   ; Threshold value for Sensors E and F, shift left

;*******************************************************************
;* Displacement Values 																						 *
;*******************************************************************
INC_D        EQU 400   ; Distance to move
FWD_D        EQU 1200  ; Distance to go forward
REV_D        EQU 1000  ; Distance to reverse
STR_D        EQU 1200  ; Distance
TRN_D        EQU 14800 ; Distance to turn
UTRN_D       EQU 12600 ; Distance to u-turn

;*******************************************************************
;* Intersection Values 																						 *
;*******************************************************************
PRIM_PATH    EQU 0 ; Primary route
SEC_PATH    EQU 1 ; Secodonary route

;*******************************************************************
;* EEBot States 																								   *
;*******************************************************************
START          EQU 0 ; Start
FWD            EQU 1 ; Forward
REV            EQU 2 ; Reverse
RT_TRN         EQU 3 ; Right turn
LFT_TRN         EQU 4 ; Left turn
BACK_TRCK         EQU 5 ; Backtrack
STND_BY        EQU 6 ; Stop

;*******************************************************************
;* Liquid Crystal Display Equates - From the manual 							 *
;*******************************************************************
CLEAR_HOME     EQU $01 ; Clear the display and home the cursor
INTERFACE      EQU $38 ; 8 bit interface, two line display
CURSOR_OFF     EQU $0C ; Display on, cursor off
SHIFT_OFF      EQU $06 ; Address increments, no character shift
LCD_SEC_LINE   EQU 64  ; Starting addr. of 2nd line of LCD (note decimal value!)

;*******************************************************************
;* LCD Addresses - From the manual 																 *
;*******************************************************************
LCD_CNTR 	EQU PTJ 	; LCD Control Register: E = PJ7, RS = PJ6
LCD_DAT 	EQU PORTB ; LCD Data Register: D7 = PB7, ... , D0 = PB0
LCD_E 		EQU $80 	; LCD E-signal pin
LCD_RS 		EQU $40 	; LCD RS-signal pin

;*******************************************************************
;* Codes - From the manual 																				 *
;*******************************************************************
NULL           EQU 00    ; The string ’null terminator’
CR             EQU $0D   ; ’Carriage Return’ character
SPACE          EQU ' '   ; The ’space’ character 

;*******************************************************************
;* Variables and Data 																						 *
;*******************************************************************
               ORG   $3850 
                
CRNT_STATE     DC.B  6  ; Current state register

COUNT1         DC.W  0  ; Initializing first counter value
COUNT2         DC.W  0  ; Initializing second counter value

A_DETN         DC.B  0  ; Path detection "boolean" for Sensor A (PATH = 1, NO PATH = 0)
B_DETN         DC.B  0  ; Path detection "boolean" for Sensor B (PATH = 1, NO PATH = 0)
C_DETN         DC.B  0  ; Path detection "boolean" for Sensor C (PATH = 1, NO PATH = 0)
D_DETN         DC.B  0  ; Path detection "boolean" for Sensor D (PATH = 1, NO PATH = 0)
E_DETN         DC.B  0  ; Path detection "boolean" for Sensor E (PATH = 1, NO PATH = 0)
F_DETN         DC.B  0  ; Path detection "boolean" for Sensor F (PATH = 1, NO PATH = 0)

RETURN         DC.B  0  ; RETURN (TRUE = 1, FALSE = 0)
NEXT_DIR       DC.B  1  ; Next direction instruction

TEN_THOUS      DS.B  1  ; 10,000 digit
THOUSANDS      DS.B  1  ; 1,000 digit
HUNDREDS       DS.B  1  ; 100 digit
TENS           DS.B  1  ; 10 digit
UNITS          DS.B  1  ; 1 digit
BCD_SPARE      DS.B  10 ; Used in the 'leading zero' blanking
NO_BLANK       DS.B  1  ; Extra space for the decimal point and string terminator

;*******************************************************************
;* Storage for guider sensor readings 														 *
;******************************************************************* 
SENSOR_LINE    DC.B  $0 ; Sensor E-F (LINE )  
SENSOR_BOW     DC.B  $0 ; Sensor A (FRONT)    
SENSOR_PORT    DC.B  $0 ; Sensor B (LEFT )    
SENSOR_MID     DC.B  $0 ; Sensor C (MIDDLE)   
SENSOR_STBD    DC.B  $0 ; Sensor D (RIGHT)   
SENSOR_NUM     DC.B   1 ; Current selected sensor

;*******************************************************************
;* Variables for LCD Displays 																		 *
;******************************************************************* 
TOP_LINE       RMB 20   ; Top line of display
               FCB NULL ; terminated by null
BOT_LINE       RMB 20   ; Bottom line of display
               FCB NULL ; terminated by null
CLEAR_LINE     FCC '                ' ; (around 12 spaces)
               FCB NULL ; terminated by null
TEMP           DS.B  1  ; Temporary memory location

;*******************************************************************
;* Main Code 																											 *
;*******************************************************************             
               ORG   $4000        ; Set the origin address for the main code to $4000             
Entry:                                          
_Startup:                                       
               LDS   #$4000       ; Set the stack pointer to the initial value
               CLI 								; Enable global interrupts
               
                                  ; Initialize ports, Analog/Digital (A/D), LCD; enable system timer and interrupts 
               JSR   initPORTS    ; Initialize ports              
               JSR   initAD       ; Initialize Analog/Digital             
               JSR   initLCD      ; Initialize the LCD             
               JSR   clrLCD       ; Clear the LCD screen             
               JSR   initTCNT     ; Enable the 16-bit TCNT hardware counter                                          
               
               
                                  ; initial LCD display headings                               
               JSR CLR_LCD_BUF    ; Clear the LCD buffer by writing spaces
               JSR CLR_LCD_BUF    ; Clear the LCD buffer again
							 LDX #msg1 					; Load the address of msg1
							 JSR putsLCD				; Display msg1
							 LDAA #$C0 					; Set the LCD cursor to the second row
							 JSR cmd2LCD				; Move cursor to the second row
               LDX #msg2 					; Load the address of msg2
               JSR putsLCD  			; Display msg2

;*******************************************************************
;* Main Loop 																											 *
;*******************************************************************                                  
MAIN:          JSR   UPDT_READING  ; Update sensor readings        
               JSR   UPDT_DISPL    ; Update the display      
               LDAA  CRNT_STATE    ; Load the current state      
               JSR   DISPATCHER    ; Jump to the DISPATCHER subroutine   
               BRA   MAIN 				 ; Branch back to the main loop

msg1           DC.B  "S:",0         ; Current state label
msg2           DC.B  "R:",0        ; Sensor readings label
msg3           DC.B  "V:",0         ; Battery voltage label
msg4           DC.B  "B:",0         ; Bumper status label
          
tab:           DC.B  "START  ",0
               DC.B  "FWD    ",0 
               DC.B  "REV    ",0 
               DC.B  "RT_TRN ",0 
               DC.B  "LFT_TRN ",0 
               DC.B  "RETURN ",0 
               DC.B  "PRO",0    


;*******************************************************************
;* EEBot Motor Control 			 														  				 *
;*******************************************************************   

;------------------------------------------------------------------------------------------
; Starboard (Right) Motor ON                                                               
STARON        
               BSET  PTT,%00100000
               RTS

;------------------------------------------------------------------------------------------
; Starboard (Right) Motor OFF                                                              
STAROFF       
               BCLR  PTT,%00100000
               RTS

;------------------------------------------------------------------------------------------
; Starboard (Right) Motor FWD                                                              
STARFWD       
               BCLR  PORTA,%00000010
               RTS
;------------------------------------------------------------------------------------------
; Starboard (Right) Motor REV                                                              
STARREV       
               BSET  PORTA,%00000010
               RTS

;------------------------------------------------------------------------------------------
; Port (Left) Motor ON                                                                    
PORTON        
               BSET  PTT,%00010000
               RTS

;------------------------------------------------------------------------------------------
; Port (Left) Motor OFF                                                                    
PORTOFF       
               BCLR  PTT,%00010000
               RTS

;------------------------------------------------------------------------------------------
; Port (Left) Motor FWD                                                                   
PORTFWD       
               BCLR  PORTA,%00000001
               RTS
;------------------------------------------------------------------------------------------
; Port (Left) Motor REV                                                                   
PORTREV       
               BSET  PORTA,%00000001
               RTS


;*******************************************************************
;* EEBot Subroutines (Dispatcher) 			 													 *
;*******************************************************************   

;------------------------------------------------------------------------------------------
DISPATCHER     CMPA  #START                     ; Compare accumulator with the START state
               BNE   NOT_STRT                   ; If not equal, branch to NOT_STRT
               JSR   START_ST                   ; Otherwise, jump to the START_ST subroutine
               RTS                              ; Return from DISPATCHER                          
;------------------------------------------------------------------------------------------
NOT_STRT       CMPA  #FWD                       ; Compare accumulator with the FWD state
               BNE   NOT_FWD                    ; If not equal, branch to NOT_FWD
               JMP   FWD_ST                     ; Otherwise, jump to the FWD_ST subroutine
               RTS                              ; Return from DISPATCHER           
;------------------------------------------------------------------------------------------
NOT_FWD        CMPA  #RT_TRN                    ; Compare accumulator with the RT_TRN state
               BNE   NOT_RT_TRN                 ; If not equal, branch to NOT_RT_TRN
               LDY   #1000                      ; Set a 20 ms delay for turns
               JSR   del_50us                   ; Execute a 50 microseconds delay subroutine
               JSR   RT_TRN_ST                  ; Jump to RT_TRN_ST subroutine for right turn
               RTS                             	; Return from DISPATCHER                          
;------------------------------------------------------------------------------------------
NOT_RT_TRN     CMPA  #LFT_TRN                    ; Compare accumulator with the LFT_TRN state
               BNE   NOT_LFT_TRN                 ; If not equal, branch to NOT_LFT_TRN
               LDY   #1000                      ; Set a 20 ms delay for turns
               JSR   del_50us                   ; Execute a 50 microseconds delay subroutine
               JSR   LFT_TRN_ST                  ; Jump to LFT_TRN_ST subroutine for left turn
               RTS                              ; Return from DISPATCHER                             
;------------------------------------------------------------------------------------------
NOT_LFT_TRN    CMPA  #REV                       ; Compare accumulator with the REV state
               BNE   NOT_REV                    ; If not equal, branch to NOT_REV
               JSR   REV_ST                     ; Otherwise, jump to the REV_ST subroutine
               RTS                              ; Return from DISPATCHER                             
;------------------------------------------------------------------------------------------
NOT_REV        CMPA  #BACK_TRCK                    ; Compare accumulator with the BACK_TRCK state
               BNE   NOT_BACK_TRCK                 ; If not equal, branch to NOT_BACK_TRCK
               JMP   BACK_TRCK_ST                  ; Otherwise, jump to the BACK_TRCK_ST subroutine
               RTS                              ; Return from DISPATCHER                 
;------------------------------------------------------------------------------------------
NOT_BACK_TRCK  CMPA  #STND_BY                   ; Compare accumulator with the STND_BY state
               BNE   NOT_STND_BY                ; If not equal, branch to NOT_STND_BY
               JSR   STND_BY_ST                 ; Otherwise, jump to the STND_BY_ST subroutine
               RTS                              ; Return from DISPATCHER                             
;------------------------------------------------------------------------------------------
NOT_STND_BY    NOP                              ; No operation
DISP_EXIT      RTS                              ; Return from DISPATCHER                             


;*******************************************************************
;* EEBot State Machine 			 														  				 *
;*******************************************************************   

START_ST       BRCLR PORTAD0,$04,NO_FWD        ; If "NOT" FWD_BUMP
               JSR   INIT_FWD                  ; Initialize the FORWARD state and
               MOVB  #FWD,CRNT_STATE           ; Set CRNT_STATE to FWD
               BRA   START_EXIT                ; Then exit                                                
NO_FWD         NOP                             ; Else

START_EXIT     RTS                           	 ; return to the MAIN routine
;------------------------------------------------------------------------------------------
FWD_ST         PULD                            

               BRSET PORTAD0,$04,NO_FWD_BUMP   ; Check if bot bumps into wall
               																 ; if detected, switch to second path  
               LDAA  SEC_PATH               
               STAA  NEXT_DIR                  
               JSR   INIT_REV                  ; Initialize reverse routine
               MOVB  #REV,CRNT_STATE           
               JMP   FWD_EXIT                  ; return
              
NO_FWD_BUMP    BRSET PORTAD0,$08,NO_REAR_BUMP   ; Check for REV_BUMP; if detected, initialize BACKTRACK 
               JMP   INIT_STND_BY               
               MOVB  #STND_BY,CRNT_STATE                
               JMP   FWD_EXIT                   ; return

                                                ; Choose specific subroutines based on sensor values if no bumpers detected   
NO_REAR_BUMP   LDAA  D_DETN                    ; Detected D sensor, right turn      
               BEQ   NO_D_DETECT               ; else branch to NO_D_DETECT
               
               JSR   INIT_FWD                  ; Initialize forward motion
               MOVB  #FWD, CRNT_STATE             
               
               LDY   #570                      ; Delay movement to position robot at intersection
               JSR   del_50us                   
               
               JSR   INIT_RT_TRN               ; Initialize right turn
               MOVB  #RT_TRN,CRNT_STATE         
               JMP   FWD_EXIT                  ; exit fwd subroutine   
                                               
NO_D_DETECT    LDAA B_DETN                     ; load sensor B
							 BEQ NO_B_DETECT                 ; Sensor B not detecting a line, jump to NO_B_DETECT
               LDAA A_DETN                     ; load sensor A
               BEQ LFT_TURN                     ; Sensor A = 1, jump to subroutibe
                            
               BRA NO_SHFT_LT                  ; Sensor A = 0, jump to subroutibe
                                               

LFT_TURN        JSR   INIT_FWD                   ; Initialize forward motion   
               MOVB  #FWD, CRNT_STATE           
               LDY   #570                       ; Delay movement to position robot at intersection 
               JSR   del_50us                   
               
               JSR   INIT_LFT_TRN               ; Initialize left turn
               MOVB  #LFT_TRN,CRNT_STATE         
               JMP   FWD_EXIT                  ; return  

NO_B_DETECT    LDAA  F_DETN                    ; Load Sensor F    
               BEQ   NO_SHFT_LT                ; Subroutine to adjust robot to right 
               JSR   PORTON                    ; Turn on left motor

RT_FWD_DIS     LDD   COUNT2                    
               CPD   #INC_D                  
               BLO   RT_FWD_DIS                ; If curr distance is greater than forward distance then
               JSR   INIT_FWD                  ; Turn motors off
               JMP   FWD_EXIT                  ; return   

NO_SHFT_RT     LDAA  E_DETN                    ; Load Sensor E                    
               BEQ   NO_SHFT_RT                ; Subroutine to adjust robot to left  
               JSR   STARON                    ; Turn on right motor
               
LT_FWD_DIS     LDD   COUNT1                    
               CPD   #INC_D                  
               BLO   LT_FWD_DIS                ; If curr distance is greater than forward distance then
               JSR   INIT_FWD                  ; Turn motors off
               JMP   FWD_EXIT                  ; return   

NO_SHFT_LT    JSR   STARON                    ; Turn motors on
               JSR   PORTON                    

FWD_STR_DIS    LDD   COUNT1                    
               CPD   #FWD_D                  
               BLO   FWD_STR_DIS               ; If curr distance is greater than forward distance then
               JSR   INIT_FWD                  ; Turn motors off
                
FWD_EXIT       JMP   MAIN                      ; return to main

;------------------------------------------------------------------------------------------
REV_ST         LDD   COUNT1                    ; If current distance is more than reverse distance then
               CPD   #REV_D                  ; Then u-turn
               BLO   REV_ST                    
               JSR   STARFWD                   ; Set left motor to FWD direction
               LDD   #0                        ; Restart timer
               STD   COUNT1                    
                
REV_U_TRN      LDD   COUNT1                    ; If current distance is more than u-turn distance then
               CPD   #UTRN_D                 ; Stop robot
               BLO   REV_U_TRN                 
               JSR   INIT_FWD                  ; Initialize FWD state
               LDAA  RETURN                    ; If return = 1
               BNE   BACK_TRCK_REV                
               MOVB  #FWD,CRNT_STATE           ; Then set state to FWD
               BRA   REV_EXIT                  ; and exit

BACK_TRCK_REV     JSR   INIT_FWD                  
               MOVB  #BACK_TRCK,CRNT_STATE        ; Else set state to BACK_TRCK
               
REV_EXIT       RTS                             ; return

;------------------------------------------------------------------------------------------
RT_TRN_ST      LDD   COUNT2                    ; If current distance is more than forward distance then
               CPD   #STR_D                  ; Turn robot
               BLO   RT_TRN_ST                 
               JSR   STAROFF                   ; Set left motor to OFF
               LDD   #0                        ; Restart timer
               STD   COUNT2                    
                
RT_TURN_DEL    LDD   COUNT2                    ; If current distance is more than forward turn distance then
               CPD   #TRN_D                  ; Stop robot
               BLO   RT_TURN_DEL               
               JSR   INIT_FWD                  ; Initialize the FWD state
               LDAA  RETURN                    ; If RETURN = 1 
               BNE   BACK_TRCK_RT_TRN             
               MOVB  #FWD,CRNT_STATE           ; Then set state to FWD
               BRA   RT_TRN_EXIT               ; and exit

BACK_TRCK_RT_TRN  MOVB  #BACK_TRCK,CRNT_STATE        ; Else set state to BACK_TRCK
            
RT_TRN_EXIT    RTS                             ; Return to main

;------------------------------------------------------------------------------------------
LFT_TRN_ST      LDD   COUNT1                    ; If current distance is more than forward distance then
               CPD   #STR_D                  ; Turn robot
               BLO   LFT_TRN_ST                 
               JSR   PORTOFF                   ; Set right motor to OFF
               LDD   #0                        ; Reset timer
               STD   COUNT1                    
                
LFT_TURN_DEL    LDD   COUNT1                    ; If current distance is more than forward turn distance then
               CPD   #TRN_D                  ; Stop robot
               BLO   LFT_TURN_DEL               
               JSR   INIT_FWD                  ; Initialize the FWD state
               LDAA  RETURN                    ; If RETURN = 1 
               BNE   BACK_TRCK_LFT_TRN             
               MOVB  #FWD,CRNT_STATE           ; Then set state to FWD
               BRA   LFT_TRN_EXIT               ; and exit

BACK_TRCK_LFT_TRN  MOVB  #BACK_TRCK,CRNT_STATE        ; Else set state to BACK_TRCK

LFT_TRN_EXIT    RTS                             ; Return to main

;------------------------------------------------------------------------------------------ 
BACK_TRCK_ST      PULD                            ;
               BRSET PORTAD0,$08,NO_BK_BUMP    ; If REV_BUMP, then stop
               JSR   INIT_STND_BY              ; Initialize the INIT_STND_BY state
               MOVB  #STND_BY,CRNT_STATE       ; set the state to STND_BY
               JMP   BACK_TRCK_EXIT               ; and exit

NO_BK_BUMP     LDAA  NEXT_DIR                  ; If NEXT_DIR = 0
               BEQ   GOOD_PATH                 ; branch to "good" pathing                                 
               BNE   BAD_PATH                  ; branch to "bad" (alternate) pathing                        

;--------------------------------------------------------------------------------------------  
GOOD_PATH      LDAA  D_DETN                    ; If D_DETN = 1
               BEQ   NO_RT_TRN                 ; Make right turn
               
               PULA                            ; Pull next direction value from stack
               PULA                            ; Store it in NEXT_DIR
               STAA  NEXT_DIR                  
               JSR   INIT_RT_TRN               ; Initialize the RT_TRN state
               MOVB  #RT_TRN,CRNT_STATE        ; Set CRNT_STATE to RT_TRN
               JMP   BACK_TRCK_EXIT               ; Exit

NO_RT_TRN      LDAA  B_DETN                    ; If B_DETN = 1
               BEQ   RT_LINE_S                 ; Check if A_DETN = 1
               LDAA  A_DETN                    ; If A_DETN = 1 a FORWARD path exists
               BEQ   LEFT_TURN                 ; Pull forward
               PULA                            ; Pull next direction value from stack
               PULA                            ; and store it in NEXT_DIR
               STAA  NEXT_DIR                    ; ""
               BRA   NO_LINE_S                 ; Else if A_DETN = 0

LEFT_TURN      PULA                            ; Pull Left turn
               PULA                            ; Pull next direction value from stack
               STAA  NEXT_DIR                  ; Store it in NEXT_DIR
               JSR   INIT_LFT_TRN               ; Initialize the LFT_TRN state
               MOVB  #LFT_TRN,CRNT_STATE        ; Set CRNT_STATE to LFT_TRN
               JMP   BACK_TRCK_EXIT               ; Exit

;--------------------------------------------------------------------------------------------
BAD_PATH       LDAA  B_DETN                    ; If B_DETN = 1
               BEQ   NO_LFT_TRN                 ; The robot should make a LEFT turn
               PULA                            ; Pull next direction value from stack
               STAA  NEXT_DIR                  ; and store it in NEXT_DIR
               JSR   INIT_LFT_TRN               ; Initialize the LFT_TRN state
               MOVB  #LFT_TRN,CRNT_STATE        ; Set CRNT_STATE to LFT_TRN
               JMP   BACK_TRCK_EXIT               ; and exit

NO_LFT_TRN      LDAA  D_DETN                    ; If D_DETN equals 1
               BEQ   RT_LINE_S                 ; Check if A_DETN equals 1
               LDAA  A_DETN                    ; If A_DETN equals 1 a FORWARD path exists
               BEQ   RIGHT_TURN                ; The robot should continue forward
               PULA                            ; Pull next direction value from stack
               STAA  NEXT_DIR                   ; and store it in NEXT_DIR
               BRA   NO_LINE_S                 ; Else if A_DETN equals 0

RIGHT_TURN     PULA                            ; The robot should make a RIGHT turn
               STAA  NEXT_DIR                  ; Pull next direction value from stack
               JSR   INIT_RT_TRN               ; Initialize the RT_TRN state
               MOVB  #RT_TRN,CRNT_STATE        ; Set CRNT_STATE to RT_TRN
               JMP   BACK_TRCK_EXIT               ; Exit

;--------------------------------------------------------------------------------------------
RT_LINE_S      LDAA  F_DETN                    ; Else if F_DETN equals 1
               BEQ   LT_LINE_S                 ; Robot shift right
               JSR   PORTON                    ; Turn on the left motor

RT_FWD_D       LDD   COUNT2                    
               CPD   #INC_D                  
               BLO   RT_FWD_D                  ; If current distance is more than forward distance then
               JSR   INIT_FWD                  ; Turn motors off
               JMP   BACK_TRCK_EXIT               ; Exit

LT_LINE_S      LDAA  E_DETN                    ; Else if F_DETN equals 1
               BEQ   NO_LINE_S                 ; Robot shift right
               JSR   STARON                    ; Turn on the left motor

LT_FWD_D       LDD   COUNT1                    ;
               CPD   #INC_D                  ;
               BLO   LT_FWD_D                  ; If current distance is more than forward distance then
               JSR   INIT_FWD                  ; Turn motors off
               JMP   BACK_TRCK_EXIT               ; Exit

NO_LINE_S      JSR   STARON                    ; Turn motors on
               JSR   PORTON                    

FWD_STR_D:     LDD   COUNT1                    
               CPD   #FWD_D                  
               BLO   FWD_STR_D                 ; If current distance is more than forward distance then
               JSR   INIT_FWD                  ; Turn motors off
                
BACK_TRCK_EXIT    JMP   MAIN                      ; Return to main

;--------------------------------------------------------------------------------------------
STND_BY_ST     BRSET PORTAD0,$04,NO_START      ; If FWD_BUMP
               BCLR  PTT,%00110000             ; Initialize the START state
               MOVB  #START,CRNT_STATE         ; Set CRNT_STATE to START
               BRA   STND_BY_EXIT              ; Exit
                                                
NO_START       NOP                             ; Else

STND_BY_EXIT   RTS                             ; Return to main

;*******************************************************************
;* EEBot Roaming States 		 														  				 *
;*******************************************************************   
INIT_FWD       BCLR  PTT,%00110000             ; Turn OFF the drive motors
               LDD   #0                        ; Reset timer to start from zero   
               STD   COUNT1                    ; ""
               STD   COUNT2                    ; ""
               BCLR  PORTA,%00000011           ; Set FWD direction for both motors
               RTS

;--------------------------------------------------------------------------------------------
INIT_REV       BSET  PORTA,%00000011           ; Set REV direction for both motors
               LDD   #0                        ; Reset timer to start from zero   
               STD   COUNT1                    ; ""
               BSET  PTT,%00110000             ; Turn ON the drive motors
               RTS

;--------------------------------------------------------------------------------------------
INIT_RT_TRN    BCLR  PORTA,%00000011           ; Set FWD direction for both motors
               LDD   #0                        ; Reset timer to start from zero   
               STD   COUNT2                    ; ""
               BSET  PTT,%00110000             ; Turn ON the drive motors
               RTS

;--------------------------------------------------------------------------------------------
INIT_LFT_TRN    BCLR  PORTA,%00000011           ; Set FWD direction for both motors
               LDD   #0                        ;; Reset timer to start from zero   
               STD   COUNT1                    ; ""
               BSET  PTT,%00110000             ; Turn ON the drive motors
               RTS

;--------------------------------------------------------------------------------------------
INIT_BACK_TRCK    INC   RETURN                    ; Change RETURN value to 1
               PULA                            ; Pull the next direction value from the stack
               STAA  NEXT_DIR                    ; and store it in NEXT_DIR
               JSR   INIT_REV                  ; Initialize the REVERSE routine
               JSR   REV_ST                    ; Jump to REV_ST
               JMP   MAIN

;--------------------------------------------------------------------------------------------
INIT_STND_BY   BCLR  PTT,%00110000             ; Turn off the drive motors
               RTS
                

;*******************************************************************
;* Sesnor Readings Subroutines 			 											  			 *
;*******************************************************************   
UPDT_READING   JSR   G_LEDS_ON                 ; Turn ON LEDS
               JSR   READ_SENSORS              ; Take readings from sensors
               JSR   G_LEDS_OFF                ; Turn OFF LEDS
                
               LDAA  #0                        ; Set sensor A detection value to 0
               STAA  A_DETN                    ; Sensor A
               STAA  B_DETN                    ; Sensor B
               STAA  C_DETN                    ; Sensor C
               STAA  D_DETN                    ; Sensor D
               STAA  E_DETN                    ; Sensor E
               STAA  F_DETN                    ; Sensor F
               
CHECK_A        LDAA  SENSOR_BOW                ; If SENSOR_BOW is GREATER than
               CMPA  #A_PTH_THRSH                ; Specific A Sensor value while on path   
               BLO   CHECK_B                   ; Else, leave A_DETN = 0 and move onto B   
               INC   A_DETN                    ; Set A_DETN to 1

CHECK_B        LDAA  SENSOR_PORT               ; If SENSOR_PORT is GREATER than
               CMPA  #B_PTH_THRSH                ; Specific B Sensor value while on path   
               BLO   CHECK_C                   ; Else, leave B_DETN = 0 and move onto C   
               INC   B_DETN                    ; Set B_DETN to 1

CHECK_C        LDAA  SENSOR_MID                ; If SENSOR_MID is GREATER than
               CMPA  #C_PTH_THRSH                ; Specific C Sensor value while on path  
               BLO   CHECK_D                   ; Else, leave C_DETN = 0 and move onto D   
               INC   C_DETN                    ; Set C_DETN to 1
                
CHECK_D        LDAA  SENSOR_STBD               ; If SENSOR_STBD is GREATER than
               CMPA  #D_PTH_THRSH                ; Specific D Sensor value while on path   
               BLO   CHECK_E                   ; Else, leave D_DETN = 0 and move onto E   
               INC   D_DETN                    ; Set D_DETN to 1

CHECK_E        LDAA  SENSOR_LINE               ; If SENSOR_LINE is LESS than
               CMPA  #E_PTH_THRSH                ; Specific E Sensor value while on path   
               BHI   CHECK_F                   ; Else, leave E_DETN = 0 and move onto F   
               INC   E_DETN                    ; Set E_DETN to 1
                
CHECK_F        LDAA  SENSOR_LINE               ; If SENSOR_LINE is GREATER than
               CMPA  #F_PTH_THRSH                ; Specific F Sensor value while on path   
               BLO   READ_COMPL                ; Else, leave F_DETN = 0 and exit subroutine   
               INC   F_DETN                    ; Set F_DETN to 1
                
READ_COMPL     RTS

;--------------------------------------------------------------------------------------------
G_LEDS_ON      BSET  PORTA,%00100000           ; Set bit 5
               RTS

G_LEDS_OFF     BCLR  PORTA,%00100000           ; Clear bit 5
               RTS

;--------------------------------------------------------------------------------------------
READ_SENSORS   CLR   SENSOR_NUM                ; Select sensor number 0
               LDX   #SENSOR_LINE              ; Point at the start of the sensor array

RS_MAIN_LOOP   LDAA  SENSOR_NUM                ; Select the correct sensor input
               JSR   SELECT_SENSOR             ; on the hardware
               LDY   #250                      ; 20 ms delay to allow the
               JSR   del_50us                  ; sensor to stabilize
               LDAA  #%10000001                ; Start A/D conversion on AN1
               STAA  ATDCTL5
               BRCLR ATDSTAT0,$80,*            ; Repeat until A/D signals done
               LDAA  ATDDR0L                   ; A/D conversion is complete in ATDDR0L
               STAA  0,X                       ; so copy it to the sensor register
               CPX   #SENSOR_STBD              ; If this is the last reading
               BEQ   RS_EXIT                   ; Then exit
               INC   SENSOR_NUM                ; Else, increment the sensor number
               INX                             ; and the pointer into the sensor array
               BRA   RS_MAIN_LOOP              ; and do it again
RS_EXIT        RTS

;--------------------------------------------------------------------------------------------
SELECT_SENSOR  PSHA                            ; Save the sensor number for the moment
               LDAA  PORTA                     ; Clear the sensor selection bits to zeros
               ANDA  #%11100011                
               STAA  TEMP                      ; and save it into TEMP
               PULA                            ; Get the sensor number
               ASLA                            ; Shift the selection number left, twice
               ASLA
               ANDA  #%00011100                ; Clear irrelevant bit positions
               ORAA  TEMP                      ; OR it into the sensor bit positions
               STAA  PORTA                     ; Update the hardware
               RTS


;*******************************************************************
;* Delay Subroutines  			 														  				 *
;*******************************************************************    
del_50us       PSHX                            ;2 E-clk Protect the X register

eloop:         LDX   #300                      ;2 E-clk Initialize the inner loop counter

iloop:         NOP                             ;1 E-clk No operation
               DBNE  X,iloop                   ;3 E-clk If the inner cntr not 0, loop again
               DBNE  Y,eloop                   ;3 E-clk If the outer cntr not 0, loop again
               PULX                            ;3 E-clk Restore the X register
               RTS                             ;5 E-clk Else return
;*******************************************************************
;* Sends a command in AccA to the LCD 			 											 *
;*******************************************************************   
cmd2LCD        BCLR  LCD_CNTR,LCD_RS           ; select the LCD Instruction Register (IR)
               JSR   dataMov                   ; send data to IR
      	       RTS

;*******************************************************************
;* Outputs the character in accumulator in A to LCD *
;*******************************************************************
putcLCD BSET 	 LCD_CNTR,LCD_RS 								 ; select the LCD Data register (DR)
							 JSR dataMov 										 ; send data to DR
							 RTS

;*******************************************************************
;* Outputs a NULL-terminated string pointed to by X *
;*******************************************************************
putsLCD        LDAA  1,X+                      ; get one character from the string
               BEQ   donePS                    ; reach NULL character?
               JSR   putcLCD
               BRA   putsLCD

donePS 	       RTS

;*******************************************************************
;* Sends data to the LCD IR or DR depening on RS *
;*******************************************************************
dataMov        BSET  LCD_CNTR,LCD_E            ; pull the LCD E-sigal high
               STAA  LCD_DAT                   ; send the upper 4 bits of data to LCD
               BCLR  LCD_CNTR,LCD_E            ; pull the LCD E-signal low to complete the write oper.
               LSLA                            ; match the lower 4 bits with the LCD data pins
               LSLA                            ; -"-
               LSLA                            ; -"-
               LSLA                            ; -"-
               BSET  LCD_CNTR,LCD_E            ; pull the LCD E signal high
               STAA  LCD_DAT                   ; send the lower 4 bits of data to LCD
               BCLR  LCD_CNTR,LCD_E            ; pull the LCD E-signal low to complete the write oper.
               LDY   #1                        ; adding this delay will complete the internal
               JSR   del_50us                  ; operation for most instructions
               RTS
;*******************************************************************
;* Integer to BCD Conversion Routine *
;*******************************************************************
int2BCD        XGDX                            ; Save the binary number into .X
               LDAA  #0                        ; Clear the BCD_BUFFER
               STAA  TEN_THOUS
               STAA  THOUSANDS
               STAA  HUNDREDS
               STAA  TENS
               STAA  UNITS
               STAA  BCD_SPARE
               STAA  BCD_SPARE+1

               CPX   #0                        ; Check for a zero input
               BEQ   CON_EXIT                  ; and if so, exit

               XGDX                            ; Not zero, get the binary number back to .D as dividend
               LDX   #10                       ; Setup 10 (Decimal!) as the divisor
               IDIV                            ; Divide: Quotient is now in .X, remainder in .D
               STAB  UNITS                     ; Store remainder
               CPX   #0                        ; If quotient is zero,
               BEQ   CON_EXIT                  ; then exit

               XGDX                            ; else swap first quotient back into .D
               LDX   #10                       ; and setup for another divide by 10
               IDIV
               STAB  TENS
               CPX   #0
               BEQ   CON_EXIT

               XGDX                            ; Swap quotient back into .D
               LDX   #10                       ; and setup for another divide by 10
               IDIV
               STAB  HUNDREDS
               CPX   #0
               BEQ   CON_EXIT

               XGDX                            ; Swap quotient back into .D
               LDX   #10                       ; and setup for another divide by 10
               IDIV
               STAB  THOUSANDS
               CPX   #0
               BEQ   CON_EXIT

               XGDX                            ; Swap quotient back into .D
               LDX   #10                       ; and setup for another divide by 10
               IDIV
               STAB  TEN_THOUS

CON_EXIT:      RTS                             ; 

;*******************************************************************
;* BCD to ASCII Conversion Routine                                 *
;*******************************************************************
BCD2ASC:       LDAA  #$0                       ; Initialize the blanking flag
               STAA  NO_BLANK

C_TTHOU:       LDAA  TEN_THOUS                 ; 
               ORAA  NO_BLANK
               BNE   NOT_BLANK1

ISBLANK1:      LDAA  #$20                      ; 
               STAA  TEN_THOUS                 ; 
               BRA   C_THOU                    ; 

NOT_BLANK1:    LDAA  TEN_THOUS                 ; 
               ORAA  #$30                      ; Convert to ascii
               STAA  TEN_THOUS
               LDAA  #$1                       ; 
               STAA  NO_BLANK

C_THOU:        LDAA  THOUSANDS                 ; Check the thousands digit for blankness
               ORAA  NO_BLANK                  ; 
               BNE   NOT_BLANK2
                     
ISBLANK2:      LDAA  #$30                      ; Thousands digit is blank
               STAA  THOUSANDS                 ; so store a space
               BRA   C_HUNS                    ; and check the hundreds digit

NOT_BLANK2:    LDAA  THOUSANDS                 ; 
               ORAA  #$30
               STAA  THOUSANDS
               LDAA  #$1
               STAA  NO_BLANK

C_HUNS:        LDAA  HUNDREDS                  ; Check the hundreds digit for blankness
               ORAA  NO_BLANK                  ; 
               BNE   NOT_BLANK3

ISBLANK3:      LDAA  #$20                      ; Hundreds digit is blank
               STAA  HUNDREDS                  ; so store a space
               BRA   C_TENS                    ; and check the tens digit
                     
NOT_BLANK3:    LDAA  HUNDREDS                  ; 
               ORAA  #$30
               STAA  HUNDREDS
               LDAA  #$1
               STAA  NO_BLANK

C_TENS:        LDAA  TENS                      ; Check the tens digit for blankness
               ORAA  NO_BLANK                  ; 
               BNE   NOT_BLANK4
                     
ISBLANK4:      LDAA  #$20                      ; Tens digit is blank
               STAA  TENS                      ; so store a space
               BRA   C_UNITS                   ; and check the units digit

NOT_BLANK4:    LDAA  TENS                      ; 
               ORAA  #$30
               STAA  TENS

C_UNITS:       LDAA  UNITS                     ; No blank check necessary, convert to ascii.
               ORAA  #$30
               STAA  UNITS

               RTS                             ; 

;*******************************************************************
;* Binary to ASCII                                                 *
;*******************************************************************
HEX_TABLE:     FCC '0123456789ABCDEF'          ; Table for converting values

BIN2ASC:       PSHA                            ; Save a copy of the input number on the stack
               TAB                             ; and copy it into ACCB
               ANDB #%00001111                 ; Strip off the upper nibble of ACCB
               CLRA                            ; D now contains 000n where n is the LSnibble
               ADDD #HEX_TABLE                 ; Set up for indexed load
               XGDX                
               LDAA 0,X                        ; Get the LSnibble character
               PULB                            ; Retrieve the input number into ACCB
               PSHA                            ; and push the LSnibble character in its place
               RORB                            ; Move the upper nibble of the input number
               RORB                            ;  into the lower nibble position.
               RORB
               RORB 
               ANDB #%00001111                 ; Strip off the upper nibble
               CLRA                            ; D now contains 000n where n is the MSnibble 
               ADDD #HEX_TABLE                 ; Set up for indexed load
               XGDX                                                               
               LDAA 0,X                        ; Get the MSnibble character into ACCA
               PULB                            ; Retrieve the LSnibble character into ACCB
               RTS

;--------------------------------------------------------------------------------------------

;*******************************************************************
;* Used to display values on the LCD                               *
;*******************************************************************
DP_FRONT_SENSOR EQU TOP_LINE+3   ; First Value Shown on Top Line
DP_PORT_SENSOR  EQU BOT_LINE+0   ; First Value shown on Bottom Line
DP_MID_SENSOR   EQU BOT_LINE+3   ; Second Value shown on Bottom Line
DP_STBD_SENSOR  EQU BOT_LINE+6   ; Third Value shown on Bottom Line
DP_LINE_SENSOR  EQU BOT_LINE+9   ; Fourth Value shown on Bottom Line

UPDT_DISPL     LDAA  #$82                      ; Move LCD cursor to the end of msg1
               JSR   cmd2LCD                   ;
                
               LDAB  CRNT_STATE                ; Display current state
               LSLB                            ; "
               LSLB                            ; "
               LSLB                            ; "
               LDX   #tab                      ; "
               ABX                             ; "
               JSR   putsLCD                   ; "

               LDAA  #$8F                      ; Move LCD cursor to the end of msg2
               JSR   cmd2LCD                   ; ""
               LDAA  SENSOR_BOW                ; Convert value from SENSOR_BOW to a
               JSR   BIN2ASC                   ; Two digit hexidecimal value
               JSR   putcLCD                   ; ""
               EXG   A,B                       ; ""
               JSR   putcLCD                   ; ""

               LDAA  #$92                      ; Move LCD cursor to Line position 
               JSR   cmd2LCD                   ; ""
               LDAA  SENSOR_LINE               ; Convert value from SENSOR_BOW to a
               JSR   BIN2ASC                   ; Two digit hexidecimal value
               JSR   putcLCD                   ; ""
               EXG   A,B                       ; ""
               JSR   putcLCD                   ; ""

               LDAA  #$CC                      ; Move LCD cursor to Port position on 2nd row 
               JSR   cmd2LCD                   ; ""
               LDAA  SENSOR_PORT               ; Convert value from SENSOR_BOW to a
               JSR   BIN2ASC                   ; Two digit hexidecimal value
               JSR   putcLCD                   ; ""
               EXG   A,B                       ; ""
               JSR   putcLCD                   ; ""

               LDAA  #$CF                      ; Move LCD cursor to Mid position on 2nd row 
               JSR   cmd2LCD                   ; ""
               LDAA  SENSOR_MID                ; Convert value from SENSOR_BOW to a
               JSR   BIN2ASC                   ; Two digit hexidecimal value
               JSR   putcLCD                   ; ""
               EXG   A,B                       ; ""
               JSR   putcLCD                   ; ""

               LDAA  #$D2                      ; Move LCD cursor to Starboard position on 2nd row 
               JSR   cmd2LCD                   ; ""
               LDAA  SENSOR_STBD               ; Convert value from SENSOR_BOW to a
               JSR   BIN2ASC                   ; Two digit hexidecimal value
               JSR   putcLCD                   ; ""
               EXG   A,B                       ; ""
               JSR   putcLCD                   ; ""

               MOVB  #$90,ATDCTL5              ; R-just., uns., sing. conv., mult., ch=0, start
               BRCLR ATDSTAT0,$80,*            ; Wait until the conver. seq. is complete
               LDAA  ATDDR0L                   ; Load the ch0 result - battery volt - into A
               LDAB  #39                       ; AccB = 39
               MUL                             ; AccD = 1st result x 39
               ADDD  #600                      ; AccD = 1st result x 39 + 600
               JSR   int2BCD
               JSR   BCD2ASC
               LDAA  #$C2                      ; move LCD cursor to the end of msg3
               JSR   cmd2LCD                   ; "                
               LDAA  TEN_THOUS                 ; output the TEN_THOUS ASCII character
               JSR   putcLCD                   ; "
               LDAA  THOUSANDS                 ; output the THOUSANDS ASCII character
               JSR   putcLCD                   ; "
               LDAA  #$2E                      ; output the HUNDREDS ASCII character
               JSR   putcLCD                   ; "
               LDAA  HUNDREDS                  ; output the HUNDREDS ASCII character
               JSR   putcLCD                   ; "                

               LDAA  #$C9                      ; Move LCD cursor to the end of msg4
               JSR   cmd2LCD
                
               BRCLR PORTAD0,#%00000100,bowON  ; If FWD_BUMP, then
               LDAA  #$20                      ;
               JSR   putcLCD                   ;
               BRA   stern_bump                ; Display 'B' on LCD
bowON          LDAA  #$42                      ; ""
               JSR   putcLCD                   ; ""
          
stern_bump     BRCLR PORTAD0,#%00001000,sternON; If REV_BUMP, then
               LDAA  #$20                      ;
               JSR   putcLCD                   ;
               BRA   UPDT_DIS_EXIT             ; Display 'S' on LCD

sternON        LDAA  #$53                      ; ""
               JSR   putcLCD                   ; ""

UPDT_DIS_EXIT  RTS                             ; and exit
;---------------------------------------------------------------------------
; Clear LCD Buffer
; This routine writes ’space’ characters (ascii 20) into the LCD display
; buffer in order to prepare it for the building of a new display buffer.
; This needs only to be done once at the start of the program. Thereafter the
; display routine should maintain the buffer properly.

CLR_LCD_BUF    LDX #CLEAR_LINE
               LDY #TOP_LINE
               JSR STRCPY
            
CLB_SECOND     LDX #CLEAR_LINE
               LDY #BOT_LINE
               JSR STRCPY

CLB_EXIT       RTS

;*************************************************************************************
; String Copy                                                                        *
; Copies a null-terminated string (including the null) from one location to          *
; another                                                                            *
; Passed: X contains starting address of null-terminated string                      *
; Y contains first address of destination                                            *
;*************************************************************************************

STRCPY         PSHX ; Protect the registers used
               PSHY
               PSHA

STRCPY_LOOP    LDAA 0,X ; Get a source character
               STAA 0,Y ; Copy it to the destination
               BEQ STRCPY_EXIT ; If it was the null, then exit
            
               INX ; Else increment the pointers
               INY
               BRA STRCPY_LOOP ; and do it again
               
STRCPY_EXIT    PULA ; Restore the registers
               PULY
               PULX
               RTS 



                
;*******************************************************************
;* Initialization of various ports and control registers           *
;*******************************************************************

;--------------------------------------------------------------------------------------------
initPORTS      BCLR  DDRAD,$FF                 ; Set PORTAD as input
               BSET  DDRA, $FF                 ; Set PORTA as output
               BSET  DDRT, $30                 ; Set channels 4 & 5 of PORTT as output
               RTS
;--------------------------------------------------------------------------------------------        
initAD         MOVB  #$C0,ATDCTL2              ; power up AD, select fast flag clear
               JSR   del_50us                  ; wait for 50 us
               MOVB  #$00,ATDCTL3              ; 8 conversions in a sequence
               MOVB  #$85,ATDCTL4              ; res=8, conv-clks=2, prescal=12
               BSET  ATDDIEN,$0C               ; configure pins AN03,AN02 as digital inputs
               RTS   
;*******************************************************************
;* Initialization of the LCD: 4-bit data width, 2-line display, 	 *
;* turn on display, cursor and blinking off. Shift cursor right.   *
;*******************************************************************

initLCD        BSET  DDRB,%11111111            ; configure pins PB7,...,PB0 for output
               BSET  DDRJ,%11000000            ; configure pins PJ7(E), PJ6(RS) for output
               LDY   #2000                     ; wait for LCD to be ready
               JSR   del_50us                  ; -"-
               LDAA  #$28                      ; set 4-bit data, 2-line display
               JSR   cmd2LCD                   ; -"-
               LDAA  #$0C                      ; display on, cursor off, blinking off
               JSR   cmd2LCD                   ; -"-
               LDAA  #$06                      ; move cursor right after entering a character
               JSR   cmd2LCD                   ; -"-
               RTS

;*******************************************************************
;* Clear display and home cursor                                   *
;*******************************************************************
clrLCD         LDAA  #$01                      ; clear cursor and return to home position
               JSR   cmd2LCD                   ; -"-
               LDY   #40                       ; wait until "clear cursor" command is complete
               JSR   del_50us                  ; -"-
               RTS              
;*******************************************************************
;* Position the Cursor                                             *
;*******************************************************************
LCD_POS_CRSR   ORAA #%10000000     ; Set the high bit of the control word
               JSR cmd2LCD         ; and set the cursor address
               RTS               
               

;*******************************************************************
;* Timer System                                                    *
;*******************************************************************
initTCNT       MOVB  #$80,TSCR1                ; enable TCNT
               MOVB  #$00,TSCR2                ; disable TCNT OVF interrupt, set prescaler to 1
               MOVB  #$FC,TIOS                 ; channels PT1/IC1,PT0/IC0 are input captures
               MOVB  #$05,TCTL4                ; capture on rising edges of IC1,IC0 signals
               MOVB  #$03,TFLG1                ; clear the C1F,C0F input capture flags
               MOVB  #$03,TIE                  ; enable interrupts for channels IC1,IC0
               RTS

; First Interrupt 
ISR1           MOVB  #$01,TFLG1                ; clear the C0F input capture flag
               INC   COUNT1                    ; increment COUNT1
               RTI

;Second Interrupt 
ISR2           MOVB  #$02,TFLG1                ; clear the C1F input capture flag
               INC   COUNT2                    ; increment COUNT2 
               RTI

;********************************************************************************************
;* Interrupt Vectors                                                                        *
;********************************************************************************************

            ORG   $FFFE
            DC.W  Entry                     ; Reset Vector

            ORG   $FFEE
            DC.W  ISR1                      ; COUNT1 INT

            ORG   $FFEC
            DC.W  ISR2                      ; COUNT2 INT