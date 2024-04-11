XIncludeFile "Capture.pbi"
XIncludeFile "Widget.pbi"
;-----------------------------------------------------------------------------------------------
;         ScreenCaptureToGif
;
;     Windows Only Windows/Desktop Record To Gif
;-----------------------------------------------------------------------------------------------
DeclareModule ScreenCaptureToGif
  UseModule Capture
  #APP_NAME = "ScreenCaptureToGif"
  #BORDER_THICKNESS = 4
  
  Enumeration
    #BORDER_NONE    = 0
    #BORDER_LEFT    = 1
    #BORDER_RIGHT   = 2
    #BORDER_TOP     = 4
    #BORDER_BOTTOM  = 8
    #BORDER_CENTER  = 16
  EndEnumeration
  
  Global TRANSPARENT_COLOR.i = RGBA(0,255,0,255)
  
  
  Structure App_t
    window.i                      ; main window with control widgets
    region.i                      ; transparent window for recording region
    canvas.i                      ; canvas that draw in transparent window (over other windows)
    rect.Platform::Rectangle_t    ; rectangle that will be recorded
    hWnd.i                        ; window handle that will be recorded (not available)
    capture.Capture::Capture_t    ; screen capture recorder
    outputFolder.s                ; output folder
    outputFilename.s              ; output filename
    delay.i                       ; delay between each screen shot
    record.b                      ; is currently recording
    close.b                       ; close window flag
    *writer                       ; gif writer
    *ui.Widget::Container_t       ; ui root container widget
    elapsed.q                     ; elapsed time since last screen shot
    hover.i                       ; mouse hovering region border
    drag.i                        ; mouse drag region border
    
    Map widgets.i() 
  EndStructure
  
  Declare InitRectangle(*app.App_t)
  Declare GetRectangle(*app.App_t, *r.Platform::Rectangle_t)
  Declare SelectWindow(*app.App_t)
  Declare SelectRectangle(*app.App_t)
  
  Declare OnRecord(*app.App_t)
  
  Declare Launch()
EndDeclareModule



;-----------------------------------------------------------------------------------------------
; ScreenCaptureToGif Implementation
;-----------------------------------------------------------------------------------------------
Module ScreenCaptureToGif
  UseModule Capture
  
   Procedure.s _RandomString(len.i)
    Define string.s
    For i=0 To len-1
      Select Random(2) 
        Case 0 : string + Chr(Random(25) + 97) ; (a ---> z)
        Case 1 : string + Chr(Random(25) + 65) ; (A ---> Z)
        Default : string + Chr(Random(9) + 48) ; (0 ---> 9)
      EndSelect
    Next
    ProcedureReturn string
  EndProcedure
  
  Procedure _DrawRegion(*app.App_t)
    StartVectorDrawing(CanvasVectorOutput(*app\canvas))
    
    AddPathBox(0,0,WindowWidth(*app\region, #PB_Window_InnerCoordinate), 
               WindowHeight(*app\region, #PB_Window_InnerCoordinate))
    VectorSourceColor(TRANSPARENT_COLOR)
    FillPath()
    
    MovePathCursor(*app\rect\x,*app\rect\y)
    AddPathLine(*app\rect\x + *app\rect\w, *app\rect\y)
    AddPathLine(*app\rect\x + *app\rect\w, *app\rect\y + *app\rect\h)
    AddPathLine(*app\rect\x, *app\rect\y + *app\rect\h)
    ClosePath()
    
    If Not *app\record
      Define centerX = (*app\rect\x * 2 + *app\rect\w) >> 1
      Define centerY = (*app\rect\y * 2 + *app\rect\h) >> 1
      Define centerL = 8
      
      MovePathCursor(centerX-centerL, centerY-centerL)
      AddPathLine(centerX+centerL, centerY+centerL)
      
      MovePathCursor(centerX+centerL, centerY-centerL)
      AddPathLine(centerX-centerL, centerY+centerL)
      VectorSourceColor(RGBA(255, 255, 0, 255))
    Else
      VectorSourceColor(RGBA(255, 120, 180, 255))
    EndIf
    
    StrokePath(#BORDER_THICKNESS, #PB_Path_RoundEnd|#PB_Path_RoundCorner)
    
    StopVectorDrawing()  
  EndProcedure
  
 

  Procedure _WindowEvent(*app.App_t, event.i)    
   If event = #PB_Event_Gadget 
      Define gadget = EventGadget()

      If FindMapElement(*app\widgets(), Str(gadget))
        Widget::OnEvent(*app\widgets())
      EndIf
      
    ElseIf event = #PB_Event_SizeWindow
      Widget::Resize(*app\ui, 
                     0, 
                     0, 
                     WindowWidth(*app\window, #PB_Window_InnerCoordinate), 
                     WindowHeight(*app\window, #PB_Window_InnerCoordinate))
    EndIf
    
    
  EndProcedure
  
  Procedure _RegionEvent(*app.App_t, event.i)
    If EventGadget() <> *app\canvas : ProcedureReturn : EndIf
    Define mouseX = WindowMouseX(*app\region)
    Define mouseY = WindowMouseY(*app\region)
    Define type = EventType()
    
    If type = #PB_EventType_LeftButtonDown And *app\hover 
      *app\drag = *app\hover
      
    ElseIf type = #PB_EventType_LeftButtonUp And *app\drag
      *app\drag = #BORDER_NONE
      
    ElseIf type = #PB_EventType_MouseMove
      If *app\drag = #BORDER_NONE
        *app\hover = #BORDER_NONE
        Define centerX = (*app\rect\x * 2 + *app\rect\w) >> 1
        Define centerY = (*app\rect\y * 2 + *app\rect\h) >> 1
        
        If Abs(mouseX - centerX) < (#BORDER_THICKNESS * 2) And Abs(mouseY - centerY) < (#BORDER_THICKNESS * 2)
          *app\hover | #BORDER_CENTER
        EndIf
        
        If Abs(mouseX - *app\rect\x) < #BORDER_THICKNESS 
          *app\hover | #BORDER_LEFT
        ElseIf Abs(mouseX - (*app\rect\x + *app\rect\w)) < #BORDER_THICKNESS
          SetGadgetAttribute(*app\canvas, #PB_Canvas_Cursor, #PB_Cursor_LeftRight)
          *app\hover | #BORDER_RIGHT
        EndIf
        
        If Abs(mouseY - *app\rect\y) < #BORDER_THICKNESS
          SetGadgetAttribute(*app\canvas, #PB_Canvas_Cursor, #PB_Cursor_UpDown)
          *app\hover | #BORDER_TOP
        ElseIf Abs(mouseY - (*app\rect\y + *app\rect\h)) < #BORDER_THICKNESS
          *app\hover | #BORDER_BOTTOM
          SetGadgetAttribute(*app\canvas, #PB_Canvas_Cursor, #PB_Cursor_UpDown)
        EndIf

        If (*app\hover & #BORDER_LEFT And *app\hover & #BORDER_TOP) Or 
           (*app\hover & #BORDER_BOTTOM And *app\hover & #BORDER_RIGHT)
          SetGadgetAttribute(*app\canvas, #PB_Canvas_Cursor, #PB_Cursor_LeftUpRightDown)
        ElseIf (*app\hover & #BORDER_RIGHT And *app\hover & #BORDER_TOP) Or 
           (*app\hover & #BORDER_BOTTOM And *app\hover & #BORDER_LEFT)
          SetGadgetAttribute(*app\canvas, #PB_Canvas_Cursor, #PB_Cursor_LeftDownRightUp)
        ElseIf (*app\hover & #BORDER_LEFT) Or (*app\hover & #BORDER_RIGHT)
          SetGadgetAttribute(*app\canvas, #PB_Canvas_Cursor, #PB_Cursor_LeftRight)
        ElseIf (*app\hover & #BORDER_TOP) Or (*app\hover & #BORDER_BOTTOM)
          SetGadgetAttribute(*app\canvas, #PB_Canvas_Cursor, #PB_Cursor_UpDown)
        Else
          SetGadgetAttribute(*app\canvas, #PB_Canvas_Cursor, #PB_Cursor_Default)
        EndIf
      
      Else
        If *app\hover & #BORDER_CENTER
          *app\rect\x = mouseX - (*app\rect\w >> 1)
          *app\rect\y = mouseY - (*app\rect\h >> 1)
          
        ElseIf *app\hover & #BORDER_LEFT And *app\hover & #BORDER_TOP
          *app\rect\w = (*app\rect\x + *app\rect\w) - mouseX
          *app\rect\h = (*app\rect\y + *app\rect\h) - mouseY
          *app\rect\x = mouseX
          *app\rect\y = mouseY
          
        ElseIf *app\hover & #BORDER_BOTTOM And *app\hover & #BORDER_RIGHT
          *app\rect\w = mouseX - *app\rect\x
          *app\rect\h = mouseY - *app\rect\y
          
        ElseIf *app\hover & #BORDER_RIGHT And *app\hover & #BORDER_TOP 
          *app\rect\w = mouseX - *app\rect\x
          *app\rect\h = (*app\rect\y + *app\rect\h) - mouseY
          *app\rect\y = mouseY
          
        ElseIf *app\hover & #BORDER_BOTTOM And *app\hover & #BORDER_LEFT
          *app\rect\w = (*app\rect\x + *app\rect\w) - mouseX
          *app\rect\h = mouseY - *app\rect\y
          *app\rect\x = mouseX
          
        ElseIf *app\hover & #BORDER_LEFT
          *app\rect\w = (*app\rect\x + *app\rect\w) - mouseX
          *app\rect\x = mouseX
          
        ElseIf *app\hover & #BORDER_RIGHT
          *app\rect\w = mouseX - *app\rect\x
          
        ElseIf *app\hover & #BORDER_TOP
          *app\rect\h = (*app\rect\y + *app\rect\h) - mouseY
          *app\rect\y = mouseY
          
        ElseIf *app\hover & #BORDER_BOTTOM
          *app\rect\h = mouseY - *app\rect\y
          
        EndIf
      EndIf
    EndIf
    
    _DrawRegion(*app)
  EndProcedure
  
  Procedure _Event(*app.App_t, event.i)
    Define window = EventWindow()
    If window = *app\window : _WindowEvent(*app, event) : EndIf
    If window = *app\region : _RegionEvent(*app, event) : EndIf
        
    If *app\record And *app\elapsed > *app\delay
      SetWindowColor(*app\window, RGB(0,64,255))
      Capture::Frame(*app\capture, #True)
      StartDrawing(ImageOutput(*app\capture\img))
      AnimatedGif_AddFrame(*app\writer, DrawingBuffer())
      StopDrawing()
      *app\elapsed = 0
    Else
      SetWindowColor(*app\window, RGB(222,222,222))
    EndIf
    
    
  EndProcedure
  
  
  Procedure ResizeRectangle(*app.App_t)
    
  EndProcedure
  
  Procedure InitRectangle(*app.App_t)
    ExamineDesktops()
    
    Define rect.Platform::Rectangle_t
    rect\x = DesktopX(0)
    rect\y = DesktopY(0)
    rect\w = DesktopWidth(0)
    rect\h = DesktopHeight(0)
    
    *app\rect\x = 100
    *app\rect\y = 100
    *app\rect\w = rect\w - 200
    *app\rect\h = rect\h - 200
    
    ; then open a fullscreen window
    Define flags = #PB_Window_BorderLess|#PB_Window_Maximize
    *app\region = OpenWindow(#PB_Any, rect\x, rect\y, rect\w, rect\h, "", flags, WindowID(*app\window))    
    SetWindowColor(*app\region, color)
    Platform::SetWindowTransparentColor(*app\region, TRANSPARENT_COLOR)
    
    *app\canvas = CanvasGadget(#PB_Any, 0, 0, rect\w, rect\h, #PB_Canvas_Keyboard)
    
    Platform::EnterWindowFullscreen(*app\region)
    _DrawRegion(*app)
  EndProcedure
  
  Procedure GetRectangle(*app.App_t, *r.Platform::Rectangle_t)
    Define startX = *app\rect\x
    Define endX = startX + *app\rect\w
    Define startY = *app\rect\y
    Define endY = startY + *app\rect\h
    
    If endX < startX : Swap startX, endX : EndIf
    If endY < startY : Swap startY, endY : EndIf
    
    *r\x = startX
    *r\y = startY
    *r\w = endX - startX
    *r\h = endY - startY
    If *r\w % 4 : *r\w + ( 4 - *r\w  % 4 ) : EndIf
    If *r\h % 4 : *r\h + ( 4 - *r\h  % 4 ) : EndIf 
    
  EndProcedure
  
  Procedure _StartRecord(*app.App_t)
    *app\record = #True   
    _DrawRegion(*app)
    
    If IsWindow(*app\region)
      GetRectangle(*app, *app\capture\rect)
    EndIf
    
    *app\writer = Capture::AnimatedGif_Init( *app\outputFolder+"/"+*app\outputFilename+".gif", 
                                        *app\capture\rect\w, *app\capture\rect\h, *app\delay)
  EndProcedure
  
  Procedure _StopRecord(*app.App_t)
    AnimatedGif_Term(*app\writer)
    *app\record = #False
    _DrawRegion(*app)
    *app\outputFilename = _RandomString(8)
  EndProcedure
  
  Procedure SelectRectangle(*app.App_t)
    StickyWindow(*app\window, #False)
    ScreenCaptureToGif::InitRectangle(*app)
    Capture::Init(*app\capture, *app\rect, *app\hWnd)
    StickyWindow(*app\window, #True)
  EndProcedure
  
  Procedure SelectWindow(*app.App_t)
    
  EndProcedure
  
  Procedure Launch()
    Define app.App_t
    app\delay = 5
    app\elapsed = 0
    app\record = #False
    app\close = #False
    app\outputFilename = _RandomString(8)
    CompilerSelect #PB_Compiler_OS
      CompilerCase #PB_OS_Windows
        app\outputFolder = "C:/Users/graph/Documents/bmal/src/captures"
      CompilerCase #PB_OS_MacOS
        app\outputFolder = "/Users/malartrebenjamin/Documents/RnD/captures"
    CompilerEndSelect
    
    app\writer = #Null
    Define width = 600
    Define height = 200
    app\window = OpenWindow( #PB_Any, 
                             200, 
                             200,
                             width,
                             height,
                             #APP_NAME, 
                             #PB_Window_SystemMenu|
                             #PB_Window_SizeGadget)
    
    ;app\hWnd = GetWindo
    
    Platform::EnsureCaptureAccess()
    
    app\ui = Widget::CreateRoot(app\window)
    
    Define c0 =  Widget::CreateContainer(root, "c0", 0, 0,width, 20, Widget::#WIDGET_LAYOUT_HORIZONTAL)
    Define l0 = Widget::CreateText(c0, "l0", "output folder :", 0, 0, 80, 20)
    Define path = Widget::CreateString(c0, "path", app\outputFolder, 0, 60, width-120, 20)
    Define btn0 = Widget::CreateButton(c0, "btn0", "...", width-40, 0, 40, 20)
    CloseGadgetList()

    Define c1 =   Widget::CreateContainer(root, "c1", 0, 40,width, 140, Widget::#WIDGET_LAYOUT_VERTICAL)
    Define btn1 = Widget::CreateButton(c1, "btn1", "Select Region", 10, 20, width-20, 32)
    Define btn2 = Widget::CreateButton(c1, "btn2", "Select Window", 10, 60, width-20, 32)
    Define btn3 = Widget::CreateButton(c1, "btn3", "Start Recording", 10, 100, width-20, 32)
    CloseGadgetList()
    
;     Define c2 =   Widget::CreateContainer(root, 0, 120,width, 50, Widget::#WIDGET_LAYOUT_HORIZONTAL)
; ;     Define ico1 = Widget::CreateIcon(c2, "M 4 4 L 28 16 L 4 28 Z", 0, 0, 32, 32, RGBA(20,220, 20, 255))
; ;     Define ico2 = Widget::CreateIcon(c2, "M 4 4 L 28 4 L 28 28 L 4 28 Z", 50, 0, 32, 32, RGBA(220, 60, 20, 255))
; 
;     CloseGadgetList()
    
    ;Define c0 =   Widget::CreateContainer(root, 0, 50,width, 50, #False, Widget::#WIDGET_LAYOUT_VERTICAL));     Define explorer = Widget::CreateExplorer(c0, 10, 10, width-20, 32))
    

    
;     Define c3 =   Widget::CreateContainer(root, 0, 100,width, 50, #False)
;     Define lst  = Widget::CreateList(c3, "zob", 0,0,100,100)
;     Define check = Widget::CreateCheck(c3, "zob", #True, 120, 10, 32, 32)
   

    Widget::SetCallback(btn1, @SelectRectangle(), app)   
    Widget::SetCallback(btn2, @SelectWindow(), app) 
    Widget::SetCallback(btn3, @OnRecord(), app)
    
    Widget::SetState(btn3, Widget::#WIDGET_STATE_TOGGLE)

  
    StickyWindow(app\window, #True)
    
    app\widgets(Str(Widget::GetGadgetId(path))) = path
    app\widgets(Str(Widget::GetGadgetId(btn0))) = btn0
    app\widgets(Str(Widget::GetGadgetId(btn1))) = btn1
    app\widgets(Str(Widget::GetGadgetId(btn2))) = btn2
    app\widgets(Str(Widget::GetGadgetId(btn3))) = btn3
 
    Widget::Resize(app\ui, 
                   Widget::#WIDGET_PADDING_X, 
                   Widget::#WIDGET_PADDING_Y, 
                   WindowWidth(app\window, #PB_Window_InnerCoordinate)-2*Widget::#WIDGET_PADDING_X, 
                   WindowHeight(app\window, #PB_Window_InnerCoordinate)-2*Widget::#WIDGET_PADDING_Y)
    
    Repeat
      
      Define startTime.q = ElapsedMilliseconds()      
     _Event(app, WindowEvent())
      
      app\elapsed +  (ElapsedMilliseconds() - startTime)
      
    Until app\close = #True Or event = #PB_Event_CloseWindow
    Capture::Term(app\capture)  
  EndProcedure
  
  Procedure OnRecord(*app.App_t)
    Define *btn.Widget::Button_t = Widget::GetWidgetByName(*app\widgets(), "btn3")

    If *btn
      If *btn\state & Widget::#WIDGET_STATE_ACTIVE
        _StopRecord(*app) 
        *btn\text = "Start Recording"
        SetGadgetText(*btn\gadget, *btn\text)
        SetGadgetAttribute(*btn\gadget, #PB_Gadget_FrontColor, RGB(55,255,120))
      Else
        _StartRecord(*app)
        *btn\text = "Stop Recording"
        SetGadgetText(*btn\gadget, *btn\text)
        SetGadgetAttribute(*btn\gadget, #PB_Gadget_FrontColor, RGB(255,55,120))
      EndIf 
      
    EndIf
    
  EndProcedure

  
EndModule

ScreenCaptureToGif::Launch()
; IDE Options = PureBasic 6.10 LTS (Windows - x64)
; CursorPosition = 304
; FirstLine = 291
; Folding = ---
; EnableXP