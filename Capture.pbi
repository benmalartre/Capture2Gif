XIncludeFile "Win.pbi"
XIncludeFile "Core.pbi"
XIncludeFile "Widget.pbi"
;-----------------------------------------------------------------------------------------------
;         Scr33nCord3r
;
;     Windows Only Windows/Desktop Record To Gif
;-----------------------------------------------------------------------------------------------
DeclareModule Scr33nCord3r
  UseModule Capture
  #RECTANGLE_THICKNESS = 2
  
  Enumeration
    #RECORD_BTN
    #STOP_BTN
    #PROCESS_LIST
  EndEnumeration
  
  Structure App_t
    window.i
    capture.Capture::Capture_t
    outputFolder.s
    outputFilename.s
    frame.i
    delay.i
    record.b
    *writer
    hWnd.i
  EndStructure

  Declare GetRectangle(*rect.Rectangle_t, hwnd=#Null)
  Declare SelectWindow(*app.App_t)
  Declare SelectRectangle(*app.App_t)
  
  Declare OnPlay(*widget.Widget::Widget_t)
  Declare OnStop(*widget.Widget::Widget_t)
  Declare OnZob(*widget.Widget::Widget_t)
  Declare Launch()
EndDeclareModule


;-----------------------------------------------------------------------------------------------
; Scr33nCord3r Implementation
;-----------------------------------------------------------------------------------------------
Module Scr33nCord3r
  UseModule Capture
  Procedure GetRectangle(*rect.Rectangle_t, hwnd=#Null)
    If InitSprite() = 0 Or InitMouse() = 0 Or InitKeyboard() = 0
      MessageRequester("Error", "Can't open hardware acceleration", 0)
      End
    EndIf
    
    ExamineDesktops()
    Define width = DesktopWidth(0)
    Define height = DesktopHeight(0)
    Define rect.Rectangle_t 
    rect\y = 0
    rect\x = 0
    rect\w = width
    rect\h = height
    
    Define background.Capture_t
    Init(background, rect, hwnd)
    Capture(background, #False)
    
    Define screen = OpenScreen(width, height,32, "Capture") 
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
  
  Procedure SelectRectangle(*app.App_t)
    Define rect.Capture::Rectangle_t

    StickyWindow(*app\window, #False)
    If Not *app\hWnd
      Scr33nCord3r::GetRectangle(rect)
      Capture::Init(*app\capture, rect, #Null)
    Else 
      Capture::Init(*app\capture, #Null, *app\hWnd)
    EndIf
  
    *app\writer = Capture::AnimatedGif_Init( *app\outputFolder+"/"+*app\outputFilename+".gif", 
                                            *app\capture\rect\w, *app\capture\rect\h, *app\delay)
    StickyWindow(*app\window, #True)
    *app\record = #True
  EndProcedure
  
  Procedure SelectWindow(*app.App_t)
    
  EndProcedure
  
  Procedure Launch()
    Define app.App_t
    app\delay = 5
    app\record = #False
    app\outputFilename = "image"
    app\outputFolder = "C:/Users/graph/Documents/bmal/src/Capture2Gif"
    app\writer = #Null
    Define width = 400
    Define height = 200
    app\window = OpenWindow( #PB_Any, 
                             200, 
                             200,
                             width,
                             height,
                             "Scr33nC0rd3r", 
                             #PB_Window_SystemMenu|
                             #PB_Window_SizeGadget)
    
    app\hWnd = GetWindo
    
    Define root = Widget::CreateRoot(app\window)
    ;     Define c0 =   Widget::CreateContainer(root, 0, 50,width, 50, #False, Widget::#WIDGET_LAYOUT_VERTICAL));     Define explorer = Widget::CreateExplorer(c0, 10, 10, width-20, 32))
  
    Define c1 =   Widget::CreateContainer(root, 0, 50,width, 50, #True, Widget::#WIDGET_LAYOUT_VERTICAL)
    Define btn1 = Widget::CreateButton(c1, "Select Region", 10, 10, width-20, 32)
    Define btn2 = Widget::CreateButton(c1, "Select Window", 10, 50, width-20, 32)
    
    Define c2 =   Widget::CreateContainer(root, 0, 50,width, 50, #True, Widget::#WIDGET_LAYOUT_HORIZONTAL)
    Define ico1 = Widget::CreateIcon(c2, "M 4 4 L 28 16 L 4 28 Z", 128, 120, 32, 32)
    Define ico2 = Widget::CreateIcon(c2, "M 4 4 L 28 4 L 28 28 L 4 28 Z", 190, 120, 32, 32)
    
;     Define c3 =   Widget::CreateContainer(root, 0, 100,width, 50, #False)
;     Define lst  = Widget::CreateList(c3, "zob", 0,0,100,100)
;     Define check = Widget::CreateCheck(c3, "zob", #True, 120, 10, 32, 32)
    
    Widget::Resize(root, 0, 0, width, height)
    Widget::Draw(root)
    Widget::SetState(ico1, Widget::#WIDGET_STATE_TOGGLE)
    Widget::SetCallback(btn1, @SelectRectangle(), app)   
    Widget::SetCallback(btn2, @SelectWindow(), app) 
    Widget::SetCallback(ico1, @OnPlay(), ico1)
    Widget::SetCallback(ico2, @OnZob(), ico2)
  
    StickyWindow(app\window, #True)
    
    NewMap widgets.i()    
    widgets(Str(Widget::GetGadgetId(c1))) = c1
    Widgets(Str(Widget::GetGadgetId(c2))) = c2
;     
    
;     Define hWnd = Win::GetWindowByName("XSIFloatingView")
      
    Define close = #False
    Define record = #False
    Define rect.Capture::Rectangle_t
    Define capture.Capture::Capture_t
    
    Repeat
      Define event = WaitWindowEvent(app\delay)
  
      If event = #PB_Event_Gadget 
        Define gadget = EventGadget()
  
        If FindMapElement(widgets(), Str(gadget))
          Widget::OnEvent(widgets())
        EndIf
        
        If gadget = Scr33nCord3r::#RECORD_BTN
          
        ElseIf gadget = Scr33nCord3r::#STOP_BTN
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
                       WindowWidth(app\window, #PB_Window_InnerCoordinate), 
                       WindowHeight(app\window, #PB_Window_InnerCoordinate))
        Widget::Draw(root)
      EndIf
      
      If record
        SetWindowColor(app\window, RGB(0,64,255))
        Capture::Capture(app\capture, #True)
        AnimatedGif_AddFrame(app\writer, app\capture\buffer)
        app\frame + 1
        Delay(app\delay)
      Else
        SetWindowColor(app\window, RGB(128,128,128))
      EndIf
      
    Until close = #True Or event = #PB_Event_CloseWindow
    Capture::Term(app\capture)  
  EndProcedure
  
  Procedure OnPlay(*app.App_t)

  EndProcedure
  
  Procedure OnStop(*app.App_t)

  EndProcedure
  

  
  Procedure OnZob(*app.App_t)
    Debug "ZOB"
    Define writer = Capture::AnimatedGif_Init("/Users/malartrebenjamin/Documents/RnD/Capture2Gif/zob.gif", 256, 256, 10)
    Define buffer = AllocateMemory(256 *256 *4)
    For i = 0 To 32
        RandomData(buffer, 256 * 256 * 4)
        Capture::AnimatedGif_AddFrame(writer, buffer)
      Next
      Capture::AnimatedGif_Term(writer)
      FreeMemory(buffer)
  EndProcedure
EndModule

CompilerIf Not Defined(PB_Compiler_Backend,#PB_Constant)
  CompilerError "Please use PureBasic Version 6.00 Beta1" 
CompilerElseIf #PB_Compiler_Backend<>#PB_Backend_C
  CompilerError "Please use Compiler-Option C Backend."
CompilerEndIf 
Scr33nCord3r::Launch()
; IDE Options = PureBasic 6.04 LTS (Windows - x64)
; CursorPosition = 278
; FirstLine = 225
; Folding = --
; EnableXP