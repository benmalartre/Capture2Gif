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
  #RECTANGLE_THICKNESS = 2
  
  Enumeration
    #BORDER_NONE    = 0
    #BORDER_LEFT    = 1
    #BORDER_RIGHT   = 2
    #BORDER_TOP     = 4
    #BORDER_BOTTOM  = 8
  EndEnumeration
  
  
  Structure App_t
    window.i
    capture.Capture::Capture_t
    outputFolder.s
    outputFilename.s
    delay.i
    record.b
    close.b
    *writer
    hWnd.i
    elapsed.q
    hover.i
    drag.i
    state.i
    rect.Platform::Rectangle_t
    Map widgets.i() 
  EndStructure

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
  UsePNGImageDecoder()
  
  Procedure OnEvent(*app.App_t, canvas.i, type.i)
    Define window = EventWindow()
    If window = *app\window
      
    Else
      Define mouseX = WindowMouseX(window)
      Define mouseY = WindowMouseY(window)
      
      If type = #PB_EventType_LeftButtonDown And *app\hover 
        *app\drag = *app\hover
        *app\state + 1
      ElseIf type = #PB_EventType_LeftButtonUp And *app\drag
        *app\drag = #BORDER_NONE
      ElseIf type = #PB_EventType_MouseMove
        If *app\drag = #BORDER_NONE
          *app\hover = #BORDER_NONE
          If Abs(mouseX - *app\rect\x) < 5
            *app\hover | #BORDER_LEFT
          ElseIf Abs(mouseX - (*app\rect\x + *app\rect\w)) < 5
            SetGadgetAttribute(canvas, #PB_Canvas_Cursor, #PB_Cursor_LeftRight)
            *app\hover | #BORDER_RIGHT
          EndIf
          
          If Abs(mouseY - *app\rect\y) < 5
            SetGadgetAttribute(canvas, #PB_Canvas_Cursor, #PB_Cursor_UpDown)
            *app\hover | #BORDER_TOP
          ElseIf Abs(mouseY - (*app\rect\y + *app\rect\h)) < 5
            *app\hover | #BORDER_BOTTOM
            SetGadgetAttribute(canvas, #PB_Canvas_Cursor, #PB_Cursor_UpDown)
          EndIf
  
          If (*app\hover & #BORDER_LEFT And *app\hover & #BORDER_TOP) Or 
             (*app\hover & #BORDER_BOTTOM And *app\hover & #BORDER_RIGHT)
            SetGadgetAttribute(canvas, #PB_Canvas_Cursor, #PB_Cursor_LeftUpRightDown)
          ElseIf (*app\hover & #BORDER_RIGHT And *app\hover & #BORDER_TOP) Or 
             (*app\hover & #BORDER_BOTTOM And *app\hover & #BORDER_LEFT)
            SetGadgetAttribute(canvas, #PB_Canvas_Cursor, #PB_Cursor_LeftDownRightUp)
          ElseIf (*app\hover & #BORDER_LEFT) Or (*app\hover & #BORDER_RIGHT)
            SetGadgetAttribute(canvas, #PB_Canvas_Cursor, #PB_Cursor_LeftRight)
          ElseIf (*app\hover & #BORDER_TOP) Or (*app\hover & #BORDER_BOTTOM)
            SetGadgetAttribute(canvas, #PB_Canvas_Cursor, #PB_Cursor_UpDown)
          Else
            SetGadgetAttribute(canvas, #PB_Canvas_Cursor, #PB_Cursor_Default)
          EndIf
        
        Else
          If *app\hover & #BORDER_LEFT And *app\hover & #BORDER_TOP
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
    EndIf
  EndProcedure
  
  Procedure ResizeRectangle(*app.App_t)
    
  EndProcedure
  
  Procedure GetRectangle(*app.App_t, *r.Platform::Rectangle_t)
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
    Define color = RGB(0,255,0)
    Define flags = #PB_Window_BorderLess
    Define window = OpenWindow(#PB_Any, rect\x, rect\y, rect\w, rect\h, "", flags, WindowID(*app\window))    
    SetWindowColor(window, color)
    Platform::SetWindowTransparentColor(window, color)
    
    Define canvas = CanvasGadget(#PB_Any, 0, 0, rect\w, rect\h, #PB_Canvas_Keyboard)
    
    Platform::EnterWindowFullscreen(window)
    
    Define width = WindowWidth(window, #PB_Window_InnerCoordinate)
    Define height = WindowHeight(window, #PB_Window_InnerCoordinate)
    
    Define startX.i, startY.i, endX.i, endY.i
    Define state.i = 0
    Define color = RGBA(255,128,0, 222)
    
    Repeat
      event = WaitWindowEvent()
      If EventWindow() <> window : Continue : EndIf
      
      If EventGadget() = canvas
        eventType = EventType()      
        OnEvent(*app, window, canvas, eventType)
      EndIf
      
      StartVectorDrawing(CanvasVectorOutput(canvas))

      AddPathBox(0,0,width, height)
      VectorSourceColor(RGBA(0, 255, 0, 255))
      FillPath()
      
      MovePathCursor(*app\rect\x,*app\rect\y)
      AddPathLine(*app\rect\x + *app\rect\w, *app\rect\y)
      AddPathLine(*app\rect\x + *app\rect\w, *app\rect\y + *app\rect\h)
      AddPathLine(*app\rect\x, *app\rect\y + *app\rect\h)
      ClosePath()
      VectorSourceColor(RGBA(255, 255, 0, 255))
  
      StrokePath(5)
      ; DrawVectorImage(ImageID(background\img))
      
      StopVectorDrawing()
      
      If eventType = #PB_EventType_LeftButtonDown
        state + 1
      ElseIf state And eventType = #PB_EventType_LeftButtonUp
        state + 1
      EndIf
    
    ForEver
    
;     Capture::Term(background)
    
    If endX < startX : Swap startX, endX : EndIf
    If endY < startY : Swap startY, endY : EndIf
    
    *r\x = startX
    *r\y = startY
    *r\w = endX - startX
    *r\h = endY - startY
    If *r\w % 4 : *r\w + ( 4 - *r\w  % 4 ) : EndIf
    If *r\h % 4 : *r\h + ( 4 - *r\h  % 4 ) : EndIf
    
    SetActiveWindow(*app\window)
    CloseWindow(window) 
  EndProcedure
  
  Procedure _StartRecord(*app.App_t)
    *app\writer = Capture::AnimatedGif_Init( *app\outputFolder+"/"+*app\outputFilename+".gif", 
                                        *app\capture\rect\w, *app\capture\rect\h, *app\delay)
    *app\record = #True     
  EndProcedure
  
  Procedure _StopRecord(*app.App_t)
    AnimatedGif_Term(*app\writer)
    *app\record = #False
    Capture::Term(*app\capture)
  EndProcedure
  
  Procedure.s _RandomString(len.i)
    Define string.s
    For i=0 To len-1
      Select Random(2) 
        Case 0  ; (a ---> z)
          string + Chr(Random(25) + 97)
        Case 1  ; (A ---> Z)
          string + Chr(Random(25) + 65)
        Default ; (0 ---> 9)
          string + Chr(Random(9) + 48)
      EndSelect
    Next
    ProcedureReturn string
  EndProcedure
  
  Procedure SelectRectangle(*app.App_t)
    StickyWindow(*app\window, #False)
    ScreenCaptureToGif::GetRectangle(*app, *app\rect)
    Capture::Init(*app\capture, *app\rect, *app\hWnd)
    StickyWindow(*app\window, #True)
  EndProcedure
  
  Procedure SelectWindow(*app.App_t)
    
  EndProcedure
  
  Procedure TransparentTextGadget(hwnd.i, x, y, string.s, Font.l, Color.l) ;-- Create Text without a background
  	; TextGadget() seem's to leave holes behind everything
  	; It is probably better practice to remove the StartDrawing(WindowOutput(hwnd)) from this procedure
    ; and instead place it within the main loop. I do not know if keeping it within a Procedure would hinder performance.
    Debug hwnd
  	StartDrawing(WindowOutput(hwnd))
  		If Font.l <> #Null
  			DrawingFont(FontID(Font.l))
  		EndIf
  		DrawingMode(#PB_2DDrawing_Transparent)
  		DrawText(x, y, string.s,Color.l)
  	StopDrawing()
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
    
    Define root = Widget::CreateRoot(app\window)
    
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

;     
    
    Widget::Resize(root, 
                   Widget::#WIDGET_PADDING_X, 
                   Widget::#WIDGET_PADDING_Y, 
                   WindowWidth(app\window, #PB_Window_InnerCoordinate)-2*Widget::#WIDGET_PADDING_X, 
                   WindowHeight(app\window, #PB_Window_InnerCoordinate)-2*Widget::#WIDGET_PADDING_Y)
    
    Repeat
      
      Define startTime.q = ElapsedMilliseconds()
      Define event = WindowEvent()
      
      If event = #PB_Event_Gadget 
        Define gadget = EventGadget()

        If FindMapElement(app\widgets(), Str(gadget))
          Widget::OnEvent(app\widgets())
        EndIf
        
      ElseIf event = #PB_Event_SizeWindow
        Widget::Resize(root, 
                       0, 
                       0, 
                       WindowWidth(app\window, #PB_Window_InnerCoordinate), 
                       WindowHeight(app\window, #PB_Window_InnerCoordinate))
      EndIf
      
      If app\record And app\elapsed > app\delay
        SetWindowColor(app\window, RGB(0,64,255))
        Capture::Frame(app\capture, #True)
        StartDrawing(ImageOutput(app\capture\img))
        AnimatedGif_AddFrame(app\writer, DrawingBuffer())
        StopDrawing()
        app\elapsed = 0
      Else
        SetWindowColor(app\window, RGB(222,222,222))
      EndIf
      
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
; CursorPosition = 167
; FirstLine = 146
; Folding = ---
; EnableXP