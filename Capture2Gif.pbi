;================================================================================================
; CAPTURE TO GIF (WINDOWS ONLY)
;================================================================================================

;------------------------------------------------------------------------------------------------
; SCREEN CAPTURE MODULE DECLARATION
;------------------------------------------------------------------------------------------------
DeclareModule ScreenCapture
  #RECTANGLE_THICKNESS = 2
  Structure RectangleData_t
    left.i
    top.i
    width.i
    height.i
  EndStructure
 
  Structure ScreenCapture_t
    rect.RectangleData_t
    img.i
    *buffer
  EndStructure
  
  DataSection
    swap_red_blue_mask:
    Data.a 2,1,0,3,6,5,4,7,10,9,8,11,14,13,12,15
  EndDataSection
  
  Declare Init(*data.ScreenCapture_t, *rect.RectangleData_t)
  Declare Capture(*data.ScreenCapture_t, flipBuffer.b)
  Declare Term(*data.ScreenCapture_t)
EndDeclareModule

;------------------------------------------------------------------------------------------------
; SCREEN CAPTURE MODULE IMPLEMENTATION
;------------------------------------------------------------------------------------------------
Module ScreenCapture
  Procedure FlipBuffer(*data.ScreenCapture_t)
    StartDrawing(ImageOutput(*data\img))
    Define *input = DrawingBuffer()
    Define *output = *data\buffer
    Define num_pixels_in_row.i = *data\rect\width
    Define num_rows.i = *data\rect\height
    Define *mask = ScreenCapture::?swap_red_blue_mask
    
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

  Procedure Init(*data.ScreenCapture_t, *rect.RectangleData_t)
    *data\rect\top = *rect\top
    *data\rect\left = *rect\left
    *data\rect\width = *rect\width
    *data\rect\height = *rect\height
    
    Debug *data\rect\width
    Debug *data\rect\height
    
    If *data\rect\width > 0 And *data\rect\height > 0
      *data\img = CreateImage(#PB_Any, *data\rect\width, *data\rect\height, 32)
      *data\buffer = AllocateMemory(*data\rect\width * *data\rect\height * 4)
    EndIf
  EndProcedure
  
  Procedure Capture(*data.ScreenCapture_t, flipBuffer.b)
    Define hDC = StartDrawing(ImageOutput(*data\img))
     If hDC
       Define deskDC = GetDC_(GetDesktopWindow_())
       If deskDC
         BitBlt_(hDC,0,0,*data\rect\width,*data\rect\height,deskDC,*data\rect\left,*data\rect\top,#SRCCOPY)
       EndIf
       ReleaseDC_(GetDesktopWindow_(),deskDC)
     EndIf
    StopDrawing()
    
    If flipBuffer      
      FlipBuffer(*data)
    EndIf
    
    ProcedureReturn
  EndProcedure
  
  Procedure Term(*data.ScreenCapture_t)
    If IsImage(*data\img) : FreeImage(*data\img) : EndIf
    FreeMemory(*data\buffer)
  EndProcedure 
EndModule

#RECTANGLE_THICKNESS = 2
;------------------------------------------------------------------------------------------------
; IMPORT C FUNCTIONS
;------------------------------------------------------------------------------------------------
ImportC "gif.lib"
  AnimatedGif_Init(filename.p-utf8, width.l, height.l, delay.i)
  AnimatedGif_Term(*writer)
  AnimatedGif_AddFrame(*writer, *datas)
EndImport

;------------------------------------------------------------------------------------------------
; CAPTURE TO GIF DATAS
;------------------------------------------------------------------------------------------------
Structure Capture2Gif
  capture.ScreenCapture::ScreenCapture_t
  outputFolder.s
  outputFilename.s
  frame.i
  delay.i
  *writer
EndStructure

;------------------------------------------------------------------------------------------------
; GET CAPTURE RECTANGLE
;------------------------------------------------------------------------------------------------
Procedure GetRectangle(*rect.ScreenCapture::RectangleData_t)
  If InitMouse() = 0 Or InitSprite() = 0 Or InitKeyboard() = 0
    MessageRequester("Error", "Can't open DirectX", 0)
    End
  EndIf
  
  ExamineDesktops()
  Define width = DesktopWidth(0)
  Define height = DesktopHeight(0)
  Define rect.ScreenCapture::RectangleData_t 
  rect\top = 0
  rect\left = 0
  rect\width = width
  rect\height = height
  
  Define background.ScreenCapture::ScreenCapture_t
  ScreenCapture::Init(background, rect)
  ScreenCapture::Capture(background, #False)
  
  Define screen = OpenScreen(width, height, 32, "ScreenCapture") 
  If Not screen
    MessageRequester("Error", "Impossible to open a "+Str(width)+"*"+Str(height)+" 32-bit screen",0)
    End
  EndIf

  Define sprite = CreateSprite(#PB_Any,width,height)
  StartDrawing(SpriteOutput(sprite))
  DrawingMode(#PB_2DDrawing_AllChannels)
  DrawImage(ImageID(background\img), 0,0, width, height)
  StopDrawing()
  ScreenCapture::Term(background)
  
  Define startX.i, startY.i, endX.i, endY.i
  startX = DesktopMouseX()
  startY = DesktopMouseY()
  MouseLocate(startX, startY)
  Define drag = #False
  Define drop = #False
  Define color = RGB(255,128,0)
  
  Repeat
    FlipBuffers()                        ; Flip for DoubleBuffering
    ClearScreen(RGB(0,0,0))              ; CleanScreen, black
  
    ExamineKeyboard()
    ExamineMouse()                      
    
    If drag : endX = MouseX() : endY = MouseY() 
    Else : startX = MouseX() : startY = MouseY() : EndIf
  
    DisplaySprite(sprite, 0,0)
    StartDrawing(ScreenOutput())
    If drag
      Box(startX, startY - #RECTANGLE_THICKNESS * 0.5, endX - startX, #RECTANGLE_THICKNESS, color)
      Box(startX, endY - #RECTANGLE_THICKNESS * 0.5, endX - startX, #RECTANGLE_THICKNESS, color)
      Box(startX - #RECTANGLE_THICKNESS * 0.5, startY, #RECTANGLE_THICKNESS, endY - startY, color)
      Box(endX - #RECTANGLE_THICKNESS * 0.5, startY, #RECTANGLE_THICKNESS, endY - startY, color)
    Else
      Box(startX - 12, startY -#RECTANGLE_THICKNESS * 0.5, 24, #RECTANGLE_THICKNESS, color)
      Box(startX - #RECTANGLE_THICKNESS * 0.5, startY - 12, #RECTANGLE_THICKNESS, 24, color)
    EndIf
    StopDrawing()
    
    If MouseButton(#PB_MouseButton_Left) 
      drag = #True
    ElseIf drag
      drop = #True
    EndIf
  
  Until drop = #True
  
  If endX < startX : Swap startX, endX : EndIf
  If endY < startY : Swap startY, endY : EndIf
  
  *rect\left = startX
  *rect\top = startY
  *rect\width = endX - startX
  *rect\height = endY - startY
  If *rect\width % 4 : *rect\width + ( 4 - *rect\width  % 4 ) : EndIf
  If *rect\height % 4 : *rect\height + ( 4 - *rect\height  % 4 ) : EndIf

  CloseScreen()
EndProcedure
  
Procedure Launch()
  Define app.Capture2Gif
  app\delay = 5
  app\outputFilename = "image"
  app\outputFolder = "E:/Projects/RnD/Capture2Gif"
  app\writer = #Null
  Define window = OpenWindow(#PB_Any, 200,200,400,200,"ScreenCapture")
  StickyWindow(window, #True)
  ButtonGadget(0, 10, 60, 100, 30, "Record")
  ButtonGadget(1, 120, 60, 100, 30, "Stop")
  Define close = #False
  Define record = #False
  Define rect.ScreenCapture::RectangleData_t
  Define capture.ScreenCapture::ScreenCapture_t
  
  Repeat
    Define event = WaitWindowEvent(1/60)

    If event = #PB_Event_Gadget 
      Define gadget = EventGadget()
      If gadget = 0
        StickyWindow(window, #False)
        GetRectangle(rect)
        ScreenCapture::Init(app\capture, rect)
        
        app\writer = AnimatedGif_Init( app\outputFolder+"/"+app\outputFilename+".gif", app\capture\rect\width, app\capture\rect\height, app\delay)
        
        StickyWindow(window, #True)
        record = #True
      ElseIf gadget = 1
        AnimatedGif_Term(app\writer)
        close = #True
      EndIf
    EndIf
    
    If record
      SetWindowColor(window, RGB(0,64,255))
      ScreenCapture::Capture(app\capture, #True)
      AnimatedGif_AddFrame(app\writer, app\capture\buffer)
      app\frame + 1
      Delay(app\delay)
    Else
      SetWindowColor(window, RGB(128,128,128))
    EndIf
    
  Until close = #True Or event = #PB_Event_CloseWindow
  ScreenCapture::Term(app\capture)  
EndProcedure
Launch()
; IDE Options = PureBasic 5.70 LTS (Windows - x64)
; CursorPosition = 215
; FirstLine = 189
; Folding = --
; EnableXP