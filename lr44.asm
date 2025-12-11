; Часы на семисегментных индикаторах
TStart equ 1000    ; Значение периода счетчика для динамической индикации
NCount equ 6       ; Количество выводимых цифр (мм:сс)
RG2 equ 0A000h     ; адрес регистра RG2 (позиция)
RG3 equ 0B000h     ; адрес регистра RG3 (значение)

; Константы для точного времени
; Предполагаем частоту кварца 12 МГц
; 1 машинный цикл = 12 тактов кварца = 1 мкс
; Для 50 мс нужно: 50000 циклов
TICKS_50MS equ 50000
T1_RELOAD equ 65536 - TICKS_50MS

dseg at 30h
DigitDivision: ds NCount ; массив цифр для вывода на индикаторы
Position: ds 1           ; байт текущей маски позиции
Seconds: ds 1            ; секунды (0-59)
Minutes: ds 1            ; минуты (0-59)
TickCounter: ds 1        ; счетчик тиков для подсчета 1 секунды

cseg
jmp START

; Прерывание от Timer0 - динамическая индикация
org 0Bh
call TIMER_DISPLAY
reti

; Прерывание от Timer1 - отсчет времени
org 1Bh
call TIMER_CLOCK
reti

org 30h
START:
; Начальная инициализация времени
mov Minutes, #0          ; минуты
mov Seconds, #0          ; секунды
mov TickCounter, #0

; Формируем начальный массив для вывода (00:00)
call UPDATE_DISPLAY_ARRAY

; Инициализация позиции индикации
mov r0, #0                    ; индекс текущей позиции
mov Position, #10111111b      ; крайнее левое положение

; Настройка Timer0 для динамической индикации
mov TMOD, #00010001b ; Timer0 и Timer1 в режиме 1 (16-битный)

; Настройка Timer0 (динамическая индикация)
mov TH0, #high(65535-TStart)
mov TL0, #low(65535-TStart)

; Настройка Timer1 для точного отсчета 50 мс
mov TH1, #high(T1_RELOAD)
mov TL1, #low(T1_RELOAD)

; Разрешение прерываний
mov IE, #10001010b ; EA=1, ET1=1, ET0=1

; Запуск таймеров
setb TR0  ; запуск Timer0
setb TR1  ; запуск Timer1

; Основной цикл (бесконечный)
MAIN_LOOP:
jmp MAIN_LOOP

; Прерывание Timer0 - вывод на индикаторы (динамическая индикация)
TIMER_DISPLAY:
push acc
push dpl
push dph

; Перезагрузка Timer0
mov TH0, #high(65535-TStart)
mov TL0, #low(65535-TStart)

; Погасить все индикаторы
mov dptr, #RG3
mov a, #0
movx @dptr, a

; Выбрать текущий разряд
mov dptr, #RG2
mov a, Position
movx @dptr, a

; Получить значение для текущего разряда
mov a, #DigitDivision
add a, r0
mov r1, a
mov a, @r1

; Если это позиция двоеточия (позиция 2), выводим двоеточие
cjne r0, #2, DISPLAY_DIGIT
mov a, #01000000b  ; двоеточие (сегмент g включен)
sjmp OUTPUT_TO_DISPLAY

DISPLAY_DIGIT:
; Проверка на пустой разряд (значение 10)
cjne a, #10, CONVERT_DIGIT
mov a, #0  ; пустой разряд
sjmp OUTPUT_TO_DISPLAY

CONVERT_DIGIT:
; Преобразовать цифру в код для индикатора
mov dptr, #DigitTable
movc a, @a+dptr

OUTPUT_TO_DISPLAY:
; Зажечь индикатор
mov dptr, #RG3
movx @dptr, a

; Переход к следующему разряду
mov a, Position
rr a
mov Position, a
inc r0
cjne r0, #NCount, END_TIMER_DISPLAY

; Вернуться к первому разряду
mov r0, #0
mov Position, #10111111b

END_TIMER_DISPLAY:
pop dph
pop dpl
pop acc
ret

; Прерывание Timer1 - отсчет времени (точные 50 мс)
TIMER_CLOCK:
push acc
push psw

; Перезагрузка Timer1 с ТОЧНЫМ значением
mov TH1, #high(T1_RELOAD)
mov TL1, #low(T1_RELOAD)

; Подсчет до 1 секунды (20 тиков по 50 мс = 1000 мс)
inc TickCounter
mov a, TickCounter
cjne a, #20, END_TIMER_CLOCK
mov TickCounter, #0

; Прошла 1 секунда - увеличиваем время
inc Seconds
mov a, Seconds
cjne a, #60, UPDATE_TIME ; если секунды < 60

; Переполнение секунд (60 секунд)
mov Seconds, #0
inc Minutes
mov a, Minutes
cjne a, #60, UPDATE_TIME ; если минуты < 60

; Переполнение минут (60 минут)
mov Minutes, #0

UPDATE_TIME:
; Обновляем массив для вывода
call UPDATE_DISPLAY_ARRAY

END_TIMER_CLOCK:
pop psw
pop acc
ret

; Обновление массива DigitDivision для вывода времени
; Формат: MM:SS
UPDATE_DISPLAY_ARRAY:
push acc
push b
push psw

; Преобразуем минуты в BCD
mov a, Minutes
mov b, #10
div ab          ; A = десятки минут, B = единицы минут
mov DigitDivision+0, a  ; десятки минут
mov DigitDivision+1, b  ; единицы минут

; Позиция для двоеточия
mov DigitDivision+2, #10 ; специальный код для двоеточия

; Преобразуем секунды в BCD
mov a, Seconds
mov b, #10
div ab          ; A = десятки секунд, B = единицы секунд
mov DigitDivision+3, a  ; десятки секунд
mov DigitDivision+4, b  ; единицы секунд

; Пустой разряд
mov DigitDivision+5, #10

pop psw
pop b
pop acc
ret

; Таблица символов для семисегментного индикатора
DigitTable: 
db 00111111b  ; 0
db 00000110b  ; 1
db 01011011b  ; 2
db 01001111b  ; 3
db 01100110b  ; 4
db 01101101b  ; 5
db 01111101b  ; 6
db 00000111b  ; 7
db 01111111b  ; 8
db 01101111b  ; 9
db 00000000b  ; 10 - пусто

end