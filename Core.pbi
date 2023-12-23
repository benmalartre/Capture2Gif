;------------------------------------------------------------------------------------------------
; CAPTURE MODULE DECLARATION (WINDOWS ONLY)
;------------------------------------------------------------------------------------------------
DeclareModule Capture
  Structure Rectangle_t
    x.i
    y.i
    w.i
    h.i
  EndStructure
 
  Structure Capture_t
    rect.Rectangle_t
    hWnd.i
    img.i
    *buffer
  EndStructure
  
  DataSection
    swap_red_blue_mask:
    Data.a 2,1,0,3,6,5,4,7,10,9,8,11,14,13,12,15
  EndDataSection
  
  ;------------------------------------------------------------------------------------------------
  ; IMPORT C FUNCTIONS
  ;------------------------------------------------------------------------------------------------
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    ImportC "Gif.lib"
  CompilerElse
    ImportC "Gif.a"
  CompilerEndIf
    AnimatedGif_Init(filename.p-utf8, width.l, height.l, delay.i)
    AnimatedGif_Term(*writer)
    AnimatedGif_AddFrame(*writer, *cs)
  EndImport
  
  Declare Init(*c.Capture_t, *r.Rectangle_t=#Null, hWnd=#NUL)
  Declare Capture(*c.Capture_t, flipBuffer.b=#True)
  Declare Term(*c.Capture_t)
EndDeclareModule

;------------------------------------------------------------------------------------------------
; CAPTURE MODULE IMPLEMENTATION
;------------------------------------------------------------------------------------------------
Module Capture

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
    
    ! loop_over_row_pixels:
    !   movups xmm0, [r14]                ; load pixel to xmm0
    !   pshufb xmm0, xmm1                 ; shuffle bytes with mask
    !   movups [rdi], xmm0                ; set fixed color to output ptr
    !   add r14, 16                       ; advance input ptr
    !   add rdi, 16                       ; advance output ptr
    !   sub r11, 4                        ; decrement pixel counter
    !   jg loop_over_row_pixels           ; loop next pixel
    
    ! next_row:
    !   dec rcx                           ; decrement row counter
    !   jg loop_over_rows                 ; loop next row
    StopDrawing()
  EndProcedure
  
  Procedure _CopyBuffer(*c.Capture_t)
    StartDrawing(ImageOutput(*c\img))
    
    Define *input = DrawingBuffer()
    Define *output = *c\buffer
    Define num_pixels.i = *c\rect\w * *c\rect\h
    Define *mask = Capture::?swap_red_blue_mask
    
    ! mov rsi, [p.p_input]                ; input buffer to rsi register
    ! mov rdi, [p.p_output]               ; output buffer to rdi register
    ! mov eax, [p.v_num_pixels]           ; image size in rax register
    ! mov r10, [p.p_mask]                 ; load mask in r10 register
    ! mov r11, rax                        ; num pixels in image
    ! movups xmm1, [r10]                  ; load mask in xmm1 register
    
    ! loop_over_pixels:
    !   movups xmm0, [rsi]                ; load pixel to xmm0
    !   pshufb xmm0, xmm1                 ; shuffle bytes with mask
    !   movups [rdi], xmm0                ; set fixed color to output ptr
    !   add rsi, 16                       ; advance input ptr
    !   add rdi, 16                       ; advance output ptr
    !   sub r11, 4                        ; decrement pixel counter
    !   jg loop_over_pixels               ; loop next pixel
    
    StopDrawing()
  EndProcedure
  
  Procedure Init(*c.Capture_t, *r.Rectangle_t=#Null, hWnd=#Null)
    If *r
      *c\rect\x = *r\x
      *c\rect\y = *r\y
      *c\rect\w = *r\w
      *c\rect\h = *r\h
    ElseIf hWnd
      Define rect.Rectangle_t
      *c\hWnd = hWnd
      CompilerIf #PB_Compiler_OS = #PB_OS_Windows
        If GetWindowRect_(hWnd, rect)
          *c\rect\x = 0
          *c\rect\y = 0
          *c\rect\w = rect\w
          *c\rect\h = rect\h
        EndIf
      CompilerElseIf #PB_Compiler_OS = #PB_OS_MacOS
        Define frame.CGRect
  
        CocoaMessage(@frame, hWnd, "frame")
        
        frame\origin\x = 100
        ; this will be from bottom of screen!
        ; correct calculation: ScreenHeight() - WindowHeight() - 100
        frame\origin\y = 100
        frame\size\width = 200
        frame\size\height = 300
        
        CocoaMessage(0, CocoaMessage(0, hWnd, "animator"), "setFrame:@", @frame, "display:", #YES) 
  
      CompilerEndIf
      
    Else
      MessageRequester("Capture", "Fail to Initialize : No valid context !")
    EndIf
    
    If *c\rect\w > 0 And *c\rect\h > 0
      *c\img = CreateImage(#PB_Any, *c\rect\w, *c\rect\h, 32)
      *c\buffer = AllocateMemory(*c\rect\w * *c\rect\h * 4)
    EndIf
  EndProcedure
  
  Procedure Capture(*c.Capture_t, flipBuffer.b=#True)
    CompilerIf #PB_Compiler_OS = #PB_OS_Windows
      Define hWnd = *c\hWnd
      If Not hWnd : hWnd = GetDesktopWindow_() : EndIf 
      Define srcDC = GetDC_(hWnd)
      Define dstDC = StartDrawing(ImageOutput(*c\img))
      If dstDC And srcDC
        BitBlt_(dstDC,0,0,*c\rect\w,*c\rect\h,srcDC,*c\rect\x,*c\rect\y,#SRCCOPY)
      EndIf
      ReleaseDC_(hWnd, srcDC)
      StopDrawing()
      
      If flipBuffer : _FlipBuffer(*c) : Else : _CopyBuffer(*c): EndIf
    CompilerElse
      
    CompilerEndIf
  EndProcedure
  
  Procedure Term(*c.Capture_t)
    If IsImage(*c\img) : FreeImage(*c\img) : EndIf
    If *c\buffer : FreeMemory(*c\buffer) : EndIf
  EndProcedure 
EndModule
; IDE Options = PureBasic 6.00 Beta 7 - C Backend (MacOS X - arm64)
; CursorPosition = 30
; FirstLine = 6
; Folding = --
; EnableXP