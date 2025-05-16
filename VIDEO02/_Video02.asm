	DEVICE ZXSPECTRUM256
	LABELSLIST "_Video02.lab"

;используется драйвер от fatall (кусок кода от #6000 до #8000)	
;изменения в новом драйвере версии 0,25
;Код #C вместо #4 для перемещения вперёд-назад по каталогу
;При считывании файла код #5 в HL - куда, в A- сколько секторов, в DE - с какого сектора, BC = 0 (старшие адреса сектора)
;Перед кодом #5 вызвать код #3 (открытие файла)
;;
	
COM_DEV equ #6009 ;адрес драйвера FAT, менеджер устройств
COM_FAT equ #626c ;адрес драйвера FAT
;#b000 - здесь будут переменные и буферы, с адреса #c000 свободно
;изначально таблица при открытии файла строится с адреса #b800 
;адрес таблицы переделан на #8400, и может расти до #af00, после чего начинает затирать другие переменные
;таблицы хватит примерно на файл в 10 мегабайт, но наверное может меняться в зависимости от типа раздела, размера кластера

;ИМЕНА ДЛЯ ВЫЗОВА МЕНЕДЖЕРА УСТРОЙСТВ
Devfind EQU 0
Set_vol EQU 1
Kol_vol EQU 2

;ИМЕНА ДЛЯ ВЫЗОВА FAT ДРАЙВЕРА
Wc_fat  EQU 0
Getfzap EQU 1
Ent_dir EQU 2
Getlong EQU 3
Positf  EQU 4
Openfil EQU 5
Nextsec EQU 6

buf_tmp equ #c000-128 ;временный буфер для первого сектора
interrupt_vec equ #c000-256-1 ;указатель на обработчик прерываний


	org #6000
start_
	incbin "READFATX.C" ;драйвер
	
;патчи драйвера
	org #79a8 ;работа с портами напрямую без #3d2f
	in a,(c)
	ret
	ds 5

	org #7992
	out (c),a
	ret
	ds 5
	
	org #799a ;здесь переход на ldir для определения версии
	;пока не трогаем

	org #78ed ;здесь чтение сектора без #3d2f
	ld a,#20
	ex af,af'
	dup 8
	ld b,d
	ini
	ld b,e
	ini
	edup
	ex af,af'
	dec a
	jr nz,#78ef
	ret
	
	; org #750c ;отключаем проверку карты на NGS
	; ret
	; org #7512
	; ret
	
;	
	
	
	
;ПРИМЕР ИСПОЛЬЗОВАНИЯ
        ORG #8000
		jr start2
note	db 47 ;нота (скорость звука), можно менять из бейсика
volume  db #40 ;громкость звука
delay_v db 5 ;задержка между кадрами видео
file_name_a db "VIDEO   GMA ",0,0 ;имя файла звук
file_name_v db "VIDEO   GMV ",0,0 ;имя файла видео


start2
;WAITKEY	XOR A:IN A,(#FE):CPL:AND #1F:JR Z,WAITKEY
        DI
;ЖЕЛАТЕЛЬНО ЗАПРЕЩАТЬ НА ВРЕМА РАБОТЫ
		ld a,#04
		ld (PageSlot3DOS+1),a ;включить ПЗУ TR-DOS, иначе в эмуляторе не виден SMUC с открытыми портами
							  ;а на реальном компьютере полосы по бордюру
		ld a,#10
		ld (PageSlot3Scr+1),a ;экран 5
	    xor a
		call PageSlot3 ;включить страницу 00
		
        CALL COM_DEV :DB Devfind
;СКАНИРОВАНИЕ УСТРОЙСТВ
;СКАНИРОВАТЬ ПЕРЕД ПЕРВЫМ ОБРАЩЕНИЕМ
;К FAT И ПРИ СМЕНЕ SD КАРТОЧЕК
;ВЫЗВАТЬ МОЖНО В ЛЮБОМ МЕСТЕ
;ПОСЛЕ СКАНИРОВАНИЯ ПО ДЕФОЛТУ
;ВЫБРАН ПОСЛЕДНИЙ ИЗ НАЙДЕННЫХ

        CALL COM_DEV :DB Kol_vol
;ЗАПРОС КОЛ-ВО НАЙДЕННЫХ РАЗДЕЛОВ
;ВЫДАСТ ТОЖЕ ЧТО И ПОСЛЕ СКАНИРОВАНИЯ

		
        LD A,E: 
		cp #ff
		ret z ;выход если нет разделов
		
		push af
		ld a,#00
		ld (PageSlot3DOS+1),a ;выключить ПЗУ TR-DOS чтобы напечатать сообщения
	    xor a
		call PageSlot3 ;включить страницу 00
		pop af
		
		call select_dev ;выбор раздела пользователем


		
		push af
		
;----------		
	di ;установим прерывания 2, поскольку обычное ПЗУ отключено
	ld a,interrupt_vec/256 ;вектор
	ld i,a
	im 2
	ld hl,interrupt ;адрес обработчика
	ld ((interrupt_vec/256)*256+#ff),hl ;
	;ei
;-----------		
		
		ld a,#04
		ld (PageSlot3DOS+1),a ;включить ПЗУ TR-DOS
	    xor a
		call PageSlot3 ;включить страницу 00
		pop af
		
	
	
		;LD A,E
		CALL COM_DEV :DB Set_vol
;ВЫБОР РАЗДЕЛА. В ДАННОМ СЛУЧАЕ ВЫБРАН
;РАЗДЕЛ (КОЛИЧЕСТВО-1)
;Т.Е. ПОСЛЕДНИЙ НАЙДЕННЫЙ

        CALL COM_FAT :DB Wc_fat
;ИНИЦИАЛИЗАЦИЯ ДЛЯ ВЫБРАННОГО РАЗДЕЛА
;ВЫЗЫВАТЬ ВСЕГДА ПОСЛЕ СМЕНЕ РАЗДЕЛА
;И ПОСЛЕ СКАНИРОВАНИЯ


find_file_a ;поиск файла звука
        CALL COM_FAT :DB Getfzap
 ;       BIT 4,A
;ЗАПРОС ОПИСАТЕЛЯ ТЕКУЩЕЙ ПОЗИЦИИ
;НА ВЫХОДЕ:
;Z=1 ЭТО DIR
;Z=0 ЭТО ФАЙЛ

		
;поиск нужного файла
		;ld hl,buf_file_name
		ld de,file_name_a
		ld b,13 ;сравнение
compare_a
		ld a,(de)
		cp (hl)
		jr nz,next_file_a
		inc de
		inc hl
		djnz compare_a
		; ld bc,16 ;узнаем длину файла в секторах
		; add hl,bc
		; ld e,(hl)
		; inc hl
		; ld d,(hl)
		; srl d ;разделим на 2
		; rr e
		; ld (len_sec),de
		jr play_a ;нашли
		
next_file_a		
        LD A,4,B,1
        CALL COM_FAT :DB #c; Positf 
;ПЕРЕМОТКА ПОЗИЦИИ ВНУТРИ FAT ДРАЙВЕРА
;НА 1 ПОЗИЦИЮ ВПЕРЕД

;------------
		or a
		jr nz,find_file_a
		jp exit_ ;выход если больше файлов нет
		
		
		
play_a		
;----------
;тут файл уже нашли
		CALL COM_FAT :DB 3 ;открыть файл
;НА ВЫХОДЕ:
;Z=1 ФАЙЛ НЕ ОТКРЫТ, ЭТО DIR
;Z=0 ФАЙЛ ОТКРЫТ


;загрузка звука
	ld de,0
	ld (cur_sec),de ;в начало файла	
	call LoadFX


;поиск загрузка картинок
        LD A,2,B,1 ;перемотать снова на первый файл
        CALL COM_FAT :DB #c; Positf 
		
find_file_v ;поиск файла
        CALL COM_FAT :DB Getfzap
		
;поиск нужного файла
		;ld hl,buf_file_name
		ld de,file_name_v
		ld b,13 ;сравнение
compare_v
		ld a,(de)
		cp (hl)
		jr nz,next_file_v
		inc de
		inc hl
		djnz compare_v
		jr play_v ;нашли
		
next_file_v		
        LD A,4,B,1
        CALL COM_FAT :DB #c; Positf 

		or a
		jr nz,find_file_v
		jp exit_ ;выход если больше файлов нет
		
				
play_v		
;----------
;тут файл уже нашли
		CALL COM_FAT :DB 3 ;открыть файл

	
;вывод картинок
	;ei
	;halt
	ld de,0
	ld (cur_sec),de ;в начало файла	
	

	
	ld a,#3b
	call PageSlot3 ;включить страницу 3b
	ld hl,#c000
	ld (hl),#0f ;подготовка страницы пикселей
	ld de,#c001
	ld bc,16000-1
	ldir
	ld a,#39
	call PageSlot3 ;включить страницу 39
	ld hl,#c000
	ld (hl),#0f ;подготовка страницы пикселей
	ld de,#c001
	ld bc,16000-1
	ldir
	
	ld a,#79	
	call PageSlot3 ; включить страницу атрибутов 79
	ld hl,#c000
	ld (hl),#00 ;очистка страницы атрибутов
	ld de,#c001
	ld bc,16000-1
	ldir
	
	call gmxscron ;включить расширенный экран	
	
	;запустить звук
	ld a,1
	call SENDDATA
	ld a,#80
	call SENDCOM
	ld a,1
	call SENDDATA
	ld a,#82
	call SENDCOM
	; ;call PlayFX
	;jp exit_
		
	ei
loadpic
;1й
		;ei
		;halt
		;di
		;call gmxscron ;включить расширенный экран
		call delay
		ld a,#10
		ld (PageSlot3Scr+1),a ;экран 5
		ld a,#7b	
		call PageSlot3 ; включить страницу атрибутов 7b	
		
		;сначала первый сектор
		ld a,1 ;
		ld de,(cur_sec) ;с какого сектора начать
		ld bc,#0
		LD HL,#C000 ;у картинок нужно убирать заголовок
;АДРЕС КУДА ГРУЗИТЬ СЕКТОР С FAT
        CALL COM_FAT :DB 5
;ЗАГРУЗКА ОЧЕРЕДНОГО СЕКТОРА НАЧИНАЯ С 0
;Z=1 ФАЙЛ ЕЩЕ НЕ КОНЧИЛСЯ
;Z=0 ФАЙЛ КОНЧИЛСЯ
;В ДАННОМ СЛУЧАЕ ГРУЗИТ СЕКТОРА
;ПОКА ФАЙЛ НЕ КОНЧИТСЯ		
		jr nz,exit_ ;выход если файл кончился
		;ld (cur_adr),hl
		ld hl,(cur_sec) ;на следующий сектор
		inc hl
		ld (cur_sec),hl
;loadpic1
		;перенос остатка первого сектора затирая заголовок
		ld hl,#c000+128
		ld de,#c000
		ld bc,512-128
		ldir
		
		;остальные
		ld a,16384/512-1 ;секторов в картинке
		ld de,(cur_sec) ;с какого сектора начать
		;ld hl,(cur_adr)
		ld bc,#0
		LD HL,#C000+512-128 ;сектор с заголовком уже загружен

        CALL COM_FAT :DB 5
		jr nz,exit_ ;выход если файл кончился	

		ld hl,(cur_sec) ;на следующий кадр
		ld bc,16384/512-1
		add hl,bc
		ld (cur_sec),hl

;2й
		;перенос остатка временно
		ld hl,#c000+16000+128
		ld de,buf_tmp
		ld bc,128
		ldir
		;ei
		;halt
		;di
		;call gmxscron ;включить расширенный экран
		call delay
		ld a,#18
		ld (PageSlot3Scr+1),a ;экран 7
		ld a,#79	
		call PageSlot3 ; включить страницу атрибутов 79
		
		ld hl,buf_tmp ;перенос остатка на место
		ld de,#c000
		ld bc,128
		ldir
		
		ld a,16384/512-1 ;секторов в картинке 
		; ld (cur_adr),hl
; loadpic2
		ld de,(cur_sec)
		ld bc,#0
        LD HL,#C000+128 ;второй кадр со сдвигом		

        CALL COM_FAT :DB 5
		jr nz,exit_ ;выход если файл кончился
		
		ld hl,(cur_sec)
		ld bc,16384/512-1
		add hl,bc
		ld (cur_sec),hl	

		jp loadpic;продожить
		
exit_ ;выход	

	ld a,#ff ;выключить звук
	call SENDDATA
	ld a,#3a ;выключить звук
	call SENDCOM

		xor a
		ld (PageSlot3DOS+1),a ;вернуть обычный DOS
		
		call gmxscroff ;обычный экран
		ld a,#10
		ld (PageSlot3Scr+1),a ;экран 5
	    ld a,#00
		call PageSlot3 ;включить страницу 00
		LD 	HL,10072
		EXX
		im 1
		ei
		ret
	
	
select_dev ;выбор устройства и раздела
	ld ixl,a ;запомнить сколько разделов
	add a,"0"-1 ;подготовить сообщение выбора разделов
	ld (message_dev_dig),a
	exx
	ld hl,message_dev
	ld ixh,11
select_dev_mes
	ld a,(hl)
	rst 16 ;печать
	inc hl
	dec ixh
	jr nz,select_dev_mes
	ld a,13
	rst 16
	ld a,13
	rst 16
	exx	
	
select_dev_print	
	ld a,(hl) ;код раздела
	exx
	sub 3
	;exx
	ld c,a
	ld b,0
	ld hl,table_dev-8
	ld bc,8
select_dev2
	add hl,bc
	dec a
	jr nz,select_dev2
	ld ixh,8 ;длина для печати
select_dev1
	ld a,(hl)
	rst 16 ;печать
	inc hl
	dec ixh
	jr nz,select_dev1
	ld a,13
	rst 16 ;след. строка
	exx
	ld bc,8 ;на следующий раздел
	add hl,bc
	dec ixl
	jr nz,select_dev_print
	
	
select_dev3	
	ei
	halt
	di
	ld 	a,(23556) ;сист. переменная нажатая клавиша 
	cp "0"
	jr nz,select_dev31
	ld a,0 ;выбрать раздел 0
	ret
select_dev31
	cp "1"
	jr nz,select_dev32
	ld a,1 ;выбрать раздел 1
	ret
select_dev32
	cp "2"
	jr nz,select_dev33
	ld a,2 ;выбрать раздел 2
	ret
select_dev33
	cp "3"
	jr nz,select_dev34
	ld a,3 ;выбрать раздел 3
	ret
select_dev34
	jr select_dev3
	
	


;cur_adr dw 0 ;текущий адрес загрузки
cur_sec dw 0 ;текущий сектор
;len_sec dw 0 ;длина в секторах
message_dev 
	db "Select 0-"
message_dev_dig	
	db "0"
	db ":"
table_dev
	db "SD ZC   "
	db "SD NeoGS"
	db "HDD Nemo"
	db "HDD Smuc"

gmxscron
            ld      bc,#7efd
            ld      a,#c8
            out     (c),a
            ; ld      bc,#7ffd
            ; ld      a,#10    ;5 screen
            ; out     (c),a
            ret
			
; gmxscron2
            ; ld      bc,#7efd
            ; ld      a,#c8
            ; out     (c),a
            ; ld      bc,#7ffd
            ; ld      a,#18    ;7 screen
            ; out     (c),a
            ; ret
			
gmxscroff
            ld      bc,#7efd
            ld      a,#c0
            out     (c),a
            ; ld      bc,#7ffd
            ; ld      a,#10    ;5 screen
            ; out     (c),a
            ret	
			
PageSlot3 
; драйвер памяти для TR-DOS Navigator
; и Scorpion GMX 2Mb
         ; org  #5b00
         ; jr   pag_on
         ; jr   clock
         ; db   #00
         ; db   #00

         push hl
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
PageSlot3DOS
		 or #00 ; #04 тут выбор ПЗУ TRDOS
         out  (c),a
         pop  af
         push af
         and  #07
PageSlot3Scr ;тут выбор экрана и ПЗУ
         or   #0 ;#18
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
         pop  hl
         ret
; clock    ld   d,%00100000
         ; rst  8
         ; db   #89
         ; ret

         ; org  #5b5c ; здесь системная переменая
         ; db   #10
;все страницы
table    db   #00,#01,#02,#03,#04,#05,#06,#07,#08,#09
         db   #0a,#0b,#0c,#0d,#0e
         db   #0f,#10,#11,#12,#13,#14
         db   #15,#16,#17,#18,#19,#1a
         db   #1b,#1c,#1d,#1e,#1f,#20
         db   #21,#22,#23,#24,#25,#26
         db   #27,#28,#29,#2a,#2b,#2c
         db   #2d,#2e,#2f,#30,#31,#32
         db   #33,#34,#35,#36,#37,#38,#39
         db   #3a,#3b,#3c,#3d,#3e,#3f,#40
         db   #41,#42,#43,#44,#45,#46
         db   #47,#48,#49,#4a,#4b,#4c

         db   #4d,#4e,#4f,#50,#51,#52
         db   #53,#54,#55,#56,#57,#58
         db   #59,#5a,#5b,#5c,#5d,#5e
         db   #5f,#60,#61,#62,#63,#64
         db   #65,#66,#67,#68,#69,#6a
         db   #6b,#6c,#6d,#6e,#6f,#70
         db   #71,#72,#73,#74,#75,#76
         db   #77,#78,#79,#7a,#7b,#7c,#7d,#7e
         db   #7f

         db   #ff ;конец таблицы



delay	;цикл задержки между кадрами
		ei
		ld hl,delay_v ;пауза между кадрами
delay1
		ld a,(frame) ;счётчик кадров
		cp (hl)
		jr nc,delay_e ;выход если достигли нужной задержки
		halt
		jr delay1
delay_e		
		xor a
		ld (frame),a ;счётчик кадров
		;di
		ret
		
		
;раздел звука для GS
;После загрузки эти параметры устанавливаются в определенные значения, как то: 
;Note=60, Volume=#40, FineTune=0, SeekFirst=#0F, SeekLast=#0F, Priority=#80, 
;No Loop и внутренняя переменная CurFX устанавливается равной FX_Handle.
;А вот как можно закачать сэмпл:
GSCOM EQU 187
GSDAT EQU 179
LoadFX ;загрузка сэмпла
		ld a,1 ; грузим по 1 сектору
		ld de,(cur_sec) ;
		ld bc,#0
		LD HL,#C000 ;
        CALL COM_FAT :DB 5
		jr nz,WAIT; если всё загрузили
		ld hl,(cur_sec) ;след. сектор
		inc hl
		ld (cur_sec),hl	
	
	LD HL,#c000
	LD DE,0-512	;1 сектор загрузим в GS
	LD C,GSCOM
	LD A,#38
	CALL SENDCOM
	LD A,#D1
	CALL SENDCOM
	LD A,(HL)
LOOP: IN B,(C)
	JP P,READY
	IN B,(C)
	JP M,LOOP
READY: OUT (GSDAT),A
	INC HL
	LD A,(HL)
	INC E
	JP NZ,LOOP
	INC D
	JP NZ,LOOP
	jr LoadFX ;продолжить загрузу
	
WAIT: 
	LD C,GSCOM
	IN B,(C) ;Ждем принятия
	JP M,WAIT ;последнего байта
	LD A,#D2
	CALL SENDCOM
; Теперь переопределяем параметры
; сэмпла по умолчанию своими
; значениями
	;LD IX,Parameters
	LD A,(note) ;(IX+#00)
	OUT (GSDAT),A ; Нота
	LD A,#40
	CALL SENDCOM
	LD A,(volume) ;(IX+#01)
	OUT (GSDAT),A ; Громкость
	LD A,#41
SENDCOM: ;это SC
	OUT (GSCOM), A 
WAITCOM: ;это WC
	IN A,(GSCOM)
	RRCA
	JR C,WAITCOM
	RET
SENDDATA ;это SD
	OUT (GSDAT),A
	ret

PlayFX ;Проигрывание эффекта.
	; SD FX_Handle - номер сэмпла
	; SC #39
	; WC
	;ld a,1 ;номер семпла
	call SENDDATA
	ld a,#39
	call SENDCOM
	ret
	
; Parameters
	; db 45,#40 ;нота, громкость
;


	;org #6450 ;обработчик прерывания
interrupt
	; push af
	; push bc
	; push de
	push hl
	; exx
	; ex af,af'
	; push af
	; push bc
	; push de
	; push hl
	; push ix
	; push iy
	; call #6500
	ld hl,frame
	inc (hl)
	; pop iy
	; pop ix
	; pop hl
	; pop de
	; pop bc
	; pop af
	; ex af,af'
	; exx
	pop hl
	; pop de
	; pop bc
	; pop af
	ei
	ret
frame db 0


	; org #c000 ;тестовый звук
; sndtest
	; ;incbin "sndtest.wav"
; sndtestend
	
end_
	SAVETRD "DISK.TRD",|"VIDEO02.C",start_,end_-start_