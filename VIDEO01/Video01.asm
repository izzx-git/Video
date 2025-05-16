;Видео ролик 01 для ZS GMX
loadadr equ #8000-128 ;адрес загрузки
firstpage equ 0 ;первая страница для загрузки
picondisk equ 40 ;картинок на одном диске
picall equ 120 ;картинок всего
	org	#6000
start_main	
	
;загрузка в память
	ld a,firstpage-1
	ld (curpage),a
	xor a
	call load
	ld a,1
	call load
	ld a,3
	call load
	
;просмотр
	di
	ld a,#63 ;вектор
	ld i,a
	im 2
	ld hl,#6450 ;адрес обработчика
	ld (#63ff),hl ;
	ei

	call gmxpagon2 ;включить страницу 3b
	ld hl,#8000
	ld (hl),#0f ;подготовка страницы пикселей
	ld de,#8001
	ld bc,16000-1
	ldir
	call gmxpagon ;включить страницу 39
	ld hl,#8000
	ld (hl),#0f ;подготовка страницы пикселей
	ld de,#8001
	ld bc,16000-1
	ldir
	
	call gmxatron2 ; включить страницу атрибутов 7b
	ld hl,#8000
	ld (hl),#00 ;очистка страницы атрибутов
	ld de,#8001
	ld bc,16000-1
	ldir	
	call gmxscron2 ;включить расширенный экран 7
	
	ld b,2*50 ;пауза пока вступление музыки
playloop2
	halt
	djnz playloop2
	
main
	ld a,firstpage-1
	ld (curpage),a
	ld ixl,picall ;цикл картинок
playloop
	ld b,3 ;пауза
playloop1
	halt
	djnz playloop1
    ld a,(curpage) ;след. страница
	inc a
	ld (curpage),a
	
	bit 0,a ;выбор экрана
	jr z,scr2	
	ld a,#10
	jr scr1
scr2
	ld a,#18
scr1
	ld (PageSlot3Scr+1),a
    ld a,(curpage)	
	call PageSlot3 ;включить страницу с очередным кадром в слот 3
	
	ld a,(curpage)
	bit 0,a
	jr z,evenn1
	call gmxatron2 ;страница 7B
	jr evenn2
evenn1
	call gmxatron ;страница 79
evenn2

	ld hl,#c000 ;перенос картинки
	ld de,#8000
	ld bc,16000
	ldir

	dec ixl
	jr nz,playloop	

;ожидание клавиши и повтор	
WAITKEY	XOR A:IN A,(#FE):CPL:AND #1F:JR Z,WAITKEY
	jr main
	;ret

load	;загрузка в память
	call driveSel ;выбрать диск
	ld de,#0100 ;текущие сектор дорожка на первый файл
    ld (#5cf4),de ;установим	

	ld ixl,picondisk ;цикл картинок
loadloop
    ld a,(curpage)
	inc a
	ld (curpage),a
	call PageSlot2
	ld      hl,loadadr ;куда
    ld      de,(#5cf4) ;текущие сектор дорожка
    ld      bc,#3f05 ;читать 63 сектора
    call    #3d13
	;call gmxscron ;включить расширенный экран			
	dec ixl
	jr nz,loadloop
	ret	
	
curpage db 0

driveSel ;настройка на диск
            ld      (#5d19) ,a
            ld      c,1
            call    #3d13
            ld      c,#18
            call    #3d13
			ret
			
gmxpagon
            ld      bc,#78fd
            ld      a,#3b  ;39
            out     (c),a
            ret

gmxatron
            ld      bc,#78fd
            ld      a,#7b  ;79
            out     (c),a
            ret
gmxpagon2 ;второй экран пиксели
            ld      bc,#78fd
            ld      a,#39  ;3b
            out     (c),a
            ret

gmxatron2 ;второй экран атрибуты
            ld      bc,#78fd
            ld      a,#79  ;7b
            out     (c),a
            ret			
			
			
gmxpagoff
            ld      bc,#78fd
            ld      a,#00  ;02
            out     (c),a
            ret
gmxscron
            ld      bc,#7efd
            ld      a,#c8
            out     (c),a
            ld      bc,#7ffd
            ld      a,#10    ;5 screen
            out     (c),a
            ret
			
gmxscron2
            ld      bc,#7efd
            ld      a,#c8
            out     (c),a
            ld      bc,#7ffd
            ld      a,#18    ;7 screen
            out     (c),a
            ret
gmxscroff
            ld      bc,#7efd
            ld      a,#c0
            out     (c),a
            ld      bc,#7ffd
            ld      a,#10    ;5 screen
            out     (c),a
            ret		


PageSlot2 ;включение банка из A в слот памяти 2
         ld   hl,table
         add  a,l
         jr   nc,PageSlot2_1
         inc  h          ;коррекция
PageSlot2_1  ld   l,a
         ld   a,(hl)
		 
	xor 2
	ld bc,#78fd
	out (c),a	
	ret		 

	
PageSlot3	
; драйвер памяти для TR-DOS Navigator
; и Scorpion GMX 2Mb
         ; org  #5b00
         ; jr   pag_on
         ; jr   clock
         ; db   #00
         ; db   #00

        ;push hl
         ld   hl,table
         add  a,l
         jr   nc,PageSlot3_1
         inc  h          ;коррекция
PageSlot3_1  ld   l,a
         ld   a,(hl)
         ;pop  hl
         ;cp   #ff
         ;scf
         ;ret  z
         ;push bc
         push af
         rlca
         and  #10
         ld   bc,#1ffd
         out  (c),a
         pop  af
         push af
         and  #07
PageSlot3Scr ;тут выбор экрана и ПЗУ
         or   #10
         ld   b,#7f
         out  (c),a
         pop  af
         rrca
         rrca
         rrca
         rrca
         and  #07
         ld   b,#df
         out  (c),a
         ;pop  bc
         ret
; clock    ld   d,%00100000
         ; rst  8
         ; db   #89
         ; ret

         ; org  #5b5c ; здесь системная переменая
         ; db   #10
;страницы кроме 00,02,05,07,08,09,39,3b,79,7b
table    db   #01,#03,#04,#06
         db   #0a,#0b,#0c,#0d,#0e
         db   #0f,#10,#11,#12,#13,#14
         db   #15,#16,#17,#18,#19,#1a
         db   #1b,#1c,#1d,#1e,#1f,#20
         db   #21,#22,#23,#24,#25,#26
         db   #27,#28,#29,#2a,#2b,#2c
         db   #2d,#2e,#2f,#30,#31,#32
         db   #33,#34,#35,#36,#37,#38
         db   #3a,#3c,#3d,#3e,#3f,#40
         db   #41,#42,#43,#44,#45,#46
         db   #47,#48,#49,#4a,#4b,#4c

         db   #4d,#4e,#4f,#50,#51,#52
         db   #53,#54,#55,#56,#57,#58
         db   #59,#5a,#5b,#5c,#5d,#5e
         db   #5f,#60,#61,#62,#63,#64
         db   #65,#66,#67,#68,#69,#6a
         db   #6b,#6c,#6d,#6e,#6f,#70
         db   #71,#72,#73,#74,#75,#76
         db   #77,#78,#7a,#7c,#7d,#7e
         db   #7f

         db   #ff ;конец таблицы	
	
	org #6450 ;прерывания
	push af
	push bc
	push de
	push hl
	exx
	ex af,af'
	push af
	push bc
	push de
	push hl
	push ix
	push iy
	call #6500
	pop iy
	pop ix
	pop hl
	pop de
	pop bc
	pop af
	ex af,af'
	exx
	pop hl
	pop de
	pop bc
	pop af
	ei
	ret
	
	org #6500 ;
	incbin "DUCKT.C"

end_main
	
	SAVETRD "DISKA.TRD",|"VIDEO01.C",start_main,end_main-start_main