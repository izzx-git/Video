	DEVICE ZXSPECTRUM256
	LABELSLIST "_Video.lab"
;Видео для ZS GMX

;используется драйвер FAT и устройств из FATALL v 0.25 (by savelij) (кусок кода от #6000 до #8000)	
;изменения в новом драйвере версии 0,25
;Код #C вместо #4 для перемещения вперёд-назад по каталогу
;При считывании файла код #5 в HL - куда, в A- сколько секторов, в DE - с какого сектора, BC = 0 (старшие адреса сектора)
;Перед кодом #5 вызвать код #3 (открытие файла)
;;
	
COM_DEV equ #6009 ;адрес драйвера FAT, менеджер устройств
COM_FAT equ #626c ;ОБЩАЯ ТОЧКА ВХОДА ДЛЁ РАБОТЫ С FAT
;#b000 - здесь будут переменные и буферы, с адреса #c000 свободно, может даже с #b800, если не открывать файл
;изначально таблица при открытии файла строится с адреса #b800, но можно заменить около 7 цифр в файле на другой адрес
;пробовал адрес таблицы переделать на #8400, она могла расти до #af00, после чего начинала затирать другие переменные
;таблицы хватит примерно на файл в 10 мегабайт, но наверное, может меняться в зависимости от типа раздела, размера кластера
;но можно не открывать файл, а читать по секторам самостоятельно, узнав адрес первого кластера, тогда размер не ограничен
;
;размер кластера обычно 4096 = 8 секторов

REALSEC equ #6606
;ВЯЧИСЛЕНИЕ РЕАЛЬНОГО СЕКТОРА
;НА ВХОДЕ BCDE=НОМЕР FAT
;НА ВЫХОДЕ BCDE=АДРЕС СЕКТОРА

TO_DRV equ #6003 ;вызов текущего драйвера. Лучше через него, а не конкретный драйвер
;ЗАГРУЖАЕМ СЕКТОР В БУФЕР - пример
;LOADLST LD HL,BUF_512:PUSH HL
;CALL TO_DRV:DB 2:POP HL:RET
	
;#77F1 - драйвер SMUC, номер сектора ему нужен реальный
;Входные параметры общие:
;HL-адрес загрузки в память
;BCDE-32-х битный номер сектора
;A-количество блоков (блок = 512 байт)
;только для многоблочной записи/чтении
	

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
	
	org #7829 ;отключим проверку нужных байт в TRDOS
	;nop
	;nop

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
	org #752d ; с картой GS всё равно не работает подгрузка звука
	jr #74d7
	
;	
	
	
	
;Начало здесь
        ORG #8000
		;jr start2

start
	call cls_pic
;WAITKEY	XOR A:IN A,(#FE):CPL:AND #1F:JR Z,WAITKEY
        DI
	;установим прерывания 2, поскольку обычное ПЗУ отключено
	ld a,interrupt_vec/256 ;вектор
	ld i,a
	im 2
	ld hl,interrupt ;адрес обработчика
	ld ((interrupt_vec/256)*256+#ff),hl ;
	
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
		or a
		jr nz,no_part
		ld hl,message_no_part
		call print
		jp  exit_basic ;выход если нет разделов
no_part		
		cp 11
		jr c,max_part
		ld a,10 ;максимум 10 разделов
max_part
		
		call select_dev ;выбор раздела пользователем
	
	
		;LD A,E
		CALL COM_DEV :DB Set_vol
;ВЫБОР РАЗДЕЛА. В ДАННОМ СЛУЧАЕ ВЫБРАН
;РАЗДЕЛ (КОЛИЧЕСТВО-1)
;Т.Е. ПОСЛЕДНИЙ НАЙДЕННЫЙ

        CALL COM_FAT :DB Wc_fat
;ИНИЦИАЛИЗАЦИЯ ДЛЯ ВЫБРАННОГО РАЗДЕЛА
;ВЫЗЫВАТЬ ВСЕГДА ПОСЛЕ СМЕНЕ РАЗДЕЛА
;И ПОСЛЕ СКАНИРОВАНИЯ

		call fill_cat

		ei
		jp shell ;запуск оболочки
		



fill_cat
;заполнение каталога
		ld ix,cat
		xor a
		ld (files_r),a ;файлов всего
		ld (files),a
		ld hl,cat ;очистка временного каталога
		ld de,cat+1
		ld bc,256*16
		ld (hl),0
		ldir
		
find_file_a ;поиск файлов для каталога

        CALL COM_FAT :DB Getfzap
 ;       BIT 4,A
;ЗАПРОС ОПИСАТЕЛЯ ТЕКУЩЕЙ ПОЗИЦИИ
;НА ВЫХОДЕ:
;Z=1 ЭТО DIR
;Z=0 ЭТО ФАЙЛ

		
;Добавление во временный каталог
		push ix
		pop de
		ld bc,11
		ldir
		ld bc,16
		add ix,bc
		ld a,(files_r)
		inc a
		ret z ;проверка что каталог максимум 255 элементов
		ld (files_r),a	
		ld (files),a		
		
next_file_a		
        LD A,4,B,1
        CALL COM_FAT :DB #c; Positf 
;ПЕРЕМОТКА ПОЗИЦИИ ВНУТРИ FAT ДРАЙВЕРА
;НА 1 ПОЗИЦИЮ ВПЕРЕД

;------------
		or a
		jr nz,find_file_a
		ret
		



find_file ;поиск файла
        LD A,2,B,1 ;перемотать снова на первый файл
        CALL COM_FAT :DB #c; Positf 
		
find_file_v ;поиск файла
        CALL COM_FAT :DB Getfzap
		
;поиск нужного файла
		;ld hl,buf_file_name
		ld de,file_name_v
		ld b,11 ;сравнение
compare_v
		ld a,(de)
		cp (hl)
		jr nz,next_file_v
		inc de
		inc hl
		djnz compare_v
		ld a,1 ;на выходе a!=0 если нашли
		or a
		ret ;нашли
		
next_file_v		
        LD A,4,B,1
        CALL COM_FAT :DB #c; Positf 
;ПЕРЕМОТКА ПОЗИЦИИ ВНУТРИ FAT ДРАЙВЕРА
;НА 1 ПОЗИЦИЮ ВПЕРЕД
		or a
		jr nz,find_file_v
		ret ;выход если больше файлов нет, значит не нашли, a=0


PlayV
;поиск и загрузка видео

	call find_file
	ret z
				
;play_v		
;----------
;тут файл уже нашли
		;CALL COM_FAT :DB 3 ;открыть файл
	
;вывод картинок
	ld bc,9 ;HL указывает на запись в каталоге
	add hl,bc
	ld c,(hl)
	inc hl
	ld b,(hl)
	ld de,5 ;HL указывает на запись в каталоге
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)	
	push hl
	call REALSEC
	pop hl
	ld (cur_sec_de),de ;запомним адрес сектора FAT
	ld (cur_sec_bc),bc ;
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld (len_file_l),de ;запомним длину файла
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld (len_file_h),de ;запомним длину файла старшие
	; ld b,4
; dev
	; rr h ;разделим на 4096
	; rr l
	; rr d
	; rr e
	; djnz dev
	; ld b,0
	; ld c,h
	; ld d,l	
	; ld e,d
	; ld (len_clust_h),bc ;размер в кластерах
	; ld (len_clust_l),de
	ld hl,0
	ld (cur_file_pos_l),hl ;в начало файла
	ld (cur_file_pos_h),hl
	xor a
	ld (cur_scr),a ;первый экран

	
	
	ld a,(type_video) ;
	cp "Z"
	jp z,PlayV_zx ;перейти формат для классики



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
	


	ld a,#7b	
	call PageSlot3 ; включить страницу атрибутов 7b
	ld hl,#c000
	ld (hl),#00 ;очистка страницы атрибутов
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
	
	call LPlayGSInit ;подготовка GS	
	call gmxscron ;включить расширенный экран	
	jr loadpic_ ;запуск изображения		
	
loadpic
;1й
		call delay
loadpic_
		ld a,(cur_scr) ;смена экрана
		xor 1
		ld (cur_scr),a

		;
		;ld a,(cur_scr) ;выбор экрана
		;or a
		jr nz,select_scr5
		ld a,#18
		ld (PageSlot3Scr+1),a ;экран 7
		ld a,#79	
		call PageSlot3 ; включить страницу атрибутов 79
		jr select_scr7
select_scr5		
		ld a,#10
		ld (PageSlot3Scr+1),a ;экран 5
		ld a,#7b	
		call PageSlot3 ; включить страницу атрибутов 7b	
select_scr7

		;звук 8 секторов = 4096
		ld de,(cur_sec_de) ;адрес сектора 
		ld bc,(cur_sec_bc)	
		;call REALSEC ;узнаем реальный адрес сектора	
		ld a,4 ;8 секторов на реальном компе не успевает
		LD HL,#b800 ;адрес звука	
		CALL TO_DRV:DB 3 ;грузим несколько секторов без открытия файла

		ld bc,8
		call next_sec ;след сектор	
		
		;теперь картинка
		ld a,(type_video) ;
		cp "M"
		jr nz,attr2 ;перейти сразу на загрузку атрибутов, если формат GMV
		
		ld a,(cur_scr) ;выбор экрана
		or a
		jr nz,select_scr5p
		ld a,#18
		ld (PageSlot3Scr+1),a ;экран 7
		ld a,#39	
		call PageSlot3 ; включить страницу пикселей 39
		jr select_scr7p
select_scr5p	
		ld a,#10
		ld (PageSlot3Scr+1),a ;экран 5
		ld a,#3b	
		call PageSlot3 ; включить страницу пикселей 3b	
select_scr7p		

		;ld ixl,32/8 ;кластеров  в кадре
		LD HL,#c000 ;с начала экрана	
		ld (cur_adr),hl
loadpic1		
		ld de,(cur_sec_de) ;адрес кластера 
		ld bc,(cur_sec_bc)	
		;call REALSEC ;узнаем реальный адрес сектора	
		ld a,32 ; секторов
		LD HL,(cur_adr)		
		CALL TO_DRV:DB 3 ;грузим несколько секторов без открытия файла
		
        ;CALL COM_FAT :DB 5
		;jp nz,exit_ ;выход если файл кончился	

		ld bc,32
		call next_sec ;след сектор
		
		; ld hl,(cur_adr) ;сдвинуть адрес загрузки
		; ld bc,512*8
		; add hl,bc
		; ld (cur_adr),hl
		
		; dec ixl
		; jr nz,loadpic1
		

attr	;загрузка атрибутов

		ld a,(cur_scr) ;выбор экрана
		or a
		jr nz,select_scr5a
		ld a,#18
		ld (PageSlot3Scr+1),a ;экран 7
		ld a,#79	
		call PageSlot3 ; включить страницу атрибутов 79
		jr select_scr7a
select_scr5a		
		ld a,#10
		ld (PageSlot3Scr+1),a ;экран 5
		ld a,#7b	
		call PageSlot3 ; включить страницу атрибутов 7b	
select_scr7a	

attr2	
		;ld ixl,32/8 ;кластеров  в кадре
		LD HL,#c000 ;	
		ld (cur_adr),hl		

loadpic2		;теперь пиксели
		ld de,(cur_sec_de) ;адрес кластера 
		ld bc,(cur_sec_bc)	
		;call REALSEC ;узнаем реальный адрес сектора	
		ld a,32 ;секторов
		LD HL,(cur_adr)		
		CALL TO_DRV:DB 3 ;грузим несколько секторов без открытия файла
		
        ;CALL COM_FAT :DB 5
		;jp nz,exit_ ;выход если файл кончился	

		ld bc,32
		call next_sec ;след сектор
		; ld hl,(cur_adr) ;сдвинуть адрес загрузки
		; ld bc,512*8
		; add hl,bc
		; ld (cur_adr),hl
		
		; dec ixl
		; jr nz,loadpic2
		
		
		;прибавить текущую позицию файла
		ld bc,4096+32768 ;размер кадра #9000 для GMM
		ld a,(type_video) ;
		cp "M"
		jr z,calc_cur_pos2 ;
		ld bc,4096+16384 ;или размер кадра #5000 для GMV
calc_cur_pos2

		ld hl,(cur_file_pos_l)
		add hl,bc ;увеличить младшие разряды
		ld (cur_file_pos_l),hl
		jr nc,calc_cur_pos
		ld hl,(cur_file_pos_h) ;увеличить старшие разряды
		inc hl
		ld (cur_file_pos_h),hl		
calc_cur_pos
	
	
		;определение конец файла
		ld hl,(len_file_h) ;размер файла старшие байты
		ld bc,(cur_file_pos_h) ;текущий
		and a
		sbc hl,bc
		jr c,exit_ ;выход если файл кончился	
		jr nz,chek_skip
		ld hl,(len_file_l) ;размер файла младшие байты
		ld bc,(cur_file_pos_l) ;текущий
		and a
		sbc hl,bc		
		jr c,exit_ ;выход если файл кончился		
chek_skip
		;cur_file_pos_l
		
		
		ld hl,#b800 ;подгрузить звук
		ld de,2048/4 ;(sound_frame_size)
		call LPlayGS
		;подгрузить остаток звука	
		ld hl,(sound_frame_size)
		ld de,2048/4
		and a
		sbc hl,de
		jr c,add_sound_skip
		ex de,hl
		ld hl,#c000+16000 	;остаток после картинки
		call LPlayGS
add_sound_skip		

		XOR A
		IN A,(#FE)
		CPL
		AND #1F
		JR nz,exit_ ;выход по любой клавише

		jp loadpic;продожить
	

exit_ ;выход из плеера

		ld a,#ff ;выключить звук
		call SENDDATA
		ld a,#3a ;выключить звук
		call SENDCOM
	
		; ld a,#f3 ;горячий сброс GS
		; out (#bb),a
		
		call gmxscroff ;обычный экран
		ld a,#10
		ld (PageSlot3Scr+1),a ;экран 5
	    ld a,#00
		call PageSlot3 ;включить страницу 00	
		ret




PlayV_zx ;плеер для обычного экрана

	ld a,#7+#10	
	call PageSlot3_zx ; включить страницу
	ld hl,#c000
	ld (hl),#00 ;очистка страницы
	ld de,#c001
	ld bc,6912-1
	ldir
	
	ld a,#5+#10
	call PageSlot3_zx ; включить страницу
	ld hl,#c000
	ld (hl),#00 ;очистка страницы
	ld de,#c001
	ld bc,6912-1
	ldir
	
	call LPlayGSInit ;подготовка GS	
	jr loadpic__zx ;запуск изображения		
	
loadpic_zx
;1й
		call delay
loadpic__zx
		ld a,(cur_scr) ;смена экрана
		xor 1
		ld (cur_scr),a

		;
		;ld a,(cur_scr) ;выбор экрана
		;or a
		jr nz,select_scr5_zx
		ld a,#5+#18
		call PageSlot3_zx ; включить страницу
		jr select_scr7_zx
select_scr5_zx		
		ld a,#7+#10
		call PageSlot3_zx ; включить страницу	
select_scr7_zx

		;звук 8 секторов = 4096
		ld de,(cur_sec_de) ;адрес кластера 
		ld bc,(cur_sec_bc)	
		;call REALSEC ;узнаем реальный адрес сектора	
		ld a,4 ;8 секторов 
		LD HL,#b800 ;адрес звука	
		CALL TO_DRV:DB 3 ;грузим несколько секторов без открытия файла

		ld bc,8
		call next_sec ;след сектор	
		
		;теперь картинка

		; ld a,(cur_scr) ;выбор экрана
		; or a
		; jr nz,select_scr5p_zx
		; ld a,#5+#18
		; call PageSlot3_zx ; включить страницу
		; jr select_scr7p_zx
; select_scr5p_zx	
		; ld a,#7+#10
		; call PageSlot3_zx ; включить страницу	
; select_scr7p_zx	


		LD HL,#c000 ;с начала адреса экрана	
		ld (cur_adr),hl
	
		ld de,(cur_sec_de) ;адрес кластера 
		ld bc,(cur_sec_bc)	
		;call REALSEC ;узнаем реальный адрес сектора	
		ld a,8+6 ;14 секторов 
		LD HL,(cur_adr)		
		CALL TO_DRV:DB 3 ;грузим несколько секторов без открытия файла

		ld bc,16
		call next_sec ;след кластер
		
		; LD HL,#c000+8*512 ;
		; ld (cur_adr),hl
	
		; ld de,(cur_sec_de) ;адрес кластера 
		; ld bc,(cur_sec_bc)	
		; ;call REALSEC ;узнаем реальный адрес сектора	
		; ld a,6 ;6 секторов
		; LD HL,(cur_adr)		
		; CALL TO_DRV:DB 3 ;грузим несколько секторов без открытия файла

		; call next_sec ;след кластер
		

		;прибавить текущую позицию файла
		ld bc,4096+8192 ;размер кадра #3000 для ZXV

		ld hl,(cur_file_pos_l)
		add hl,bc ;увеличить младшие разряды
		ld (cur_file_pos_l),hl
		jr nc,calc_cur_pos_zx
		ld hl,(cur_file_pos_h) ;увеличить старшие разряды
		inc hl
		ld (cur_file_pos_h),hl		
calc_cur_pos_zx
	
	
		;определение конец файла
		ld hl,(len_file_h) ;размер файла старшие байты
		ld bc,(cur_file_pos_h) ;текущий
		and a
		sbc hl,bc
		jr c,exit_zx ;выход если файл кончился	
		jr nz,chek_skip_zx
		ld hl,(len_file_l) ;размер файла младшие байты
		ld bc,(cur_file_pos_l) ;текущий
		and a
		sbc hl,bc		
		jr c,exit_zx ;выход если файл кончился		
chek_skip_zx
		;cur_file_pos_l

		ld hl,#b800 ;подгрузить звук
		ld de,2048/4 ;(sound_frame_size)
		call LPlayGS
		;подгрузить остаток звука	
		ld hl,(sound_frame_size)
		ld de,2048/4
		and a
		sbc hl,de
		jr c,add_sound_skip_zx
		ex de,hl
		ld hl,#c000+6912 	;остаток после картинки
		call LPlayGS
add_sound_skip_zx
		
		XOR A
		IN A,(#FE)
		CPL
		AND #1F
		JR nz,exit_zx ;выход по любой клавише

		jp loadpic_zx;продожить



next_sec ;след. сектор, на входе BC=сколько секторов прибавить
		ld hl,(cur_sec_de) ;на следующий сектор младший 
		;ld bc,8
		add hl,bc
		ld (cur_sec_de),hl
		ret nc
		ld hl,(cur_sec_bc) ;на следующий сектор старший
		inc hl
		ld (cur_sec_bc),hl	
		ret
		
	
exit_zx ;выход из плеера классик

		ld a,#ff ;выключить звук
		call SENDDATA
		ld a,#3a ;выключить звук
		call SENDCOM
	
	    ld a,#00+#10
		call PageSlot3_zx ;включить страницу 00	
		ret

exit_basic ;выход в бэйсик	
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
	call print
	exx
select_dev_print	
	ld a,(hl) ;код раздела
	exx
	sub 3
	;exx
	ld hl,table_dev-10
	ld bc,10
select_dev2
	add hl,bc
	dec a
	jr nz,select_dev2
	call print
	exx
	ld bc,8 ;на следующий раздел
	add hl,bc
	dec ixl
	jr nz,select_dev_print
	
	
select_dev3	
	ei
	halt
	call scan_key
	ld 	a,(23556) ;сист. переменная нажатая клавиша 
	cp #ff
	jr z,select_dev3
	cp "0"
	jr c,select_dev3
	cp "9"+1
	jr nc,select_dev3
	sub "0"
	ret

	
scan_key ;опрос клавиатуры
; #7FFE - полуряд Space...B
; #BFFE - полуряд Enter...H
; #DFFE - полуряд P...Y
; #EFFE - полуряд 0...6
; #F7FE - полуряд 1...5
; #FBFE - полуряд Q...T
; #FDFE - полуряд A...G
; #FEFE - полуряд CS...V
	ld a,#f7
	in a,(#fe)
	bit 0,a
	jr z,key_1
	bit 1,a
	jr z,key_2
	bit 2,a
	jr z,key_3
	bit 3,a
	jr z,key_4
	bit 4,a
	jr z,key_5
	
	ld a,#ef
	in a,(#fe)
	bit 0,a
	jr z,key_0
	bit 1,a
	jr z,key_9
	bit 2,a
	jr z,key_8
	bit 3,a
	jr z,key_7
	bit 4,a
	jr z,key_6	
	
	ld a,#bf
	in a,(#fe)
	bit 0,a
	jr z,key_En

	ld a,#fb
	in a,(#fe)
	bit 3,a
	jr z,key_R
	
	ld a,#ff ;ничего не нажато
	jr scan_key_exit
	
key_1
	ld a,"1"
	jr scan_key_exit
key_2
	ld a,"2"
	jr scan_key_exit
key_3
	ld a,"3"
	jr scan_key_exit
key_4
	ld a,"4"
	jr scan_key_exit
key_5
	ld a,"5"
	jr scan_key_exit	
key_0
	ld a,"0"
	jr scan_key_exit
key_9
	ld a,"9"
	jr scan_key_exit
key_8
	ld a,"8"
	jr scan_key_exit
key_7
	ld a,"7"
	jr scan_key_exit
key_6	
	ld a,"6"
	jr scan_key_exit
key_En
	ld a,13
	jr scan_key_exit
key_R
	ld a,"R"
	jr scan_key_exit
	
	
scan_key_exit	
	ld (23556),a
	ret
	

cur_scr db 0 ;текущий экран
cur_adr dw 0 ;текущий адрес загрузки
cur_sec dw 0 ;текущий сектор FAT
cur_sec_de dw 0 ;реальный текущий сектор младшие разряды
cur_sec_bc dw 0 ;реальный текущий сектор старшие разряды
;len_clust_l dw 0 ;длина в кластерах младшие байты
;len_clust_h dw 0 ;длина в кластерах старшие байты
len_file_l dw 0 ;длина файла младшие байты
len_file_h dw 0 ;длина файла старшие байты
cur_file_pos_l dw 0 ;позиция проигрывания файла младшие байты
cur_file_pos_h dw 0 ;позиция проигрывания файла старшие байты

message_dev 
	db 22,0,0,"Select 0-"
message_dev_dig	
	db "0"
	db ":",13,0
table_dev
	db "SD ZC   ",13,0
	db "SD NeoGS",13,0
	db "HDD Nemo",13,0
	db "HDD Smuc",13,0
	
message_no_part 
	db 22,0,0,"No partition",0

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



PageSlot3_zx
; драйвер памяти классик
         ld   bc,#7ffd
         out  (c),a
         ret


delay	;цикл задержки между кадрами
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
		ret
	
	
		
;раздел звука для GS
;После загрузки эти параметры устанавливаются в определенные значения, как то: 
;Note=60, Volume=#40, FineTune=0, SeekFirst=#0F, SeekLast=#0F, Priority=#80, 
;No Loop и внутренняя переменная CurFX устанавливается равной FX_Handle.
;А вот как можно закачать сэмпл:
GSCOM EQU 187
GSDAT EQU 179
; LoadFX ;загрузка сэмпла
		; ld a,1 ; грузим по 1 сектору
		; ld de,(cur_sec) ;
		; ld bc,#0
		; LD HL,#C000 ;
        ; CALL COM_FAT :DB 5
		; jr nz,WAIT; если всё загрузили
		; ld hl,(cur_sec) ;след. сектор
		; inc hl
		; ld (cur_sec),hl	
	
	; LD HL,#c000
	; LD DE,0-512	;1 сектор загрузим в GS
	; LD C,GSCOM
	; LD A,#38
	; CALL SENDCOM
	; LD A,#D1
	; CALL SENDCOM
	; LD A,(HL)
; LOOP: IN B,(C)
	; JP P,READY
	; IN B,(C)
	; JP M,LOOP
; READY: OUT (GSDAT),A
	; INC HL
	; LD A,(HL)
	; INC E
	; JP NZ,LOOP
	; INC D
	; JP NZ,LOOP
	; jr LoadFX ;продолжить загрузу
	
; WAIT: 
	; LD C,GSCOM
	; IN B,(C) ;Ждем принятия
	; JP M,WAIT ;последнего байта
	; LD A,#D2
	; CALL SENDCOM
; ; Теперь переопределяем параметры
; ; сэмпла по умолчанию своими
; ; значениями
	; ;LD IX,Parameters
	; LD A,(note) ;(IX+#00)
	; OUT (GSDAT),A ; Нота
	; LD A,#40
	; CALL SENDCOM
	; LD A,(volume) ;(IX+#01)
	; OUT (GSDAT),A ; Громкость
	; LD A,#41
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

; PlayFX ;Проигрывание эффекта.
	; ; SD FX_Handle - номер сэмпла
	; ; SC #39
	; ; WC
	; ;ld a,1 ;номер семпла
	; call SENDDATA
	; ld a,#39
	; call SENDCOM
	; ret
	
; Parameters
	; db 45,#40 ;нота, громкость
;



;Работа со звуком GS и постоянной подгрузкой, взято из Wild Player v0.333 (by Budder/MGN)
LPlayGSInit ;инициализация, загрузка кода
;играть начинает после загрузки примерно 110 секторов по 512
;и дальше заполняет буфер 
;буфер около 512 килобайт
;чтобы после загрузки доиграл буфер, подаётся команда #FF (?)
;для скорости 11025 герц моно надо подкидывать примерно 1104 байт 10 раз в секунду
;	call LPlayGSInit1

; loop1
		; ld a,4 ; грузим по 1 сектору
		; ld de,(cur_sec) ;
		; ld bc,#0
		; LD HL,#c000 ;
        ; CALL COM_FAT :DB 5
		; jp nz,exit_; если всё загрузили
		; ld hl,(cur_sec) ;след. сектор
		; inc hl
		; inc hl
		; inc hl
		; inc hl		
		; ld (cur_sec),hl	
		; call LPlayGS
		; jr loop1
		
; LPlayGSInit1
	
	;подготовка
	;ld bc,#00bb
	;ld a,#f4 ;холодный сброс GS, иначе глючит после детекта устройств
	;call LPOutBB
	ld a,#f3 ;горячий сброс GS
	call LPOutBB
	;out (c),a
	in a,(#b3) ;определение наличия ?
	ld b,#00
	ld c,a
La820
	in a,(#b3)
	cp c
	jr nz,La85f ;нэт?
	djnz La820
	
	ld a,#23 ;сколько страниц
	out (#bb),a
	ld bc,#200 ;определение наличия ?
La82e
	dec bc
	ld a,b
	or c
	jr z,La85f ;нэту ?
	in a,(#bb)
	rrca
	jr c,La82e
	in a,(#b3)
	cp #03 ;сколько страниц памяти?
	jr c,La85f ;меньше чем надо
	ld a,#01
	out (#b3),a
	ld a,#6a ;
	call LPOutBB
	xor a
	out (#b3),a
	ld a,#6b ;
	call LPOutBB
La85f
	ld a,#f3 ;горячий сброс GS
	call LPOutBB
	in a,(#7b) ;?

;0102, 7e23 - 22050 stereo
;0102, 0000 - 11025 stereo	
;0403, 7e23 - 22050 mono
;0403, 0000 - 11025 mono
	ld de,(sound_value1) ;0403 или 0102
	ld hl,(sound_value2) ;7e23 или 0000
	ld (GS_Code+3),de ;переменные 
	ld (GS_Code+5),hl
	ld a,#f3 ;горячий сброс GS
	call LPOutBB
	ld a,#00
	out (#b3),a
	ld a,#14 ;команда загрузка кода
	call LPOutBB
	ld a,#02 ;размер
	call LPOutB3
	ld a,#00
	call LPOutB3	
	ld a,#40 ;адрес?
	call LPOutB3
	ld hl,GS_Code ;адрес кода
	ld bc,#200 ;размер
LPlayGSI00	
	push bc
	ld a,(hl)
	call LPOutB3	;грузим
	inc hl
	pop bc
	dec bc
	ld a,b
	or c
	jr nz,LPlayGSI00
	xor a
	out (#b3),a
	ld a,#13 ;код запуска кода
	call LPOutBB
	ld a,#40
	call LPOutB3
	xor a
	out (#bb),a
	in a,(#b3)
	ret
	
	
LPlayGS ;подгрузка данных кусками
	;ld bc,#01 ;цикл
	;ld hl,#c000 ;адрес звука
	ld bc,#00bb 
	;ld de,2048/4 ;#02 длина кратна 4. В оригинале грузилось кусками по 2048
L6408
	in a,(c)
	jp p,L6412
	in a,(c)
	jp m,L6408
L6412
	ld a,(hl)
	out (#b3),a
	; and 7
	; out (254),a
	inc l
L6416
	in a,(c)
	jp p,L6420
	in a,(c)
	jp m,L6416
L6420
	ld a,(hl)
	out (#b3),a
	; and 7
	; out (254),a
	inc hl
L6424	
	in a,(c)
	jp p,L642E
	in a,(c)
	jp m,L6424
L642E	
	ld a,(hl)
	out (#b3),a
	; and 7
	; out (254),a
	inc hl
L6432
	in a,(c)
	jp p,L643C
	in a,(c)
	jp m,L6432
L643C	
	ld a,(hl)
	out (#b3),a
	; and 7
	; out (254),a
	inc hl
	;djnz L6408	
	dec de
	ld a,e
	or d
	jr nz,L6408
	ret
	
	
LPOutBB ;вывод в порт BB
	nop
	out (#bb),a
LPOutBB1
	in a,(#bb)
	rrca
	jr c,LPOutBB1
	ret
	
LPOutB3 ;вывод в порт B3
	nop
	out (#b3),a
LPOutB31
	in a,(#bb)
	rlca
	jr c,LPOutB31
	ret

GS_Code ;код для загрузки в GS
	incbin "GS_Code.C"









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






;Раздел оболочки
shell
	ld a,"R" ;выберем правую панель
	ld (panel),a
	xor a
	ld (curfile),a ;выберем первый файл
	ld (curfile_r),a ;выберем первый файл
	ld (shiftcat),a ;в начало каталога
	ld (shiftcat_r),a ;в начало каталога
	; ld (files_r),a	;всего
shell_warm ;тёплый старт
	call cls_pic
	ld hl,mes_title
	call print

	call   printcat_r


wait ;ожидание клавиши
		call input_key
			
;waitPass
			ld      a,c ;вспомним клавишу
            ; cp 		"E"
            ; jp      z,exit
            cp 		6 ;#36-" "
            jp      z,down
            cp 		7 ;#37-" "
            jp      z,up
            ; cp 		"T" ;#0d
            ; jp      z,TRD ;view ;enter
            cp 		"R"
            jp      z,start ;обновить всё
            ; cp 		"1"
            ; jp      z,driveA ;1
            ; cp 		"A"
            ; jp      z,driveA ;A			
            ; cp 		"2"
            ; jp      z,driveB ;2
            ; cp 		"B"
            ; jp      z,driveB ;B
            ; cp 		"3"
            ; jp      z,driveC ;3
            ; cp 		"C"
            ; jp      z,driveC ;C
            ; cp 		"4"
            ; jp      z,driveD ;4
            ; cp 		"D"
            ; jp      z,driveD ;D
            ; cp 		#0e ;-" " ;CS+SS
            ; jp      z,change_panel ;S
            cp 		5 ;#35-" "
            jp      z,left
            cp 		8 ;#38-" "
            jp      z,right
            ; cp 		"I" 
            ; jp      z,ShowInfo ;I
			; cp 		"S"
            ; jp      z,check_sum_tog ;S
            cp 		13 ;Enter
            jp      z,Enter_			
            jp      wait
			

input_key ;на выходе в c - код клавиши
            halt
			call scan_key
		
			ld      a,(keyLast) ;предыдущая нажатая клавиша
			ld		b,a
			ld 		a,(23556) ;сист. переменная нажатая клавиша 
			;ld 		c,a	
			call 	input_key_curs
			ld 		a,e
			ld 		c,a
			;ld      (23556),a
			ld 		(keyLast),a ;запомним клавишу
			cp		#ff ;если сейчас ничего не нажато
			jr		nz,wait1
			xor		a
			ld		(keyDelayF),a ;обнулим флаг задержки
			jr      input_key ;и снова на ожидание
wait1
			ld		a,c
			cp		b
			ret		nz ;если нажата первый раз, пропустим задержку

			ld 		a,(keyDelayF)
			or		a
			ret		nz ;если всё ещё нажата и была пауза, пропустим
			
;waitDelay		
			ld      a,(keyRepeat) ;пауза
			ld b,a
waitDelay
            halt
			call scan_key
			ld 		a,(23556) ;сист. переменная нажатая клавиша
			call 	input_key_curs
			ld 		a,e
			;ld      (23556),a
			ld 		(keyLast),a ;запомним клавишу
			cp		#ff ;если сейчас ничего не нажато
			jr		nz,waitDelay1
			xor		a
			ld		(keyDelayF),a ;обнулим флаг задержки
			jr      input_key ;и снова на ожидание	
waitDelay1
			djnz waitDelay
			ld		a,1
			ld		(keyDelayF),a ;установить флаг была пауза
			jr      input_key ;и снова на ожидание	

input_key_curs ;перехват курсора
			ld e,a
			ld a,#fe 
			in a,(#fe)
			bit 0,a ;Caps 
			ret nz
			ld a,#f7 
			in a,(#fe)
			bit 4,a 
			jr nz,input_key_curs_1	
			ld e,5 ;left
			ret
input_key_curs_1				
			ld a,#ef 
			in a,(#fe)
			bit 4,a 
			jr nz,input_key_curs_2	
			ld e,6 ;down
			ret
input_key_curs_2				
			bit 3,a 
			jr nz,input_key_curs_3	
			ld e,7 ;up
			ret
input_key_curs_3				
			bit 2,a 
			jr nz,input_key_curs_4	
			ld e,8 ;right
			ret
input_key_curs_4				
			bit 0,a 
			ret nz	
			ld e,0 ;Back Space
			ret			
			
			
input_key_curs_e
			ld a,c
			ret

	
wait_cont ;обновить переменные и продолжить
	ld a,(panel)
	cp "L"
	jr nz,wait_cont_r
	ld     a,(shiftcat)
	ld     (shiftcat_l),a
	ld     a,(curfile)
	ld     (curfile_l),a
	call   printcat
    jp     wait
wait_cont_r
	ld     a,(shiftcat)
	ld     (shiftcat_r),a
	ld     a,(curfile)
	ld     (curfile_r),a
	call   printcat
    jp     wait	
			

down ; вниз по каталогу
            ld     a,(files)
            ld     c,a
			ld     a,(shiftcat)
			ld     b,a 		
            ld     a,(curfile)
            inc    a
            cp     c
            jp     nc,wait ;выход если дошли до конца
            ld     (curfile),a
			sub b
        ;    ld     a,(cursor)
            cp     files_view ;не пора ли сдвинуться вниз всему каталогу
            jr     c,downE
            inc b
            ld   a,b
            ld     (shiftcat),a
downE
            jp     wait_cont



up ; ; вверх по каталогу

            ld     a,(curfile)
            or     a
            jp     z,wait
            dec    a
            ld     (curfile),a
			ld     c,a
            ld     a,(shiftcat)
			ld b,a
			ld a,c
			sub b
			cp files_view
			jr c,upE
			dec b
			ld a,b
            ld     (shiftcat),a
upE
            jp     wait_cont
	


left ; на страницу вверх

            ld     a,(curfile)
            or     a
            jp     z,wait
            sub    files_view-1
            jr     nc,left02
            xor    a
left02
            ld     (curfile),a
            ld     c,a
			;проверка сдвига
			ld     a,(shiftcat)
			ld b,a
			ld     a,c
			sub b
			;cp files_view
			jr nc,leftE ;листать не надо
			
			ld a,b
			sub files_view-1
			jr nc,left03
			xor a
left03
            ld     (shiftcat),a
leftE			
            jp     wait_cont




right; на страницу вниз
            ld     a,(files) ;всего
			or     a
            jp     z,wait
            ld     c,a
            ld     a,(curfile) ;текущий
            add    a,files_view-1 ;листаем вперёд
            cp     c
            jr     c,right01 ;если не дошли до конца
            ld     a,(files) ;иначе на последний файл
            dec    a
right01
            ld     (curfile),a

			;проверка сдвига, листать каталог или нет
			ld     a,(files)
			ld c,a
			cp files_view+1
			jr c,rightE ;выход если файлов меньше 25
            ld     a,(shiftcat)
			ld b,a
			ld     a,(curfile) ;текущий
			sub b
			cp files_view
			jr c,rightE ;если не пора пролистать на страницу
			ld a,files_view-1
			add b
			cp c ;если больше чем всего файлов
			jr c,right04
			ld a,c
			sub files_view ;тогда максимум файлов - 24
			jr right05
right04
			ld b,a ;и если до последнего файла не меньше 24х
			ld a,c
			sub b
			cp files_view
			ld a,b
			jr nc,right05
			ld a,c
			sub files_view ;тогда максимум файлов - 24

right05
            ld     (shiftcat),a ;новое смещение от начала каталога
rightE
            jp     wait_cont
		
		
cls_pic
			ld hl,#4000
			ld de,#4001
			ld bc,6144
			ld (hl),0
			ldir
			ld (hl),col_fon
			ld bc,768-1	
			ldir
			ret
			
Enter_ ;Проверка надо ли открыть папку или запустить файл

            ld     a,(files)
            or     a      ;no files?
            jp     z,wait

			ld 		a,(curfile)
			ld 		bc,cat
			ld      l,a
			ld 		h,0
            add    hl,hl ;2
			add    hl,hl ;4
			add    hl,hl ;8
			add    hl,hl ;16
			add hl,bc	
			push hl ;запомним указатель на имя файла в каталоге
			pop ix
		ld de,file_name_v ;скопируем имя для поиска
		ld bc,11
		ldir			
		
		call find_file
		
		jp z,wait
		
		CALL COM_FAT :DB Getfzap
        BIT 4,A
;ЗАПРОС ОПИСАТЕЛЯ ТЕКУЩЕЙ ПОЗИЦИИ
;НА ВЫХОДЕ:
;Z=1 ЭТО DIR
;Z=0 ЭТО ФАЙЛ

		jr z,PlayV_ ;это файл
		
		CALL COM_FAT :DB Ent_dir ;войти в каталог
		
		call fill_cat ; заполнить каталог

	
		jp shell
		
		
PlayV_ ;проиграть файл		
		push ix
		pop hl
			;проверим расширение файла
			ld bc,8
			add hl,bc
			ld de,file_name_ext_GMV
		ld b,3 ;сравнение
compare_
		ld a,(de)
		cp (hl)
		jp nz,wait_GMM ;не равно
		inc de
		inc hl
		djnz compare_
		;нашли GMV
		ld (type_video),a ;сохраним тип видео
		ld a,delay_GMV
		ld (delay_v),a ;зададим сколько фреймов на кадр
		ld hl,sound_frame_size_GMV
		ld (sound_frame_size),hl ;размер кадра звука
		ld hl,#0102 ; 22050 герц моно
		ld (sound_value1),hl
		ld hl,#0000 ;#7e23
		ld (sound_value2),hl		
		jr wait_play
		
wait_GMM ;проверим другое расширение
		push ix
		pop hl
		ld bc,8
		add hl,bc
		ld de,file_name_ext_GMM
		ld b,3 ;сравнение
compare2_
		ld a,(de)
		cp (hl)
		jp nz,wait_ZXV ;не равно
		inc de
		inc hl
		djnz compare2_
		;нашли GMM
		ld (type_video),a ;сохраним тип видео
		ld a,delay_GMM
		ld (delay_v),a ;зададим сколько фреймов на кадр
		ld hl,sound_frame_size_GMM
		ld (sound_frame_size),hl ;размер кадра звука
		ld hl,#0403 ; 11025 герц моно
		ld (sound_value1),hl
		ld hl,#0000
		ld (sound_value2),hl
		jr wait_play


wait_ZXV ;проверим другое расширение
		push ix
		pop hl
		ld bc,8
		add hl,bc
		ld de,file_name_ext_ZXV
		ld b,3 ;сравнение
compare3_
		ld a,(de)
		cp (hl)
		jp nz,wait ;вернуться в цикл ожидания
		inc de
		inc hl
		djnz compare3_
		;нашли ZXV
		ld a,"Z"
		ld (type_video),a ;сохраним тип видео
		ld a,delay_ZXV
		ld (delay_v),a ;зададим сколько фреймов на кадр
		ld hl,sound_frame_size_ZXV
		ld (sound_frame_size),hl ;размер кадра звука
		ld hl,#0102 ; 22050 герц моно
		ld (sound_value1),hl
		ld hl,#0000
		ld (sound_value2),hl


wait_play

		call PlayV ;запустить плеер
		jp shell_warm


	
printcat ;печать активного каталога
	; ld a,(panel)
	; cp "L"
	; jp z,printcat_l
	;jp printcat_r

printcat_r ;печать каталога правая панель
			ld a,(panel) ;проверка надо ли скрыть курсор
			cp "R"
			ld a,colorcatc_act	
			jr z,printcat_r1
			ld a,colorcat_		
printcat_r1
			ld (colorcatc_r),a
	
            ld      hl,col_pos_r ;
            xor		a
clscat_r
            ld      d,h
            ld      e,l
            inc     de
            ld      c,a  ;keep
            ld      a,(shiftcat_r)
            ld      b,a
            ld      a,(curfile_r)
            and     a
            sbc     a,b
            cp      c
            ld      (cursor_r),a ;posit
            ld      a,(colorcat_r)
            jr      nz,clscat01_r
            ld      a,(colorcatc_r) ;mark
clscat01_r
            ld      (hl),a  ;раскраска атрибутами
            ld      a,c  ;restor
            ld      bc,9
            ldir
            ld      bc,32-9
            add     hl,bc
            inc     a
            cp      files_view
            jr      c,clscat_r

       ;     ld      hl,catposit
       ;     call    print
	   
			ld a,(files_r)
			or a
			ret z ;выход если нет файлов
			
            ld      bc,cat  ;теперь печать имён файлов
            ld      a,(shiftcat_r)
            ; or      a
            ; jr      z,printcat00
			ld      l,a
			ld 		h,0
;printcat01  ;find name file
            add    hl,hl ;2
			add    hl,hl ;4
			add    hl,hl ;8
			add    hl,hl ;16
			add hl,bc
            ;dec    a
            ;jr    nz,printcat01
;printcat00

            xor     a
printcat02_r
            push    af
            push    hl
                       ;print 24 row

            ld      (catposit_r+1),a
            ld      hl,catposit_r ;установим позицию печати
            call    print
            pop     hl
            push    hl
			;call 	formatName ;подготовим
			ld bc,12 ;длина
            call    print_ ;печать одного имени файла
            ;ld      hl,catspace
            ;call    print
            pop     hl
            ld      bc,lenghtName ;на след. имя
            add     hl,bc
            pop     af
            inc     a
			ld 		bc,(files_r) ;проверка сколько всего файлов
			cp 		c
			ret		nc
            cp      files_view
            jr      c,printcat02_r
			ret
	

;печать до символа 0
;hl - text address
;13-enter
;16-color(атрибуты 128+64+pap*8+ink)
;20-inverse
;21-отступ от левого края
;22-at
print_  ;var 2: print text lenght in bc
        ld      a,(hl)
        call    prsym
        inc     hl
        dec     bc
        ld      a,b
        or      c
        jr      nz,print_
        ret
aupr    pop     hl
        call    print
        push    hl
        ret
;start print to 0
print   ld      a,(hl)
        inc     hl
        or      a
        ret     z
        cp      23
        jr      c,prin
        call    prsym
        jr      print
prin
        cp      13
        jr      nz,prin0
        ld      a,(space)
        ld      (xtxt),a
        ld      a,(ytxt)
        inc     a
        cp      23
        jr      c,pr13_0
        xor     a
pr13_0  ld      (ytxt),a
        jr      print
prin0   cp      16
        jr      nz,prin1
        ld      a,(hl)
        inc     hl
        ld      (23695),a
        jr      print
prin1   cp      20
        jr      nz,prin2
        ld      a,(hl)
        inc     hl
        or      a
        jr      z,pr20_0
        ld      a,#2f
        ld      (pr0),a
        ld      (pr1),a
        ld      (pr2),a
        ld      (pr3),a
        jr      print
pr20_0  ld      (pr0),a
        ld      (pr1),a
        ld      (pr2),a
        ld      (pr3),a
        jr      print
prin2   cp      22
        jr      nz,prin3
        ld      a,(hl)
        ld      (ytxt),a
        inc     hl
        ld      a,(hl)
        ld      (xtxt),a
        inc     hl
        jr      print
prin3   cp      21
        jr      nz,print
        ld      a,(hl)
        inc     hl
        ld      (space),a
        jr      print
prsym
        push    af
        push    bc
        push    de
        push    hl
        push    ix
        ld      de,(ytxt)
        inc     d
        ld      (ytxt),de
        dec     d
        ex      af,af'
        ld      a,d
        cp      41
        jr      c,prs
        ld      a,e
        inc     a
        cp      24
        jr      c,prs1
        xor     a
prs1    ld      (ytxt),a
        ld      a,(space)
        ld      (xtxt),a
prs     ex      af,af'
        ld      l,a
        ld      h,#00
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      bc,font
        add     hl,bc
        push    hl
        ld      a,d
        add     a,a
        ld      d,a
        add     a,a
        add     a,d
        add     a,#02
        ld      d,a
        and     #07
        ex      af,af'
        ld      a,d
        rrca
        rrca
        rrca
        and     #1F
        ld      d,a
        ld      a,e
        and     #18
        add     a,#40
        ld      h,a
        ld      a,e
        and     #07
        rrca
        rrca
        rrca
        add     a,d
        ld      l,a
        ld      (posit),hl
        pop     de
        ld      b,#08
        ex      af,af'
        jr      z,L73C7
        ld      xh,b
        cp      #02
        jr      z,L73D6
        cp      #04
        jr      z,L73E9
L73A7   ld      a,(hl)
        rrca
        rrca
        ld      b,a
        inc     hl
        ld      a,(hl)
        and     #0F
        ld      c,a
        ld      a,(de)
pr0     nop
        and     #FC
        sla     a
        rl      b
        sla     a
        rl      b
        or      c
        ld      (hl),a
        dec     hl
        ld      (hl),b
        inc     h
        inc     de
        dec     xh
        jr      nz,L73A7
        jr      prsc1
L73C7   ld      a,(hl)
        and     #03
        ld      c,a
        ld      a,(de)
pr1     nop
        and     #FC
        or      c
        ld      (hl),a
        inc     h
        inc     de
        djnz    L73C7
        jr      prsc
L73D6   ld      a,(hl)
        and     #C0
        ld      b,a
        ld      a,(de)
pr2     nop
        and     #FC
        rrca
        rrca
        or      b
        ld      (hl),a
        inc     h
        inc     de
        dec     xh
        jr      nz,L73D6
        jr      prsc
L73E9   ld      a,(hl)
        rrca
        rrca
        rrca
        rrca
        ld      b,a
        inc     hl
        ld      a,(hl)
        and     #3F
        ld      c,a
        ld      a,(de)
pr3     nop
        and     #FC
        sla     a
        rl      b
        sla     a
        rl      b
        sla     a
        rl      b
        sla     a
        rl      b
        or      c
        ld      (hl),a
        dec     hl
        ld      (hl),b
        inc     h
        inc     de
        dec     xh
        jr      nz,L73E9
        jr      prsc1
prsc    ld      hl,(posit)
        ld      a,h
        and     #18
        rrca
        rrca
        rrca
        add     a,#58+#80
        ld      h,a
        ld      a,(23695)
        ld      (hl),a
        jr      prse
prsc1   ld      hl,(posit)
        ld      a,h
        and     #18
        rrca
        rrca
        rrca
        add     a,#58+#80
        ld      h,a
        ld      a,(23695)
        ld      (hl),a
        inc     hl
        ld      (hl),a
prse    pop     ix
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret
posit   dw      0
space   nop
ytxt    nop
xtxt    nop



cat equ #c000 ;буфер каталога диска 
col_fon equ 7 ;цвет фона

file_name_len equ 12 ;длина имени файла
lenghtName equ 16 ;длина имени файла в каталоге

files_view equ 24 ;показывать файлов в каталоге
col_pos_l equ #5800 ;позиция для покраски левая панель
col_pos_r equ #5800+31-9 ;позиция для покраски правая панель
colorcatc_act equ 7*8+1 ;цвет выбранного файла активной панели
colorcat_ equ     1*8+7; фон панели файлов

colorcatc_l db colorcatc_act ;цвет выбранного файла слева
colorcat_l db  colorcat_; цвет окна каталога слева
colorcatc_r db colorcatc_act ;цвет выбранного файла справа
colorcat_r db  colorcat_; цвет окна каталога	справа
cursor_l   db     0; строка курсора слева
cursor_r   db     0; строка курсора справа
cur_drive db 0 ; дисковод
shiftcat db 0;сдвиг по каталогу
shiftcat_r db 0;сдвиг по каталогу правая панель
shiftcat_l db 0;сдвиг по каталогу левая панель
keyRepeat db 20 ;пауза перед повтором нажатия клавиши
keyLast db 255; последняя нажатая клавиша
keyDelayF db 0 ;флаг что уже была пауза нажатия
files db 0 ;всего файлов
curfile db 0 ; текущий файл
files_r db 0 ;всего файлов правая панель
curfile_r db 0 ; текущий файл правая панель
files_l db 0 ;всего файлов левая панель
curfile_l db 0 ; текущий файл левая панель

panel db 0; текущая панель
catFName  ds		13 ;имя файла для каталога
		 db		0 ;маркер конца имени
catposit_r ;позиция печати каталога справа
	db 22,0,30,0
mes_title
	db 22,0,13,"VPlayer v0.1.5"
	db 22,2,13,"Arrow keys"
	db 22,3,13,"R - rescan"
	db 22,4,13,"Enter - play"
	db 22,5,13,"Any key - stop"
	db 0

delay_v db 0 ;
delay_GMV equ 5 ;прерываний (фреймов) на кадр GMV
delay_GMM equ 10 ;прерываний (фреймов) на кадр GMM
delay_ZXV equ 5 ;прерываний (фреймов) на кадр ZXV
file_name_v db "VIDEO   GMM",0,0,0,0,0 ;имя файла видео
file_name_ext_GMM db "GMM" ;расширение
file_name_ext_GMV db "GMV" ;расширение
file_name_ext_ZXV db "ZXV" ;расширение
sound_frame_size_GMV equ (1124*2)/4 ;размер звука на один кадр GMV (по рассчётам 1104)
sound_frame_size_GMM equ (1124*2)/4 ;размер звука на один кадр GMM
sound_frame_size_ZXV equ (1124*2)/4 ;размер звука на один кадр GMM
type_video db 0 ;тип видео
sound_frame_size dw 0 ;длина кадра звука в байтах
sound_value1 dw 0 ;выбор качества звука
sound_value2 dw 0 ;выбор качества звука



		align 256
font    insert  "FONT.C" ;шрифт
		align 256
interrupt_vec equ $-1 ;указатель на обработчик прерываний

	
end_
	SAVETRD "DISK.TRD",|"VIDEO.C",start_,end_-start_