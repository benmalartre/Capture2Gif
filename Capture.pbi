XIncludeFile "Platform.pbi"
XIncludeFile "Memory.pbi"

;------------------------------------------------------------------------------------------------
; CAPTURE MODULE
;------------------------------------------------------------------------------------------------
DeclareModule Capture

  Structure Capture_t
    rect.Platform::Rectangle_t
    hWnd.i
    img.i
    delay.i             ; frame delay in centiseconds (for gif encoding)
    *buffer             ; working pixel scratch buffer for current frame
    frameCount.i        ; number of frames stored
    *frames             ; pointer to a dynamically-grown array of frame pointers
    frameCapacity.i     ; current allocated capacity of the frames array
    excludeHWnd.i       ; CGWindowID to exclude from desktop capture (control bar)
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
    AnimatedGif_AllocFrame(width.l, height.l)
    AnimatedGif_FreeFrame(*frame)
    AnimatedGif_WriteFrames(filename.p-utf8, *frames, count.l, width.l, height.l, startFrame.l, endFrame.l, delay.l)
    GifLoad(filename.p-utf8, *out_count, *out_width, *out_height, *out_delay)
    GifFreeFrames(*frames, count.l)
  EndImport

  Declare Init(*c.Capture_t, *r.Platform::Rectangle_t, hWnd=#Null)
  Declare Frame(*c.Capture_t, flipBuffer.b=#True)
  Declare Term(*c.Capture_t)
  Declare Export(*c.Capture_t, filename.s, startFrame.i=0, endFrame.i=-1)
  Declare Free(*c.Capture_t)
EndDeclareModule

;------------------------------------------------------------------------------------------------
; CAPTURE MODULE IMPLEMENTATION
;------------------------------------------------------------------------------------------------
Module Capture

  #FRAMES_INITIAL_CAPACITY = 64

  Procedure _GrowFrames(*c.Capture_t)
    Define newCapacity = *c\frameCapacity * 2
    Define *newArray = ReAllocateMemory(*c\frames, newCapacity * SizeOf(Integer))
    If *newArray
      *c\frames = *newArray
      *c\frameCapacity = newCapacity
    EndIf
  EndProcedure

  Procedure _FlipBuffer(*c.Capture_t)
    Define size = *c\rect\w * *c\rect\h * 4
    Define *copy = Memory::AllocateAlignedMemory(size + Memory::#ALIGN_BITS)
    Define *buffer = *c\buffer
    CopyMemory(*buffer, *copy, size)
    Define numPixelsInRow.i = *c\rect\w

    Define numRows.i = *c\rect\h
    Define *mask = Capture::?swap_red_blue_mask

    CompilerIf #PB_Compiler_Backend = #PB_Backend_Asm
      ! mov rsi, [p.p_copy]                 ; copy buffer to rsi register
      ! mov rdi, [p.p_buffer]               ; drawing buffer to rdi register
      ! mov eax, [p.v_numPixelsInRow]       ; image width in rax register
      ! mov ecx, [p.v_numRows]              ; image height in rcx register
      ! mov r11, [p.p_mask]                 ; load mask in r10 register
      ! mov r15, rax                        ; num pixels in a row
      ! imul r15, 4                         ; size of a row of pixels
      ! movups xmm1, [r11]                  ; load mask in xmm1 register

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
        For pixel = 0 To numPixelsInRow -1
          PokeB(*buffer + (numRows - 1-row)* rowSize + pixel * 4 + 2, PeekB(*copy + row * rowSize + pixel * 4 + 0))
          PokeB(*buffer + (numRows - 1-row)* rowSize + pixel * 4 + 1, PeekB(*copy + row * rowSize + pixel * 4 + 1))
          PokeB(*buffer + (numRows - 1-row)* rowSize + pixel * 4 + 0, PeekB(*copy + row * rowSize + pixel * 4 + 2))
          PokeB(*buffer + (numRows - 1-row)* rowSize + pixel * 4 + 3, PeekB(*copy + row * rowSize + pixel * 4 + 3))
        Next
      Next
    CompilerEndIf

    Memory::FreeAlignedMemory(*copy, size + Memory::#ALIGN_BITS)
  EndProcedure

  Procedure Init(*c.Capture_t, *r.Platform::Rectangle_t, hWnd=#Null)
    *c\hWnd = hWnd
    If *r
      CopyMemory(*r, @*c\rect, SizeOf(Platform::Rectangle_t))
    ElseIf hWnd
      Platform::GetWindowRect(hWnd, @*c\rect)
    EndIf

    If *c\rect\w > 0 And *c\rect\h > 0
      *c\img    = CreateImage(#PB_Any, *c\rect\w, *c\rect\h, 32)
      *c\buffer = Memory::AllocateAlignedMemory(*c\rect\w * *c\rect\h * 4 + Memory::#ALIGN_BITS)
    EndIf

    *c\frameCount    = 0
    *c\frameCapacity = #FRAMES_INITIAL_CAPACITY
    *c\frames        = AllocateMemory(*c\frameCapacity * SizeOf(Integer))
  EndProcedure

  Procedure Frame(*c.Capture_t, flipBuffer.b=#True)
    Define dstDC = StartDrawing(ImageOutput(*c\img))
    If *c\hWnd
      Platform::CaptureWindowImage(dstDC, *c\hWnd, @*c\rect)
    Else
      Platform::CaptureDesktopImage(dstDC, @*c\rect, *c\excludeHWnd)
    EndIf

    CopyMemory(DrawingBuffer(), *c\buffer, *c\rect\w * *c\rect\h * 4)
    StopDrawing()

    If flipBuffer : _FlipBuffer(*c) : EndIf

    ; grow frames array if needed
    If *c\frameCount >= *c\frameCapacity
      _GrowFrames(*c)
    EndIf

    ; allocate a new frame buffer and copy the current pixel data into it
    Define *frame = AnimatedGif_AllocFrame(*c\rect\w, *c\rect\h)
    If *frame
      CopyMemory(*c\buffer, *frame, *c\rect\w * *c\rect\h * 4)
      PokeI(*c\frames + *c\frameCount * SizeOf(Integer), *frame)
      *c\frameCount + 1
    EndIf
  EndProcedure

  Procedure Term(*c.Capture_t)
    ; stop capturing — release image and scratch buffer but keep frame array intact
    ; caller should call Export() then Free() when done
    If IsImage(*c\img) : FreeImage(*c\img) : *c\img = 0 : EndIf
    If *c\buffer
      Memory::FreeAlignedMemory(*c\buffer, *c\rect\w * *c\rect\h * 4 + Memory::#ALIGN_BITS)
      *c\buffer = 0
    EndIf
  EndProcedure

  ; Write a subset of captured frames to a GIF file.
  ; startFrame / endFrame are 0-based inclusive indices.
  ; Pass endFrame = -1 to include all frames from startFrame.
  ; delay is in centiseconds (5 = 50ms ≈ 20fps).
  Procedure Export(*c.Capture_t, filename.s, startFrame.i=0, endFrame.i=-1)
    If *c\frameCount = 0 Or Not *c\frames : ProcedureReturn : EndIf
    If endFrame < 0 Or endFrame >= *c\frameCount : endFrame = *c\frameCount - 1 : EndIf
    If startFrame < 0 : startFrame = 0 : EndIf
    AnimatedGif_WriteFrames(filename, *c\frames, *c\frameCount,
                             *c\rect\w, *c\rect\h,
                             startFrame, endFrame, *c\delay)
  EndProcedure

  ; Free all stored frame buffers and the frames array itself.
  Procedure Free(*c.Capture_t)
    If *c\frames
      For i = 0 To *c\frameCount - 1
        Define *frame = PeekI(*c\frames + i * SizeOf(Integer))
        If *frame : AnimatedGif_FreeFrame(*frame) : EndIf
      Next
      FreeMemory(*c\frames)
      *c\frames = 0
    EndIf
    *c\frameCount    = 0
    *c\frameCapacity = 0
  EndProcedure

EndModule
; IDE Options = PureBasic 6.00 Beta 7 - C Backend (MacOS X - arm64)
; CursorPosition = 1
; FirstLine = 1
; Folding = --
; EnableXP
