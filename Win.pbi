DeclareModule Win
  Structure Window_t
    hWnd.i
    Map childrens.i()
  EndStructure
  
  Declare GetWindowByName(name.s="Softimage")
  
  Declare EnterWindowFullscreen(window)
  Declare ExitWindowFullscreen(window, x.i, y.i, width.i, height.i, title.s="")

  
  CompilerIf #PB_Compiler_OS = #PB_OS_MacOS
    #NSApplicationPresentationDefault                    = 0
    #NSApplicationPresentationAutoHideDock               = 1 << 0
    #NSApplicationPresentationAutoHideMenuBar            = 1 << 2
    
    #NSBorderlessWindowMask                              = 0
    #NSTitledWindowMask                                  = 1 << 0
    #NSClosableWindowMask                                = 1 << 1
    #NSMiniaturizableWindowMask                          = 1 << 2
    #NSResizableWindowMask                               = 1 << 3
  CompilerEndIf
  
  
EndDeclareModule

Module Win
 CompilerIf #PB_Compiler_OS = #PB_OS_Windows

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
  
  ;--[ Window fullscreen procedures ]----------------------------------------------------------------

  Procedure EnterWindowFullscreen(window)
    Protected hWnd = WindowID(window)
    SetWindowState(window, #PB_Window_Normal)
    SetWindowLong_(hWnd, #GWL_STYLE, GetWindowLong_(hWnd, #GWL_STYLE)|#WS_CAPTION|#WS_SIZEBOX) 
  EndProcedure
  
  Procedure ExitWindowFullscreen(window, x.i, y.i, width.i, height.i, title.s="")
    Protected hWnd = WindowID(window)
    SetWindowState(window, #PB_Window_Maximize)
    SetWindowLong_(hWnd, #GWL_STYLE, GetWindowLong_(hWnd, #GWL_STYLE)&~#WS_CAPTION&~#WS_SIZEBOX) 
  EndProcedure

CompilerElseIf #PB_Compiler_OS = #PB_OS_MacOS
  ; try get a window by it's name
  ;
  Procedure GetWindowByName(name.s="Softimage")
    
    Define screen = CocoaMessage(0,0,"NSScreen mainScreen")
    CocoaMessage(@visibleFrame.NSRect,mainScreen,"visibleFrame")
    
    Debug visibleFrame\origin\x
    Debug visibleFrame\origin\y
    Debug visibleFrame\size\height
    Debug visibleFrame\size\width
    
  EndProcedure
  
  ;--[ Window fullscreen procedures ]----------------------------------------------------------------

  Procedure EnterWindowFullscreen(window)
    Define sharedApp = CocoaMessage(0, 0, "NSApplication sharedApplication")
    CocoaMessage(0, WindowID(window), "setStyleMask:", #NSBorderlessWindowMask)
    CocoaMessage(0, sharedApp, "setPresentationOptions:", 
                 #NSApplicationPresentationAutoHideDock | #NSApplicationPresentationAutoHideMenuBar)
    ExamineDesktops()
    ResizeWindow(window, 0, 0, DesktopWidth(0), DesktopHeight(0))
  EndProcedure
  
  Procedure ExitWindowFullscreen(window, x.i, y.i, width.i, height.i, title.s="")
    Define sharedApp = CocoaMessage(0, 0, "NSApplication sharedApplication")
    CocoaMessage(0, sharedApp, "setPresentationOptions:", #NSApplicationPresentationDefault)
    CocoaMessage(0, WindowID(window), "setStyleMask:", 
                 #NSTitledWindowMask | #NSClosableWindowMask | #NSMiniaturizableWindowMask | #NSResizableWindowMask)
    If title : SetWindowTitle(0, title) : EndIf
    ResizeWindow(window, x, y, width, height)
  EndProcedure
  
  
CompilerEndIf
EndModule
; IDE Options = PureBasic 6.00 Beta 7 - C Backend (MacOS X - arm64)
; CursorPosition = 117
; FirstLine = 87
; Folding = ---
; EnableXP