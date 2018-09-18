; void tresColores_asm (unsigned char *src, unsigned char *dst, int width, int height,
;                       int src_row_size, int dst_row_size);
; rdi -> *src
; rsi -> *dst
; edx -> width
; ecx -> height
; r8d -> src_row_size
; r9d -> dst_row_size
section .data
  maskRGBsinA: times 4 DD 0x00010101
  maskAlfa: times 4 DD 0xff000000
  maskIdentidad: times 8 DW 1
  maskDiv3: times 4 DD 3.0
  ;maskCrema: times 4 DD 0x00a1afb1   ; 0|161|175|177
  ;maskVerde: times 4 DD 0x00535400   ; 0|83 |84 |0
  ;maskRojo:  times 4 DD 0x003142b7   ; 0|49 |66 |183
  maskCrema: times 4 DD 0x00b1afa1   ; 0|161|175|177
  maskVerde: times 4 DD 0x00005453   ; 0|83 |84 |0
  maskRojo:  times 4 DD 0x00b74231   ; 0|49 |66 |183
  maskCmp33: times 4 DD 85
  maskCmp170: times 4 DD 170
  maskShuffleW: db 0,0,0,0xFF,4,4,4,0xFF,8,8,8,0xFF,12,12,12,0xFF

section .text

global tresColores_asm
tresColores_asm:
  push rbp
  mov rbp, rsp
  sub rsp, 8
  push r12

  mov r12d, edx ; guardo el ancho en r12 para conservarlo

.alto:
  cmp ecx, 0 ; me fijo si llegue a la ultima fila
  je .fin
  mov edx, r12d ; reseteo el ancho para comenzar otra iteracion sobre la fila
  dec ecx
  jmp .ancho

.ancho:
  movdqu xmm0, [rdi] ; movemos a xmm0 el puntero a los primeros 4 pixeles
  ; construimos W para utilizarlo despues
  movdqu xmm1, [maskRGBsinA]
  pmaddubsw xmm0, xmm1 ; | r + g | b + 0 | cada double word ...
  movdqu xmm1, [maskIdentidad]
  pmaddwd xmm0, xmm1 ; | r + g + b | cada double word ...
  cvtdq2ps xmm0, xmm0 ; convierto el contenido de xmm0 a float
  movdqu xmm1, [maskDiv3]
  divps xmm0, xmm1 ; divido las sumas rgb por 3
  cvttps2dq xmm0, xmm0 ; convierto los W resultantes a entero

  ; vamos reemplazando los colores segun el brillo
  movdqu xmm14, [maskCrema]
  movdqu xmm13, [maskVerde]
  movdqu xmm12, [maskRojo]
  movdqu xmm1, [maskCmp33]
  pcmpgtd xmm1, xmm0 ; comparo los W contra 33
  movdqu xmm2, xmm1 ; guardamos en xmm2 la mascara de esa comparacion
  pand xmm1, xmm12 ; aca tengo guardado Crema para donde corresponde ese color y 0 en el resto
  movdqu xmm3, [maskCmp170]
  pcmpgtd xmm3, xmm0 ; comparo los W contra 170
  pcmpeqb xmm4, xmm4 ; seteo xmm4 con '11111...'
  pxor xmm3, xmm4 ; niego el resultado de la mascara
  movdqu xmm5, xmm3 ; guardo en xmm5 la mascara
  pand xmm3, xmm14 ; ahora en xmm3 tenemos los pixeles que queremos reemplazar salvo por los verdes
  por xmm2, xmm5
  pxor xmm2, xmm4 ; invierto el resultado y con eso tengo los pixeles verdes
  pand xmm2, xmm13
  por xmm1, xmm2
  por xmm1, xmm3 ; y con esto queda en xmm1 los pixeles reemplazados
  ; queda sumar los W a los pixeles nuevos
  psrld xmm0, 2 ; dividimos los W por 4 shifteando bits
  movdqu xmm6, [maskShuffleW]
  pshufb xmm0, xmm6 ; guardamos en xmm0 los W correspondientes byte a byte en vez de dw
  paddusb xmm1, xmm0 ; sumamos los W a los nuevos pixeles
  movdqu xmm6, [maskAlfa]
  por xmm1, xmm6
  ; muevo el resultado al espacio correspondiente en memoria
  movdqu [rsi], xmm1
  add rdi, 16 ; me desplazo a los siguientes 4 pixeles
  add rsi, 16

  sub edx, 4
  cmp edx,0
  je .alto
  jne .ancho

.fin:
  pop r12
  add rsp, 8
  pop rbp
  ret
