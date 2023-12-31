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
  EndStructure

  Declare GetRectangle(*app.App_t, *r.Platform::Rectangle_t)
  Declare SelectWindow(*app.App_t)
  Declare SelectRectangle(*app.App_t)
  
  Declare OnRecord(*app.App_t)
  Declare OnStop(*app.App_t)
  
  Declare Launch()
EndDeclareModule



;-----------------------------------------------------------------------------------------------
; ScreenCaptureToGif Implementation
;-----------------------------------------------------------------------------------------------
Module ScreenCaptureToGif
  UseModule Capture

  Procedure GetRectangle(*app.App_t, *r.Platform::Rectangle_t)
    ExamineDesktops()
    
    ; first capture desktop framebuffer
    Define background.Capture_t
    Define rect.Platform::Rectangle_t
    rect\x = 0
    rect\y = 0
    rect\w = DesktopWidth(0)
    rect\h = DesktopHeight(0)
    
    Capture::Init(background, rect)
    Capture::Frame(background, #False)
    
    ; then open a fullscreen window
    Define flags = #PB_Window_Maximize|#PB_Window_BorderLess|#PB_Window_Invisible
    Define window = OpenWindow(#PB_Any, rect\x, rect\y, rect\w, rect\h, "background", flags)    
    Define canvas = CanvasGadget(#PB_Any, rect\x, rect\y, rect\w, rect\h, #PB_Canvas_Keyboard)
    Platform::EnterWindowFullscreen(window)
    HideWindow(window, #False)
    
    Define startX.i, startY.i, endX.i, endY.i
    Define state.i = 0
    Define color = RGBA(255,128,0, 222)
    
    Repeat
      event = WaitWindowEvent()
      If EventWindow() <> window : Continue : EndIf
      
      eventType = EventType()      
      
      If state : endX = DesktopMouseX() : endY = DesktopMouseY() 
      Else : startX = DesktopMouseX() : startY = DesktopMouseY() : EndIf
    
      StartVectorDrawing(CanvasVectorOutput(canvas))
      DrawVectorImage(ImageID(background\img))
      If state
        MovePathCursor(startX, startY)
        AddPathLine(endX, startY)
        AddPathLine(endX, endY)
        AddPathLine(startX, endY)
        ClosePath()
        
        VectorSourceColor(color)
        StrokePath(8)
       
      Else
;         Box(startX - 12, startY -#RECTANGLE_THICKNESS * 0.5, 24, #RECTANGLE_THICKNESS, color)
;         Box(startX - #RECTANGLE_THICKNESS * 0.5, startY - 12, #RECTANGLE_THICKNESS, 24, color)
      EndIf
      StopVectorDrawing()
      
      If eventType = #PB_EventType_LeftButtonDown
        state + 1
      ElseIf state And eventType = #PB_EventType_LeftButtonUp
        state + 1
      EndIf
    
    Until state = 2
    
    Capture::Term(background)
    
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
  
  Procedure SelectRectangle(*app.App_t)
    StickyWindow(*app\window, #False)
    Define rect.Platform::Rectangle_t
    ScreenCaptureToGif::GetRectangle(*app, rect)
    Capture::Init(*app\capture, rect, *app\hWnd)
   
    *app\writer = Capture::AnimatedGif_Init( *app\outputFolder+"/"+*app\outputFilename+".gif", 
                                            *app\capture\rect\w, *app\capture\rect\h, *app\delay)
    StickyWindow(*app\window, #True)
    *app\record = #True
  EndProcedure
  
  Procedure SelectWindow(*app.App_t)
    
  EndProcedure
  
  Procedure Launch()
    Define app.App_t
    app\delay = 50
    app\record = #False
    app\close = #False
    app\outputFilename = "image"
    CompilerSelect #PB_Compiler_OS
      CompilerCase #PB_OS_Windows
        app\outputFolder = "C:/Users/graph/Documents/bmal/src/Capture2Gif"
      CompilerCase #PB_OS_MacOS
        app\outputFolder = "/Users/malartrebenjamin/Documents/RnD/Capture2Gif"
    CompilerEndSelect
    
    app\writer = #Null
    Define width = 400
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
    ;     Define c0 =   Widget::CreateContainer(root, 0, 50,width, 50, #False, Widget::#WIDGET_LAYOUT_VERTICAL));     Define explorer = Widget::CreateExplorer(c0, 10, 10, width-20, 32))
  
    Define c1 =   Widget::CreateContainer(root, 0, 50,width, 50, #True, Widget::#WIDGET_LAYOUT_VERTICAL)
    Define btn1 = Widget::CreateButton(c1, "Select Region", 10, 10, width-20, 32)
    Define btn2 = Widget::CreateButton(c1, "Select Window", 10, 50, width-20, 32)
    
    Define c2 =   Widget::CreateContainer(root, 0, 50,width, 50, #True, Widget::#WIDGET_LAYOUT_HORIZONTAL)
    Define ico1 = Widget::CreateIcon(c2, "M 4 4 L 28 16 L 4 28 Z", 128, 120, 32, 32, RGBA(20,220, 20, 255))
    Define ico2 = Widget::CreateIcon(c2, "M 4 4 L 28 4 L 28 28 L 4 28 Z", 190, 120, 32, 32, RGBA(220, 60, 20, 255))
    
;     Define c3 =   Widget::CreateContainer(root, 0, 100,width, 50, #False)
;     Define lst  = Widget::CreateList(c3, "zob", 0,0,100,100)
;     Define check = Widget::CreateCheck(c3, "zob", #True, 120, 10, 32, 32)
    
    Widget::Resize(root, 0, 0, width, height)
    Widget::Draw(root)
    Widget::SetState(ico1, Widget::#WIDGET_STATE_TOGGLE)
    Widget::SetCallback(btn1, @SelectRectangle(), app)   
    Widget::SetCallback(btn2, @SelectWindow(), app) 
    Widget::SetCallback(ico1, @OnRecord(), app)
    Widget::SetCallback(ico2, @OnStop(), app)
  
    StickyWindow(app\window, #True)
    
    NewMap widgets.i()    
    widgets(Str(Widget::GetGadgetId(c1))) = c1
    Widgets(Str(Widget::GetGadgetId(c2))) = c2
;     
    
;     Define hWnd = Win::GetWindowByName("XSIFloatingView")
    
    Repeat
      Define event = WaitWindowEvent(app\delay)
  
      If event = #PB_Event_Gadget 
        Define gadget = EventGadget()
        Debug  "gadget event : "+Str(gadget)
  
        If FindMapElement(widgets(), Str(gadget))
          Widget::OnEvent(widgets())
          Widget::Draw(root)
        Else 
          Debug "gadget not in map"
        EndIf
        
      ElseIf event = #PB_Event_SizeWindow
        Widget::Resize(root, 
                       0, 
                       0, 
                       WindowWidth(app\window, #PB_Window_InnerCoordinate), 
                       WindowHeight(app\window, #PB_Window_InnerCoordinate))
        Widget::Draw(root)
      EndIf
      
      If app\record
        SetWindowColor(app\window, RGB(0,64,255))
        Capture::Frame(app\capture, #True)
        StartDrawing(ImageOutput(app\capture\img))
        AnimatedGif_AddFrame(app\writer, DrawingBuffer())
        StopDrawing()
        Delay(app\delay)
      Else
        SetWindowColor(app\window, RGB(128,128,128))
      EndIf
      
    Until app\close = #True Or event = #PB_Event_CloseWindow
    Capture::Term(app\capture)  
  EndProcedure
  
  Procedure OnRecord(*app.App_t)
    *app\outputFilename = "test"
    SelectRectangle(*app)
    *app\record = #True
  EndProcedure
  
  Procedure OnStop(*app.App_t)
    If *app\record
      AnimatedGif_Term(*app\writer)
      *app\record = #False
    EndIf
    *app\close = #True
  EndProcedure
  
EndModule

ScreenCaptureToGif::Launch()
; IDE Options = PureBasic 6.10 beta 1 (Windows - x64)
; CursorPosition = 209
; FirstLine = 163
; Folding = v-
; EnableXP