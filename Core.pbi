;------------------------------------------------------------------------------------------------
; CAPTURE MODULE DECLARATION (WINDOWS ONLY)
;------------------------------------------------------------------------------------------------
DeclareModule Capture
  #RECTANGLE_THICKNESS = 2
  Structure Rectangle_t
    x.i
    y.i
    w.i
    h.i
  EndStructure
 
  Structure Capture_t
    hWnd.i
    rect.Rectangle_t
    img.i
    *buffer
  EndStructure
  
  DataSection
    swap_red_blue_mask:
    Data.a 2,1,0,3,6,5,4,7,10,9,8,11,14,13,12,15
  EndDataSection
  
  Declare Init(*c.Capture_t, *r.Rectangle_t=#Null, hwnd=#NUL)
  Declare Capture(*c.Capture_t, flipBuffer.b)
  Declare Term(*c.Capture_t)
EndDeclareModule

;------------------------------------------------------------------------------------------------
; CAPTURE MODULE IMPLEMENTATION
;------------------------------------------------------------------------------------------------
Module Capture
  
  Procedure _DebugFormat(format.i)
    If format & #PB_PixelFormat_8Bits 
      Debug "8 bits (1 octet par pixel, palettisé)"
    ElseIf format & #PB_PixelFormat_15Bits
      Debug "15 bits (2 octets par pixel)"
    ElseIf format & #PB_PixelFormat_16Bits
      Debug "16 bits (2 octets par pixel)"
    ElseIf format & #PB_PixelFormat_24Bits_RGB
      Debug "24 bits (3 octets par pixel (RRGGBB))"
    ElseIf format & #PB_PixelFormat_24Bits_BGR
      Debug "24 bits (3 octets par pixel (BBGGRR))"
    ElseIf format & #PB_PixelFormat_32Bits_RGB  
      Debug "32 bits (4 octets par pixel (RRGGBB))"
    ElseIf format & #PB_PixelFormat_32Bits_BGR
      Debug "32 bits (4 octets par pixel (BBGGRR))"
    EndIf
    
    If format & #PB_PixelFormat_ReversedY 
      Debug "Les lignes sont inversées en hauteur !"
    Else
      Debug "Les lignes ne sont pas inversées en hauteur !"
    EndIf 
  EndProcedure

  Procedure _FlipBuffer(*c.Capture_t)
    
    StartDrawing(ImageOutput(*c\img))
    
    Define *input = DrawingBuffer()
    Define *output = *c\buffer
    Define num_pixels_in_row.i = *c\rect\w
    Define num_rows.i = *c\rect\h
    Define *mask = Capture::?swap_red_blue_mask
    
    ! mov rsi, [p.p_input]                ; input buffer to rsi register
    ! mov rdi, [p.p_output]               ; output buffer to rdi register
    ! mov eax, [p.v_num_pixels_in_row]    ; image width in rax register
    ! mov ecx, [p.v_num_rows]             ; image height in rcx register
    ! mov r10, [p.p_mask]                 ; load mask in r10 register
    ! mov r15, rax                        ; num pixels in a row
    ! imul r15, 4                         ; size of a row of pixels
    ! movups xmm1, [r10]                  ; load mask in xmm1 register
    
    ! loop_over_rows:
    !   mov r11, rax                      ; reset pixels counter
    !   mov r13, rcx                      ; as we reverse iterate
    !   sub r13, 1                        ; we need the previous row
    !   imul r13, r15                     ; address of current pixel
    !   mov r14, rsi                      ; load input buffer in r14 register
    !   add r14, r13                      ; offset to current pixel
    
    ! loop_over_pixels:
    !   movups xmm0, [r14]                ; load pixel to xmm0
    !   pshufb xmm0, xmm1                 ; shuffle bytes with mask
    !   movups [rdi], xmm0                ; set fixed color to output ptr
    !   add r14, 16                       ; advance input ptr
    !   add rdi, 16                       ; advance output ptr
    !   sub r11, 4                        ; decrement pixel counter
    !   jg loop_over_pixels               ; loop next pixel
    
    ! next_row:
    !   dec rcx                           ; decrement row counter
    !   jg loop_over_rows                 ; loop next row
    StopDrawing()
  EndProcedure
  
  Procedure Init(*c.Capture_t, *r.Rectangle_t=#Null, hWnd=#Null)
    *c\hWnd = hWnd
    If *r
      *c\rect\x = *r\x
      *c\rect\y = *r\y
      *c\rect\w = *r\w
      *c\rect\h = *r\h
    ElseIf *c\hWnd
      Define rect.RECT
      If GetWindowRect_(*c\hWnd, rect)
        *c\rect\x = 0
        *c\rect\y = 0
        *c\rect\w = rect\right - rect\left
        *c\rect\h = rect\bottom - rect\top
      EndIf
    Else
      MessageRequester("Capture", "Fail to Initialize : No valid context !")
    EndIf
    
    Debug "x : "+ Str(*c\rect\x)
    Debug "y : "+ Str(*c\rect\y)
    Debug "width : "+Str(*c\rect\w)
    Debug "height : "+Str(*c\rect\h)
    If *c\rect\w > 0 And *c\rect\h > 0
      *c\img = CreateImage(#PB_Any, *c\rect\w, *c\rect\h, 32)
      *c\buffer = AllocateMemory(*c\rect\w * *c\rect\h * 4)
    EndIf
  EndProcedure
  
  Procedure Capture(*c.Capture_t, flipBuffer.b)
    Define dstDC = StartDrawing(ImageOutput(*c\img))
    
    If Not *c\hWnd : *c\hWnd = GetDesktopWindow_() : EndIf 
    Define srcDC = GetDC_(*c\hWnd)
    
    If dstDC And srcDC
      BitBlt_(hDC,0,0,*c\rect\w,*c\rect\h,srcDC,*c\rect\x,*c\rect\y,#SRCCOPY)
    EndIf
    ReleaseDC_(*c\hWnd, srcDC)

    StopDrawing()
    
    If flipBuffer      
      _FlipBuffer(*c)
    EndIf
    ProcedureReturn
  EndProcedure
  
  Procedure Term(*c.Capture_t)
    If IsImage(*c\img) : FreeImage(*c\img) : EndIf
    If *c\buffer : FreeMemory(*c\buffer) : EndIf
  EndProcedure 
EndModule

;------------------------------------------------------------------------------------------------
; IMPORT C FUNCTIONS
;------------------------------------------------------------------------------------------------
ImportC "gif.lib"
  AnimatedGif_Init(filename.p-utf8, width.l, height.l, delay.i)
  AnimatedGif_Term(*writer)
  AnimatedGif_AddFrame(*writer, *cs)
EndImport

; IDE Options = PureBasic 5.73 LTS (Windows - x64)
; CursorPosition = 144
; FirstLine = 103
; Folding = --
; EnableXP