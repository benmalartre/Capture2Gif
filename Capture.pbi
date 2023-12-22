XIncludeFile "Core.pbi"
XIncludeFile "Widget.pbi"
;------------------------------------------------------------------------------------------------
; CAPTURE APP 
;------------------------------------------------------------------------------------------------
#RECTANGLE_THICKNESS = 2

Enumeration
  #RECORD_BTN
  #STOP_BTN
  #PROCESS_LIST
EndEnumeration

Structure Capture2Gif
  capture.Capture::Capture_t
  outputFolder.s
  outputFilename.s
  frame.i
  delay.i
  *writer
EndStructure

Structure Window_t
  hWnd.i
  Map childrens.i()
EndStructure

; Get capture rectangle
;
Procedure GetRectangle(*rect.Capture::Rectangle_t, hwnd=#Null)
  If InitMouse() = 0 Or InitSprite() = 0 Or InitKeyboard() = 0
    MessageRequester("Error", "Can't open DirectX", 0)
    End
  EndIf
  
  ExamineDesktops()
  Define width = DesktopWidth(0)
  Define height = DesktopHeight(0)
  Define rect.Capture::Rectangle_t 
  rect\y = 0
  rect\x = 0
  rect\w = width
  rect\h = height
  
  Define background.Capture::Capture_t
  Capture::Init(background, rect, hwnd)
  Capture::Capture(background, #False)
  
  Define screen = OpenScreen(width, height, 32, "Capture") 
  If Not screen
    MessageRequester("Error", "Impossible to open a "+Str(width)+"*"+Str(height)+" 32-bit screen",0)
    End
  EndIf

  Define sprite = CreateSprite(#PB_Any,width,height)
  StartDrawing(SpriteOutput(sprite))
  DrawingMode(#PB_2DDrawing_AllChannels)
  DrawImage(ImageID(background\img), 0,0, width, height)
  StopDrawing()
  Capture::Term(background)
  
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
  
  *rect\x = startX
  *rect\y = startY
  *rect\w = endX - startX
  *rect\h = endY - startY
  If *rect\w % 4 : *rect\w + ( 4 - *rect\w  % 4 ) : EndIf
  If *rect\h % 4 : *rect\h + ( 4 - *rect\h  % 4 ) : EndIf

  CloseScreen()
EndProcedure

; helper function to enumerate open windows
;
Procedure _EnumerateWindows(*window.Window_t)
  Define title.s {256}
  Define hWnd    .i
  
  hWnd = GetWindow_(GetDesktopWindow_(), #GW_CHILD)
  While hWnd
    GetWindowText_(hWnd, @title, 256)
    AddMapElement(*window\childrens(), title)
    *window\childrens() = hWnd
    hWnd = GetWindow_(hWnd, #GW_HWNDNEXT)
  Wend
EndProcedure

; try get a window by it's name
;
Procedure GetWindowByName(name.s="Softimage")
  Define window.Window_t
  _EnumerateWindows(window)
  ForEach window\childrens()
    If FindString(MapKey(window\childrens()), name)
      Debug "found xsi view"
      ProcedureReturn window\childrens()
    EndIf
  Next 
EndProcedure

Procedure.l _EnumChildWindowsProc(hWnd.l, param.l) 
  Protected *window.Window_t = param
  Protected title.s = Space(256)
  GetWindowText_(hWnd, @title, 200)
  AddMapElement(*window\childrens(), title)
  *window\childrens() = hWnd
  ProcedureReturn #True
EndProcedure 

Procedure EnumerateChildWindows(*window.Window_t, pWnd)
  EnumChildWindows_(pWnd,@_EnumChildWindowsProc(), *window)
EndProcedure 

Enumeration
  #PLAY
  #RECORD
  #STOP
EndEnumeration


Procedure Launch()
  Define app.Capture2Gif
  app\delay = 5
  app\outputFilename = "image"
  app\outputFolder = "C:/Users/graph/Documents/bmal/src/Capture2Gif"
  app\writer = #Null
  Define width = 400
  Define height = 400
  Define window = OpenWindow(#PB_Any, 
                             200, 
                             200,
                             width,
                             height,
                             "Scr33nC0rd3r", 
                             #PB_Window_SystemMenu|
                             #PB_Window_SizeGadget)
  
  Define width
  Define root = Widget::CreateRoot(window)
  Define text = Widget::CreateText(root, "   enter the dragon!",0,0, width, 32)
  Define string = Widget::CreateString(root, 0,32, width, 120)
  Define canvas = Widget::CreateContainer(root, 0, height / 2,width, height / 2, #True)
  Define play = Widget::CreateButton(canvas, "zob", 10, 10, width-20, 32)
  Define stop = Widget::CreateButton(canvas, "zob", 10, 50, width-20, 32)
  
  Define play = Widget::CreateIcon(canvas, "M 4 4 L 28 16 L 4 28 Z", 128, 120, 32, 32)
  Define stop = Widget::CreateIcon(canvas, "M 4 4 L 28 4 L 28 28 L 4 28 Z", 190, 120, 32, 32)
  
  Define check = Widget::CreateCheck(canvas, "zob", #True, 120, 10, 32, 32)
  Widget::Draw(root)
  StickyWindow(window, #True)

;   ListViewGadget(#PROCESS_LIST, 10, 10, 380, 150)
  
  Define hWnd = GetWindowByName("XSIFloatingView")
  ;Define hWnd = GetWindowByName("Softimage")
    
  Define close = #False
  Define record = #False
  Define rect.Capture::Rectangle_t
  Define capture.Capture::Capture_t
  
  Repeat
    Define event = WaitWindowEvent(app\delay)

    If event = #PB_Event_Gadget 
      Define gadget = EventGadget()
      If gadget = #RECORD_BTN
        StickyWindow(window, #False)
        If Not hWnd
          GetRectangle(rect)
          Capture::Init(app\capture, rect, #Null)
        Else 
          Capture::Init(app\capture, #Null, hWnd)
        EndIf

        app\writer = AnimatedGif_Init( app\outputFolder+"/"+app\outputFilename+".gif", app\capture\rect\w, app\capture\rect\h, app\delay)
        StickyWindow(window, #True)
        record = #True
      ElseIf gadget = #STOP_BTN
        If record
          AnimatedGif_Term(app\writer)
          record = #False
        EndIf
        close = #True
      EndIf
      
    ElseIf event = #PB_Event_SizeWindow
      Widget::Resize(root, 
                     0, 
                     0, 
                     WindowWidth(window, #PB_Window_InnerCoordinate), 
                     WindowHeight(window, #PB_Window_InnerCoordinate))
      Widget::Draw(root)
    EndIf
    
    If record
      SetWindowColor(window, RGB(0,64,255))
      Capture::Capture(app\capture, #True)
      AnimatedGif_AddFrame(app\writer, app\capture\buffer)
      app\frame + 1
      Delay(app\delay)
    Else
      SetWindowColor(window, RGB(128,128,128))
    EndIf
    
  Until close = #True Or event = #PB_Event_CloseWindow
  Capture::Term(app\capture)  
EndProcedure
Launch()
; IDE Options = PureBasic 5.73 LTS (Windows - x64)
; CursorPosition = 187
; FirstLine = 176
; Folding = --
; EnableXP