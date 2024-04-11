XIncludeFile "Platform.pbi"
;------------------------------------------------------------------------------------------------
; CAPTURE MODULE DECLARATION (WINDOWS ONLY)
;------------------------------------------------------------------------------------------------
DeclareModule Capture

  Structure Capture_t
    rect.Platform::Rectangle_t
    hWnd.i
    img.i
  EndStructure
  
  DataSection
    swap_red_blue_mask:
    Data.a 2,1,0,3,6,5,4,7,10,9,8,11,14,13,12,15
  EndDataSection
  
  ;------------------------------------------------------------------------------------------------
  ; IMPORT C FUNCTIONS
  ;------------------------------------------------------------------------------------------------
  CompilerSelect #PB_Compiler_OS
    CompilerCase #PB_OS_Windows
      ImportC "Gif.lib"
    CompilerCase #PB_OS_MacOS
      ImportC "Gif.a"
  CompilerEndSelect
    AnimatedGif_Init(filename.p-utf8, width.l, height.l, delay.i)
    AnimatedGif_Term(*writer)
    AnimatedGif_AddFrame(*writer, *cs)
  EndImport
  
  Declare Init(*c.Capture_t, *r.Platform::Rectangle_t, hWnd=#NUL)
  Declare Frame(*c.Capture_t, flipBuffer.b=#True)
  Declare Term(*c.Capture_t)
EndDeclareModule

;------------------------------------------------------------------------------------------------
; CAPTURE MODULE IMPLEMENTATION
;------------------------------------------------------------------------------------------------
Module Capture

  Procedure _FlipBuffer(*c.Capture_t)
    StartDrawing(ImageOutput(*c\img))
    
    Define size = *c\rect\w * *c\rect\h * 4
    Define *copy = AllocateMemory(size)
    Define *buffer = DrawingBuffer()
    CopyMemory(*buffer, *copy, size)
    Define numPixelsInRow.i = *c\rect\w
    Define numRows.i = *c\rect\h
    Define *mask = Capture::?swap_red_blue_mask
    
    CompilerIf #PB_Compiler_Backend = #PB_Backend_Asm
      ! mov rsi, [p.p_copy]                 ; copy buffer to rsi register
      ! mov rdi, [p.p_buffer]               ; drawing buffer to rdi register
      ! mov eax, [p.v_numPixelsInRow]       ; image width in rax register
      ! mov ecx, [p.v_numRows]              ; image height in rcx register
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
      
    CompilerElse
      Define row.i
      Define rowSize = numPixelsInRow * 4
      For row = 0 To numRows - 1
        CopyMemory(*copy + row * rowSize, *buffer + (numRows - row)* rowSize, rowSize)
      Next
      
    CompilerEndIf
    StopDrawing()
    
    FreeMemory(*copy)
  EndProcedure
  
  Procedure Init(*c.Capture_t, *r.Platform::Rectangle_t, hWnd=#Null)   
    *c\hWnd =  hWnd
    If *r 
      CopyMemory(*r, *c\rect, SizeOf(Platform::Rectangle_t))
    ElseIf hWnd
      Platform::GetWindowRect(hWnd, *c\rect)
    EndIf
    
    If *c\rect\w > 0 And *c\rect\h > 0
      *c\img = CreateImage(#PB_Any, *c\rect\w, *c\rect\h, 32)
    EndIf
  EndProcedure
  
  Procedure Frame(*c.Capture_t, flipBuffer.b=#True)
    If *c\hWnd
      Platform::CaptureWindowImage(*c\img, *c\hWnd, *c\rect)
    Else
      Platform::CaptureDesktopImage(*c\img, *c\rect)
    EndIf
    
    If flipBuffer : _FlipBuffer(*c) : EndIf
  EndProcedure
  
  Procedure Term(*c.Capture_t)
    If IsImage(*c\img) : FreeImage(*c\img) : EndIf
  EndProcedure 
 
  
EndModule
; IDE Options = PureBasic 6.10 LTS (Windows - x64)
; CursorPosition = 93
; FirstLine = 46
; Folding = --
; EnableXP