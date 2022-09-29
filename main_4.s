
.include "macros.s"

    .arch armv8-a

    .data
    .align 2

arg_error: // метка
    .asciz "No first argument\n" // asciz - .string ”строка” – набор символов, заканчивающийся нулевым байтом

file_error:
    .asciz "Error opening file\n"

prescision_error:
    .asciz "Incorrect prescision\n"

x_too_big_error:
    .asciz "x is too big\n"

fopen_w_mode:
    .asciz "w"

s_x:
    .asciz "x: "
s_prescision:
    .asciz "prescision: "

scan_float:
    .asciz "%f"
scan_int:
    .asciz "%d"

s_sqrt:
    .asciz "sqrt(1 + x) = %.17lf\n"

s_series:
    .asciz "series = %.7f\n"

s_index_value:
    .asciz "%d: %.7f\n"

    .text
    .align 2

    .global main
    .type main, %function
main:
    stp x29, x30, [sp, -32]! // для работы со стеком. 2 регистра - 29 и 30 сохраняются в стек и стек и вершина сдвигается на -32, ! для сохранение (надо сохранить)
    mov x29, sp // Копирование второго операнда ( (Указатель стека), стек верхние регистры для сохранения верхнего адреса стека;) в первый
    // x0 = argc
    // x1 = argv

    cmp x0, #1 // сравнение первого регистра с 1, если нет - в 57 строку
    bne 1f // если 1 - прыгаем в 1: на 60 строке (пропускаем ошибку)
    // no first argument
    adr x0, arg_error
    bl printf
    b exit
1:

    add x1, x1, #8 // skip 1st arg // прибавляем к x1 - 8 и сохраняем в x1
    ldr x2, [x1]   // char* filename, загрузка в регистр по адресу x1 // данные из x1 загружаем в x2.

    mov x0, x2 // Копируем x2 в x0
    adr x1, fopen_w_mode // загружаем в х1 адрес fopen_w_mode
    bl fopen

    mov x28, x0 // копируем x0 в x28
    cmp x0, xzr // сравниваем х0 с нулём. Если x0 != 0, то bne 1f прыгает в 1:. Если x0 = 0, выполняем код внутри
    bne 1f
    adr x0, file_error
    bl printf
    b exit
1:

    adr x0, s_x // записываем "x: " в регистр x0
    bl printf  // выводим из x0 в файл
    adr x0, scan_float // загружаем в x0 %f
    add x1, x29, 24 //к указателю на стековый кадр прибавляем 24 байта и записываем в x1
    bl scanf // scanf(scan_float, временный адрес на стеке)

    // s8 = x
    ldr s8, [x29, 24] // загрузжаем из памяти по адресу, куда scanf записал результат, и записываем в s8

    adr x0, s_prescision
    bl printf
    adr x0, scan_int
    add x1, x29, 24 //к указателю на стековый кадр прибавляем 24 байта и записываем в x1
    bl scanf

    // x21 = prescision
    ldr x19, [x29, 24] // загрузжаем из памяти по адресу, куда scanf записал результат, и записываем в x19
    mov x21, x19

    // проверяем |x| < 1
    fmov s0, s8 // пересылка из s8 в s0
    fabs s1, s0 // модуль числа s0 в s1
    fmov s2, 1 // пересылка 1 в s2
    fcmp s1, s2 // сравниваем s1 и s2, если s1 > s2 - выходим с ошибкой (102)
    ble 1f // если нет - прыгаем в 1: ниже
    adr x0, x_too_big_error
    bl printf
    b exit
1:


 // проверяем, что 0 <= точность <= 17
    cmp x21, xzr // сравниваем 21 регистр с 0
    blt 1f // branches to 1forward если x21 < 0.
    cmp x21, 17 // сравниваем регистр 21 с 17
    bgt 1f // если x21 > 17 - прыгаем в 1 и выводим ошибку точности.
    b 2f // если нет - прыгаем в 2.
1:
    adr x0, prescision_error
    bl printf
    b exit
2:

    fmov s1, 1
    fadd s0, s1, s8 // s0 = s1+s8, не add потому что плавающая точка
    fcvt d0, s0 // преобразование формата плавающей точки
    bl sqrt // x0 = sqrt

    // printf("sqrt x = %.17lf\n", acos(x))
    adr x0, s_sqrt
    // d0 = sqrt(1+x)
    bl printf

    // считаем 0.1 в степени prescision
    mov x0, x19 // копируем х19 в x0
    fmov s1, 1 // 1 в s1
    fmov s10, 10 // 10 в s10
prescision_loop:
    fdiv s1, s1, s10 // s1 = s1 / s10
    sub x0, x0, #1 // x0 = x0-1
    cbnz x0, prescision_loop // сравниваем 0 и переходим обратно, если x0 != 0

    fmov s15, s1 // prescision -> перебрасываем из s1 в s15.

interesting: // метка для отладки
    // инициализация
    mov x20, 0 // n , 0 в x20
    mov x21, 1 // 1 - 2n, 1 в 21
    // s8 = x
    fmov s9, 1 // s9 = (-1)^n * x^n // f с плавающей точкой.
    fmov s10, wzr // sum // s10 = 0.0
    // fmov s11, 1 // n!
    // fmov s12, 1 // (2n)!
    // fmov s13, 1 // 4^n

 // считаем ряд
loop:
// считаем очередной член ряда и прибавляем к сумме
    scvtf s0, x21 // преобразование целого числа со знаком в вещественное, округление в соответствии со значением FPCR
    fdiv s0, s9, s0   // /= (1 - 2n) // s0= s9/s0
    // fmul s0, s0, s12  // *= (2n)!
    // fdiv s0, s0, s13  // /= 4^n
    // fmul s1, s11, s11 //  = (n!)^2
    // fdiv s0, s0, s1   // /= (n!)^2

    fadd s10, s10, s0 // s10 = s10+s0

    fmov s14, s0 // s0 = s14

    mov x0, x28 // x28 = x0
    adr x1, s_index_value // загружаем "%d: %.7f\n" в x1
    mov x2, x20 // x20 в x2
    fcvt d0, s0 // преобразование формата плавающей точки
    bl fprintf
    // fprintf(file, "%d: %.7f\n", член ряда)
    
    // проверяем на сколько порядков член ряда меньше суммы
    fabs s0, s10 // s0 = модуль от s10
    fmov s1, 1 // 1 в s1
    fmov s2, 10 // 10 в s2
1:
    fcmp s0, s1 // сравниваем s1 и s0
    bge 2f // если s0 > s1, прыгаеем в 2
    fmul s0, s0, s2 // s0 = s0 * s2
    b 1b // назад на 1: (158)
2:
    fdiv s1, s10, s0 // s1 = s10/s0

    fdiv s0, s14, s1 // s0 = s14 / s1
    fabs s0, s0 // s0 = modul s0
    fcmp s0, s15 // если s0 < prescision, то закинчиваем вычисления
    blt calculated

     // обновляем множители для следующего цикла
    add x20, x20, 1 // x20 = x20 + 1
    sub x21, x21, 2 // x21 = x21 + 2

    fmul s9, s9, s8 // *= x^2 // s9 = s9*s8
    fneg s9, s9
    
    scvtf s0, x20 // n // преобразование целого числа со знаком в вещественное, округление в соответствии со значением FPCR
    fmul s0, s0, s0 // n^2 // s0 = s0*s0
    fdiv s9, s9, s0 // /= n^2 // s9 = s9/s0
    
    add x0, x20, x20 // x0 = x20+x20
    scvtf s0, x0 // 2n // преобразование целого числа со знаком в вещественное, округление в соответствии со значением FPCR
    fmul s9, s9, s0  // *= 2n // s9 = s9*s0
    
    sub x0, x0, 1 // x0 = x0 - 1
    scvtf s0, x0 // 2n-1 // преобразование целого числа со знаком в вещественное, округление в соответствии со значением FPCR
    fmul s9, s9, s0 // *= 2n-1 // s9 = s9*s0
    
    fmov s0, 4
    fdiv s9, s9, s0

    b loop  // считаем следующий член ряда
calculated:

     // сумма вычислена до нужной точности
     
    adr x0, s_series
    fcvt d0, s10 // преобразование формата плавающей точки
    bl printf

    mov x0, x28 // закрываем файл
    bl fclose
exit:
    mov     sp, x29
    ldp     x29, x30, [sp], 32 // восстанавливаем значения x29 и x30 из стека и выходим из стекового фрейма
    ret

    .size   main, (. - main)
